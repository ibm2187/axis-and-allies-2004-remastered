# Finding the game folder and making sure the game is not running.

function Test-GameDir {
  param([string]$Path)
  $Path -and (Test-Path -LiteralPath (Join-Path $Path 'AA.exe')) -and (Test-Path -LiteralPath (Join-Path $Path 'Data.rwd'))
}

# Likely places, best first: next to or above the mod folder, installed programs, usual folders.
function Find-GameDir {
  param([Parameter(Mandatory)][string]$ModDir)
  $parent = Split-Path $ModDir
  $candidates = @($parent, $ModDir) + @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
  $candidates += Get-InstalledGameDirs
  foreach ($root in ${env:ProgramFiles(x86)}, $env:ProgramFiles, 'C:\Games') {
    if ($root) { $candidates += @('Atari\Axis & Allies', 'Axis & Allies', 'Axis and Allies') | ForEach-Object { Join-Path $root $_ } }
  }
  $candidates | Where-Object { Test-GameDir $_ } | Select-Object -First 1
}

function Get-InstalledGameDirs {
  $keys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  Get-ItemProperty $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Axis.*Allies' } |
    ForEach-Object { if ($_.InstallLocation) { $_.InstallLocation } elseif ($_.DisplayIcon) { Split-Path ($_.DisplayIcon -replace '"|,\d+$', '') } }
}

function Assert-GameClosed {
  param([Parameter(Mandatory)][string]$GameDir)
  $exe = Join-Path $GameDir 'AA.exe'
  if (Get-Process AA -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) {
    throw 'Axis & Allies is running. Close the game and run this again.'
  }
}

function Test-FolderWritable {
  param([Parameter(Mandatory)][string]$Path)
  $probe = Join-Path $Path ("remastered-write-test-" + [guid]::NewGuid())
  try { [IO.File]::WriteAllText($probe, ''); Remove-Item -LiteralPath $probe; $true } catch { $false }
}
