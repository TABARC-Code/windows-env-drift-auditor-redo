# Check that snapshotting redacts a known credential-bearing environment value.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('snapshot-test-' + [guid]::NewGuid().ToString('N'))
$oldValue = [Environment]::GetEnvironmentVariable('TABARC_TEST_API_TOKEN')
New-Item -ItemType Directory -Path $root | Out-Null
try {
  $env:TABARC_TEST_API_TOKEN = 'secret-fixture-not-for-export'
  & (Join-Path $PSScriptRoot '..\Snapshot-Env.ps1') -OutDir $root -ToolNames @('git') | Out-Null
  $snapshot = @(Get-ChildItem -LiteralPath $root -Filter 'env_*.json' -File)
  if ($snapshot.Count -ne 1) { throw 'Expected one snapshot.' }
  $text = Get-Content -LiteralPath $snapshot[0].FullName -Raw
  if ($text.Contains('secret-fixture-not-for-export')) { throw 'Secret was stored in the snapshot.' }
  $data = $text | ConvertFrom-Json
  $token = @($data.env | Where-Object { $_.name -eq 'TABARC_TEST_API_TOKEN' })
  if ($token.Count -ne 1 -or $token[0].value -ne '[REDACTED]' -or -not $token[0].redacted) {
    throw 'Credential value was not redacted.'
  }
  Write-Host 'Snapshot redaction test passed.'
} finally {
  [Environment]::SetEnvironmentVariable('TABARC_TEST_API_TOKEN',$oldValue)
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
