from __future__ import annotations

import json
import os
import time
from pathlib import Path

import cv2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from google import genai
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Serega Racing Video Service", version="0.1.0")

CAPTURE_DIR = Path("captures")
PROMPT = """
Analyze this entire webcam video as a short action sequence. Determine whether the
person performs a drinking action: bringing a container to their mouth, holding or
tilting it as if drinking, and moving it away. Also identify the visible container
and liquid colors. If the liquid is not clearly visible, use the dominant body color
of the container. If neither is reliable, select unknown. Do not claim that liquid
was swallowed; only classify the visible action. Return only the requested schema.
""".strip()


class DrinkAnalysis(BaseModel):
    drinking_detected: bool
    container_type: str = "unknown"
    container_color: str = "unknown"
    liquid_color: str = "unknown"
    selected_color: str = "unknown"
    confidence: float = Field(ge=0, le=1)
    reason: str


def _record_clip(output_path: Path, seconds: float, camera_index: int) -> None:
    capture = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    if not capture.isOpened():
        raise RuntimeError(f"Could not open camera index {camera_index}")

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)) or 1280
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)) or 720
    fps = capture.get(cv2.CAP_PROP_FPS)
    if not 5 <= fps <= 60:
        fps = 20.0

    writer = cv2.VideoWriter(
        str(output_path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
    )
    if not writer.isOpened():
        capture.release()
        raise RuntimeError("Could not initialize MP4 video writer")

    deadline = time.monotonic() + seconds
    try:
        while time.monotonic() < deadline:
            ok, frame = capture.read()
            if ok:
                writer.write(frame)
    finally:
        writer.release()
        capture.release()


def _analyze_video(video_path: Path) -> DrinkAnalysis:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is missing from .env")

    client = genai.Client(api_key=api_key)
    uploaded = client.files.upload(file=video_path)

    while uploaded.state and uploaded.state.name == "PROCESSING":
        time.sleep(1)
        uploaded = client.files.get(name=uploaded.name)

    if uploaded.state and uploaded.state.name == "FAILED":
        raise RuntimeError("Gemini failed to process the recorded video")

    response = client.models.generate_content(
        model=os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
        contents=[uploaded, PROMPT],
        config={
            "response_mime_type": "application/json",
            "response_schema": DrinkAnalysis,
        },
    )
    if not response.text:
        raise RuntimeError("Gemini returned an empty response")
    return DrinkAnalysis.model_validate(json.loads(response.text))


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "gemini_configured": bool(os.getenv("GEMINI_API_KEY")),
        "camera_index": int(os.getenv("CAMERA_INDEX", "0")),
    }


@app.post("/analyze-drink", response_model=DrinkAnalysis)
def analyze_drink() -> DrinkAnalysis:
    CAPTURE_DIR.mkdir(exist_ok=True)
    video_path = CAPTURE_DIR / f"drink-{int(time.time())}.mp4"
    try:
        _record_clip(
            video_path,
            float(os.getenv("CAPTURE_SECONDS", "5")),
            int(os.getenv("CAMERA_INDEX", "0")),
        )
        return _analyze_video(video_path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        video_path.unlink(missing_ok=True)

