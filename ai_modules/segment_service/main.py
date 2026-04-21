# ai_modules/segment_service/main.py
# Smart Cutout microservice using Segment Anything Model (SAM) via ONNX Runtime

from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import cv2
import onnxruntime as ort
import tempfile, os, json, logging
from typing import List, Optional
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SAM Smart Cutout Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── Configuration ─────────────────────────────────────────────────────────────

# SAM has two parts: Image Encoder (heavy) and Mask Decoder (light)
# Usually, we pre-compute image embeddings once per image.
ENCODER_MODEL_PATH = os.environ.get("SAM_ENCODER_MODEL", "sam_vit_b_encoder.onnx")
DECODER_MODEL_PATH = os.environ.get("SAM_DECODER_MODEL", "sam_vit_b_decoder.onnx")

encoder_session: ort.InferenceSession = None
decoder_session: ort.InferenceSession = None

@app.on_event("startup")
async def load_models():
    global encoder_session, decoder_session
    providers = ['CUDAExecutionProvider', 'CPUExecutionProvider'] if 'CUDAExecutionProvider' in ort.get_available_providers() else ['CPUExecutionProvider']
    try:
        if os.path.exists(ENCODER_MODEL_PATH):
            encoder_session = ort.InferenceSession(ENCODER_MODEL_PATH, providers=providers)
            logger.info(f"SAM Encoder loaded: {ENCODER_MODEL_PATH}")
        if os.path.exists(DECODER_MODEL_PATH):
            decoder_session = ort.InferenceSession(DECODER_MODEL_PATH, providers=providers)
            logger.info(f"SAM Decoder loaded: {DECODER_MODEL_PATH}")
    except Exception as e:
        logger.error(f"Failed to load SAM models: {e}")

# ── Models ────────────────────────────────────────────────────────────────────

class Point(BaseModel):
    x: float  # normalized 0-1
    y: float
    label: int = 1  # 1 for foreground, 0 for background

class CutoutRequest(BaseModel):
    points: List[Point]

# ── Core Logic ───────────────────────────────────────────────────────────────

def preprocess_image(img_bgr: np.ndarray) -> np.ndarray:
    """Prepare image for SAM encoder (1024x1024)."""
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    # SAM expects 1024x1024
    img_1024 = cv2.resize(img_rgb, (1024, 1024))
    img_f = img_1024.astype(np.float32)
    # Normalize with mean/std (COCO/ImageNet style as expected by SAM)
    mean = np.array([123.675, 116.28, 103.53], dtype=np.float32)
    std = np.array([58.395, 57.12, 57.375], dtype=np.float32)
    img_norm = (img_f - mean) / std
    # HWC -> CHW -> NCHW
    return np.transpose(img_norm, (2, 0, 1))[np.newaxis]

def get_image_embedding(img_bgr: np.ndarray):
    """Run encoder to get 256x64x64 embedding."""
    if encoder_session is None:
        # Fallback/Mock for development if model missing
        return np.zeros((1, 256, 64, 64), dtype=np.float32)

    inp = preprocess_image(img_bgr)
    outputs = encoder_session.run(None, {encoder_session.get_inputs()[0].name: inp})
    return outputs[0]

def run_decoder(embedding: np.ndarray, points: List[Point], orig_size: tuple):
    """Run decoder to get mask from points and embedding."""
    if decoder_session is None:
        # Mock mask (circle around first point)
        h, w = orig_size
        mask = np.zeros((h, w), dtype=np.uint8)
        if points:
            cx, cy = int(points[0].x * w), int(points[0].y * h)
            cv2.circle(mask, (cx, cy), 100, 255, -1)
        return mask

    h, w = orig_size
    # SAM decoder inputs:
    # image_embeddings: [1, 256, 64, 64]
    # point_coords: [1, N, 2] (coordinates in 1024x1024 scale)
    # point_labels: [1, N]
    # mask_input: [1, 1, 256, 256] (zeros)
    # has_mask_input: [1] (0)
    # orig_im_size: [2] (float32 [h, w])

    coords = np.array([[[p.x * 1024, p.y * 1024] for p in points]], dtype=np.float32)
    labels = np.array([[p.label for p in points]], dtype=np.float32)
    mask_input = np.zeros((1, 1, 256, 256), dtype=np.float32)
    has_mask_input = np.array([0], dtype=np.float32)

    inputs = {
        "image_embeddings": embedding,
        "point_coords": coords,
        "point_labels": labels,
        "mask_input": mask_input,
        "has_mask_input": has_mask_input,
        "orig_im_size": np.array([h, w], dtype=np.float32)
    }

    outputs = decoder_session.run(None, inputs)
    # SAM usually returns 3 masks + scores, we take the best one
    masks, scores = outputs[0], outputs[1]
    best_idx = np.argmax(scores[0])
    mask = masks[0, best_idx] > 0 # Threshold at 0 for logits

    return (mask.astype(np.uint8) * 255)

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "encoder_loaded": encoder_session is not None,
        "decoder_loaded": decoder_session is not None
    }

@app.post("/smart-cutout")
async def smart_cutout(
    file: UploadFile = File(...),
    points_json: str = Form(...), # JSON string of points
):
    """
    Extract object based on prompt points.
    Returns PNG with transparency.
    """
    try:
        points_data = json.loads(points_json)
        points = [Point(**p) for p in points_data]
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid points JSON: {e}")

    content = await file.read()
    nparr = np.frombuffer(content, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise HTTPException(status_code=422, detail="Invalid image")

    h, w = img_bgr.shape[:2]

    # 1. Get embedding (usually this would be cached in a real app)
    embedding = get_image_embedding(img_bgr)

    # 2. Run decoder with points
    mask = run_decoder(embedding, points, (h, w))

    # 3. Create RGBA output
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    rgba = np.dstack([img_rgb, mask])

    _, buf = cv2.imencode(".png", cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA))
    return Response(content=buf.tobytes(), media_type="image/png")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8006)
