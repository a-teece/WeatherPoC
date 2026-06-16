# Spec — Feature 4: Per-measurement Unit Preferences 🌡️

**Feature:** 4 (Roadmap.md)
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Depends on:** Features 2 and 3 — the typed `IWeatherService` combined `GetWeatherAsync` / `WeatherSnapshot` surface, the `CurrentConditions` and `DailyForecast` domain types, and the shell + presentation ViewModels. **As amended by this Feature's brainstorm** (see §7 R1): F2 and F3 are reshaped to carry the Weather Variables as **UnitsNet quantity types** (the canonical representation this Feature formats from), so F4's formatter is a clean additive retrofit rather than a value-representation rewrite.
**Downstream:** Feature 5 (Place Search + Saved Location) reuses the **MAUI-`Preferences`-behind-an-interface** persistence pattern this Feature establishes for its Saved Location store.

---

## 1. Intent

Every numeric Weather Variable the User chooses a unit for — **temperature** (current, feels-like, and the Daily Forecast high/low), **wind speed**, and **precipitation** — becomes displayed in a **Measurement Unit the User picks independently per kind of measurement**. Defaults are **derived from the device locale** via the Unicode CLDR `unitPreferenceData` (`weather`/`wind`/`rainfall` usages) per **ADR 0002**, so a UK User starts with **°C *and* mph *and* mm** — the mixed convention `RegionInfo.IsMetric` (a single boolean) cannot express. A **dedicated Settings page** lets the User override any single unit without disturbing the others, and those overrides **persist across restarts**. Changing a unit is **purely a display concern**: it re-renders the held reading **instantly and losslessly**, **never re-fetching** and never mutating the underlying value (PRD stories 26–32; ADR 0002).

This Feature lands four cooperating pieces and retrofits the two display surfaces:

1. the **embedded CLDR `unitPreferenceData` slice** + the pure **Locale unit-default resolver** (region → default unit; the guardrail against the `IsMetric` regression);
2. the pure **Weather Variable formatter** (canonical quantity → chosen unit → localized string, via UnitsNet);
3. the **Unit Preferences store** (per-measurement overrides, layered on top of the CLDR defaults, persisted via MAUI `Preferences`);
4. the **Settings page + `SettingsViewModel`**; and
5. the **retrofit** of the Current Conditions and Daily Forecast presentation ViewModels to render through the formatter and **re-render on a preference change without re-fetching**.

The scary unknown this Feature de-risks is the **defaults-routing contract** — that the locale → unit mapping is the *CLDR* one (mixed-convention-correct: UK = °C + mph), **not** the `RegionInfo.IsMetric` regression ADR 0002 exists to forbid — and the **lossless, no-re-fetch re-render** (a unit change must reformat the *held* canonical reading, never trigger a network call). The well-trodden parts — a settings form of pickers, binding strings — stay thin.

## 2. Goals — what "done" proves

1. Temperature (current + feels-like + Daily Forecast high/low), wind speed, and precipitation each render in the **User's chosen Measurement Unit**, picked **independently** per measurement (stories 26, 29). Humidity (%) and wind direction (degrees + compass) are **not** user-choosable and are unchanged.
2. Out of the box, with **no configuration**, units come from the **device locale** via the embedded CLDR slice: **GB → °C + mph + mm**, **US → °F + mph + in**, an **unmapped region → world (001) defaults °C + km/h + mm** (stories 27, 28; §4.3, Seam 3). The resolver **never** falls back to `RegionInfo.IsMetric` (the ADR 0002 guardrail).
3. The Settings page offers, per measurement, the option lists **temperature {°C, °F}**, **wind speed {mph, km/h, m/s}**, **precipitation {mm, in}**, and overriding one **does not disturb the others** (stories 29, 32; §4.6).
4. Overrides **persist across restarts**; clearing an override **reverts** that measurement to its CLDR default (story 30; §4.5, Seam 4).
5. Changing a unit **re-renders the held reading instantly and losslessly** — the displayed string changes, the underlying canonical quantity is unchanged, and **`IWeatherService` is not called again** (stories 31, 35; §4.7, Seam 1). Switching back and forth is lossless.
6. The new surface (resolver, formatter, store layering logic, `SettingsViewModel`, and the retrofitted presentation VMs) is **100% unit-tested with the platform/provider faked** (Overriding Principles 4 & 5). The Settings XAML page and the concrete MAUI-`Preferences`-backed store stay in the **coverage-excluded app head**.

