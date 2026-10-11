# Font crash fix and DPI-independent text size.
#
# - On current Windows the engine aborts with "Processing non-Unicode TrueType font" on the Korean
#   GulimChe character sets and on Arial. The GulimChe sets are dropped; Arial is replaced by
#   Liberation Sans Bold (SIL OFL, metric-compatible with Arial), loaded from a file through the
#   same GDI+ path as the game's own A&A.TTF. If it can't be downloaded, Tahoma is used.
# - GDI+ created the fonts in points, so text grew with Windows display scaling (1.5x at 150%) and
#   overflowed its cells, clipping g/j/p/q/y. AA.exe is patched to create them in pixels, and the
#   sizes of the former file fonts are scaled by 4/3 (points at 96 DPI) to keep the original look.
#   Former Arial fonts were drawn at their plain size and keep it.

$script:FontFiles = 'font_large.tgi', 'font_medium.tgi', 'font_metagame.tgi', 'font_small.tgi', 'font_tiny.tgi'
$script:LiberationVersion = '2.1.5'
$script:LiberationFont = 'LiberationSans-Bold.ttf'

function Get-FontsPatches {
  @(New-ExePatch -Name 'font-unit-pixel' -Offset 0x3089CF -Original 0x6A, 0x03 -Patched 0x6A, 0x02 `
      -Description 'GDI+ fonts in pixels instead of points (push at VA 0x7089CF)')
}

function Install-Fonts {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Fonts: crash fix and DPI-independent text size'
  Remove-TrackedFiles $Context 'Fonts'
  $files = @()
  $liberation = Get-LiberationFont $Context
  if ($liberation) {
    $files += Write-GameFile $Context "data/Fonts/TrueType/$script:LiberationFont" ([IO.File]::ReadAllBytes((Join-Path $liberation $script:LiberationFont)))
    $files += Write-GameFile $Context 'data/Fonts/TrueType/LiberationSans-LICENSE.txt' ([IO.File]::ReadAllBytes((Join-Path $liberation 'LICENSE')))
    $replacement = "/fonts/truetype/$script:LiberationFont"
  } else {
    $replacement = 'Tahoma'
  }
  foreach ($file in $script:FontFiles) {
    $text = Convert-FontFile (Read-ArchiveText $Context.Data "Fonts/$file") $replacement
    $files += Write-GameFile $Context "data/Fonts/$file" (ConvertTo-Latin1 $text)
  }
  Save-TrackedFiles $Context 'Fonts' $files
  Write-Detail "$($script:FontFiles.Count) font files, Arial -> $replacement"
  Set-ExePatches $Context (Get-FontsPatches) 'Applied'
}

function Uninstall-Fonts {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Fonts: original'
  Remove-TrackedFiles $Context 'Fonts'
  Set-ExePatches $Context (Get-FontsPatches) 'Original'
}

# Downloads and unpacks Liberation Sans once; returns its folder, or $null when that fails.
function Get-LiberationFont {
  param([Parameter(Mandatory)]$Context)
  $folder = Join-Path $Context.CacheDir "liberation-fonts-ttf-$script:LiberationVersion"
  if (Test-Path (Join-Path $folder $script:LiberationFont)) { return $folder }
  try {
    $url = "https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-$script:LiberationVersion.tar.gz"
    $archive = Get-CachedDownload $Context -Url $url -FileName "liberation-fonts-ttf-$script:LiberationVersion.tar.gz"
    & (Join-Path $env:SystemRoot 'System32\tar.exe') -xzf $archive -C $Context.CacheDir  # Windows' own bsdtar
    if ($LASTEXITCODE) { throw "tar exit code $LASTEXITCODE" }
    $folder
  } catch {
    Write-Note "Liberation Sans download failed ($_); using Tahoma"
    $null
  }
}

function Convert-FontFile {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Replacement)
  $gulimChe = '[ \t]*\[CharacterSet\][ \t]*\r?\n[ \t]*ids[ \t]*=[ \t]*hangul_\w+[^\n]*\n[ \t]*font[ \t]*=[ \t]*GulimChe[^\n]*\n?'
  $Text = [regex]::Replace($Text, $gulimChe, '')
  $fontBlock = '(?s)\[Font template = Font\].*?(?=\[Font template = Font\]|\z)'
  [regex]::Replace($Text, $fontBlock, { param($block) Convert-FontBlock $block.Value $Replacement })
}

function Convert-FontBlock {
  param([Parameter(Mandatory)][string]$Block, [Parameter(Mandatory)][string]$Replacement)
  $base = [regex]::Match($Block, '(?s)ids\s*=\s*base.*?\n\s*font\s*=\s*(\S+)')
  # only fonts that were file fonts originally (A&A.TTF) went through GDI+ in points
  if (-not $base.Success -or $base.Groups[1].Value.StartsWith('/')) {
    $sizes = '(?m)^([ \t]*(?:size|backup_font_size|use_backup_font_when_smaller_than)[ \t]*=[ \t]*)(\d+)'
    $Block = [regex]::Replace($Block, $sizes, { param($m) $m.Groups[1].Value + [math]::Max(1, [math]::Round([int]$m.Groups[2].Value * 4 / 3)) })
  }
  [regex]::Replace($Block, '(?m)^([ \t]*(?:backup_)?font[ \t]*=[ \t]*)Arial([ \t]*\r?)$', "`${1}$Replacement`${2}")
}
