# zlib streams (map entries) and uncompressed TGA images (UI art).

function Expand-Zlib {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  $source = [IO.MemoryStream]::new($Bytes, 2, $Bytes.Length - 2)  # skip the 2-byte zlib header
  $deflate = [IO.Compression.DeflateStream]::new($source, [IO.Compression.CompressionMode]::Decompress)
  $output = [IO.MemoryStream]::new()
  try { $deflate.CopyTo($output) } finally { $deflate.Dispose() }
  , $output.ToArray()
}

function Compress-Zlib {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  $output = [IO.MemoryStream]::new()
  $output.WriteByte(0x78); $output.WriteByte(0xDA)
  $deflate = [IO.Compression.DeflateStream]::new($output, [IO.Compression.CompressionLevel]::Optimal, $true)
  try { $deflate.Write($Bytes, 0, $Bytes.Length) } finally { $deflate.Dispose() }
  $adler = Get-Adler32 $Bytes
  foreach ($shift in 24, 16, 8, 0) { $output.WriteByte([byte](($adler -shr $shift) -band 0xFF)) }
  , $output.ToArray()
}

function Get-Adler32 {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  [long]$a = 1; [long]$b = 0
  foreach ($byte in $Bytes) { $a = ($a + $byte) % 65521; $b = ($b + $a) % 65521 }
  ($b -shl 16) -bor $a
}

function Get-TgaWidth {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  [BitConverter]::ToUInt16($Bytes, 12)
}

# Columns From..To (exclusive) of an uncompressed 24/32-bit TGA, as a new TGA.
function Get-TgaColumns {
  param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)][int]$From, [Parameter(Mandatory)][int]$To)
  $idLength = $Bytes[0]
  $width = [BitConverter]::ToUInt16($Bytes, 12)
  $height = [BitConverter]::ToUInt16($Bytes, 14)
  $bitsPerPixel = $Bytes[16]
  if ($Bytes[1] -ne 0 -or $Bytes[2] -ne 2 -or $bitsPerPixel -notin 24, 32) {
    throw "unsupported TGA (type $($Bytes[2]), $bitsPerPixel bpp)"
  }
  $pixelSize = $bitsPerPixel / 8
  $rowSize = ($To - $From) * $pixelSize
  $result = [byte[]]::new(18 + $rowSize * $height)
  [Array]::Copy($Bytes, 0, $result, 0, 18)
  $result[0] = 0
  [Array]::Copy([BitConverter]::GetBytes([uint16]($To - $From)), 0, $result, 12, 2)
  $body = 18 + $idLength
  for ($y = 0; $y -lt $height; $y++) {
    [Array]::Copy($Bytes, $body + ($y * $width + $From) * $pixelSize, $result, 18 + $y * $rowSize, $rowSize)
  }
  , $result
}

# SHA-256 of a file as upper-case hex (what Get-FileHash returns; that cmdlet is missing when
# Windows PowerShell is started from PowerShell 7, whose module path it inherits).
function Get-FileSha256 {
  param([Parameter(Mandatory)][string]$Path)
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead($Path)
  try { -join ($sha.ComputeHash($stream) | ForEach-Object { $_.ToString('X2') }) }
  finally { $stream.Dispose(); $sha.Dispose() }
}
