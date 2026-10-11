# Widescreen UI. The engine lays the UI out in a virtual InterfacePositioningWidth x
# InterfacePositioningHeight space (1024 x 768, AVars.tgi) and scales each axis to the screen, so
# wide screens stretched it. The virtual width becomes 768 * aspect (E extra units) and the
# layouts named in Widescreen.Rules.psd1 are moved so nothing stretches. The in-game control
# panel art is cut into five slices (left, stretchable middles, emblem, right) for the default UI,
# every nation skin and the HD art sets.

$script:WidescreenRules = (& ([scriptblock]::Create([IO.File]::ReadAllText("$PSScriptRoot\Widescreen.Rules.psd1")))).Rules |
  ForEach-Object { [pscustomobject]$_ }
# control panel art cuts, as positions in the 1024-unit layout (= fraction of the texture width)
$script:PanelCuts = 0, 320, 448, 624, 792, 1024
$script:PanelSlices = 'WsBgLeft', 'WsBgMidL', 'WsBgEmblem', 'WsBgMidR', 'WsBgRight'
$script:PanelVariants = 'UI/1280/Game/ControlPanel', 'UI/800/Game/ControlPanel', 'UI/Game/ControlPanel'
$script:Nations = 'USA', 'GBR', 'GER', 'RUS', 'JPN'
$script:LayoutCoordinate = [regex]'^(\s*)(L|T|R|B)(\s*=\s*)([+-]?)([0-9.]+)(%|r|b|t)?(.*)$'

function Install-Widescreen {
  param([Parameter(Mandatory)]$Context)
  $width = 768 * $Context.Screen.Width / $Context.Screen.Height
  $extra = $width - 1024
  Write-Step "Widescreen UI: virtual width $(Format-Number $width) ($($Context.Screen.Width):$($Context.Screen.Height))"
  Remove-TrackedFiles $Context 'Widescreen'
  Set-GameVars $Context 'AVars.tgi' @{ InterfacePositioningWidth = (Format-Number $width) }
  if ($extra -le 0) {
    Write-Detail 'aspect is 4:3 or narrower: original layouts'
    return
  }
  $files = @(Write-WidescreenLayouts $Context $extra) + @(Write-ControlPanelSlices $Context)
  Save-TrackedFiles $Context 'Widescreen' $files
  Write-Detail "$($files.Count) layout and control panel files"
}

function Uninstall-Widescreen {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Widescreen UI: original 4:3 layout'
  Remove-TrackedFiles $Context 'Widescreen'
  Reset-GameVars $Context 'AVars.tgi' @('InterfacePositioningWidth')
}

function Write-WidescreenLayouts {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][double]$Extra)
  $byFile = [ordered]@{}
  foreach ($rule in $script:WidescreenRules) {
    if (-not $byFile.Contains($rule.File)) { $byFile[$rule.File] = New-Object System.Collections.Generic.List[object] }
    $byFile[$rule.File].Add($rule)
  }
  foreach ($file in $byFile.Keys) {
    $lines = Split-Lines (Read-ArchiveText $Context.Data $file)
    # bottom-up, because width rules may insert lines
    foreach ($rule in ($byFile[$file] | Sort-Object Line -Descending)) {
      try { Invoke-LayoutRule $lines $rule $Extra } catch { throw "${file}: $_" }
    }
    $text = Join-Lines $lines
    if ($file -eq 'UI/Game/control_panel.tgi') { $text = Set-ControlPanelArt $text $Extra }
    Write-GameFile $Context "data/$file" (ConvertTo-Latin1 $text)
  }
}

