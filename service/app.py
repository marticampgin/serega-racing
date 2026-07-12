from __future__ import annotations

import os
import threading
import time
import uuid
from pathlib import Path
from typing import Literal

import cv2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from google import genai
from google.genai import types
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Serega Racing Video Service", version="0.2.0")
CAPTURE_DIR = Path(os.getenv("CAPTURE_DIR", "captures"))
_analysis_guard = threading.BoundedSemaphore(value=1)

PROMPT = """
Analyze the complete video as an action sequence. Decide whether the person visibly
performs a drinking gesture: a container approaches the mouth, is held or tilted
there, and then moves away. Identify the visible container and liquid colors. Prefer
the liquid color only when clearly visible; otherwise use the container body color.
Do not infer swallowing or contents hidden by an opaque container. Return the schema
only. Keep reason under 160 characters.
""".strip()


class DrinkAnalysis(BaseModel):
    drinking_detected: bool
    container_type: Literal["bottle", "can", "cup", "glass", "other", "unknown"] = "unknown"
    container_color: str = Field(default="unknown", max_length=32)
    liquid_color: str = Field(default="unknown", max_length=32)
    selected_color: str = Field(default="unknown", max_length=32)
    confidence: float = Field(ge=0, le=1)
    reason: str = Field(max_length=200)


MOCK_RESULT = DrinkAnalysis(
    drinking_detected=True,
    container_type="bottle",
    container_color="blue",
    liquid_color="unknown",
    selected_color="blue",
    confidence=0.95,
    reason="Dry-run drinking gesture with a blue bottle.",
)


def _env_float(name: str, default: float, minimum: float, maximum: float) -> float:
    try:
        value = float(os.getenv(name, str(default)))
    except ValueError as exc:
        raise RuntimeError(f"{name} must be numeric") from exc
    if not minimum <= value <= maximum:
        raise RuntimeError(f"{name} must be between {minimum} and {maximum}")
    return value


def _record_clip(output_path: Path, seconds: float, camera_index: int) -> None:
    capture = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    if not capture.isOpened():
        capture.release()
        raise RuntimeError(f"Could not open camera index {camera_index}")

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)) or 1280
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)) or 720
    fps = capture.get(cv2.CAP_PROP_FPS)
    fps = fps if 5 <= fps <= 60 else 20.0
    writer = cv2.VideoWriter(
        str(output_path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
    )
    if not writer.isOpened():
        capture.release()
        raise RuntimeError("Could not initialize MP4 video writer")

    deadline = time.monotonic() + seconds
    frames = 0
    try:
        while time.monotonic() < deadline:
            ok, frame = capture.read()
            if ok:
                writer.write(frame)
                frames += 1
    finally:
        writer.release()
        capture.release()
    if frames == 0 or not output_path.exists() or output_path.stat().st_size == 0:
        raise RuntimeError("Camera produced no usable video frames")


def _analyze_video(video_path: Path) -> DrinkAnalysis:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is missing from .env")

    request_timeout = int(_env_float("GEMINI_REQUEST_TIMEOUT_SECONDS", 45, 5, 180) * 1000)
    processing_timeout = _env_float("GEMINI_PROCESSING_TIMEOUT_SECONDS", 45, 5, 180)
    client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=request_timeout))
    uploaded = None
    try:
        uploaded = client.files.upload(file=video_path)
        deadline = time.monotonic() + processing_timeout
        while uploaded.state and uploaded.state.name == "PROCESSING":
            if time.monotonic() >= deadline:
                raise TimeoutError("Gemini video processing timed out")
            time.sleep(min(1.0, max(0.05, deadline - time.monotonic())))
            uploaded = client.files.get(name=uploaded.name)
        if uploaded.state and uploaded.state.name == "FAILED":
            raise RuntimeError("Gemini failed to process the recorded video")

        response = client.models.generate_content(
            model=os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
            contents=[uploaded, PROMPT],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=DrinkAnalysis,
                temperature=0,
                max_output_tokens=300,
            ),
        )
        if response.parsed is not None:
            return DrinkAnalysis.model_validate(response.parsed)
        if not response.text:
            raise RuntimeError("Gemini returned an empty response")
        return DrinkAnalysis.model_validate_json(response.text)
    finally:
        if uploaded is not None and uploaded.name:
            try:
                client.files.delete(name=uploaded.name)
            except Exception:
                pass  # Temporary remote files expire; cleanup failure must not hide the result.
        client.close()


def _dry_run_enabled(requested: bool) -> bool:
    return requested or os.getenv("DRY_RUN", "").lower() in {"1", "true", "yes"}


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "gemini_configured": bool(os.getenv("GEMINI_API_KEY")),
        "camera_index": int(os.getenv("CAMERA_INDEX", "0")),
        "dry_run": _dry_run_enabled(False),
        "busy": _analysis_guard._value == 0,
    }


@app.post("/analyze-drink", response_model=DrinkAnalysis)
def analyze_drink(dry_run: bool = Query(False)) -> DrinkAnalysis:
    if not _analysis_guard.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="Drink analysis already in progress")
    video_path: Path | None = None
    try:
        if _dry_run_enabled(dry_run):
            return MOCK_RESULT.model_copy()
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        video_path = CAPTURE_DIR / f"drink-{uuid.uuid4().hex}.mp4"
        _record_clip(
            video_path,
            _env_float("CAPTURE_SECONDS", 5, 1, 15),
            int(os.getenv("CAMERA_INDEX", "0")),
        )
        return _analyze_video(video_path)
    except HTTPException:
        raise
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        if video_path is not None:
            video_path.unlink(missing_ok=True)
        _analysis_guard.release()
