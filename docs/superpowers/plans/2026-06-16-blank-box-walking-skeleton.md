# Blank-box Walking Skeleton Implementation Plan

> **For agentic workers:** Do NOT implement this plan directly. It must first pass `/feature-doc-gauntlet` in a clean session, then be broken into stories by `/enate-to-stories`; AFK implementation happens per-story from there. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a native Windows .NET MAUI app that launches to an empty box, backed by an xUnit test project and a CI pipeline that builds the app, runs the tests, and enforces a 100%-unit-test-coverage gate proven able to *fail* a build.

**Architecture:** Three projects in one solution — a coverage-excluded MAUI app head (`WeatherPoC`), a plain `net10.0` gated production surface (`WeatherPoC.Core`) holding the Serilog logging-configuration module `LoggingSetup` (the one real, testable piece of infrastructure the skeleton needs, and the gated surface's coverable code), and an xUnit test project (`WeatherPoC.Tests`) that references Core but **not** the app. The coverage gate's pass/fail rule lives in a standalone PowerShell script proven against real **ReportGenerator-produced** Cobertura fixtures — the exact artefact CI gates on; CI wires that script in plus a scope assertion and a self-test that reproduces the gate's green/red behaviour deterministically. No domain logic ships in this Feature (logging configuration is infrastructure, not domain).

**Tech Stack:** .NET MAUI on .NET 10, MVVM (CommunityToolkit.Mvvm), Serilog (+ Serilog.Extensions.Logging, rolling-file and Debug sinks), xUnit + Moq + AwesomeAssertions + coverlet.collector, ReportGenerator, GitHub Actions on `windows-latest`. (All matching `Technical-Context.MD` → Packages in use.)

**Context references:**
- Spec: `docs/superpowers/specs/0001-blank-box-walking-skeleton.md`
- `Context.MD`
- `Technical-Context.MD` (Overriding Principles that apply: **P5** — 100% coverage gate with XAML View / DI composition root / Serilog bootstrap coverage-excluded *(headline)*; **P2** — UI thread never blocks *(trivially satisfied — no UI-thread I/O here)*; **P4** — unit tests never touch the network *(satisfied: the `LoggingSetup` test does real **disk** I/O in a temp directory, not network)*; **P1/P3** latent — no secrets, no provider yet)
- `Roadmap.md` — Feature 1 entry
- `PRD.md` — stories 38–41 (privacy, local logs, Windows native, macOS-viable), Architecture, Testing Decisions
- ADRs (awareness only — neither is implemented here): `docs/adr/0001-location-detection-cascade.md`, `docs/adr/0002-per-measurement-unit-defaults.md`
- `docs/superpowers/consistency-checks/2026-06-16.md` — finding C1 (R1 reconciliation)
- Seam taxonomy (reference-only — lives in the sibling `enate-claude-skills` repo, **not** in this project tree; the seam contracts it governs are inlined verbatim in the Tasks below, so an AFK Developer Agent need not fetch it): `../enate-claude-skills/docs/seam-taxonomy.md`

> An AFK Developer Agent picking up this plan MUST load every file in the Context references block before writing code.

**A note on package versions:** the versions pinned below are current as of 2026-06 and satisfy spec §9 (versions pinned at Plan time). At the first `dotnet restore` the engineer confirms each resolves against the live NuGet feed and the installed .NET 10 / MAUI workload, and bumps to the nearest available patch if a pin is missing. The `net10.0-windows10.0.19041.0` TFM revision (spec §9) is confirmed against the installed Windows SDK at that point.

**Seam 3 toolchain authority (spec §5 Seam 3 (e)):** the .NET 10 / MAUI Windows target is grounded against the live Microsoft source, not model memory — *Supported platforms for .NET MAUI apps* (`learn.microsoft.com/dotnet/maui/supported-platforms?view=net-maui-10.0`: Windows 11 / Windows 10 version 1809 = `10.0.17763.0` or higher, via WinUI 3) and the *dotnet/maui Release-Versions* wiki (`github.com/dotnet/maui/wiki/Release-Versions`, the authority for exact .NET 10 / Windows App SDK / MAUI workload versions per release). The binding check is the toolchain actually resolved in CI (`actions/setup-dotnet@v4` at `10.0.x` + `dotnet workload install maui` + `dotnet restore`), so the pins above are confirmed live, not asserted.

---

## File Structure

| File | Responsibility | Coverage |
|---|---|---|
| `WeatherPoC.sln` | Solution tying the three projects together | n/a |
| `WeatherPoC.Core/WeatherPoC.Core.csproj` | Plain `net10.0` gated production surface; references only Serilog + `Serilog.Sinks.File` (cross-platform — no MAUI/Windows deps, macOS-viable spine) | **included — the gated surface** |
| `WeatherPoC.Core/LoggingSetup.cs` | The Serilog rolling-file configuration (Seam 4 write contract): takes a base directory, returns a configured `LoggerConfiguration`. The gated surface's real coverable code | included |
| `WeatherPoC.Tests/WeatherPoC.Tests.csproj` | xUnit test project; references Core **only** (never the app) | not measured |
| `WeatherPoC.Tests/LoggingSetupTests.cs` | Seam 4 on-disk round-trip test: real disk I/O against a temp dir, asserts the line lands in the dated rolling file; 100% covers `LoggingSetup` | not measured |
| `WeatherPoC/WeatherPoC.csproj` | MAUI app head — empty box, single Windows TFM, references Core | **excluded** |
| `WeatherPoC/MauiProgram.cs` | DI composition root + Serilog bootstrap; `[ExcludeFromCodeCoverage]` | excluded |
| `WeatherPoC/App.xaml(.cs)` | Application bootstrap + window creation; `[ExcludeFromCodeCoverage]` | excluded |
| `WeatherPoC/MainPage.xaml(.cs)` | The empty box; emits the startup log line via injected `ILogger`; `[ExcludeFromCodeCoverage]` | excluded |
| `coverage.runsettings` | coverlet config: Cobertura format, `Include [WeatherPoC.Core]*`, `ExcludeByAttribute ExcludeFromCodeCoverageAttribute` | n/a |
| `scripts/Check-Coverage.ps1` | The threshold gate (Seam 1 contract): parse Cobertura, fail on `lines-valid==0` or `lines-covered<lines-valid` | n/a |
| `scripts/Check-CoverageScope.ps1` | The scope assertion (Seam 2 contract): the report measures exactly `WeatherPoC.Core` | n/a |
| `scripts/Test-CoverageGate.ps1` | Seam 1 boundary-crossing self-test: runs the gate against real Cobertura fixtures (proofs a/b/c) | n/a |
| `ci/coverage-fixtures/{green,below,empty}.cobertura.xml` | Real **ReportGenerator-merged** Cobertura payloads (the exact artefact the gate reads) for the self-test | n/a |
| `.github/workflows/ci.yml` | Build + test + coverage report + gate + scope assertion + self-test on `windows-latest` | n/a |

---

## Task 1: Solution spine — Core logging-config module + its on-disk round-trip test (Seam 4) (TDD)

**Seam 4 — Serilog logging → rolling on-disk file. Class: persistent-on-disk-state + host-OS/runtime (path semantics). Internal.**
**Contract (verbatim from spec §5 Seam 4):** Given a base directory `D`, the configured logger writes to `D/logs/weatherpoc-<yyyyMMdd>.log` (daily rolling interval, 7 files retained); a line written at `Information` level is present, verbatim, in that file after the logger is flushed/disposed. The base directory is a required, non-null parameter — `LoggingSetup` does not itself resolve `FileSystem.AppDataDirectory`.
**Proof (this Task):** an automated on-disk round-trip test — real I/O on the write side — calls `LoggingSetup` with a temp directory, logs a known line, flushes, reads the dated file back from disk, and asserts the line is present.

This is the fast, macOS-viable spine (`net10.0`, Serilog + `Serilog.Sinks.File` only — both cross-platform). It establishes red-green-commit on the real logging-config module before any MAUI machinery exists. `LoggingSetup` is the gated surface's coverable code, so **no throwaway canary is needed** (spec §4.3).

**Files:**
- Create: `WeatherPoC.sln`
- Create: `WeatherPoC.Core/WeatherPoC.Core.csproj`
- Create: `WeatherPoC.Core/LoggingSetup.cs`
- Create: `WeatherPoC.Tests/WeatherPoC.Tests.csproj`
- Test: `WeatherPoC.Tests/LoggingSetupTests.cs`

- [ ] **Step 1: Scaffold the solution and the two non-MAUI projects**

Run from the repo root (`WeatherPoC/`):

```bash
dotnet new sln -n WeatherPoC
dotnet new classlib -n WeatherPoC.Core -f net10.0 -o WeatherPoC.Core
dotnet new xunit -n WeatherPoC.Tests -f net10.0 -o WeatherPoC.Tests
dotnet sln add WeatherPoC.Core/WeatherPoC.Core.csproj WeatherPoC.Tests/WeatherPoC.Tests.csproj
dotnet add WeatherPoC.Tests/WeatherPoC.Tests.csproj reference WeatherPoC.Core/WeatherPoC.Core.csproj
rm WeatherPoC.Core/Class1.cs WeatherPoC.Tests/UnitTest1.cs
```

- [ ] **Step 2: Pin the Core project file**

Overwrite `WeatherPoC.Core/WeatherPoC.Core.csproj` with (Serilog + the file sink are plain .NET, so Core stays macOS-viable):

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Serilog" Version="4.2.0" />
    <PackageReference Include="Serilog.Sinks.File" Version="6.0.0" />
  </ItemGroup>

</Project>
```

- [ ] **Step 3: Pin the Tests project file (references Core only — never the app)**

Overwrite `WeatherPoC.Tests/WeatherPoC.Tests.csproj` with:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.12.0" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.0.2" />
    <PackageReference Include="Moq" Version="4.20.72" />
    <PackageReference Include="AwesomeAssertions" Version="9.1.0" />
    <PackageReference Include="coverlet.collector" Version="6.0.4" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\WeatherPoC.Core\WeatherPoC.Core.csproj" />
  </ItemGroup>

</Project>
```

> Moq is listed in the fixed testing stack and is pinned here so the scaffold matches `Technical-Context.MD`; it has no use in Feature 1 (no collaborators to fake yet) and earns its keep from Feature 2.

- [ ] **Step 4: Write the failing Seam 4 round-trip test**

Create `WeatherPoC.Tests/LoggingSetupTests.cs`:

```csharp
using AwesomeAssertions;
using Serilog;
using WeatherPoC.Core;
using Xunit;

namespace WeatherPoC.Tests;

public class LoggingSetupTests
{
    [Fact]
    public void Configured_logger_writes_the_line_to_a_dated_rolling_file_on_disk()
    {
        var baseDir = Path.Combine(Path.GetTempPath(), "weatherpoc-tests", Guid.NewGuid().ToString("N"));
        try
        {
            using (var logger = LoggingSetup.CreateConfiguration(baseDir).CreateLogger())
            {
                logger.Information("walking-skeleton startup line");
            } // dispose flushes the sink and releases the file handle

            var files = Directory.GetFiles(Path.Combine(baseDir, "logs"), "weatherpoc-*.log");
            files.Should().HaveCount(1);
            File.ReadAllText(files[0]).Should().Contain("walking-skeleton startup line");
        }
        finally
        {
            if (Directory.Exists(baseDir)) Directory.Delete(baseDir, recursive: true);
        }
    }
}
```

> This is real on-disk I/O (a temp directory), not network — P4 (unit tests never touch the network) holds. The `using` block disposes the logger so the file sink flushes and releases its handle before the assertion reads the file back.

> **Namespace note (confirm at first build):** `AwesomeAssertions` is a drop-in fork of FluentAssertions. The 9.x package exposes the `AwesomeAssertions` namespace used above. If your resolved version still ships the FluentAssertions-compatible namespace, the build will fail to find `Should()` — switch the using to `using FluentAssertions;`. Do not guess; let the first build tell you.

- [ ] **Step 5: Run the test to verify it fails**

Run: `dotnet test WeatherPoC.Tests/WeatherPoC.Tests.csproj`
Expected: **compile failure** — `WeatherPoC.Core.LoggingSetup` does not exist yet.

- [ ] **Step 6: Write the minimal `LoggingSetup`**

Create `WeatherPoC.Core/LoggingSetup.cs`:

```csharp
using Serilog;

namespace WeatherPoC.Core;

/// <summary>
/// Serilog rolling-file configuration for WeatherPoC, factored out of the app
/// shell so the on-disk write contract (Seam 4) is testable with real I/O. The
/// platform-bound per-user path (FileSystem.AppDataDirectory) is resolved by the
/// app head and passed in as <paramref name="baseDirectory"/>, keeping
/// WeatherPoC.Core free of MAUI/Windows dependencies (macOS-viable).
/// </summary>
public static class LoggingSetup
{
    /// <summary>
    /// Builds a Serilog configuration with a daily rolling file sink at
    /// <c>{baseDirectory}/logs/weatherpoc-.log</c> (Serilog inserts the date,
    /// yielding <c>weatherpoc-yyyyMMdd.log</c>), retaining 7 files, minimum
    /// level Information.
    /// </summary>
    public static LoggerConfiguration CreateConfiguration(string baseDirectory)
    {
        ArgumentNullException.ThrowIfNull(baseDirectory);

        var logPath = Path.Combine(baseDirectory, "logs", "weatherpoc-.log");

        return new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.File(
                path: logPath,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 7);
    }
}
```

> Every line executes on the test's happy path (the `ThrowIfNull` call returns normally), so `LoggingSetup` reaches 100% line coverage — the gated surface has real, fully-covered production code.

- [ ] **Step 7: Run the test to verify it passes**

Run: `dotnet test WeatherPoC.Tests/WeatherPoC.Tests.csproj`
Expected: **PASS** — 1 test passed.

- [ ] **Step 8: Commit**

```bash
git add WeatherPoC.sln WeatherPoC.Core WeatherPoC.Tests
git commit -m "feat: solution spine with Core LoggingSetup and on-disk round-trip test"
```

---

## Task 2: Coverage collection + runsettings

Make `dotnet test` emit a Cobertura report scoped to `WeatherPoC.Core`. This pins the *data format* that Seams 1 and 2 cross.

**Files:**
- Create: `coverage.runsettings`

- [ ] **Step 1: Create the coverlet runsettings**

Create `coverage.runsettings` at the repo root:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<RunSettings>
  <DataCollectionRunSettings>
    <DataCollectors>
      <DataCollector friendlyName="XPlat Code Coverage">
        <Configuration>
          <Format>cobertura</Format>
          <Include>[WeatherPoC.Core]*</Include>
          <ExcludeByAttribute>ExcludeFromCodeCoverageAttribute</ExcludeByAttribute>
        </Configuration>
      </DataCollector>
    </DataCollectors>
  </DataCollectionRunSettings>
</RunSettings>
```

- [ ] **Step 2: Run tests with coverage collection**

Run from the repo root:

```bash
dotnet test WeatherPoC.sln --collect:"XPlat Code Coverage" --settings coverage.runsettings --results-directory ./TestResults
```

Expected: PASS, and a file appears at `./TestResults/<guid>/coverage.cobertura.xml`.

- [ ] **Step 3: Verify the report shape and scope by hand**

Run: `cat ./TestResults/*/coverage.cobertura.xml`
Expected:
- The root `<coverage ...>` element carries `lines-covered` and `lines-valid` attributes, both **equal and greater than 0** (`LoggingSetup` is fully covered).
- The only `<package name="...">` is `WeatherPoC.Core`. (The app does not exist yet; this re-confirms once it does, in Task 5.)

- [ ] **Step 4: Ignore coverage output in git**

Append to `.gitignore` (create it if absent) at the repo root:

```gitignore
# Build + test output
bin/
obj/
TestResults/
CoverageReport/
```

> `ci/coverage-fixtures/*.cobertura.xml` are deliberately **committed** (Task 3) and are not under `TestResults/`, so this ignore rule does not touch them.

- [ ] **Step 5: Commit**

```bash
git add coverage.runsettings .gitignore
git commit -m "feat: coverlet runsettings scoping coverage to WeatherPoC.Core"
```

---

## Task 3: The coverage gate + its boundary-crossing self-test (Seam 1)

**Seam 1 — Coverage-gate contract (headline). Class: cross-process I/O + data-format (Cobertura XML file → gate script). Internal.**
**Contract (verbatim from spec §5 Seam 1):** After the test run and the ReportGenerator merge, a Cobertura report exists at the fixed path `CoverageReport/Cobertura.xml` whose root element carries `lines-covered` and `lines-valid` (non-negative integers; `lines-valid` absent or `0` denotes zero coverable lines) for the measured assembly `WeatherPoC.Core`. The gate **passes iff `lines-valid > 0 ∧ lines-covered == lines-valid`**; it fails otherwise (including the zero-coverable-lines case).
**Proof (this Task):** the self-test runs the *real* gate script against three fixtures **captured from ReportGenerator's merged output** — the exact producer the gate reads in CI, not raw coverlet and not hand-typed — and asserts: (a) fully-covered → exit 0 (green); (b) `covered < valid` → exit 1 ("coverage below 100%"); (c) `valid == 0` → exit 1 ("no coverable lines").

**Files:**
- Create: `scripts/Check-Coverage.ps1`
- Create: `scripts/Test-CoverageGate.ps1`
- Create: `ci/coverage-fixtures/green.cobertura.xml`
- Create: `ci/coverage-fixtures/below.cobertura.xml`
- Create: `ci/coverage-fixtures/empty.cobertura.xml`

- [ ] **Step 1: Write the gate script**

Create `scripts/Check-Coverage.ps1`:

```powershell
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
```

- [ ] **Step 2: Capture the three REAL Cobertura fixtures from ReportGenerator's merged output**

These payloads MUST come from the real producer **the gate actually reads** — ReportGenerator's merged `Cobertura.xml`, not raw coverlet and not hand-typed. Per the seam taxonomy, a self-written sample (or one captured from a *different* writer than the gate consumes) re-encodes the assumption it is meant to check; capturing from ReportGenerator makes the self-test cross the exact `coverlet → ReportGenerator → gate` boundary CI uses. Install ReportGenerator once locally if needed:

```bash
dotnet tool install --global dotnet-reportgenerator-globaltool --version 5.4.4
```

Generate each fixture by running coverage, merging with ReportGenerator, then copying `CoverageReport/Cobertura.xml` into `ci/coverage-fixtures/`:

1. **green** — `LoggingSetup` test present (the current state):
   ```bash
   dotnet test WeatherPoC.sln --collect:"XPlat Code Coverage" --settings coverage.runsettings --results-directory ./TestResults
   reportgenerator -reports:"./TestResults/**/coverage.cobertura.xml" -targetdir:./CoverageReport -reporttypes:"Cobertura"
   cp ./CoverageReport/Cobertura.xml ci/coverage-fixtures/green.cobertura.xml
   ```
   Confirm `green.cobertura.xml` has `lines-covered` == `lines-valid` and both > 0, and its only `<package name>` is `WeatherPoC.Core`.

2. **below** — covered < valid. Temporarily add an *uncovered* method to `LoggingSetup` so coverlet reports a real shortfall, run coverage + report, capture, then revert:
   ```bash
   # Temporarily append an untested method inside the LoggingSetup class body:
   #     public static string Unreached() => "not-covered";
   dotnet test WeatherPoC.sln --collect:"XPlat Code Coverage" --settings coverage.runsettings --results-directory ./TestResults
   reportgenerator -reports:"./TestResults/**/coverage.cobertura.xml" -targetdir:./CoverageReport -reporttypes:"Cobertura"
   cp ./CoverageReport/Cobertura.xml ci/coverage-fixtures/below.cobertura.xml
   # Revert: remove Unreached() so the working tree is green again.
   ```
   Confirm `below.cobertura.xml` has `lines-covered` < `lines-valid`.

3. **empty** — valid == 0. Temporarily reduce `WeatherPoC.Core` to zero coverable lines (replace `LoggingSetup.cs` with an empty marker type) **and** comment out `LoggingSetupTests` (it references `LoggingSetup`, so it must not compile against the stub), run coverage + report, capture, then revert both:
   ```bash
   # Temporarily: LoggingSetup.cs -> an empty type (no coverable lines); comment out LoggingSetupTests.
   dotnet test WeatherPoC.sln --collect:"XPlat Code Coverage" --settings coverage.runsettings --results-directory ./TestResults
   reportgenerator -reports:"./TestResults/**/coverage.cobertura.xml" -targetdir:./CoverageReport -reporttypes:"Cobertura"
   cp ./CoverageReport/Cobertura.xml ci/coverage-fixtures/empty.cobertura.xml
   # Revert: restore LoggingSetup.cs and LoggingSetupTests so the working tree is green again.
   ```
   Confirm `empty.cobertura.xml` has `lines-valid` == 0 (the root attribute is `0` or absent).

After capturing all three, run `dotnet test WeatherPoC.sln` once more to confirm the working tree is back to green (`LoggingSetup` present and its test passing).

- [ ] **Step 3: Write the self-test runner**

Create `scripts/Test-CoverageGate.ps1`:

```powershell
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
```

- [ ] **Step 4: Run the self-test to verify the gate behaves per the contract**

Run: `pwsh -File scripts/Test-CoverageGate.ps1`
Expected output includes three `SELFTEST PASS` lines and `Coverage-gate self-test passed (Seam 1 proofs a, b, c).`, exit code 0.

> If `pwsh` is not installed locally, install PowerShell 7 (it is preinstalled on the `windows-latest` GitHub runner). This is tooling, not a .NET test framework — it introduces no change to the xUnit testing stack.

- [ ] **Step 5: Commit**

```bash
git add scripts/Check-Coverage.ps1 scripts/Test-CoverageGate.ps1 ci/coverage-fixtures
git commit -m "feat: coverage threshold gate with Seam 1 boundary-crossing self-test"
```

---

## Task 4: The MAUI app head — empty box, DI, MVVM scaffold, Serilog bootstrap (Seam 3 build + composition)

**Seam 3 — App build + host composition + launch. Class: subprocess (`dotnet build -c Release`) + host-OS/runtime (Windows MAUI head). External — the .NET 10 SDK + MAUI workload toolchain.**
**Contract (verbatim from spec §5 Seam 3):** The solution compiles on CI for the Windows head `net10.0-windows10.0.19041.0` (minimum OS `10.0.17763.0`); the host builds without DI resolution exceptions; the app process starts and renders `MainPage`. *(The Serilog write to the rolling file is Seam 4 / Task 1; this seam covers build + composition + launch only.)*
**(e) authority:** the .NET 10 / MAUI Windows target is grounded against the live Microsoft source per the "Seam 3 toolchain authority" note near the top of this Plan (the *Supported platforms* doc + the *dotnet/maui Release-Versions* wiki), with the CI-resolved toolchain (`actions/setup-dotnet@v4` `10.0.x` + `dotnet workload install maui` + `dotnet restore`) as the binding check — not model memory.
**Proof:** CI build step green (compilation against the real external toolchain — automated, wired in Task 5); launch-to-empty-box + DI-resolves-`ILogger<MainPage>` verified manually (Task 6). The on-disk write is proven automatically by Seam 4 (Task 1). Automated UI-launch testing is out of scope (spec §3).

All types in this Task carry `[ExcludeFromCodeCoverage]` (belt-and-braces with the `Include` filter from Task 2 and the test project not referencing the app — spec §4.2, Seam 2).

**Files:**
- Create: `WeatherPoC/WeatherPoC.csproj` (scaffolded, then trimmed)
- Create/Modify: `WeatherPoC/MauiProgram.cs`
- Create/Modify: `WeatherPoC/App.xaml.cs`
- Create/Modify: `WeatherPoC/MainPage.xaml`
- Create/Modify: `WeatherPoC/MainPage.xaml.cs`

- [ ] **Step 1: Install the MAUI workload and scaffold the app project**

Run from the repo root:

```bash
dotnet workload install maui
dotnet new maui -n WeatherPoC -o WeatherPoC
dotnet sln add WeatherPoC/WeatherPoC.csproj
dotnet add WeatherPoC/WeatherPoC.csproj reference WeatherPoC.Core/WeatherPoC.Core.csproj
```

> The template generates `Platforms/`, `Resources/`, and the multi-head `App`/`MainPage`. Keep the template's `Platforms/Windows/*` and `Resources/*` as-is; only the files below are hand-authored.

- [ ] **Step 2: Trim the project to a single Windows TFM and pin packages**

In `WeatherPoC/WeatherPoC.csproj`, replace the template's `<TargetFrameworks>` line (the multi-head `net10.0-android;net10.0-ios;...` list) with a single Windows TFM, and ensure the package set below is present. The result must contain:

```xml
  <PropertyGroup>
    <TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>
    <OutputType>Exe</OutputType>
    <UseMaui>true</UseMaui>
    <SingleProject>true</SingleProject>
    <RootNamespace>WeatherPoC</RootNamespace>
    <ApplicationTitle>WeatherPoC</ApplicationTitle>
    <ApplicationId>net.enate.weatherpoc</ApplicationId>
    <ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>
    <ApplicationVersion>1</ApplicationVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TargetPlatformMinVersion>10.0.17763.0</TargetPlatformMinVersion>
    <WindowsPackageType>None</WindowsPackageType>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.4.0" />
    <PackageReference Include="Serilog" Version="4.2.0" />
    <PackageReference Include="Serilog.Extensions.Logging" Version="9.0.0" />
    <PackageReference Include="Serilog.Sinks.Debug" Version="3.0.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\WeatherPoC.Core\WeatherPoC.Core.csproj" />
  </ItemGroup>
```

> `WindowsPackageType=None` builds an unpackaged Win32 app so it launches with `dotnet run` (Task 6) without MSIX packaging — release/installer mechanics stay deferred (spec §3, R2). `CommunityToolkit.Mvvm` is the MVVM scaffold the spec mandates (§4.2); it carries no behaviour yet and is used in earnest from Feature 2. `CommunityToolkit.Maui` is **not** added here — YAGNI for the empty box (no behaviors/converters/popups in scope). `Serilog.Sinks.File` is **not** referenced here either — the rolling-file configuration lives in `WeatherPoC.Core`'s `LoggingSetup` (Seam 4) and reaches the app transitively via the Core reference; the app head adds only the `DEBUG`-only Debug sink.

- [ ] **Step 3: Write the DI composition root + Serilog bootstrap**

Overwrite `WeatherPoC/MauiProgram.cs`:

```csharp
using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.Logging;
using Serilog;
using Serilog.Extensions.Logging;
using WeatherPoC.Core;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "DI composition root + Serilog bootstrap: untestable wiring, coverage-excluded per Overriding Principle 5.")]
public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        // The rolling-file configuration (path + sink) is the testable Seam 4 contract in
        // WeatherPoC.Core; the app head passes the platform-bound per-user path into it.
        var loggerConfiguration = LoggingSetup.CreateConfiguration(FileSystem.AppDataDirectory);

#if DEBUG
        loggerConfiguration = loggerConfiguration.WriteTo.Debug();
#endif

        Log.Logger = loggerConfiguration.CreateLogger();

        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        builder.Logging.ClearProviders();
        builder.Logging.AddSerilog(Log.Logger, dispose: true);

        builder.Services.AddSingleton<MainPage>();

        return builder.Build();
    }
}
```

> The rolling file sits under `FileSystem.AppDataDirectory` (per-user app-data) — the path and file sink are configured by `LoggingSetup` in Core (Seam 4); the app head only supplies the base directory and adds the `DEBUG`-only Debug sink. Local-only telemetry, no data leaves the machine (PRD stories 38–39; Technical-Context Instrumentation).

- [ ] **Step 4: Write the application bootstrap**

Overwrite `WeatherPoC/App.xaml.cs` (keep the template's `App.xaml` as-is):

```csharp
using System.Diagnostics.CodeAnalysis;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "Application bootstrap: untestable wiring, coverage-excluded per Overriding Principle 5.")]
public partial class App : Application
{
    private readonly MainPage _mainPage;

    public App(MainPage mainPage)
    {
        InitializeComponent();
        _mainPage = mainPage;
    }

    protected override Window CreateWindow(IActivationState? activationState)
        => new Window(_mainPage);
}
```

- [ ] **Step 5: Write the empty box View and its startup log line**

Overwrite `WeatherPoC/MainPage.xaml`:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="WeatherPoC.MainPage">
    <Grid />
</ContentPage>
```

Overwrite `WeatherPoC/MainPage.xaml.cs`:

```csharp
using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.Logging;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "XAML View code-behind: untestable UI, coverage-excluded per Overriding Principle 5.")]
public partial class MainPage : ContentPage
{
    public MainPage(ILogger<MainPage> logger)
    {
        InitializeComponent();
        logger.LogInformation("WeatherPoC started: walking skeleton MainPage composed and rendered.");
    }
}
```

> This single startup line, written through the **injected** `ILogger<MainPage>`, exercises the Seam 3 composition — the logging provider resolves and the injected logger flows to Serilog — verified manually in Task 6. The on-disk *write* contract itself is proven automatically by Seam 4 (Task 1), independent of the UI.

- [ ] **Step 6: Build the whole solution in Release (the automated half of Seam 3)**

Run from the repo root:

```bash
dotnet build WeatherPoC.sln -c Release
```

Expected: **Build succeeded** for all three projects — the app compiles for the Windows head (Goal 1). Must be run on Windows with the MAUI workload installed.

- [ ] **Step 7: Re-run coverage and confirm the scope is unchanged (Seam 2 belt-and-braces)**

Run from the repo root:

```bash
dotnet test WeatherPoC.sln --collect:"XPlat Code Coverage" --settings coverage.runsettings --results-directory ./TestResults
cat ./TestResults/*/coverage.cobertura.xml
```

Expected: the report still lists **only** `WeatherPoC.Core` (now containing `LoggingSetup`, fully covered). The newly-added app shell (full of uncovered lines) contributes nothing — proving the `[ExcludeFromCodeCoverage]` + `Include` filter + test-project-doesn't-reference-app combination holds.

- [ ] **Step 8: Commit**

```bash
git add WeatherPoC/
git commit -m "feat: MAUI app head with DI, MVVM scaffold, Serilog, and empty box"
```

---

## Task 5: CI pipeline — build, test, coverage report, gate, scope assertion (Seams 1, 2, 3 in CI)

**Seam 2 — Coverage-scope boundary. Class: cross-process I/O (runsettings filter shapes the Cobertura payload) + data-format. Internal.**
**Contract (verbatim from spec §5 Seam 2):** Coverage measures **exactly** the `WeatherPoC.Core` assembly. The XAML View, DI composition root, Serilog bootstrap, and the test assembly contribute **zero** coverable lines to the gate.
**Proof:** `Check-CoverageScope.ps1` parses the *real* produced Cobertura report and asserts the only measured package is `WeatherPoC.Core`; CI fails otherwise. (The app shell's uncovered lines not reddening the gate is demonstrated by the green run itself — the shell is full of untested lines.)

**Files:**
- Create: `scripts/Check-CoverageScope.ps1`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the scope-assertion script (Seam 2 proof)**

Create `scripts/Check-CoverageScope.ps1`:

```powershell
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

[xml]$report = Get-Content -LiteralPath $CoberturaPath -Raw
$packages    = @($report.coverage.packages.package.name) | Sort-Object -Unique

Write-Host "Measured assemblies: $($packages -join ', ')"

$expected   = @('WeatherPoC.Core')
$unexpected = $packages | Where-Object { $_ -notin $expected }

if ($unexpected) {
    Write-Host "FAIL: coverage measured assemblies outside WeatherPoC.Core: $($unexpected -join ', ')"
    exit 1
}

if ($packages -notcontains 'WeatherPoC.Core') {
    Write-Host "FAIL: WeatherPoC.Core not present in coverage report"
    exit 1
}

Write-Host "PASS: coverage scoped to WeatherPoC.Core only"
exit 0
```

- [ ] **Step 2: Verify the scope script locally against the green fixture**

Run: `pwsh -File scripts/Check-CoverageScope.ps1 -CoberturaPath ci/coverage-fixtures/green.cobertura.xml`
Expected: `PASS: coverage scoped to WeatherPoC.Core only`, exit 0.

- [ ] **Step 3: Write the CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [ main ]
  push:
    branches:
      - 'claude/**'
      - 'feature/**'

jobs:
  build-test-coverage:
    runs-on: windows-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET 10 SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Install MAUI workload
        run: dotnet workload install maui

      - name: Restore
        run: dotnet restore WeatherPoC.sln

      - name: Build (Release) — proves the app compiles (Goal 1, Seam 3)
        run: dotnet build WeatherPoC.sln -c Release --no-restore

      - name: Test with coverage
        run: >
          dotnet test WeatherPoC.sln -c Release --no-build
          --collect:"XPlat Code Coverage"
          --settings coverage.runsettings
          --results-directory ${{ github.workspace }}/TestResults

      - name: Install ReportGenerator
        run: dotnet tool install --global dotnet-reportgenerator-globaltool --version 5.4.4

      - name: Generate coverage report
        run: >
          reportgenerator
          -reports:"${{ github.workspace }}/TestResults/**/coverage.cobertura.xml"
          -targetdir:"${{ github.workspace }}/CoverageReport"
          -reporttypes:"Html;Cobertura"

      - name: Upload coverage report artifact
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: ${{ github.workspace }}/CoverageReport

      - name: Coverage scope assertion (Seam 2)
        shell: pwsh
        run: ./scripts/Check-CoverageScope.ps1 -CoberturaPath ${{ github.workspace }}/CoverageReport/Cobertura.xml

      - name: Coverage threshold gate (Seam 1)
        shell: pwsh
        run: ./scripts/Check-Coverage.ps1 -CoberturaPath ${{ github.workspace }}/CoverageReport/Cobertura.xml

      - name: Coverage-gate self-test (Seam 1 proofs a/b/c)
        shell: pwsh
        run: ./scripts/Test-CoverageGate.ps1
```

> ReportGenerator's merged `Cobertura.xml` carries the same root `lines-covered`/`lines-valid` attributes and `<package>` entries the gate and scope scripts read. The gate runs against this deterministic path rather than the globbed raw coverlet output. This coverlet → ReportGenerator schema-equivalence is **not merely asserted**: the Seam 1 self-test fixtures (Task 3 Step 2) are captured from this same ReportGenerator output, so the gate's behaviour against the exact artefact it reads in CI is proven by the self-test, not assumed in prose.

- [ ] **Step 4: Guard the dependency direction (acceptance criterion 1)**

Confirm the test project does **not** reference the app project (the mechanism behind Seam 2). Run:

```bash
grep -i "WeatherPoC\\\\WeatherPoC.csproj\|WeatherPoC/WeatherPoC.csproj" WeatherPoC.Tests/WeatherPoC.Tests.csproj || echo "OK: Tests does not reference the app project"
```

Expected: `OK: Tests does not reference the app project`.

- [ ] **Step 5: Commit**

```bash
git add scripts/Check-CoverageScope.ps1 .github/workflows/ci.yml
git commit -m "ci: build + test + coverage gate, scope assertion, and gate self-test"
```

- [ ] **Step 6: Push and open the PR; confirm CI is green**

Push the working branch and open a PR targeting `main`. On the PR, confirm:
- the **Build (Release)** step is green (Seam 3 compilation proof, Goal 1);
- the **coverage-report** artifact is published (Goal 4 / acceptance 4);
- the **scope assertion** is green (Seam 2 / acceptance 6);
- the **threshold gate** is green with `LoggingSetup` fully covered (Seam 1 proof a / acceptance 5);
- the **self-test** is green, reproducing proofs a/b/c deterministically (Seam 1 b & c / acceptance 5).

---

## Task 6: Manual launch verification (Seam 3 launch proof)

Automated UI-launch testing is out of scope (spec §3); the launch-to-empty-box and DI-resolution halves of Seam 3 are verified **manually** on Windows and evidenced on the PR. *(The Serilog on-disk write contract is already proven automatically by Seam 4 / Task 1; the manual run below additionally confirms it end-to-end at the real per-user path as a host-level sanity check, but is not the primary proof of the write.)*

**Files:** none (verification + evidence only).

- [ ] **Step 1: Launch the app on Windows**

Run from the repo root on a Windows machine with the MAUI workload installed:

```bash
dotnet run --project WeatherPoC/WeatherPoC.csproj -f net10.0-windows10.0.19041.0
```

Expected: a single window opens showing an **empty box** (no controls, no content). Capture a screenshot.

- [ ] **Step 2: Confirm the startup log line was written to the per-user rolling file**

The log lives under `FileSystem.AppDataDirectory/logs/weatherpoc-<date>.log`. For the unpackaged build this resolves under the per-user local app-data folder. Locate today's file and confirm it contains the startup line:

```
WeatherPoC started: walking skeleton MainPage composed and rendered.
```

If the folder is unclear, the path is logged at startup under the Debug sink in a `DEBUG` build (run from an IDE / `-c Debug`). Capture the relevant log lines. This end-to-end check complements (does not replace) the automated Seam 4 round-trip test, which proves the write contract deterministically in CI.

- [ ] **Step 3: Attach the evidence to the PR**

Post the screenshot of the empty box and the log-file snippet (showing the startup line) to the PR as the manual verification record for Seam 3 / acceptance criterion 3. No code change; no commit.

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Covered by |
|---|---|
| §4.1 three projects, stated TFMs, reference directions; Tests ⇏ app | Task 1 (Core/Tests), Task 4 (app), Task 5 Step 4 guard |
| §4.2 DI root + MVVM scaffold + Serilog bootstrap, all coverage-excluded | Task 4 Steps 3–5 (`[ExcludeFromCodeCoverage]` on every shell type) |
| §4.2 startup line via injected `ILogger` (Seam 3 composition, manual) | Task 4 Step 5; Task 6 Step 2 |
| §4.3 `LoggingSetup` logging-config module + 100% on-disk round-trip test (no canary) | Task 1 Steps 4–7 |
| §4.4 CI: checkout→setup→workload→restore→build→test→ReportGenerator→gate | Task 5 Step 3 |
| §4.4 gate fails on `lines-valid==0` and `lines-covered<lines-valid` | Task 3 Step 1 (script), Task 3 Steps 2–4 (self-test against ReportGenerator-merged fixtures) |
| §4.4 runsettings: cobertura, `Include [WeatherPoC.Core]*`, `ExcludeByAttribute` | Task 2 Step 1 |
| Goals 1–5 | G1: Task 4 Step 6 / Task 6; G2: Task 4 Steps 3–5 + Task 1 (Seam 4 write proof); G3: Task 1 / Task 5; G4: Task 3 + Task 5; G5: Task 5 Steps 1–3 |
| Acceptance 1–8 | 1: T1/T4/T5.4; 2: T5.6; 3: T6 (launch + DI); 4: T1/T5.6 (`LoggingSetup` test green); 5: T3/T5.6; 6: T5.2/T5.6; 7: T1 Step 2 (`net10.0`, Serilog cross-platform only); 8: T1 (Seam 4 round-trip) |
| Out-of-scope respected | No `IWeatherService`, no domain types, no behavioural VMs, no Location, no signing/packaging (`WindowsPackageType=None`, build+test+coverage only), Windows-only TFM |

**2. Placeholder scan** — no `TBD`/`TODO`/"add appropriate…"; every code and script step is complete; package versions are concrete pins with a single confirm-at-restore note (spec §9 defers exact versions by design); the one genuine external-fact uncertainty (AwesomeAssertions namespace) is called out with the exact fallback rather than guessed; the .NET 10 / MAUI Windows toolchain facts are grounded against cited Microsoft Learn sources (Seam 3 (e)), not memory.

**3. Type consistency** — `LoggingSetup` / `CreateConfiguration(baseDirectory)` used identically in Task 1 Steps 4 & 6, in `MauiProgram` (Task 4 Step 3), the File Structure table, and spec §4.3 / Seam 4. `MainPage`, `App`, `MauiProgram`, `ILogger<MainPage>`, `CreateMauiApp`, `CreateWindow` consistent across Task 4. Script names (`Check-Coverage.ps1`, `Check-CoverageScope.ps1`, `Test-CoverageGate.ps1`) and fixture names (`green/below/empty.cobertura.xml`) match between Tasks 3 and 5 and the CI workflow. No `SkeletonMarker`/canary references remain.

**4. Seam coverage**

| Seam (spec §5) | Covering Task naming the contract | Boundary-crossing proof (step) |
|---|---|---|
| **Seam 1** — coverage-gate contract | Task 3 (contract quoted verbatim) | Task 3 Steps 2–4: `Test-CoverageGate.ps1` runs the real gate against **ReportGenerator-merged** fixtures (the exact artefact CI reads) — proofs a/b/c; wired into CI in Task 5 Step 3 |
| **Seam 2** — coverage-scope boundary | Task 5 (contract quoted verbatim) | Task 5 Steps 1–2: `Check-CoverageScope.ps1` parses the real produced report, asserts only `WeatherPoC.Core`; reinforced by Task 4 Step 7 |
| **Seam 3** — app build + composition + launch (external toolchain, (e) grounded) | Task 4 (contract + (e) authority quoted) | Automated: CI `Build (Release)` green against the real SDK/workload (Task 5). Manual (per spec §3): empty-box + DI-resolves-`ILogger<MainPage>` (Task 6) |
| **Seam 4** — Serilog logging → rolling on-disk file | Task 1 (contract quoted verbatim) | Task 1 Steps 4–7: automated on-disk round-trip test — real disk I/O against a temp dir, asserts the dated file contains the line |

Every seam maps to a Task that quotes its contract and a step that writes its proof. No gaps.

**5. Fix-pass closure map** *(answers the failed `/feature-doc-gauntlet` run recorded in the Spec sign-off, 2026-06-16; all four findings were raised by `check-seam-cynicism`)*

| Finding | Root cause | Fix (decision) | Closure evidence |
|---|---|---|---|
| 1. Coverage-gate proof crosses the wrong boundary | Fixtures captured from raw coverlet, but the gate reads ReportGenerator's merged report | Capture fixtures from ReportGenerator's merged output (RC1) | Task 3 Step 2 + Spec §4.4 / Seam 1: fixtures = `CoverageReport/Cobertura.xml`; no "raw coverlet" fixture remains |
| 2. Seam 3 external but no (e) authority | Toolchain grounded on model memory | Added (e) authority citing MS Learn *Supported platforms* + *dotnet/maui Release-Versions* + the CI-resolved toolchain | Spec §5 Seam 3 (e); Plan "Seam 3 toolchain authority" note + Task 4 contract block |
| 3. Missing Serilog on-disk seam | Seam 3 overloaded; no inventory row for the on-disk write | Split out a new **Seam 4** (logging → on-disk file) with a falsifiable (c) | Spec §5 Seam 4; Plan Task 1 names it verbatim |
| 4. Logger-writes contract has no real (d) | Manual-only proof of an automatable, non-UI write | Automated on-disk round-trip test in `LoggingSetup` + `LoggingSetupTests` (RC3) | Plan Task 1 Steps 4–7; Spec §4.3, acceptance 8 |
| obs. Orphaned seam-taxonomy path | Sibling-repo path unresolvable from the project root | Annotated reference-only / sibling repo | Plan Context references block |

All four findings closed and the on-path observation swept; the Spec and Plan were edited jointly. Ready for a **full** `/feature-doc-gauntlet` re-run (all three leaves, fresh).
