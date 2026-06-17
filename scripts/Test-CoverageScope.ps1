#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$script   = Join-Path $here 'Check-CoverageScope.ps1'
$fixtures = Join-Path (Split-Path -Parent $here) 'ci/coverage-fixtures'

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("covscope-selftest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

$failures = 0
try {
    $missingFile = Join-Path $tmp 'does-not-exist.cobertura.xml'

    $malformedFile = Join-Path $tmp 'malformed.cobertura.xml'
    Set-Content -LiteralPath $malformedFile -Value '<coverage line-rate="1"'

    $wrongRootFile = Join-Path $tmp 'wrongroot.cobertura.xml'
    Set-Content -LiteralPath $wrongRootFile -Value '<html><body>500 Internal Server Error</body></html>'

    $extraAssemblyFile = Join-Path $tmp 'extra-assembly.cobertura.xml'
    Set-Content -LiteralPath $extraAssemblyFile -Value @'
<?xml version="1.0" encoding="utf-8"?>
<coverage lines-covered="10" lines-valid="10">
  <packages>
    <package name="WeatherPoC.Core" />
    <package name="WeatherPoC" />
  </packages>
</coverage>
'@

    $onlyExtraFile = Join-Path $tmp 'only-extra.cobertura.xml'
    Set-Content -LiteralPath $onlyExtraFile -Value @'
<?xml version="1.0" encoding="utf-8"?>
<coverage lines-covered="10" lines-valid="10">
  <packages>
    <package name="WeatherPoC" />
  </packages>
</coverage>
'@

    $cases = @(
        @{ Path = (Join-Path $fixtures 'green.cobertura.xml'); Expected = 0; Name = 'a: WeatherPoC.Core only -> pass (exit 0)' },
        @{ Path = (Join-Path $fixtures 'empty.cobertura.xml'); Expected = 1; Name = 'b: no packages -> WeatherPoC.Core missing (exit 1)' },
        @{ Path = $extraAssemblyFile;  Expected = 1; Name = 'c: extra assembly alongside WeatherPoC.Core -> fail (exit 1)' },
        @{ Path = $onlyExtraFile;      Expected = 1; Name = 'd: only unexpected assembly, no WeatherPoC.Core -> fail (exit 1)' },
        @{ Path = $missingFile;        Expected = 2; Name = 'e: report file missing -> exit 2' },
        @{ Path = $malformedFile;      Expected = 3; Name = 'f: not well-formed XML -> malformed (exit 3)' },
        @{ Path = $wrongRootFile;      Expected = 3; Name = 'g: no <coverage> root -> malformed (exit 3)' }
    )

    foreach ($case in $cases) {
        & pwsh -File $script -CoberturaPath $case.Path | Out-Null
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
    Write-Host "Coverage-scope self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Coverage-scope self-test passed (Seam 2 proofs a, b, c, d; guard rails e, f, g)."
exit 0
