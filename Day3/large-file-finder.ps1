[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SearchPath = (Split-Path -Parent $PSScriptRoot),

    [Parameter(Mandatory = $false)]
    [int]$MinSizeMB = 100,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = (Join-Path $PSScriptRoot ("large-files-report_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt"))
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $SearchPath)) {
        throw "Search path does not exist: $SearchPath"
    }

    $minBytes = [int64]$MinSizeMB * 1MB

    # Read-only scan for files at or above the requested size.
    $files = Get-ChildItem -LiteralPath $SearchPath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -ge $minBytes } |
        Sort-Object Length -Descending

    $reportLines = New-Object System.Collections.Generic.List[string]
    $reportLines.Add("Large File Report")
    $reportLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $reportLines.Add("Search Path: $SearchPath")
    $reportLines.Add("Threshold: $MinSizeMB MB")
    $reportLines.Add("")

    if (-not $files -or $files.Count -eq 0) {
        $reportLines.Add("No files found at or above $MinSizeMB MB.")
    }
    else {
        $reportLines.Add(("{0,-12} {1,-22} {2}" -f "Size(MB)", "LastWriteTime", "FullName"))
        $reportLines.Add(("{0,-12} {1,-22} {2}" -f "--------", "-------------", "--------"))

        foreach ($file in $files) {
            $sizeMB = [math]::Round($file.Length / 1MB, 2)
            $line = "{0,-12} {1,-22} {2}" -f $sizeMB, $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $file.FullName
            $reportLines.Add($line)
        }

        $reportLines.Add("")
        $reportLines.Add("Total files found: $($files.Count)")
    }

    $reportLines | Out-File -LiteralPath $OutputFile -Encoding UTF8

    Write-Host "Report saved to: $OutputFile"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
