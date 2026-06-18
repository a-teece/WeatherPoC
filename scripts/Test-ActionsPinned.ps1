#requires -Version 7.0
$ErrorActionPreference = 'Stop'

# Boundary-crossing self-test for Check-ActionsPinned.ps1 (Story #26). Runs the real
# gate against synthetic, throwaway workflow trees written to a temp directory — never
# the repo's own workflows — covering pinned/tag/branch/short/no-ref/local/empty cases.

$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$check = Join-Path $here 'Check-ActionsPinned.ps1'

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("actions-pinned-selftest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null

$sha = '0123456789abcdef0123456789abcdef01234567'  # 40 hex chars

function New-WorkflowDir {
    param([string] $Name, [string] $Body)
    $dir = Join-Path $root $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'wf.yml') -Value $Body
    return $dir
}

$failures = 0
try {
    $pinnedDir = New-WorkflowDir 'pinned' @"
jobs:
  j:
    steps:
      - uses: actions/checkout@$sha # v4.3.1
      - uses: actions/setup-dotnet@$sha
"@

    $tagDir    = New-WorkflowDir 'tag'    "jobs:`n  j:`n    steps:`n      - uses: actions/checkout@v4`n"
    $branchDir = New-WorkflowDir 'branch' "jobs:`n  j:`n    steps:`n      - uses: actions/checkout@main`n"
    $shortDir  = New-WorkflowDir 'short'  "jobs:`n  j:`n    steps:`n      - uses: actions/checkout@1234567`n"
    $noRefDir  = New-WorkflowDir 'noref'  "jobs:`n  j:`n    steps:`n      - uses: actions/checkout`n"

    $localDir = New-WorkflowDir 'local' @"
jobs:
  j:
    steps:
      - uses: ./.github/actions/local-thing
      - uses: actions/checkout@$sha
"@

    $emptyDir = Join-Path $root 'empty'
    New-Item -ItemType Directory -Path $emptyDir | Out-Null

    $cases = @(
        @{ Path = $pinnedDir; Expected = 0; Name = 'a: all refs 40-hex SHA -> pass (exit 0)' },
        @{ Path = $tagDir;    Expected = 1; Name = 'b: mutable tag @v4 -> fail (exit 1)' },
        @{ Path = $branchDir; Expected = 1; Name = 'c: branch @main -> fail (exit 1)' },
        @{ Path = $shortDir;  Expected = 1; Name = 'd: short SHA @1234567 -> fail (exit 1)' },
        @{ Path = $noRefDir;  Expected = 1; Name = 'e: no @ref at all -> fail (exit 1)' },
        @{ Path = $localDir;  Expected = 0; Name = 'f: local ./ action exempt, sibling pinned -> pass (exit 0)' },
        @{ Path = $emptyDir;  Expected = 2; Name = 'g: no workflow files -> exit 2 (not vacuous)' }
    )

    foreach ($case in $cases) {
        & pwsh -File $check -WorkflowsPath $case.Path | Out-Null
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
    Write-Host "Actions-pinned self-test FAILED ($failures case(s))."
    exit 1
}

Write-Host "Actions-pinned self-test passed (proofs a, b, c, d, e, f, g)."
exit 0
