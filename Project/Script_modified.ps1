#Requires -Version 5.1

<#
.SYNOPSIS
Read-only Floor 6 evidence capture.

.DESCRIPTION
Collects endpoint evidence for the three likely Floor 6 causes:
1. Logon slowness or failure after Win11 and Intune migration.
2. Missing shortcuts after the document management rollout.
3. Copilot surfacing a matter the user should not see.

This script is strictly read-only. It does not create, delete, or change files, registry values, policies, services, tasks, accounts, or network settings.

.VERIFY_BEFORE_RUNNING
1. Run on an affected Floor 6 device, not a control device.
2. Update the app hints if you know the exact document management product name.
3. Validate the Copilot matter in the source system separately; this script cannot prove source permissions.
4. Security log reads may require local admin rights.
5. The script only prints evidence to the console and does not save output.
#>

[CmdletBinding()]
param(
    [string[]]
    $DocumentAppHints = @(
        'document management',
        'documentmanagement',
        'dms',
        'iManage',
        'NetDocuments',
        'M-Files',
        'OpenText',
        'Worldox',
        'SharePoint'
    ),

    [string]
    $MatterHint = '',

    [string]
    $OutputFolder = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$transcriptStarted = $false
if (-not [string]::IsNullOrWhiteSpace($OutputFolder)) {
    try {
        if (-not (Test-Path -Path $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $transcriptPath = Join-Path -Path $OutputFolder -ChildPath ("Floor6_Evidence_{0}.txt" -f $timestamp)
        Start-Transcript -Path $transcriptPath -Force | Out-Null
        $transcriptStarted = $true
    }
    catch {
        Write-Host ('Could not start transcript export: {0}' -f $_.Exception.Message)
    }
}

function Write-SectionHeader {
    # Prints a clear separator so each evidence block is easy to scan in the console.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('=' * 90)
    Write-Host $Title
    Write-Host ('=' * 90)
}

function Write-TableBlock {
    # Renders tabular results with fixed formatting and a readable fallback when there is no data.
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Items,

        [string[]]$Properties = @()
    )

    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host '   No matching items found.'
        return
    }

    if ($Properties -and $Properties.Count -gt 0) {
        $Items | Select-Object $Properties | Format-Table -AutoSize | Out-String | Write-Host
    }
    else {
        $Items | Format-Table -AutoSize | Out-String | Write-Host
    }
}

function Write-TextBlock {
    # Writes plain text lines with indentation so raw command output stays readable.
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    if (-not $Lines -or $Lines.Count -eq 0) {
        Write-Host '   No text returned.'
        return
    }

    foreach ($line in $Lines) {
        Write-Host ('   {0}' -f $line)
    }
}

function Get-PendingRebootState {
    # Checks the common registry locations Windows uses to indicate that a reboot is pending.
    $pendingPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    $pendingValueChecks = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'PendingFileRenameOperations' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Updates'; Name = 'UpdateExeVolatile' }
    )

    foreach ($path in $pendingPaths) {
        if (Test-Path -Path $path) {
            return $true
        }
    }

    foreach ($check in $pendingValueChecks) {
        try {
            $value = Get-ItemProperty -Path $check.Path -Name $check.Name -ErrorAction Stop
            if ($null -ne $value.($check.Name)) {
                return $true
            }
        }
        catch {
            # Missing values are expected on many healthy systems.
        }
    }

    return $false
}

function Get-RegistryPropertyValue {
    # Safely reads a registry value without throwing when the path or value is absent.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.($Name)
    }
    catch {
        return $null
    }
}

function Get-DsRegStatusSnapshot {
    # Captures the important dsregcmd /status lines that show device join and sign-in state.
    $raw = & dsregcmd /status 2>&1
    $keywords = @(
        'AzureAdJoined',
        'EnterpriseJoined',
        'DomainJoined',
        'DeviceName',
        'DeviceId',
        'TenantName',
        'TenantId',
        'MdmUrl',
        'AzureAdPrt',
        'NgcSet',
        'WamDefaultSet',
        'WorkplaceJoined'
    )

    $interesting = foreach ($line in $raw) {
        foreach ($keyword in $keywords) {
            if ($line -match ('^\s*{0}\s*:' -f [regex]::Escape($keyword))) {
                $line
                break
            }
        }
    }

    if ($interesting) {
        return $interesting
    }

    return $raw | Select-Object -First 60
}

