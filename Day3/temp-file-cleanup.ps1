<#
.SYNOPSIS
Safely cleans up temp files on Windows endpoints with dry-run, logging, rollback, and summary reporting.

.DESCRIPTION
- Targets temp file locations (or custom paths) and processes files older than a configurable number of days.
- Skips locked files without stopping execution.
- Uses per-file try/catch so one failure does not stop the run.
- Logs every action to a timestamped log file.
- Supports rollback from a generated manifest.
- Idempotent behavior: rerunning cleanup/rollback will skip items already processed or no longer present.

.NOTES
PowerShell version: 5.1
#>

[CmdletBinding(DefaultParameterSetName = 'Cleanup')]
param(
    # --- Cleanup mode parameters ---
    [Parameter(ParameterSetName = 'Cleanup')]
    [string[]]$TargetPaths = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    ),

    [Parameter(ParameterSetName = 'Cleanup')]
    [ValidateRange(0, 36500)]
    [int]$OlderThanDays = 0,

    [Parameter(ParameterSetName = 'Cleanup')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Cleanup')]
    [switch]$Recurse,

    # --- Rollback mode parameters ---
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [ValidateNotNullOrEmpty()]
    [string]$RollbackManifestPath
)

# --- Section: Strict runtime settings for predictable behavior ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Section: Establish shared paths and timestamped logging ---
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$timeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDirectory = Join-Path -Path $scriptRoot -ChildPath 'Logs'
$rollbackRoot = Join-Path -Path $scriptRoot -ChildPath 'RollbackStore'

if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $rollbackRoot)) {
    New-Item -Path $rollbackRoot -ItemType Directory -Force | Out-Null
}

$logPath = Join-Path -Path $logDirectory -ChildPath ("temp_cleanup_{0}.log" -f $timeStamp)

# --- Section: Logging helper used by all operations ---
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
    Add-Content -Path $logPath -Value $line
    Write-Host $line
}

# --- Section: Detect whether a file is currently locked by another process ---
function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        return $false
    }
    catch [System.IO.IOException] {
        return $true
    }
    catch {
        # Non-IO exceptions are treated as inaccessible/locked for safety.
        return $true
    }
}

# --- Section: Build deterministic backup path for rollback and idempotency ---
function Get-BackupPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,

        [Parameter(Mandatory = $true)]
        [string]$SessionFolder
    )

    # Keep enough of the original path to avoid collisions while staying filesystem-safe.
    $safeRelative = $OriginalPath -replace ':', ''
    $safeRelative = $safeRelative.TrimStart('\\')
    return (Join-Path -Path $SessionFolder -ChildPath $safeRelative)
}

