$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot "godot\Godot_v4.7-stable_win64_console.exe"
$outputDirectory = Join-Path $projectRoot "build\windows"
$output = Join-Path $outputDirectory "Serega Speedster.exe"

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.7 was not found at $godot"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

& $godot --headless --audio-driver Dummy --path $projectRoot `
    --script res://tools/build_optimized_runtime_world.gd
if ($LASTEXITCODE -ne 0) {
    throw "Optimized runtime-world build failed with exit code $LASTEXITCODE"
}

& $godot --headless --audio-driver Dummy --path $projectRoot `
    --export-release "Windows Desktop" $output
if ($LASTEXITCODE -ne 0) {
    throw "Windows export failed with exit code $LASTEXITCODE"
}

Write-Host "Windows build ready: $output"