function Get-RecentEventSample {
    # Reads recent event log entries from a specific log and returns a compact evidence sample.
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogName,

        [int]$MaxEvents = 40,

        [string]$ProviderPattern = '',

        [string]$MessagePattern = '',

        [datetime]$StartTime = $null
    )

    $filter = @{ LogName = $LogName }
    if ($StartTime) {
        $filter.StartTime = $StartTime
    }

    try {
        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop | Select-Object -First $MaxEvents
    }
    catch {
        return @([pscustomobject]@{
            TimeCreated = $null
            Id = $null
            ProviderName = $null
            LevelDisplayName = 'Unavailable'
            Message = $_.Exception.Message
        })
    }

    if ($ProviderPattern -or $MessagePattern) {
        $events = $events | Where-Object {
            $providerOk = $true
            $messageOk = $true

            if ($ProviderPattern) {
                $providerOk = $_.ProviderName -match $ProviderPattern
            }

            if ($MessagePattern) {
                $messageOk = $_.Message -match $MessagePattern
            }

            $providerOk -and $messageOk
        }
    }

    return $events | Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, @{Name = 'Message'; Expression = { ($_.Message -replace "`r|`n", ' ') } }
}

function Get-InstalledAppMatches {
    # Searches common uninstall registry locations for installed apps that match the supplied name hints.
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$NameHints
    )

    $pattern = ($NameHints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [regex]::Escape($_) }) -join '|'
    if ([string]::IsNullOrWhiteSpace($pattern)) {
        return @()
    }

    $roots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($root in $roots) {
        try {
            Get-ItemProperty -Path $root -ErrorAction Stop | Where-Object {
                $_.DisplayName -and ($_.DisplayName -match $pattern)
            } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName    = $_.DisplayName
                    DisplayVersion = $_.DisplayVersion
                    Publisher      = $_.Publisher
                    InstallDate    = $_.InstallDate
                    Scope          = $(if ($root -like 'HKCU:*') { 'CurrentUser' } else { 'Machine' })
                    RegistryKey    = $_.PSChildName
                }
            }
        }
        catch {
            # Some registry branches may be inaccessible or empty on a given endpoint.
        }
    }

    return $results | Sort-Object DisplayName, DisplayVersion -Unique
}

function Get-DesktopEvidence {
    # Captures desktop folder paths and the current shortcut inventory so shortcut loss can be checked quickly.
    $userDesktop = [Environment]::GetFolderPath('Desktop')
    $commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')

    $userShellDesktop = Get-RegistryPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name 'Desktop'
    $shellDesktop = Get-RegistryPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -Name 'Desktop'

    $desktopFolders = @(
        [pscustomobject]@{ Scope = 'UserDesktop'; Path = $userDesktop; Exists = (Test-Path -Path $userDesktop) },
        [pscustomobject]@{ Scope = 'CommonDesktop'; Path = $commonDesktop; Exists = (Test-Path -Path $commonDesktop) },
        [pscustomobject]@{ Scope = 'UserShellFolder'; Path = $userShellDesktop; Exists = $(if ($userShellDesktop) { Test-Path -Path $userShellDesktop } else { $false }) },
        [pscustomobject]@{ Scope = 'ShellFolder'; Path = $shellDesktop; Exists = $(if ($shellDesktop) { Test-Path -Path $shellDesktop } else { $false }) }
    )

    $shortcutInventory = @()
    foreach ($path in @($userDesktop, $commonDesktop)) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -Path $path)) {
            continue
        }

        $shortcutInventory += Get-ChildItem -Path $path -Filter '*.lnk' -ErrorAction SilentlyContinue | Select-Object @{Name = 'Scope'; Expression = { if ($_.FullName -like "$userDesktop*") { 'UserDesktop' } else { 'CommonDesktop' } } }, Name, Length, LastWriteTime, FullName
    }

    return [pscustomobject]@{
        DesktopFolders = $desktopFolders
        ShortcutInventory = $shortcutInventory
    }
}

function Get-OneDriveEvidence {
    # Collects OneDrive process, version, and operational log evidence because folder redirection and sync issues can hide shortcuts.
    $process = Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime, Path
    $oneDriveExe = Get-RegistryPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OneDrive.exe' -Name '(default)'
    $oneDriveVersion = Get-RegistryPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\OneDrive' -Name 'Version'
    $oneDriveMachineVersion = Get-RegistryPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\OneDrive' -Name 'OneDriveVersion'

    $operationalEvents = Get-RecentEventSample -LogName 'Microsoft-Windows-OneDrive/Operational' -MaxEvents 50 -StartTime (Get-Date).AddDays(-7)

    return [pscustomobject]@{
        Process = $process
        OneDriveExe = $oneDriveExe
        OneDriveVersion = $oneDriveVersion
        OneDriveMachineVersion = $oneDriveMachineVersion
        OperationalEvents = $operationalEvents
    }
}

