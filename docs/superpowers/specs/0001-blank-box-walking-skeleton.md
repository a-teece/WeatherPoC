# Spec — Feature 1: Blank-box walking skeleton 🔫

**Feature:** 1 (Roadmap.md) — *tracer bullet*
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Depends on:** None — this is the tracer bullet.
**Downstream:** Feature 2 (Live Current Conditions) rides on the shell, DI/MVVM scaffold, Serilog wiring, and the build + test + coverage pipeline this Feature lands.

---

## 1. Intent

Stand up a native Windows .NET MAUI app that launches to an **empty box**, backed by a
unit-test project and a CI pipeline that builds the app, runs the tests, and enforces the
100%-unit-test-coverage gate (Overriding Principle 5). There is **no domain logic** yet.

The job of this Feature is to prove the *mechanism* end-to-end, not to ship product
behaviour. The scariest greenfield unknowns are "does a .NET MAUI app on .NET 10 build and
run on Windows at all" and "can we stand up a deterministic pipeline that gates on 100%
coverage" — not the well-trodden weather call. Nailing the build/test/coverage spine here
de-risks every Feature that rides on top of it.

A deliberate consequence of "no domain logic" is that the coverage gate could **pass
vacuously** (100% of nothing) if `WeatherPoC.Core` held no production code. This Feature avoids
that not with throwaway scaffolding but with the **one piece of real, testable production code
the skeleton genuinely needs**: the Serilog logging-configuration module (`LoggingSetup`, §4.3),
whose on-disk write contract is Seam 4. It gives the gate real teeth on real code, and the gate's
ability to *fail* a build — an explicit goal — is proven independently by the threshold self-test
against captured coverage fixtures (§5, Seam 1).

## 2. Goals — what "done" proves

1. The MAUI app **compiles** for the Windows head in CI and **launches to an empty box** locally.
2. The **DI composition root, MVVM scaffold, and Serilog bootstrap** are wired and exercised at
   startup (a startup line is written to the local rolling log file); the logging-config's on-disk
   write is proven by an automated round-trip test (§5, Seam 4).
3. The **test project** builds and runs under xUnit in CI.
4. The pipeline **produces a coverage report** and the gate **can fail the build** — proven by the
   threshold self-test: the gate is green on a fully-covered coverage fixture and red on a
   below-100% fixture and on a zero-coverable-lines fixture (§5, Seam 1).
5. The coverage gate measures **exactly the testable production surface** (`WeatherPoC.Core`) and
   **excludes** the XAML View, DI composition root, and Serilog bootstrap (§5, Seam 2).

## 3. Non-goals / out of scope

Per Roadmap Feature 1 and the PRD:

- **Any weather data, any Location, any domain logic** — including the Active Location resolver
  (deferred to Feature 5, where there is something to resolve). No `IWeatherService`, no domain
  types, no ViewModels with behaviour, no navigation beyond the single blank page.
- **Inline loading / empty / error UI states** (PRD stories 33–37) — they need real data; Feature 2+.
- **Release signing and installer packaging** — only build + test + coverage is pulled in here
  (Roadmap F1). Release mechanics stay deferred (consistent with PRD "Out of Scope").
- **Multi-platform heads beyond Windows** — Windows-only single TFM for now; the architecture
  stays macOS-viable (Core is plain `net10.0`, no Windows-only APIs without abstraction), honouring
  PRD story 41.
- **Automated UI-launch / end-to-end testing** — launch-to-empty-box is verified manually for this
  Feature (§5, Seam 3); the end-to-end suite arrives with real behaviour.

## 4. Design

### 4.1 Solution structure

One solution, `WeatherPoC.sln`, three projects:

| Project | TFM | Role | Coverage |
|---|---|---|---|
| `WeatherPoC` | `net10.0-windows10.0.19041.0` | MAUI app head — the empty box, DI composition root, MVVM, Serilog bootstrap | **Excluded** (`[ExcludeFromCodeCoverage]` + not referenced by the test project) |
| `WeatherPoC.Core` | `net10.0` | The 100%-gated production surface. No domain logic yet; holds the Serilog logging-configuration module `LoggingSetup` (§4.3) — plain, cross-platform, no MAUI/Windows deps | **Included — the gated surface** |
| `WeatherPoC.Tests` | `net10.0` | xUnit + Moq + AwesomeAssertions + coverlet.collector | Not measured |

