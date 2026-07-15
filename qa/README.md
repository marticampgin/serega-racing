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

Verify the editable district bake, unchanged runtime mesh count and absence of
duplicate decorative generation:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/editable_world_bake_test.gd
```

Verify the planned building blocks: exact road-relative rows and setbacks,
grounding, land clearance, road-facing facades, copied/reordered rear rows,
zero building overlaps, and single-instance landmarks:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/building_layout_test.gd
```

Capture aerial and driver-height views of every building block for visual QA:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://qa/building_layout_visual_audit.gd
```

Validate the generated hills, dunes, mountain and oasis footprints, then
capture an aerial and road-level view of each site:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/natural_landscape_test.gd
.\godot\Godot_v4.7-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://qa/natural_landscape_visual_audit.gd
```

Verify the neighborhood connective layer, including district coverage,
balanced lamp spacing, terrain/water placement, compacted mesh budget and the
preservation of all saved user catalog instances:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/neighborhood_detail_layout_test.gd
```

Verify all 52 small props and the complete 11-artwork x 5-carrier media matrix:

```powershell
.\godot\Godot_v4.7-stable_win64_console.exe --path . --headless --rendering-method gl_compatibility --script res://qa/manual_scenery_expansion_test.gd
```
