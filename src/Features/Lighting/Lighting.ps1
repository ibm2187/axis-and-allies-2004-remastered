# Relights the maps: less ambient light, a slightly warm sun.
#
# Every shipped map embeds its own light in the SUN entry of its .rmp (the Sun/*.tgi presets are
# not used): sun direction 0.41,0.41,-0.82, diffuse 1.0 and ambient 0.8 (1.0 on two). Units and
# buildings are lit ambient + diffuse * N.L, so anything facing the sun even slightly clipped to
# full brightness and models looked flat. The maps are written as loose overrides under data/Maps/
# with only the SUN colours changed; direction and specular stay as they were. Modified maps have
# different checksums, so LAN games need the same files on every PC.
#
# .rmp layout: "TGCK", u32 version, u32 count; entry data from byte 12; at the end, count 96-byte
# directory records (64-byte UTF-16 name, u64 offset, u64 stored size, u64 FILETIME, u64 size).
# SUN (134 bytes, zlib): i32 version, i32 1, i32 -1, then two sets of light colours: direction
# @12, diffuse @24, ambient @36, specular @48; diffuse @60, ambient @72, specular @84; ...

$script:LightingAmbient = 0.55, 0.57, 0.62
$script:LightingDiffuse = 1.0, 0.97, 0.90

function Install-Lighting {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Map lighting'
  Remove-TrackedFiles $Context 'Lighting'
  $maps = $Context.Data.Names | Where-Object { $_ -match '\.rmp$' } | Sort-Object
  $files = foreach ($map in $maps) {
    Write-GameFile $Context "data/$map" (Set-MapLight (Read-ArchiveEntry $Context.Data $map))
  }
  Save-TrackedFiles $Context 'Lighting' $files
  Write-Detail "relit $(@($files).Count) maps: ambient $($script:LightingAmbient -join '/'), sun $($script:LightingDiffuse -join '/')"
}

function Uninstall-Lighting {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Map lighting: original'
  Remove-TrackedFiles $Context 'Lighting'
}

function Set-MapLight {
  param([Parameter(Mandatory)][byte[]]$Map)
  $entries = Get-MapEntries $Map
  $output = New-Object IO.MemoryStream
  $output.Write($Map, 0, 12)
  $records = @{}
  foreach ($entry in ($entries | Sort-Object Offset)) {
    $data = New-Object byte[] $entry.StoredSize
    [Array]::Copy($Map, $entry.Offset, $data, 0, $entry.StoredSize)
    $size = $entry.Size
    if ($entry.Name -eq 'SUN') {
      $sun = Set-SunColors (Expand-Zlib $data)
      $data = Compress-Zlib $sun
      $size = $sun.Length
    }
    $records[$entry.Name] = New-MapRecord $entry $output.Position $data.Length $size
    $output.Write($data, 0, $data.Length)
  }
  foreach ($entry in $entries) { $output.Write($records[$entry.Name], 0, 96) }  # original order
  , $output.ToArray()
}

function Get-MapEntries {
  param([Parameter(Mandatory)][byte[]]$Map)
  if ([Text.Encoding]::ASCII.GetString($Map, 0, 4) -ne 'TGCK') { throw 'not a TGCK map' }
  $count = [BitConverter]::ToUInt32($Map, 8)
  $directory = $Map.Length - 96 * $count
  $position = 12
  $entries = for ($i = 0; $i -lt $count; $i++) {
    $at = $directory + 96 * $i
    [pscustomobject]@{
      Name       = [Text.Encoding]::Unicode.GetString($Map, $at, 64).TrimEnd([char]0)
      RawName    = $Map[$at..($at + 63)]
      Offset     = [BitConverter]::ToInt64($Map, $at + 64)
      StoredSize = [BitConverter]::ToInt64($Map, $at + 72)
      FileTime   = [BitConverter]::ToInt64($Map, $at + 80)
      Size       = [BitConverter]::ToInt64($Map, $at + 88)
    }
  }
  foreach ($entry in ($entries | Sort-Object Offset)) {
    if ($entry.Offset -ne $position) { throw "map entries are not contiguous ($($entry.Name))" }
    $position += $entry.StoredSize
  }
  if ($position -ne $directory) { throw 'unexpected data before the map directory' }
  $entries
}

function New-MapRecord {
  param([Parameter(Mandatory)]$Entry, [long]$Offset, [long]$StoredSize, [long]$Size)
  $record = New-Object byte[] 96
  [Array]::Copy([byte[]]$Entry.RawName, 0, $record, 0, 64)
  $at = 64
  foreach ($value in $Offset, $StoredSize, $Entry.FileTime, $Size) {
    [Array]::Copy([BitConverter]::GetBytes([long]$value), 0, $record, $at, 8)
    $at += 8
  }
  , $record
}

function Set-SunColors {
  param([Parameter(Mandatory)][byte[]]$Sun)
  if ($Sun.Length -ne 134) { throw 'unexpected SUN entry size' }
  $expected = 0.408, 0.408, -0.816  # the sun direction every shipped map uses
  for ($i = 0; $i -lt 3; $i++) {
    if ([math]::Abs([BitConverter]::ToSingle($Sun, 12 + 4 * $i) - $expected[$i]) -gt 0.01) { throw 'unexpected SUN direction' }
  }
  foreach ($offset in 24, 60) { Write-Floats $Sun $offset $script:LightingDiffuse }
  foreach ($offset in 36, 72) { Write-Floats $Sun $offset $script:LightingAmbient }
  , $Sun
}

function Write-Floats {
  param([Parameter(Mandatory)][byte[]]$Bytes, [int]$Offset, [double[]]$Values)
  foreach ($value in $Values) {
    [Array]::Copy([BitConverter]::GetBytes([single]$value), 0, $Bytes, $Offset, 4)
    $Offset += 4
  }
}
