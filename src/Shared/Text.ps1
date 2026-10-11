# Text helpers. The game's data files are Latin-1, and its numbers always use '.', whatever the
# Windows locale says.

$script:Latin1 = [Text.Encoding]::GetEncoding(28591)
$script:Invariant = [Globalization.CultureInfo]::InvariantCulture

function ConvertFrom-Latin1 {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  $script:Latin1.GetString($Bytes)
}

function ConvertTo-Latin1 {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
  , $script:Latin1.GetBytes($Text)
}

# 4 decimals without trailing zeros, the way the layout files write numbers (1365.3333, 82, 0.5).
function Format-Number {
  param([Parameter(Mandatory)][double]$Value)
  $Value.ToString('F4', $script:Invariant).TrimEnd('0').TrimEnd('.')
}

function ConvertTo-Number {
  param([Parameter(Mandatory)][string]$Text)
  [double]::Parse($Text, $script:Invariant)
}

# Splits text into lines the way the layout files need it: each line's content and its own line
# ending kept apart, so edited lines can be put back with their original endings.
function Split-Lines {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
  $lines = New-Object System.Collections.Generic.List[object]
  foreach ($m in [regex]::Matches($Text, '([^\r\n\x0b\x0c\x1c-\x1e\x85]*)(\r\n|[\r\n\x0b\x0c\x1c-\x1e\x85]|\z)')) {
    if ($m.Length -eq 0) { continue }
    $lines.Add([pscustomobject]@{ Text = $m.Groups[1].Value; End = $m.Groups[2].Value })
  }
  , $lines
}

function Join-Lines {
  param([Parameter(Mandatory)][System.Collections.Generic.List[object]]$Lines)
  -join ($Lines | ForEach-Object { $_.Text + $_.End })
}
