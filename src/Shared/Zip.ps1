# Zip archives (dgVoodoo release, HD art pack parts), with the .NET classes that ship with
# Windows PowerShell 5.1.

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

function Read-ZipEntry {
  param([Parameter(Mandatory)][string]$ZipPath, [Parameter(Mandatory)][string]$EntryName)
  $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entry = $zip.Entries | Where-Object { $_.FullName -eq $EntryName } | Select-Object -First 1
    if (-not $entry) { throw "$EntryName not found in $ZipPath" }
    $stream = $entry.Open()
    $buffer = New-Object IO.MemoryStream
    try { $stream.CopyTo($buffer) } finally { $stream.Dispose() }
    , $buffer.ToArray()
  } finally { $zip.Dispose() }
}

# Extracts every file of a zip into the game folder, with its entry path mapped by $MapPath
# (a scriptblock: relative path in -> relative path out, or $null to skip). Returns the paths written.
function Expand-ZipIntoGame {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$ZipPath, [scriptblock]$MapPath = { param($p) $p })
  $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    foreach ($entry in $zip.Entries) {
      if (-not $entry.Name) { continue }  # folder entry
      $relative = & $MapPath ($entry.FullName -replace '\\', '/')
      if (-not $relative) { continue }
      $path = Get-GamePath $Context $relative
      New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path, $true)
      $relative
    }
  } finally { $zip.Dispose() }
}