## 3. Non-goals / out of scope

Per Roadmap Feature 4, the PRD, and ADR 0002:

- **A bundled metric/imperial "unit system" toggle** — explicitly *not* built. Units are chosen **per measurement** (ADR 0002; PRD *Out of Scope*). There is no single switch.
- **A unit choice for humidity or wind direction** — humidity is always **%**, wind direction always **degrees + compass**; the glossary lists only temperature, wind speed, and precipitation as Measurement-Unit-bearing (Context.MD; story 32). Neither gets a picker.
- **Re-fetching on a unit change** — forbidden by ADR 0002. The formatter converts the **held** canonical quantity; the network is never touched by a unit change (§4.7).
- **`Porticle.CLDR.Units`** — the ADR-0002 spike (resolved here, §7 R2) found it is **formatting-only** with **no `unitPreferenceData` routing API**, so it is **dropped**; the small CLDR slice is embedded and **UnitsNet** does conversion + localized formatting.
- **Location detection, Place Search, Saved Location** — units and location are orthogonal (Roadmap F4 "Independent of location"). The Location stays the single hard-coded constant (Features 5–6); this Feature touches no location code.
- **Release signing / installer packaging** — unchanged from Features 1–3; still deferred.

## 4. Design

### 4.1 Where the code lives (coverage map)

Feature 1's four-project structure and the gate line carry over. F4 adds code on both sides of the line; **all** of F4's new logic except the Settings XAML page and the concrete MAUI-backed store is gated Core:

| Lands in | Project | Coverage | What |
|---|---|---|---|
| `WeatherPoC.Core` (`net10.0`, gated) | the **embedded CLDR slice** + the pure **Locale unit-default resolver**; the pure **Weather Variable formatter** (over UnitsNet); the **effective-unit resolution** (`override ?? default`); the **`IUnitPreferencesStore` interface** + the **layering logic**; the **`SettingsViewModel`**; the **retrofit** of the Current Conditions + Daily Forecast presentation VMs to format via the formatter and react to the store's `Changed` event | **100% gated** | the real domain + presentation logic |
| `WeatherPoC` (app head, excluded) | the **Settings XAML page** (pickers + bindings), the **gear/Settings nav** entry, the DI registration, and the **concrete MAUI-`Preferences`-backed `IUnitPreferencesStore`** | `[ExcludeFromCodeCoverage]` (untestable UI/platform wiring) | thin binding + platform persistence |
| `WeatherPoC.Tests` (`net10.0`, not measured) | unit tests with a **faked `IUnitPreferencesStore`**, a **faked region/culture**, and a **faked `IWeatherService`** | n/a | offline, deterministic |
| `WeatherPoC.EndToEnd` (not measured, not in the gate) | manual/e2e verification of the **real MAUI `Preferences` round-trip across restart** (§4.5, Seam 4) | n/a | platform persistence |

