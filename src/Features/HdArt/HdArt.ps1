# HD art: AI-upscaled UI art and 3D/terrain textures, installed from the prebuilt HD pack (see
# HdArt.Build.ps1, which makes it on the maintainer's PC). Players need no GPU work or Python.
#
# The pack is split into zip parts (each under GitHub's 2 GB asset limit), listed with their
# SHA-256 in hdpack.json:
#   textures   model, building, terrain and world-map textures (any resolution)
#   icons      icons and pictures the game loads by a fixed path (any resolution)
#   ui         one UI art set per screen height (1080, 1440, 2160). The game looks the set up as
#              /UI/<screen width>/, so the set's width folder is renamed to the player's width.
#              The 2160 set also carries the 2x mouse cursor.
# Parts are taken from the mod folder when present, otherwise downloaded into .cache.

$script:HdPackManifest = Join-Path $PSScriptRoot 'hdpack.json'

# Downloaded parts, and the parts Build-HdPack makes, are kept here.
function Get-HdPackCacheDir {
  param([Parameter(Mandatory)]$Context)
  Join-Path $Context.CacheDir 'hdpack\parts'
}

function Get-HdPack {
  Get-Content $script:HdPackManifest -Raw | ConvertFrom-Json
}

# The parts this screen needs, each with where it is (or will be) on disk.
function Get-HdPackParts {
  param([Parameter(Mandatory)]$Context)
  $pack = Get-HdPack
  $uiSet = Select-UiSet $pack $Context.Screen.Height
  foreach ($part in $pack.parts) {
    if ($part.kind -eq 'ui' -and (-not $uiSet -or $part.height -ne $uiSet)) { continue }
    $local = Join-Path $Context.Options.HdPackDir $part.file
    $path = if (Test-Path -LiteralPath $local) { $local } else { Join-Path (Get-HdPackCacheDir $Context) $part.file }
    $part | Add-Member -NotePropertyName Path -NotePropertyValue $path -PassThru -Force
  }
}

# Bytes still to download for this screen (0 when everything is on disk).
function Get-HdPackDownloadSize {
  param([Parameter(Mandatory)]$Context)
  $bytes = 0
  foreach ($part in Get-HdPackParts $Context) {
    if (-not (Test-Path -LiteralPath $part.Path)) { $bytes += $part.bytes }
  }
  $bytes
}

function Test-HdPackAvailable {
  @((Get-HdPack).parts).Count -gt 0
}

function Install-HdArt {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'HD art (prebuilt pack)'
  Remove-TrackedFiles $Context 'HdArt'
  if (-not (Test-HdPackAvailable)) { Write-Detail 'skipped: no HD pack has been published yet'; return }
  if (-not $Context.Options.HdArt) { Write-Detail 'skipped (not selected)'; return }
  $files = foreach ($part in Get-HdPackParts $Context) {
    Get-HdPackPart $part
    Write-Detail "$($part.file): installing $($part.files) files"
    Expand-ZipIntoGame $Context $part.Path (Get-HdPathMap $part $Context.Screen.Width)
  }
  Save-TrackedFiles $Context 'HdArt' @($files)
}

function Uninstall-HdArt {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'HD art'
  Remove-TrackedFiles $Context 'HdArt'
  Write-Detail 'removed'
}

# UI set for a screen height: the nearest one (the larger on a tie); none at 800 px and below,
# where the game's own art is already sharp.
function Select-UiSet {
  param([Parameter(Mandatory)]$Pack, [Parameter(Mandatory)][int]$Height)
  if ($Height -le 800) { return $null }
  $heights = @($Pack.parts | Where-Object kind -eq 'ui' | ForEach-Object height)
  $heights | Sort-Object { [math]::Abs($_ - $Height) }, { - $_ } | Select-Object -First 1
}

function Get-HdPackPart {
  param([Parameter(Mandatory)]$Part)
  if (-not (Test-Path -LiteralPath $Part.Path)) {
    $url = "$((Get-HdPack).baseUrl)/$($Part.file)"
    Write-Detail "downloading $($Part.file) ($([math]::Round($Part.bytes / 1GB, 2)) GB)"
    Save-WebFile -Url $url -Path $Part.Path -ShowProgress
  }
  Write-Detail "checking $($Part.file)"
  if ((Get-FileSha256 $Part.Path) -ne $Part.sha256) {
    throw "$($Part.Path) is damaged or from another version (SHA-256 mismatch). Delete it and run the installer again."
  }
}

# Zip paths are game-relative; a UI set's width folder becomes the player's screen width.
function Get-HdPathMap {
  param([Parameter(Mandatory)]$Part, [Parameter(Mandatory)][int]$ScreenWidth)
  if ($Part.kind -ne 'ui') { return { param($path) $path } }
  $setWidth = [string]$Part.width
  {
    param($path)
    $segments = $path -split '/'
    for ($i = 0; $i -lt $segments.Count - 1; $i++) {
      if ($segments[$i] -eq $setWidth) { $segments[$i] = [string]$ScreenWidth }
    }
    $segments -join '/'
  }.GetNewClosure()
}
