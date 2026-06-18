#requires -Version 7.0
<#
.SYNOPSIS
  Story #28 self-test: proves the secret scanner detects committed credentials (AC2)
  and passes on a clean tree (AC3).

.DESCRIPTION
  (a) canary: a temp git repo with a fake AWS access key committed → gitleaks exits non-zero.
  (b) clean:  a temp git repo with no secrets committed           → gitleaks exits 0.

  Each case uses an isolated temp git repository so the fake credentials never appear
  in this project's working tree or history. The key in case (a) is constructed via
  string concatenation so the regex pattern does not match THIS script file when the
  main-repo scan runs.
#>
$ErrorActionPreference = 'Stop'

if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
    Write-Host 'FAIL: gitleaks not found in PATH — install gitleaks before running this self-test.'
    exit 1
}

Write-Host ("SECRET-SCAN SELF-TEST: gitleaks {0}" -f (& gitleaks version 2>&1))

$failures = 0

function New-TempGitRepo {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("secretscan-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $dir | Out-Null
    git -C $dir init -q
    git -C $dir config user.email "ci@example.invalid"
    git -C $dir config user.name "CI Self-Test"
    return $dir
}

$tmpDirs = [System.Collections.Generic.List[string]]::new()
try {
    # ── (a) canary ────────────────────────────────────────────────────────────
    # Fake AWS access key committed in a temp repo → gitleaks must exit non-zero.
    # The key ID is split across two literals ("AKIA" + "IOSFODNN7EXAMPLE") so the
    # 20-char token does not appear as a continuous substring in this committed
    # script file; the full token only exists in the temp repo's git history.
    $canaryDir = New-TempGitRepo
    $tmpDirs.Add($canaryDir)
    $fakeKeyId = "AKIA" + "IOSFODNN7EXAMPLE"
    Set-Content -LiteralPath (Join-Path $canaryDir '.env') -Value "AWS_ACCESS_KEY_ID=$fakeKeyId"
    git -C $canaryDir add .
    git -C $canaryDir commit -q -m "config: add environment settings"

    # gitleaks exit codes: 0 = clean, 1 = leaks found. Any other code is gitleaks
    # itself erroring, which must NOT be mistaken for a detection (the previous
    # version passed `--quiet`, which gitleaks does not accept; it errored on every
    # run and case (a) passed spuriously while case (b) failed — exit 126).
    & gitleaks detect --source $canaryDir --no-banner --redact
    $code = $LASTEXITCODE
    if ($code -eq 1) {
        Write-Host "SELFTEST PASS [a: canary AWS key committed -> gitleaks detects it (exit 1)]"
    }
    elseif ($code -eq 0) {
        Write-Host "SELFTEST FAIL [a: canary AWS key committed -> NOT detected (exit 0)]"
        $failures++
    }
    else {
        Write-Host "SELFTEST FAIL [a: canary -> gitleaks errored (exit $code), not a detection]"
        $failures++
    }

    # ── (b) clean ─────────────────────────────────────────────────────────────
    # A temp repo with no secrets → gitleaks must exit 0.
    $cleanDir = New-TempGitRepo
    $tmpDirs.Add($cleanDir)
    Set-Content -LiteralPath (Join-Path $cleanDir 'README.md') -Value '# WeatherPoC — no secrets here'
    git -C $cleanDir add .
    git -C $cleanDir commit -q -m "docs: initial commit"

    & gitleaks detect --source $cleanDir --no-banner --redact
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host "SELFTEST PASS [b: clean repo -> gitleaks passes (exit 0)]"
    }
    elseif ($code -eq 1) {
        Write-Host "SELFTEST FAIL [b: clean repo -> false positive (exit 1)]"
        $failures++
    }
    else {
        Write-Host "SELFTEST FAIL [b: clean repo -> gitleaks errored (exit $code), not exit 0]"
        $failures++
    }
}
finally {
    foreach ($d in $tmpDirs) {
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures -gt 0) {
    Write-Host "Secret-scan self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Secret-scan self-test passed (Story #28 proofs a, b)."
exit 0
