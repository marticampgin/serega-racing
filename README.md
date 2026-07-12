# Serega Racing

A short third-person arcade racing game and birthday gift. The player drives an F1-inspired car through randomized obstacles and refuels by drinking on webcam. A Gemini video model analyzes a short recorded clip and selects the fuel effect from the visible drink/container color.

## Project status

Initial foundation:

- Godot 4.7 project with a launch scene.
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

The 12 km course includes technical esses, a mountain spiral, major elevation changes, repeated bridges and tunnels, rocks, turbines, coastal buildings, grandstands, and personalized portrait billboards.

The setting is a retro-synthwave island with a continuous ocean, sandy keys, palms, neon lamp posts, Miami-inspired beach houses and hotels, five extended tunnel sequences, and four visually exposed water-crossing bridges. Obstacle impacts force a full stop with a short control lockout to prevent collision catapulting.

The skyline uses an original generated synthwave sunset panorama. Seven neighborhood districts add storefront rows, awnings, homes, hotels, alleys and courtyards; offshore islets, docks and boats create depth between denser districts and quieter beaches. The track adds localized omega and marina-crescent curve sectors while preserving reliable forward progress.

Obstacle contact stops the initial impact. After the brief pause, motion into the obstacle remains blocked while steering can build controlled tangential motion to slide around its side.

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
