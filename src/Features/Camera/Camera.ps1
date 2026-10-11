# Wider camera zoom range: 0.7-1.4 -> 0.5-1.8 (closer for the HD textures, more of the battlefield
# at 4K). The gameplay limits are hard-coded: AA.exe registers CameraZoomGameplayMin/Max with
# flag 2, which AVars cannot override, so the float immediates of those registrations are patched.
# The ground on screen grows with the zoom, so the terrain texture pool grows to match.

$script:CameraAppVars = [ordered]@{
  # dev-mode zoom limit; kept at or above the gameplay limit
  CameraZoomMax = '1.8'
}

$script:CameraUserVars = [ordered]@{
  # "approximately 20% more than on-screen for max zoom": 120 for the stock limit of 1.4,
  # (1.8 / 1.4)^2 = 1.65x the ground on screen
  TerrainTexturePoolDesiredNumEntries = '200'
}

function Get-CameraPatches {
  @(
    New-ExePatch -Name 'zoom-in-limit' -Offset 0x23C5 -Original 0x33, 0x33, 0x33, 0x3F -Patched 0x00, 0x00, 0x00, 0x3F `
      -Description 'zoom-in limit 0.7 -> 0.5 (push at VA 0x4023C4)'
    New-ExePatch -Name 'zoom-out-limit' -Offset 0x2447 -Original 0x33, 0x33, 0xB3, 0x3F -Patched 0x66, 0x66, 0xE6, 0x3F `
      -Description 'zoom-out limit 1.4 -> 1.8 (push at VA 0x402446)'
  )
}

function Install-Camera {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Camera zoom range'
  Set-ExePatches $Context (Get-CameraPatches) 'Applied'
  Set-GameVars $Context 'AVars.tgi' $script:CameraAppVars
  Set-GameVars $Context 'UVars.tgi' $script:CameraUserVars
}

function Uninstall-Camera {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Camera zoom range: original'
  Set-ExePatches $Context (Get-CameraPatches) 'Original'
  Reset-GameVars $Context 'AVars.tgi' @($script:CameraAppVars.Keys)
  Reset-GameVars $Context 'UVars.tgi' @($script:CameraUserVars.Keys)
}
