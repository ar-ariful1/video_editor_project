# ai_modules/esrgan_service/main.py
# 4K AI upscaling microservice using Real-ESRGAN via ONNX / GPU

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import cv2
import onnxruntime as ort
import tempfile, os, uuid, asyncio, logging
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Real-ESRGAN 4K Upscaling Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

MODEL_PATH  = os.environ.get("ESRGAN_MODEL_PATH", "realesrgan_x4.onnx")
SCALE       = 4        # 4x upscaling
TILE_SIZE   = 512      # Process in tiles to avoid OOM
TILE_PAD    = 10

session: ort.InferenceSession = None
jobs: dict = {}        # job_id → status/result

# ── Startup ───────────────────────────────────────────────────────────────────

@app.on_event("startup")
async def load_model():
    global session
    providers = []
    for p in ['TensorrtExecutionProvider', 'CUDAExecutionProvider', 'CoreMLExecutionProvider']:
        if p in ort.get_available_providers():
            providers.append(p)
            break
    providers.append('CPUExecutionProvider')
    try:
        opts = ort.SessionOptions()
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        session = ort.InferenceSession(MODEL_PATH, sess_options=opts, providers=providers)
        logger.info(f"Real-ESRGAN loaded with {providers}")
    except Exception as e:
        logger.error(f"Failed to load Real-ESRGAN: {e}")

# ── Core Upscaling ─────────────────────────────────────────────────────────────

def preprocess_tile(tile: np.ndarray) -> np.ndarray:
    """BGR tile → NCHW float32 [0,1]."""
    tile_rgb = cv2.cvtColor(tile, cv2.COLOR_BGR2RGB)
    tile_f   = tile_rgb.astype(np.float32) / 255.0
    return np.transpose(tile_f, (2, 0, 1))[np.newaxis]     # (1, 3, H, W)

def postprocess_tile(output: np.ndarray) -> np.ndarray:
    """NCHW [0,1] → BGR uint8."""
    out = output[0].clip(0, 1)                               # (3, H*4, W*4)
    out = np.transpose(out, (1, 2, 0))                       # HWC
    out = (out * 255).round().astype(np.uint8)
    return cv2.cvtColor(out, cv2.COLOR_RGB2BGR)

def upscale_image_tiled(img: np.ndarray) -> np.ndarray:
    """
    Tile-based upscaling to handle images of any resolution.
    Splits into overlapping tiles, upscales each, stitches back.
    """
    if session is None:
        raise RuntimeError("Model not loaded")

    h, w = img.shape[:2]
    out_h, out_w = h * SCALE, w * SCALE
    output = np.zeros((out_h, out_w, 3), dtype=np.uint8)

    input_name = session.get_inputs()[0].name

    # Iterate tiles
    for y in range(0, h, TILE_SIZE - TILE_PAD * 2):
        for x in range(0, w, TILE_SIZE - TILE_PAD * 2):
            # Extract tile with padding
            x1 = max(0, x - TILE_PAD)
            y1 = max(0, y - TILE_PAD)
            x2 = min(w, x + TILE_SIZE + TILE_PAD)
            y2 = min(h, y + TILE_SIZE + TILE_PAD)

            tile = img[y1:y2, x1:x2]
            inp  = preprocess_tile(tile)
            out  = session.run(None, {input_name: inp})[0]
            tile_out = postprocess_tile(out)

            # Destination in output image (accounting for pad)
            ox1 = (x1 + TILE_PAD if x1 > 0 else 0) * SCALE
            oy1 = (y1 + TILE_PAD if y1 > 0 else 0) * SCALE
            ox2 = min(out_w, ox1 + (x2 - x1 - (TILE_PAD if x1 > 0 else 0)) * SCALE)
            oy2 = min(out_h, oy1 + (y2 - y1 - (TILE_PAD if y1 > 0 else 0)) * SCALE)

            # Source region in upscaled tile
            sx1 = (TILE_PAD if x1 > 0 else 0) * SCALE
            sy1 = (TILE_PAD if y1 > 0 else 0) * SCALE
            sx2 = sx1 + (ox2 - ox1)
            sy2 = sy1 + (oy2 - oy1)

            output[oy1:oy2, ox1:ox2] = tile_out[sy1:sy2, sx1:sx2]

    return output

