# Downloads. curl.exe ships with Windows 10 1803 and later: fast, resumable, with a progress bar.
# Invoke-WebRequest is the fallback (TLS 1.2 forced for Windows PowerShell 5.1).

function Save-WebFile {
  param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Path, [switch]$ShowProgress)
  New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
  $partial = "$Path.part"
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $arguments = @('--fail', '--location', '--retry', '3', '--output', $partial)
    if ($ShowProgress) { $arguments += @('--progress-bar', '--continue-at', '-') } else { $arguments += @('--silent', '--show-error') }
    & curl.exe @arguments $Url
    if ($LASTEXITCODE) { throw "Download failed ($Url), curl exit code $LASTEXITCODE" }
  } else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial
  }
  Move-Item -LiteralPath $partial -Destination $Path -Force
}

# Downloads into the mod's cache folder once and returns the local path.
function Get-CachedDownload {
  param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$FileName)
  $path = Join-Path $Context.CacheDir $FileName
  if (-not (Test-Path $path)) { Save-WebFile -Url $Url -Path $path }
  $path
}
