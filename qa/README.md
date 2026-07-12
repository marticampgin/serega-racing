# Native Godot smoke test

The harness loads the production main scene without using the webcam or Gemini,
checks the race structure and drink-effect state, renders frames, and writes
`qa/artifacts/smoke.png`.

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
