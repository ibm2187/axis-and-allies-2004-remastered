# Installs Axis & Allies (2004) Remastered. Players: double-click Install.cmd instead.
#
#   powershell -ExecutionPolicy Bypass -File install.ps1 [-GameDir <folder with AA.exe>]
#     [-Resolution 3840x2160] [-Supersample 2x] [-NoHdArt] [-HdPackDir <folder with the HD zips>] [-Wizard]
#
# Safe to run again (updates, or a different resolution). Without -GameDir the game folder is
# looked for next to this folder and among installed programs; without -Resolution the primary
# monitor's native resolution is used.
param(
  [Parameter(Position = 0)][string]$GameDir,
  [ValidatePattern('^\d+x\d+$')][string]$Resolution,
  [ValidateSet('off', '2x')][string]$Supersample = 'off',
  [switch]$NoHdArt,
  [string]$HdPackDir,
  [switch]$Wizard
)
$ErrorActionPreference = 'Stop'
try {
  Import-Module (Join-Path $PSScriptRoot 'src\Remastered.psm1') -Force -DisableNameChecking
  Install-Remastered -ModDir $PSScriptRoot @PSBoundParameters
} catch {
  Write-Host ''
  Write-Host "Installation did not complete: $_" -ForegroundColor Red
  exit 1
}
