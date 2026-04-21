# ai_modules/whisper_service/main.py
# Auto-captions microservice using OpenAI Whisper with word-level timestamps

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import tempfile
import os
import asyncio
import uuid
import logging
from typing import Optional
import torch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Whisper Caption Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Model Loading ──────────────────────────────────────────────────────────────

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Using device: {DEVICE}")

models: dict = {}

def get_model(size: str = "small"):
    if size not in models:
        logger.info(f"Loading Whisper {size} model...")
        models[size] = whisper.load_model(size, device=DEVICE)
        logger.info(f"Whisper {size} loaded.")
    return models[size]

# Pre-load small model on startup
@app.on_event("startup")
async def startup_event():
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, get_model, "small")

# ── Models ────────────────────────────────────────────────────────────────────

class Word(BaseModel):
    word: str
    start: float
    end: float
    probability: float

class Segment(BaseModel):
    id: int
    text: str
    start: float
    end: float
    words: list[Word]

class TranscriptionResult(BaseModel):
    job_id: str
    language: str
    duration: float
    segments: list[Segment]
    full_text: str

class TranscriptionJob(BaseModel):
    job_id: str
    status: str  # pending | processing | done | error
    result: Optional[TranscriptionResult] = None
    error: Optional[str] = None

# In-memory job store (use Redis in production)
jobs: dict[str, TranscriptionJob] = {}

# ── Helpers ───────────────────────────────────────────────────────────────────

async def extract_audio(video_path: str, output_path: str):
    """Placeholder for audio extraction (Native Engine should handle this)."""
    # Previously used FFmpeg, now expecting audio files or native extraction
    if not video_path.endswith('.wav'):
        logger.warning(f"File {video_path} might not be a supported audio format without FFmpeg.")

def _transcribe_sync(audio_path: str, model_size: str, language: Optional[str]) -> dict:
    model = get_model(model_size)
    options = {
        "word_timestamps": True,
        "verbose": False,
        "fp16": DEVICE == "cuda",
    }
    if language:
        options["language"] = language

    result = model.transcribe(audio_path, **options)
    return result

def _build_segments(raw_result: dict) -> list[Segment]:
    segments = []
    for i, seg in enumerate(raw_result.get("segments", [])):
        words = []
        for w in seg.get("words", []):
            words.append(Word(
                word=w["word"].strip(),
                start=round(w["start"], 3),
                end=round(w["end"], 3),
                probability=round(w.get("probability", 1.0), 4),
            ))
        segments.append(Segment(
            id=i,
            text=seg["text"].strip(),
            start=round(seg["start"], 3),
            end=round(seg["end"], 3),
            words=words,
        ))
    return segments

async def process_transcription(job_id: str, audio_path: str, model_size: str, language: Optional[str]):
    try:
        jobs[job_id].status = "processing"
        loop = asyncio.get_event_loop()
        raw = await loop.run_in_executor(None, _transcribe_sync, audio_path, model_size, language)

        segments = _build_segments(raw)
        full_text = " ".join(s.text for s in segments)

        # Estimate duration from last segment
        duration = segments[-1].end if segments else 0.0

        jobs[job_id].status = "done"
        jobs[job_id].result = TranscriptionResult(
            job_id=job_id,
            language=raw.get("language", "en"),
            duration=duration,
            segments=segments,
            full_text=full_text,
        )
    except Exception as e:
        logger.exception(f"Transcription failed for job {job_id}")
        jobs[job_id].status = "error"
        jobs[job_id].error = str(e)
    finally:
        # Cleanup temp files
        try:
            os.unlink(audio_path)
        except Exception:
            pass

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "device": DEVICE, "models_loaded": list(models.keys())}

@app.post("/transcribe", response_model=TranscriptionJob)
async def transcribe(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    model_size: str = "small",   # tiny | base | small | medium | large
    language: Optional[str] = None,
):
    """
    Upload a video or audio file, returns a job_id.
    Poll /status/{job_id} for results.
    """
    if model_size not in ["tiny", "base", "small", "medium", "large"]:
        raise HTTPException(status_code=400, detail="Invalid model_size")

    job_id = str(uuid.uuid4())

    # Save uploaded file to temp
    suffix = os.path.splitext(file.filename or "upload.mp4")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        upload_path = tmp.name

    # Extract audio if it's a video
    audio_path = upload_path
    is_video = suffix.lower() in [".mp4", ".mov", ".avi", ".mkv", ".webm"]
    if is_video:
        audio_path = upload_path.replace(suffix, ".wav")
        try:
            await extract_audio(upload_path, audio_path)
        except Exception as e:
            os.unlink(upload_path)
            raise HTTPException(status_code=422, detail=f"Audio extraction failed: {e}")
        finally:
            os.unlink(upload_path)

    # Create job
    job = TranscriptionJob(job_id=job_id, status="pending")
    jobs[job_id] = job

    # Process in background
    background_tasks.add_task(process_transcription, job_id, audio_path, model_size, language)

    return job

@app.get("/status/{job_id}", response_model=TranscriptionJob)
async def get_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    return jobs[job_id]

@app.post("/transcribe/sync", response_model=TranscriptionResult)
async def transcribe_sync(
    file: UploadFile = File(...),
    model_size: str = "tiny",
    language: Optional[str] = None,
):
    """Synchronous transcription (for small files only, use tiny model)."""
    suffix = os.path.splitext(file.filename or "upload.mp4")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        upload_path = tmp.name

    audio_path = upload_path
    is_video = suffix.lower() in [".mp4", ".mov", ".avi", ".mkv", ".webm"]
    if is_video:
        audio_path = upload_path.replace(suffix, ".wav")
        try:
            await extract_audio(upload_path, audio_path)
        except Exception as e:
            os.unlink(upload_path)
            raise HTTPException(status_code=422, detail=str(e))
        finally:
            os.unlink(upload_path)

    try:
        loop = asyncio.get_event_loop()
        raw = await loop.run_in_executor(None, _transcribe_sync, audio_path, model_size, language)
        segments = _build_segments(raw)
        full_text = " ".join(s.text for s in segments)
        duration = segments[-1].end if segments else 0.0
        return TranscriptionResult(
            job_id=str(uuid.uuid4()),
            language=raw.get("language", "en"),
            duration=duration,
            segments=segments,
            full_text=full_text,
        )
    finally:
        try:
            os.unlink(audio_path)
        except Exception:
            pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001, workers=1)
