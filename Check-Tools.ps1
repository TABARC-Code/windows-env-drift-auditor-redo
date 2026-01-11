# TABARC-Code
# Quick tool presence check.

[CmdletBinding()]
param([string[]]$ToolNames = @("python","git","node","npm","pwsh","dotnet"))

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

foreach($t in $ToolNames){
  $cmd = Get-Command $t -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host ("OK   {0} -> {1}" -f $t, $cmd.Source)
  } else {
    Write-Host ("MISS {0}" -f $t)
  }
}
