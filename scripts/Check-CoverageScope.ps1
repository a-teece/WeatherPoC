#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CoberturaPath
)

# Exit codes:
#   0 - PASS: coverage measures exactly WeatherPoC.Core (no more, no less)
#   1 - FAIL: unexpected assembly in scope, or WeatherPoC.Core missing
#   2 - FAIL: the coverage report file is missing
#   3 - FAIL: the file exists but is not a usable Cobertura report (malformed)

if (-not (Test-Path -LiteralPath $CoberturaPath)) {
    Write-Host "FAIL: coverage report not found at '$CoberturaPath'"
    exit 2
}

# Parse defensively with XXE prevention — same approach as Check-Coverage.ps1:
# DtdProcessing.Ignore + null resolver is XXE-safe (no entity is ever expanded,
# no external subset fetched) yet still parses ReportGenerator's real report,
# which carries a <!DOCTYPE coverage SYSTEM "..."> declaration.
try {
    $xmlSettings = [System.Xml.XmlReaderSettings]::new()
    $xmlSettings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $xmlSettings.XmlResolver = $null
    $xmlReader = [System.Xml.XmlReader]::Create($CoberturaPath, $xmlSettings)
    try {
        $report = [System.Xml.XmlDocument]::new()
        $report.Load($xmlReader)
    }
    finally {
        $xmlReader.Dispose()
    }
}
catch {
    Write-Host "FAIL: coverage report at '$CoberturaPath' is not well-formed XML - $($_.Exception.Message)"
    exit 3
}

$root = $report.DocumentElement
if ($null -eq $root -or $root.Name -ne 'coverage') {
    Write-Host "FAIL: coverage report at '$CoberturaPath' has no <coverage> root element - malformed report"
    exit 3
}

$packages = @($root.packages.package | Where-Object { $null -ne $_ } | ForEach-Object { $_.GetAttribute('name') }) | Sort-Object -Unique

Write-Host "Measured assemblies: $(if ($packages.Count -gt 0) { $packages -join ', ' } else { '(none)' })"

$expected   = @('WeatherPoC.Core')
$unexpected = $packages | Where-Object { $_ -notin $expected }

if ($unexpected) {
    Write-Host "FAIL: coverage measured assemblies outside WeatherPoC.Core: $($unexpected -join ', ')"
    exit 1
}

if ($packages -notcontains 'WeatherPoC.Core') {
    Write-Host "FAIL: WeatherPoC.Core not present in coverage report"
    exit 1
}

Write-Host "PASS: coverage scoped to WeatherPoC.Core only"
exit 0
