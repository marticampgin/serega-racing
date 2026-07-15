# Native Godot smoke test

The harness loads the production main scene without using the webcam or Gemini,
checks the race structure and drink-effect state, renders frames, and writes
`qa/artifacts/smoke.png`.

World assertions also guard the requested semantic variety (three palm silhouettes,
shops, neighborhood rows, alleys, hotels, and offshore islets), reject the legacy
oversized cone formations, and verify that building roots sit on local ground.

Run from the repository root:

```powershell
& .\godot\Godot_v4.7-stable_win64_console.exe --path . --script res://qa/smoke_test.gd
```

The process exits with code `1` when any check fails.

Run the full-course collider traversal and off-track recovery regression test with:

```powershell
& .\godot\Godot_v4.7-stable_win64_console.exe --path . --script res://qa/course_traversal.gd
```

It raycasts the road every 60 metres across all 12 km and reproduces the reported 1.68 km fall-through state.
## Manual scenery catalog

Validate every draggable preset, the empty serialized manual layer, infrastructure exclusion and unchanged procedural mesh baseline:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/manual_scenery_catalog_test.gd
```

Capture one labeled visual sheet per scenery category:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://qa/manual_scenery_visual_audit.gd
```

Verify the editor-only road/land placement guide (and that it has no collision):

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --editor --script res://qa/editor_placement_guide_test.gd
```

Verify the detailed editor world preview contains the full track, ocean, terrain,
bridges, tunnels, flyovers and districts without adding collision or processing:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --editor --rendering-method gl_compatibility --script res://qa/editor_world_preview_test.gd
```

Verify that generated buildings, palms and lamps reserve around a manually placed hotel:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/manual_scenery_reservation_test.gd
```
