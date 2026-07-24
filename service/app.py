from __future__ import annotations

import os
import logging
import threading
import time
import uuid
from pathlib import Path
import cv2
import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Seryoga Speedster Video Service", version="0.4.0")
CAPTURE_DIR = Path(os.getenv("CAPTURE_DIR", "captures"))
POLL_UPLOAD_URL = "https://media.pollinations.ai/upload"
POLL_CHAT_URL = "https://gen.pollinations.ai/v1/chat/completions"
_analysis_guard = threading.BoundedSemaphore(value=1)
logger = logging.getLogger("uvicorn.error")

PROMPT = """
Analyze the complete video as an action sequence. Answer drinking_detected=true only
when a person visibly brings the opening or spout of a bottle, can, cup, or canister
to their mouth and holds or tilts it as if drinking. The container may be opaque and
actual swallowing does not need to be visible. Otherwise answer false. Return the
following JSON object only:
{"drinking_detected": boolean, "confidence": number from 0 to 1, "reason": string}
Keep reason under 160 characters.
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
      <div class="tile"><div class="label">Pollinations API</div><div class="value" id="provider">—</div></div>
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
async function refresh(){try{let r=await fetch('/health');health=await r.json();$('service').innerHTML='<span class="pulse"></span>Online';$('provider').textContent=health.pollinations_configured?'Configured · '+health.pollinations_model:'Missing key';$('camera').textContent='Index '+health.camera_index;$('mode').textContent=health.dry_run?'DRY RUN':'LIVE CAPABLE';$('mode').className='mode '+(health.dry_run?'dry':'live');$('live').disabled=!health.pollinations_configured||health.dry_run;$('hint').textContent=health.dry_run?'Global DRY_RUN is enabled. Live requests are locked out.':health.pollinations_configured?'The local clip is deleted after analysis; Pollinations retains the unlisted upload under its media policy.':'Add POLL_API_KEY to enable live analysis.'}catch(e){$('service').textContent='Offline';$('live').disabled=true;$('mode').textContent='OFFLINE';}}
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


def _pollinations_client(api_key: str) -> httpx.Client:
    request_timeout = _env_float("POLL_REQUEST_TIMEOUT_SECONDS", 75, 5, 180)
    return httpx.Client(
        headers={"Authorization": f"Bearer {api_key}"},
        timeout=httpx.Timeout(request_timeout, connect=15),
        follow_redirects=True,
    )


def _response_content(payload: dict[str, object]) -> str:
    try:
        content = payload["choices"][0]["message"]["content"]  # type: ignore[index]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError("Pollinations returned an invalid chat response") from exc
    if isinstance(content, str):
        cleaned = content.strip()
        if cleaned.startswith("```") and cleaned.endswith("```"):
            cleaned = cleaned.removeprefix("```json").removeprefix("```")
            cleaned = cleaned.removesuffix("```").strip()
        return cleaned
    raise RuntimeError("Pollinations returned non-text analysis content")


def _analyze_video(video_path: Path) -> DrinkAnalysis:
    api_key = os.getenv("POLL_API_KEY")
    if not api_key:
        raise RuntimeError("POLL_API_KEY is missing from .env")

    with _pollinations_client(api_key) as client:
        with video_path.open("rb") as video:
            upload_response = client.post(
                POLL_UPLOAD_URL,
                files={"file": (video_path.name, video, "video/mp4")},
            )
        upload_response.raise_for_status()
        uploaded_url = str(upload_response.json().get("url", ""))
        if not uploaded_url.startswith("https://media.pollinations.ai/"):
            raise RuntimeError("Pollinations upload returned no usable media URL")

        analysis_response = client.post(
            POLL_CHAT_URL,
            json={
                "model": os.getenv("POLL_MODEL", "gemini-3-flash"),
                "messages": [{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": PROMPT},
                        {"type": "video_url", "video_url": {"url": uploaded_url}},
                    ],
                }],
                "temperature": 0,
                "max_tokens": 300,
                "tools": [],
                "response_format": {"type": "json_object"},
            },
        )
        analysis_response.raise_for_status()
        return DrinkAnalysis.model_validate_json(
            _response_content(analysis_response.json())
        )


def _dry_run_enabled(requested: bool) -> bool:
    return requested or os.getenv("DRY_RUN", "").lower() in {"1", "true", "yes"}


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def control_panel() -> HTMLResponse:
    return HTMLResponse(CONTROL_PANEL)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "pollinations_configured": bool(os.getenv("POLL_API_KEY")),
        "pollinations_model": os.getenv("POLL_MODEL", "gemini-3-flash"),
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
        stage = "Pollinations Gemini video analysis"
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
