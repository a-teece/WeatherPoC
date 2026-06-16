# Spec — Feature 2: Live Current Conditions for a fixed Location 🌤️

**Feature:** 2 (Roadmap.md) — first real domain code
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Depends on:** Feature 1 — the MAUI app shell, DI/MVVM scaffold, Serilog wiring, and the build + test + 100%-coverage pipeline.
**Downstream:** Feature 3 (Daily Forecast) reuses the typed `IWeatherService` and the WMO-code → icon + label mapping this Feature lands; Feature 4 (Unit Preferences) retrofits the formatter onto the Weather Variables shown here; Feature 5 (Place Search + Saved Location) replaces this Feature's hard-coded Location with the resolved Active Location.

---

## 1. Intent

For a **single hard-coded Location**, fetch and display **Current Conditions** — the live, right-now reading: temperature, apparent ("feels-like") temperature, humidity, wind speed, wind direction, precipitation, and the categorical **Weather Condition** as an icon and label. The view fetches on open, refreshes on demand, and **auto-refreshes every 15 minutes** so the reading never silently goes stale; a visible "Updated HH:MM" line tells the User how old the reading is.

This is the **first real domain production code** in the repo. Feature 1's `LoggingSetup` already gave the 100% coverage gate teeth; here the gate starts biting on the **weather domain** — the typed `IWeatherService` (Overriding Principle 3), the `CurrentConditions` domain type, the Open-Meteo JSON → domain mapping, the WMO-code → icon/label mapping, and the backing ViewModel with its loading / loaded / stale / error state machine.

The scary unknowns this Feature de-risks are the **external wire contract** (does the Open-Meteo `current` response deserialize to our domain type, and stay deserializable over time?) and the **non-blocking refresh lifecycle** (a timer + in-flight fetch that never freezes the UI thread and never leaks past view teardown). The well-trodden parts — rendering bound values — stay thin.

## 2. Goals — what "done" proves

