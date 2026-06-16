# Roadmap

**Product:** WeatherPoC — a clean, single-user desktop app showing weather for exactly one Active Location, the User's way.
**Last reviewed:** 2026-06-16

## Sequencing

Features are listed in delivery order. Each Feature gets its own `/brainstorming` session, Spec, and Plan.

**Dependency chain:** 1 → 2 → 3; Feature 4 depends on 2 + 3; Feature 5 depends on 2 + 3 (independent of 4); Feature 6 depends on 5.

---

## Feature 1: Blank-box walking skeleton 🔫 *tracer bullet*

A native Windows .NET MAUI app that launches to an empty box, backed by a unit-test skeleton and a pipeline that builds the app, runs the tests, and wires in the 100%-unit-test-coverage gate. There is no domain logic yet, but the skeleton lands the one piece of real, testable production code it genuinely needs — the Serilog logging-configuration module (`LoggingSetup`) — so the coverage gate has real coverable code and is **not** vacuous. Its job here is to prove the *mechanism* end-to-end: the app builds and runs on Windows, the DI/MVVM scaffold and Serilog bootstrap are in place, the test project builds and runs, and the pipeline produces a coverage report that can fail the build.

**Out of scope:** Any weather data, any location, and any domain logic — including the Active Location resolver, which moves to Feature 5 where there is something to resolve. The XAML View, DI composition root, and Serilog bootstrap are coverage-excluded as untestable UI/wiring; the one piece of testable production code the skeleton does ship is the `LoggingSetup` logging-configuration module, covered 100% by the gate. Release signing and installer packaging stay deferred (only build + test + coverage is pulled in here).

**Dependencies:** None (this is the tracer bullet).

**Why first:** In greenfield .NET MAUI on .NET 10 the scariest unknowns are "does a MAUI app build and run on Windows at all" and "can we stand up a deterministic pipeline that gates on 100% coverage" — not the well-trodden weather call. A walking skeleton that nails the build/test/coverage spine de-risks every Feature that rides on top of it.

---

## Feature 2: Live Current Conditions for a fixed Location

For a single hard-coded Location, the app fetches and displays Current Conditions — temperature, feels-like, humidity, wind speed and direction, precipitation, and the Weather Condition as an icon and label — with an inline loading state while fetching, an inline friendly error message on failure, a refresh-on-demand action, and an **automatic refresh every 15 minutes** so the live reading does not silently go stale (PRD story 20). A visible "last updated" timestamp shows the reading's age, and a failed refresh keeps the last good reading behind a quiet "couldn't update" indicator rather than blanking it; only a failed *first* fetch (nothing cached yet) shows the dedicated error + Retry state. The Weather Condition icon distinguishes day from night for clear and partly-cloudy skies via Open-Meteo's `is_day` flag. This lands the typed `IWeatherService` (the one Open-Meteo client per Overriding Principle 3), the domain Current Conditions type, the JSON→domain mapping, the WMO-code→icon/label mapping, and the backing ViewModel (which owns the loading/loaded/stale/error state machine and the auto-refresh timer lifecycle). It is the first real *domain* production code — the coverage gate already has real teeth from Feature 1's `LoggingSetup` module, and here it starts biting on the weather domain logic; every Open-Meteo call is logged to the local Serilog file.

**Out of scope:** Location detection and Place Search (the Location is hard-coded). The Daily Forecast. Unit Preferences — values are shown in a single fixed unit per measurement, with no per-measurement choice, CLDR defaults, or formatter yet. Saved Location, persistence, and the empty state.

**Dependencies:** Feature 1 (the app shell, DI/MVVM scaffold, Serilog wiring, and the build + test + coverage pipeline it runs through).

---

## Feature 3: Daily Forecast

Below Current Conditions, the app shows the Daily Forecast for the same (still hard-coded) Location: today plus the following days, each day summarised as a high/low temperature and an overall Weather Condition rendered as an icon and label. The first day is today, deliberately overlapping Current Conditions at a different granularity — the live reading sits alongside today's high/low summary, presented as complementary rather than contradictory. Extends `IWeatherService` with the daily-forecast portion of the Open-Meteo response and adds the forecast domain type, mapping, and ViewModel, all faked-provider unit-tested under the 100% gate.

**Out of scope:** An hourly forecast — one summary per day only, with no hour-by-hour view (and never, per the PRD). Location detection, Place Search, Saved Location. Unit Preferences — high/low temperatures are still shown in a single fixed unit; the formatter comes in Feature 4.

**Dependencies:** Feature 2 — reuses the typed `IWeatherService` and the WMO-code → icon + label rendering introduced for the Current Conditions Weather Condition, so a forecast day's condition reads the same way as the live one.

