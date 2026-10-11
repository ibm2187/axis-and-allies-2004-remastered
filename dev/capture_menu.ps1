# Launch AA.exe, wait for a log pattern (default: main menu), optionally type console commands and wait
# for a second pattern, screenshot the screen, then close the game.
param([Parameter(Mandatory)][string]$GameDir, [Parameter(Mandatory)][string]$OutPng, [int]$SettleSeconds = 8,
      [string[]]$GameArgs = @(), [string]$WaitPattern = 'connect end MainMenuInterface', [int]$TimeoutSeconds = 120,
      [string[]]$ConsoleCommands = @(), [string]$ThenWaitPattern = '', [int]$ThenSettleSeconds = 8)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Cap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit, Size = 28)] struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(4)] public KEYBDINPUT ki; }
  [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
  static void Send(ushort scan, uint flags) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.scan = scan; i[0].ki.flags = flags;
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  // KEYEVENTF_SCANCODE = 8, KEYUP = 2, UNICODE = 4
  public static void Scan(ushort sc) { Send(sc, 8); System.Threading.Thread.Sleep(50); Send(sc, 8 | 2); System.Threading.Thread.Sleep(50); }
  public static void Char(char c) { Send(c, 4); Send(c, 4 | 2); System.Threading.Thread.Sleep(30); }
}
'@
[Cap]::SetProcessDPIAware() | Out-Null
$logDir = Join-Path $GameDir 'Logs'

function Wait-Log([string]$pattern, [int]$seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { throw "AA.exe exited early (code $($p.ExitCode))" }
    $script:log = Get-ChildItem $logDir -Filter 'log-*.log' | Where-Object { $_.Name -notmatch '-(crash|ok)\.log$' -and $_.LastWriteTime -gt $started } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($script:log -and (Select-String -Path $script:log.FullName -Pattern "$pattern|^ERROR" -Quiet)) { break }
    Start-Sleep -Milliseconds 500
  }
  if ($script:log -and (Select-String -Path $script:log.FullName -Pattern '^ERROR' -Quiet)) { throw "Game logged an ERROR: $($script:log.Name)" }
}

$started = Get-Date
$p = Start-Process -FilePath (Join-Path $GameDir 'AA.exe') -ArgumentList $GameArgs -WorkingDirectory $GameDir -PassThru
try {
  Wait-Log $WaitPattern $TimeoutSeconds
  Start-Sleep -Seconds $SettleSeconds
  $p.Refresh(); $h = $p.MainWindowHandle
  [Cap]::ShowWindow($h, 9) | Out-Null; [Cap]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Seconds 1
  if ($ConsoleCommands.Count) {
    foreach ($cmd in $ConsoleCommands) {
      [Cap]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 300
      [Cap]::Scan(0x29); Start-Sleep -Milliseconds 300   # ~ opens the console
      foreach ($ch in $cmd.ToCharArray()) { [Cap]::Char($ch) }
      [Cap]::Scan(0x1C); Start-Sleep -Milliseconds 300   # Enter
      [Cap]::Scan(0x29)                                  # close the console
    }
    if ($ThenWaitPattern) { Wait-Log $ThenWaitPattern $TimeoutSeconds }
    Start-Sleep -Seconds $ThenSettleSeconds
    [Cap]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Seconds 1
  }
  $r = New-Object Cap+RECT
  [Cap]::DwmGetWindowAttribute($h, 9, [ref]$r, [Runtime.InteropServices.Marshal]::SizeOf($r)) | Out-Null
  $w = $r.R - $r.L; $hgt = $r.B - $r.T
  $bmp = New-Object Drawing.Bitmap $w, $hgt
  $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $g.Dispose()
  $bmp.Save($OutPng, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  "Captured ${w}x${hgt} -> $OutPng (log $($log.Name))"
}
finally { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -Confirm:$false } }
