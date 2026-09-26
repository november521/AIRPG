param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot),
    [string]$BlenderRoot = 'D:\SteamLibrary\steamapps\common\Blender'
)

$ErrorActionPreference = 'Stop'

$toolsRoot = Join-Path $Workspace '.tools'
$godotRoot = Join-Path $toolsRoot 'godot'
$godotZip = Join-Path $toolsRoot 'godot-4.7.2.zip'
$godotExe = Join-Path $godotRoot 'Godot_v4.7.2-stable_win64.exe'
$godotMcpRoot = Join-Path $toolsRoot 'godot-mcp'
$uvRoot = Join-Path $toolsRoot 'uv'
$uvZip = Join-Path $toolsRoot 'uv.zip'
$uvxExe = Join-Path $uvRoot 'uvx.exe'
$uvCache = Join-Path $toolsRoot 'uv-cache'
$uvPython = Join-Path $toolsRoot 'uv-python'
$blenderAddonRoot = Join-Path $env:APPDATA 'Blender Foundation\Blender\5.2\scripts\addons'
$codexHome = Join-Path $env:USERPROFILE '.codex'

New-Item -ItemType Directory -Force -Path $toolsRoot, $godotRoot, $uvRoot, $uvCache, $uvPython | Out-Null

if (-not (Test-Path -LiteralPath $godotExe)) {
    Invoke-WebRequest -Uri 'https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip' -OutFile $godotZip
    Expand-Archive -LiteralPath $godotZip -DestinationPath $godotRoot -Force
}

if (-not (Test-Path -LiteralPath $uvxExe)) {
    Invoke-WebRequest -Uri 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip' -OutFile $uvZip
    Expand-Archive -LiteralPath $uvZip -DestinationPath $uvRoot -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $godotMcpRoot '.git'))) {
    git clone --branch v3.1.0 --depth 1 https://github.com/tugcantopaloglu/godot-mcp.git $godotMcpRoot
}

Push-Location $godotMcpRoot
try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw 'Godot MCP npm install failed.' }
    # Update vulnerable transitive packages within the upstream semver ranges.
    # npm may still report development-only test framework advisories here.
    npm audit fix
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'Godot MCP build failed.' }
    npm test -- --run
    if ($LASTEXITCODE -ne 0) { throw 'Godot MCP tests failed.' }
    npm audit --omit=dev --audit-level=high
    if ($LASTEXITCODE -ne 0) { throw 'Godot MCP production dependency audit failed.' }
} finally {
    Pop-Location
}

$env:UV_CACHE_DIR = $uvCache
$env:UV_PYTHON_INSTALL_DIR = $uvPython
$env:UV_PYTHON_PREFERENCE = 'only-managed'
$env:BLENDERMCP_ADDONS_DIR = $blenderAddonRoot
& $uvxExe --python 3.11 mcp-for-blender install-addon

$blenderExe = Join-Path $BlenderRoot 'blender.exe'
if (-not (Test-Path -LiteralPath $blenderExe)) {
    throw "Blender executable not found: $blenderExe"
}

& $blenderExe --background --python-expr "import bpy; bpy.ops.preferences.addon_enable(module='blender_mcp'); bpy.ops.wm.save_userpref()"

$env:HOME = $env:USERPROFILE
$env:CODEX_HOME = $codexHome

codex mcp remove godot 2>$null
codex mcp remove blender 2>$null

codex mcp add godot `
    --env "GODOT_PATH=$godotExe" `
    --env "GODOT_MCP_ALLOWED_DIRS=$Workspace" `
    --env 'DEBUG=false' `
    -- node (Join-Path $godotMcpRoot 'build\index.js')

codex mcp add blender `
    --env 'BLENDER_HOST=127.0.0.1' `
    --env 'BLENDER_PORT=9876' `
    --env 'BLENDER_MCP_SAFE_MODE=1' `
    --env 'DISABLE_TELEMETRY=true' `
    --env "UV_CACHE_DIR=$uvCache" `
    --env "UV_PYTHON_INSTALL_DIR=$uvPython" `
    --env 'UV_PYTHON_PREFERENCE=only-managed' `
    -- $uvxExe --python 3.11 mcp-for-blender

codex mcp list

Write-Host "GODOT_EXE=$godotExe"
Write-Host "BLENDER_EXE=$blenderExe"
Write-Host "BLENDER_ADDON_DIR=$blenderAddonRoot"