1. For the hard-coded Location, the app fetches the Open-Meteo `current` block and renders all seven Weather Variables of story 19 + 16 + 17 + 18: temperature, feels-like, humidity, wind speed, wind direction, precipitation, and the Weather Condition (icon + label).
2. The Weather Condition icon distinguishes **day vs night** for clear and partly-cloudy skies (via Open-Meteo's `is_day`), and renders one glyph per condition otherwise (§4.4, Seam 2).
3. The view shows an **inline loading state** on first fetch, a **loaded state** with an "Updated HH:MM" timestamp, a **"couldn't update" stale indicator** when a later refresh fails, and a dedicated **"load failed" + Retry** state when the *first* fetch fails (§4.5, Seam 3). *(PRD stories 33, 34, 36)*
4. The view **refreshes on demand** and **auto-refreshes every 15 minutes** while open; the timer is cancelled on teardown and reset by a manual refresh; the UI thread never blocks (§4.5, Seam 3). *(PRD stories 20, 21, 35; Overriding Principle 2)*
5. All Open-Meteo access routes through the **single typed `IWeatherService`** (Overriding Principle 3); **every call is logged** (endpoint, status, latency) to the local Serilog file (Seam 4). *(PRD stories 38–39)*
6. The new domain surface (`IWeatherService` impl, mappers, WMO mapping, `CurrentConditions`, the ViewModel) is **100% unit-tested with the provider faked** (Overriding Principles 4 & 5); a **separate end-to-end test** exercises the real Open-Meteo endpoint to prove the live wire shape (Seam 1) — and is **excluded from the deterministic unit/coverage gate**.

## 3. Non-goals / out of scope

Per Roadmap Feature 2 and the PRD:

- **Location detection, Place Search, and the Active Location resolver** — the Location is a single hard-coded constant (Features 5–6). There is therefore **no "no Active Location" empty state** here (it needs Place Search to invite into — Feature 5).
- **The Daily Forecast** — Current Conditions only; the daily summary and the today-overlap are Feature 3.
- **Unit Preferences, the Weather Variable formatter, CLDR locale defaults, and per-measurement unit choice** — each Weather Variable is shown in **one fixed display unit** with no User choice (Feature 4; ADR 0002). F2 deliberately avoids the conversion/formatting layer entirely (§4.3).
- **Saved Location, persistence of any kind** — nothing is persisted in this Feature.
- **Release signing / installer packaging** — unchanged from Feature 1; still deferred.

## 4. Design

### 4.1 Where the code lives (coverage map)

Feature 1's three-project structure and coverage rules carry over unchanged. F2 adds code on both sides of the gate line:

| Lands in | Project | Coverage | What |
|---|---|---|---|
| `WeatherPoC.Core` (`net10.0`, gated) | the typed `IWeatherService` + its implementation, the `CurrentConditions` domain type, the Open-Meteo response DTOs + JSON→domain mapper, the `(weather_code, is_day) → (category, label, iconKey)` mapping, and the **Current Conditions ViewModel** | **100% gated** | the real domain + presentation logic |
| `WeatherPoC` (app head, excluded) | the XAML View (bindings + glyph rendering), the DI registration of the typed `HttpClient` + `Microsoft.Extensions.Http.Resilience` policies, and the hard-coded `Location` constant | `[ExcludeFromCodeCoverage]` (untestable UI/wiring) | thin binding + composition |
| `WeatherPoC.Tests` (`net10.0`, not measured) | unit tests with a **faked HTTP layer** | n/a | offline, deterministic |
| `WeatherPoC.EndToEnd` *(new, not measured, not in the gate)* | one deliberate live-network test against real Open-Meteo | n/a | proves Seam 1's live wire |

CommunityToolkit.Mvvm is cross-platform, so the ViewModel lives in `WeatherPoC.Core` and is **gated** (PRD Testing Decisions explicitly unit-test ViewModels). The XAML View stays in the excluded app head. The `IWeatherService` implementation does real HTTP, but is unit-tested **offline** by faking at the `HttpMessageHandler` boundary (canned JSON in, domain type out) — so it is 100%-coverable without touching the network (Overriding Principle 4), while the real wire is proven separately by the end-to-end test (Seam 1).

### 4.2 The typed weather client (`IWeatherService`)

The single typed client for **all** Open-Meteo access (Overriding Principle 3). Its F2 surface:

```
Task<Result<CurrentConditions>> GetCurrentConditionsAsync(Location location, CancellationToken ct)
```

- Built on an `IHttpClientFactory` typed client with `Microsoft.Extensions.Http.Resilience` (retry, timeout, circuit-breaker) configured in the app head.
- Serialization via source-generated `System.Text.Json`.
- All I/O is `async`; the cancellation token flows from the ViewModel so a torn-down view cancels its in-flight fetch (Overriding Principle 2).
- After resilience is exhausted, transport/HTTP/deserialization failures are returned as a **friendly domain-level failure** (a result type, not a thrown exception bubbling to the UI) carrying a user-safe message; the raw detail goes to the log only (PRD story 36; Technical-Context User Feedback).
- **Every call is logged** — endpoint, response status, latency — to the Serilog rolling file (Seam 4).

*(The exact `Result`/failure representation — discriminated result type vs nullable + error — is a Plan/TDD detail; the contract is "success → `CurrentConditions`, failure → a user-safe message, never an unhandled exception to the UI".)*

### 4.3 Fixed display units (no formatter)

F2 shows each Weather Variable in **one fixed unit**, obtained by **requesting that unit directly from Open-Meteo** via the API's unit query parameters (`temperature_unit`, `wind_speed_unit`, `precipitation_unit`). The response is therefore already in display units, so **F2 carries no conversion or formatting layer at all** — UnitsNet, the CLDR locale defaults, the per-measurement choice, and the Weather Variable formatter are all **Feature 4** (ADR 0002). This keeps the fixed-unit constraint of Roadmap F2 honest *and* keeps the F4 formatter a clean, additive retrofit rather than a rewrite.

The fixed units chosen for F2 (foreshadowing the eventual UK locale default of °C-with-mph that ADR 0002 exists to express) are:

| Weather Variable | Fixed unit (F2) | Open-Meteo param |
|---|---|---|
| Temperature / feels-like | °C | `temperature_unit=celsius` |
| Wind speed | mph | `wind_speed_unit=mph` |
| Wind direction | degrees + 8-point compass (e.g. "NW 315°") | — (derived from `wind_direction_10m`) |
| Humidity | % | — (native) |
| Precipitation | mm | `precipitation_unit=mm` |

*(These specific fixed units are a brainstorming outcome, listed here so the Plan has a concrete target; they are display-only and changing them later is an F4 concern, never a re-fetch.)*

### 4.4 The Weather Condition mapping (pure, in Core)

A pure function `(weather_code, is_day) → (category, label, iconKey)`:

- `weather_code` is Open-Meteo's integer **WMO** code; `is_day` is its `0/1` flag.
- The mapping groups WMO codes into human conditions — **Clear**, **Partly cloudy**, **Overcast**, **Fog**, **Drizzle/Rain**, **Snow**, **Thunderstorm**.
- **Only Clear and Partly cloudy fork on `is_day`**, producing `clear-day`/`clear-night` and `partly-cloudy-day`/`partly-cloudy-night`. Overcast, fog, rain, snow, and thunder render one key regardless of time of day.
- An **unrecognised code** maps to a defined fallback (a neutral label + icon key) — never throws.
- Core emits an **icon key** (a string), **never a glyph**. The `iconKey → emoji` lookup lives in the View (§4.5), keeping Core string-pure and trivially unit-testable.

### 4.5 The view and its state machine (ViewModel)

The Current Conditions ViewModel owns the fetch/refresh lifecycle and exposes one of four states to the bound XAML View:

| State | Entered when | View renders |
|---|---|---|
| **Loading** | first fetch in flight, nothing cached | inline loading indicator (story 33) |
| **Loaded** | any fetch succeeds | the seven Weather Variables; the Weather Condition glyph (View maps `iconKey`→emoji) + label; "Updated HH:MM" |
| **Couldn't update** | a refresh (manual or tick) fails *while a good reading exists* | the last Loaded view + a quiet, non-blocking "couldn't update" indicator; the timestamp still shows the last **successful** fetch |
| **Load failed** | the **first** fetch fails (nothing cached) | a dedicated friendly error + **Retry** action (stories 34, 36) |

Lifecycle rules:

- **Fetch on activation**, then **auto-refresh every 15 minutes** while the view is active.
- A **manual refresh** command is always available and **resets the 15-minute countdown** (so manual + tick never double-fire).
- The timer **starts on activation and is cancelled on deactivation/teardown**; the in-flight fetch is cancelled too — no orphaned timers, no fetch resolving against a dead view.
- **At most one fetch in flight** at a time.
- The displayed **timestamp always reflects the last *successful* fetch**, so its age stays truthful even after a failed tick.
- All of the above is `async`; the **UI thread never blocks** (Overriding Principle 2, story 35).

The 15-minute cadence matches Open-Meteo's own roughly-15-minute refresh of current-conditions data, so ticks pick up genuinely new readings rather than re-fetching identical data. Time and the timer are abstracted (e.g. `TimeProvider`) so the ViewModel's lifecycle is **deterministically unit-testable without real waiting** (Seam 3).

## 5. Seam inventory

The cross-module contracts this Feature relies on. Each carries a falsifiable contract and a real proof.

### Seam 1 — Open-Meteo `current` JSON → domain `CurrentConditions` *(headline)*

- **Class:** cross-process I/O + data-format (HTTP JSON → domain type). **External** — Open-Meteo is third-party and not under our control; its response shape can drift.
- **Boundary:** `IWeatherService.GetCurrentConditionsAsync(Location)` → HTTP GET to the Open-Meteo Forecast endpoint with a `current=` field set and the unit params of §4.3 → `System.Text.Json` deserialization → mapping to `CurrentConditions`.
- **Contract:** Given a Location (latitude, longitude), the request asks for `current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,precipitation,weather_code,is_day` plus the §4.3 unit params. The response's `current` object maps field-by-field to `CurrentConditions`; `weather_code` (int) + `is_day` (0/1) resolve via **Seam 2**; the `current.time` field becomes the reading's observation time. A transport error, non-success status, or undeserializable body maps to the **friendly domain-level failure** of §4.2 — never an unhandled exception to the UI. No API key is sent (Open-Meteo needs none — Overriding Principle 1).
- **(e) authority:** grounded against the **live Open-Meteo Forecast API docs** (`open-meteo.com/en/docs`) — the `current` parameter names, the unit query params (`temperature_unit`/`wind_speed_unit`/`precipitation_unit`), the WMO `weather_code` table, and `is_day` semantics — **not** model memory. There is no wire auth to pin. The *binding* authority is the live API itself, confirmed by Seam 1's end-to-end proof, so field names/shape are verified against the real service at test time.
- **Proof (falsifiable):**
  - **Unit (offline, deterministic):** representative `current` JSON fixtures (clear-day, clear-night, rain, snow, an unknown code, and a missing-field case) are fed through a **faked `HttpMessageHandler`** and asserted to map to the expected `CurrentConditions` (Overriding Principle 4). Transport/timeout/non-200/garbage-body fixtures assert the friendly-failure path.
  - **End-to-end (deliberate, live network, outside the gate):** one test in `WeatherPoC.EndToEnd` hits the **real** Open-Meteo endpoint for the hard-coded Location and asserts the response still deserializes into `CurrentConditions` with all requested fields present — this is what catches real wire drift, and is excluded from the deterministic unit/coverage gate so CI stays offline and stable.

### Seam 2 — `(weather_code, is_day)` → `(category, label, iconKey)` *(pure)*

- **Class:** pure function. **Internal** (Core only).
- **Boundary:** the Weather Condition mapping in `WeatherPoC.Core`.
- **Contract:** every WMO `weather_code` maps to exactly one `(category, label, iconKey)`. Codes `0` (clear) and `1,2` (mainly clear / partly cloudy) **fork on `is_day`** → `*-day`/`*-night` keys. Code `3` (overcast), `45,48` (fog), `51–67` + `80–82` (drizzle/rain), `71–77` + `85,86` (snow), `95–99` (thunderstorm) each map to a **single** key regardless of `is_day`. Any code outside the WMO set maps to a **defined fallback** (neutral label + key); the function never throws. The output is an icon **key**, never a glyph.
- **Proof:** pure unit tests — one per condition group, both forks of each day/night condition, and the unknown-code fallback; exhaustive over the WMO code set the API documents.

### Seam 3 — ViewModel state machine + auto-refresh lifecycle

- **Class:** in-process (ViewModel ↔ View binding + a timer). **Internal.** Concurrency-/lifetime-sensitive (Overriding Principle 2).
- **Boundary:** the Current Conditions ViewModel: activation → initial fetch + start 15-min timer; manual-refresh command; tick; deactivation → cancel timer + in-flight fetch. States and transitions per §4.5.
- **Contract:** on activation exactly one initial fetch runs and the timer starts; success → **Loaded** (timestamp = now), failure → **Load failed**. While Loaded, a failed refresh (manual or tick) → **Couldn't update** with the **timestamp unchanged** (last success); a successful refresh → **Loaded** (timestamp advanced). A manual refresh **resets** the countdown. Deactivation **cancels** the timer and the in-flight fetch — no further fetches occur. **At most one fetch is in flight** at any time. Nothing blocks the UI thread.
- **Proof:** behavioural unit tests over the ViewModel with a **faked `IWeatherService`** and an **abstracted time source** (`TimeProvider`), so ticks are driven deterministically with **no real waiting**: initial-success→Loaded; initial-failure→LoadFailed (+Retry re-fetches); Loaded→tick-failure→CouldntUpdate (timestamp pinned to last success); manual-refresh resets the timer; deactivate→timer cancelled (advancing virtual time fires no further fetch); overlapping triggers never produce two concurrent fetches.

### Seam 4 — Open-Meteo call logging → local Serilog file

- **Class:** cross-cutting diagnostic. **Internal** (`IWeatherService` ↔ the injected `ILogger`/Serilog).
- **Boundary:** every Open-Meteo call made by `IWeatherService` emits a structured log record.
- **Contract:** each call logs **endpoint, response status, and latency** (Technical-Context Instrumentation: "always logged, regardless of level"). Failures additionally log the raw detail (which never reaches the UI — story 36). **No telemetry leaves the machine** — this is the local Serilog rolling file only (stories 38–39; the functional weather request itself is the expected exception to local-only, per Technical-Context).
- **Proof:** unit tests with a faked logger assert a call record (endpoint + status + latency) is written on both the success and failure paths.

## 6. Acceptance criteria

1. For the hard-coded Location, the app renders temperature, feels-like, humidity, wind speed, wind direction, precipitation, and the Weather Condition as icon + label, each in the fixed unit of §4.3. *(stories 16–19)*
2. The Weather Condition glyph differs for day vs night on clear and partly-cloudy skies (driven by `is_day`) and is otherwise one glyph per condition; an unknown WMO code renders the defined fallback, not a crash (Seam 2).
3. First fetch shows a loading state; success shows the reading with an "Updated HH:MM" timestamp; a later failed refresh shows a non-blocking "couldn't update" indicator over the last good reading with the timestamp unchanged; a failed **first** fetch shows a friendly error + Retry (Seam 3). *(stories 33, 34, 36)*
4. The view auto-refreshes every 15 minutes and on a manual refresh command; manual refresh resets the countdown; the timer and any in-flight fetch are cancelled on teardown; the UI thread never blocks (Seam 3). *(stories 20, 21, 35; Principle 2)*
5. All Open-Meteo access goes through the typed `IWeatherService`; every call logs endpoint, status, and latency to the local Serilog file (Seam 4). *(Principle 3; stories 38–39)*
6. The `IWeatherService` impl, mappers, WMO mapping, `CurrentConditions`, and the ViewModel are **100% covered** by unit tests that **fake the provider** (faked `HttpMessageHandler`) and **never touch the network**; the coverage gate stays green and offline (Principles 4 & 5).
7. A separate `WeatherPoC.EndToEnd` test hits the **real** Open-Meteo endpoint and asserts the live `current` response deserializes into `CurrentConditions` (Seam 1), and is **not** part of the deterministic unit/coverage gate.
8. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41); the XAML View, HTTP/resilience registration, and hard-coded Location stay in the excluded app head.

