# Spec — Feature 3: Daily Forecast 📅

**Feature:** 3 (Roadmap.md)
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Amended:** 2026-06-16 by the Feature 4 brainstorm — `DailyForecastDay` high/low are carried as **UnitsNet `Temperature?`** quantities (the canonical representation Feature 4's formatter converts from); until F4 lands the Daily Forecast VM formats them in **interim fixed °C**. See §7 **R5** and `docs/superpowers/specs/0004-per-measurement-unit-preferences.md` §7 R1.
**Depends on:** Feature 2 — the typed `IWeatherService`, the `(weather_code, is_day) → (category, label, iconKey)` WMO mapping, the `Result<T>` friendly-failure contract, and the ViewModel loading/loaded/stale/error state machine + 15-min auto-refresh. **As amended by this Feature's brainstorm** (see §7 R1): F2 is reshaped to the combined `GetWeatherAsync` / `WeatherSnapshot` surface with a shell ViewModel owning the fetch, so F3 is purely additive.
**Downstream:** Feature 4 (Unit Preferences) retrofits the formatter onto the high/low temperatures shown here; Feature 5 (Place Search + Saved Location) replaces the hard-coded Location feeding the combined fetch with the resolved Active Location.

---

## 1. Intent

Below Current Conditions, for the **same single hard-coded Location**, show the **Daily Forecast** — **today plus the next 6 days** (7 in total), each day summarised as a **high/low temperature** and an **overall Weather Condition** rendered as an icon and label. The first day is **today**, deliberately overlapping Current Conditions at a different granularity: the live "now" reading sits above, today's strip cell shows the day's high/low **range** — complementary, not contradictory (PRD *Further Notes*, stories 22–25).

Per the brainstorm's keystone decision, the forecast is fetched in the **same Open-Meteo request** as Current Conditions — one HTTP GET carrying both `current=` and `daily=` blocks — so today's high/low and the live reading are read from the **same instant** and cannot drift. This makes F3 the moment the **shell ViewModel** the PRD calls for emerges: one fetch, one 15-min refresh timer, one loading/loaded/stale/error state machine, feeding **two** presentation sections (Current Conditions and the Daily Forecast).

The scary unknown this Feature de-risks is the **daily wire shape** — Open-Meteo's `daily` block is **parallel arrays** that must be zipped by index, in the Location's timezone, with nullable elements — and the **cross-timezone day-labeling** trap (the hard-coded Location may sit in a different timezone than the device). The well-trodden parts — reusing F2's WMO mapping and rendering a 7-cell strip — stay thin.

## 2. Goals — what "done" proves

1. For the hard-coded Location, the combined fetch returns **7 days** (today + 6) and the view renders each day's **high/low temperature** (°C) and **Weather Condition** as icon + label (stories 22, 23, 25).
2. The forecast is fetched in the **same HTTP request** as Current Conditions (`current=` + `daily=` + `forecast_days=7` + `timezone=auto`); today's high/low and the live reading come from one snapshot, so they are mutually consistent (§4.2, Seam 1; PRD *Further Notes* "today appears twice").
3. Each forecast day's Weather Condition reuses F2's **pure WMO mapping**, called with **`is_day = day`** (a day-summary has no `is_day` and always reads as daytime), so a forecast day's condition renders the same way as the live one (§4.5, Seam 2).
4. Day labels read **"Today" → "Tomorrow" → short weekday names**, assigned **by array index** (not by re-deriving from the device clock), so labeling stays correct when the Location's timezone differs from the device's (§4.6, Seam 4).
5. A failed refresh keeps the **last good forecast** behind the same single "couldn't update" indicator that covers Current Conditions; a failed **first** fetch shows the whole-screen load-failed + Retry; the timer + in-flight fetch cancel on teardown; the UI thread never blocks (§4.6, Seam 3; stories 33, 34, 36; Overriding Principle 2).
6. The new domain surface (the `daily` DTOs + parallel-array mapper, the `DailyForecast` types, the daily-condition reuse, the Daily Forecast ViewModel incl. the day-label logic, and the shell VM's handling of the daily section) is **100% unit-tested with the provider faked** (Overriding Principles 4 & 5); the **end-to-end test** is extended to prove the live `daily` block deserializes (Seam 1) and stays **outside** the deterministic unit/coverage gate.

## 3. Non-goals / out of scope

Per Roadmap Feature 3 and the PRD:

- **An hourly forecast.** One summary per day only; there is no hour-by-hour view (and never, per the PRD *Out of Scope*).
- **Any Weather Variable beyond high/low + the Weather Condition.** No precipitation probability, precipitation amount, wind, sunrise/sunset, or UV per day — explicitly confirmed at brainstorm (strict YAGNI, matches story 23). Adding any later is an additive change to the `daily=` field set + the day cell, not a rework.
- **Unit Preferences / the formatter / CLDR defaults.** High/low temperatures are shown in the **same fixed °C** F2 requests directly from Open-Meteo (§4.3 of F2); the per-measurement choice, CLDR locale defaults, and the Weather Variable formatter are **Feature 4** (ADR 0002). F3 introduces **no** conversion layer and **no** `RegionInfo.IsMetric` shortcut.
- **Location detection, Place Search, Saved Location.** The Location stays the single hard-coded constant (Features 5–6). There is therefore still **no "no Active Location" empty state** here.
- **Release signing / installer packaging.** Unchanged from Features 1–2; still deferred.

## 4. Design

### 4.1 Where the code lives (coverage map)

Feature 1's four-project structure and the F2 gate line carry over. F3 adds code on both sides of the line; **all** of F3's new logic except the XAML strip is gated Core:

| Lands in | Project | Coverage | What |
|---|---|---|---|
| `WeatherPoC.Core` (`net10.0`, gated) | `DailyForecast` + `DailyForecastDay` domain types; the `daily` response DTOs + the **parallel-array → `DailyForecast` mapper**; the daily-condition reuse (calling F2's WMO mapping with `is_day = day`); the **Daily Forecast ViewModel** incl. the **day-label logic**; the **shell ViewModel** extension that exposes the daily section; the `daily=` + `forecast_days` + `timezone` additions to the request the typed client builds | **100% gated** | the real domain + presentation logic |
| `WeatherPoC` (app head, excluded) | the XAML **7-cell strip** View (bindings + the reused `iconKey → emoji` glyph lookup from F2) | `[ExcludeFromCodeCoverage]` (untestable UI) | thin binding |
| `WeatherPoC.Tests` (`net10.0`, not measured) | unit tests with a **faked `HttpMessageHandler`** fed **daily JSON fixtures captured from a real Open-Meteo response** | n/a | offline, deterministic |
| `WeatherPoC.EndToEnd` (not measured, not in the gate) | the existing live-Open-Meteo test **extended** to assert the `daily` block deserializes for the hard-coded Location | n/a | proves Seam 1's live wire |

`WeatherPoC.Core` stays plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41).

### 4.2 The combined fetch (one request, both blocks)

Per the brainstorm keystone decision, the typed `IWeatherService` exposes the **single combined method** F2 is amended to (§7 R1):

```
Task<Result<WeatherSnapshot>> GetWeatherAsync(Location location, CancellationToken ct)
```

```
WeatherSnapshot { CurrentConditions Current; DailyForecast Daily; }   // F2 lands Current; F3 lands Daily
```

One HTTP GET to the Open-Meteo Forecast endpoint carries **both** blocks plus the new parameters F3 adds:

- `current=…` — F2's eight fields (unchanged).
- `daily=weather_code,temperature_2m_max,temperature_2m_min` — **new in F3**.
- `forecast_days=7` — **new in F3** (today + 6).
- `timezone=auto` — present from the F2 amendment; **load-bearing for F3**: Open-Meteo aggregates each `daily` value over the **Location's local day** and timestamps `daily.time`/`current.time` in that timezone. Without it the daily block is bucketed by **GMT**, so "today" (index 0) can be the wrong calendar day for a non-GMT Location.
- the F2 unit params (`temperature_unit=celsius`, …) — unchanged; the high/low arrive already in °C, so F3 still carries **no** conversion layer.

Same `Result<T>` contract as F2: success → `WeatherSnapshot` (now with `Daily` populated), failure → user-safe message, never an unhandled exception to the UI; the single call is logged (endpoint, status, latency) exactly once via F2's Seam 4 (unchanged — one call still serves both sections).

### 4.3 Domain types

```
DailyForecast    { IReadOnlyList<DailyForecastDay> Days; }            // exactly 7, index 0 = the Location's today
DailyForecastDay { DateOnly Date; Temperature? High; Temperature? Low; WeatherCondition Condition; }
```

- `High`/`Low` are **nullable `Temperature`** (UnitsNet quantities, per §7 R5) to honour Open-Meteo's nullable daily elements (§4.4); a null renders as "—", never a crash.
- `Condition` is the **same `(category, label, iconKey)` Weather Condition value** F2's WMO mapping yields — reused, not redefined (§4.5).
- High/low are carried as **canonical `Temperature` quantities**; until **Feature 4** lands they are formatted in **fixed °C** (matching F2 §4.3). Feature 4's formatter then converts them to the User's *effective* unit **losslessly, never a re-fetch** (§7 R5).

### 4.4 The daily mapping (parallel arrays, in Core)

Open-Meteo's `daily` block is **parallel arrays** — `daily.time[]`, `daily.weather_code[]`, `daily.temperature_2m_max[]`, `daily.temperature_2m_min[]` — that the mapper **zips by index** into the 7 `DailyForecastDay` records, **index 0 = today** (in the Location's timezone, per `timezone=auto`).

- **`daily.time[]`** entries are **ISO-8601 date strings** (`YYYY-MM-DD`) → parsed to `DateOnly`.
- **Length invariant:** all four arrays have equal length = `forecast_days` = **7**. A missing `daily` object, a missing array, or arrays of **unequal** length / length ≠ 7 maps to the **friendly domain-level failure** of §4.2 (the same failure path as F2's Seam 1).
- **Nullability:** an individual element of `weather_code[]`/`temperature_2m_max[]`/`temperature_2m_min[]` **may be null**; a null maps to an absent field on that `DailyForecastDay` (rendered "—"), and the day's other fields still render — never a throw, never the whole-screen failure.

### 4.5 The daily Weather Condition (pure reuse of Seam 2)

A forecast day's condition reuses F2's pure `(weather_code, is_day) → (category, label, iconKey)` mapping **unchanged**, called with **`is_day = day`** for every forecast day. Rationale: the daily `weather_code` is a **whole-day aggregate** with no `is_day` flag, and a day-summary always reads as daytime. So clear/partly-cloudy forecast days always get the `*-day` glyph (never `*-night`); all other conditions render their single key, and an unrecognised code falls back exactly as F2 defines. The View reuses F2's `iconKey → emoji` lookup, so a forecast day's condition renders identically to the live one (story 25). No new mapping logic is introduced.

### 4.6 ViewModel structure — the shell VM and the shared state machine

F3 is where the second display section appears, so the **shell ViewModel** the PRD calls for emerges here (the F2 amendment introduces it; F3 extends it):

- The **shell ViewModel** owns the **single combined fetch**, the **15-min auto-refresh timer**, and the **loading / loaded / couldn't-update / load-failed** state machine — lifted out of F2's Current Conditions ViewModel.
- The **Current Conditions ViewModel** and the **new Daily Forecast ViewModel** are **presentation-only**, both populated from the one `WeatherSnapshot`.

Because there is **one** fetch and **one** state machine, both sections move together:

| State | Entered when | Current Conditions section | Daily Forecast section |
|---|---|---|---|
| **Loading** | first fetch in flight, nothing cached | inline loading | inline loading |
| **Loaded** | any fetch succeeds | the seven Weather Variables + "Updated HH:MM" | the 7-day strip |
| **Couldn't update** | a refresh (manual or tick) fails while a good snapshot exists | last-good reading + quiet "couldn't update"; timestamp pinned to last success | last-good strip (held, not blanked) |
| **Load failed** | the **first** fetch fails (nothing cached) | whole-screen friendly error + **Retry** | (covered by the whole-screen error) |

All F2 lifecycle rules carry over to the shell VM unchanged: fetch on activation; auto-refresh every 15 min; manual refresh resets the countdown; timer + in-flight fetch cancelled on deactivation; at most one fetch in flight; timestamp = last **successful** fetch; nothing blocks the UI thread; time/timer abstracted (`TimeProvider`) for deterministic tests (Overriding Principle 2; Seam 3).

The **Daily Forecast ViewModel** additionally computes each day's **label** (§4.6.1) and exposes the per-day `High`/`Low`/`Condition` for binding.

#### 4.6.1 Day labels by index, not by device clock

The Daily Forecast VM assigns labels **by array position**: index 0 → **"Today"**, index 1 → **"Tomorrow"**, indices 2–6 → the **short weekday name** derived from that day's `Date` via the device culture (e.g. "Wed", "Thu"). It does **not** decide "Today" by comparing each `Date` to the device's current date — because the daily block is bucketed in the **Location's** timezone (`timezone=auto`), which may differ from the **device's**, so a date-comparison against the device clock can mislabel the boundary day for a non-local hard-coded Location. Index 0 **is** the Location's today by construction; labeling by position is the correct, timezone-safe rule (Seam 4).

### 4.7 The view (7-cell strip)

Below the F2 Current Conditions panel, a **horizontal 7-cell strip** (desktop-window-friendly). Each cell binds: the **day label** (§4.6.1) · the **Weather Condition glyph** (reused `iconKey → emoji`) + label · the **H / L** in °C ("—" when null). Today's cell carries the **"Today"** label and the day's H/L **range**, so the live reading above reads as a point *inside* today's range rather than a competing number (PRD *Further Notes*). The strip lives in the excluded app head and is thin declarative binding.

## 5. Seam inventory

The cross-boundary contracts this Feature crosses. Each carries a falsifiable contract (incl. data shape + nullability) and a real proof. Two contracts are **inherited from F2 unchanged** and are referenced, not re-proven: the **combined-request envelope** is F2's amended Seam 1 (§7 R1), and **Open-Meteo call logging** is F2's Seam 4 (one combined call still logs endpoint/status/latency exactly once).

### Seam 1 — Open-Meteo `daily` block → domain `DailyForecast` *(headline)*

- **(a) class:** cross-process I/O + network-protocol, data-format facet (HTTP JSON → domain type). **External** — Open-Meteo is third-party; its response shape can drift.
- **(b) sides:** the `IWeatherService` implementation ↔ the Open-Meteo Forecast API.
- **(c) contract:** the single combined GET adds `daily=weather_code,temperature_2m_max,temperature_2m_min` + `forecast_days=7` + `timezone=auto`. The response `daily` object is **four parallel arrays** — `time[]` (ISO-8601 `YYYY-MM-DD` strings), `weather_code[]` (int, WMO), `temperature_2m_max[]` (number, °C), `temperature_2m_min[]` (number, °C) — **all of equal length = 7**, zipped **by index** into 7 `DailyForecastDay` (the max/min numbers **wrapped into `Temperature?`** quantities per §7 R5), **index 0 = the Location's today** (in the `timezone=auto` zone). **Nullability:** an individual element of `weather_code[]`/`max[]`/`min[]` **may be null** → the affected field on that day becomes absent (rendered "—"), other fields still render, no throw; a **missing `daily` object, missing array, or unequal/≠7 lengths** → the **friendly domain-level failure** (no unhandled exception to the UI). `weather_code` resolves to a Weather Condition via **Seam 2**. No API key is sent.
- **(d) proof:** **Unit (offline, deterministic):** `daily` JSON fixtures **captured from a real Open-Meteo response** (a normal 7-day week; a day with a null `temperature_2m_max`; an unknown `weather_code`; and a malformed block with unequal array lengths) fed through a **faked `HttpMessageHandler`** and asserted to map to the expected `DailyForecast` / friendly-failure. A **round-trip** assertion confirms the real captured payload parses to the expected day records, including the null and length-mismatch cases. **End-to-end (live network, outside the gate):** the existing `WeatherPoC.EndToEnd` test is extended to hit the **real** endpoint and assert the `daily` block deserializes into 7 `DailyForecastDay` with `time`/`weather_code`/`max`/`min` present — this is what catches real wire drift.
- **(e) authority:** the **live Open-Meteo Forecast API** (`api.open-meteo.com/v1/forecast`; docs `open-meteo.com/en/docs`) — the `daily` variable names, `forecast_days`, `timezone=auto` day-bucketing semantics, the parallel-array response shape, and the WMO `weather_code` table. **Auth method:** inherited from F2's first contact with Open-Meteo — the service is **keyless** (no API key, no wire auth; Overriding Principle 1); F3 introduces no new auth and re-confirms none is required. **Grounding note (confirmed 2026-06-16):** live grounding **was** performed against `api.open-meteo.com/v1/forecast` — egress is now open, superseding the prior brainstorm session where the allowlist blocked the host. A real combined GET (`current=…&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=7&timezone=auto&temperature_unit=celsius`, no API key, representative coordinates — the hard-coded Location is a Plan-time detail) returned **HTTP 200** and verified the full contract: the `daily` object is **four parallel arrays** (`time[]` ISO-8601 `YYYY-MM-DD`, `weather_code[]` int, `temperature_2m_max[]`/`temperature_2m_min[]` °C), **all of length 7**, with **`time[0]` = the Location's today** under `timezone=auto` (the response carried `timezone:"Europe/Berlin"`, `utc_offset_seconds:7200`, confirming day-bucketing in the Location's zone); `daily_units` reported `°C` and `wmo code`, the observed `weather_code` values sit in the documented WMO table, and **no API key** was sent (keyless re-confirmed, Overriding Principle 1). `open-meteo.com/en/docs` is also reachable (200), no longer 403. The contract no longer rests on F2's prior grounding alone. The **binding proof remains the end-to-end test** (live network, outside the gate), and the offline fixtures must still be **captured from a real Open-Meteo response** at implementation time — including the null-element and unequal-length cases, which a normal live response does not exhibit — never hand-invented (re-encoding an unchecked assumption is exactly what (d) forbids).

### Seam 2 — daily `weather_code` → `(category, label, iconKey)` via reused WMO mapping *(pure)*

- **(a) class:** pure function. **Internal** (Core only) — reuse of F2's Seam 2.
- **(b) sides:** the daily mapper ↔ F2's `(weather_code, is_day) → (category, label, iconKey)` mapping.
- **(c) contract:** every forecast day calls the **unchanged** F2 mapping with **`is_day = day`**. Therefore clear (`0`) and mainly-clear/partly-cloudy (`1`,`2`) forecast days resolve to the **`*-day`** keys **only** (never `*-night`); all other WMO groups resolve to their single key; an unrecognised code resolves to F2's defined fallback; the function never throws and emits an icon **key**, never a glyph. A null `weather_code[i]` (Seam 1) is **not** passed to the mapping — that day's condition is absent.
- **(d) proof:** pure unit tests: a clear and a partly-cloudy forecast day both yield the **`*-day`** key (asserting the `is_day = day` wiring); representative other groups map to their single key; an unknown code yields the fallback. (F2's exhaustive WMO-table tests are not duplicated — F3 only proves the `is_day = day` call-site wiring.)

### Seam 3 — shell ViewModel state machine + auto-refresh, now driving two sections

- **(a) class:** in-process (shell VM ↔ two presentation VMs ↔ View binding + a timer). **Internal.** Concurrency-/lifetime-sensitive (Overriding Principle 2).
- **(b) sides:** the shell ViewModel ↔ the Current Conditions VM and the Daily Forecast VM (and the bound View).
- **(c) contract:** one combined fetch populates **both** sections from one `WeatherSnapshot`. On activation exactly one fetch runs and the timer starts; success → **Loaded** (both sections render; timestamp = now), first-fetch failure → **Load failed** (whole screen). While Loaded, a failed refresh → **Couldn't update** with **both** sections holding their last-good values and the timestamp **pinned to last success**; a successful refresh advances both. Manual refresh **resets** the countdown; deactivation **cancels** timer + in-flight fetch; **at most one fetch in flight**; nothing blocks the UI thread.
- **(d) proof:** behavioural unit tests over the shell VM with a **faked `IWeatherService`** and an **abstracted `TimeProvider`** (no real waiting): initial-success → both sections Loaded; initial-failure → LoadFailed (Retry re-fetches); Loaded → tick-failure → CouldntUpdate with **the daily strip held** and timestamp pinned; successful tick advances both; manual refresh resets the timer; deactivate → advancing virtual time fires no further fetch; overlapping triggers never produce two concurrent fetches.

### Seam 4 — day labeling by array index, not by device clock *(timezone-safe)*

- **(a) class:** host-OS / runtime (device clock + timezone + locale). **Internal.**
- **(b) sides:** the Daily Forecast ViewModel ↔ the runtime clock/timezone and the device culture.
- **(c) contract:** labels are assigned **by array index** — index 0 → **"Today"**, index 1 → **"Tomorrow"**, indices 2–6 → the **short weekday name** of that day's `Date` from the device `CultureInfo`. The label for index 0 is "Today" **regardless of the device's current date**, because the `daily` block is bucketed in the Location's timezone (Seam 1) which may differ from the device timezone; the VM does **not** compute "Today" by comparing `Date` to the device clock. Weekday names are **locale-dependent** (the device culture); "Today"/"Tomorrow" are fixed strings.
- **(d) proof:** pure unit tests on the VM's label logic: index 0 → "Today" and index 1 → "Tomorrow" **even when the injected device date differs from the day's `Date`** (the cross-timezone case); indices 2–6 → the expected weekday name for a known `Date`; a fixture where the Location-timezone date ≠ device date confirms index-based labeling does not drift.

## 6. Acceptance criteria

1. For the hard-coded Location, the app renders a **7-day** strip below Current Conditions; each day shows **H / L in °C** ("—" if null) and the **Weather Condition** as icon + label (stories 22, 23, 25).
2. The forecast and Current Conditions come from **one** HTTP request (`current=` + `daily=` + `forecast_days=7` + `timezone=auto`); today's strip cell and the live reading are mutually consistent (Seam 1; PRD *Further Notes*).
3. A forecast day's condition reuses F2's WMO mapping with **`is_day = day`** — clear/partly-cloudy days show the **day** glyph; an unknown code shows the fallback, not a crash (Seam 2).
4. Day labels read **"Today" / "Tomorrow" / weekday**, assigned by **index**; index 0 stays "Today" even when the Location's timezone puts it on a different calendar date than the device (Seam 4).
5. A failed refresh **holds** the last-good forecast behind the single "couldn't update" indicator (timestamp unchanged); a failed **first** fetch shows the whole-screen error + Retry; timer + in-flight fetch cancel on teardown; the UI thread never blocks (Seam 3; stories 33, 34, 36; Principle 2).
6. The `daily` DTOs + parallel-array mapper, the `DailyForecast` types, the daily-condition reuse, the Daily Forecast VM (incl. day labels), and the shell VM's daily handling are **100% covered** by unit tests that **fake the provider** and **never touch the network** (Principles 4 & 5).
7. The `WeatherPoC.EndToEnd` test is extended to hit the **real** Open-Meteo endpoint and assert the live `daily` block deserializes into 7 `DailyForecastDay` (Seam 1), and is **not** part of the deterministic unit/coverage gate.
8. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41); the XAML strip stays in the excluded app head.

## 7. Reconciliations with upstream artefacts

- **R1 — F2 spec amended to be combined-ready (brainstorming decision, 2026-06-16).** F3's keystone decision is a **combined single fetch** (current + daily in one Open-Meteo request), chosen so today's high/low and the live reading cannot drift (the PRD *Further Notes* "today appears twice, complementary not contradictory" concern). Because Feature 2 is **spec-only, not yet coded**, the Feature owner chose to **amend F2's spec now** (over letting F3 retrofit F2's code later) so F2 is built combined-ready and F3 is purely additive. Accordingly `docs/superpowers/specs/0002-live-current-conditions.md` is amended in this same change to: (1) the combined `GetWeatherAsync(Location, ct) → Result<WeatherSnapshot>` surface (F2 lands `WeatherSnapshot.Current`; F3 lands `.Daily`); (2) a **shell ViewModel** owning the fetch/timer/state machine, with the Current Conditions VM becoming presentation-only; (3) `timezone=auto` on the request (which also corrects F2's "Updated HH:MM" to the Location's local time). F2's amendment carries the matching note (its R5). The Roadmap's F2/F3 entries are unaffected — the combined fetch is an implementation shape, not a scope change.
- **R2 — High/low + condition only (brainstorming decision, 2026-06-16).** Roadmap F3 and PRD story 23 specify "a high and low temperature plus an overall Weather Condition." The Feature owner confirmed **strict adherence** — no precipitation probability/amount, wind, sunrise/sunset, or UV per day — over extending scope. This is the YAGNI default, so there is **no** divergence to reconcile; recorded only because the option to extend (as F2 did for auto-refresh) was explicitly declined.
- **R3 — Fixed °C, no formatter (consistent with F2 R2 and ADR 0002).** High/low are requested directly in °C via Open-Meteo's `temperature_unit` (F2 §4.3), so F3 carries **no** conversion/formatting layer and **no** `RegionInfo.IsMetric` shortcut. ADR 0002's CLDR resolver + UnitsNet formatter land in **Feature 4** and retrofit onto these same high/low values — additive, not a rewrite. No contradiction with ADR 0002.
- **R4 — Still no empty state in F3 (consistent with F2 R3).** PRD story 6 / Roadmap F5's "no Active Location" empty state needs Place Search to invite into; the Location is still hard-coded here, so that state remains correctly **absent** (it arrives in Feature 5). F3's non-Loaded states stay Load-failed and Couldn't-update, now covering both sections.
- **R5 — Amended to carry `Temperature?` quantities (Feature 4 brainstorm, 2026-06-16).** Feature 4 needs a **canonical representation** its formatter converts from **losslessly without re-fetching** (ADR 0002). Because F3 is **spec-only (not yet coded)**, the Feature owner chose to amend this spec **now** so `DailyForecastDay` is built **quantity-native** rather than having F4 rework `double?` fields. Delta: `HighC`/`LowC` (`double?`) → `High`/`Low` (`Temperature?`); the parallel-array mapper wraps `temperature_2m_max[]`/`temperature_2m_min[]` into `Temperature?` (§4.4, Seam 1), preserving the nullability contract (a null element → an absent `Temperature?` → "—"). **No F3 scope change** — high/low are still **displayed in fixed °C** until F4 (now as interim formatting of a quantity); the per-measurement choice + formatter are **Feature 4**, which retrofits onto these same high/low values (mirrors F2's R6). Cross-referenced from `docs/superpowers/specs/0004-per-measurement-unit-preferences.md` §7 R1.

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary: **Daily Forecast**, **Weather Condition**, **Weather Variable**, **Measurement Unit**, **Current Conditions**, **Location**, **Active Location** (governs test + type naming; the today-overlap is defined under Daily Forecast and Current Conditions).
- `Technical-Context.MD` — **Overriding Principles 1–5** (Open-Meteo keyless; UI thread never blocks; one typed client; unit tests fake the provider / E2E hits the real API; 100% gate with UI/wiring excluded), Frameworks (MAUI/.NET 10, MVVM), Packages (CommunityToolkit.Mvvm, `IHttpClientFactory` + Microsoft.Extensions.Http.Resilience, System.Text.Json source-gen, Serilog, xUnit/Moq/AwesomeAssertions/coverlet), Instrumentation (every Open-Meteo call logged; local-only telemetry), User Feedback (inline states; friendly, no raw codes).
- `PRD.md` — stories 22–25 (Daily Forecast + the today-overlap), 33–36 (loading/error/responsive/plain-language), 41 (macOS-viable); *Implementation Decisions* (shell ViewModel drives the fetch; dedicated VMs back Current Conditions and the Daily Forecast; typed `IWeatherService`); *Further Notes* ("Today appears twice, by design"); *Testing Decisions* (fake the provider, name tests in domain language).
- `Roadmap.md` — **Feature 3** entry (scope, out-of-scope, dependency on F2's `IWeatherService` + WMO mapping).
- `docs/adr/0002-per-measurement-unit-defaults.md` — for awareness; **not** implemented here (formatter/CLDR is Feature 4). No F3 decision contradicts it — §4.3 stays clear of `IsMetric`.
- `docs/adr/0001-location-detection-cascade.md` — for awareness only; the Location is hard-coded in F3 (detection is Features 5–6).
- `docs/superpowers/specs/0002-live-current-conditions.md` — the typed `IWeatherService`, the WMO mapping (Seam 2), the `Result<T>` contract, and the shell VM / state machine F3 extends — **as amended by R1**.
- `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` — the shell, coverage-gate, and project structure this Feature builds on.

## 9. Open questions / deferred to the Plan

- **`WeatherSnapshot` / `DailyForecast` exact type shapes** — record vs class, collection type — a Plan/TDD detail; the contract is only §4.3 and Seam 1 (7 days, nullable high/low, reused Weather Condition value).
- **Null-element rendering string** — "—" is the working choice; the exact glyph/placeholder is a Plan/UI detail. The contract is only "a null daily element renders as unavailable, never a crash" (Seam 1).
- **Strip orientation/styling specifics** — the horizontal 7-cell strip is the agreed layout; exact spacing/typography is a Plan/View detail (excluded app head).
- **Captured fixture provenance** — the offline `daily` fixtures must be captured from a real Open-Meteo response at implementation time (where egress is open); which Location/day they are captured from is a Plan/TDD detail.
- **Package versions** — pinned against the live feed at implementation time, as in specs 0001/0002.

## Feature-doc-gauntlet sign-off

- **Status:** Pending — runs on the Spec **and** the Plan together, after `/writing-plans` produces the Plan and before `/enate-to-stories`. Not yet run for Feature 3.
