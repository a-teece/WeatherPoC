#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$gate     = Join-Path $here 'Check-Coverage.ps1'
$fixtures = Join-Path (Split-Path -Parent $here) 'ci/coverage-fixtures'

# The three committed contract fixtures (green/below/empty) are captured from
# ReportGenerator's merged Cobertura.xml - the exact artefact the gate reads in
# CI. The guard-rail inputs below are deliberately synthetic and throwaway: they
# prove the defensive branches (missing file, malformed XML, wrong root, missing
# attribute, over-covered) and must NEVER come from a real run, so they are
# written to a temp directory rather than committed alongside the contract
# fixtures.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("covgate-selftest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

$failures = 0
try {
    $missingFile = Join-Path $tmp 'does-not-exist.cobertura.xml'

    $malformedFile = Join-Path $tmp 'malformed.cobertura.xml'
    # Truncated element - not well-formed XML.
    Set-Content -LiteralPath $malformedFile -Value '<coverage lines-covered="5" lines-valid="10"'

    $wrongRootFile = Join-Path $tmp 'wrongroot.cobertura.xml'
    # Well-formed XML, but not a coverage report (e.g. an HTML error page).
    Set-Content -LiteralPath $wrongRootFile -Value '<html><body>500 Internal Server Error</body></html>'

    $missingAttrFile = Join-Path $tmp 'missing-attr.cobertura.xml'
    # <coverage> root but no lines-covered attribute - must not coerce to 0.
    Set-Content -LiteralPath $missingAttrFile -Value '<coverage lines-valid="10"></coverage>'

    $overCoveredFile = Join-Path $tmp 'overcovered.cobertura.xml'
    # lines-covered > lines-valid - a malformed result that -lt would let pass.
    Set-Content -LiteralPath $overCoveredFile -Value '<coverage lines-covered="11" lines-valid="10"></coverage>'

    $xxeUnusedFile = Join-Path $tmp 'xxe-unused.cobertura.xml'
    # External entity declaration with no reference in the document body. The gate
    # must reject this even though the entity is never expanded: any file containing
    # a DTD internal subset is a potential XXE vector and must be treated as malformed.
    Set-Content -LiteralPath $xxeUnusedFile -Value '<?xml version="1.0"?><!DOCTYPE coverage [<!ENTITY xxe SYSTEM "file:///C:/Windows/System32/drivers/etc/hosts">]><coverage lines-covered="10" lines-valid="10"></coverage>'

    $xxeUsedFile = Join-Path $tmp 'xxe-used.cobertura.xml'
    # External entity injected into the lines-covered attribute — the classic XXE
    # attribute-injection vector. Must be rejected as malformed, not silently coerced.
    Set-Content -LiteralPath $xxeUsedFile -Value '<?xml version="1.0"?><!DOCTYPE coverage [<!ENTITY xxe SYSTEM "file:///C:/Windows/System32/drivers/etc/hosts">]><coverage lines-covered="&xxe;" lines-valid="10"></coverage>'

    $cases = @(
        @{ Path = (Join-Path $fixtures 'green.cobertura.xml'); Expected = 0; Name = 'a: fully covered -> green (exit 0)' },
        @{ Path = (Join-Path $fixtures 'below.cobertura.xml'); Expected = 1; Name = 'b: covered < valid -> red, coverage below 100% (exit 1)' },
        @{ Path = (Join-Path $fixtures 'empty.cobertura.xml'); Expected = 1; Name = 'c: valid == 0 -> red, no coverable lines (exit 1)' },
        @{ Path = $missingFile;     Expected = 2; Name = 'd: report file missing -> exit 2' },
        @{ Path = $malformedFile;   Expected = 3; Name = 'e: not well-formed XML -> malformed (exit 3)' },
        @{ Path = $wrongRootFile;   Expected = 3; Name = 'f: no <coverage> root -> malformed (exit 3)' },
        @{ Path = $missingAttrFile; Expected = 3; Name = 'g: missing lines-covered attribute -> malformed (exit 3)' },
        @{ Path = $overCoveredFile;  Expected = 1; Name = 'h: covered > valid -> red, not exactly 100% (exit 1)' },
        @{ Path = $xxeUnusedFile;   Expected = 3; Name = 'i: external entity declared but not used (xxe) -> malformed (exit 3)' },
        @{ Path = $xxeUsedFile;     Expected = 3; Name = 'j: external entity injected into attribute (xxe) -> malformed (exit 3)' }
    )

    foreach ($case in $cases) {
        & pwsh -File $gate -CoberturaPath $case.Path | Out-Null
        $actual = $LASTEXITCODE
        if ($actual -ne $case.Expected) {
            Write-Host "SELFTEST FAIL [$($case.Name)]: expected exit $($case.Expected), got $actual"
            $failures++
        }
        else {
            Write-Host "SELFTEST PASS [$($case.Name)]"
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures -gt 0) {
    Write-Host "Coverage-gate self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Coverage-gate self-test passed (Seam 1 proofs a, b, c; guard rails d, e, f, g, h, i, j)."
exit 0
