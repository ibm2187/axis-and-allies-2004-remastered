# Launch AA.exe, wait for the main menu in its log, screenshot the game window, then close it.
param([Parameter(Mandatory)][string]$GameDir, [Parameter(Mandatory)][string]$OutPng, [int]$SettleSeconds = 8,
      [string[]]$GameArgs = @('ResolutionWindowed=1'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Cap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
}
'@
[Cap]::SetProcessDPIAware() | Out-Null
$logDir = Join-Path $GameDir 'Logs'
$started = Get-Date
$p = Start-Process -FilePath (Join-Path $GameDir 'AA.exe') -ArgumentList $GameArgs -WorkingDirectory $GameDir -PassThru
try {
  $deadline = (Get-Date).AddSeconds(120); $log = $null
  while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { throw "AA.exe exited early (code $($p.ExitCode))" }
    $log = Get-ChildItem $logDir -Filter 'log-*.log' | Where-Object { $_.Name -notmatch '-(crash|ok)\.log$' -and $_.LastWriteTime -gt $started } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($log -and (Select-String -Path $log.FullName -Pattern 'connect end MainMenuInterface|^ERROR' -Quiet)) { break }
    Start-Sleep -Milliseconds 500
  }
  if ($log -and (Select-String -Path $log.FullName -Pattern '^ERROR' -Quiet)) { throw "Game logged an ERROR: $($log.Name)" }
  Start-Sleep -Seconds $SettleSeconds
  $p.Refresh(); $h = $p.MainWindowHandle
  [Cap]::ShowWindow($h, 9) | Out-Null; [Cap]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Seconds 2
  $r = New-Object Cap+RECT
  [Cap]::DwmGetWindowAttribute($h, 9, [ref]$r, [Runtime.InteropServices.Marshal]::SizeOf($r)) | Out-Null
  $w = $r.R - $r.L; $hgt = $r.B - $r.T
  $bmp = New-Object Drawing.Bitmap $w, $hgt
  $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $g.Dispose()
  $bmp.Save($OutPng, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  "Captured ${w}x${hgt} -> $OutPng (log $($log.Name))"
}
finally { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -Confirm:$false } }
