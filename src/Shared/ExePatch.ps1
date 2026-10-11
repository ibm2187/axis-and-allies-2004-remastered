# Small, reversible byte patches to AA.exe (v1.0.5.0, build 4129.7). Every patch knows the
# original bytes, so a different build is refused instead of being damaged.

function New-ExePatch {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][int]$Offset,
    [Parameter(Mandatory)][byte[]]$Original,
    [Parameter(Mandatory)][byte[]]$Patched,
    [Parameter(Mandatory)][string]$Description
  )
  [pscustomobject]@{ Name = $Name; Offset = $Offset; Original = $Original; Patched = $Patched; Description = $Description }
}

function Get-ExePatchState {
  param([Parameter(Mandatory)][byte[]]$Exe, [Parameter(Mandatory)]$Patch)
  if (Test-BytesAt $Exe $Patch.Offset $Patch.Patched) { return 'Applied' }
  if (Test-BytesAt $Exe $Patch.Offset $Patch.Original) { return 'Original' }
  'Unknown'
}

function Test-BytesAt {
  param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)][int]$Offset, [Parameter(Mandatory)][byte[]]$Expected)
  for ($i = 0; $i -lt $Expected.Length; $i++) {
    if ($Bytes[$Offset + $i] -ne $Expected[$i]) { return $false }
  }
  $true
}

function Set-ExePatches {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][object[]]$Patches, [Parameter(Mandatory)][ValidateSet('Applied', 'Original')][string]$State)
  $path = Get-GamePath $Context 'AA.exe'
  $exe = [IO.File]::ReadAllBytes($path)
  $changed = $false
  foreach ($patch in $Patches) {
    $current = Get-ExePatchState $exe $patch
    if ($current -eq 'Unknown') {
      throw "AA.exe has unexpected bytes at 0x$($patch.Offset.ToString('X')) ($($patch.Name)). Only the v1.0.5.0 (build 4129.7) executable is supported."
    }
    if ($current -ne $State) {
      [byte[]]$bytes = if ($State -eq 'Applied') { $patch.Patched } else { $patch.Original }
      [Array]::Copy($bytes, 0, $exe, $patch.Offset, $bytes.Length)
      $changed = $true
    }
    Write-Detail "$($patch.Description): $($State.ToLower())"
  }
  if ($changed) {
    Set-ItemProperty -LiteralPath $path -Name IsReadOnly -Value $false
    [IO.File]::WriteAllBytes($path, $exe)
  }
}
