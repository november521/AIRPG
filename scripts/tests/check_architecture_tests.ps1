$ErrorActionPreference = 'Stop'
$gate = Join-Path (Split-Path -Parent $PSScriptRoot) 'check_architecture.ps1'
$cases = @{
  reverse = 'Forbidden dependency:'
  cycle = 'Dependency cycle'
  ui_io = 'Engine I/O outside adapter:'
}
foreach ($case in $cases.Keys) {
  $failure = $null
  try { & $gate -Root (Join-Path $PSScriptRoot "cases/$case") | Out-Null }
  catch { $failure = $_.Exception.Message }
  if (-not $failure -or -not $failure.Contains($cases[$case])) {
    throw "Architecture negative case $case was not rejected for the expected reason: $failure"
  }
}
Write-Host "Architecture negative tests passed ($($cases.Count) cases)."
