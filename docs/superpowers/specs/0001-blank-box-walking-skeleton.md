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

A deliberate consequence of "no domain logic" is that the coverage gate would **pass
vacuously** (100% of nothing). Because a vacuous pass proves nothing about whether the gate
*can* fail a build — which is an explicit goal — this Feature ships a **throwaway canary**
(§4.3) so the gate is demonstrably live in the merged artefact.

## 2. Goals — what "done" proves

1. The MAUI app **compiles** for the Windows head in CI and **launches to an empty box** locally.
2. The **DI composition root, MVVM scaffold, and Serilog bootstrap** are wired and exercised at
   startup (a startup line is written to the local rolling log file).
3. The **test project** builds and runs under xUnit in CI.
4. The pipeline **produces a coverage report** and the gate **can fail the build** — proven by the
   canary: the gate is green with the canary test present and red without it (§5, Seam 1).
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
| `WeatherPoC.Core` | `net10.0` | The 100%-gated production surface. No domain logic yet; holds only the throwaway canary (§4.3) | **Included — the gated surface** |
| `WeatherPoC.Tests` | `net10.0` | xUnit + Moq + AwesomeAssertions + coverlet.collector | Not measured |

**Dependency direction (set now, even though minimal):** `WeatherPoC` → `WeatherPoC.Core`;
`WeatherPoC.Tests` → `WeatherPoC.Core`. The test project **does not** reference the app project —
this is one of the mechanisms that keeps the UI/wiring out of the coverage measurement (§5, Seam 2).
`WeatherPoC.Core` is plain `net10.0` (no platform dependencies), so it is the fast-to-test,
macOS-viable spine.

### 4.2 App shell + scaffold (coverage-excluded)

All of the following live in the `WeatherPoC` app project and are coverage-excluded as untestable
UI/wiring (Overriding Principle 5; PRD Testing Decisions "Excluded from unit tests"):

- **`MauiProgram.CreateMauiApp()`** — builds the `MauiAppBuilder` DI container, registers
  CommunityToolkit.Mvvm and a single `MainPage`, and registers Serilog as the logging provider.
- **`MainPage` (XAML View)** — the empty box. No bound behaviour, no ViewModel logic.
- **Serilog bootstrap** — a rolling file sink in the per-user app-data folder
  (`FileSystem.AppDataDirectory`) plus a Debug sink under `DEBUG` (Technical-Context Instrumentation;
  PRD Logging and privacy). One startup line is emitted via the injected `ILogger` to prove the
  logging provider resolves and writes. **No telemetry leaves the machine** (PRD stories 38–39).

Exclusion is belt-and-braces: `[ExcludeFromCodeCoverage]` on the shell types **and** the test project
not referencing the app **and** the runsettings include-filter scoping measurement to Core (§4.4).

### 4.3 Core + the throwaway canary

`WeatherPoC.Core` contains **one trivial pure type** — a scaffolding canary (e.g. a `SkeletonMarker`
with a single method returning a constant) — and `WeatherPoC.Tests` contains an xUnit test that
covers it **100%**. The canary exists for exactly one reason: to give the coverage gate teeth in the
merged artefact (without it, Core has zero coverable lines and the gate passes vacuously).

The canary is documented in-code as temporary scaffolding. **Feature 2 deletes it** when the first
real module (the typed `IWeatherService` + the Current Conditions domain type) lands and the gate
starts biting on real production code.

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

> **Branch protection** (making this check *required* on `main`, the mechanical enforcement of the
> Technical-Context guardrail "No merge to `main` without deterministic checks") is a repo-admin
> action, not code — flagged here as a follow-up for the repo owner, outside this Feature's diff.

## 5. Seam inventory

The cross-module contracts this Feature relies on. Each carries a falsifiable contract and a real
proof — this is the payload of the tracer bullet.

### Seam 1 — Coverage-gate contract *(headline)*

