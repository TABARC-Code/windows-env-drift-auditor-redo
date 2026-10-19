# TABARC-Code
# Snapshot the environment to JSON.
# Notes:
# - Best-effort. Windows doesn't give you one clean truth source for "installed software".
# - We collect enough to spot drift, not to write a biography.

[CmdletBinding()]
param(
  [string]$OutDir = "$PSScriptRoot\snapshots",
  [string[]]$ToolNames = @("python","git","node","npm","pwsh","dotnet"),
  [switch]$IncludeSensitive
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$out = Join-Path $OutDir "env_$ts.json"

function NormPath([string]$p){
  if (-not $p) { return $null }
  $p.Trim() -replace '[\\/]+','\\' 
}

# Keep credential-bearing environment values out of snapshots by default.
$secretNamePattern = '(?i)(PASSWORD|PASSWD|TOKEN|SECRET|CREDENTIAL|AUTH|API.?KEY|ACCESS.?KEY|PRIVATE.?KEY|SESSION|COOKIE|CONNECTION.?STRING)'
$envVars = Get-ChildItem Env: | Sort-Object Name | ForEach-Object {
  $sensitive = $_.Name -match $secretNamePattern
  [pscustomobject]@{
    name = $_.Name
    value = if ($sensitive -and -not $IncludeSensitive) { '[REDACTED]' } else { $_.Value }
    redacted = [bool]($sensitive -and -not $IncludeSensitive)
  }
}

$pathRaw = $env:PATH
$pathParts = @()
if ($pathRaw) {
  $pathParts = $pathRaw -split ';' | ForEach-Object { NormPath $_ } | Where-Object { $_ } | Select-Object -Unique
}

# Uninstall keys (both 32 and 64)
$uninstallPaths = @(
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = @()
foreach($p in $uninstallPaths){
  try {
    $apps += Get-ItemProperty $p -ErrorAction SilentlyContinue | ForEach-Object {
      if (-not $_.PSObject.Properties['DisplayName'] -or -not $_.DisplayName) { return }
      [pscustomobject]@{
        name = $_.DisplayName
        version = if ($_.PSObject.Properties['DisplayVersion']) { $_.DisplayVersion } else { $null }
        publisher = if ($_.PSObject.Properties['Publisher']) { $_.Publisher } else { $null }
      }
    }
  } catch {}
}
$apps = $apps | Sort-Object name -Unique

$tasks = @()
try {
  $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Select-Object TaskName, TaskPath, State
} catch {}

$services = @()
try {
  $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.StartType -in "Automatic","AutomaticDelayedStart" } |
    Select-Object Name, DisplayName, Status, StartType
} catch {}

$tools = @()
foreach($t in $ToolNames){
  $cmd = Get-Command $t -ErrorAction SilentlyContinue
  $tools += [pscustomobject]@{
    name=$t
    found=([bool]$cmd)
    source=if($cmd){$cmd.Source}else{$null}
    version=(
      try {
        if($t -eq "python"){ (& python --version 2>&1) -join " " }
        elseif($t -eq "git"){ (& git --version 2>&1) -join " " }
        elseif($t -eq "node"){ (& node --version 2>&1) -join " " }
        elseif($t -eq "npm"){ (& npm --version 2>&1) -join " " }
        elseif($t -eq "pwsh"){ (& pwsh --version 2>&1) -join " " }
        elseif($t -eq "dotnet"){ (& dotnet --version 2>&1) -join " " }
        else { $null }
      } catch { $null }
    )
  }
}

$data = [ordered]@{
  sensitiveValuesIncluded = [bool]$IncludeSensitive
  time=(Get-Date).ToString("o")
  computer=$env:COMPUTERNAME
  user=$env:USERNAME
  env=$envVars
  path=$pathParts
  apps=$apps
  tasks=$tasks
  services=$services
  tools=$tools
}

$data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Wrote $out"