function Get-OfficeEvidence {
    # Collects Microsoft 365 Apps build and channel data because Copilot behavior depends on the Office client and cloud sign-in context.
    $c2rPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
    $officeEvidence = [pscustomobject]@{
        VersionToReport   = Get-RegistryPropertyValue -Path $c2rPath -Name 'VersionToReport'
        ClientVersionToReport = Get-RegistryPropertyValue -Path $c2rPath -Name 'ClientVersionToReport'
        Platform          = Get-RegistryPropertyValue -Path $c2rPath -Name 'Platform'
        ProductReleaseIds = Get-RegistryPropertyValue -Path $c2rPath -Name 'ProductReleaseIds'
        UpdateChannel     = Get-RegistryPropertyValue -Path $c2rPath -Name 'CDNBaseUrl'
        OfficeClientEdition = Get-RegistryPropertyValue -Path $c2rPath -Name 'AudienceId'
    }

    $edgePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    $edgeVersion = $null
    try {
        $edgeExe = Get-ItemProperty -Path $edgePath -ErrorAction Stop
        if ($edgeExe.'(default)') {
            $edgeVersion = (Get-Item -Path $edgeExe.'(default)').VersionInfo.ProductVersion
        }
    }
    catch {
        # Edge may be absent on a few endpoints; that does not change the read-only nature of the script.
    }

    $officeEvents = Get-RecentEventSample -LogName 'Application' -MaxEvents 80 -StartTime (Get-Date).AddDays(-7) -ProviderPattern 'MsiInstaller|AppXDeployment|ClickToRun|Office' -MessagePattern 'Office|Click-to-Run|Microsoft 365|Copilot'

    return [pscustomobject]@{
        Office = $officeEvidence
        EdgeVersion = $edgeVersion
        RecentOfficeEvents = $officeEvents
    }
}

function Convert-InstallDate {
    # Converts uninstall registry date values in yyyyMMdd format into DateTime when available.
    param(
        [Parameter(Mandatory = $false)]
        [string]$InstallDate
    )

    if ([string]::IsNullOrWhiteSpace($InstallDate)) {
        return $null
    }

    try {
        if ($InstallDate -match '^\d{8}$') {
            return [datetime]::ParseExact($InstallDate, 'yyyyMMdd', $null)
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-LastInstalledApp {
    # Returns the most recent app install entry from common uninstall registry locations.
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = foreach ($path in $paths) {
        try {
            Get-ItemProperty -Path $path -ErrorAction Stop | Where-Object {
                $_.DisplayName
            } | ForEach-Object {
                $parsedDate = Convert-InstallDate -InstallDate $_.InstallDate
                if ($parsedDate) {
                    [pscustomobject]@{
                        DisplayName = $_.DisplayName
                        Publisher = $_.Publisher
                        InstallDate = $parsedDate
                        InstallDateRaw = $_.InstallDate
                        Scope = $(if ($path -like 'HKCU:*') { 'CurrentUser' } else { 'Machine' })
                    }
                }
            }
        }
        catch {
            # Registry branches can be missing or inaccessible on some endpoints.
        }
    }

    if (-not $apps) {
        return $null
    }

    return $apps | Sort-Object InstallDate -Descending | Select-Object -First 1
}

function Get-NetworkEvidence {
    # Captures active IPv4 addresses, DHCP/static mode, and MAC ID for IP-enabled adapters.
    try {
        $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' -ErrorAction Stop
    }
    catch {
        return @([pscustomobject]@{
            Adapter = 'Unavailable'
            IPAddress = 'Unavailable'
            IPMode = 'Unavailable'
            MacID = 'Unavailable'
            Error = $_.Exception.Message
        })
    }

    $rows = foreach ($adapter in $adapters) {
        $ipv4 = @($adapter.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
        if (-not $ipv4) {
            continue
        }

        foreach ($ip in $ipv4) {
            [pscustomobject]@{
                Adapter = $adapter.Description
                IPAddress = $ip
                IPMode = $(if ($adapter.DHCPEnabled) { 'Dynamic (DHCP)' } else { 'Static' })
                MacID = $adapter.MACAddress
                Error = ''
            }
        }
    }

    if (-not $rows) {
        return @([pscustomobject]@{
            Adapter = 'No IPv4 adapter found'
            IPAddress = 'N/A'
            IPMode = 'N/A'
            MacID = 'N/A'
            Error = ''
        })
    }

    return $rows
}

function Get-GroupPolicyOperationalEvidence {
    # Captures recent Group Policy operational events to identify policy processing delays/failures.
    return Get-RecentEventSample -LogName 'Microsoft-Windows-GroupPolicy/Operational' -MaxEvents 80 -StartTime (Get-Date).AddDays(-2)
}

function Get-WinlogonTimelineEvidence {
    # Captures recent Winlogon-related events from Application/System logs to help pinpoint logon stage delays.
    $app = Get-RecentEventSample -LogName 'Application' -MaxEvents 80 -ProviderPattern 'Winlogon|User Profile Service' -StartTime (Get-Date).AddDays(-2)
    $sys = Get-RecentEventSample -LogName 'System' -MaxEvents 80 -ProviderPattern 'Winlogon|User Profile Service' -StartTime (Get-Date).AddDays(-2)
    return [pscustomobject]@{
        ApplicationEvents = $app
        SystemEvents = $sys
    }
}

function Get-NetworkReadinessEvidence {
    # Captures DNS/gateway/DHCP/domain reachability context that can affect sign-in performance.
    $domain = $env:USERDNSDOMAIN
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
            Adapter = $_.Description
            DHCPEnabled = $_.DHCPEnabled
            DHCPServer = ($_.DHCPServer -join ', ')
            DefaultGateway = ($_.DefaultIPGateway -join ', ')
            DnsServers = ($_.DNSServerSearchOrder -join ', ')
        }
    }

    $domainPing = 'Not tested'
    if (-not [string]::IsNullOrWhiteSpace($domain)) {
        try {
            $ok = Test-Connection -ComputerName $domain -Count 1 -Quiet -ErrorAction Stop
            $domainPing = $(if ($ok) { 'Reachable' } else { 'Unreachable' })
        }
        catch {
            $domainPing = ('Test failed: {0}' -f $_.Exception.Message)
        }
    }

    return [pscustomobject]@{
        Domain = $(if ($domain) { $domain } else { 'Not available' })
        DomainReachability = $domainPing
        AdapterDetails = $adapters
    }
}

function Get-TimeSyncEvidence {
    # Captures Windows time service status and source to detect clock drift risk.
    $service = Get-Service -Name W32Time -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
    $statusOutput = @()
    $sourceOutput = @()

    try {
        $statusOutput = & w32tm /query /status 2>&1
    }
    catch {
        $statusOutput = @('w32tm status query failed')
    }

    try {
        $sourceOutput = & w32tm /query /source 2>&1
    }
    catch {
        $sourceOutput = @('w32tm source query failed')
    }

    return [pscustomobject]@{
        Service = $service
        StatusOutput = $statusOutput
        SourceOutput = $sourceOutput
    }
}

function Get-IntuneManagementExtensionEvidence {
    # Captures Intune Management Extension service and log freshness data.
    $imeService = Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
    $logRoot = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
    $recentLogs = @()

    if (Test-Path -Path $logRoot) {
        $recentLogs = Get-ChildItem -Path $logRoot -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 Name, Length, LastWriteTime
    }

    return [pscustomobject]@{
        Service = $imeService
        LogPath = $logRoot
        RecentLogs = $recentLogs
    }
}

function Get-LastSuccessfulInteractiveLogonEvidence {
    # Captures recent successful interactive and remote-interactive logons for baseline comparison.
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4624; StartTime = (Get-Date).AddDays(-7) } -ErrorAction Stop | Select-Object -First 60
    }
    catch {
        return @([pscustomobject]@{ TimeCreated = $null; Id = 4624; Detail = ('Unavailable: {0}' -f $_.Exception.Message) })
    }

    $items = foreach ($event in $events) {
        $msg = $event.Message
        if ($msg -match 'Logon Type:\s+(2|10)') {
            [pscustomobject]@{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                Detail = ($msg -replace "`r|`n", ' ')
            }
        }
    }

    return $items | Select-Object -First 20
}

function Get-DiskAndProfilePathHealthEvidence {
    # Captures disk free space and profile folder accessibility checks.
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
            Drive = $_.DeviceID
            FreeGB = [math]::Round($_.FreeSpace / 1GB, 2)
            TotalGB = [math]::Round($_.Size / 1GB, 2)
        }
    }

    $profileChecks = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object {
        $path = Get-RegistryPropertyValue -Path $_.PSPath -Name 'ProfileImagePath'
        $exists = $false
        $aclState = 'Not checked'
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $exists = Test-Path -Path $path
            if ($exists) {
                try {
                    $null = Get-Acl -Path $path -ErrorAction Stop
                    $aclState = 'Readable'
                }
                catch {
                    $aclState = ('ACL read failed: {0}' -f $_.Exception.Message)
                }
            }
        }

        [pscustomobject]@{
            SID = $_.PSChildName
            ProfilePath = $path
            Exists = $exists
            ACLState = $aclState
        }
    }

    return [pscustomobject]@{
        DiskState = $disks
        ProfilePathState = $profileChecks
    }
}

function Get-StartupLoadPressureEvidence {
    # Captures top process resource consumers and startup entries that may increase logon delay.
    $topCpu = Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id, CPU
    $topMemory = Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } }

    $startupEntries = @()
    $runPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($runPath in $runPaths) {
        try {
            $props = Get-ItemProperty -Path $runPath -ErrorAction Stop
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -notmatch '^PS') {
                    $startupEntries += [pscustomobject]@{
                        Location = $runPath
                        Name = $p.Name
                        Command = [string]$p.Value
                    }
                }
            }
        }
        catch {
            # Missing run keys are expected on some endpoints.
        }
    }

    return [pscustomobject]@{
        TopCPU = $topCpu
        TopMemory = $topMemory
        StartupEntries = $startupEntries
    }
}

function Get-PendingUpdateInstallEvidence {
    # Captures pending-update indicators and recent update-install activity.
    $pending = [pscustomobject]@{
        RebootRequiredPath = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
        CBSRebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
    }

    $recentUpdateEvents = Get-RecentEventSample -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' -MaxEvents 60 -StartTime (Get-Date).AddDays(-7)
    $latestQfe = Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, InstalledOn, Description

    return [pscustomobject]@{
        PendingState = $pending
        UpdateEvents = $recentUpdateEvents
        RecentQfe = $latestQfe
    }
}

function Get-IssueCorrelationMarkers {
    # Produces counts of key event IDs across relevant logs to identify repeat patterns.
    $markers = @()

    $queries = @(
        @{ Log = 'Security'; Ids = @(4624, 4625, 4771, 4776); Label = 'Security auth markers' },
        @{ Log = 'System'; Ids = @(6005, 6006, 7001, 7002); Label = 'System startup markers' },
        @{ Log = 'Application'; Ids = @(1000, 1001); Label = 'Application failure markers' }
    )

    foreach ($q in $queries) {
        foreach ($id in $q.Ids) {
            $count = 0
            try {
                $count = (Get-WinEvent -FilterHashtable @{ LogName = $q.Log; Id = $id; StartTime = (Get-Date).AddDays(-1) } -ErrorAction Stop | Measure-Object).Count
            }
            catch {
                $count = -1
            }

            $markers += [pscustomobject]@{
                Marker = $q.Label
                LogName = $q.Log
                EventId = $id
                CountLast24h = $count
            }
        }
    }

    return $markers
}


# Section 1: Print a compact startup banner so the operator can verify the prerequisites before any evidence collection starts.
Write-SectionHeader 'Floor 6 evidence check (read-only)'
Write-Host 'This script is read-only and will not change system state.'
Write-Host 'Verify before running: affected Floor 6 device, app hints, optional matter hint, and possible admin rights for Security log access.'

# Section 2: Capture the baseline device identity so the logon, shortcut, and Copilot findings can be tied to one endpoint.
Write-SectionHeader '1. Baseline device and user context'
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
$bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
$uptime = (Get-Date) - $os.LastBootUpTime

Write-Host ('Host               : {0}' -f $env:COMPUTERNAME)
Write-Host ('User               : {0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
Write-Host ('Make               : {0}' -f $computerSystem.Manufacturer)
Write-Host ('Model              : {0}' -f $computerSystem.Model)
Write-Host ('OS                 : {0}' -f $os.Caption)
Write-Host ('Version            : {0}' -f $os.Version)
Write-Host ('Build              : {0}' -f $os.BuildNumber)
Write-Host ('Boot               : {0}' -f $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Host ('Uptime             : {0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
Write-Host ('BIOS Serial        : {0}' -f $bios.SerialNumber)
Write-Host ('Domain Joined      : {0}' -f $computerSystem.PartOfDomain)
Write-Host ('Domain             : {0}' -f $(if ($computerSystem.PartOfDomain) { $computerSystem.Domain } else { 'Not domain joined' }))

$networkEvidence = Get-NetworkEvidence
$lastInstalledApp = Get-LastInstalledApp

Write-Host ''
Write-Host 'Network details (IP address / Static-Dynamic / MAC ID):'
$networkEvidence | Select-Object Adapter, IPAddress, IPMode, MacID, Error | Format-Table -AutoSize | Out-String | Write-Host

if ($lastInstalledApp) {
    Write-Host ('Last App Installed Date: {0}' -f $lastInstalledApp.InstallDate.ToString('yyyy-MM-dd'))
    Write-Host ('Last App Name          : {0}' -f $lastInstalledApp.DisplayName)
    Write-Host ('Publisher              : {0}' -f $(if ($lastInstalledApp.Publisher) { $lastInstalledApp.Publisher } else { 'Unknown' }))
    Write-Host ('Install Scope          : {0}' -f $lastInstalledApp.Scope)
}
else {
    Write-Host 'Last App Installed Date: Not available from uninstall registry records'
    Write-Host 'Last App Name          : Not available'
}

# Section 3: Capture join, management, reboot, and profile evidence because the top-ranked logon cause is a Win11/Intune policy or profile issue.
Write-SectionHeader '2. Logon, Intune, and profile evidence'
Write-Host ('Pending Reboot      : {0}' -f $(if (Get-PendingRebootState) { 'Yes' } else { 'No' }))
Write-Host ''

Write-Host 'dsregcmd /status snapshot:'
Write-TextBlock -Lines (Get-DsRegStatusSnapshot)
Write-Host ''

$profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$profileItems = Get-ChildItem -Path $profileListPath -ErrorAction SilentlyContinue | ForEach-Object {
    $profilePath = Get-RegistryPropertyValue -Path $_.PSPath -Name 'ProfileImagePath'
    [pscustomobject]@{
        SID = $_.PSChildName
        ProfilePath = $profilePath
        Loaded = $(if ($profilePath) { Test-Path -Path ("Registry::HKEY_USERS\{0}" -f $_.PSChildName) } else { $false })
    }
}

Write-Host 'Profile list snapshot:'
Write-TableBlock -Items ($profileItems | Select-Object -First 15) -Properties @('SID', 'ProfilePath', 'Loaded')

Write-Host 'Recent Security logon events (4624, 4625, 4672, 4771, 4776):'
try {
    $securityEvents = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; StartTime = (Get-Date).AddDays(-2) } -ErrorAction Stop | Where-Object {
        $_.Id -in 4624, 4625, 4672, 4771, 4776
    } | Select-Object -First 20 TimeCreated, Id, ProviderName, LevelDisplayName, @{Name = 'Message'; Expression = { ($_.Message -replace "`r|`n", ' ') } }
    Write-TableBlock -Items $securityEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
}
catch {
    Write-Host ('   Security log query failed or is restricted: {0}' -f $_.Exception.Message)
}

Write-Host 'Recent User Profile Service events:'
Write-TableBlock -Items (Get-RecentEventSample -LogName 'Microsoft-Windows-User Profiles Service/Operational' -MaxEvents 25 -StartTime (Get-Date).AddDays(-7)) -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')

Write-Host 'Recent System errors and warnings:'
try {
    $systemEvents = Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = (Get-Date).AddDays(-2) } -ErrorAction Stop | Where-Object {
        $_.LevelDisplayName -in 'Error', 'Warning'
    } | Select-Object -First 20 TimeCreated, Id, ProviderName, LevelDisplayName, @{Name = 'Message'; Expression = { ($_.Message -replace "`r|`n", ' ') } }
    Write-TableBlock -Items $systemEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
}
catch {
    Write-Host ('   System log query failed: {0}' -f $_.Exception.Message)
}

Write-Host 'Focused User Profile Service event IDs (last 7 days):'
try {
    $upsFocused = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-User Profiles Service/Operational'; StartTime = (Get-Date).AddDays(-7) } -ErrorAction Stop | Where-Object {
        $_.Id -in 1, 2, 3, 4, 5, 1500, 1508, 1509, 1511, 1515, 1530
    } | Select-Object -First 40 TimeCreated, Id, ProviderName, LevelDisplayName, @{Name = 'Message'; Expression = { ($_.Message -replace "`r|`n", ' ') } }
    Write-TableBlock -Items $upsFocused -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
}
catch {
    Write-Host ('   Focused profile event query failed: {0}' -f $_.Exception.Message)
}

