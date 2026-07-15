# Serega Racing

A short third-person arcade racing game and birthday gift. The player drives an F1-inspired car around a synthwave island and refuels by drinking on webcam. A Gemini video model analyzes a short recorded clip and selects the fuel effect from the visible drink/container color.

## Project status

Playable map-driven track prototype:

- Closed 11.9 km Godot 4.7 circuit based on `tools/map template.png`.
- Three real loop/curl sectors, an underwater tunnel, and an elevated bridge.
- Recognizable Party Town, City Centre, Shopping Alley, Sport Complex, coastal
  villas, marinas, and off-track Party Island.
- Obstacles intentionally disabled while track drivability is evaluated.
- Python webcam/Gemini companion service.
- Five-second MP4 capture and native video upload.
- Structured drink-analysis response.

## Setup

### Python service

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Add your Gemini API key to `.env`, then run:

```powershell
uvicorn service.app:app --reload --port 8765
```

Check `http://127.0.0.1:8765/health`. To record and analyze a clip, send a POST request to `http://127.0.0.1:8765/analyze-drink`.

Set `DRY_RUN=true` in `.env` while developing to return a deterministic blue-bottle result without opening the camera or calling Gemini. Remove it for a real run.

### Godot

Open the repository root in Godot 4.7 and run the project. The downloaded Godot executables under `godot/` are local-only and ignored by Git.

Controls: `W` accelerate, `S`/`Space` brake, `A`/`D` steer, `F` record and analyze a refuelling video, `G` instantly refill to 100% for debugging, and `R` reset. Start the Python service before using `F`; `G` works without it.

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
by district, including the additive `NeighborhoodDetails` layer, or drag any of the 164 checked-in presets from
`scenes/manual_scenery/presets/` under `EditableWorld/ManualScenery`. The
library includes 52 individual landscaping/street/beach pieces and every one
of the 11 current images on all five media carriers. See
[`docs/manual_scenery.md`](docs/manual_scenery.md) for the exact workflow.

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
  "container_type": "bottle",
  "container_color": "blue",
  "liquid_color": "clear",
  "selected_color": "blue",
  "confidence": 0.92,
  "reason": "The bottle is raised to the mouth and tilted before being lowered."
}
```

Never commit `.env` or recorded webcam clips.
