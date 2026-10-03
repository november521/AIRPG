param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
  if ($env:AIRPG_GODOT) { $Godot = $env:AIRPG_GODOT }
  else { $Godot = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
}
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Set AIRPG_GODOT or pass -Godot with the pinned Godot console executable.' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$pin = (Get-Content -Raw -LiteralPath (Join-Path $root 'engine-version.txt')).Trim()
$version = (& $Godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $pin) { throw "Engine mismatch. Expected $pin; found $version" }
& (Join-Path $PSScriptRoot 'check_architecture.ps1') -Root $root
& (Join-Path $PSScriptRoot 'tests/check_architecture_tests.ps1')
$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
$game = Join-Path $root 'game'
function Invoke-GodotCheck([string]$Name, [string[]]$EngineArgs, [string]$SuccessMarker = '') {
  $output = & $Godot --headless --path $game --log-file (Join-Path $artifacts "$Name.engine.log") @EngineArgs 2>&1
  $exitCode = $LASTEXITCODE
  $output | Out-File -Encoding utf8 -LiteralPath (Join-Path $artifacts "$Name.log")
  $text = $output | Out-String
  if ($exitCode -ne 0 -or $text -match '(?m)(SCRIPT ERROR:|ERROR:|FAIL:|WARNING:.*leaked|Parse Error)') {
    throw "$Name failed (exit $exitCode):`n$text"
  }
  if ($SuccessMarker -and -not $text.Contains($SuccessMarker)) { throw "$Name did not reach its success marker.`n$text" }
  if ($Name -eq 'tests') {
    if ($text -notmatch 'AIRPG_TESTS: [1-9][0-9]* checks, 0 failures') { throw 'Aggregate did not finish with zero failures.' }
    # Only the suites this branch registers; C1/I1/G1/INTEGRATION still live on their own branches.
	foreach ($suite in @('BASE_TESTS', 'ARCHIVE_TESTS', 'MANOR_TESTS', 'CHARACTER_TESTS', 'NPC_RIG_TESTS', 'INTERACTION_TESTS')) {
      if ($text -notmatch "AIRPG_${suite}: [1-9][0-9]* checks") { throw "Missing or empty suite: $suite" }
    }
  }
  Write-Host "$Name passed."
  if ($Name -eq 'tests') { Write-Host $text.Trim() }
}
Invoke-GodotCheck 'import' @('--editor', '--import')
Invoke-GodotCheck 'tests' @('--script', 'res://tests/run_tests.gd') 'AIRPG_TESTS:'
Invoke-GodotCheck 'boot' @('--quit-after', '5') 'AIRPG_BOOT_READY'
Write-Host 'AIRPG verification passed.'