# --- Section: Cleanup mode (scan, filter, dry-run/move, manifest, summary) ---
function Invoke-Cleanup {
    $summary = [ordered]@{
        ScannedFiles        = 0
        EligibleByAge       = 0
        WouldDelete         = 0
        MovedToRollback     = 0
        SkippedLocked       = 0
        SkippedMissing      = 0
        SkippedPathNotFound = 0
        Errors              = 0
    }

    $sessionId = "cleanup_{0}" -f $timeStamp
    $sessionFolder = Join-Path -Path $rollbackRoot -ChildPath $sessionId
    $manifestPath = Join-Path -Path $sessionFolder -ChildPath 'manifest.csv'
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)

    Write-Log -Message "Starting cleanup mode. DryRun=$DryRun, OlderThanDays=$OlderThanDays, Cutoff=$($cutoff.ToString('s')), Recurse=$Recurse"

    if (-not $DryRun) {
        New-Item -Path $sessionFolder -ItemType Directory -Force | Out-Null
    }

    $manifestRows = New-Object System.Collections.Generic.List[object]

    foreach ($targetPath in $TargetPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $targetPath)) {
            $summary.SkippedPathNotFound++
            Write-Log -Level 'WARN' -Message "Target path not found: $targetPath"
            continue
        }

        Write-Log -Message "Scanning target path: $targetPath"

        $childItems = @()
        try {
            if ($Recurse) {
                $childItems = Get-ChildItem -LiteralPath $targetPath -File -Force -Recurse -ErrorAction SilentlyContinue
            }
            else {
                $childItems = Get-ChildItem -LiteralPath $targetPath -File -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Failed to enumerate $targetPath. Error: $($_.Exception.Message)"
            continue
        }

        foreach ($file in $childItems) {
            $summary.ScannedFiles++

            # Per-file try/catch ensures one bad file never stops the script.
            try {
                if ($file.LastWriteTime -ge $cutoff) {
                    continue
                }

                $summary.EligibleByAge++

                if (-not (Test-Path -LiteralPath $file.FullName)) {
                    $summary.SkippedMissing++
                    Write-Log -Level 'WARN' -Message "File missing before processing (already handled or removed): $($file.FullName)"
                    continue
                }

                if (Test-FileLocked -Path $file.FullName) {
                    $summary.SkippedLocked++
                    Write-Log -Level 'WARN' -Message "Skipped locked file: $($file.FullName)"
                    continue
                }

                if ($DryRun) {
                    $summary.WouldDelete++
                    Write-Output "Would delete: $($file.FullName)"
                    Write-Log -Message "Dry-run candidate: $($file.FullName)"
                    continue
                }

                $backupPath = Get-BackupPath -OriginalPath $file.FullName -SessionFolder $sessionFolder
                $backupParent = Split-Path -Path $backupPath -Parent
                if (-not (Test-Path -LiteralPath $backupParent)) {
                    New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
                }

                # If a backup file already exists, add suffix to keep operation idempotent and collision-safe.
                $resolvedBackupPath = $backupPath
                $suffix = 1
                while (Test-Path -LiteralPath $resolvedBackupPath) {
                    $resolvedBackupPath = "{0}.{1}" -f $backupPath, $suffix
                    $suffix++
                }

                Move-Item -LiteralPath $file.FullName -Destination $resolvedBackupPath -Force -ErrorAction Stop

                $manifestRows.Add([pscustomobject]@{
                    OriginalPath = $file.FullName
                    BackupPath   = $resolvedBackupPath
                    LastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
                    SessionId    = $sessionId
                    MovedAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
                }) | Out-Null

                $summary.MovedToRollback++
                Write-Log -Message "Moved to rollback store: $($file.FullName) -> $resolvedBackupPath"
            }
            catch {
                $summary.Errors++
                Write-Log -Level 'ERROR' -Message "Failed processing file: $($file.FullName). Error: $($_.Exception.Message)"
            }
        }
    }

    if (-not $DryRun) {
        $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding UTF8
        Write-Log -Message "Rollback manifest created: $manifestPath"
    }

    Write-Log -Message "Cleanup summary: $(($summary.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"

    Write-Host ''
    Write-Host '=== Cleanup Summary ==='
    $summary.GetEnumerator() | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Key, $_.Value) }
    if (-not $DryRun) {
        Write-Host ("Rollback manifest: {0}" -f $manifestPath)
    }
    Write-Host ("Log file: {0}" -f $logPath)
}

# --- Section: Rollback mode (restore files from a prior manifest) ---
function Invoke-Rollback {
    $summary = [ordered]@{
        ManifestRows   = 0
        Restored       = 0
        MissingBackup  = 0
        ConflictAtDest = 0
        Errors         = 0
    }

    Write-Log -Message "Starting rollback mode. Manifest=$RollbackManifestPath"

    if (-not (Test-Path -LiteralPath $RollbackManifestPath)) {
        throw "Rollback manifest not found: $RollbackManifestPath"
    }

    $rows = Import-Csv -Path $RollbackManifestPath
    $summary.ManifestRows = @($rows).Count

    foreach ($row in $rows) {
        # Per-file try/catch ensures rollback continues even when one file fails.
        try {
            $source = $row.BackupPath
            $destination = $row.OriginalPath

            if (-not (Test-Path -LiteralPath $source)) {
                $summary.MissingBackup++
                Write-Log -Level 'WARN' -Message "Backup file missing; likely already restored or manually removed: $source"
                continue
            }

            if (Test-Path -LiteralPath $destination) {
                $summary.ConflictAtDest++
                Write-Log -Level 'WARN' -Message "Rollback conflict, destination already exists: $destination"
                continue
            }

            $destinationParent = Split-Path -Path $destination -Parent
            if (-not (Test-Path -LiteralPath $destinationParent)) {
                New-Item -Path $destinationParent -ItemType Directory -Force | Out-Null
            }

            Move-Item -LiteralPath $source -Destination $destination -Force -ErrorAction Stop
            $summary.Restored++
            Write-Log -Message "Restored file: $source -> $destination"
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Failed rollback entry (OriginalPath=$($row.OriginalPath), BackupPath=$($row.BackupPath)). Error: $($_.Exception.Message)"
        }
    }

    Write-Log -Message "Rollback summary: $(($summary.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"

    Write-Host ''
    Write-Host '=== Rollback Summary ==='
    $summary.GetEnumerator() | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Key, $_.Value) }
    Write-Host ("Log file: {0}" -f $logPath)
}

# --- Section: Entrypoint routes to cleanup or rollback mode ---
try {
    if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
        Invoke-Rollback
    }
    else {
        Invoke-Cleanup
    }
}
catch {
    Write-Log -Level 'ERROR' -Message "Fatal error: $($_.Exception.Message)"
    throw
}
