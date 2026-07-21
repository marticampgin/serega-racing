from __future__ import annotations

import os
import logging
import threading
import time
import uuid
from pathlib import Path
import cv2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse
from google import genai
from google.genai import types
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Seryoga Speedster Video Service", version="0.3.0")
CAPTURE_DIR = Path(os.getenv("CAPTURE_DIR", "captures"))
_analysis_guard = threading.BoundedSemaphore(value=1)
logger = logging.getLogger("uvicorn.error")

PROMPT = """
Analyze the complete video as an action sequence. Answer drinking_detected=true only
when a person visibly brings the opening or spout of a bottle, can, cup, or canister
to their mouth and holds or tilts it as if drinking. The container may be opaque and
actual swallowing does not need to be visible. Otherwise answer false. Return the
schema only and keep reason under 160 characters.
""".strip()


class DrinkAnalysis(BaseModel):
    drinking_detected: bool
    confidence: float = Field(ge=0, le=1)
    reason: str = Field(max_length=200)


MOCK_RESULT = DrinkAnalysis(
    drinking_detected=True,
    confidence=0.95,
    reason="Dry-run drinking gesture with a canister.",
)

CONTROL_PANEL = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Серёга Speedster · Fuel Lab</title>
  <style>
    :root{color-scheme:dark;--ink:#f4f5f7;--muted:#999fa9;--line:#2b3038;--red:#ff3b30;--green:#40e07c}
    *{box-sizing:border-box} body{margin:0;min-height:100vh;font:15px/1.5 Inter,ui-sans-serif,system-ui,sans-serif;color:var(--ink);background:#090a0c;display:grid;place-items:center;padding:28px}
    body:before{content:"";position:fixed;inset:0;pointer-events:none;background:radial-gradient(circle at 70% 0,#39100d 0,transparent 34%),linear-gradient(120deg,transparent 50%,#11151a 50%)}
    main{position:relative;width:min(760px,100%);background:#111318eF;border:1px solid var(--line);border-radius:22px;box-shadow:0 30px 80px #0009;overflow:hidden}
    header{padding:27px 30px 24px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:20px;align-items:center}
    .eyebrow{color:var(--red);font-weight:800;letter-spacing:.16em;font-size:11px;text-transform:uppercase}.title{font-size:26px;font-weight:800;letter-spacing:-.035em;margin:3px 0 0}
    .mode{border:1px solid #58433e;background:#251816;border-radius:999px;padding:7px 12px;font-size:12px;font-weight:800;letter-spacing:.08em}.mode.dry{border-color:#325141;background:#10291b;color:#7bf2a4}.mode.live{color:#ff8b82}
    section{padding:26px 30px}.status{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:22px}.tile{border:1px solid var(--line);background:#171a20;border-radius:12px;padding:13px}.label{font-size:10px;text-transform:uppercase;letter-spacing:.12em;color:var(--muted)}.value{font-weight:700;margin-top:3px}
    .actions{display:grid;grid-template-columns:1fr 1fr;gap:12px}button{border:0;border-radius:12px;padding:14px 16px;font:700 14px inherit;cursor:pointer;transition:.15s transform,.15s opacity}button:hover:not(:disabled){transform:translateY(-1px)}button:disabled{cursor:not-allowed;opacity:.45}.primary{background:var(--red);color:white}.secondary{background:#262b33;color:white;border:1px solid #39404a}
    .hint{color:var(--muted);font-size:12px;margin:10px 1px 20px}.output{border:1px solid var(--line);border-radius:13px;background:#090b0e;min-height:178px;overflow:hidden}.output-head{padding:10px 14px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.1em}pre{margin:0;padding:16px;white-space:pre-wrap;word-break:break-word;color:#b9f7cc;font:12px/1.65 ui-monospace,SFMono-Regular,Consolas,monospace}.pulse{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--green);margin-right:6px;box-shadow:0 0 10px var(--green)}
    @media(max-width:580px){header{align-items:flex-start}.status{grid-template-columns:1fr}.actions{grid-template-columns:1fr}section,header{padding-left:20px;padding-right:20px}}
  </style>
</head>
<body><main>
  <header><div><div class="eyebrow">Race engineering</div><h1 class="title">Fuel Recognition Lab</h1></div><div id="mode" class="mode">CHECKING</div></header>
  <section>
    <div class="status">
      <div class="tile"><div class="label">Service</div><div class="value" id="service"><span class="pulse"></span>Connecting</div></div>
      <div class="tile"><div class="label">Gemini API</div><div class="value" id="gemini">—</div></div>
      <div class="tile"><div class="label">Camera</div><div class="value" id="camera">—</div></div>
    </div>
    <div class="actions">
      <button class="secondary" id="dry">Run safe dry test</button>
      <button class="primary" id="live">Record &amp; analyze 5s</button>
    </div>
    <div class="hint" id="hint">Dry test never opens the camera or spends API quota.</div>
    <div class="output"><div class="output-head"><span>Analysis response</span><span id="state">Ready</span></div><pre id="result">Choose a test above.</pre></div>
  </section>
</main><script>
const $=id=>document.getElementById(id), result=$('result'), state=$('state'); let health={};
async function refresh(){try{let r=await fetch('/health');health=await r.json();$('service').innerHTML='<span class="pulse"></span>Online';$('gemini').textContent=health.gemini_configured?'Configured · '+health.gemini_model:'Missing key';$('camera').textContent='Index '+health.camera_index;$('mode').textContent=health.dry_run?'DRY RUN':'LIVE CAPABLE';$('mode').className='mode '+(health.dry_run?'dry':'live');$('live').disabled=!health.gemini_configured||health.dry_run;$('hint').textContent=health.dry_run?'Global DRY_RUN is enabled. Live requests are locked out.':health.gemini_configured?'Live mode records the camera, uploads one clip, then deletes it.':'Add GEMINI_API_KEY to enable live analysis.'}catch(e){$('service').textContent='Offline';$('live').disabled=true;$('mode').textContent='OFFLINE';}}
async function run(dry){document.querySelectorAll('button').forEach(b=>b.disabled=true);state.textContent=dry?'Dry test':'Recording / analyzing';result.textContent=dry?'Generating mock result…':'Camera recording starts now. Drink naturally…';try{let r=await fetch('/analyze-drink'+(dry?'?dry_run=true':''),{method:'POST'}),data=await r.json();if(!r.ok)throw Error(data.detail||'Request failed');result.textContent=JSON.stringify(data,null,2);state.textContent='Complete'}catch(e){result.textContent=JSON.stringify({error:e.message},null,2);state.textContent='Failed'}finally{await refresh();$('dry').disabled=false}}
$('dry').onclick=()=>run(true);$('live').onclick=()=>run(false);refresh();
  </script></body></html>"""


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
            model=os.getenv("GEMINI_MODEL", "gemini-3.5-flash"),
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


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def control_panel() -> HTMLResponse:
    return HTMLResponse(CONTROL_PANEL)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "gemini_configured": bool(os.getenv("GEMINI_API_KEY")),
        "gemini_model": os.getenv("GEMINI_MODEL", "gemini-3.5-flash"),
        "camera_index": int(os.getenv("CAMERA_INDEX", "0")),
        "dry_run": _dry_run_enabled(False),
        "busy": _analysis_guard._value == 0,
    }


@app.post("/analyze-drink", response_model=DrinkAnalysis)
def analyze_drink(dry_run: bool = Query(False)) -> DrinkAnalysis:
    if not _analysis_guard.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="Drink analysis already in progress")
    video_path: Path | None = None
    stage = "initialization"
    try:
        if _dry_run_enabled(dry_run):
            return MOCK_RESULT.model_copy()
        stage = "capture directory setup"
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        video_path = CAPTURE_DIR / f"drink-{uuid.uuid4().hex}.mp4"
        stage = "camera recording"
        _record_clip(
            video_path,
            _env_float("CAPTURE_SECONDS", 5, 1, 15),
            int(os.getenv("CAMERA_INDEX", "0")),
        )
        stage = "Gemini video analysis"
        return _analyze_video(video_path)
    except HTTPException:
        raise
    except TimeoutError as exc:
        detail = f"{stage}: {type(exc).__name__}: {exc}"
        logger.exception("Fueling failed during %s", stage)
        raise HTTPException(status_code=504, detail=detail) from exc
    except Exception as exc:
        detail = f"{stage}: {type(exc).__name__}: {exc}"
        logger.exception("Fueling failed during %s", stage)
        raise HTTPException(status_code=500, detail=detail) from exc
    finally:
        if video_path is not None:
            video_path.unlink(missing_ok=True)
        _analysis_guard.release()