## 7. Reconciliations with upstream artefacts

- **R1 — Auto-refresh vs Roadmap/PRD "refresh-on-demand" (brainstorming decision, 2026-06-16).** Roadmap F2 specified only "a refresh-on-demand action" and PRD **story 21** is on-demand refresh; the F2 brainstorming session added **automatic refresh every 15 minutes** (the Feature owner chose it over on-open-only and over manual-only). PRD **story 20** — "I want Current Conditions to reflect the present moment … a live reading rather than a stale snapshot" — is the product anchor that motivates it, so the addition is *grounded in*, not *contradictory to*, the PRD. Because the **Roadmap outranks the Spec** in the artefact authority order (the same situation spec 0001 handled in its R3), the higher-authority `Roadmap.md` F2 entry has been **amended** to record auto-refresh + the staleness/timestamp behaviour, rather than letting the Spec silently diverge. On-demand refresh (story 21) is **preserved** — the manual refresh command remains. Decision recorded by the Feature owner during the F2 brainstorming on 2026-06-16.
- **R2 — Fixed units vs the Unit Preferences machinery.** Roadmap F2 puts Unit Preferences out of scope ("a single fixed unit per measurement, with no per-measurement choice, CLDR defaults, or formatter yet"); ADR 0002 mandates CLDR-derived per-measurement defaults + a UnitsNet formatter. **No contradiction:** F2 requests fixed units directly from Open-Meteo and carries no formatter at all (§4.3); ADR 0002's resolver + formatter land in **Feature 4** and retrofit onto these same Weather Variables. F2 introduces **no** `RegionInfo.IsMetric` shortcut (the regression ADR 0002 guards against) — it simply hard-requests display units, leaving the locale logic entirely to F4.
- **R3 — No empty state in F2.** PRD story 6 and Roadmap F5 describe a "no Active Location" empty state that invites a Place Search. F2 has a **hard-coded** Location, so that empty state has nothing to invite into and is correctly **absent** here (Roadmap F2 lists "the empty state" as out of scope); it arrives with Place Search in Feature 5. F2's failure states are Load-failed and Couldn't-update only.
- **R4 — End-to-end suite now begins.** Spec 0001 deferred end-to-end testing ("the end-to-end suite arrives with real behaviour"). F2 is that first real behaviour, so it introduces the single live-Open-Meteo end-to-end test (Seam 1), satisfying Overriding Principle 4's "a separate end-to-end suite exercises the real Open-Meteo API deliberately" while keeping it out of the deterministic coverage gate.

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary: **Current Conditions**, **Weather Variable**, **Weather Condition**, **Measurement Unit**, **Location**, **Active Location** (governs test + type naming).
- `Technical-Context.MD` — **Overriding Principles 1–5** (no secrets / Open-Meteo needs none; UI thread never blocks; one typed client; unit tests fake the provider / E2E hits the real API; 100% gate with UI/wiring excluded), Frameworks (MAUI/.NET 10, MVVM), Packages (CommunityToolkit.Mvvm + .Maui, `IHttpClientFactory` + Microsoft.Extensions.Http.Resilience, System.Text.Json source-gen, Serilog, xUnit/Moq/AwesomeAssertions/coverlet), Instrumentation (every Open-Meteo call logged; local-only telemetry), User Feedback (inline states; friendly, no raw codes).
- `PRD.md` — stories 16–21 (Current Conditions + on-demand refresh), 20 (live reading — the auto-refresh anchor), 33–36 (loading/error/responsive/plain-language), 38–39 (local logs, no telemetry), 41 (macOS-viable); Implementation Decisions (typed `IWeatherService`, resilience, ViewModels own inline state); Testing Decisions (fake the provider, name tests in domain language).
- `Roadmap.md` — **Feature 2** entry (scope, out-of-scope, dependencies) — as amended by R1.
- `docs/adr/0002-per-measurement-unit-defaults.md` — for awareness; **not** implemented here (formatter/CLDR is Feature 4). No F2 decision may contradict it — §4.3 stays clear of `IsMetric`.
- `docs/adr/0001-location-detection-cascade.md` — for awareness only; the Location is hard-coded in F2 (detection is Features 5–6).
- `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` — the shell, coverage-gate, and project structure this Feature builds on.

