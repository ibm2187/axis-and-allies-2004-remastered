# What every feature works with: the game folder, the opened Data.rwd, the screen mode it is set
# up for, the mod's own folders and the installer options.

function New-RemasteredContext {
  param(
    [Parameter(Mandatory)][string]$GameDir,
    [Parameter(Mandatory)][string]$ModDir,
    $Screen,
    [hashtable]$Options = @{}
  )
  $defaults = @{ Supersample = 'off'; HdArt = $true; HdPackDir = $ModDir }
  foreach ($key in $defaults.Keys) { if (-not $Options.ContainsKey($key)) { $Options[$key] = $defaults[$key] } }
  [pscustomobject]@{
    GameDir  = (Resolve-Path -LiteralPath $GameDir).Path
    ModDir   = $ModDir
    StateDir = Join-Path $GameDir 'Remastered'
    CacheDir = Join-Path $ModDir '.cache'
    Data     = Open-GameArchive (Join-Path $GameDir 'Data.rwd')
    Screen   = $Screen
    Options  = [pscustomobject]$Options
  }
}

function Close-RemasteredContext {
  param([Parameter(Mandatory)]$Context)
  Close-GameArchive $Context.Data
}
