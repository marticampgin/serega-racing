param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [double]$CrossfadeSeconds = 1.0
)

$inputBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputPath))
if ([Text.Encoding]::ASCII.GetString($inputBytes, 0, 4) -ne 'RIFF' -or
    [Text.Encoding]::ASCII.GetString($inputBytes, 8, 4) -ne 'WAVE') {
    throw "Not a RIFF/WAVE file: $InputPath"
}

$fmtOffset = -1
$fmtSize = 0
$dataOffset = -1
$dataSize = 0
$cursor = 12
while ($cursor + 8 -le $inputBytes.Length) {
    $chunkId = [Text.Encoding]::ASCII.GetString($inputBytes, $cursor, 4)
    $chunkSize = [BitConverter]::ToInt32($inputBytes, $cursor + 4)
    $chunkData = $cursor + 8
    if ($chunkId -eq 'fmt ') {
        $fmtOffset = $chunkData
        $fmtSize = $chunkSize
    } elseif ($chunkId -eq 'data') {
        $dataOffset = $chunkData
        $dataSize = $chunkSize
        break
    }
    $cursor = $chunkData + $chunkSize + ($chunkSize % 2)
}
if ($fmtOffset -lt 0 -or $dataOffset -lt 0) { throw "Missing fmt or data chunk: $InputPath" }

$format = [BitConverter]::ToInt16($inputBytes, $fmtOffset)
$channels = [BitConverter]::ToInt16($inputBytes, $fmtOffset + 2)
$sampleRate = [BitConverter]::ToInt32($inputBytes, $fmtOffset + 4)
$blockAlign = [BitConverter]::ToInt16($inputBytes, $fmtOffset + 12)
$bitsPerSample = [BitConverter]::ToInt16($inputBytes, $fmtOffset + 14)
if ($format -ne 1 -or $bitsPerSample -ne 16) {
    throw "Only 16-bit PCM WAV is supported: $InputPath"
}

$frameCount = [int]($dataSize / $blockAlign)
$overlapFrames = [Math]::Min([int][Math]::Round($sampleRate * $CrossfadeSeconds), [int]($frameCount / 3))
if ($overlapFrames -lt 2) { throw "Audio is too short to crossfade: $InputPath" }
$outputFrames = $frameCount - $overlapFrames
$outputData = [byte[]]::new($outputFrames * $blockAlign)

for ($frame = 0; $frame -lt $outputFrames; $frame++) {
    if ($frame -ge $overlapFrames) {
        [Array]::Copy($inputBytes, $dataOffset + $frame * $blockAlign, $outputData, $frame * $blockAlign, $blockAlign)
        continue
    }
    $progress = $frame / [double]($overlapFrames - 1)
    # Raised-cosine gains make both ends derivative-smooth without a volume bump.
    $headGain = 0.5 - 0.5 * [Math]::Cos([Math]::PI * $progress)
    $tailGain = 1.0 - $headGain
    $tailFrame = $outputFrames + $frame
    for ($channel = 0; $channel -lt $channels; $channel++) {
        $sampleOffset = $channel * 2
        $head = [BitConverter]::ToInt16($inputBytes, $dataOffset + $frame * $blockAlign + $sampleOffset)
        $tail = [BitConverter]::ToInt16($inputBytes, $dataOffset + $tailFrame * $blockAlign + $sampleOffset)
        $mixed = [int][Math]::Round($tail * $tailGain + $head * $headGain)
        if ($mixed -gt 32767) { $mixed = 32767 }
        if ($mixed -lt -32768) { $mixed = -32768 }
        $sampleBytes = [BitConverter]::GetBytes([int16]$mixed)
        $outputData[$frame * $blockAlign + $sampleOffset] = $sampleBytes[0]
        $outputData[$frame * $blockAlign + $sampleOffset + 1] = $sampleBytes[1]
    }
}

$absoluteOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($absoluteOutput)) | Out-Null
$stream = [IO.File]::Create($absoluteOutput)
$writer = [IO.BinaryWriter]::new($stream)
try {
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](36 + $outputData.Length))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]$channels)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * $blockAlign))
    $writer.Write([int16]$blockAlign)
    $writer.Write([int16]$bitsPerSample)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]$outputData.Length)
    $writer.Write($outputData)
} finally {
    $writer.Dispose()
    $stream.Dispose()
}

Write-Output ("Built {0}: {1:N2}s, {2:N2}s raised-cosine crossfade" -f $OutputPath, ($outputFrames / $sampleRate), ($overlapFrames / $sampleRate))