- **Boundary:** `dotnet test` (coverlet.collector) → Cobertura XML → threshold gate step → CI pass/fail.
- **Contract:** After the test run, a Cobertura report exists with `lines-covered` and `lines-valid`
  for assembly `WeatherPoC.Core`. The gate **passes iff `lines-valid > 0 ∧ lines-covered == lines-valid`**;
  it fails otherwise (including the zero-coverable-lines case).
- **Proof (falsifiable, demonstrable in CI):**
  - (a) Canary test present → `covered == valid > 0` → **green**.
  - (b) Canary test removed/skipped → `covered < valid` → **red** ("coverage below 100%").
  - (c) Canary removed entirely (empty Core) → `valid == 0` → **red** ("no coverable lines").

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

- **Boundary:** `dotnet build -c Release` over the solution on the Windows runner (with the maui
  workload); the DI composition root resolves `MainPage` + `ILogger`; the app launches to the empty
  box and Serilog writes a startup line to the per-user rolling log file.
- **Contract:** The solution compiles on CI; the host builds without DI resolution exceptions; the
  app process starts, renders `MainPage`, and emits a startup log line via the injected logger.
- **Proof:** CI build step green (compilation — **automated**). Launch-to-empty-box + log-file-written
  verified **manually** (screenshot of the running app + the log file) — automated UI-launch testing
  is out of scope for this Feature (§3).

## 6. Acceptance criteria

1. `WeatherPoC.sln` contains the three projects of §4.1 with the stated TFMs and reference directions;
   the test project does **not** reference the app project.
2. `dotnet build -c Release` succeeds for the whole solution in CI on `windows-latest`. *(PRD story 40)*
3. The app launches on Windows to an empty box; the per-user rolling log file contains a startup line.
   *(PRD stories 38–39; verified manually per Seam 3)*
4. `dotnet test` runs the canary test green and produces a Cobertura coverage report; ReportGenerator
   publishes an HTML report as a CI artifact.
5. The threshold gate **fails the build** when coverage of `WeatherPoC.Core` is below 100% **and** when
   `WeatherPoC.Core` has zero coverable lines (Seam 1 proofs b and c are reproducible).
6. The coverage report covers **only** `WeatherPoC.Core`; the app shell is excluded (Seam 2).
7. `WeatherPoC.Core` is plain `net10.0` with no Windows-only dependencies, keeping macOS viable.
   *(PRD story 41)*

## 7. Reconciliations with upstream artefacts

- **R1 — Principle 5 wording (consistency-check C1, 2026-06-16).** Technical-Context Overriding
  Principle 5 states "100%" flatly, while the PRD and Roadmap carve out the XAML View / DI composition
  root / Serilog bootstrap as coverage-excluded. This Feature **implements the exclusion exactly as the
  PRD/Roadmap describe** (via the include-filter + `[ExcludeFromCodeCoverage]`). The authoritative
  wording fix to Principle 5 is a **human-owned prescriptive edit** (already tracked in the
  2026-06-16 consistency check) — this Feature does not silently edit the principle; the gate
  configuration is the mechanical embodiment of the already-agreed intent.
- **R2 — CI/CD scope.** The PRD lists "CI/CD pipeline, signing, and installer packaging" under
  *Out of Scope* (release mechanics are separate from the product PRD), while Roadmap F1 explicitly
  pulls in the build + test + coverage pipeline. **No contradiction:** this Feature lands **only** the
  build + test + coverage spine (the de-risking mechanism, per Roadmap F1's "only build + test +
  coverage is pulled in here"); **signing and installer packaging stay deferred**, matching the PRD.

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
- **Canary shape** — the precise pure type and its test are a Plan/TDD detail; the contract is only
  that it is a pure, fully-coverable type with a 100%-covering test, removed in Feature 2.
- **Windows SDK TFM revision** (`net10.0-windows10.0.19041.0` vs a later revision) — confirmed against
  the installed workload at implementation time.
