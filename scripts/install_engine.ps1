param([string]$Destination = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Destination) { $Destination = Join-Path $root '.tools/ci-godot' }
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'engine-download.json') | ConvertFrom-Json
$pin = (Get-Content -Raw -LiteralPath (Join-Path $root 'engine-version.txt')).Trim()
if ($spec.version -ne $pin) { throw 'Engine download descriptor disagrees with engine-version.txt.' }
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$zip = Join-Path $Destination 'engine.zip'
Invoke-WebRequest -Uri $spec.url -OutFile $zip -MaximumRetryCount 2
$actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $spec.sha256) { throw 'Godot archive checksum mismatch. Do not run this archive.' }
Expand-Archive -LiteralPath $zip -DestinationPath $Destination -Force
$exe = Join-Path $Destination $spec.executable
$version = (& $exe --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $pin) { throw 'Downloaded Godot version mismatch.' }
Write-Output $exe