---

## Feature 4: Per-measurement Unit Preferences

Every numeric Weather Variable across Current Conditions and the Daily Forecast becomes displayed in a Measurement Unit the User chooses independently per kind of measurement — °C/°F for temperature, mph/km·h⁻¹ and similar for wind, mm/in for precipitation, and so on. Defaults are derived from the device locale via CLDR `unitPreferenceData` (`weather` usage) per ADR 0002 — so a UK User starts with °C **and** mph, the mixed convention `RegionInfo.IsMetric` cannot express. A settings surface lets the User override any single unit from a sensible list of options without disturbing the others, and those overrides persist across restarts. Changing a unit is purely a display concern — it re-renders the existing reading instantly and losslessly, never re-fetching or mutating the underlying canonical value. Lands the Locale unit-default resolver (pure; the guardrail against the `IsMetric` regression), the Weather Variable formatter (canonical value → chosen unit → localized string, via UnitsNet), and the Unit Preferences store (overrides layered on top of CLDR defaults), and retrofits Features 2 and 3 to render through the formatter.

**Out of scope:** A bundled metric/imperial "unit system" toggle — explicitly not built; units are per-measurement (ADR 0002). Location detection, Place Search, Saved Location. Confirming the concrete CLDR data package (`Porticle.CLDR.Units` vs embedding the slice) — that is the ADR-0002 spike, resolved at this Feature's spec/brainstorming time.

**Dependencies:** Features 2 and 3 — these are the surfaces whose values get reformatted; the formatter has nothing to format until Current Conditions and the Daily Forecast exist. Independent of location (Feature 5/6).

---

## Feature 5: Place Search + Saved Location

The User can set the Active Location by hand instead of living with the hard-coded one. Via Place Search they type a human-readable place name; when the query is ambiguous the app shows a list of matching named candidates to disambiguate; choosing one makes it the Active Location and persists it as the Saved Location, so the app reopens on that place. The User can clear the Saved Location, which removes the override — and since there is no detection yet, clearing drops to a clear empty state that invites a Place Search. The UI keeps it legible that the displayed place is a chosen one. Lands the Geocoding service (the second typed Open-Meteo client — place name → candidate Locations), the Saved Location store (ordinary local persistence, not `SecureStorage` — no secrets), and the Active Location resolver — the pure rule the tracer bullet deferred. At this stage the resolver arbitrates Saved-or-absent (Saved set → Active is Saved; cleared → no Active Location → empty state); the full Saved-over-Detected matrix completes in Feature 6.

**Out of scope:** Automatic location detection (GPS / IP) — that is Feature 6; here, location is only what the User searches for. A saved-list / multiple locations — exactly one Active Location at a time, always. The detected-vs-saved distinction is only half-real here (there is no Detected Location yet to contrast against); it completes in Feature 6.

**Dependencies:** Feature 2 (the Active Location drives the Current Conditions fetch/display already built) and Feature 3 (the forecast re-fetches for the newly chosen Location). Independent of Feature 4 — units and location are orthogonal.

---

## Feature 6: Automatic location detection

On launch, the app establishes the Active Location with no typing required, replacing the hard-coded Location for good. It runs the detection cascade of ADR 0001 — device GPS first, falling back to IP-based geolocation when GPS is unavailable or permission is denied, and only dropping to Place Search when both fail entirely (the empty state built in Feature 5 becomes that terminal fallback). A resolved position becomes a named Detected Location, and the Detected Location is re-derived every run, never persisted, so the app follows the User as they move. The Active Location resolver's full rule now completes: a Saved Location still overrides detection, and clearing the Saved Location reverts the Active Location to the Detected Location — and the UI makes detected vs saved legible at all times. Lands the Location detection cascade orchestration, the IP-geolocation client (concrete provider chosen at this Feature's spec time per the ADR-0001 deferral), and a platform GPS position source abstracted so a macOS implementation can follow without touching the cascade logic. Friendly messaging guides the User to Place Search when detection fails — a gentle nudge, not a dead end.

**Out of scope:** Choosing the IP-geolocation provider before this Feature — it is resolved in this Feature's brainstorming/spec. A macOS GPS implementation — only the abstraction is built; shipping macOS stays a future target. Pinpoint accuracy — IP geolocation is city-level by nature (ADR 0001); good enough for weather, not precise.

**Dependencies:** Feature 5 — reuses the Active Location resolver (now feeding it a Detected input alongside Saved) and the Place Search surface as the cascade's terminal fallback. Indirectly Features 2 and 3, since the Detected Location drives the same fetch/display.