`WeatherPoC.Core` stays plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41): the resolver reads the **region/culture through injected values**, not a platform API, and the store is an **interface**; the platform-bound MAUI `Preferences` lookup stays in the excluded app head (the same shape as F1's `FileSystem.AppDataDirectory` staying in the shell).

### 4.2 The canonical representation (UnitsNet quantities)

Per the brainstorm keystone decision (§7 R1), F2/F3 are amended so the Weather Variables are carried as **UnitsNet quantity types** — the canonical, unit-aware representation the formatter converts from:

```
CurrentConditions { Temperature Temperature; Temperature ApparentTemperature;
                    Speed WindSpeed; Length Precipitation;
                    double HumidityPercent; /* wind direction: degrees + compass */ ... }
DailyForecastDay  { DateOnly Date; Temperature? High; Temperature? Low; WeatherCondition Condition; }
```

- A UnitsNet quantity stores its value **unit-agnostically**; converting `Temperature` °C→°F (or `Speed` mph→km/h→m/s, or `Length` mm→in) is **lossless** and never mutates the source quantity. This makes "lossless re-render" a property of the **type**, not a convention a future edit could break.
- The `IWeatherService` mapper (F2/F3 Seam 1) wraps the Open-Meteo numbers into quantities at the boundary (e.g. `Temperature.FromDegreesCelsius(json.temperature_2m)`). What unit F2/F3 request from Open-Meteo becomes an **internal fetch detail**; the **display** unit is now entirely the formatter's job.
- Humidity stays a plain `double` percentage and wind direction stays its degrees + 8-point compass rendering — **neither is user-choosable** (§3), so neither becomes a quantity-with-a-picker.

### 4.3 The Locale unit-default resolver (pure, in Core)

A pure function `(region, measurement) → default Measurement Unit`, over an **embedded CLDR `unitPreferenceData` slice**:

- The slice holds the three weather-relevant usage rows captured from Unicode CLDR `common/supplemental/units.xml` `<unitPreferenceData>` (Seam 3, grounded 2026-06-16):

  | Measurement | CLDR category / usage | World (`001`) | GB | US |
  |---|---|---|---|---|
  | temperature | `temperature` / `weather` | celsius | **celsius** | fahrenheit |
  | wind speed | `speed` / `wind` | kilometer-per-hour | **mile-per-hour** | mile-per-hour |
  | precipitation | `length` / `rainfall` | millimeter | millimeter | inch |

- The resolver takes the **region** as an **injected value** (the app head supplies `RegionInfo.CurrentRegion.TwoLetterISORegionName`; Core never calls the platform), looks the measurement up for that region, and **falls back to region `001`** when the region is unmapped, unknown, or null.
- It maps the CLDR unit name (`celsius`, `mile-per-hour`, …) to the project's `MeasurementUnit` value (which in turn maps to a UnitsNet unit for the formatter).
- It is the **guardrail against `RegionInfo.IsMetric`** (ADR 0002): GB resolves to **°C + mph + mm** — a mix `IsMetric` cannot produce. The resolver **never** consults `IsMetric`.

### 4.4 The Weather Variable formatter (pure, in Core, over UnitsNet)

A pure function `format(quantity, targetUnit, culture) → string`:

- Converts the canonical UnitsNet quantity to `targetUnit` (**lossless**) and returns a **culture-formatted** string carrying the unit's localized abbreviation (e.g. `"21 °C"`, `"13 mph"`, `"2 mm"`), via UnitsNet's localized `ToString`/`QuantityFormatter`.
- The input quantity is **never mutated** — formatting is a read. Re-formatting the same quantity to a different unit is the whole "lossless, instant" mechanism (§4.7).
- The **culture** (device `CultureInfo`, injected) governs number formatting and abbreviation localization; this is **distinct** from the **region** that drives the *default* unit (§4.3) — locale has two facets here and the design keeps them separate.
- Only present quantities are formatted: a **null** Daily Forecast `High`/`Low` (F3 Seam 1) renders `"—"` and the formatter is **not** called for it.

### 4.5 The Unit Preferences store (overrides, layered on defaults)

- **`IUnitPreferencesStore`** (Core) exposes: `GetOverride(measurement) → MeasurementUnit?` (**absent** when unset), `SetOverride(measurement, unit)`, `ClearOverride(measurement)`, and a **`Changed` event** (§4.7, Seam 1).
- The **effective unit** is a pure composition: `effective(measurement) = store.GetOverride(measurement) ?? resolver.Default(region, measurement)`. So an unset override means "use the CLDR default", and **clearing** an override **reverts** that measurement to its default (story 30).
- Overrides are persisted as a small **`measurement → stable unit token`** map. Tokens are **stable strings** (not enum ordinals) so persisted values survive enum refactors. **First run = no overrides = pure CLDR defaults.**
- Persistence is **MAUI `Preferences`** (ordinary local key-value — no secrets, so **not** `SecureStorage`; ADR/Technical-Context). The **concrete `Preferences`-backed implementation lives in the excluded app head**; Core depends only on the `IUnitPreferencesStore` interface, which unit tests **fake** (§4.1). This is the persistence pattern Feature 5's Saved Location store reuses (§7 R3).

### 4.6 The Settings page + `SettingsViewModel`

- A **gear / Settings button** on the main view navigates to a **dedicated Settings page** (with back navigation), backed by `SettingsViewModel` (gated Core). The XAML page is excluded app-head binding.
- The page shows **one picker per measurement**, populated from the offered option lists — temperature **{°C, °F}**, wind speed **{mph, km/h, m/s}**, precipitation **{mm, in}** — each **pre-selected to the current effective unit** (override if set, else the CLDR default).
- Selecting a unit calls `SetOverride`; the picker reflects the new effective unit. (A future "reset to default" affordance would call `ClearOverride` — the store already supports it; whether the page surfaces a reset control in this Feature is an Open Question, §9.)
- Picking a unit for one measurement leaves the others untouched (story 29).

### 4.7 The retrofit: format on display, re-render on change, never re-fetch

This is the behavioural heart of the Feature.

- The **shell ViewModel** continues to own the single fetch and holds the canonical `WeatherSnapshot` (quantities) — **unchanged** from F3.
- The **Current Conditions** and **Daily Forecast** presentation VMs are retrofitted: instead of formatting in **interim fixed units** (the placeholder F2/F3 ship before this Feature — §7 R1), they expose display strings produced by the **formatter** using the **effective unit** per measurement.
- Each presentation VM **subscribes to the store's `Changed` event**. On a change it **re-runs the formatter against the held snapshot's quantities** and raises `PropertyChanged` for the affected display strings — **no `IWeatherService` call**, no new fetch, the quantities unchanged. Switching units back and forth is therefore instant and lossless (stories 31, 35; Seam 1).
- A change to (say) temperature reformats temperature strings only; wind/precip strings are unaffected.

## 5. Seam inventory

The cross-boundary contracts this Feature crosses. Each carries a falsifiable contract (incl. data shape + nullability) and a real proof. The **Open-Meteo wire** is **not** an F4 seam — it is F2/F3's amended Seam 1; F4 only changes its **mapping target** (numbers → UnitsNet quantities, §4.2), referenced here, not re-proven.

### Seam 1 — Unit-preference change → presentation VMs re-render, lossless, no re-fetch *(headline)*

- **(a) class:** in-process (store event ↔ presentation VMs holding the snapshot). **Internal.** Lifetime-/correctness-sensitive (the "never re-fetch" guarantee).
- **(b) sides:** `IUnitPreferencesStore` (`Changed` event) ↔ the Current Conditions VM and the Daily Forecast VM (which hold the canonical `WeatherSnapshot`).
- **(c) contract:** `SetOverride`/`ClearOverride` raises `Changed`. On receipt, each presentation VM recomputes its display strings by calling the **formatter** (Seam 2) with the new **effective unit** against the **held** canonical quantities, and raises `PropertyChanged` for the affected strings. **No `IWeatherService` call occurs**; the underlying `Temperature`/`Speed`/`Length` quantities are **identical** before and after (lossless). A change to one measurement alters **only** that measurement's strings. **Nullability:** a null daily `High`/`Low` stays `"—"` across a unit change (the formatter is not called for an absent quantity). `Changed` carries no required payload — VMs re-read the effective units.
- **(d) proof:** behavioural unit test over the presentation VMs with a **faked `IUnitPreferencesStore`** and a **faked `IWeatherService`**: load a `WeatherSnapshot`; fire `Changed` for a temperature override °C→°F; assert (i) the temperature display string changes to the converted value, (ii) wind/precipitation strings are unchanged, (iii) the faked `IWeatherService` is **never re-invoked**, (iv) the source `Temperature` quantity is reference/value-identical, and (v) a null daily `Low` remains `"—"`.

### Seam 2 — Weather Variable formatter: canonical quantity → localized display string *(pure)*

- **(a) class:** pure function, data-format facet (over UnitsNet). **Internal** — UnitsNet is a referenced library; **code is the authority** for its API.
- **(b) sides:** the presentation VMs / `SettingsViewModel` ↔ the formatter (over UnitsNet).
- **(c) contract:** `format(quantity, targetUnit, culture)` converts the **non-null** UnitsNet quantity to `targetUnit` **losslessly** and returns a string formatted in `culture` with the unit's localized abbreviation. The input quantity is **never mutated**. `targetUnit` is always a member of the measurement's offered set (temperature {°C, °F}; wind {mph, km/h, m/s}; precipitation {mm, in}) — the picker (§4.6) cannot produce an out-of-set unit, so no unsupported pairing arises. **Nullability:** the quantity argument is non-null by construction (absent daily values are filtered to `"—"` upstream, §4.4); `culture` is the injected device `CultureInfo`.
- **(d) proof:** pure unit tests: numeric conversion correctness per option (e.g. `0 °C → "32 °F"`, a known mph→km/h and mph→m/s pair, a known mm→in pair); the source quantity is unchanged after formatting (lossless); re-formatting the same quantity to a different unit changes **only** the string; number format + abbreviation follow the **injected culture** (assert with two cultures).

### Seam 3 — Locale unit-default resolver: device region → default Measurement Unit *(CLDR-grounded)*

- **(a) class:** host-OS / runtime (device region) + data-format facet (the embedded CLDR slice). **Internal at runtime** (the slice is our embedded resource and the region is injected), but the **slice's data authority is external (Unicode CLDR)** — so it carries (e).
- **(b) sides:** the Locale unit-default resolver ↔ the injected device region and the embedded CLDR `unitPreferenceData` slice.
- **(c) contract:** given a region code, the resolver returns the default `MeasurementUnit` per measurement from the embedded slice: **GB → {temperature: °C, wind: mph, precipitation: mm}**, **US → {°F, mph, in}**, and an **unmapped/unknown/null region → world `001` {°C, km/h, mm}**. It **never** derives a default from `RegionInfo.IsMetric` (the ADR 0002 regression). **Nullability:** a null/empty/unrecognised region is **not** an error — it resolves to `001`; the function never throws and always returns a unit for every measurement.
- **(d) proof:** pure unit tests with an **injected region**: **GB → °C + mph + mm** (the mixed-convention headline that proves the `IsMetric` regression is absent); **US → °F + mph + in**; a metric locale (e.g. **FR → °C + km/h + mm**); a garbage/empty region **→ `001` defaults**. A test pins the embedded slice's values to the CLDR-grounded table in (e) so slice drift goes red.
- **(e) authority:** the **live Unicode CLDR** `common/supplemental/units.xml` `<unitPreferenceData>` (`github.com/unicode-org/cldr`), grounded **2026-06-16**: `temperature`/`weather` (`001`=celsius, US-group=fahrenheit, GB→`001`=celsius); `speed`/`wind` (`001`=kilometer-per-hour, `GB US`=mile-per-hour); `length`/`rainfall` (`001`=millimeter, US=inch, GB→`001`=millimeter). The embedded slice **must be captured from CLDR**, never hand-asserted from model memory. **No auth / no wire** — this is embedded reference data, not a service (no first-contact auth to pin).

### Seam 4 — Unit Preferences store ↔ persisted overrides (MAUI `Preferences`)

- **(a) class:** persistent-on-disk-state. **Internal** at the `IUnitPreferencesStore` interface boundary; the concrete persistence is **MAUI `Preferences`** (host platform), living in the **excluded app head**.
- **(b) sides:** the effective-unit logic / VMs ↔ `IUnitPreferencesStore`; the concrete impl ↔ MAUI `Preferences` (on-disk, per-user).
- **(c) contract:** `GetOverride(measurement)` returns the persisted `MeasurementUnit` or **absent** (→ the CLDR default applies); `SetOverride` persists the override and raises `Changed`; `ClearOverride` removes it (→ reverts to the CLDR default) and raises `Changed`. Overrides **survive an app restart**. **Effective-unit layering:** `effective = override ?? default`. **Nullability/presence:** an unset override is **absent** (not a sentinel unit); **first run = no overrides = pure CLDR defaults**. **Data shape:** a `measurement → stable unit token` map; tokens are **stable strings**, so persisted data survives enum refactors.
- **(d) proof:** the **layering + effective-unit logic** (`override ?? default`, set-then-get returns the override, clear-reverts-to-default, first-run = defaults, `Changed` fires on set and clear) is unit-tested with a **faked `IUnitPreferencesStore`** + faked resolver (gated, 100%). The **real MAUI `Preferences` round-trip across restart** is **excluded app-head platform wiring**, verified **manually / e2e** — consistent with how Feature 1 treats the Serilog bootstrap and the platform path lookup, since `Preferences` is a static platform API not exercisable in offline xUnit. *(This is the conscious trade-off of choosing MAUI `Preferences` over a Core JSON-file store — recorded in §7 R4.)*

## 6. Acceptance criteria

1. Temperature (current + feels-like + Daily Forecast high/low), wind speed, and precipitation render in the User's chosen unit, chosen **independently** per measurement; humidity (%) and wind direction (degrees + compass) are unchanged and have **no** picker (stories 26, 29, 32; §4.2).
2. With no configuration, defaults come from the device region via the embedded CLDR slice — **GB → °C + mph + mm**, **US → °F + mph + in**, **unmapped → °C + km/h + mm** — and **never** from `RegionInfo.IsMetric` (stories 27, 28; Seam 3; ADR 0002).
3. The Settings page offers temperature {°C, °F}, wind {mph, km/h, m/s}, precipitation {mm, in}; overriding one leaves the others untouched (stories 29, 32; §4.6).
4. Overrides persist across restarts; clearing an override reverts that measurement to its CLDR default (story 30; Seam 4).
5. Changing a unit reformats the **held** reading instantly; the displayed string changes, the canonical quantity is unchanged, and **`IWeatherService` is not called again** (stories 31, 35; Seam 1).
6. The resolver, formatter, store-layering logic, `SettingsViewModel`, and the retrofitted presentation VMs are **100% covered** by unit tests that **fake** the store/region/culture/provider and **never touch the network or platform persistence** (Principles 4 & 5); the Settings XAML page and the concrete MAUI-backed store stay in the excluded app head.
7. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41); region and culture enter Core as **injected values**, never via a platform call.
8. `Porticle.CLDR.Units` is **not** taken as a dependency; **UnitsNet** does conversion + localized formatting and the embedded CLDR slice does the routing (§7 R2; Technical-Context + ADR 0002 updated).

