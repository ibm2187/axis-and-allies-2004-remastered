# Files the mod writes into the game folder. Every feature records what it wrote in
# <game>\Remastered\<Feature>.files, so it can remove exactly that again (uninstall, or before
# writing a new version). Paths are relative to the game folder, with forward slashes.

function Get-GamePath {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$RelativePath)
  Join-Path $Context.GameDir ($RelativePath -replace '/', '\')
}

# Writes a file into the game folder and returns its relative path (for the feature's file list).
function Write-GameFile {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$RelativePath, [Parameter(Mandatory)][byte[]]$Bytes)
  $path = Get-GamePath $Context $RelativePath
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [IO.File]::WriteAllBytes($path, $Bytes)
  $RelativePath
}

function Get-TrackedFiles {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Feature)
  $list = Join-Path $Context.StateDir "$Feature.files"
  if (Test-Path $list) { @(Get-Content $list | Where-Object { $_ }) } else { @() }
}

function Save-TrackedFiles {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Feature, [string[]]$Files)
  New-Item -ItemType Directory -Force $Context.StateDir | Out-Null
  Set-Content -Path (Join-Path $Context.StateDir "$Feature.files") -Value @($Files | Sort-Object -Unique) -Encoding UTF8
}

function Add-TrackedFiles {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Feature, [string[]]$Files)
  Save-TrackedFiles $Context $Feature (@(Get-TrackedFiles $Context $Feature) + $Files)
}

# Deletes everything a feature wrote, then the folders that became empty.
function Remove-TrackedFiles {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Feature)
  $files = Get-TrackedFiles $Context $Feature
  Remove-GameFiles $Context $files
  Remove-Item (Join-Path $Context.StateDir "$Feature.files") -ErrorAction SilentlyContinue
}

function Remove-GameFiles {
  param([Parameter(Mandatory)]$Context, [string[]]$Files)
  $folders = @{}
  foreach ($file in $Files) {
    $path = Get-GamePath $Context $file
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    $folders[(Split-Path $path)] = $true
  }
  Remove-EmptyFolders $Context $folders.Keys
}

# Removes each folder and its parents while they are empty, never the game folder itself.
function Remove-EmptyFolders {
  param([Parameter(Mandatory)]$Context, [string[]]$Folders)
  $root = $Context.GameDir.TrimEnd('\')
  foreach ($folder in ($Folders | Sort-Object Length -Descending)) {
    $current = $folder
    while ($current -and $current.Length -gt $root.Length -and (Test-Path -LiteralPath $current) -and
           -not (Get-ChildItem -LiteralPath $current -Force | Select-Object -First 1)) {
      Remove-Item -LiteralPath $current -Force
      $current = Split-Path $current
    }
  }
}
