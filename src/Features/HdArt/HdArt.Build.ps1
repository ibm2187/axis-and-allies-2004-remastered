# Builds the HD pack on the maintainer's PC (players never run this). Needs Python 3 on PATH
# (Pillow and numpy are installed into .cache\venv) and a Vulkan GPU. The first build runs
# Real-ESRGAN for about an hour; results are cached in .cache, so later builds take minutes.
#
#   Import-Module .\src\Remastered.psm1; Build-HdPack -GameDir 'C:\Games\Axis & Allies' -Version 1.0
#
# -Only Ui rebuilds the UI sets and icons, -Only Textures the 3D/terrain textures (re-encoding
# them all with texconv is the slow part); the other parts are kept from the current hdpack.json.
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
    [string]$BaseUrl = "https://github.com/ibm2187/axis-and-allies-2004-remastered/releases/download/hd-$Version",
    [ValidateSet('All', 'Ui', 'Textures')][string]$Only = 'All'
  )
  $kinds = switch ($Only) { 'Ui' { 'ui', 'icons' } 'Textures' { , 'textures' } default { 'textures', 'ui', 'icons' } }
  $modDir = Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent
  $context = New-RemasteredContext -GameDir $GameDir -ModDir $modDir
  try {
    $kept = @(Get-KeptHdPackParts $context $Version $kinds)
    $tools = Initialize-HdBuildTools $context
    $stage = Join-Path $context.CacheDir 'hdpack\stage'
    if ('ui' -in $kinds) {
      foreach ($set in $script:HdUiSets) { Invoke-UiSetBuild $context $tools $set (Join-Path $stage "ui-$($set.Height)") }
    }
    if ('textures' -in $kinds) { Invoke-TextureBuild $context $tools (Join-Path $stage 'textures') }
    $built = @(New-HdPackParts $context $stage $Version $kinds)
    Save-HdPackManifest $Version $BaseUrl (Sort-HdPackParts ($kept + $built))
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

# Parts of the current hdpack.json that are not rebuilt: same version, zip still in the cache.
function Get-KeptHdPackParts {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string[]]$Kinds)
  $pack = Get-HdPack
  foreach ($part in @($pack.parts | Where-Object { $_.kind -notin $Kinds })) {
    $zip = Join-Path (Get-HdPackCacheDir $Context) $part.file
    if ($pack.version -ne $Version -or -not (Test-Path -LiteralPath $zip)) {
      throw "The $($part.kind) part of HD pack $Version is not built yet ($zip); build without -Only first."
    }
    Write-Detail "keeping $($part.file)"
    $part
  }
}

function Sort-HdPackParts {
  param([Parameter(Mandatory)][object[]]$Parts)
  $order = @{ textures = 0; ui = 1; icons = 2 }
  $Parts | Sort-Object { $order[$_.kind] }, { Get-PartHeight $_ }, file
}

function Get-PartHeight {
  param([Parameter(Mandatory)]$Part)
  $height = $Part.PSObject.Properties['height']
  if ($height) { [int]$height.Value } else { 0 }
}

# Zips the staged files of these kinds into parts: textures (split by size), icons, one per UI set.
function New-HdPackParts {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$Kinds)
  Write-Step 'Packing'
  $out = Get-HdPackCacheDir $Context
  New-Item -ItemType Directory -Force $out | Out-Null
  $groups = @()
  if ('textures' -in $Kinds) {
    Remove-Item "$out\AA2004-Remastered-HD-$Version-textures-*.zip" -ErrorAction SilentlyContinue
    $textures = @(Get-StagedFiles (Join-Path $Stage 'textures'))
    $groups += Split-BySize $textures | ForEach-Object -Begin { $n = 0 } -Process {
      $n++; @{ Kind = 'textures'; Name = "textures-$n"; Files = $_ }
    }
  }
  if ('ui' -in $Kinds) { foreach ($set in $script:HdUiSets) {
    $files = @(Get-StagedFiles (Join-Path $Stage "ui-$($set.Height)"))
    $isSetFile = { param($f) $f.Relative -match "/$($set.Width)/" -or $f.Relative -like 'data/Cursors/*' }.GetNewClosure()
    $groups += @{ Kind = 'ui'; Name = "ui-$($set.Height)"; Height = $set.Height; Width = $set.Width; Files = @($files | Where-Object { & $isSetFile $_ }) }
    if ($set.Height -eq 2160) { $groups += @{ Kind = 'icons'; Name = 'icons'; Files = @($files | Where-Object { -not (& $isSetFile $_) }) } }
  } }
  foreach ($group in $groups) {
    $file = "AA2004-Remastered-HD-$Version-$($group.Name).zip"
    $zip = Join-Path $out $file
    Remove-Item -LiteralPath $zip -ErrorAction SilentlyContinue
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