**Dependency direction (set now, even though minimal):** `WeatherPoC` → `WeatherPoC.Core`;
`WeatherPoC.Tests` → `WeatherPoC.Core`. The test project **does not** reference the app project —
this is one of the mechanisms that keeps the UI/wiring out of the coverage measurement (§5, Seam 2).
`WeatherPoC.Core` is plain `net10.0` (no platform dependencies — it references only Serilog and
`Serilog.Sinks.File`, both cross-platform), so it is the fast-to-test, macOS-viable spine. The
platform-bound per-user path lookup (`FileSystem.AppDataDirectory`) stays in the app shell and is
passed into Core as a parameter (§4.2/§4.3), so no MAUI/Windows API leaks into the gated surface.

### 4.2 App shell + scaffold (coverage-excluded)

All of the following live in the `WeatherPoC` app project and are coverage-excluded as untestable
UI/wiring (Overriding Principle 5; PRD Testing Decisions "Excluded from unit tests"):

- **`MauiProgram.CreateMauiApp()`** — builds the `MauiAppBuilder` DI container, registers
  CommunityToolkit.Mvvm and a single `MainPage`, and registers Serilog as the logging provider.
- **`MainPage` (XAML View)** — the empty box. No bound behaviour, no ViewModel logic.
- **Serilog bootstrap** — the rolling-file-sink configuration is built by `LoggingSetup` in
  `WeatherPoC.Core` (§4.3), which takes the **base directory as a parameter**; `MauiProgram` passes
  `FileSystem.AppDataDirectory` (the per-user app-data folder), and a Debug sink is added app-side
  under `DEBUG` (Technical-Context Instrumentation; PRD Logging and privacy). The platform-bound
  path lookup stays in the excluded shell while the testable rolling-file configuration lives in
  Core (Seam 4). One startup line is emitted via the injected `ILogger` to prove the logging
  provider resolves and writes. **No telemetry leaves the machine** (PRD stories 38–39).

Exclusion is belt-and-braces: `[ExcludeFromCodeCoverage]` on the shell types **and** the test project
not referencing the app **and** the runsettings include-filter scoping measurement to Core (§4.4).

### 4.3 Core + the logging-configuration module (`LoggingSetup`)

`WeatherPoC.Core` contains **one real, testable module** — `LoggingSetup`, the Serilog
rolling-file-sink configuration factored out of the app shell so it can be exercised with real I/O.
It exposes a method that takes a **base directory** and returns a Serilog `LoggerConfiguration`
configured with a rolling file sink at `<baseDirectory>/logs/weatherpoc-.log` (daily roll, 7 files
retained). `WeatherPoC.Tests` covers it **100%** with an on-disk round-trip test (Seam 4): it builds
a logger against a temporary directory, writes a line, flushes, and asserts the dated file on disk
contains that line.

