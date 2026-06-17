# WeatherPoC

A clean, single-user Windows desktop weather app. Shows Current Conditions and a Daily Forecast for exactly one Active Location at a time, with per-measurement unit preferences (so a UK user gets °C for temperature and mph for wind speed, not a forced all-metric or all-imperial toggle).

## Status

Walking skeleton — solution scaffold, `LoggingSetup` module, and on-disk round-trip test in place. No UI or weather data yet (Feature 2 onwards).

## Prerequisites

- .NET 10 SDK
- Windows (first target; macOS planned)

## Build

```
dotnet build WeatherPoC.slnx
```

## Test

```
dotnet test WeatherPoC.slnx
```

## Solution layout

| Project | Target | Purpose |
|---|---|---|
| `WeatherPoC.Core` | net10.0 | Pure domain and cross-cutting modules (no MAUI dependency) |
| `WeatherPoC.Tests` | net10.0 | xUnit test project for all testable production code |

The MAUI app head (`WeatherPoC`) is not yet in the solution — it arrives in Feature 1's MAUI scaffold work.

## Logging

`LoggingSetup.CreateConfiguration(baseDirectory)` configures Serilog to write daily rolling files at `{baseDirectory}/logs/weatherpoc-yyyyMMdd.log`, retaining 7 files, minimum level Information. The app head calls this and passes `FileSystem.AppDataDirectory` as the base; `WeatherPoC.Core` itself has no MAUI dependency.

## Privacy

No analytics or crash-reporting. Logs stay on the user's machine. The only data that leaves the device is functional API traffic (weather, geocoding, location detection).