def upscale_video(input_path: str, output_path: str, job_id: str):
    """Upscale every frame of a video."""
    cap = cv2.VideoCapture(input_path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    w   = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h   = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    out_w, out_h = w * SCALE, h * SCALE
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(output_path, fourcc, fps, (out_w, out_h))

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        upscaled = upscale_image_tiled(frame)
        writer.write(upscaled)
        frame_idx += 1

        # Update job progress
        if job_id in jobs:
            jobs[job_id]['progress'] = round(frame_idx / max(total, 1), 3)

    cap.release()
    writer.release()

# ── Background Job ─────────────────────────────────────────────────────────────

async def run_upscale_job(job_id: str, input_path: str, output_path: str, media_type: str):
    try:
        jobs[job_id]['status'] = 'processing'
        loop = asyncio.get_event_loop()

        if media_type == 'image':
            img = cv2.imread(input_path)
            if img is None:
                raise ValueError("Could not read image")
            result = await loop.run_in_executor(None, upscale_image_tiled, img)
            cv2.imwrite(output_path, result)
        else:
            await loop.run_in_executor(None, upscale_video, input_path, output_path, job_id)

        jobs[job_id]['status']      = 'done'
        jobs[job_id]['output_path'] = output_path
        jobs[job_id]['progress']    = 1.0

    except Exception as e:
        logger.exception(f"Upscale job {job_id} failed")
        jobs[job_id]['status'] = 'error'
        jobs[job_id]['error']  = str(e)
    finally:
        try:
            os.unlink(input_path)
        except Exception:
            pass

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model_loaded": session is not None,
        "scale": SCALE,
        "providers": session.get_providers() if session else [],
    }

@app.post("/upscale/image")
async def upscale_image_sync(
    file: UploadFile = File(...),
    output_format: str = "png",
):
    """Synchronous image upscaling (4x). Returns upscaled image bytes."""
    if session is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    content = await file.read()
    nparr = np.frombuffer(content, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=422, detail="Invalid image")

    # Guard: don't upscale if already large
    h, w = img.shape[:2]
    if w * SCALE > 8192 or h * SCALE > 8192:
        raise HTTPException(status_code=400, detail=f"Output would be {w*SCALE}x{h*SCALE} — too large")

    loop = asyncio.get_event_loop()
    try:
        result = await loop.run_in_executor(None, upscale_image_tiled, img)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    ext = ".png" if output_format == "png" else ".jpg"
    encode_params = [] if ext == ".png" else [cv2.IMWRITE_JPEG_QUALITY, 92]
    _, buf = cv2.imencode(ext, result, encode_params)
    media = "image/png" if ext == ".png" else "image/jpeg"
    return Response(content=buf.tobytes(), media_type=media)

@app.post("/upscale/video/start")
async def upscale_video_start(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    """Start async video upscaling. Poll /upscale/video/status/{job_id}."""
    if session is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    suffix = os.path.splitext(file.filename or "video.mp4")[1]
    job_id = str(uuid.uuid4())

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        input_path = tmp.name

    output_path = input_path.replace(suffix, f"_4k{suffix}")
    jobs[job_id] = {'status': 'pending', 'progress': 0.0, 'output_path': None, 'error': None}

    background_tasks.add_task(run_upscale_job, job_id, input_path, output_path, 'video')
    return {"job_id": job_id, "status": "pending"}

@app.get("/upscale/video/status/{job_id}")
async def upscale_video_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    return jobs[job_id]

@app.get("/upscale/video/download/{job_id}")
async def download_upscaled(job_id: str):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    job = jobs[job_id]
    if job['status'] != 'done':
        raise HTTPException(status_code=400, detail=f"Job not done yet: {job['status']}")
    path = job['output_path']
    if not path or not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Output file not found")
    with open(path, 'rb') as f:
        data = f.read()
    # Cleanup
    try:
        os.unlink(path)
        del jobs[job_id]
    except Exception:
        pass
    return Response(content=data, media_type="video/mp4")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)
