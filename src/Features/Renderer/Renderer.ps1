# Direct3D 9 -> Direct3D 11 through dgVoodoo2 (its D3D9.dll next to AA.exe): stable on current
# Windows and GPUs, 16x anisotropic filtering, v-sync, no watermark, and the largest 4:3 mode
# added to the game's resolution list. Settings are in dgVoodoo.conf next to this script.
#
# Optional supersampling (Options.Supersample = '2x'): dgVoodoo renders at twice the game's
# resolution and downsamples. Off by default: at 4K it made the mouse and camera less responsive.

$script:DgVoodooVersion = '2.87.5'

function Install-Renderer {
  param([Parameter(Mandatory)]$Context)
  Write-Step "Renderer: dgVoodoo2 $script:DgVoodooVersion (Direct3D 11)"
  Remove-TrackedFiles $Context 'Renderer'
  $zip = Get-CachedDownload $Context -Url (Get-DgVoodooUrl) -FileName "dgVoodoo$script:DgVoodooVersion.zip"
  $files = @(
    Write-GameFile $Context 'D3D9.dll' (Read-ZipEntry $zip 'MS/x86/D3D9.dll')
    Write-GameFile $Context 'dgVoodooCpl.exe' (Read-ZipEntry $zip 'dgVoodooCpl.exe')
    Write-GameFile $Context 'dgVoodoo.conf' (Get-DgVoodooConfig $Context.Options.Supersample)
  )
  Save-TrackedFiles $Context 'Renderer' $files
  Write-Detail "D3D9.dll, dgVoodooCpl.exe, dgVoodoo.conf (supersampling: $($Context.Options.Supersample))"
}

function Uninstall-Renderer {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Renderer: dgVoodoo2'
  Remove-TrackedFiles $Context 'Renderer'
  Write-Detail 'removed (the game uses Direct3D 9 again)'
}

function Get-DgVoodooUrl {
  $file = 'dgVoodoo' + ($script:DgVoodooVersion -replace '\.', '_') + '.zip'
  "https://github.com/dege-diosg/dgVoodoo2/releases/download/v$script:DgVoodooVersion/$file"
}

function Get-DgVoodooConfig {
  param([Parameter(Mandatory)][ValidateSet('off', '2x')][string]$Supersample)
  $text = ConvertFrom-Latin1 ([IO.File]::ReadAllBytes("$PSScriptRoot\dgVoodoo.conf"))
  if ($Supersample -ne 'off') {
    # only the [DirectX] section's Resolution (the [Glide] section has one too)
    $text = [regex]::Replace($text, '(?ms)(^\[DirectX\].*?^Resolution\s*=\s*)unforced', "`${1}$Supersample")
  }
  ConvertTo-Latin1 $text
}
