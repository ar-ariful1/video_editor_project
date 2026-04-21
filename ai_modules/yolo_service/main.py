# ai_modules/yolo_service/main.py
# Object tracking microservice using YOLOv8n with ONNX Runtime

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import cv2
import onnxruntime as ort
import tempfile, os, asyncio, logging
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="YOLOv8 Object Tracking Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

MODEL_PATH = os.environ.get("YOLO_MODEL_PATH", "yolov8n.onnx")
INPUT_SIZE = 640

# COCO class names (80 classes)
COCO_CLASSES = [
    'person','bicycle','car','motorcycle','airplane','bus','train','truck','boat',
    'traffic light','fire hydrant','stop sign','parking meter','bench','bird','cat',
    'dog','horse','sheep','cow','elephant','bear','zebra','giraffe','backpack',
    'umbrella','handbag','tie','suitcase','frisbee','skis','snowboard','sports ball',
    'kite','baseball bat','baseball glove','skateboard','surfboard','tennis racket',
    'bottle','wine glass','cup','fork','knife','spoon','bowl','banana','apple',
    'sandwich','orange','broccoli','carrot','hot dog','pizza','donut','cake','chair',
    'couch','potted plant','bed','dining table','toilet','tv','laptop','mouse',
    'remote','keyboard','cell phone','microwave','oven','toaster','sink',
    'refrigerator','book','clock','vase','scissors','teddy bear','hair drier','toothbrush'
]

session: ort.InferenceSession = None

@app.on_event("startup")
async def load_model():
    global session
    providers = ['CUDAExecutionProvider', 'CPUExecutionProvider'] if 'CUDAExecutionProvider' in ort.get_available_providers() else ['CPUExecutionProvider']
    try:
        session = ort.InferenceSession(MODEL_PATH, providers=providers)
        logger.info(f"YOLOv8 loaded: {MODEL_PATH}")
    except Exception as e:
        logger.error(f"Failed to load YOLOv8: {e}")

# ── Models ────────────────────────────────────────────────────────────────────

class BoundingBox(BaseModel):
    x: float      # normalized 0-1
    y: float
    width: float
    height: float
    confidence: float
    class_id: int
    class_name: str

class FrameDetection(BaseModel):
    frame_index: int
    time_seconds: float
    detections: list[BoundingBox]

class TrackResult(BaseModel):
    fps: float
    total_frames: int
    tracked_class: str
    detections_per_frame: list[FrameDetection]
    # Keyframes for Flutter timeline
    keyframes: list[dict]

# ── Inference ─────────────────────────────────────────────────────────────────

def preprocess(frame: np.ndarray) -> tuple[np.ndarray, tuple, tuple]:
    """Letterbox resize + normalize for YOLOv8."""
    h, w = frame.shape[:2]
    scale = INPUT_SIZE / max(h, w)
    new_h, new_w = int(h * scale), int(w * scale)
    resized = cv2.resize(frame, (new_w, new_h))
    padded = np.full((INPUT_SIZE, INPUT_SIZE, 3), 114, dtype=np.uint8)
    pad_y, pad_x = (INPUT_SIZE - new_h) // 2, (INPUT_SIZE - new_w) // 2
    padded[pad_y:pad_y+new_h, pad_x:pad_x+new_w] = resized

    blob = padded.astype(np.float32) / 255.0
    blob = np.transpose(blob, (2, 0, 1))[np.newaxis]
    return blob, (h, w), (pad_x, pad_y, scale)

def postprocess(
    output: np.ndarray,
    orig_shape: tuple,
    pad_info: tuple,
    conf_thresh: float = 0.4,
    iou_thresh: float = 0.5,
    target_class: Optional[int] = None
) -> list[BoundingBox]:
    """NMS + decode boxes back to original image coordinates."""
    pad_x, pad_y, scale = pad_info
    orig_h, orig_w = orig_shape
    predictions = output[0].T  # (8400, 84)

    boxes, scores, class_ids = [], [], []
    for pred in predictions:
        cls_scores = pred[4:]
        class_id = int(np.argmax(cls_scores))
        confidence = float(cls_scores[class_id])
        if confidence < conf_thresh:
            continue
        if target_class is not None and class_id != target_class:
            continue

        cx, cy, bw, bh = pred[:4]
        # Undo letterbox
        x1 = (cx - bw/2 - pad_x) / scale
        y1 = (cy - bh/2 - pad_y) / scale
        x2 = (cx + bw/2 - pad_x) / scale
        y2 = (cy + bh/2 - pad_y) / scale

        boxes.append([x1, y1, x2-x1, y2-y1])
        scores.append(confidence)
        class_ids.append(class_id)

    if not boxes:
        return []

    indices = cv2.dnn.NMSBoxes(boxes, scores, conf_thresh, iou_thresh)
    result = []
    for i in (indices.flatten() if len(indices) else []):
        x, y, w, h = boxes[i]
        result.append(BoundingBox(
            x=max(0, x/orig_w), y=max(0, y/orig_h),
            width=min(1, w/orig_w), height=min(1, h/orig_h),
            confidence=scores[i],
            class_id=class_ids[i],
            class_name=COCO_CLASSES[class_ids[i]] if class_ids[i] < len(COCO_CLASSES) else 'unknown',
        ))
    return result

