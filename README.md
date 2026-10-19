# windows-env-drift-auditor

Snapshot a Windows environment and diff it later, so you can prove what drifted instead of arguing with your past self.

Author: TABARC-Code  
Plugin URI: https://github.com/TABARC-Code/

## What it snapshots

- environment variables
- PATH entries (split + normalised).
- installed applications (best-effort).
- scheduled tasks summary.
- services (auto-start focus).
- basic tool presence (git, python, node, etc.)

## Scripts

- `Snapshot-Env.ps1`
- `Diff-Env.ps1`
- `Check-Tools.ps1`

## Quick start

```powershell
.\Snapshot-Env.ps1
# later...
.\Snapshot-Env.ps1
.\Diff-Env.ps1 -Old .\snapshots\env_OLD.json -New .\snapshots\env_NEW.json
```

## Notes

This repo won't magically heal your machine.
It’ll just point at the corpse and say which bits are missing.


## Sensitive data

`Snapshot-Env.ps1` now redacts environment variables with credential-like names by default. The snapshot marks these entries as `redacted`. The optional `-IncludeSensitive` flag stores their actual values and should only be used in a protected local environment. Name-based filtering is a precaution, not a guarantee that all secrets will be detected. Review and protect snapshots before sharing them.
