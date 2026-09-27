param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
  if ($env:AIRPG_GODOT) { $Godot = $env:AIRPG_GODOT }
  else { $Godot = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
}
if (-not (Test-Path -LiteralPath $Godot)) {
  throw 'Pass -Godot with the pinned Godot executable, or set AIRPG_GODOT.'
}
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$pin = (Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'engine-version.txt')).Trim()
$version = (& $Godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $pin) { throw "Engine mismatch: $version; expected $pin." }
$game = Join-Path $projectRoot 'game'
$artifacts = Join-Path $projectRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
# Import is required on a fresh checkout; exported games use Godot's packed resources.
$output = & $Godot --headless --path $game --log-file (Join-Path $artifacts 'launch-import.engine.log') --editor --import 2>&1
$importExit = $LASTEXITCODE
$output | Out-File -Encoding utf8 -LiteralPath (Join-Path $artifacts 'launch-import.log')
if ($importExit -ne 0 -or ($output | Out-String) -match '(SCRIPT ERROR:|ERROR:|Parse Error)') {
  throw "Resource import failed; see artifacts/launch-import.log."
}
& $Godot --path $game --log-file (Join-Path $artifacts 'launch.engine.log')
if ($LASTEXITCODE -ne 0) { throw "Game exited with code $LASTEXITCODE." }
