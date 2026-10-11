# Questions and dialogs for the double-click installer (Install.cmd / Uninstall.cmd).

function Read-YesNo {
  param([Parameter(Mandatory)][string]$Question, [bool]$Default = $true)
  $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
  while ($true) {
    $answer = (Read-Host "$Question $hint").Trim().ToLower()
    if (-not $answer) { return $Default }
    if ($answer -in 'y', 'yes') { return $true }
    if ($answer -in 'n', 'no') { return $false }
  }
}

function Select-GameFolder {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Select the Axis & Allies folder (the one with AA.exe)'
  $dialog.ShowNewFolderButton = $false
  if ($dialog.ShowDialog() -eq 'OK') { $dialog.SelectedPath } else { $null }
}

# The game folder: given, found automatically and confirmed, or picked in a folder dialog.
function Resolve-GameFolder {
  param([string]$GameDir, [Parameter(Mandatory)][string]$ModDir, [switch]$Wizard)
  if ($GameDir) {
    if (-not (Test-GameDir $GameDir)) { throw "AA.exe and Data.rwd not found in $GameDir" }
    return (Resolve-Path -LiteralPath $GameDir).Path
  }
  $found = Find-GameDir $ModDir
  if ($found -and -not $Wizard) { return $found }
  if ($found) {
    Write-Host "Game folder: $found"
    if (Read-YesNo 'Use this folder?') { return $found }
  } elseif (-not $Wizard) {
    throw 'Game folder not found. Pass -GameDir "<folder with AA.exe>".'
  } else {
    Write-Host 'Game folder not found automatically. Select it in the window that opens.'
  }
  while ($true) {
    $picked = Select-GameFolder
    if (-not $picked) { throw 'No game folder selected.' }
    if (Test-GameDir $picked) { return $picked }
    Write-Note "AA.exe and Data.rwd are not in $picked; pick the game's own folder."
  }
}

# Runs the same .cmd again as administrator (game folders under Program Files need it).
function Start-Elevated {
  param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string]$GameDir)
  Write-Host 'The game folder needs administrator rights; continuing in a new window.'
  Start-Process -FilePath $Command -ArgumentList "`"$GameDir`"" -Verb RunAs
}

function Format-Size {
  param([Parameter(Mandatory)][double]$Bytes)
  if ($Bytes -ge 1GB) { '{0:N1} GB' -f ($Bytes / 1GB) } else { '{0:N0} MB' -f ($Bytes / 1MB) }
}