## 7. Reconciliations with upstream artefacts

- **R1 — F2 & F3 specs amended to carry UnitsNet quantities (brainstorming decision, 2026-06-16).** F4's keystone decision is that the canonical representation the formatter converts from is a **UnitsNet quantity** in the domain types, making "lossless re-render" a property of the type. Because Features 2 and 3 are **spec-only (not yet coded)** — and F2 implements **before** F4 — the Feature owner chose to amend their specs **now** (so they are built quantity-native) rather than have F4 rework `double` fields later. Accordingly `0002-live-current-conditions.md` and `0003-daily-forecast.md` are amended in this same change: `CurrentConditions` temperature/feels-like → `Temperature`, wind → `Speed`, precipitation → `Length`; `DailyForecastDay` `HighC/LowC (double?)` → `High/Low (Temperature?)`; the Seam 1 mappers wrap Open-Meteo numbers into quantities; and until F4 lands, the F2/F3 presentation VMs format in **interim fixed units** (°C/mph/mm), which F4 swaps for the effective unit + reactivity. The Roadmap's F2/F3/F4 entries are unaffected — the quantity representation is an implementation shape, not a scope change. Cross-referenced from each amended spec's new R-entry.
- **R2 — ADR-0002 CLDR spike resolved: drop `Porticle.CLDR.Units`, embed the slice (brainstorming decision, 2026-06-16).** ADR 0002 deferred to "this Feature's spec time" the question of whether `Porticle.CLDR.Units` exposes the usage+region→unit routing API, "otherwise embed the small CLDR slice required." Grounded against the package's repo and NuGet page (2026-06-16), `Porticle.CLDR.Units` is **formatting-only** — it embeds CLDR unit data for grammatical singular/plural formatting and exposes **no `unitPreferenceData` routing**. Since **UnitsNet** already owns conversion + localized formatting (Technical-Context; ADR 0002), Porticle would add nothing we need. **Resolution:** drop `Porticle.CLDR.Units`; **embed the small CLDR `unitPreferenceData` slice** (the three weather usages, Seam 3) and write the pure resolver over it. ADR 0002's *Consequences* and Technical-Context's *Units* package line are updated in this same change to record the outcome.
- **R3 — Persistence pattern set for Feature 5 (brainstorming decision, 2026-06-16).** The Feature owner chose **MAUI `Preferences` behind an `IUnitPreferencesStore` interface** over a Core JSON-file store. This establishes the local-persistence pattern Roadmap F5's **Saved Location store** ("ordinary local persistence, not `SecureStorage`") reuses: an interface in gated Core (layering logic unit-tested with a fake) + a concrete MAUI-platform-backed implementation in the excluded app head.
- **R4 — Persistence proof is faked-store unit tests + manual/e2e round-trip (trade-off of R3).** Choosing MAUI `Preferences` (a static platform API) means the **real** persistence round-trip is **not** exercisable in offline xUnit, so Seam 4's real-I/O proof is **deferred to manual/e2e verification** while the **layering/effective-unit logic** is fully unit-tested with a faked store. This is a conscious departure from Feature 1's "testable persistence in Core" (`LoggingSetup`) pattern — accepted because unit *preferences* are idiomatically MAUI `Preferences`, and it is consistent with the project's existing treatment of platform APIs as excluded wiring (F1's Serilog bootstrap, the `FileSystem.AppDataDirectory` lookup).
- **R5 — No `IsMetric`, no unit-system toggle (consistent with ADR 0002).** The resolver derives defaults **only** from the embedded CLDR slice (Seam 3) and there is no bundled metric/imperial switch (§3) — both are the explicit ADR 0002 guardrails. No contradiction; recorded because this Feature is where the guardrail becomes live code.

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary: **Measurement Unit**, **Unit Preferences**, **Weather Variable**, **Weather Condition**, **Current Conditions**, **Daily Forecast**, **User** (governs test + type naming; "Unit Preferences … selected independently … defaults from device locale … overrides any individual unit" is the spec for §4.3/§4.5).
- `Technical-Context.MD` — **Overriding Principles** (no secrets / MAUI `Preferences` is not `SecureStorage`; UI thread never blocks; unit tests fake the platform/provider; 100% gate with UI/wiring excluded), Frameworks (MAUI/.NET 10, MVVM), Packages (**UnitsNet** for conversion + localized formatting; CommunityToolkit.Mvvm; **Porticle.CLDR.Units dropped per R2**), User Feedback (no raw errors). *As updated by R2.*
- `PRD.md` — stories 26–32 (per-measurement Unit Preferences, locale defaults, independent overrides, persistence, lossless display-only change, sensible option lists), 35 (responsive), 41 (macOS-viable); *Implementation Decisions* (Locale unit-default resolver, Weather Variable formatter, Unit Preferences store — all named there); *Further Notes* ("CLDR is the starting point, not the final say").
- `Roadmap.md` — **Feature 4** entry (scope, out-of-scope, dependency on Features 2 & 3; the ADR-0002 spike assigned to this Feature's spec time).
- `docs/adr/0002-per-measurement-unit-defaults.md` — the governing decision; **implemented here**, with its spike resolved per R2. *As updated by R2.*
- `docs/adr/0001-location-detection-cascade.md` — for awareness only; the Location is hard-coded in F4 (detection is Features 5–6).
- `docs/superpowers/specs/0002-live-current-conditions.md`, `docs/superpowers/specs/0003-daily-forecast.md` — the surfaces F4 retrofits and the domain types F4 amends to quantities — **as amended by R1**.
- `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` — the shell, coverage-gate, project structure, and the "platform API stays in the excluded app head" pattern this Feature follows.

## 9. Open questions / deferred to the Plan

- **`MeasurementUnit` representation** — the exact enum/type for the offered units and its stable persistence tokens — a Plan/TDD detail; the contract is only Seams 2–4 (per-measurement option lists, stable tokens, `override ?? default`).
- **Embedded-slice shape** — whether the CLDR slice is a hand-trimmed static table or a generated resource, and exactly which regions beyond GB/US/`001` are pinned — a Plan detail; the contract is Seam 3's grounded values + the `001` fallback. The slice **must** be captured from CLDR (Seam 3 (e)), not hand-typed from memory.
- **"Reset to default" affordance on the Settings page** — the store supports `ClearOverride`; whether the page surfaces a per-measurement reset control in this Feature, or only implicit defaults, is a UI/Plan detail (§4.6).
- **`Changed` event granularity** — whether the store's `Changed` event is coarse (any change) or carries the changed measurement(s) — a Plan/TDD detail; Seam 1's contract holds either way (VMs re-read effective units).
- **Region/culture injection shape** — how the app head supplies `RegionInfo`/`CultureInfo` into Core (constructor value, a small provider) — a Plan detail; the contract is only that Core receives them as **values**, never calling the platform (Acceptance 7).
- **Package versions** — UnitsNet (and the CommunityToolkit pieces) pinned against the live feed at implementation time, as in specs 0001–0003.

## Feature-doc-gauntlet sign-off

- **Status:** Pending — runs on the Spec **and** the Plan together, after `/writing-plans` produces the Plan and before `/enate-to-stories`. Not yet run for Feature 4.
