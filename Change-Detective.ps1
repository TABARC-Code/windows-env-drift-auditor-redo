# TABARC-Code
# Compare two environment snapshots and produce a structured change report.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Old,
  [Parameter(Mandatory=$true)][string]$New,
  [string]$OutputJson = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Snapshot([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Snapshot not found: $path" }
  $data = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  if (-not $data.time -or -not $data.computer) { throw "Invalid snapshot: $path" }
  return $data
}

function Map-Items($items,[string[]]$keys) {
  $map = @{}
  foreach ($item in $items) {
    if ($null -eq $item) { continue }
    $parts = @()
    foreach ($key in $keys) { $parts += [string]$item.$key }
    $id = $parts -join '|'
    if (-not $id.Trim('|')) { continue }
    $map[$id] = $item
  }
  return $map
}

$script:changes = New-Object System.Collections.ArrayList
$script:unverified = New-Object System.Collections.ArrayList

function Add-Change([string]$category,[string]$item,[string]$type,[string]$detail) {
  [void]$script:changes.Add([pscustomobject]@{
    category = $category
    item = $item
    change = $type
    detail = $detail
  })
}

function Compare-Category([string]$category,$before,$after,[string[]]$keys,[string[]]$properties) {
  $a = Map-Items $before $keys
  $b = Map-Items $after $keys
  $allKeys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
  foreach ($id in $allKeys) {
    if (-not $a.ContainsKey($id)) {
      Add-Change $category $id 'added' ''
      continue
    }
    if (-not $b.ContainsKey($id)) {
      Add-Change $category $id 'removed' ''
      continue
    }
    if ($category -eq 'environment' -and ($a[$id].redacted -or $b[$id].redacted)) {
      [void]$script:unverified.Add($id)
      continue
    }
    foreach ($prop in $properties) {
      if ([string]$a[$id].$prop -ne [string]$b[$id].$prop) {
        $detail = if ($category -eq 'environment') {
          'value changed (values withheld)'
        } else {
          "$prop changed: '$($a[$id].$prop)' -> '$($b[$id].$prop)'"
        }
        Add-Change $category $id 'modified' $detail
      }
    }
  }
}

$o = Read-Snapshot $Old
$n = Read-Snapshot $New
if ($o.computer -ne $n.computer) { throw 'Snapshots belong to different computers.' }
if ([datetimeoffset]$o.time -gt [datetimeoffset]$n.time) {
  throw 'Old snapshot must precede new snapshot.'
}

Compare-Category 'environment' $o.env $n.env @('name') @('value')
Compare-Category 'application' $o.apps $n.apps @('name') @('version','publisher')
Compare-Category 'scheduled-task' $o.tasks $n.tasks @('TaskPath','TaskName') @('State')
Compare-Category 'service' $o.services $n.services @('Name') @('Status','StartType')
Compare-Category 'tool' $o.tools $n.tools @('name') @('found','source','version')

$oldPath = @($o.path | Where-Object { $_ })
$newPath = @($n.path | Where-Object { $_ })
foreach ($entry in @($newPath | Where-Object { $oldPath -notcontains $_ })) {
  Add-Change 'PATH' $entry 'added' ''
}
foreach ($entry in @($oldPath | Where-Object { $newPath -notcontains $_ })) {
  Add-Change 'PATH' $entry 'removed' ''
}
if ($oldPath.Count -eq $newPath.Count -and
    ($oldPath -join [char]31) -cne ($newPath -join [char]31) -and
    (@($oldPath | Where-Object { $newPath -notcontains $_ }).Count -eq 0)) {
  Add-Change 'PATH' 'order' 'reordered' 'Search precedence may have changed.'
}

$report = [ordered]@{
  computer = $n.computer
  oldCapturedAt = $o.time
  newCapturedAt = $n.time
  changeCount = $script:changes.Count
  redactedEnvironmentValuesNotCompared = @($script:unverified | Sort-Object -Unique)
  changes = @($script:changes)
}

Write-Host "Computer: $($n.computer)"
Write-Host "Compared: $($o.time) -> $($n.time)"
Write-Host "Detected changes: $($script:changes.Count)"
if ($script:unverified.Count) {
  Write-Warning "Some environment values were redacted and could not be compared ($($script:unverified.Count) entries)."
}
foreach ($item in $script:changes) {
  Write-Host ("[{0}] {1} {2} {3}" -f $item.category,$item.change,$item.item,$item.detail)
}
Write-Host 'Changes are observations, not proof of what caused a problem.'

if ($OutputJson) {
  $folder = Split-Path -Parent ([IO.Path]::GetFullPath($OutputJson))
  if (-not (Test-Path -LiteralPath $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
  }
  $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputJson -Encoding UTF8
  Write-Host "Saved: $OutputJson"
}