def detect_frame(frame: np.ndarray, target_class: Optional[int] = None, conf: float = 0.4) -> list[BoundingBox]:
    blob, orig_shape, pad_info = preprocess(frame)
    input_name = session.get_inputs()[0].name
    output = session.run(None, {input_name: blob})[0]
    return postprocess(output, orig_shape, pad_info, conf_thresh=conf, target_class=target_class)

# ── Keyframe Generation ───────────────────────────────────────────────────────

def detections_to_keyframes(
    detections_per_frame: list[FrameDetection],
    fps: float,
    smoothing: bool = True
) -> list[dict]:
    """
    Convert per-frame detections to Flutter timeline keyframes.
    Output: [{time, x, y, width, height}] for the primary tracked object.
    """
    keyframes = []
    prev = None

    for fd in detections_per_frame:
        if not fd.detections:
            continue
        # Pick highest-confidence detection
        det = max(fd.detections, key=lambda d: d.confidence)
        kf = {
            'time': fd.time_seconds,
            'x': det.x + det.width / 2,   # center x (normalized)
            'y': det.y + det.height / 2,   # center y (normalized)
            'width': det.width,
            'height': det.height,
            'confidence': det.confidence,
        }
        # Simple smoothing: skip if change is tiny
        if prev and smoothing:
            dx = abs(kf['x'] - prev['x'])
            dy = abs(kf['y'] - prev['y'])
            if dx < 0.005 and dy < 0.005:
                continue
        keyframes.append(kf)
        prev = kf

    return keyframes

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": session is not None, "classes": len(COCO_CLASSES)}

@app.get("/classes")
async def get_classes():
    return {"classes": [{"id": i, "name": n} for i, n in enumerate(COCO_CLASSES)]}

@app.post("/detect/image")
async def detect_image(
    file: UploadFile = File(...),
    confidence: float = 0.4,
    target_class: Optional[int] = None,
):
    """Detect objects in a single image."""
    if session is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    content = await file.read()
    nparr = np.frombuffer(content, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=422, detail="Invalid image")

    loop = asyncio.get_event_loop()
    detections = await loop.run_in_executor(None, detect_frame, frame, target_class, confidence)
    return {"detections": detections, "count": len(detections)}

@app.post("/track/video", response_model=TrackResult)
async def track_video(
    file: UploadFile = File(...),
    target_class: int = 0,      # 0 = person
    confidence: float = 0.4,
    sample_fps: float = 10.0,   # Process this many frames per second
):
    """Track an object class through an entire video, returning keyframes."""
    if session is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    suffix = os.path.splitext(file.filename or "video.mp4")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        video_path = tmp.name

    try:
        cap = cv2.VideoCapture(video_path)
        orig_fps = cap.get(cv2.CAP_PROP_FPS) or 30
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        frame_skip = max(1, round(orig_fps / sample_fps))

        detections_per_frame: list[FrameDetection] = []
        frame_idx = 0

        loop = asyncio.get_event_loop()

        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if frame_idx % frame_skip == 0:
                time_s = frame_idx / orig_fps
                dets = await loop.run_in_executor(None, detect_frame, frame, target_class, confidence)
                detections_per_frame.append(FrameDetection(
                    frame_index=frame_idx,
                    time_seconds=round(time_s, 3),
                    detections=dets,
                ))
            frame_idx += 1

        cap.release()

        class_name = COCO_CLASSES[target_class] if target_class < len(COCO_CLASSES) else 'object'
        keyframes = detections_to_keyframes(detections_per_frame, orig_fps)

        return TrackResult(
            fps=orig_fps,
            total_frames=total_frames,
            tracked_class=class_name,
            detections_per_frame=detections_per_frame,
            keyframes=keyframes,
        )
    finally:
        try:
            os.unlink(video_path)
        except Exception:
            pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
