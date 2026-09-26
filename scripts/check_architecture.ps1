param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$game = Join-Path $Root 'game'
$allowed = @{
  shared = @('shared')
  domain = @('domain', 'shared')
  application = @('application', 'domain', 'shared')
  infrastructure = @('infrastructure', 'application', 'domain', 'shared')
  presentation = @('presentation', 'application', 'shared')
  bootstrap = @('bootstrap', 'presentation', 'infrastructure', 'application', 'domain', 'shared', 'data')
  tests = @('tests', 'bootstrap', 'presentation', 'infrastructure', 'application', 'domain', 'shared', 'data')
}
$errors = [Collections.Generic.List[string]]::new()
$graph = @{}
$files = Get-ChildItem -LiteralPath $game -Recurse -File | Where-Object {
  $_.Extension -in '.gd', '.tscn', '.tres' -and $_.FullName -notmatch '[\\/]\.godot[\\/]'
}
foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($game, $file.FullName).Replace('\', '/')
  $layer = $relative.Split('/')[0]
  if (-not $allowed.ContainsKey($layer)) { $errors.Add("Unowned source: $relative"); continue }
  $source = Get-Content -Raw -LiteralPath $file.FullName
  $graph[$relative] = @()
  foreach ($reference in [regex]::Matches($source, 'res://([a-zA-Z0-9_./-]+)')) {
    $target = $reference.Groups[1].Value
    $targetLayer = $target.Split('/')[0]
    if ($targetLayer -notin $allowed[$layer]) { $errors.Add("Forbidden dependency: $relative -> $target") }
    if ($target.EndsWith('.gd') -or $target.EndsWith('.tscn') -or $target.EndsWith('.tres')) {
      if (-not (Test-Path -LiteralPath (Join-Path $game $target))) { $errors.Add("Missing dependency: $relative -> $target") }
      $graph[$relative] += $target
    }
  }
  if ($file.Extension -ne '.gd' -or $layer -eq 'tests') { continue }
  if (($source -split "`n").Count -gt 300) { $errors.Add("Split source over 300 lines: $relative") }
  if ($layer -in 'shared', 'domain', 'application', 'presentation') {
    if ($source -match '\b(FileAccess|DirAccess|HTTPRequest|HTTPClient|Input|InputMap|OS|Time|ResourceLoader|SceneTree|RandomNumberGenerator)\b|\b(get_tree|load)\s*\(') {
      $errors.Add("Engine I/O outside adapter: $relative")
    }
    if ($layer -ne 'presentation' -and $source -match '(?m)^extends\s+(Node|Control|Node2D|CharacterBody2D)\b') { $errors.Add("Scene-dependent core: $relative") }
  }
  if ($source -match 'class_name\s|/root/|\b(load|ResourceLoader\.load)\s*\(') {
    $errors.Add("Hidden/global dependency; use explicit preload and injection: $relative")
  }
}
$visiting = @{}
$done = @{}
function Visit([string]$path) {
  if ($visiting.ContainsKey($path)) { $errors.Add("Dependency cycle at $path"); return }
  if ($done.ContainsKey($path)) { return }
  $visiting[$path] = $true
  foreach ($target in $graph[$path]) { if ($graph.ContainsKey($target)) { Visit $target } }
  $visiting.Remove($path)
  $done[$path] = $true
}
foreach ($path in @($graph.Keys)) { Visit $path }
$project = Get-Content -Raw -LiteralPath (Join-Path $game 'project.godot')
if ($project -match '\[autoload\]') { $errors.Add('Autoload requires an explicit architecture decision and gate update.') }
if ($errors.Count) { throw ($errors -join "`n") }
Write-Host "Architecture checks passed ($($files.Count) source/scene files)."