function Invoke-LayoutRule {
  param([Parameter(Mandatory)]$Lines, [Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][double]$Extra)
  $start = $Rule.Line - 1
  if ($Rule.Kind -eq 'tooltip') { Move-AnchoredTooltip $Lines $Rule $Extra; return }
  $i = $start
  while ($i -lt $Lines.Count -and $Lines[$i].Text -notmatch '^\s*L\s*=') {
    $i++
    if ($i - $start -gt 40) { throw "no L assignment near line $($Rule.Line)" }
  }
  if ($Rule.Kind -eq 'width') { Set-LayoutWidth $Lines $i $Rule.Left $Rule.Width; return }
  for ($j = $i; $j -lt $Lines.Count -and $j - $i -lt 10 -and $Lines[$j].Text -notmatch '^\s*[\[}]'; $j++) {
    $match = $script:LayoutCoordinate.Match($Lines[$j].Text)
    if ($match.Success) { $Lines[$j].Text = Move-Coordinate $match $Rule $Extra }
  }
}

# One coordinate line moved by a rule (unchanged when the rule does not apply to it).
function Move-Coordinate {
  param([Parameter(Mandatory)]$Match, [Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][double]$Extra)
  $indent, $key, $equals, $sign, $suffix, $rest = 1, 2, 3, 4, 6, 7 | ForEach-Object { $Match.Groups[$_].Value }
  $value = ConvertTo-Number $Match.Groups[5].Value
  $relative = $sign -or $suffix  # +width, or percent/edge-relative values
  switch ($Rule.Kind) {
    'box' {
      if ($key -eq 'L') { return "${indent}L$equals$(Format-Number ($Extra / 2))$rest" }
      if ($key -eq 'R') { return "${indent}R$equals+1024$rest" }
    }
    { $_ -in 'right', 'center' } {
      $shift = if ($Rule.Kind -eq 'right') { $Extra } else { $Extra / 2 }
      if ($key -in 'L', 'R' -and -not $relative) { return "$indent$key$equals$(Format-Number ($value + $shift))$rest" }
    }
    'stretch' {
      if ($key -eq 'R' -and -not $suffix) { return "${indent}R$equals$sign$(Format-Number ($value + $Extra))$rest" }
    }
    'scale' {
      $factor = ($Rule.Parent + $Extra) / $Rule.Parent  # child of a parent that was stretched by E
      if ($key -in 'L', 'R' -and -not $suffix) { return "$indent$key$equals$sign$(Format-Number ($value * $factor))$rest" }
    }
  }
  $Match.Value
}

# Sets L and the width (R = +width) of the coordinate run starting at line $At.
function Set-LayoutWidth {
  param([Parameter(Mandatory)]$Lines, [Parameter(Mandatory)][int]$At, [Parameter(Mandatory)][double]$Left, [Parameter(Mandatory)][double]$Width)
  $match = $script:LayoutCoordinate.Match($Lines[$At].Text)
  $indent, $equals = $match.Groups[1].Value, $match.Groups[3].Value
  $Lines[$At].Text = "${indent}L$equals$(Format-Number $Left)$($match.Groups[7].Value)"
  $rightLine = "${indent}R$equals+$(Format-Number $Width)"
  $last = $At
  for ($j = $At + 1; $j -lt $Lines.Count -and $j - $At -lt 6; $j++) {
    $coordinate = $script:LayoutCoordinate.Match($Lines[$j].Text)
    if (-not $coordinate.Success) { break }
    if ($coordinate.Groups[2].Value -eq 'R') { $Lines[$j].Text = $rightLine; return }
    $last = $j
  }
  $Lines.Insert($last + 1, [pscustomobject]@{ Text = $rightLine; End = $Lines[$last].End })
}

function Move-AnchoredTooltip {
  param([Parameter(Mandatory)]$Lines, [Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][double]$Extra)
  $line = $Lines[$Rule.Line - 1]
  $match = [regex]::Match($line.Text, '^(\s*float\s+anchored_tooltip_x\s*=\s*)([0-9.]+)(.*)$')
  if (-not $match.Success) { throw "no anchored_tooltip_x on line $($Rule.Line)" }
  $shift = if ($Rule.Anchor -eq 'right') { $Extra } else { $Extra / 2 }
  $line.Text = $match.Groups[1].Value + (Format-Number ((ConvertTo-Number $match.Groups[2].Value) + $shift)) + $match.Groups[3].Value
}

