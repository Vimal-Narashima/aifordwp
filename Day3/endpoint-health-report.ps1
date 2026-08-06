# Requires -Version 5.1

<#
.SYNOPSIS
Read-only endpoint health report for DWP engineers.

.DESCRIPTION
Collects common endpoint health indicators without changing system state.

.VERIFY_BEFORE_RUNNING
1. Internet speed testing in Section 7 makes outbound web requests to Microsoft-hosted test files.
   Verify that outbound HTTPS access is permitted and that generating test traffic is acceptable.
2. Event log access in Section 6 may require elevated rights on some endpoints.
3. Defender service checks in Section 8 assume Microsoft Defender is present on the device.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PendingRebootState {
    <#
    Checks common registry locations that indicate whether Windows is waiting for a reboot.
    This is read-only and only queries registry values/keys.
    #>
    $pendingPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    $pendingValues = @(
        @{
            Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            Name = 'PendingFileRenameOperations'
        }
    )

    foreach ($path in $pendingPaths) {
        if (Test-Path -Path $path) {
            return $true
        }
    }

    foreach ($item in $pendingValues) {
        try {
            $value = Get-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction Stop
            if ($null -ne $value.($item.Name)) {
                return $true
            }
        }
        catch {
            # Missing registry values are expected on healthy systems.
        }
    }

    return $false
}

function Get-InternetSpeedMbps {
    <#
    Measures approximate download throughput by streaming a test file over HTTPS.
    This is read-only (no local file writes or configuration changes), but it does generate network traffic.
    #>
    $testUris = @(
        'https://speed.cloudflare.com/__down?bytes=10000000',
        'https://proof.ovh.net/files/10Mb.dat',
        'https://speed.hetzner.de/10MB.bin'
    )

    $lastError = $null

    foreach ($uri in $testUris) {
        $response = $null
        $stream = $null
        try {
            # Many modern endpoints require TLS 1.2 when called from Windows PowerShell 5.1.
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

            $request = [System.Net.HttpWebRequest]::Create($uri)
            $request.Method = 'GET'
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000
            $request.AllowReadStreamBuffering = $false

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $response = $request.GetResponse()
            $stream = $response.GetResponseStream()

            $buffer = New-Object byte[] 65536
            $bytesReadTotal = 0L
            while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $bytesReadTotal += $bytesRead
            }

            $stopwatch.Stop()

            if ($bytesReadTotal -gt 0 -and $stopwatch.Elapsed.TotalSeconds -gt 0) {
                $megabits = ($bytesReadTotal * 8) / 1MB
                $mbps = $megabits / $stopwatch.Elapsed.TotalSeconds

                return [pscustomobject]@{
                    Source = $uri
                    Mbps   = [math]::Round($mbps, 2)
                    Detail = 'Measured successfully'
                }
            }

            $lastError = 'Downloaded zero bytes from source'
        }
        catch {
            $lastError = $_.Exception.Message
            continue
        }
        finally {
            if ($stream) {
                $stream.Dispose()
            }
            if ($response) {
                $response.Dispose()
            }
        }
    }

    return [pscustomobject]@{
        Source = 'Unavailable'
        Mbps   = 'Unable to measure'
        Detail = $(if ($lastError) { $lastError } else { 'All test sources failed or were blocked' })
    }
}

function Get-LoggedOnUserCount {
    <#
    Counts interactive user profiles currently loaded in the registry as a proxy for logged-on users.
    This is read-only and avoids changing session state.
    #>
    $excludedSids = @(
        'S-1-5-18',
        'S-1-5-19',
        'S-1-5-20'
    )

    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $profiles = Get-ChildItem -Path $profileListPath -ErrorAction Stop | Where-Object {
        $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notin $excludedSids
    }

    $loadedProfiles = foreach ($profile in $profiles) {
        if (Test-Path -Path ("Registry::HKEY_USERS\{0}" -f $profile.PSChildName)) {
            $profile.PSChildName
        }
    }

    return ($loadedProfiles | Measure-Object).Count
}

