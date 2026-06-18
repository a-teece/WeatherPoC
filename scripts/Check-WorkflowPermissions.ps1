#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $WorkflowsPath = '.github/workflows',

    # Allowlist of scopes permitted to hold WRITE access in a workflow's top-level
    # `permissions:` block. Intentionally EMPTY: this pipeline only checks out code,
    # runs tests, and uploads a coverage artifact via actions/upload-artifact (which
    # operates with the default token and needs no write scope). Any future step that
    # demonstrably needs a write scope should be granted it at the JOB level, scoped to
    # that one job — not the top-level block — and only then added here with a comment
    # naming the step that requires it. A non-empty top-level grant is a finding by
    # default. The self-test passes a non-empty list to prove the allowlist works.
    [Parameter(Mandatory = $false)]
    [string[]] $AllowedWriteScopes = @()
)

# Story #25 — least-privilege gate. A workflow with no top-level `permissions:` block
# inherits the repository/organisation DEFAULT GITHUB_TOKEN scope, which can include
# write access to `contents` and more. A compromised third-party action or a malicious
# PR step could then abuse a broad token to push code, alter releases, or tamper with a
# protected branch. This gate requires every workflow to declare an explicit top-level
# `permissions:` block and forbids any top-level WRITE scope that is not allowlisted.
#
# Exit codes:
#   0 - PASS: every workflow declares a top-level permissions block with no
#             un-allowlisted write scope
#   1 - FAIL: at least one workflow has no top-level permissions block, or grants a
#             write scope (including write-all) not on the allowlist
#   2 - FAIL: the path is missing or holds no workflow files
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

# Strip a trailing YAML comment (a '#' not inside quotes — good enough for the simple
# scalar values used in permissions blocks) and surrounding whitespace.
function Get-ScalarValue {
    param([string] $Raw)
    $hash = $Raw.IndexOf('#')
    if ($hash -ge 0) { $Raw = $Raw.Substring(0, $hash) }
    return $Raw.Trim()
}

$violations = @()

foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file.FullName)

    # Locate a TOP-LEVEL `permissions:` key — column 0, no leading whitespace. Job-level
    # permissions are indented under `jobs:` and are out of scope for this top-level gate.
    $permIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^permissions:(?<rest>.*)$') {
            $permIndex = $i
            $inlineRest = $Matches['rest']
            break
        }
    }

    if ($permIndex -lt 0) {
        $violations += "$($file.Name): no top-level 'permissions:' block — token inherits the default (possibly broad) scope"
        continue
    }

    # Collect (scope -> level) pairs, whether the block is inline or indented.
    $grants = @()
    $inline = Get-ScalarValue $inlineRest

    if ($inline -eq 'read-all' -or $inline -eq '{}' -or $inline -eq '') {
        # read-all / empty-mapping / block-form-follows: no inline write to record here.
        # (Block-form entries, if any, are gathered from the following indented lines.)
    }
    elseif ($inline -eq 'write-all') {
        $grants += @{ Scope = 'write-all'; Level = 'write' }
    }
    else {
        $violations += "$($file.Name): unrecognised inline permissions value 'permissions: $inline'"
    }

    # If block form, read the indented entries that follow until the next top-level key.
    if ($inline -eq '' -or $inline -eq $null) {
        for ($j = $permIndex + 1; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ($line -match '^\s*$') { continue }            # blank — does not end the block
            if ($line -match '^\s*#') { continue }            # comment — does not end the block
            if ($line -notmatch '^\s') { break }              # non-indented, non-blank — block ends

            if ($line -match '^\s+(?<scope>[\w-]+):\s*(?<level>\S.*)$') {
                $scope = $Matches['scope']
                $level = Get-ScalarValue $Matches['level']
                $grants += @{ Scope = $scope; Level = $level }
            }
        }
    }

    # Flag any write grant whose scope is not on the allowlist.
    $fileClean = $true
    foreach ($g in $grants) {
        if ($g.Level -eq 'write') {
            if ($AllowedWriteScopes -contains $g.Scope) {
                Write-Host "OK (allowlisted write): $($file.Name) -> $($g.Scope): write"
            }
            else {
                $violations += "$($file.Name): top-level write scope '$($g.Scope): write' is not on the allowlist"
                $fileClean = $false
            }
        }
    }
    if ($fileClean) {
        Write-Host "OK: $($file.Name) declares a top-level permissions block with no un-allowlisted write scope"
    }
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "FAIL: $($violations.Count) workflow permission violation(s):"
    $violations | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Host ""
Write-Host "PASS: all $($files.Count) workflow file(s) declare a least-privilege top-level permissions block"
exit 0
