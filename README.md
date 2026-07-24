# Серёга Speedster

A third-person synthwave arcade racing game and birthday gift. Races support two to five laps, a clean time-trial mode, and a randomized obstacle course. The obstacle mode can optionally require refueling by drinking on webcam; Gemini analyzes the complete five-second video and returns a structured yes/no decision.

## Project status

Playable map-driven track prototype:

- Closed 11.9 km Godot 4.7 circuit based on `tools/map template.png`.
- Three real loop/curl sectors, an underwater tunnel, and an elevated bridge.
- Recognizable Party Town, City Centre, Shopping Alley, Sport Complex, coastal
  villas, marinas, and off-track Party Island.
- Obstacles intentionally disabled while track drivability is evaluated.
- Python webcam/Gemini companion service.
- Five-second MP4 capture and native Gemini video upload.
- Structured drinking-gesture decision; successful detection adds 40% fuel without power-up effects.

## Setup

### Python service

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Add your Pollinations secret API key as `POLL_API_KEY` in `.env`, then run:

```powershell
.\start_fueling_service.ps1
```

Check `http://127.0.0.1:8765/health`. To record and analyze a clip, send a POST request to `http://127.0.0.1:8765/analyze-drink`.

The video is evaluated by Pollinations `gemini-3-flash`. The launcher deliberately
uses `.venv\Scripts\python.exe -m uvicorn` instead of a global `uvicorn.exe`,
preventing stale Python-launcher paths from breaking startup.

Set `DRY_RUN=true` in `.env` while developing to return a deterministic blue-bottle result without opening the camera or calling Gemini. Remove it for a real run.

### Godot

Open the repository root in Godot 4.7 and run the project. The downloaded Godot executables under `godot/` are local-only and ignored by Git.

Controls: `W` accelerate, `S`/`Space` brake, `A`/`D` steer, `F` begin realistic refueling when that obstacle-mode option is enabled, `G` instantly refill to 100% for debugging, `O`/`P` select the previous/next race song, `R` reset, and `Esc` pause. Start the Python service before using `F`; `G` works without it.

Music defaults to 30% and sound effects to 40%. Normal races shuffle the 20
local race tracks into a new order, while the Cadillac keeps its exclusive
looping song. The boot sequence displays three local splash cards before fading
into the main menu.

`S` brakes while moving forward and engages reverse near a standstill. Forward acceleration has no normal gameplay cap; steering becomes less responsive and collision movement is sub-stepped as speed rises.

The 11.9 km course now follows an authored closed curve instead of a single
forward world axis. Progress and recovery use local curve distance, preventing
the car from jumping between branches at Loop 3's elevated crossing.

The setting uses a generated synthwave sunset panorama, continuous ocean,
sandy island keys, palms, lamps, recognizable building silhouettes, shop rows,
marinas, and a separate Party Island landmark. See `docs/course-map.md` for the
course guide.

### Manual scenery editing

Open `scenes/world/editable_world.tscn` to move the saved decorative objects
by district, or drag any of the 164 checked-in presets from
`scenes/manual_scenery/presets/` under `EditableWorld/ManualScenery`. The
library includes 52 individual landscaping/street/beach pieces and every one
of the 11 current images on all five media carriers. See
[`docs/manual_scenery.md`](docs/manual_scenery.md) for the exact workflow.

Generated neighborhood details and natural landscapes appear in a locked
editor preview and are composed at identity at runtime, so the whole generated
layer cannot be accidentally moved while editing.

## Verification

Run the map and gameplay contracts without using Gemini quota:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script qa/course_layout_data_test.gd
.\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script qa/map_course_contract.gd
.\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script qa/map_gameplay_test.gd
```

Capture every named district for visual review:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --script qa/map_course_screenshots.gd
```

## API response

```json
{
  "drinking_detected": true,
  "confidence": 0.92,
  "reason": "The canister spout is raised to the mouth and held there as if drinking."
}
```

Never commit `.env` or recorded webcam clips.
