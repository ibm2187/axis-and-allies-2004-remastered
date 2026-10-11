# Applies the Axis & Allies (2004) modernization to a game folder. Safe to re-run.
#
#   pwsh -ExecutionPolicy Bypass -File install.ps1 -GameDir "C:\path\to\Game Files"
#
# Steps: copy mod/ files, generate font overrides, upscale the UI art for -UiArt (default
# 3840x2160, the screen mode it is made for; 'off' removes it), generate widescreen UI overrides
# for -Aspect (default 16:9; use 4:3 to restore the original layout space), raise rendering
# settings for -Graphics (default high; 'off' restores the game's defaults), set the 4 GB large-address-aware
# flag and byte patches on AA.exe, mark AA.exe DPI-aware for the current user, install dgVoodoo2
# (D3D9 -> D3D11) and stage DXVK.
param(
  [Parameter(Mandatory)][string]$GameDir,
  [string]$DgVoodooVersion = '2.87.5',
  [string]$DxvkVersion = '3.1.1',
  [string]$Aspect = '16:9',
  [string]$UiArt = '3840x2160',
  [ValidateSet('high', 'off')][string]$Graphics = 'high',
  [ValidateSet('on', 'off')][string]$Textures = 'on',
  [string]$TexconvRelease = 'may2026',
  [string]$EsrganVersion = '0.2.5.0',
  [string]$EsrganBuild = '20220424',
  [switch]$SkipWrappers
)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$GameDir = (Resolve-Path $GameDir).Path
$exe = Join-Path $GameDir 'AA.exe'
if (-not (Test-Path $exe)) { throw "AA.exe not found in $GameDir" }
if (Get-Process AA -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) { throw 'Axis & Allies is running; close it first.' }

Write-Host '== Copying mod files'
$mod = Join-Path $repo 'mod'
Get-ChildItem $mod -Recurse -File | ForEach-Object {
  $dest = Join-Path $GameDir $_.FullName.Substring($mod.Length + 1)
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  Copy-Item $_.FullName $dest -Force
  Write-Host "   $($_.FullName.Substring($mod.Length + 1))"
}

Write-Host '== Fonts (crash fix, DPI-independent sizes, Liberation Sans for Arial)'
$fontTmp = Join-Path ([IO.Path]::GetTempPath()) ("aa2004-fonts-" + [guid]::NewGuid())
New-Item -ItemType Directory $fontTmp | Out-Null
try {
  $libArgs = @()
  try {
    $tgz = Join-Path $fontTmp 'liberation.tar.gz'
    Invoke-WebRequest 'https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz' -OutFile $tgz
    tar -xzf $tgz -C $fontTmp
    if ($LASTEXITCODE) { throw 'tar failed' }
    $libArgs = @('--liberation', (Join-Path $fontTmp 'liberation-fonts-ttf-2.1.5'))
  } catch { Write-Warning "Liberation Sans download failed ($_); using Tahoma" }
  python -I (Join-Path $repo 'tools\fonts.py') $GameDir @libArgs
  if ($LASTEXITCODE) { throw 'fonts.py failed' }
}
finally { Remove-Item -Recurse -Force $fontTmp -ErrorAction SilentlyContinue }

$cache = Join-Path $repo '.cache'
$venvPy = Join-Path $cache 'venv\Scripts\python.exe'
if (-not (Test-Path $venvPy)) {
  Write-Host '== Python venv for image tools (Pillow, numpy)'
  python -m venv (Join-Path $cache 'venv')
  if ($LASTEXITCODE) { throw 'venv creation failed' }
  & $venvPy -m pip install --quiet pillow numpy
  if ($LASTEXITCODE) { throw 'pip install failed' }
}
$esrgan = Join-Path $cache 'esrgan\realesrgan-ncnn-vulkan.exe'
if (($UiArt -ne 'off' -or $Textures -ne 'off') -and -not (Test-Path $esrgan)) {
  $zip = Join-Path $cache 'esrgan.zip'
  Invoke-WebRequest "https://github.com/xinntao/Real-ESRGAN/releases/download/v$EsrganVersion/realesrgan-ncnn-vulkan-$EsrganBuild-windows.zip" -OutFile $zip
  Expand-Archive $zip (Join-Path $cache 'esrgan') -Force
  Remove-Item $zip
}
if ($UiArt -eq 'off') {
  Write-Host '== High-resolution UI art: removing'
  & $venvPy -I (Join-Path $repo 'tools\upscale_ui.py') $GameDir --clean
} else {
  $w, $h = $UiArt -split 'x'
  Write-Host "== High-resolution UI art for ${w}x${h} (Real-ESRGAN; first run takes a few minutes)"
  & $venvPy -I (Join-Path $repo 'tools\upscale_ui.py') $GameDir --esrgan $esrgan --width $w --height $h
}
if ($LASTEXITCODE) { throw 'upscale_ui.py failed' }

