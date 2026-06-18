# Manual launch verification — Seam 3 (Story #22)

**Story:** [#22 — Manual launch verification on Windows: empty box + DI + on-disk log line (Seam 3 launch proof)](https://github.com/a-teece/WeatherPoC/issues/22)
**Feature:** Blank-box walking skeleton (Feature 1)
**Spec:** `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` (§3 — automated UI-launch out of scope; Seam 3; acceptance 3)
**Plan:** `docs/superpowers/plans/2026-06-16-blank-box-walking-skeleton.md` (Task 6)

This story is the **manual** half of Seam 3 — automated UI-launch testing is out of scope (Spec §3), so the launch-to-empty-box and DI-resolution proof is performed by a human on Windows and recorded here as the verification record. No production code changes.

## Environment

| | |
|---|---|
| Date | 2026-06-18 |
| OS | Windows 11 Pro (10.0.26200) |
| .NET SDK | 10.0.301 |
| MAUI workload | 10.0.20/10.0.100 |
| TFM | `net10.0-windows10.0.19041.0` (unpackaged, `WindowsPackageType=None`) |
| Build | `dotnet build WeatherPoC/WeatherPoC.csproj -c Debug` → **Build succeeded, 0 warnings, 0 errors** |
| Launch | ran the produced `WeatherPoC.exe` head |

## Acceptance criteria

### AC1 — Single empty-box window
The app launched to a single window rendering `MainPage` (a bare `<Grid />`) as an empty box. Screenshot captured via `PrintWindow` of the app's main window:

![Seam 3 empty-box window](./seam3-empty-box-window.png)

### AC2 — DI composition root resolves `ILogger<MainPage>` cleanly
The app started without a resolution exception. The DI chain `App(MainPage)` → `MainPage(ILogger<MainPage>)` is exercised on launch; an unresolved `ILogger<MainPage>` would throw during composition and crash startup. The process launched and rendered, and — definitively — the startup line below was written *through* the injected logger from inside `MainPage`'s constructor, which can only happen if the logger resolved.

### AC3 — Startup line present in the per-user rolling log
Log file located at:

```
%LOCALAPPDATA%\User Name\net.enate.weatherpoc\Data\logs\weatherpoc-20260618.log
```

(`FileSystem.AppDataDirectory/logs/weatherpoc-<date>.log` per `WeatherPoC.Core.LoggingSetup`; Serilog daily rolling sink inserts the `yyyyMMdd` date.) Contents (see `weatherpoc-20260618.log` in this folder):

```
2026-06-18 13:51:08.787 +01:00 [INF] WeatherPoC started: walking skeleton MainPage composed and rendered.
```

This matches the expected line exactly: `WeatherPoC started: walking skeleton MainPage composed and rendered.`

> Note: the on-disk **write contract** itself is proven automatically by the Seam 4 round-trip test (Story #18), independent of the UI. This manual check is the host-level launch sanity confirmation.

### AC4 — Evidence recorded
This document plus the attached screenshot (`seam3-empty-box-window.png`) and log snippet (`weatherpoc-20260618.log`) are the manual verification record for Seam 3 / acceptance criterion 3, posted on this PR.

## Verdict

**PASS** — all four acceptance criteria satisfied.
