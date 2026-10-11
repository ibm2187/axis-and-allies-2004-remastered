# Axis & Allies (2004) Remastered: loads the shared helpers, every feature slice and the
# installer that runs them. Runs on the Windows PowerShell 5.1 that ships with Windows 10/11.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$parts = @(Get-ChildItem "$PSScriptRoot\Shared\*.ps1") +
         @(Get-ChildItem "$PSScriptRoot\Features\*\*.ps1") +
         @(Get-ChildItem "$PSScriptRoot\Installer\*.ps1")
foreach ($part in $parts) { . $part.FullName }

Export-ModuleMember -Function Install-Remastered, Uninstall-Remastered, Build-HdPack
