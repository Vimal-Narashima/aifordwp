[CmdletBinding(DefaultParameterSetName = 'Audit')]
param(
    [Parameter(ParameterSetName = 'Disable', Mandatory = $true)]
    [switch]$Disable,

    [Parameter(ParameterSetName = 'Disable', Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProgramName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StartupPrograms {
    [CmdletBinding()]
    param()

    $items = New-Object System.Collections.Generic.List[object]

    function Add-RegistryStartupItems {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Scope,

            [Parameter(Mandatory = $true)]
            [bool]$Enabled
        )

        if (-not (Test-Path -Path $Path)) {
            return
        }

        $props = Get-ItemProperty -Path $Path
        $meta = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

        foreach ($p in $props.PSObject.Properties) {
            if ($meta -contains $p.Name) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace([string]$p.Value)) {
                continue
            }

            $items.Add([PSCustomObject]@{
                Name      = $p.Name
                Command   = [string]$p.Value
                Scope     = $Scope
                Type      = 'Registry'
                Location  = $Path
                Enabled   = $Enabled
                MatchText = ($p.Name + ' ' + [string]$p.Value)
                FullPath  = $null
            })
        }
    }

    function Add-StartupFolderItems {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Scope
        )

        if (-not (Test-Path -Path $Path)) {
            return
        }

        $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $isDisabled = $file.Name -like '*.disabled'

            $items.Add([PSCustomObject]@{
                Name      = $file.BaseName
                Command   = $file.FullName
                Scope     = $Scope
                Type      = 'StartupFolder'
                Location  = $Path
                Enabled   = -not $isDisabled
                MatchText = ($file.Name + ' ' + $file.FullName)
                FullPath  = $file.FullName
            })
        }
    }

    Add-RegistryStartupItems -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Scope 'CurrentUser' -Enabled $true
    Add-RegistryStartupItems -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Scope 'AllUsers' -Enabled $true

    Add-RegistryStartupItems -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run_Disabled_By_Auditor' -Scope 'CurrentUser' -Enabled $false
    Add-RegistryStartupItems -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run_Disabled_By_Auditor' -Scope 'AllUsers' -Enabled $false

    $userStartup = [Environment]::GetFolderPath('Startup')
    $commonStartup = [Environment]::GetFolderPath('CommonStartup')

    Add-StartupFolderItems -Path $userStartup -Scope 'CurrentUser'
    Add-StartupFolderItems -Path $commonStartup -Scope 'AllUsers'

    $items
}

function Disable-StartupProgram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramName
    )

    $allItems = Get-StartupPrograms
    $targetItems = $allItems | Where-Object {
        $_.Enabled -and ($_.Name -like "*$ProgramName*" -or $_.MatchText -like "*$ProgramName*")
    }

    if (-not $targetItems) {
        Write-Warning "No enabled startup program matched '$ProgramName'."
        return
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($item in $targetItems) {
        try {
            if ($item.Type -eq 'Registry') {
                $disabledKey = $item.Location -replace '\\Run$', '\\Run_Disabled_By_Auditor'
                if (-not (Test-Path -Path $disabledKey)) {
                    New-Item -Path $disabledKey -Force | Out-Null
                }

                Set-ItemProperty -Path $disabledKey -Name $item.Name -Value $item.Command -Type String
                Remove-ItemProperty -Path $item.Location -Name $item.Name

                $results.Add([PSCustomObject]@{
                    Name      = $item.Name
                    Type      = $item.Type
                    Scope     = $item.Scope
                    Action    = 'Disabled'
                    Mechanism = 'Moved registry value to Run_Disabled_By_Auditor'
                })
            }
            elseif ($item.Type -eq 'StartupFolder') {
                $newPath = "$($item.FullPath).disabled"
                Rename-Item -Path $item.FullPath -NewName (Split-Path -Path $newPath -Leaf)

                $results.Add([PSCustomObject]@{
                    Name      = $item.Name
                    Type      = $item.Type
                    Scope     = $item.Scope
                    Action    = 'Disabled'
                    Mechanism = 'Renamed startup file with .disabled suffix'
                })
            }
        }
        catch {
            $results.Add([PSCustomObject]@{
                Name      = $item.Name
                Type      = $item.Type
                Scope     = $item.Scope
                Action    = 'Failed'
                Mechanism = $_.Exception.Message
            })
        }
    }

    $results | Sort-Object Scope, Type, Name | Format-Table -AutoSize
}

if ($Disable) {
    Disable-StartupProgram -ProgramName $ProgramName
}
else {
    $startupItems = Get-StartupPrograms | Sort-Object Enabled, Scope, Type, Name -Descending

    if (-not $startupItems) {
        Write-Output 'No startup programs were found in common registry and startup-folder locations.'
        return
    }

    $startupItems |
        Select-Object Name, Scope, Type, Enabled, Command, Location |
        Format-Table -AutoSize
}