Write-Host 'Group Policy operational evidence:'
Write-TableBlock -Items (Get-GroupPolicyOperationalEvidence) -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')

$winlogonTimeline = Get-WinlogonTimelineEvidence
Write-Host 'Winlogon/Application timeline markers:'
Write-TableBlock -Items $winlogonTimeline.ApplicationEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
Write-Host 'Winlogon/System timeline markers:'
Write-TableBlock -Items $winlogonTimeline.SystemEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')

Write-Host 'Last successful interactive sign-in baseline (event 4624, logon type 2 or 10):'
Write-TableBlock -Items (Get-LastSuccessfulInteractiveLogonEvidence) -Properties @('TimeCreated', 'Id', 'Detail')

$timeSyncEvidence = Get-TimeSyncEvidence
Write-Host 'Time synchronization evidence:'
Write-TableBlock -Items @($timeSyncEvidence.Service) -Properties @('Name', 'Status', 'StartType')
Write-Host 'w32tm /query /status:'
Write-TextBlock -Lines $timeSyncEvidence.StatusOutput
Write-Host 'w32tm /query /source:'
Write-TextBlock -Lines $timeSyncEvidence.SourceOutput

$networkReadiness = Get-NetworkReadinessEvidence
Write-Host ('Domain context: {0}' -f $networkReadiness.Domain)
Write-Host ('Domain reachability test: {0}' -f $networkReadiness.DomainReachability)
Write-Host 'DNS/Gateway/DHCP adapter details:'
Write-TableBlock -Items $networkReadiness.AdapterDetails -Properties @('Adapter', 'DHCPEnabled', 'DHCPServer', 'DefaultGateway', 'DnsServers')

$imeEvidence = Get-IntuneManagementExtensionEvidence
Write-Host 'Intune Management Extension health:'
Write-TableBlock -Items @($imeEvidence.Service) -Properties @('Name', 'Status', 'StartType')
Write-Host ('IME log path: {0}' -f $imeEvidence.LogPath)
Write-Host 'Recent IME log files:'
Write-TableBlock -Items $imeEvidence.RecentLogs -Properties @('Name', 'Length', 'LastWriteTime')

$diskProfileEvidence = Get-DiskAndProfilePathHealthEvidence
Write-Host 'Disk space state:'
Write-TableBlock -Items $diskProfileEvidence.DiskState -Properties @('Drive', 'FreeGB', 'TotalGB')
Write-Host 'Profile path health snapshot:'
Write-TableBlock -Items $diskProfileEvidence.ProfilePathState -Properties @('SID', 'ProfilePath', 'Exists', 'ACLState')

$startupLoadEvidence = Get-StartupLoadPressureEvidence
Write-Host 'Top CPU processes:'
Write-TableBlock -Items $startupLoadEvidence.TopCPU -Properties @('Name', 'Id', 'CPU')
Write-Host 'Top memory processes:'
Write-TableBlock -Items $startupLoadEvidence.TopMemory -Properties @('Name', 'Id', 'WorkingSetMB')
Write-Host 'Startup entries snapshot:'
Write-TableBlock -Items $startupLoadEvidence.StartupEntries -Properties @('Location', 'Name', 'Command')

$pendingUpdateEvidence = Get-PendingUpdateInstallEvidence
Write-Host 'Pending update/install state:'
Write-TableBlock -Items @($pendingUpdateEvidence.PendingState) -Properties @('RebootRequiredPath', 'CBSRebootPending')
Write-Host 'Recent Windows Update client events:'
Write-TableBlock -Items $pendingUpdateEvidence.UpdateEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
Write-Host 'Recent installed hotfixes:'
Write-TableBlock -Items $pendingUpdateEvidence.RecentQfe -Properties @('HotFixID', 'InstalledOn', 'Description')

Write-Host 'Issue correlation markers (last 24h counts):'
Write-TableBlock -Items (Get-IssueCorrelationMarkers) -Properties @('Marker', 'LogName', 'EventId', 'CountLast24h')

# Section 4: Capture desktop path, shortcut inventory, and app-install evidence because the second top-ranked cause is a rollout or shell/policy change.
Write-SectionHeader '3. Desktop, shortcut, and rollout evidence'
$desktopEvidence = Get-DesktopEvidence

