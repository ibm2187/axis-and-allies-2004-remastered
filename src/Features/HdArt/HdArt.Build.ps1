# Builds the HD pack on the maintainer's PC (players never run this). Needs Python 3 on PATH
# (Pillow and numpy are installed into .cache\venv) and a Vulkan GPU. The first build runs
# Real-ESRGAN for about an hour; results are cached in .cache, so later builds take minutes.
#
#   Import-Module .\src\Remastered.psm1; Build-HdPack -GameDir 'C:\Games\Axis & Allies' -Version 1.0
#
# Output: .cache\hdpack\parts\*.zip (upload them as release assets under the tag hd-<Version>) and
# src\Features\HdArt\hdpack.json (commit it).

$script:HdUiSets = @(
  @{ Height = 1080; Width = 1920 }
  @{ Height = 1440; Width = 2560 }
  @{ Height = 2160; Width = 3840 }
)
$script:HdPartLimit = 1.8GB  # GitHub release assets must stay under 2 GB
$script:HdTools = @{
  Esrgan        = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip'
  # texture-trained models in ncnn format, CC BY-NC-SA 4.0 (non-commercial use)
  Models        = 'https://raw.githubusercontent.com/upscayl/upscayl/v2.15.0/resources/models'
  ModelNames    = 'ultrasharp-4x', 'ultramix-balanced-4x'
  Texconv       = 'https://github.com/microsoft/DirectXTex/releases/download/may2026/texconv.exe'
}

function Build-HdPack {
  param(
    [Parameter(Mandatory)][string]$GameDir,
    [Parameter(Mandatory)][string]$Version,
    [string]$BaseUrl = "https://github.com/ibm2187/axis-and-allies-2004-remastered/releases/download/hd-$Version"
  )
  $modDir = Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent
  $context = New-RemasteredContext -GameDir $GameDir -ModDir $modDir
  try {
    $tools = Initialize-HdBuildTools $context
    $stage = Join-Path $context.CacheDir 'hdpack\stage'
    foreach ($set in $script:HdUiSets) { Invoke-UiSetBuild $context $tools $set (Join-Path $stage "ui-$($set.Height)") }
    Invoke-TextureBuild $context $tools (Join-Path $stage 'textures')
    $parts = New-HdPackParts $context $stage $Version
    Save-HdPackManifest $Version $BaseUrl $parts
  } finally { Close-RemasteredContext $context }
}

function Initialize-HdBuildTools {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Build tools'
  $cache = $Context.CacheDir
  $python = Join-Path $cache 'venv\Scripts\python.exe'
  if (-not (Test-Path $python)) {
    & python -m venv (Join-Path $cache 'venv'); if ($LASTEXITCODE) { throw 'python -m venv failed (is Python 3 on PATH?)' }
    & $python -m pip install --quiet pillow numpy; if ($LASTEXITCODE) { throw 'pip install pillow numpy failed' }
  }
  $esrgan = Join-Path $cache 'esrgan\realesrgan-ncnn-vulkan.exe'
  if (-not (Test-Path $esrgan)) {
    $zip = Get-CachedDownload $Context $script:HdTools.Esrgan 'realesrgan-ncnn-vulkan.zip'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $cache 'esrgan'))
  }
  foreach ($model in $script:HdTools.ModelNames) {
    foreach ($extension in 'param', 'bin') {
      $file = Join-Path $cache "esrgan\models\$model.$extension"
      if (-not (Test-Path $file)) { Save-WebFile "$($script:HdTools.Models)/$model.$extension" $file }
    }
  }
  $texconv = Get-CachedDownload $Context $script:HdTools.Texconv 'texconv.exe'
  Write-Detail "Python $(& $python --version), Real-ESRGAN, texconv"
  @{ Python = $python; Esrgan = $esrgan; Texconv = $texconv }
}

function Invoke-UiSetBuild {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Tools, [Parameter(Mandatory)]$Set, [Parameter(Mandatory)][string]$Out)
  Write-Step "UI art set for $($Set.Width)x$($Set.Height)"
  $arguments = @($Context.GameDir, '--esrgan', $Tools.Esrgan, '--width', $Set.Width, '--height', $Set.Height, '--out', $Out)
  if ($Set.Height -ne 2160) { $arguments += '--no-inplace' }  # fixed-path icons come from the 2160 build
  Invoke-BuildScript $Tools 'upscale_ui.py' $arguments
}