`LoggingSetup` is the real coverable production code that gives the coverage gate teeth in the merged
artefact — so **no throwaway canary is introduced**. (The earlier draft of this Spec planned a
disposable `SkeletonMarker` canary to avoid a vacuous 100%-of-nothing pass and have Feature 2 delete
it once "the first real module lands"; that real module now lands here, in Feature 1, as
`LoggingSetup` — so the canary's only rationale is already satisfied and it is dropped.)

### 4.4 The coverage gate (CI)

A GitHub Actions workflow at `.github/workflows/ci.yml`, on `windows-latest`, triggered on pull
requests targeting `main` and on pushes to the working branch. Steps:

1. Checkout.
2. Setup .NET 10 SDK (`actions/setup-dotnet`).
3. `dotnet workload install maui` (required to build the Windows MAUI head).
4. `dotnet restore`.
5. **`dotnet build -c Release`** over the whole solution — proves the app *compiles* (Goal 1).
6. **`dotnet test`** with `--collect:"XPlat Code Coverage" --settings coverage.runsettings`
   (coverlet.collector → Cobertura XML).
7. **ReportGenerator** (dotnet tool) renders an HTML report + a Cobertura summary, uploaded as a
   build artifact — satisfying "the pipeline produces a coverage report".
8. **Threshold gate step** (PowerShell) reads `lines-covered` / `lines-valid` from the Cobertura
   report and **fails the build** on either condition:
   - `lines-valid == 0` → fail: *"no coverable lines — the gate cannot be vacuously satisfied"*
     (the explicit guard against the vacuous-pass trap), **or**
   - `lines-covered < lines-valid` → fail: *"coverage below 100%"*.

`coverage.runsettings` configures the coverlet collector to emit `cobertura` format, **Include**
`[WeatherPoC.Core]*`, and **ExcludeByAttribute** `ExcludeFromCodeCoverageAttribute`. This scopes
measurement to exactly the gated surface.

The threshold gate and the scope assertion both read **ReportGenerator's merged `Cobertura.xml`**
(step 7's output), not the raw per-run coverlet file. So the boundary the gate crosses is
*coverlet → ReportGenerator → gate script*. The Seam 1 self-test fixtures are therefore captured
**from ReportGenerator's merged output** — the exact artefact the gate reads — so the self-test
proves the real production boundary rather than a coverlet-shaped stand-in for it (§5, Seam 1).

> **Branch protection** (making this check *required* on `main`, the mechanical enforcement of the
> Technical-Context guardrail "No merge to `main` without deterministic checks") is a repo-admin
> action, not code — flagged here as a follow-up for the repo owner, outside this Feature's diff.

## 5. Seam inventory

The cross-module contracts this Feature relies on. Each carries a falsifiable contract and a real
proof — this is the payload of the tracer bullet.

### Seam 1 — Coverage-gate contract *(headline)*

- **Class:** cross-process I/O + data-format (Cobertura XML file → gate script), internal.
- **Boundary:** `dotnet test` (coverlet.collector) → **ReportGenerator merged `Cobertura.xml`** → threshold gate step → CI pass/fail.
- **Contract:** After the test run and the ReportGenerator merge, a Cobertura report exists at the
  fixed path `CoverageReport/Cobertura.xml` whose root element carries `lines-covered` and
  `lines-valid` (non-negative integers; `lines-valid` absent or `0` denotes zero coverable lines) for
  the measured assembly `WeatherPoC.Core`. The gate **passes iff `lines-valid > 0 ∧ lines-covered == lines-valid`**;
  it fails otherwise (including the zero-coverable-lines case).
- **Proof (falsifiable, demonstrable in CI):** a self-test runs the *real* gate script against three
  fixtures **captured from ReportGenerator's merged output** — the exact producer the gate reads in
  CI, not raw coverlet and not hand-typed:
  - (a) fully-covered fixture (the `LoggingSetup` test green) → `covered == valid > 0` → **green**.
  - (b) below-100% fixture (an uncovered method present in Core) → `covered < valid` → **red** ("coverage below 100%").
  - (c) zero-coverable-lines fixture (empty Core) → `valid == 0`/absent → **red** ("no coverable lines").

### Seam 2 — Coverage-scope boundary

- **Boundary:** runsettings include-filter `[WeatherPoC.Core]*` + `[ExcludeFromCodeCoverage]` on the
  app shell + the test project not referencing the app.
- **Contract:** Coverage measures **exactly** the `WeatherPoC.Core` assembly. The XAML View, DI
  composition root, Serilog bootstrap, and the test assembly contribute **zero** coverable lines to
  the gate.
- **Proof:** The Cobertura report lists only `WeatherPoC.Core`. An uncovered line added to the app
  shell does **not** turn the gate red (proving exclusion); an uncovered line added to Core **does**
  (proving inclusion).

### Seam 3 — App build + host composition + launch

- **Class:** subprocess (`dotnet build -c Release`) + host-OS/runtime (the Windows MAUI head).
  **External** — the .NET 10 SDK + MAUI workload toolchain is third-party and not under our control.
- **Boundary:** `dotnet build -c Release` over the solution on the Windows runner (with the maui
  workload); the DI composition root resolves `MainPage` + `ILogger`; the app launches to the empty
  box and renders `MainPage`.
- **Contract:** The solution compiles on CI for the Windows head `net10.0-windows10.0.19041.0`
  (minimum OS `10.0.17763.0`); the host builds without DI resolution exceptions; the app process
  starts and renders `MainPage`. *(The Serilog write to the rolling file is **Seam 4**; this seam
  covers build + composition + launch only.)*
- **(e) authority:** grounded against the live Microsoft source, not model memory — *Supported
  platforms for .NET MAUI apps* (`learn.microsoft.com/dotnet/maui/supported-platforms?view=net-maui-10.0`:
  Windows 11 / Windows 10 version 1809 = `10.0.17763.0` or higher, via WinUI 3) and the
  *dotnet/maui Release-Versions* wiki (`github.com/dotnet/maui/wiki/Release-Versions` — the authority
  for the exact .NET 10 / Windows App SDK / MAUI workload versions per release). There is **no wire
  auth** to pin (this is a build-toolchain seam, not a service). The *binding* authority at build
  time is the toolchain actually resolved in CI — `actions/setup-dotnet@v4` at `10.0.x`,
  `dotnet workload install maui`, and `dotnet restore` against the live NuGet feed — so version pins
  are confirmed against the live workload at restore, not asserted from memory (§9; Plan "note on
  package versions").
- **Proof:** CI build step green — compilation against the real external toolchain (**automated**,
  real I/O against the SDK/workload). Launch-to-empty-box + DI-resolves-`ILogger<MainPage>` verified
  **manually** (screenshot of the running app) — automated UI-launch testing is out of scope (§3).

### Seam 4 — Serilog logging → rolling on-disk file

- **Class:** persistent-on-disk-state + host-OS/runtime (path semantics). **Internal** (`LoggingSetup` ↔ the filesystem).
- **Boundary:** `LoggingSetup` (Core) builds a Serilog `LoggerConfiguration` rooted at a
  caller-supplied base directory; the configured logger writes log lines to a rolling file on disk.
- **Contract:** Given a base directory `D`, the configured logger writes to
  `D/logs/weatherpoc-<yyyyMMdd>.log` (daily rolling interval, 7 files retained); a line written at
  `Information` level is present, verbatim, in that file after the logger is flushed/disposed. The
  base directory is a **required, non-null** parameter — `LoggingSetup` does **not** itself resolve
  `FileSystem.AppDataDirectory` (that platform-bound lookup stays in the app shell, which passes it
  in), keeping Core free of MAUI/Windows dependencies.
- **Proof:** an **automated on-disk round-trip test** (`WeatherPoC.Tests`) with real I/O on the write
  side — it calls `LoggingSetup` with a temporary directory, logs a known line, flushes, then reads
  the dated file back from disk and asserts the line is present; it goes red if the path shape,
  rolling pattern, or write behaviour drifts. *(The app-side composition — `MauiProgram` passing
  `FileSystem.AppDataDirectory`, and the injected `ILogger<MainPage>` resolving and flowing to
  Serilog — is the Seam 3 launch concern, verified manually per §3.)*

## 6. Acceptance criteria

1. `WeatherPoC.sln` contains the three projects of §4.1 with the stated TFMs and reference directions;
   the test project does **not** reference the app project.
2. `dotnet build -c Release` succeeds for the whole solution in CI on `windows-latest`. *(PRD story 40)*
3. The app launches on Windows to an empty box and the DI root resolves `ILogger<MainPage>`
   (verified manually per Seam 3). *(PRD stories 38–39)*
4. `dotnet test` runs green — including the `LoggingSetup` on-disk round-trip test (Seam 4) — and
   produces a Cobertura coverage report; ReportGenerator publishes an HTML report as a CI artifact.
5. The threshold gate **fails the build** when coverage of `WeatherPoC.Core` is below 100% **and** when
   `WeatherPoC.Core` has zero coverable lines; the self-test reproduces Seam 1 proofs b and c against
   fixtures **captured from ReportGenerator's merged report** (the artefact the gate reads).
6. The coverage report covers **only** `WeatherPoC.Core`; the app shell is excluded (Seam 2).
7. `WeatherPoC.Core` is plain `net10.0` with no Windows-only dependencies (Serilog + `Serilog.Sinks.File`
   only, both cross-platform), keeping macOS viable. *(PRD story 41)*
8. `LoggingSetup` writes a line to `<base>/logs/weatherpoc-<date>.log` (daily roll, 7 files retained),
   proven by the automated round-trip test against a temporary directory (Seam 4). *(PRD stories 38–39)*

## 7. Reconciliations with upstream artefacts

- **R1 — Principle 5 coverage exclusion (consistency-check C1, 2026-06-16).** Technical-Context Overriding
  Principle 5 **already states the exclusion explicitly** — "100% unit-test coverage of testable production
  code … The XAML Views, the DI composition root, and the Serilog bootstrap are untestable UI/wiring and are
  coverage-excluded (via `[ExcludeFromCodeCoverage]`); the 100% gate applies to everything else." This Feature
  **implements that exclusion exactly** (via the include-filter `[WeatherPoC.Core]*` + `[ExcludeFromCodeCoverage]`);
  the gate configuration is the mechanical embodiment of the principle as written. (Consistency check C1 flagged
  an earlier flat "100%" wording; the human-owned wording fix to Principle 5 has since landed — it now carries the
  carve-out — so no edit to the principle is pending.)
- **R2 — CI/CD scope.** The PRD lists "CI/CD pipeline, signing, and installer packaging" under
  *Out of Scope* (release mechanics are separate from the product PRD), while Roadmap F1 explicitly
  pulls in the build + test + coverage pipeline. **No contradiction:** this Feature lands **only** the
  build + test + coverage spine (the de-risking mechanism, per Roadmap F1's "only build + test +
  coverage is pulled in here"); **signing and installer packaging stay deferred**, matching the PRD.
- **R3 — Roadmap F1 "vacuous gate" framing (feature-doc-gauntlet, 2026-06-16).** Roadmap Feature 1
  originally stated "the coverage gate passes vacuously" and that the Feature "ships no testable production
  code" — language from the earlier draft's vacuous-100%-of-nothing-plus-disposable-canary approach. This
  Feature instead lands `LoggingSetup` (§4.3) as the one real, fully-covered gated module, so the gate is
  **non-vacuous** and no canary is needed. The `/feature-doc-gauntlet` re-run flagged the resulting
  Spec/Plan ↔ Roadmap contradiction (the Roadmap **outranks** the Spec/Plan in the authority order).
  **Resolution:** rather than reverting this design to a vacuous gate, the higher-authority `Roadmap.md`
  was amended — Feature 1 (its intro and *Out of scope*) and Feature 2's "first real testable production
  code" line — to record that `LoggingSetup` is the real gated module landing in F1, so Feature 2 is the
  first real **domain** code rather than the first testable code at all. Decision taken by the Feature owner
  during the `/fix-feature-docs` pass on 2026-06-16.

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary (no domain terms are implemented here, but vocabulary governs naming).
- `Technical-Context.MD` — **Overriding Principle 5** (the 100% gate + UI/wiring exclusion), Frameworks
  (.NET MAUI on .NET 10, MVVM), Packages in use (CommunityToolkit.Mvvm, Serilog + extensions, xUnit,
  Moq, AwesomeAssertions, coverlet), Instrumentation (Serilog rolling file + Debug sink, local-only),
  Branching (trunk-based, `main` protected, deterministic checks), Git Guardrails.
- `PRD.md` — stories 38–41 (privacy, local logs, Windows native, macOS-viable), Architecture, and
  Testing Decisions (coverage gate, the modules that are excluded from unit tests).
- `Roadmap.md` — Feature 1 entry (scope, out-of-scope, "why first").
- `docs/adr/0001-location-detection-cascade.md`, `docs/adr/0002-per-measurement-unit-defaults.md` —
  for awareness only; neither is implemented in this Feature (their subjects are deferred to Features
  4–6). No design decision here may contradict them.
- `docs/superpowers/consistency-checks/2026-06-16.md` — finding C1 (the R1 reconciliation above).

## 9. Open questions / deferred to the Plan

- **Exact package versions** (.NET 10 GA / current MAUI workload, CommunityToolkit.Mvvm, Serilog sinks,
  coverlet.collector, ReportGenerator) — pinned at Plan/implementation time.
- **`LoggingSetup` shape** — the exact method signature (e.g. returns a Serilog `LoggerConfiguration`
  for the caller to finish and build, vs a built logger) is a Plan/TDD detail; the contract is only
  Seam 4's: a base-directory parameter in, a logger that writes to `<base>/logs/weatherpoc-<date>.log`
  (daily, 7 retained), proven by the on-disk round-trip test.
- **Windows SDK TFM revision** (`net10.0-windows10.0.19041.0` vs a later revision) — confirmed against
  the installed workload at implementation time.

## Feature-doc-gauntlet sign-off

- **Result:** pass
- **Date:** 2026-06-16
- **Summary:** All three leaves passed on a clean full re-run — the prior `check-artefact-consistency` blocker (Roadmap F1 "passes vacuously" / "ships no testable production code") is resolved and the fix-pass amendment introduced no new contradiction.
- **Leaves:** check-seam-cynicism (pass), check-doc-adr-consistency (pass), check-artefact-consistency (pass)
- **Supersedes:** the stale `fail` sign-off from the 2026-06-16 re-run (which predated the `/fix-feature-docs` edits). This sign-off reflects a fresh full re-run of all three leaves against the current Spec, Plan, and the amended `Roadmap.md`.
- **Non-gating observations (do not block `enate-to-stories`):**
  - *Seam 1 (Plan Task 5):* the gate's build-failing power ultimately rests on the GitHub Actions `pwsh` step translating a non-zero script exit code into a failed CI step — standard runner behaviour, and the script's own exit-code logic is proven by the self-test; worth one live CI red-run as belt-and-braces.
  - *Seam 3 launch/DI half (Plan Task 6):* proven manually by design (automated UI-launch out of scope, §3) — depends on the screenshot/log evidence actually being attached to the PR.
  - The `LoggingSetup` technical term is absent from `Context.MD` (by design — it is a domain glossary and no domain terms ship in F1), and the cited `docs/superpowers/consistency-checks/2026-06-16.md` exists in the tree.
- **Next step:** This Feature is **cleared for `enate-to-stories`**. A later substantive edit to this Spec or the Plan invalidates this sign-off — re-run `/feature-doc-gauntlet` in full rather than trusting it.
