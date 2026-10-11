# Reader for the game's TGCK archives (Data.rwd, skins/*.rwd).
#
# Layout: the last 288 bytes are three 96-byte section descriptors (Header, Files, Footer), each a
# 64-byte UTF-16 name followed by offset, size, ptr, size (u64). The Footer section is the
# directory: u32 count, then per entry a u16 name length, the UTF-16 name, u64 offset (relative to
# the Files section), u64 size, u32 zero, u32 unknown.

function Open-GameArchive {
  param([Parameter(Mandatory)][string]$Path)
  $stream = [IO.File]::OpenRead($Path)
  $reader = New-Object IO.BinaryReader($stream)
  $sections = @{}
  $stream.Seek(-288, 'End') | Out-Null
  for ($i = 0; $i -lt 3; $i++) {
    $name = [Text.Encoding]::Unicode.GetString($reader.ReadBytes(64)).TrimEnd([char]0)
    $sections[$name] = $reader.ReadInt64()
    $reader.ReadBytes(24) | Out-Null
  }
  $stream.Seek($sections['Footer'], 'Begin') | Out-Null
  $count = $reader.ReadUInt32()
  $entries = New-Object 'System.Collections.Generic.Dictionary[string,object]'
  $names = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $count; $i++) {
    $length = $reader.ReadUInt16()
    $name = [Text.Encoding]::Unicode.GetString($reader.ReadBytes($length * 2))
    $offset = $reader.ReadInt64()
    $size = $reader.ReadInt64()
    $reader.ReadBytes(8) | Out-Null
    $entries[$name.ToLowerInvariant()] = [pscustomobject]@{ Name = $name; Offset = $offset; Size = $size }
    $names.Add($name)
  }
  [pscustomobject]@{ Path = $Path; Reader = $reader; FilesBase = $sections['Files']; Entries = $entries; Names = $names }
}

function Close-GameArchive {
  param([Parameter(Mandatory)]$Archive)
  $Archive.Reader.Close()
}

function Test-ArchiveEntry {
  param([Parameter(Mandatory)]$Archive, [Parameter(Mandatory)][string]$Name)
  $Archive.Entries.ContainsKey($Name.ToLowerInvariant())
}

function Read-ArchiveEntry {
  param([Parameter(Mandatory)]$Archive, [Parameter(Mandatory)][string]$Name)
  $entry = $Archive.Entries[$Name.ToLowerInvariant()]
  if (-not $entry) { throw "$Name not found in $($Archive.Path)" }
  $Archive.Reader.BaseStream.Seek($Archive.FilesBase + $entry.Offset, 'Begin') | Out-Null
  , $Archive.Reader.ReadBytes([int]$entry.Size)
}

function Read-ArchiveText {
  param([Parameter(Mandatory)]$Archive, [Parameter(Mandatory)][string]$Name)
  ConvertFrom-Latin1 (Read-ArchiveEntry $Archive $Name)
}