function Invoke-TextureBuild {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Tools, [Parameter(Mandatory)][string]$Out)
  Write-Step 'Model and terrain textures'
  Invoke-BuildScript $Tools 'upscale_textures.py' @($Context.GameDir, '--esrgan', $Tools.Esrgan, '--texconv', $Tools.Texconv, '--out', $Out)
}

function Invoke-BuildScript {
  param([Parameter(Mandatory)]$Tools, [Parameter(Mandatory)][string]$Script, [Parameter(Mandatory)][object[]]$Arguments)
  & $Tools.Python -I (Join-Path $PSScriptRoot "build\$Script") @Arguments
  if ($LASTEXITCODE) { throw "$Script failed (exit code $LASTEXITCODE)" }
}

# Zips the staged files into parts: textures (split by size), icons, and one per UI set.
function New-HdPackParts {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][string]$Version)
  Write-Step 'Packing'
  $out = Get-HdPackCacheDir $Context
  New-Item -ItemType Directory -Force $out | Out-Null
  Remove-Item "$out\*.zip" -ErrorAction SilentlyContinue
  $groups = @()
  $textures = @(Get-StagedFiles (Join-Path $Stage 'textures'))
  $groups += Split-BySize $textures | ForEach-Object -Begin { $n = 0 } -Process {
    $n++; @{ Kind = 'textures'; Name = "textures-$n"; Files = $_ }
  }
  foreach ($set in $script:HdUiSets) {
    $files = @(Get-StagedFiles (Join-Path $Stage "ui-$($set.Height)"))
    $isSetFile = { param($f) $f.Relative -match "/$($set.Width)/" -or $f.Relative -like 'data/Cursors/*' }.GetNewClosure()
    $groups += @{ Kind = 'ui'; Name = "ui-$($set.Height)"; Height = $set.Height; Width = $set.Width; Files = @($files | Where-Object { & $isSetFile $_ }) }
    if ($set.Height -eq 2160) { $groups += @{ Kind = 'icons'; Name = 'icons'; Files = @($files | Where-Object { -not (& $isSetFile $_) }) } }
  }
  foreach ($group in $groups) {
    $file = "AA2004-Remastered-HD-$Version-$($group.Name).zip"
    $zip = Join-Path $out $file
    New-ZipFromFiles $zip $group.Files
    Write-Detail "$file : $($group.Files.Count) files, $([math]::Round((Get-Item $zip).Length / 1MB)) MB"
    $part = [ordered]@{ file = $file; kind = $group.Kind; files = $group.Files.Count; bytes = (Get-Item $zip).Length
                        sha256 = Get-FileSha256 $zip }
    if ($group.Kind -eq 'ui') { $part.height = $group.Height; $part.width = $group.Width }
    [pscustomobject]$part
  }
}

function Get-StagedFiles {
  param([Parameter(Mandatory)][string]$Root)
  Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Name -notlike '*-generated.txt' } | ForEach-Object {
    [pscustomobject]@{ Path = $_.FullName; Relative = $_.FullName.Substring($Root.Length + 1) -replace '\\', '/'; Length = $_.Length }
  }
}

function Split-BySize {
  param([Parameter(Mandatory)][object[]]$Files)
  $chunk = @(); $size = 0
  foreach ($file in ($Files | Sort-Object Relative)) {
    if ($chunk.Count -and $size + $file.Length -gt $script:HdPartLimit) { , $chunk; $chunk = @(); $size = 0 }
    $chunk += $file; $size += $file.Length
  }
  if ($chunk.Count) { , $chunk }
}

function New-ZipFromFiles {
  param([Parameter(Mandatory)][string]$ZipPath, [Parameter(Mandatory)][object[]]$Files)
  $zip = [IO.Compression.ZipFile]::Open($ZipPath, 'Create')
  try {
    foreach ($file in $Files) {
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.Path, $file.Relative, 'Optimal') | Out-Null
    }
  } finally { $zip.Dispose() }
}

function Save-HdPackManifest {
  param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$BaseUrl, [Parameter(Mandatory)][object[]]$Parts)
  $manifest = [ordered]@{ version = $Version; baseUrl = $BaseUrl; parts = $Parts }
  [IO.File]::WriteAllText($script:HdPackManifest, ($manifest | ConvertTo-Json -Depth 4))  # UTF-8, no BOM
  Write-Detail "wrote $script:HdPackManifest ($($Parts.Count) parts, $([math]::Round(($Parts | Measure-Object bytes -Sum).Sum / 1GB, 2)) GB)"
}
