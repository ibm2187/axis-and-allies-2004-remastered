# Screen resolution: detects the monitor's native mode (the other features size the UI art and the
# widescreen layout for it) and makes it the game's resolution, so the first start is already sharp.
# The game saves its settings in Documents/A&A/data/User/UVars.tgi; the previous values are kept
# in the mod's state folder and put back on uninstall.

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RemasteredDisplay {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
    public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
  }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE devMode);
  // Current mode of the primary display in physical pixels, whatever the DPI scaling.
  public static int[] PrimaryMode() {
    var mode = new DEVMODE();
    mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
    if (!EnumDisplaySettings(null, -1, ref mode)) return null;
    return new int[] { mode.dmPelsWidth, mode.dmPelsHeight };
  }
}
'@

function Get-NativeResolution {
  $mode = [RemasteredDisplay]::PrimaryMode()
  if (-not $mode) { throw 'Could not read the screen resolution; pass -Resolution WIDTHxHEIGHT.' }
  [pscustomobject]@{ Width = $mode[0]; Height = $mode[1] }
}

function Install-Display {
  param([Parameter(Mandatory)]$Context)
  $screen = $Context.Screen
  Write-Step "Game resolution: $($screen.Width) x $($screen.Height)"
  $settings = Get-UserSettingsPath
  $text = if (Test-Path $settings) { ConvertFrom-Latin1 ([IO.File]::ReadAllBytes($settings)) } else { "[Vars]`r`n{`r`n}`r`n" }
  Save-PreviousResolution $Context $text
  $text = Set-UserSetting $text 'ResolutionX' $screen.Width
  $text = Set-UserSetting $text 'ResolutionY' $screen.Height
  New-Item -ItemType Directory -Force (Split-Path $settings) | Out-Null
  [IO.File]::WriteAllBytes($settings, (ConvertTo-Latin1 $text))
  Write-Detail $settings
}

function Uninstall-Display {
  param([Parameter(Mandatory)]$Context)
  $state = Join-Path $Context.StateDir 'Display.json'
  $settings = Get-UserSettingsPath
  if (-not (Test-Path $state) -or -not (Test-Path $settings)) { return }
  Write-Step 'Game resolution: previous setting'
  $previous = Get-Content $state -Raw | ConvertFrom-Json
  $text = ConvertFrom-Latin1 ([IO.File]::ReadAllBytes($settings))
  foreach ($key in 'ResolutionX', 'ResolutionY') {
    $value = $previous.$key
    $text = if ($value) { Set-UserSetting $text $key $value } else { Remove-UserSetting $text $key }
  }
  [IO.File]::WriteAllBytes($settings, (ConvertTo-Latin1 $text))
  Remove-Item $state
}

function Get-UserSettingsPath {
  Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'A&A\data\User\UVars.tgi'
}

# Keeps the player's own resolution from before the first install (later installs keep it too).
function Save-PreviousResolution {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Text)
  $state = Join-Path $Context.StateDir 'Display.json'
  if (Test-Path $state) { return }
  New-Item -ItemType Directory -Force $Context.StateDir | Out-Null
  [pscustomobject]@{ ResolutionX = Get-UserSetting $Text 'ResolutionX'; ResolutionY = Get-UserSetting $Text 'ResolutionY' } |
    ConvertTo-Json | Set-Content $state -Encoding UTF8
}

function Get-UserSetting {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Key)
  $match = [regex]::Match($Text, "(?m)^\s*int\s+$Key\s*=\s*(\d+)")
  if ($match.Success) { $match.Groups[1].Value } else { $null }
}

function Set-UserSetting {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
  $line = [regex]"(?m)^(\s*int\s+$Key\s*=\s*)\d+"
  if ($line.IsMatch($Text)) { return $line.Replace($Text, "`${1}$Value") }
  $end = $Text.LastIndexOf('}')
  $Text.Insert($end, "`tint`t$Key = $Value`r`n")
}

function Remove-UserSetting {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Key)
  $Text -replace "(?m)^\s*int\s+$Key\s*=\s*\d+\r?\n", ''
}
