# ai_modules/rmbg_service/main.py
# Background removal microservice using BRIA-RMBG-1.4

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import cv2
import onnxruntime as ort
import tempfile
import os
import io
import asyncio
import logging
from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Background Removal Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── Model ─────────────────────────────────────────────────────────────────────

MODEL_PATH = os.environ.get("RMBG_MODEL_PATH", "rmbg.onnx")
INPUT_SIZE = 1024

session: ort.InferenceSession = None

@app.on_event("startup")
async def load_model():
    global session
    providers = []
    if "CoreMLExecutionProvider" in ort.get_available_providers():
        providers.append("CoreMLExecutionProvider")
    elif "CUDAExecutionProvider" in ort.get_available_providers():
        providers.append("CUDAExecutionProvider")
    providers.append("CPUExecutionProvider")

    try:
        session = ort.InferenceSession(MODEL_PATH, providers=providers)
        logger.info(f"RMBG model loaded with providers: {providers}")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")

# ── Core Processing ───────────────────────────────────────────────────────────

def preprocess_image(img: np.ndarray) -> tuple[np.ndarray, tuple]:
    """Resize, normalize, and prepare image for ONNX inference."""
    original_size = img.shape[:2]  # (H, W)
    img_resized = cv2.resize(img, (INPUT_SIZE, INPUT_SIZE))
    img_float = img_resized.astype(np.float32) / 255.0

    # Normalize with ImageNet mean/std
    mean = np.array([0.5, 0.5, 0.5], dtype=np.float32)
    std = np.array([1.0, 1.0, 1.0], dtype=np.float32)
    img_norm = (img_float - mean) / std

    # HWC → CHW → NCHW
    img_chw = np.transpose(img_norm, (2, 0, 1))
    img_nchw = np.expand_dims(img_chw, axis=0)
    return img_nchw, original_size

def postprocess_mask(mask: np.ndarray, original_size: tuple) -> np.ndarray:
    """Convert model output to alpha mask at original resolution."""
    mask = mask.squeeze()  # Remove batch and channel dims
    mask = (mask - mask.min()) / (mask.max() - mask.min() + 1e-8)  # Normalize 0-1
    mask_resized = cv2.resize(mask, (original_size[1], original_size[0]))
    mask_uint8 = (mask_resized * 255).astype(np.uint8)
    # Refine edges
    mask_uint8 = cv2.GaussianBlur(mask_uint8, (3, 3), 0)
    _, mask_uint8 = cv2.threshold(mask_uint8, 10, 255, cv2.THRESH_BINARY)
    return mask_uint8

def apply_alpha_matte(img_rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Combine RGB + alpha to RGBA."""
    rgba = np.dstack([img_rgb, alpha])
    return rgba

def remove_background_from_image(img_rgb: np.ndarray) -> np.ndarray:
    """Full pipeline: RGB → RGBA with background removed."""
    if session is None:
        raise RuntimeError("Model not loaded")
    inp, original_size = preprocess_image(img_rgb)
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: inp})
    alpha = postprocess_mask(outputs[0], original_size)
    return apply_alpha_matte(img_rgb, alpha)

# ── Video Processing ──────────────────────────────────────────────────────────

def process_video_frames(
    input_path: str,
    output_path: str,
    process_fps: int = 15,
    bg_color: tuple = (0, 177, 64, 255),  # Green screen by default
    replace_with_color: bool = False,
):
    """Remove background from video, outputting with alpha or color replacement."""
    cap = cv2.VideoCapture(input_path)
    orig_fps = cap.get(cv2.CAP_PROP_FPS) or 30
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, orig_fps, (width, height))

    frame_skip = max(1, round(orig_fps / process_fps))
    frame_count = 0
    prev_mask = None

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_count % frame_skip == 0:
            # Process this frame
            img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            rgba = remove_background_from_image(img_rgb)
            alpha = rgba[:, :, 3]
            prev_mask = alpha
        else:
            # Interpolate mask from previous
            alpha = prev_mask if prev_mask is not None else np.zeros((height, width), np.uint8)

        if replace_with_color:
            # Composite over solid color
            bg = np.full_like(frame, bg_color[:3][::-1])  # BGR
            alpha_3ch = cv2.cvtColor(alpha, cv2.COLOR_GRAY2BGR).astype(float) / 255.0
            result = (frame.astype(float) * alpha_3ch + bg.astype(float) * (1 - alpha_3ch)).astype(np.uint8)
        else:
            # Just output with white bg for preview
            result = frame.copy()
            result[alpha < 128] = [255, 255, 255]

        out.write(result)
        frame_count += 1

    cap.release()
    out.release()

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": session is not None}

@app.post("/remove-bg/image")
async def remove_bg_image(
    file: UploadFile = File(...),
    output_format: str = "png",  # png (with alpha) | jpeg (white bg)
):
    """Remove background from a single image."""
    content = await file.read()
    nparr = np.frombuffer(content, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise HTTPException(status_code=422, detail="Could not decode image")

    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    loop = asyncio.get_event_loop()
    rgba = await loop.run_in_executor(None, remove_background_from_image, img_rgb)

    pil_img = Image.fromarray(rgba, 'RGBA')
    buf = io.BytesIO()

    if output_format == "jpeg":
        # White background
        bg = Image.new('RGB', pil_img.size, (255, 255, 255))
        bg.paste(pil_img, mask=pil_img.split()[3])
        bg.save(buf, format='JPEG', quality=90)
        return Response(content=buf.getvalue(), media_type="image/jpeg")
    else:
        pil_img.save(buf, format='PNG')
        return Response(content=buf.getvalue(), media_type="image/png")

@app.post("/remove-bg/video")
async def remove_bg_video(
    file: UploadFile = File(...),
    process_fps: int = 15,
    replace_with_green: bool = True,
):
    """Remove background from video frames."""
    suffix = os.path.splitext(file.filename or "video.mp4")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        input_path = tmp.name

    output_path = input_path.replace(suffix, "_nobg.mp4")

    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(
            None,
            process_video_frames,
            input_path, output_path, process_fps,
            (0, 177, 64, 255), replace_with_green,
        )
        with open(output_path, "rb") as f:
            video_bytes = f.read()
        return Response(content=video_bytes, media_type="video/mp4")
    finally:
        for p in [input_path, output_path]:
            try:
                os.unlink(p)
            except Exception:
                pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
