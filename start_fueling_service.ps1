$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $projectRoot ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $python)) {
    throw "Project virtual environment not found. Run: py -m venv .venv; .\.venv\Scripts\python.exe -m pip install -r requirements.txt"
}

Set-Location -LiteralPath $projectRoot
Write-Host "Starting the Seryoga Speedster fueling service on http://127.0.0.1:8765"
& $python -m uvicorn service.app:app --host 127.0.0.1 --port 8765
exit $LASTEXITCODE
