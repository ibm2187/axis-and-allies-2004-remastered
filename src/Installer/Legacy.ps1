# Installs made by the earlier Python-based install.ps1 (before the feature file lists in
# <game>\Remastered existed). Their files are removed once, then the features install as usual.

$script:LegacyLists = 'upscale-generated.txt', 'textures-generated.txt', 'widescreen-generated.txt', 'lighting-generated.txt'

function Test-LegacyInstall {
  param([Parameter(Mandatory)]$Context)
  @($script:LegacyLists | Where-Object { Test-Path (Get-GamePath $Context "data/$_") }).Count -gt 0
}

function Remove-LegacyInstall {
  param([Parameter(Mandatory)]$Context)
  if (-not (Test-LegacyInstall $Context)) { return }
  Write-Step 'Removing files of the earlier install'
  foreach ($list in $script:LegacyLists) {
    $path = Get-GamePath $Context "data/$list"
    if (-not (Test-Path $path)) { continue }
    $files = @(Get-Content $path | Where-Object { $_ } | ForEach-Object { $_ -replace '\\', '/' })
    Remove-GameFiles $Context $files
    Remove-Item $path
    Write-Detail "$list ($($files.Count) files)"
  }
  # written without a list: fonts, settings, dgVoodoo, staged DXVK, and UI art sets of older runs
  foreach ($relative in 'data/Fonts', 'data/UVars.tgi', 'data/AVars.tgi', 'D3D9.dll', 'dgVoodooCpl.exe', 'dgVoodoo.conf', '_wrappers') {
    Remove-Item -LiteralPath (Get-GamePath $Context $relative) -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-StaleArtSets $Context
}

# Loose UI art folders named by a screen width; the game itself only ships 800, 1024 and 1280.
function Remove-StaleArtSets {
  param([Parameter(Mandatory)]$Context)
  $roots = @('data') + @(Get-ChildItem (Get-GamePath $Context 'skins') -Directory -ErrorAction SilentlyContinue | ForEach-Object { "skins/$($_.Name)" })
  foreach ($root in $roots) {
    $folder = Get-GamePath $Context $root
    Get-ChildItem -LiteralPath $folder -Recurse -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^\d+$' -and $_.Name -notin '800', '1024', '1280' } |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
  }
  Remove-EmptyFolders $Context @(Get-ChildItem (Get-GamePath $Context 'data') -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
}
