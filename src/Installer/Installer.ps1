# Installs and uninstalls the feature slices, in order. Widescreen comes after HdArt because it
# also slices the HD control panel art; Display last, once everything else succeeded.

$script:Features = 'Compatibility', 'Renderer', 'Fonts', 'HdArt', 'Widescreen', 'Graphics', 'Lighting', 'Camera', 'Display'

function Install-Remastered {
  param(
    [Parameter(Mandatory)][string]$ModDir,
    [string]$GameDir,
    [string]$Resolution,
    [ValidateSet('off', '2x')][string]$Supersample = 'off',
    [switch]$NoHdArt,
    [string]$HdPackDir,
    [switch]$Wizard
  )
  Write-Host 'Axis & Allies (2004) Remastered: install' -ForegroundColor Green
  $GameDir = Resolve-GameFolder -GameDir $GameDir -ModDir $ModDir -Wizard:$Wizard
  Assert-GameClosed $GameDir
  if (-not (Test-FolderWritable $GameDir)) {
    if ($Wizard) { Start-Elevated (Join-Path $ModDir 'Install.cmd') $GameDir; return }
    throw "No write access to $GameDir; run as administrator."
  }
  $options = @{ Supersample = $Supersample; HdArt = -not $NoHdArt }
  if ($HdPackDir) { $options.HdPackDir = $HdPackDir }
  $context = New-RemasteredContext -GameDir $GameDir -ModDir $ModDir -Screen (Get-TargetScreen $Resolution) -Options $options
  try {
    Assert-SupportedGame $context
    Write-Host "Game folder: $($context.GameDir)"
    Write-Host "Screen:      $($context.Screen.Width) x $($context.Screen.Height)"
    if ($context.Options.HdArt) { $context.Options.HdArt = Confirm-HdArt $context -Wizard:$Wizard }
    Invoke-Logged $context 'install' {
      Remove-LegacyInstall $context
      foreach ($feature in $script:Features) { & "Install-$feature" $context }
    }
  } finally { Close-RemasteredContext $context }
  Write-Host ''
  Write-Host 'Done. Start the game with AA.exe as usual.' -ForegroundColor Green
}

function Uninstall-Remastered {
  param([Parameter(Mandatory)][string]$ModDir, [string]$GameDir, [switch]$Wizard)
  Write-Host 'Axis & Allies (2004) Remastered: uninstall' -ForegroundColor Green
  $GameDir = Resolve-GameFolder -GameDir $GameDir -ModDir $ModDir -Wizard:$Wizard
  Assert-GameClosed $GameDir
  if (-not (Test-FolderWritable $GameDir)) {
    if ($Wizard) { Start-Elevated (Join-Path $ModDir 'Uninstall.cmd') $GameDir; return }
    throw "No write access to $GameDir; run as administrator."
  }
  if ($Wizard -and -not (Read-YesNo "Remove the mod from $GameDir?")) { return }
  $context = New-RemasteredContext -GameDir $GameDir -ModDir $ModDir
  try {
    Invoke-Logged $context 'uninstall' {
      Remove-LegacyInstall $context
      $features = @($script:Features)
      [array]::Reverse($features)
      foreach ($feature in $features) { & "Uninstall-$feature" $context }
      Remove-TrackedFiles $context 'GameVars'
      Remove-Item -LiteralPath $context.StateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  } finally { Close-RemasteredContext $context }
  Write-Host ''
  Write-Host 'Done. The game is back to its original files.' -ForegroundColor Green
  if (Test-Path (Join-Path $GameDir 'dxgi.dll')) {
    Write-Note 'ReShade (dxgi.dll, ReShade.ini, reshade-shaders) was installed separately and is still there.'
  }
}

function Get-TargetScreen {
  param([string]$Resolution)
  if (-not $Resolution) { return Get-NativeResolution }
  $width, $height = $Resolution -split 'x'
  [pscustomobject]@{ Width = [int]$width; Height = [int]$height }
}

# Every byte the mod patches must be either original or already patched: that is the
# v1.0.5.0 (build 4129.7) executable this mod is made for.
function Assert-SupportedGame {
  param([Parameter(Mandatory)]$Context)
  $exe = [IO.File]::ReadAllBytes((Get-GamePath $Context 'AA.exe'))
  $patches = @(Get-CompatibilityPatches) + @(Get-FontsPatches) + @(Get-CameraPatches)
  if ($patches | Where-Object { (Get-ExePatchState $exe $_) -eq 'Unknown' }) {
    throw 'This AA.exe is not the v1.0.5.0 (build 4129.7) executable the mod supports; nothing was changed.'
  }
}

function Confirm-HdArt {
  param([Parameter(Mandatory)]$Context, [switch]$Wizard)
  if (-not (Test-HdPackAvailable)) { return $false }
  $download = Get-HdPackDownloadSize $Context
  if (-not $Wizard) { return $true }
  $question = if ($download) { "Install the HD art? It downloads $(Format-Size $download)." } else { 'Install the HD art (pack found next to the installer)?' }
  Read-YesNo $question
}

function Invoke-Logged {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
  $logs = Join-Path $Context.ModDir 'logs'
  New-Item -ItemType Directory -Force $logs | Out-Null
  $log = Join-Path $logs ("$Name-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
  $failure = $null
  Start-Transcript -Path $log | Out-Null
  try { & $Action }
  catch { $failure = $_; throw }
  finally {
    Stop-Transcript | Out-Null
    if ($failure) { Add-Content -LiteralPath $log -Value "FAILED: $failure`r`n$($failure.ScriptStackTrace)" }
    Write-Host "Log: $log"
  }
}