if ($Textures -eq 'off') {
  Write-Host '== Model and terrain textures: removing'
  & $venvPy -I (Join-Path $repo 'tools\upscale_textures.py') $GameDir --clean
} else {
  Write-Host '== Model and terrain textures (Real-ESRGAN + texconv; first run takes a while)'
  $texconv = Join-Path $cache 'texconv.exe'
  if (-not (Test-Path $texconv)) {
    Invoke-WebRequest "https://github.com/microsoft/DirectXTex/releases/download/$TexconvRelease/texconv.exe" -OutFile $texconv
  }
  & $venvPy -I (Join-Path $repo 'tools\upscale_textures.py') $GameDir --esrgan $esrgan --texconv $texconv
}
if ($LASTEXITCODE) { throw 'upscale_textures.py failed' }

Write-Host "== Widescreen UI ($Aspect)"
python -I (Join-Path $repo 'tools\widescreen.py') $GameDir --aspect $Aspect
if ($LASTEXITCODE) { throw 'widescreen.py failed' }

Write-Host "== Rendering settings ($Graphics)"
$gfxArgs = @(); if ($Graphics -eq 'off') { $gfxArgs = @('--off') }
python -I (Join-Path $repo 'tools\graphics.py') $GameDir @gfxArgs
if ($LASTEXITCODE) { throw 'graphics.py failed' }

Write-Host '== Large-address-aware flag'
python -I (Join-Path $repo 'tools\laa.py') $exe --set
if ($LASTEXITCODE) { throw 'laa.py failed' }

Write-Host '== AA.exe byte patches'
python -I (Join-Path $repo 'tools\exe_patch.py') $exe --apply
if ($LASTEXITCODE) { throw 'exe_patch.py failed' }

Write-Host '== DPI-aware compatibility flag (HKCU)'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
if (-not (Test-Path $layers)) { New-Item -Path $layers -Force | Out-Null }
New-ItemProperty -Path $layers -Name $exe -Value '~ HIGHDPIAWARE' -PropertyType String -Force | Out-Null

if (-not $SkipWrappers) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("aa2004-wrappers-" + [guid]::NewGuid())
  New-Item -ItemType Directory $tmp | Out-Null
  try {
    Write-Host "== dgVoodoo2 $DgVoodooVersion"
    $dgZip = Join-Path $tmp 'dgvoodoo.zip'
    Invoke-WebRequest "https://github.com/dege-diosg/dgVoodoo2/releases/download/v$DgVoodooVersion/dgVoodoo$($DgVoodooVersion -replace '\.', '_').zip" -OutFile $dgZip
    Expand-Archive $dgZip (Join-Path $tmp 'dg')
    Copy-Item (Join-Path $tmp 'dg\MS\x86\D3D9.dll') (Join-Path $GameDir 'D3D9.dll') -Force
    Copy-Item (Join-Path $tmp 'dg\dgVoodooCpl.exe') $GameDir -Force

    Write-Host "== DXVK $DxvkVersion (staged in _wrappers\dxvk, not active)"
    $dxTar = Join-Path $tmp 'dxvk.tar.gz'
    Invoke-WebRequest "https://github.com/doitsujin/dxvk/releases/download/v$DxvkVersion/dxvk-$DxvkVersion.tar.gz" -OutFile $dxTar
    tar -xzf $dxTar -C $tmp
    if ($LASTEXITCODE) { throw 'tar failed' }
    $dxDir = Join-Path $GameDir '_wrappers\dxvk'
    New-Item -ItemType Directory -Force $dxDir | Out-Null
    Copy-Item (Join-Path $tmp "dxvk-$DxvkVersion\x32\d3d9.dll") $dxDir -Force
  }
  finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
Write-Host '== Done'
