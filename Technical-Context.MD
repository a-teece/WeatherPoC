# Technical Context

Engineering-practice contract for code-writing agents in this project. Every implementation must respect what's written here. If a constraint conflicts with the user's request, flag the conflict — don't silently bypass it.

_Last reconciled with reality: 2026-06-16._

## Overriding Principles
1. **Secrets live in OS secure storage, never in source.** Any secret the app holds (a keyed provider, a telemetry DSN, signing credentials) is stored via MAUI `SecureStorage` (Windows DPAPI / macOS Keychain) and never committed in `appsettings.json`, `.env`, or code. The current data provider (Open-Meteo) needs no key, but the rule stands for everything that follows.
2. **The UI thread never blocks.** All I/O is `async`; no `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` on the UI thread. A frozen UI is a defect, not a nit.
3. **All weather-provider access goes through one typed client.** Every call to the data provider routes through a single typed service (e.g. `IWeatherService`). No ad-hoc `HttpClient` usage scattered across ViewModels or views.
4. **Unit tests never touch the network; end-to-end tests do.** Unit tests always fake the provider — no live calls (flaky, rate-limited). A separate end-to-end suite exercises the real Open-Meteo API deliberately.
5. **100% unit-test coverage of testable production code.** Coverage is a hard gate, not an aspiration. New production code arrives with the unit tests that cover it. The XAML Views, the DI composition root, and the Serilog bootstrap are untestable UI/wiring and are coverage-excluded (via `[ExcludeFromCodeCoverage]`); the 100% gate applies to everything else.

## Frameworks
- **.NET MAUI on .NET 10 (LTS)** — cross-platform desktop UI from a single codebase. Ships to Windows first; macOS is a planned future target, so no Windows-only APIs without an abstraction.
- **MVVM** — the app's structural pattern. Views bind to ViewModels; business logic stays out of code-behind.

## 3rd-party tech
- **Open-Meteo (Weather Forecast API)** — current conditions and forecast data. Free, open data, **no API key required**.
- **Open-Meteo Geocoding API** — resolves place names to coordinates for lookups.
- **IP-geolocation service** *(provider TBD — see `docs/adr/0001-location-detection-cascade.md`)* — approximates the User's location when device GPS is unavailable or denied.

## Packages in use
Reach for these before pulling in a new dependency. A new package needs a reason these don't cover.

**UI / MVVM:** CommunityToolkit.Mvvm (observable objects, relay commands, source generators), CommunityToolkit.Maui (behaviors, converters, Snackbar/Toast, popups)
**HTTP / resilience:** `IHttpClientFactory` (typed clients), Microsoft.Extensions.Http.Resilience (retry, timeout, circuit-breaker)
**Serialization:** System.Text.Json (source-generated serialization)
**Units:** UnitsNet (unit conversion + localized formatting); CLDR `unitPreferenceData` (`weather` usage) for locale-derived per-measurement defaults — *evaluating* `Porticle.CLDR.Units`, see `docs/adr/0002-per-measurement-unit-defaults.md`
**DI / hosting:** Microsoft.Extensions.DependencyInjection via `MauiAppBuilder` (built in)
**Secure storage:** Microsoft.Maui.Storage `SecureStorage`
**Logging:** Serilog (+ Serilog.Extensions.Logging and a rolling-file sink)
**Testing:** xUnit (runner), Moq (fakes/mocks), AwesomeAssertions (fluent assertions), coverlet (coverage measurement for the 100% gate)

## Instrumentation
Serilog is the logging backbone. Logs write to a **rolling file in the per-user app-data folder**; in development a Debug sink mirrors output to the IDE. **No telemetry leaves the user's machine** — there is no crash-reporting or analytics service; logging is local-only by design. This "local-only" rule governs **telemetry and diagnostics**, not **functional** API calls — fetching weather, geocoding, or IP-based location necessarily sends requests (and therefore the source IP) to third parties, and that is expected.

Always logged, regardless of level configuration:
- **Every Open-Meteo call** — endpoint, response status, and latency.
- **Every unhandled exception.**

## User Feedback Approach
The app's own UI is the only feedback channel (no email/Slack/push for a desktop app).

- **Inline view state** — loading / empty / error states rendered on the view itself.
- **Snackbar / Toast** (CommunityToolkit.Maui) — transient, non-blocking notices.
- **Dialogs** — blocking errors that need acknowledgement.

**Tone: friendly and actionable.** User-facing copy says what happened and what to do next ("Couldn't reach the weather service. Check your connection and try again."). Never surface raw error codes or stack traces to the user — that detail goes to the log only.

## Branching and Environments
- **Model:** Trunk-based. Short-lived feature branches merge into `main` via PR with review and green CI.
- **Branches:** `main` (integration), short-lived `feature/*` branches off `main`.
- **Environments (release channels):** desktop app, so channels replace server tiers —
  - **Debug** — local development builds.
  - **Release** — signed installer shipped to end-user desktops; a tag on `main` triggers the release build.
- **Protected:** `main`.

## Git Guardrails
Require explicit human confirmation to override:
- **No force-push** (`--force` / `--force-with-lease`) to `main` or any shared branch.
- **No history/worktree destruction** — no `git reset --hard`, `git clean -fd`, or destructive checkout that discards uncommitted work.
- **No direct commits to `main`** and **no committing secrets** (API keys, `SecureStorage` values, signing certificates/passwords). Changes land via PR.
- **No merge to `main` without deterministic checks** — once CI/pipeline gating is in place, a merge requires it green.

Hooks: none installed yet (fresh repo). Candidates to wire up later — `git-guardrails-claude-code` (blocks dangerous git commands at the Claude Code layer) and a Husky.NET pre-commit gate running `dotnet format` + `dotnet test`.
