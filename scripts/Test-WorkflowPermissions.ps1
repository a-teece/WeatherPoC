#requires -Version 7.0
$ErrorActionPreference = 'Stop'

# Boundary-crossing self-test for Check-WorkflowPermissions.ps1 (Story #25). Runs the
# real gate against synthetic, throwaway workflow trees written to a temp directory —
# never the repo's own workflows — covering: top-level read block, missing block,
# un-allowlisted write, write-all, read-all, empty mapping, allowlisted write, a
# job-level write that must be ignored, and an empty directory.

$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$check = Join-Path $here 'Check-WorkflowPermissions.ps1'

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-perms-selftest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null

function New-WorkflowDir {
    param([string] $Name, [string] $Body)
    $dir = Join-Path $root $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'wf.yml') -Value $Body
    return $dir
}

$failures = 0
try {
    $readDir = New-WorkflowDir 'read' @"
name: CI
permissions:
  contents: read
jobs:
  j:
    steps:
      - run: echo hi
"@

    $missingDir = New-WorkflowDir 'missing' @"
name: CI
jobs:
  j:
    steps:
      - run: echo hi
"@

    $writeDir = New-WorkflowDir 'write' @"
name: CI
permissions:
  contents: write
jobs:
  j:
    steps:
      - run: echo hi
"@

    $writeAllDir = New-WorkflowDir 'writeall' @"
name: CI
permissions: write-all
jobs:
  j:
    steps:
      - run: echo hi
"@

    $readAllDir = New-WorkflowDir 'readall' @"
name: CI
permissions: read-all
jobs:
  j:
    steps:
      - run: echo hi
"@

    $emptyMapDir = New-WorkflowDir 'emptymap' @"
name: CI
permissions: {}
jobs:
  j:
    steps:
      - run: echo hi
"@

    # Top-level read, but a job-level write scoped to one job — must be IGNORED by the
    # top-level gate (proves we don't false-positive on a correctly job-scoped grant).
    $jobLevelDir = New-WorkflowDir 'joblevel' @"
name: CI
permissions:
  contents: read
jobs:
  releaser:
    permissions:
      contents: write
    steps:
      - run: echo hi
"@

    $emptyDir = Join-Path $root 'empty'
    New-Item -ItemType Directory -Path $emptyDir | Out-Null

    # Each case carries its own optional allowlist (passed through to the gate).
    $cases = @(
        @{ Path = $readDir;     Expected = 0; Allow = @();           Name = 'a: top-level contents:read -> pass (exit 0)' },
        @{ Path = $missingDir;  Expected = 1; Allow = @();           Name = 'b: no permissions block -> fail (exit 1)' },
        @{ Path = $writeDir;    Expected = 1; Allow = @();           Name = 'c: un-allowlisted contents:write -> fail (exit 1)' },
        @{ Path = $writeAllDir; Expected = 1; Allow = @();           Name = 'd: write-all -> fail (exit 1)' },
        @{ Path = $readAllDir;  Expected = 0; Allow = @();           Name = 'e: read-all -> pass (exit 0)' },
        @{ Path = $emptyMapDir; Expected = 0; Allow = @();           Name = 'f: empty mapping {} -> pass (exit 0)' },
        @{ Path = $writeDir;    Expected = 0; Allow = @('contents'); Name = 'g: contents:write WITH allowlist -> pass (exit 0)' },
        @{ Path = $jobLevelDir; Expected = 0; Allow = @();           Name = 'h: job-level write ignored, top-level read -> pass (exit 0)' },
        @{ Path = $emptyDir;    Expected = 2; Allow = @();           Name = 'i: no workflow files -> exit 2 (not vacuous)' }
    )

    foreach ($case in $cases) {
        # Build args explicitly: passing an empty @() as a named argument would unroll
        # to nothing and trip "missing argument", so only add the param when non-empty.
        $gateArgs = @('-File', $check, '-WorkflowsPath', $case.Path)
        if ($case.Allow.Count -gt 0) {
            $gateArgs += '-AllowedWriteScopes'
            $gateArgs += $case.Allow
        }
        & pwsh @gateArgs | Out-Null
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
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures -gt 0) {
    Write-Host "Workflow-permissions self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Workflow-permissions self-test passed (proofs a, b, c, d, e, f, g, h, i)."
exit 0
