# Removes Axis & Allies (2004) Remastered and restores the game's original files and settings.
# Players: double-click Uninstall.cmd instead.
#
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GameDir <folder with AA.exe>] [-Wizard]
param(
  [Parameter(Position = 0)][string]$GameDir,
  [switch]$Wizard
)
$ErrorActionPreference = 'Stop'
try {
  Import-Module (Join-Path $PSScriptRoot 'src\Remastered.psm1') -Force -DisableNameChecking
  Uninstall-Remastered -ModDir $PSScriptRoot @PSBoundParameters
} catch {
  Write-Host ''
  Write-Host "Uninstall did not complete: $_" -ForegroundColor Red
  exit 1
}
