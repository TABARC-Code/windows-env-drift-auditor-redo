# Tests for Change Detective with two local fixture snapshots.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('change-detective-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
  $old = [ordered]@{
    computer = 'FIXTURE-PC'
    time = '2026-10-01T10:00:00+00:00'
    env = @(
      @{ name = 'API_TOKEN'; value = '[REDACTED]'; redacted = $true },
      @{ name = 'TEST_SETTING'; value = 'one'; redacted = $false }
    )
    path = @('C:\Tools','C:\Windows')
    apps = @(@{ name = 'Editor'; version = '1.0'; publisher = 'Vendor' })
    services = @(@{ Name = 'ExampleService'; Status = 'Running'; StartType = 'Automatic' })
    tasks = @(@{ TaskPath = '\'; TaskName = 'Example'; State = 'Ready' })
    tools = @(@{ name = 'git'; found = $true; source = 'C:\git.exe'; version = '2.0' })
  }
  $new = [ordered]@{
    computer = 'FIXTURE-PC'
    time = '2026-10-02T10:00:00+00:00'
    env = @(
      @{ name = 'API_TOKEN'; value = '[REDACTED]'; redacted = $true },
      @{ name = 'TEST_SETTING'; value = 'two'; redacted = $false }
    )
    path = @('C:\Windows','C:\Tools')
    apps = @(@{ name = 'Editor'; version = '2.0'; publisher = 'Vendor' })
    services = @(@{ Name = 'ExampleService'; Status = 'Stopped'; StartType = 'Automatic' })
    tasks = @(@{ TaskPath = '\'; TaskName = 'Example'; State = 'Ready' })
    tools = @(@{ name = 'git'; found = $true; source = 'C:\git.exe'; version = '2.0' })
  }
  $oldPath = Join-Path $root 'old.json'
  $newPath = Join-Path $root 'new.json'
  $outPath = Join-Path $root 'changes.json'
  $old | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $oldPath
  $new | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $newPath

  & (Join-Path $PSScriptRoot '..\Change-Detective.ps1') -Old $oldPath -New $newPath -OutputJson $outPath
  if (-not (Test-Path -LiteralPath $outPath)) { throw 'Missing change report.' }
  $report = Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json
  if ($report.changeCount -lt 4) { throw "Expected several changes, got $($report.changeCount)." }
  if ('API_TOKEN' -notin $report.redactedEnvironmentValuesNotCompared) { throw 'Redacted environment variable not marked unverified.' }
  if (@($report.changes | Where-Object { $_.category -eq 'PATH' -and $_.change -eq 'reordered' }).Count -ne 1) { throw 'PATH reorder not reported.' }
  if (@($report.changes | Where-Object { $_.category -eq 'application' -and $_.item -eq 'Editor' }).Count -ne 1) { throw 'Application change not reported.' }
  Write-Host 'Change Detective fixture passed.'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
