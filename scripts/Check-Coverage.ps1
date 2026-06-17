#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CoberturaPath
)

if (-not (Test-Path -LiteralPath $CoberturaPath)) {
    Write-Host "FAIL: coverage report not found at '$CoberturaPath'"
    exit 2
}

[xml]$report  = Get-Content -LiteralPath $CoberturaPath -Raw
$coverage     = $report.coverage
$linesValid   = [int]$coverage.'lines-valid'
$linesCovered = [int]$coverage.'lines-covered'

Write-Host "Coverage gate: lines-covered=$linesCovered, lines-valid=$linesValid"

if ($linesValid -eq 0) {
    Write-Host "FAIL: no coverable lines - the gate cannot be vacuously satisfied"
    exit 1
}

if ($linesCovered -lt $linesValid) {
    Write-Host "FAIL: coverage below 100%"
    exit 1
}

Write-Host "PASS: coverage is 100% ($linesCovered/$linesValid)"
exit 0
