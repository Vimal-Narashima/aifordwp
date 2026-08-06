<#
.SYNOPSIS
    Basic endpoint health snapshot for a Windows machine.

.DESCRIPTION
    Collects and displays:
      - Computer name and total physical RAM
      - Free space remaining on the C: drive
      - Top 5 processes by memory (working set) usage
      - Recent System event log errors (last 10 events, errors only)
      - Count of local user profiles unused for 90 or more days

.AUTHOR
    [Your Name]

.HOW TO RUN
    Open PowerShell as a standard user and run:
        .\inherit.ps1

    No parameters required. No changes are made to the system.
    Local administrator rights may be needed to read all event log entries.
#>

# Retrieve hardware and OS details for this computer from WMI
$computerInfo = Get-CimInstance Win32_ComputerSystem

# Get the number of free bytes currently available on the C: drive
$cDriveFreeBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Collect all running processes, sort by RAM usage (largest first), keep top 5
$topMemoryProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Pull the last 10 System log entries and keep only errors (Level 2)
$recentSystemErrors = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Find local user profiles (excluding built-in/special accounts) not used in 90+ days
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# Display the computer name and total physical RAM in bytes
Write-Host $computerInfo.Name $computerInfo.TotalPhysicalMemory

# Convert free disk space from bytes to GB and display rounded to 2 decimal places
Write-Host ([math]::Round($cDriveFreeBytes / 1GB, 2)) 'GB free'

# Print the process name and working set (RAM) for each of the top 5 memory consumers
$topMemoryProcesses | ForEach-Object { Write-Host $_.Name $_.WS }

# Print the timestamp and message for each recent System error event
$recentSystemErrors | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# If any stale profiles were found, display how many
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }