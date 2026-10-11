# Console output. Write-Host also lands in the transcript log.

function Write-Step {
  param([Parameter(Mandatory)][string]$Message)
  Write-Host ''
  Write-Host "== $Message" -ForegroundColor Cyan
}

function Write-Detail {
  param([Parameter(Mandatory)][string]$Message)
  Write-Host "   $Message"
}

function Write-Note {
  param([Parameter(Mandatory)][string]$Message)
  Write-Host "   ! $Message" -ForegroundColor Yellow
}
