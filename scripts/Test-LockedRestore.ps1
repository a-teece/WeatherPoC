#requires -Version 7.0
<#
.SYNOPSIS
  Proof that a bumped dependency version breaks --locked-mode restore (Story #27 AC3).

.DESCRIPTION
  This self-test proves the locked-restore contract: a packages.lock.json committed
  against one set of resolved transitive dependencies cannot be satisfied when a direct
  dependency version is bumped without regenerating the lockfile.

  The test mutates WeatherPoC.Core.csproj (bumps Serilog from 4.2.0 to 4.3.0),
  runs `dotnet restore --locked-mode`, asserts the restore FAILS (exit != 0), then
  reverts the csproj so the working tree is left clean.
#>
$ErrorActionPreference = 'Stop'

$root     = Split-Path -Parent $PSScriptRoot
$csproj   = Join-Path $root 'WeatherPoC.Core\WeatherPoC.Core.csproj'
$original = Get-Content -LiteralPath $csproj -Raw

Write-Host 'LOCKED-RESTORE SELF-TEST: bumping Serilog 4.2.0 -> 4.3.0 without regenerating lockfile...'

try {
    $bumped = $original -replace 'Include="Serilog" Version="4\.2\.0"', 'Include="Serilog" Version="4.3.0"'
    if ($bumped -eq $original) {
        Write-Host 'FAIL: could not locate Serilog 4.2.0 pin in WeatherPoC.Core.csproj — is the version already different?'
        exit 1
    }
    Set-Content -LiteralPath $csproj -Value $bumped -NoNewline

    $restoreOutput = & dotnet restore (Join-Path $root 'WeatherPoC.Core\WeatherPoC.Core.csproj') --locked-mode 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host 'FAIL: locked-mode restore succeeded after bumping dependency — lockfile is not enforced.'
        Write-Host $restoreOutput
        exit 1
    }

    Write-Host 'PASS: locked-mode restore failed as expected (exit $exitCode) — bumped dependency rejected.'
    Write-Host 'LOCKED-RESTORE SELF-TEST PASSED: --locked-mode enforces the committed dependency graph.'
    exit 0
}
finally {
    Set-Content -LiteralPath $csproj -Value $original -NoNewline
}
