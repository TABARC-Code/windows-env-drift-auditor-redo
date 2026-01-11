# TABARC-Code
# Diff two env snapshots.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Old,
  [Parameter(Mandatory=$true)][string]$New
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Load([string]$p){
  if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
  Get-Content -Raw -LiteralPath $p | ConvertFrom-Json
}

$o = Load $Old
$n = Load $New

Write-Host "Comparing:"
Write-Host "  Old: $Old"
Write-Host "  New: $New"
Write-Host ""

# PATH diff
$pathAdded = Compare-Object $o.path $n.path -PassThru | Where-Object { $_.SideIndicator -eq "=>" }
$pathRemoved = Compare-Object $o.path $n.path -PassThru | Where-Object { $_.SideIndicator -eq "<=" }

Write-Host "PATH added:   $($pathAdded.Count)"
Write-Host "PATH removed: $($pathRemoved.Count)"
if($pathAdded.Count){ $pathAdded | ForEach-Object { Write-Host ("  + {0}" -f $_) } }
if($pathRemoved.Count){ $pathRemoved | ForEach-Object { Write-Host ("  - {0}" -f $_) } }
Write-Host ""

# Tools diff
$omap = @{}; foreach($t in $o.tools){ $omap[$t.name] = $t }
foreach($t in $n.tools){
  if (-not $omap.ContainsKey($t.name)) { continue }
  $a=$omap[$t.name]
  if ($a.found -ne $t.found){
    Write-Host ("Tool presence changed: {0} {1} -> {2}" -f $t.name, $a.found, $t.found)
  }
  if ($a.version -ne $t.version -and $t.version){
    Write-Host ("Tool version changed: {0} '{1}' -> '{2}'" -f $t.name, $a.version, $t.version)
  }
}

Write-Host ""
Write-Host "If something drifted and you didn't do it, check scheduled tasks and installers. That's usually where the rot starts."
