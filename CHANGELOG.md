# Changelog

## [Story 18] - 2026-06-17

### Added

- **Solution scaffold** (`WeatherPoC.slnx`) with two projects: `WeatherPoC.Core` (net10.0 class library) and `WeatherPoC.Tests` (xUnit test project). The MAUI app head is deferred — the walking skeleton deliberately starts with the pure, testable layer first so the 100% coverage gate has real content before the untestable MAUI wiring is added.
- **`LoggingSetup.CreateConfiguration(string baseDirectory)`** in `WeatherPoC.Core` — the Serilog rolling-file configuration module (Seam 4 write contract). Configures a daily rolling file at `{baseDirectory}/logs/weatherpoc-yyyyMMdd.log`, retaining 7 files, minimum level Information. Factored out of the app shell so its on-disk write contract is unit-testable; the app head passes `FileSystem.AppDataDirectory` as the base, keeping `WeatherPoC.Core` free of MAUI dependencies (macOS-viable). The Serilog bootstrap wiring that registers this with the MAUI host is coverage-excluded as untestable — `LoggingSetup` itself is not.
- **`LoggingSetupTests` real on-disk round-trip test** — a single xUnit fact writes a line through a `LoggingSetup`-configured logger, then asserts the dated rolling file exists and contains that line. Uses a temp directory with cleanup so it is hermetic. This is the first production code covered by the 100% gate, proving the gate is not vacuous before domain code arrives.
- **`.gitignore`** — excludes `bin/`, `obj/`, `TestResults/`, and `CoverageReport/` so build and test output never reaches source control.
- **Core project documentation** (`Context.MD`, `PRD.md`, `Technical-Context.MD`, `Roadmap.md`) — domain glossary, product requirements with implementation decisions, engineering-practice constraints, and feature sequencing (F1–F6).
- **ADRs** (`0001-location-detection-cascade.md`, `0002-per-measurement-unit-defaults.md`) — resolving the IP-geolocation provider to BigDataCloud and the unit-preference data source to an embedded CLDR slice.
- **Feature specs** for all six roadmap features and an implementation plan for F1 (the walking skeleton).

### Decisions

- `WeatherPoC.Core` targets `net10.0` (not `net10.0-windows`) deliberately — keeping it free of platform-specific TFMs preserves macOS viability and allows it to be tested in a plain `net10.0` test project without MAUI dependencies.
- The Serilog configuration is separated from the Serilog bootstrap by design: configuration (path, rolling policy) is testable behaviour; wiring the configured logger into the MAUI host is not. This is the line `LoggingSetup` sits on one side of.
- AwesomeAssertions (fluent assertions) is the project-standard assertion library, chosen over FluentAssertions due to licence changes in recent FluentAssertions versions.
