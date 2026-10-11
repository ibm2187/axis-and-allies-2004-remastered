# TGCK (.rwd) archive tool for Axis & Allies (2004, TimeGate).
# Layout: "TGCK" u32 ver, u32 nsections, sections..., then 3 trailing 96-byte section
# descriptors (Header/Files/Footer: 64-byte UTF-16 name + offset, size, ptr, size as u64).
# Footer (directory): u32 count, then per entry: u16 nameLen, UTF-16 name, u64 offset,
# u64 size, u32 0, u32 unknown (hash?). Entry offsets are relative to the Files section.
param(
  [Parameter(Mandatory)][string]$Archive,
  [string]$OutDir,
  [string]$Filter = '\.(tgi|lst|txt|ini|tgs|xml|csv)$',
  [string]$ListFile
)
$ErrorActionPreference = 'Stop'
$fs = [IO.File]::OpenRead((Resolve-Path $Archive))
$br = New-Object IO.BinaryReader($fs)
try {
  $fs.Seek(-288, 'End') | Out-Null
  $sections = @{}
  for ($i = 0; $i -lt 3; $i++) {
    $name = [Text.Encoding]::Unicode.GetString($br.ReadBytes(64)).TrimEnd([char]0)
    $off = $br.ReadInt64(); $size = $br.ReadInt64(); $null = $br.ReadInt64(); $null = $br.ReadInt64()
    $sections[$name] = @($off, $size)
  }
  $fs.Seek($sections['Footer'][0], 'Begin') | Out-Null
  $count = $br.ReadUInt32()
  $entries = New-Object System.Collections.Generic.List[object]
  for ($i = 0; $i -lt $count; $i++) {
    $len = $br.ReadUInt16()
    $name = [Text.Encoding]::Unicode.GetString($br.ReadBytes($len * 2))
    $off = $br.ReadInt64(); $size = $br.ReadInt64(); $z = $br.ReadUInt32(); $h = $br.ReadUInt32()
    $entries.Add([pscustomobject]@{Name = $name; Offset = $off; Size = $size; Flag = $z; Hash = $h })
  }
  "Entries: $count"
  if ($ListFile) { $entries | ForEach-Object { "{0}`t{1}" -f $_.Size, $_.Name } | Set-Content -Encoding utf8 $ListFile }
  if ($OutDir) {
    $n = 0
    foreach ($e in $entries) {
      if ($e.Name -notmatch $Filter) { continue }
      $dest = Join-Path $OutDir ($e.Name -replace '/', '\')
      New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
      $fs.Seek($sections['Files'][0] + $e.Offset, 'Begin') | Out-Null
      [IO.File]::WriteAllBytes($dest, $br.ReadBytes([int]$e.Size))
      $n++
    }
    "Extracted: $n"
  }
}
finally { $br.Close() }
