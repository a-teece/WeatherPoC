#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$gate     = Join-Path $here 'Check-Coverage.ps1'
$fixtures = Join-Path (Split-Path -Parent $here) 'ci/coverage-fixtures'

$cases = @(
    @{ File = 'green.cobertura.xml'; Expected = 0; Name = 'a: fully covered -> green' },
    @{ File = 'below.cobertura.xml'; Expected = 1; Name = 'b: covered < valid -> red (coverage below 100%)' },
    @{ File = 'empty.cobertura.xml'; Expected = 1; Name = 'c: valid == 0 -> red (no coverable lines)' }
)

$failures = 0
foreach ($case in $cases) {
    & pwsh -File $gate -CoberturaPath (Join-Path $fixtures $case.File) | Out-Null
    $actual = $LASTEXITCODE
    if ($actual -ne $case.Expected) {
        Write-Host "SELFTEST FAIL [$($case.Name)]: expected exit $($case.Expected), got $actual"
        $failures++
    }
    else {
        Write-Host "SELFTEST PASS [$($case.Name)]"
    }
}

if ($failures -gt 0) {
    Write-Host "Coverage-gate self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Coverage-gate self-test passed (Seam 1 proofs a, b, c)."
exit 0