# Replaces the single stretched control panel background with five slices.
function Set-ControlPanelArt {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][double]$Extra)
  $c = $script:PanelCuts
  $lefts = $c[0], $c[1], ($c[2] + $Extra / 2), ($c[3] + $Extra / 2), ($c[4] + $Extra)
  $widths = ($c[1] - $c[0]), ($c[2] - $c[1] + $Extra / 2), ($c[3] - $c[2]), ($c[4] - $c[3] + $Extra / 2), ($c[5] - $c[4])
  $blocks = for ($i = 0; $i -lt 5; $i++) {
    @("`t`t[Child Template=DecalVE]", "`t`t{",
      "`t`t`ttexture = /UI/%s/Game/ControlPanel/$($script:PanelSlices[$i]).tga",
      "`t`t`tL = $(Format-Number $lefts[$i])", "`t`t`tT = 0", "`t`t`tR = +$(Format-Number $widths[$i])", "`t`t`tB = 100%",
      "`t`t`tclient_L = 0%", "`t`t`tclient_T = 170b", "`t`t`tclient_R = 100%", "`t`t`tclient_B = 100%",
      "`t`t}") -join "`r`n"
  }
  # several decals with the same 'when' state need validation off (as staging.tgi does)
  $replacement = "`t`tvalidate_decal_children = false`r`n" + ($blocks -join "`r`n")
  $background = [regex]'(?s)\t\t\[Child Template=DecalVE\]\r?\n\t\t\{\r?\n\t\t\ttexture = /UI/%s/Game/ControlPanel/Background\.tga.*?\r?\n\t\t\}'
  if (-not $background.IsMatch($Text)) { throw 'control panel background decal not found' }
  $background.Replace($Text, $replacement.Replace('$', '$$'), 1)
}

# Cuts every control panel background (shipped art, nation skins, HD art sets) into the slices.
function Write-ControlPanelSlices {
  param([Parameter(Mandatory)]$Context)
  foreach ($variant in $script:PanelVariants) {
    Write-PanelSlices $Context (Read-ArchiveEntry $Context.Data "$variant/Background.tga") 'data' $variant
  }
  foreach ($nation in $script:Nations) {
    $skin = Open-GameArchive (Get-GamePath $Context "skins/$nation.rwd")
    try {
      foreach ($variant in $script:PanelVariants) {
        if (Test-ArchiveEntry $skin "$variant/Background.tga") {
          Write-PanelSlices $Context (Read-ArchiveEntry $skin "$variant/Background.tga") "skins/$nation" $variant
        }
      }
    } finally { Close-GameArchive $skin }
  }
  foreach ($root in @('data') + @($script:Nations | ForEach-Object { "skins/$_" })) {
    $folder = Get-GamePath $Context $root
    foreach ($background in Get-ChildItem "$folder\UI\*\Game\ControlPanel\Background.tga" -ErrorAction SilentlyContinue) {
      $set = $background.Directory.Parent.Parent.Name
      if ($set -match '^\d+$' -and $set -notin '800', '1280') {
        Write-PanelSlices $Context ([IO.File]::ReadAllBytes($background.FullName)) $root "UI/$set/Game/ControlPanel"
      }
    }
  }
}

function Write-PanelSlices {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][byte[]]$Background, [Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Variant)
  $width = Get-TgaWidth $Background
  $xs = $script:PanelCuts | ForEach-Object { [int][math]::Round($_ * $width / 1024) }
  for ($i = 0; $i -lt 5; $i++) {
    Write-GameFile $Context "$Root/$Variant/$($script:PanelSlices[$i]).tga" (Get-TgaColumns $Background $xs[$i] $xs[$i + 1])
  }
}
