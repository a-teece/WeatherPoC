# CLAUDE.md — agent orientation

You are working in **WeatherPoC**, a product built with the **Enate SDLC Factory**.
This file is the *agent* front door (auto-loaded every session); `README.md` is the human one.

## Read this first — and follow the flow

This product is built by walking the Factory's **HITL → AFK** flow. **Before you act, read the
field guide and follow the flow it describes:**

➡️ **[Using the Enate SDLC Factory](https://github.com/kitcox-dev/enate-claude-skills/blob/main/docs/using-the-sdlc-factory.md)**

The guide is the source of truth for *which skill to fire when*. The single rule it hinges on,
which you must never break: **only a human moves a Story to `Agent Ready`** — that is the HITL→AFK
handoff; the orchestrator owns every other transition. Branching and merge rules are in
`CONTRIBUTING.md`.

## The documentation fabric (load before you plan or build)

Authority order (lower wins): **ADR > Technical-Context > Context (domain) > PRD > Roadmap > Spec > Plan.**

- **`Technical-Context.MD`** — the engineering contract every code-writing agent must respect
  (principles, secure-coding baseline, branching, and the testing standard).
- **`Context.MD`** — the domain glossary (the project's language; the Factory-standard filename is
  `business-domain-context.md` — this product predates that rename).
- **`PRD.md`** · **`Roadmap.md`** — product requirements; the ordered Feature list (F1–F6).
- **`docs/adr/`** — architectural decisions (highest authority).
- **`docs/superpowers/specs/`** · **`plans/`** — per-Feature Spec and Plan (the Plan carries the
  **Context references** an agent loads).

---

The rest of this file is the WeatherPoC-specific codebase guide.

## What it does

WeatherPoC is a single-user Windows desktop weather app built on .NET MAUI / .NET 10. It shows Current Conditions and a Daily Forecast for exactly one Active Location. Per-measurement unit preferences let users mix units (e.g. °C with mph) rather than choosing a single system-wide metric/imperial toggle.

## Current build status

| Feature | Status |
|---|---|
| F1: Walking skeleton — solution scaffold, LoggingSetup, on-disk test | Done |
| F2: Live Current Conditions (fixed location) | Not started |
| F3: Daily Forecast | Not started |
| F4: Per-measurement Unit Preferences | Not started |
| F5: Place Search + Saved Location | Not started |
| F6: Automatic location detection | Not started |

## Tech stack

- **.NET 10 / .NET MAUI** — desktop UI, Windows first, macOS planned
- **MVVM** — CommunityToolkit.Mvvm; no business logic in code-behind
- **Serilog** — rolling file in per-user app-data folder; no telemetry off-device
- **xUnit + AwesomeAssertions + Moq + coverlet** — test stack with hard 100% coverage gate
- **Open-Meteo** — weather and geocoding (no API key)
- **BigDataCloud** — IP geolocation + reverse geocoding (no API key; chosen in ADR 0001)
- **UnitsNet** — unit conversion and localized formatting

## Solution layout

```
WeatherPoC.slnx              — solution file
WeatherPoC.Core/             — net10.0 library; pure domain + cross-cutting, no MAUI dep
  LoggingSetup.cs            — Serilog rolling-file configuration (Seam 4; testable)
WeatherPoC.Tests/            — xUnit test project
  LoggingSetupTests.cs       — real on-disk round-trip test for LoggingSetup
docs/
  adr/                       — Architecture Decision Records
  superpowers/
    specs/                   — Feature specs (0001–0006)
    plans/                   — Implementation plans
Context.MD                   — domain glossary (source of truth for terminology)
Technical-Context.MD         — engineering constraints (prescriptive; human-owned principles)
PRD.md                       — product requirements + implementation decisions
Roadmap.md                   — feature sequencing (F1–F6)
```

## Key architectural rules

1. **Secrets live in OS secure storage.** Open-Meteo needs no key, but any future keyed provider uses MAUI `SecureStorage` — never `appsettings.json` or source.
2. **UI thread never blocks.** All I/O is `async`; no `.Result` / `.Wait()` on the UI thread.
3. **All weather-provider access through one typed client** (`IWeatherService`). No scattered `HttpClient` usage.
4. **Unit tests never touch the network.** Provider is always faked in unit tests; a separate end-to-end suite exercises live APIs.
5. **100% unit-test coverage gate.** Hard gate, not an aspiration. XAML Views, DI composition root, and Serilog bootstrap are `[ExcludeFromCodeCoverage]`; everything else is covered 100%.

## LoggingSetup — the one testable module in F1

`WeatherPoC.Core.LoggingSetup.CreateConfiguration(string baseDirectory)` returns a `LoggerConfiguration` that writes a daily rolling file at `{baseDirectory}/logs/weatherpoc-.log` (Serilog inserts the date), retaining 7 files, minimum level Information. The app head calls this and passes `FileSystem.AppDataDirectory`; Core stays free of MAUI dependencies. The Serilog bootstrap (`.AddSerilog(...)` on the MAUI host) is coverage-excluded wiring — not in `LoggingSetup`.

## Terminology

All domain terms (Active Location, Detected Location, Saved Location, Current Conditions, Daily Forecast, Weather Variable, Measurement Unit, Unit Preferences) are defined precisely in `Context.MD`. Use that glossary — not everyday English synonyms — in code, tests, and docs.

## ADRs

- `docs/adr/0001-location-detection-cascade.md` — GPS → BigDataCloud cascade; why BigDataCloud over MAUI Geocoding
- `docs/adr/0002-per-measurement-unit-defaults.md` — CLDR embedding over `Porticle.CLDR.Units`; why not `RegionInfo.IsMetric`
