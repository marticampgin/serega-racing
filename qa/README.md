# Native Godot smoke test

The harness loads the production main scene without using the webcam or Gemini,
checks the race structure and drink-effect state, renders frames, and writes
`qa/artifacts/smoke.png`.

Run from the repository root:

```powershell
& .\godot\Godot_v4.7-stable_win64_console.exe --path . --script res://qa/smoke_test.gd
```

The process exits with code `1` when any check fails.
