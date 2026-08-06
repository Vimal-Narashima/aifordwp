# Temp File Cleanup Script (PowerShell 5.1)

This document explains how to use `temp-file-cleanup.ps1` safely on Windows endpoints.

## Script Location

- `Day3/temp-file-cleanup.ps1`

## What The Script Does

The script performs controlled temp-file cleanup with safety controls:

- Supports a dry run mode (`-DryRun`) to preview deletions.
- Deletes only files older than a configured age (`-OlderThanDays`, default `0`).
- Skips locked files and continues processing.
- Uses per-file `try/catch` so one failure does not stop the run.
- Logs every action to a timestamped log file.
- Produces an end-of-run summary.
- Implements rollback by moving files into a rollback store with a manifest.
- Is idempotent (safe to re-run; already-processed/missing files are skipped).

## Safety Model

Instead of hard-deleting files, cleanup mode moves each eligible file into a rollback store:

- Rollback root: `Day3/RollbackStore/cleanup_yyyyMMdd_HHmmss/`
- Manifest file: `manifest.csv` inside that session folder

You can restore files later by running rollback mode with the manifest path.

## Parameters

### Cleanup Mode (default)

- `-TargetPaths <string[]>`
  - Paths to clean.
  - Default: user temp and Windows temp:
    - `$env:TEMP`
    - `$env:WINDIR\Temp`
- `-OlderThanDays <int>`
  - Only process files older than this many days.
  - Default: `0`
- `-DryRun`
  - Preview mode. Prints files that would be deleted.
  - No file move/delete is performed.
- `-Recurse`
  - Include subfolders under each target path.

### Rollback Mode

- `-RollbackManifestPath <string>`
  - Path to a previously created `manifest.csv`.
  - Restores files from rollback store back to original locations.

## Usage Examples

### 1) Dry Run (Recommended First Step)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Day3\temp-file-cleanup.ps1 -DryRun -Recurse
```

### 2) Cleanup Files Older Than 7 Days

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Day3\temp-file-cleanup.ps1 -OlderThanDays 7 -Recurse
```

### 3) Cleanup Specific Paths Only

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Day3\temp-file-cleanup.ps1 -TargetPaths "C:\Temp","C:\Windows\Temp" -OlderThanDays 3 -Recurse
```

### 4) Rollback A Previous Cleanup Session

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Day3\temp-file-cleanup.ps1 -RollbackManifestPath ".\Day3\RollbackStore\cleanup_20260805_113149\manifest.csv"
```

## Output And Logs

Each run creates a log file under:

- `Day3/Logs/temp_cleanup_yyyyMMdd_HHmmss.log`

The log records:

- Start settings
- Every dry-run candidate
- Every moved/restored file
- Locked-file skips
- Per-file errors
- Final summary counters

## Summary Counters

Cleanup summary includes:

- `ScannedFiles`
- `EligibleByAge`
- `WouldDelete`
- `MovedToRollback`
- `SkippedLocked`
- `SkippedMissing`
- `SkippedPathNotFound`
- `Errors`

Rollback summary includes:

- `ManifestRows`
- `Restored`
- `MissingBackup`
- `ConflictAtDest`
- `Errors`

## Idempotency Notes

The script is designed to be safe on repeated execution:

- Cleanup mode skips files already removed/missing.
- Rollback mode skips already-restored or conflicting destination files.
- Backup path collision handling prevents overwrite in rollback storage.

## Operational Guidance

- Always run with `-DryRun` first.
- Start with narrower `-TargetPaths` and a higher `-OlderThanDays` in pilot runs.
- Review the generated log after each run.
- Keep rollback store contents until validation is complete.

## Known Scope

- File cleanup only (does not remove directories).
- Locked-file detection is based on open-file access checks.
- Requires PowerShell 5.1 compatible environment.