function Get-LastWindowsUpdateDate {
    <#
    Reads the most recent successful Windows update installation date from Win32_QuickFixEngineering.
    This only queries WMI/CIM and does not alter update state.
    #>
    $updates = Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop | Where-Object {
        $_.InstalledOn
    }

    if (-not $updates) {
        return 'No installed update date found'
    }

    $latest = $updates | Sort-Object {
        [datetime]::Parse($_.InstalledOn)
    } -Descending | Select-Object -First 1

    return ([datetime]::Parse($latest.InstalledOn)).ToString('yyyy-MM-dd HH:mm:ss')
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $uptimeSpan = (Get-Date) - $os.LastBootUpTime
    $fixedDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop
    $pendingReboot = Get-PendingRebootState
    $topMemory = Get-Process -ErrorAction Stop | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 5 Name, Id, @{Name='WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) }}
    $topCpu = Get-Process -ErrorAction Stop |
        Select-Object Name, Id, @{Name='CPUSeconds'; Expression = {
            try {
                if ($null -ne $_.TotalProcessorTime) {
                    [math]::Round($_.TotalProcessorTime.TotalSeconds, 2)
                }
                else {
                    0
                }
            }
            catch {
                0
            }
        }} |
        Sort-Object -Property CPUSeconds -Descending |
        Select-Object -First 5
    $systemErrors = Get-WinEvent -LogName System -MaxEvents 200 -ErrorAction Stop | Where-Object {
        $_.LevelDisplayName -eq 'Error'
    } | Select-Object -First 5 TimeCreated, Id, ProviderName, Message
    $internetSpeed = Get-InternetSpeedMbps
    $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    $loggedOnUserCount = Get-LoggedOnUserCount
    $lastWindowsUpdate = Get-LastWindowsUpdateDate

    Write-Host '=== Endpoint Health Report ==='
    Write-Host ('Generated: {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Host ''

    # Section 1: Displays how long the endpoint has been running since the last boot.
    Write-Host '1. System Uptime'
    Write-Host ('   Last Boot Time : {0}' -f $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Host ('   Uptime         : {0} days, {1} hours, {2} minutes' -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes)
    Write-Host ''

    # Section 2: Lists free disk space for each fixed local disk.
    Write-Host '2. Free Disk Space'
    foreach ($disk in $fixedDisks) {
        Write-Host ('   Drive {0}  Free: {1} GB  Total: {2} GB' -f $disk.DeviceID, ([math]::Round($disk.FreeSpace / 1GB, 2)), ([math]::Round($disk.Size / 1GB, 2)))
    }
    Write-Host ''

    # Section 3: Reports whether Windows indicates a reboot is pending using registry checks.
    Write-Host '3. Pending Reboot'
    Write-Host ('   Pending Reboot : {0}' -f $(if ($pendingReboot) { 'Yes' } else { 'No' }))
    Write-Host ''

    # Section 4: Shows the five processes using the most working set memory.
    Write-Host '4. Top 5 Processes by Memory (Working Set)'
    $topMemory | Format-Table -AutoSize | Out-String | Write-Host

    # Section 5: Shows the five processes with the highest accumulated CPU time.
    Write-Host '5. Top 5 Processes by CPU'
    $topCpu | Format-Table -AutoSize | Out-String | Write-Host

    # Section 6: Displays the latest five error entries from the System event log.
    Write-Host '6. Last 5 System Log Errors'
    if ($systemErrors) {
        $systemErrors | Select-Object TimeCreated, Id, ProviderName, @{Name='Message'; Expression = { ($_.Message -replace "`r|`n", ' ') }} | Format-Table -Wrap -AutoSize | Out-String | Write-Host
    }
    else {
        Write-Host '   No recent System log errors found.'
    }
    Write-Host ''

    # Section 7: Measures approximate internet download speed using an outbound web request.
    Write-Host '7. Internet Speed'
    Write-Host ('   Source         : {0}' -f $internetSpeed.Source)
    Write-Host ('   Download Speed : {0} Mbps' -f $internetSpeed.Mbps)
    Write-Host ('   Detail         : {0}' -f $internetSpeed.Detail)
    Write-Host ''

    # Section 8: Checks whether the Microsoft Defender Antivirus service is currently running.
    Write-Host '8. Microsoft Defender Service'
    if ($defenderService) {
        Write-Host ('   WinDefend      : {0}' -f $defenderService.Status)
    }
    else {
        Write-Host '   WinDefend      : Service not found'
    }
    Write-Host ''

    # Section 9: Reports the count of user profiles that appear to be currently loaded/logged on.
    Write-Host '9. Logged-In User Count'
    Write-Host ('   Users Logged In: {0}' -f $loggedOnUserCount)
    Write-Host ''

    # Section 10: Shows the most recent Windows update installation date that could be queried.
    Write-Host '10. Last Windows Update'
    Write-Host ('   Last Update    : {0}' -f $lastWindowsUpdate)
}
catch {
    Write-Error ('Endpoint health report failed: {0}' -f $_.Exception.Message)
}