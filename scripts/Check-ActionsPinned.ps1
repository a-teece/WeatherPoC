#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $WorkflowsPath = '.github/workflows'
)

# Story #26 — supply-chain gate. Every third-party GitHub Action referenced by a
# `uses:` clause must be pinned to a full 40-character commit SHA, never a mutable
# tag or branch (which an upstream owner — or an attacker who compromises the
# action's repo — can repoint to run different code on our runner with GITHUB_TOKEN).
#
# Exit codes:
#   0 - PASS: every third-party `uses:` ref is a 40-hex commit SHA
#   1 - FAIL: at least one ref is a tag, branch, or short/!40-hex SHA
#   2 - FAIL: the path is missing or holds no workflow files / no third-party refs
#       (kept distinct so the gate cannot be vacuously satisfied by scanning nothing)

if (-not (Test-Path -LiteralPath $WorkflowsPath)) {
    Write-Host "FAIL: workflows path not found at '$WorkflowsPath'"
    exit 2
}

$files = @(Get-ChildItem -LiteralPath $WorkflowsPath -File -Recurse -Include '*.yml', '*.yaml')
if ($files.Count -eq 0) {
    Write-Host "FAIL: no workflow files (*.yml/*.yaml) under '$WorkflowsPath' - nothing to verify"
    exit 2
}

$shaPattern = '^[0-9a-fA-F]{40}$'
$violations = @()
$checked = 0

foreach ($file in $files) {
    $lineNo = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
        $lineNo++

        # Skip whole-line comments so a "# ... uses: foo" note can't trip the gate.
        if ($line -match '^\s*#') { continue }

        $m = [regex]::Match($line, '(^|\s)uses:\s*[''"]?(?<val>[^''"\s#]+)')
        if (-not $m.Success) { continue }
        $val = $m.Groups['val'].Value

        # Local composite actions (./ or ../) carry no ref and need no pin.
        if ($val -like './*' -or $val -like '../*') {
            Write-Host "SKIP (local action): $($file.Name):$lineNo -> $val"
            continue
        }
        # Docker image refs use a different digest format; out of scope for this gate.
        if ($val -like 'docker://*') {
            Write-Host "SKIP (docker ref): $($file.Name):$lineNo -> $val"
            continue
        }

        $checked++
        $at = $val.LastIndexOf('@')
        if ($at -lt 0) {
            $violations += "$($file.Name):$lineNo -> '$val' (no @ref — unpinned)"
            continue
        }

        $ref = $val.Substring($at + 1)
        if ($ref -notmatch $shaPattern) {
            $violations += "$($file.Name):$lineNo -> '$val' (ref '$ref' is not a 40-hex commit SHA)"
        }
        else {
            Write-Host "OK: $($file.Name):$lineNo -> $val"
        }
    }
}

if ($checked -eq 0) {
    Write-Host "FAIL: no third-party 'uses:' references found to verify - gate cannot be vacuously satisfied"
    exit 2
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "FAIL: $($violations.Count) action reference(s) not pinned to a 40-hex commit SHA:"
    $violations | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Host ""
Write-Host "PASS: all $checked third-party action reference(s) pinned to 40-hex commit SHAs"
exit 0
