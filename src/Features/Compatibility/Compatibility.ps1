# Windows 10/11 compatibility for AA.exe:
# - 4 GB large-address-aware flag: the 32-bit game may use 4 GB of memory instead of 2 GB, which
#   the HD textures need (PE Characteristics byte 0x946: 0x0E -> 0x2E; the PE checksum is 0).
# - DPI-aware compatibility flag for the current user, so Windows does not scale the game at
#   display scaling above 100% and it sees the real screen resolution.

$script:CompatibilityLayersKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'

function Get-CompatibilityPatches {
  @(New-ExePatch -Name 'large-address-aware' -Offset 0x946 -Original 0x0E -Patched 0x2E -Description '4 GB large-address-aware flag')
}

function Install-Compatibility {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Windows compatibility'
  Set-ExePatches $Context (Get-CompatibilityPatches) 'Applied'
  if (-not (Test-Path $script:CompatibilityLayersKey)) { New-Item -Path $script:CompatibilityLayersKey -Force | Out-Null }
  New-ItemProperty -Path $script:CompatibilityLayersKey -Name (Get-GamePath $Context 'AA.exe') -Value '~ HIGHDPIAWARE' -PropertyType String -Force | Out-Null
  Write-Detail 'DPI-aware flag for AA.exe (current user): set'
}

function Uninstall-Compatibility {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Windows compatibility'
  Set-ExePatches $Context (Get-CompatibilityPatches) 'Original'
  Remove-ItemProperty -Path $script:CompatibilityLayersKey -Name (Get-GamePath $Context 'AA.exe') -ErrorAction SilentlyContinue
  Write-Detail 'DPI-aware flag for AA.exe (current user): removed'
}
