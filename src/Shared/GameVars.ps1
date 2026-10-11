# Engine settings files (data/AVars.tgi, data/UVars.tgi). Several features change values in the
# same file, so the override is shared: each feature sets only its own keys, starting from the
# override if it exists, else from the game's copy in Data.rwd. Loose files under data/ override
# Data.rwd. The overrides are tracked as the 'GameVars' file list.

function Set-GameVars {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][Collections.IDictionary]$Values)
  $relative = "data/$File"
  $path = Get-GamePath $Context $relative
  if (Test-Path $path) { $text = ConvertFrom-Latin1 ([IO.File]::ReadAllBytes($path)) }
  else { $text = Read-ArchiveText $Context.Data $File }
  foreach ($key in $Values.Keys) {
    $text = Set-VarValue -Text $text -Key $key -Value $Values[$key] -File $File
    Write-Detail "$key = $($Values[$key])"
  }
  Write-GameFile $Context $relative (ConvertTo-Latin1 $text) | Out-Null
  Add-TrackedFiles $Context 'GameVars' @($relative)
}

# Puts the game's own values back for these keys (when one feature is turned off).
function Reset-GameVars {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][string[]]$Keys)
  if (-not (Test-Path (Get-GamePath $Context "data/$File"))) { return }
  $stock = Read-ArchiveText $Context.Data $File
  $values = [ordered]@{}
  foreach ($key in $Keys) { $values[$key] = Get-VarValue -Text $stock -Key $key -File $File }
  Set-GameVars $Context $File $values
}

function Get-VarRegex {
  param([Parameter(Mandatory)][string]$Key)
  [regex]"(?m)^(\s*(?:int|float|flag)\s+$([regex]::Escape($Key))\s*=\s*)([^\s;]+)"
}

function Get-VarValue {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Key, [string]$File)
  $match = (Get-VarRegex $Key).Match($Text)
  if (-not $match.Success) { throw "$Key not found in $File" }
  $match.Groups[2].Value
}

function Set-VarValue {
  param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value, [string]$File)
  $regex = Get-VarRegex $Key
  if ($regex.Matches($Text).Count -ne 1) { throw "$Key not found exactly once in $File" }
  $regex.Replace($Text, '${1}' + $Value.Replace('$', '$$'))
}