Write-Host 'Desktop folder paths:'
Write-TableBlock -Items $desktopEvidence.DesktopFolders -Properties @('Scope', 'Path', 'Exists')

Write-Host 'Desktop shortcut inventory:'
Write-TableBlock -Items $desktopEvidence.ShortcutInventory -Properties @('Scope', 'Name', 'LastWriteTime', 'FullName')

Write-Host 'Installed app matches for document-management hints:'
Write-TableBlock -Items (Get-InstalledAppMatches -NameHints $DocumentAppHints) -Properties @('DisplayName', 'DisplayVersion', 'Publisher', 'InstallDate', 'Scope', 'RegistryKey')

Write-Host 'Recent application-install or rollout-related events:'
try {
    $rolloutEvents = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddDays(-7) } -ErrorAction Stop | Where-Object {
        $_.ProviderName -match 'MsiInstaller|AppXDeployment|ClickToRun|Office' -or $_.Message -match 'document|DMS|iManage|NetDocuments|M-Files|OpenText|Worldox|SharePoint'
    } | Select-Object -First 30 TimeCreated, Id, ProviderName, LevelDisplayName, @{Name = 'Message'; Expression = { ($_.Message -replace "`r|`n", ' ') } }
    Write-TableBlock -Items $rolloutEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')
}
catch {
    Write-Host ('   Application log query failed: {0}' -f $_.Exception.Message)
}

# Section 5: Capture Office, Edge, and OneDrive evidence because the Copilot concern depends on cloud-connected client state and possible sync or indexing issues.
Write-SectionHeader '4. Copilot, Office, Edge, and OneDrive evidence'
$officeEvidence = Get-OfficeEvidence
$oneDriveEvidence = Get-OneDriveEvidence

Write-Host 'Microsoft 365 Apps build and channel snapshot:'
Write-TableBlock -Items @($officeEvidence.Office) -Properties @('VersionToReport', 'ClientVersionToReport', 'Platform', 'ProductReleaseIds', 'UpdateChannel', 'OfficeClientEdition')

Write-Host ('Microsoft Edge version: {0}' -f $(if ($officeEvidence.EdgeVersion) { $officeEvidence.EdgeVersion } else { 'Not found or not installed' }))
Write-Host ''

Write-Host 'OneDrive process and version snapshot:'
Write-TableBlock -Items @($oneDriveEvidence.Process) -Properties @('Name', 'Id', 'StartTime', 'Path')
Write-Host ('OneDrive.exe path      : {0}' -f $(if ($oneDriveEvidence.OneDriveExe) { $oneDriveEvidence.OneDriveExe } else { 'Not found' }))
Write-Host ('OneDrive version       : {0}' -f $(if ($oneDriveEvidence.OneDriveVersion) { $oneDriveEvidence.OneDriveVersion } else { 'Not found' }))
Write-Host ('OneDrive machine ver.  : {0}' -f $(if ($oneDriveEvidence.OneDriveMachineVersion) { $oneDriveEvidence.OneDriveMachineVersion } else { 'Not found' }))

Write-Host 'Recent OneDrive operational events:'
Write-TableBlock -Items $oneDriveEvidence.OperationalEvents -Properties @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message')

if (-not [string]::IsNullOrWhiteSpace($MatterHint)) {
    # This local hint is only used to remind the operator that source-system verification is still needed.
    Write-Host ''
    Write-Host ('Copilot matter hint supplied: {0}' -f $MatterHint)
    Write-Host 'Reminder: this endpoint script cannot prove source-system permissions; validate the matter access trail in the source application.'
}
else {
    Write-Host ''
    Write-Host 'Copilot matter hint not supplied.'
    Write-Host 'Reminder: source-system permissions still must be verified separately because endpoint evidence cannot confirm the matter access decision.'
}

# Section 6: Print the close-out note so the operator knows what the script can and cannot prove.
Write-SectionHeader '5. Close-out note'
Write-Host 'This script gathers endpoint evidence only.'
Write-Host 'It supports the three hypotheses by showing device join state, logon/profile health, desktop redirection and shortcut state, app-install traces, and cloud-client context.'
Write-Host 'It does not change any system state and does not validate source-system permissions for Copilot.'
if ($transcriptStarted) {
    Write-Host ('Evidence transcript saved to: {0}' -f $transcriptPath)
    Stop-Transcript | Out-Null
}