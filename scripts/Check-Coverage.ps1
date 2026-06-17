#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CoberturaPath
)

# Exit codes:
#   0 - PASS: lines-valid > 0 and lines-covered == lines-valid
#   1 - FAIL: a genuine coverage result that does not meet the gate
#   2 - FAIL: the coverage report file is missing
#   3 - FAIL: the file exists but is not a usable Cobertura report (malformed).
#       This is kept distinct from exit 1 so a broken tooling run (truncated
#       file, wrong file, an HTML error page on the output path) cannot be
#       mistaken for a real coverage failure.

if (-not (Test-Path -LiteralPath $CoberturaPath)) {
    Write-Host "FAIL: coverage report not found at '$CoberturaPath'"
    exit 2
}

# Parse defensively. A truncated coverlet run, a UTF-16 BOM, or an HTML error
# page written to the output path must surface as a distinct 'malformed report'
# failure (exit 3), not a raw stack trace and not a coverage failure (exit 1).
#
# DtdProcessing.Ignore + XmlResolver = null is the XXE-safe posture that still
# parses the real artefact: ReportGenerator's Cobertura output carries a
# <!DOCTYPE coverage SYSTEM "...coverage-04.dtd"> declaration, so an outright
# Prohibit would throw on the genuine report. Ignore skips the DTD entirely —
# declared entities are never added and the external SYSTEM subset is never
# fetched — and the null resolver blocks any external resolution, so no entity
# is ever expanded (XXE cannot occur) while a benign DOCTYPE parses cleanly. A
# document that *references* an entity still fails: the entity is undeclared
# (the DTD was skipped), which is a well-formedness error caught as malformed.
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

$coverage = $report.DocumentElement
if ($null -eq $coverage -or $coverage.Name -ne 'coverage') {
    Write-Host "FAIL: coverage report at '$CoberturaPath' has no <coverage> root element - malformed report, not a coverage result"
    exit 3
}

# lines-covered must be present; lines-valid absent is permitted by the Seam 1
# contract and denotes zero coverable lines. Anything present must parse as a
# non-negative integer - a missing or non-numeric value is a malformed report,
# not a project with zero coverage. (Relying on [int]$null -> 0 would silently
# coerce a malformed report into a misleading 'no coverable lines' verdict.)
if (-not $coverage.HasAttribute('lines-covered')) {
    Write-Host "FAIL: coverage report is missing the 'lines-covered' attribute - malformed report, not zero coverage"
    exit 3
}

$linesCovered = 0
if (-not [int]::TryParse($coverage.GetAttribute('lines-covered'), [ref] $linesCovered)) {
    Write-Host "FAIL: 'lines-covered' value '$($coverage.GetAttribute('lines-covered'))' is not an integer - malformed report"
    exit 3
}

$linesValid = 0
if ($coverage.HasAttribute('lines-valid') -and
    -not [int]::TryParse($coverage.GetAttribute('lines-valid'), [ref] $linesValid)) {
    Write-Host "FAIL: 'lines-valid' value '$($coverage.GetAttribute('lines-valid'))' is not an integer - malformed report"
    exit 3
}

Write-Host "Coverage gate: lines-covered=$linesCovered, lines-valid=$linesValid"

if ($linesValid -le 0) {
    Write-Host "FAIL: no coverable lines - the gate cannot be vacuously satisfied"
    exit 1
}

# The Seam 1 contract passes iff lines-covered == lines-valid. Use -ne (not -lt)
# so a malformed report with lines-covered > lines-valid is also rejected rather
# than vacuously passing.
if ($linesCovered -ne $linesValid) {
    Write-Host "FAIL: coverage is not exactly 100% ($linesCovered/$linesValid)"
    exit 1
}

Write-Host "PASS: coverage is 100% ($linesCovered/$linesValid)"
exit 0
