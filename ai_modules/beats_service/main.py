# ai_modules/beats_service/main.py
# Beat detection microservice using Microsoft BEATs model via ONNX Runtime

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import librosa
import onnxruntime as ort
import tempfile, os, asyncio, logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Beat Detection Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

MODEL_PATH = os.environ.get("BEATS_MODEL_PATH", "beats.onnx")
SAMPLE_RATE = 16000

session: ort.InferenceSession = None

@app.on_event("startup")
async def load_model():
    global session
    providers = ['CUDAExecutionProvider', 'CPUExecutionProvider'] \
        if 'CUDAExecutionProvider' in ort.get_available_providers() \
        else ['CPUExecutionProvider']
    try:
        session = ort.InferenceSession(MODEL_PATH, providers=providers)
        logger.info("BEATs model loaded.")
    except Exception as e:
        logger.warning(f"BEATs ONNX not found ({e}), will use librosa fallback.")

# ── Models ────────────────────────────────────────────────────────────────────

class BeatResult(BaseModel):
    bpm: float
    beat_times: list[float]       # seconds
    downbeat_times: list[float]   # every 4th beat (bar markers)
    bar_count: int
    duration_seconds: float
    # Ready-to-use keyframes for Flutter timeline snap
    timeline_markers: list[dict]

# ── Audio Loading ──────────────────────────────────────────────────────────────

def load_audio(path: str) -> tuple[np.ndarray, float]:
    """Load audio as 16kHz mono float32."""
    y, sr = librosa.load(path, sr=SAMPLE_RATE, mono=True)
    duration = len(y) / SAMPLE_RATE
    return y, duration

# ── Beat Detection ─────────────────────────────────────────────────────────────

def detect_beats_librosa(y: np.ndarray) -> tuple[float, np.ndarray]:
    """Fallback: use librosa's beat tracker."""
    tempo, beats = librosa.beat.beat_track(y=y, sr=SAMPLE_RATE, units='time')
    return float(tempo), beats.astype(float)

def detect_beats_onnx(y: np.ndarray) -> tuple[float, np.ndarray]:
    """Primary: BEATs ONNX model — process mel spectrogram."""
    # Compute mel spectrogram as input
    mel = librosa.feature.melspectrogram(
        y=y, sr=SAMPLE_RATE, n_mels=128, fmax=8000,
        n_fft=1024, hop_length=512
    )
    mel_db = librosa.power_to_db(mel, ref=np.max)
    mel_norm = (mel_db - mel_db.mean()) / (mel_db.std() + 1e-8)
    inp = mel_norm[np.newaxis, np.newaxis].astype(np.float32)  # (1, 1, 128, T)

    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: inp})

    # Model outputs beat probability per frame → threshold and convert to times
    beat_probs = outputs[0].squeeze()
    hop_time = 512 / SAMPLE_RATE
    beat_indices = np.where(beat_probs > 0.5)[0]
    beat_times = beat_indices * hop_time

    # Estimate BPM from inter-beat intervals
    if len(beat_times) > 1:
        ibi = np.diff(beat_times)
        bpm = 60.0 / np.median(ibi)
    else:
        bpm = 120.0

    return float(bpm), beat_times

def compute_downbeats(beat_times: np.ndarray, bpm: float) -> np.ndarray:
    """Estimate downbeats (every 4 beats = one bar)."""
    if len(beat_times) < 4:
        return beat_times
    # Group beats into bars of 4
    downbeats = beat_times[::4]
    return downbeats

def beats_to_timeline_markers(
    beat_times: np.ndarray,
    downbeat_times: np.ndarray,
    bpm: float
) -> list[dict]:
    """
    Convert beats to Flutter timeline marker format.
    Each marker has: time, type ('beat'|'downbeat'|'bar'), label
    """
    downbeat_set = set(round(t, 3) for t in downbeat_times)
    markers = []
    bar_num = 1
    beat_in_bar = 1

    for t in beat_times:
        t_r = round(float(t), 3)
        is_downbeat = t_r in downbeat_set

        if is_downbeat:
            marker_type = 'downbeat'
            label = f'Bar {bar_num}'
            bar_num += 1
            beat_in_bar = 1
        else:
            marker_type = 'beat'
            label = f'{beat_in_bar}'
            beat_in_bar = (beat_in_bar % 4) + 1

        markers.append({
            'time': t_r,
            'type': marker_type,
            'label': label,
            'bpm': round(bpm, 1),
        })

    return markers

# ── Processing Pipeline ───────────────────────────────────────────────────────

def process_audio(audio_path: str) -> BeatResult:
    y, duration = load_audio(audio_path)

    # Use ONNX if available, else librosa
    try:
        if session is not None:
            bpm, beat_times = detect_beats_onnx(y)
        else:
            bpm, beat_times = detect_beats_librosa(y)
    except Exception as e:
        logger.warning(f"ONNX beat detection failed ({e}), using librosa fallback.")
        bpm, beat_times = detect_beats_librosa(y)

    # Clamp BPM to sane range
    bpm = max(40.0, min(240.0, bpm))

    downbeat_times = compute_downbeats(beat_times, bpm)
    markers = beats_to_timeline_markers(beat_times, downbeat_times, bpm)

    return BeatResult(
        bpm=round(bpm, 2),
        beat_times=[round(float(t), 3) for t in beat_times],
        downbeat_times=[round(float(t), 3) for t in downbeat_times],
        bar_count=len(downbeat_times),
        duration_seconds=round(duration, 3),
        timeline_markers=markers,
    )

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model_loaded": session is not None,
        "backend": "onnx" if session else "librosa"
    }

@app.post("/detect", response_model=BeatResult)
async def detect_beats(file: UploadFile = File(...)):
    """
    Upload an audio or video file.
    Returns BPM, beat timestamps, downbeat timestamps,
    and ready-to-use Flutter timeline markers.
    """
    suffix = os.path.splitext(file.filename or "audio.mp3")[1].lower()
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        input_path = tmp.name

    # If video, handle audio extraction via Native Engine in production
    audio_path = input_path
    if suffix in [".mp4", ".mov", ".avi", ".mkv", ".webm"]:
        logger.warning("Video input received. Ensure audio is extracted via Native Engine before calling AI.")
        # Previously used FFmpeg to extract audio here

    try:
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, process_audio, audio_path)
        return result
    except Exception as e:
        logger.exception("Beat detection error")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            os.unlink(audio_path)
        except Exception:
            pass

@app.post("/bpm")
async def get_bpm_only(file: UploadFile = File(...)):
    """Quick BPM-only detection (faster, no full beat analysis)."""
    suffix = os.path.splitext(file.filename or "audio.mp3")[1].lower()
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        path = tmp.name
    try:
        loop = asyncio.get_event_loop()
        y, duration = await loop.run_in_executor(None, load_audio, path)
        tempo, _ = await loop.run_in_executor(None, librosa.beat.beat_track, y, SAMPLE_RATE)
        return {"bpm": round(float(tempo), 2), "duration_seconds": round(duration, 2)}
    finally:
        try:
            os.unlink(path)
        except Exception:
            pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)