## 9. Open questions / deferred to the Plan

- **Exact package versions** — CommunityToolkit.Mvvm, Microsoft.Extensions.Http.Resilience, System.Text.Json source-gen — pinned against the live feed at implementation time (as in spec 0001 §9).
- **Failure representation** — the precise `Result`/error type returned by `IWeatherService` (discriminated result vs nullable + error object) — a Plan/TDD detail; the contract is only §4.2 / Seam 1's "success → `CurrentConditions`, failure → user-safe message, no unhandled exception to the UI".
- **Resilience policy values** — retry count, timeout, circuit-breaker thresholds for the typed client — chosen at Plan time; the friendly-failure mapping fires only after the policy is exhausted.
- **The hard-coded Location constant** — which place + its coordinates — chosen at Plan time; it is the seam where Feature 5's resolved Active Location later plugs in.
- **`TimeProvider`/timer abstraction shape** — the exact mechanism for the deterministic, cancellable 15-min timer — a Plan/TDD detail; the contract is only Seam 3's lifecycle rules.
- **Confirm the §4.3 fixed-unit table** — the specific display unit per Weather Variable is a brainstorming outcome listed for the Plan; if the Feature owner wants different fixed units, they are display-only and trivially swapped.

## Feature-doc-gauntlet sign-off

- **Status:** Pending — runs on the Spec **and** the Plan together, after `/writing-plans` produces the Plan and before `/enate-to-stories`. Not yet run for Feature 2.
