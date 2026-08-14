#Requires -Version 5.1

<#
.SYNOPSIS
Read-only evidence gathering script for the three Floor 6 issues discussed in this chat.

.DESCRIPTION
Collects endpoint-side evidence for the top-ranked cause of each issue:
1. Logon slowness or failure after the Win11 and Intune migration.
2. Missing desktop shortcuts after the document management app rollout.
3. Copilot surfacing a client matter the user believes they should not access.

This script is strictly read-only. It does not create, delete, or modify files, registry values,
policies, services, tasks, accounts, or network settings.

.VERIFY_BEFORE_RUNNING
1. Run this on an affected Floor 6 device, not a known-good control device.
2. If you know the real document management app name, update the default app hints before running so matching is precise.
3. If you know the Copilot matter title or ID, verify it separately with the source system; this endpoint script cannot confirm source permissions by itself.
4. Reading the Security event log may require local admin rights on some devices.
5. The script only gathers evidence and prints it to the console; it does not save output to disk.
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
    $MatterHint = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

# Section 1: Print a startup warning banner so the operator can verify the prerequisites before any evidence collection starts.
Write-SectionHeader 'Floor 6 read-only evidence gathering script'
Write-Host 'This script is read-only and will not change system state.'
Write-Host 'Verify before running: affected Floor 6 device, correct app hints, optional matter hint outside the endpoint, and possible admin rights for Security log access.'

# Section 2: Capture the baseline device identity so the logon, shortcut, and Copilot findings can be tied to one endpoint.
Write-SectionHeader '1. Baseline device and user context'
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
$bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
$uptime = (Get-Date) - $os.LastBootUpTime

Write-Host ('Computer Name      : {0}' -f $env:COMPUTERNAME)
Write-Host ('Logged-on User     : {0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
Write-Host ('Manufacturer       : {0}' -f $computerSystem.Manufacturer)
Write-Host ('Model              : {0}' -f $computerSystem.Model)
Write-Host ('OS Caption         : {0}' -f $os.Caption)
Write-Host ('OS Version         : {0}' -f $os.Version)
Write-Host ('OS Build Number    : {0}' -f $os.BuildNumber)
Write-Host ('Last Boot Time     : {0}' -f $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Host ('Uptime             : {0} days, {1} hours, {2} minutes' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
Write-Host ('BIOS Serial        : {0}' -f $bios.SerialNumber)
Write-Host ('Domain Joined      : {0}' -f $computerSystem.PartOfDomain)
Write-Host ('Domain Name        : {0}' -f $(if ($computerSystem.PartOfDomain) { $computerSystem.Domain } else { 'Not domain joined' }))

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