# Puts the AALight build in front of dgVoodoo2 in a game folder, for development (the installer
# slice comes in Phase 5).
#   deploy.ps1 -GameDir <folder>           D3D9.dll -> D3D9.dgVoodoo.dll, AALight becomes D3D9.dll
#   deploy.ps1 -GameDir <folder> -Remove   dgVoodoo2's D3D9.dll back in place
# AALight.log and the AALight\capture-* folders stay after -Remove. Running install.ps1 also puts
# dgVoodoo2 back as D3D9.dll (leaving D3D9.dgVoodoo.dll unused).
param(
  [Parameter(Mandatory)][string]$GameDir,
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'

if (Get-Process -Name AA -ErrorAction SilentlyContinue) { throw 'AA.exe is running: close the game first.' }
$d3d9 = Join-Path $GameDir 'D3D9.dll'
$real = Join-Path $GameDir 'D3D9.dgVoodoo.dll'
$ini = Join-Path $GameDir 'AALight.ini'
$build = Join-Path $PSScriptRoot 'build\D3D9.dll'

function Test-AALight([string]$Path) {
  (Test-Path $Path) -and [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Path)).Contains('AALight frame capture')
}

if ($Remove) {
  if (-not (Test-AALight $d3d9)) { Write-Host 'AALight is not deployed; nothing to do.'; return }
  if (-not (Test-Path $real)) { throw "D3D9.dgVoodoo.dll is missing: run install.ps1 to put dgVoodoo2 back." }
  Remove-Item -LiteralPath $d3d9
  Move-Item -LiteralPath $real $d3d9
  if (Test-Path $ini) { Remove-Item -LiteralPath $ini }
  Write-Host 'AALight removed; dgVoodoo2 is D3D9.dll again.'
  return
}

if (-not (Test-Path $build)) { throw "No build at ${build}: run build.cmd first." }
if (-not (Test-AALight $d3d9)) {
  if (-not (Test-Path $d3d9)) { throw 'No D3D9.dll in the game folder: install the mod (dgVoodoo2) first.' }
  Move-Item -LiteralPath $d3d9 $real -Force
}
Copy-Item -LiteralPath $build $d3d9 -Force
if (-not (Test-Path $ini)) {
  @(
    '[AALight]'
    '; Direct3D 9 that AALight passes everything on to (dgVoodoo2, renamed by deploy.ps1).'
    'RealD3D9=D3D9.dgVoodoo.dll'
    '; Log every change of a fixed-function light to AALight.log (first 500).'
    'LogLights=1'
    '; Capture one frame once the game has drawn this many battle frames (0 = off).'
    '; Ctrl+Shift+F11 captures the next frame at any time.'
    'AutoCaptureLitFrames=300'
  ) | Set-Content -LiteralPath $ini -Encoding ASCII
}
Write-Host "AALight deployed to $GameDir (dgVoodoo2 is now D3D9.dgVoodoo.dll)."
