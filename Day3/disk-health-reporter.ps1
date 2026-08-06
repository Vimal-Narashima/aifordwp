# Requires -Version 5.1

<#!
.SYNOPSIS
Read-only disk health and optimization status reporter.

.DESCRIPTION
Collects physical disk health, volume details, and optimization-related status
without changing system state.

.SAFETY
- This script is read-only.
- It does not run Optimize-Volume.
- It does not run defrag.exe.
- It does not modify scheduled tasks, disk settings, or filesystems.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} KB' -f ($Bytes / 1KB))
}

function Get-PhysicalDiskReport {
    $results = @()

    if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $physicalDisks = Get-PhysicalDisk

        foreach ($disk in $physicalDisks) {
            $sizeText = if ($null -ne $disk.Size) { Format-Bytes -Bytes $disk.Size } else { 'Unknown' }
            $opStatus = if ($disk.OperationalStatus) { ($disk.OperationalStatus -join ', ') } else { 'Unknown' }

            $results += [pscustomobject]@{
                DiskName          = $disk.FriendlyName
                SerialNumber      = $disk.SerialNumber
                MediaType         = $disk.MediaType
                HealthStatus      = $disk.HealthStatus
                OperationalStatus = $opStatus
                Size              = $sizeText
            }
        }

        return $results
    }

    # Fallback for systems where Storage module cmdlets are not available.
    $legacyDisks = Get-CimInstance -ClassName Win32_DiskDrive
    foreach ($disk in $legacyDisks) {
        $status = if ($disk.Status) { $disk.Status } else { 'Unknown' }
        $sizeText = if ($null -ne $disk.Size) { Format-Bytes -Bytes $disk.Size } else { 'Unknown' }

        $results += [pscustomobject]@{
            DiskName          = $disk.Model
            SerialNumber      = $disk.SerialNumber
            MediaType         = $disk.MediaType
            HealthStatus      = $status
            OperationalStatus = 'N/A (Win32_DiskDrive fallback)'
            Size              = $sizeText
        }
    }

    return $results
}

function Get-VolumeReport {
    $results = @()

    if (Get-Command -Name Get-Volume -ErrorAction SilentlyContinue) {
        $volumes = Get-Volume | Where-Object {
            $_.DriveType -eq 'Fixed' -and $_.DriveLetter
        }

        foreach ($volume in $volumes) {
            $free = if ($null -ne $volume.SizeRemaining) { Format-Bytes -Bytes $volume.SizeRemaining } else { 'Unknown' }
            $size = if ($null -ne $volume.Size) { Format-Bytes -Bytes $volume.Size } else { 'Unknown' }
            $pctFree = if ($volume.Size -gt 0) {
                [math]::Round(($volume.SizeRemaining / $volume.Size) * 100, 2)
            }
            else {
                0
            }

            $results += [pscustomobject]@{
                Drive            = ('{0}:' -f $volume.DriveLetter)
                FileSystem       = $volume.FileSystem
                HealthStatus     = $volume.HealthStatus
                OperationalStatus = $volume.OperationalStatus
                TotalSize        = $size
                FreeSpace        = $free
                FreePercent      = ('{0}%' -f $pctFree)
            }
        }

        return $results
    }

    $legacyVolumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3'
    foreach ($volume in $legacyVolumes) {
        $free = if ($null -ne $volume.FreeSpace) { Format-Bytes -Bytes $volume.FreeSpace } else { 'Unknown' }
        $size = if ($null -ne $volume.Size) { Format-Bytes -Bytes $volume.Size } else { 'Unknown' }
        $pctFree = if ($volume.Size -gt 0) {
            [math]::Round(($volume.FreeSpace / $volume.Size) * 100, 2)
        }
        else {
            0
        }

        $results += [pscustomobject]@{
            Drive            = $volume.DeviceID
            FileSystem       = $volume.FileSystem
            HealthStatus     = if ($volume.Status) { $volume.Status } else { 'Unknown' }
            OperationalStatus = 'N/A (Win32_LogicalDisk fallback)'
            TotalSize        = $size
            FreeSpace        = $free
            FreePercent      = ('{0}%' -f $pctFree)
        }
    }

    return $results
}

function Get-OptimizationStatus {
    $taskInfo = [pscustomobject]@{
        TaskPath       = '\Microsoft\Windows\Defrag\ScheduledDefrag'
        Exists         = $false
        State          = 'Unknown'
        LastRunTime    = $null
        NextRunTime    = $null
        LastTaskResult = 'Unknown'
    }

    try {
        $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction Stop
        $taskState = $task.State
        $runtime = Get-ScheduledTaskInfo -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction Stop

        $taskInfo = [pscustomobject]@{
            TaskPath       = '\Microsoft\Windows\Defrag\ScheduledDefrag'
            Exists         = $true
            State          = $taskState
            LastRunTime    = $runtime.LastRunTime
            NextRunTime    = $runtime.NextRunTime
            LastTaskResult = $runtime.LastTaskResult
        }
    }
    catch {
        # Keep default object when task is missing or access is denied.
    }

    $recentEvents = @()
    try {
        $recentEvents = Get-WinEvent -LogName 'Microsoft-Windows-Defrag/Operational' -MaxEvents 10 -ErrorAction Stop |
            Select-Object TimeCreated, Id, LevelDisplayName, Message
    }
    catch {
        # Event log can be unavailable or access may be restricted.
    }

    return [pscustomobject]@{
        Task   = $taskInfo
        Events = $recentEvents
    }
}

try {
    $computerName = $env:COMPUTERNAME
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $physicalDisks = Get-PhysicalDiskReport
    $volumes = Get-VolumeReport
    $optimization = Get-OptimizationStatus

    Write-Host '=== Disk Health and Optimization Status Report (Read-Only) ==='
    Write-Host ('Computer: {0}' -f $computerName)
    Write-Host ('Generated: {0}' -f $timestamp)
    Write-Host ''

    Write-Host '1. Physical Disk Health'
    if ($physicalDisks.Count -gt 0) {
        $physicalDisks | Format-Table -AutoSize
    }
    else {
        Write-Host 'No physical disk data found.'
    }
    Write-Host ''

    Write-Host '2. Volume Status (Fixed Drives)'
    if ($volumes.Count -gt 0) {
        $volumes | Format-Table -AutoSize
    }
    else {
        Write-Host 'No fixed volume data found.'
    }
    Write-Host ''

    Write-Host '3. Optimization Status (Read-Only Indicators)'
    Write-Host ('Scheduled Task Path : {0}' -f $optimization.Task.TaskPath)
    Write-Host ('Task Exists          : {0}' -f $optimization.Task.Exists)
    Write-Host ('Task State           : {0}' -f $optimization.Task.State)
    Write-Host ('Last Run Time        : {0}' -f $optimization.Task.LastRunTime)
    Write-Host ('Next Run Time        : {0}' -f $optimization.Task.NextRunTime)
    Write-Host ('Last Task Result     : {0}' -f $optimization.Task.LastTaskResult)
    Write-Host ''

    Write-Host 'Recent Defrag/Optimization Events (Last 10)'
    if ($optimization.Events.Count -gt 0) {
        $optimization.Events | Format-Table -AutoSize
    }
    else {
        Write-Host 'No optimization event data available (log missing, empty, or access denied).'
    }
    Write-Host ''

    Write-Host 'Safety Confirmation:'
    Write-Host '- This script only reads system state.'
    Write-Host '- No optimization command was executed.'
    Write-Host '- No defragmentation command was executed.'
}
catch {
    Write-Error ('Disk health report failed: {0}' -f $_.Exception.Message)
    exit 1
}
