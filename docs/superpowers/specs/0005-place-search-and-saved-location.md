# Spec — Feature 5: Place Search + Saved Location 🔎📍

**Feature:** 5 (Roadmap.md)
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Depends on:** Features 2 & 3 — the typed `IWeatherService` combined `GetWeatherAsync(Location, ct) → Result<WeatherSnapshot>` surface and the **shell ViewModel** that owns the single fetch, the 15-min auto-refresh, and the loading / loaded / couldn't-update / load-failed state machine, all fed a single `Location`. **And — per §7 R1 — Feature 4**: Place Search is hosted in a new **Location section of the Settings page** F4 introduces, so F5 reuses F4's Settings page shell + gear/nav entry. The 1→…→6 delivery order already builds F4 first, so this dependency is satisfied by construction.
**Downstream:** Feature 6 reuses this Feature's **Active Location resolver** (feeding it a **Detected** input alongside Saved to complete the full matrix) and this Feature's **empty state** as the detection cascade's terminal fallback (ADR 0001; PRD stories 4, 37).

---

## 1. Intent

Replace the **single hard-coded `Location`** that has fed the combined fetch since Features 2–3 with a **User-chosen Active Location**. Via **Place Search** the User types a human-readable place name; the app queries the **Open-Meteo Geocoding API** and shows **candidate Locations** disambiguated by **name + region + country**; choosing one **atomically persists it as the Saved Location** and makes it the **Active Location**, so the app **reopens on that place** (PRD stories 8–12). The User can **clear** the Saved Location — and because there is **no detection yet** (Feature 6), clearing drops to the **empty state** that invites a Place Search (PRD stories 6, 13). The main view keeps it **legible** that the displayed place is a chosen one (story 14).

Per the brainstorm decisions: Place Search lives in a **Location section of the Settings page** (the surface F4 introduces); the search is **as-you-type, debounced** with a minimum query length; and a new place propagates into a weather re-fetch **on main-view activation** (the pure resolver stays pure — the shell VM re-resolves when the main view re-activates after the User returns from Settings).

The scary unknowns this Feature de-risks are **(1) the Geocoding wire shape** — a **different Open-Meteo host** (`geocoding-api.open-meteo.com`), a `results` array that is **entirely absent** on zero matches (not `[]`), and an **optional `admin1`** — and **(2) the debounced as-you-type search lifecycle** — minimum-length gating plus **latest-wins cancellation**, so a slow earlier query can never overwrite a newer one's results. The well-trodden parts — persisting a small value, a pure resolver, and reusing the F2/F3 fetch unchanged — stay thin.

This Feature lands the four pieces the Roadmap and PRD *Implementation Decisions* name:

1. the **Geocoding service** — the **second** typed Open-Meteo client (place name → candidate `Location`s);
2. the **Saved Location store** — ordinary local persistence (MAUI `Preferences` behind an interface, reusing F4's pattern — F4 R3);
3. the pure **Active Location resolver** — the rule the tracer bullet deferred, here arbitrating **Saved-or-absent only** (the full Saved-over-Detected matrix completes in F6); and
4. the **Place Search** surface (in the Settings Location section) + the main-view **location header** + **empty state**, plus the **rewiring** of the shell VM from a constant to the resolved Active Location.

## 2. Goals — what "done" proves

1. With a **Saved Location** set, it **is** the Active Location and drives the existing combined fetch — Current Conditions + the Daily Forecast render for the chosen place, and the **location header** shows its name and that it is a **chosen** place (stories 5, 10, 11, 14; §4.2, §4.7).
2. **Place Search** — typing a place name (debounced, at or above the minimum length) queries Open-Meteo Geocoding and shows **candidate `Location`s** disambiguated by **name + region + country**; an **ambiguous** query (e.g. "London") shows **multiple** candidates to choose between (stories 8, 9; §4.3, §4.4, Seam 1).
3. **Choosing** a candidate **atomically** persists it as the **Saved Location** and makes it the Active Location; the app **reopens on it across a restart** (stories 10, 11, 12; §4.5, Seam 4).
4. **Clearing** the Saved Location drops to the **empty state** that invites a Place Search — there is **no Detected Location to fall back to** yet (stories 6, 13; §4.6, §4.7; the F2/F3 "no empty state" gap is closed here).
5. **Zero results** (no `results` key) shows a **"no places found"** state — **not** an error; a **geocoding network/transport failure** shows a **friendly** message with raw detail only in the log; **superseded** as-you-type searches are **cancelled** (latest wins); the **UI thread never blocks** (stories 8, 9; Seam 1, Seam 2; Overriding Principles 1 & 2).
6. The new surface — the geocoding DTOs + mapper, the resolver, the store-layering logic, the Place Search ViewModel, the shell VM's resolve-on-activation + empty-state handling, and the location-header state — is **100% unit-tested with the provider + platform faked** (Overriding Principles 4 & 5); the geocoding **live wire** is pinned by an **end-to-end test** that stays **outside** the deterministic unit/coverage gate.

## 3. Non-goals / out of scope

Per Roadmap Feature 5, the PRD, and ADR 0001:

- **Automatic location detection (GPS / IP).** No detection cascade, no Detected Location, no IP-geolocation client — that is **Feature 6** (ADR 0001). Here the Active Location is **only** what the User searches for, so clearing the Saved Location drops to the **empty state**, never to a Detected Location (stories 1–4, 7, 37 are F6).
- **A saved *list* / multiple locations.** Exactly **one** Active Location at a time, always — there is **no** multi-location dashboard and **no** history of past places (story 5; PRD *Out of Scope*). Choosing a place **replaces** the Saved Location.
- **The full detected-vs-saved resolution matrix.** The resolver lands only **Saved-or-absent** here; "Detected only → Active is Detected" and "Saved cleared → revert to Detected" complete in **Feature 6** (PRD *Testing Decisions*; §7 R2). The detected-vs-saved **distinction is only half-real** in F5 (no Detected Location to contrast against), but the **legibility affordance** (the header marking the place as *chosen*) is built now so F6 only adds the *detected* variant.
- **Unit Preferences / the formatter.** Units and location are **domain-orthogonal** (Roadmap F4 "Independent of location"); F5 reuses F4's Settings **page shell** but touches **no** unit code. Weather Variables render exactly as F2/F3/F4 leave them.
- **Re-fetch on anything but an Active-Location change or the existing refresh triggers.** A Place Search query itself never touches `IWeatherService`; only **selecting** (or **clearing**) a place — surfaced through the shell VM's resolve-on-activation — drives a weather fetch (§4.6, Seam 5).
- **Release signing / installer packaging.** Unchanged from Features 1–4; still deferred.

## 4. Design

### 4.1 Where the code lives (coverage map)

Feature 1's four-project structure and the gate line carry over. F5 adds code on both sides of the line; **all** of F5's new logic except the XAML and the platform-bound persistence is gated Core:

| Lands in | Project | Coverage | What |
|---|---|---|---|
| `WeatherPoC.Core` (`net10.0`, gated) | the pure **Active Location resolver** (`Saved-or-absent`); the **`IGeocodingService`** interface + its implementation (the typed-client request build + the **geocoding JSON → candidate `Location` mapper**, incl. absent-`results`, absent-`admin1`, and malformed handling); the **`ISavedLocationStore`** interface; the **`PlaceSearchViewModel`** (debounce, min-length, latest-wins cancellation, search states); the **shell VM** changes (resolve-on-activation → fetch-or-empty-state, re-fetch after a change); the **location-header** VM state | **100% gated** | the real domain + presentation logic |
| `WeatherPoC` (app head, excluded) | the **Settings Location-section** XAML (search box + candidate list + clear control) + the main-view **location header** + **empty-state** XAML + the deep-link nav into Settings → Location; the **DI registration** of the typed `HttpClient` for the **geocoding host** + resilience handlers; the **concrete MAUI-`Preferences`-backed `ISavedLocationStore`** (JSON-serialises the `Location` into one key) | `[ExcludeFromCodeCoverage]` (untestable UI / platform wiring) | thin binding + platform persistence |
| `WeatherPoC.Tests` (`net10.0`, not measured) | unit tests with a **faked `HttpMessageHandler`** fed **geocoding JSON fixtures captured from the real API**, a **faked `ISavedLocationStore`**, a **faked `IGeocodingService`**, a **faked `IWeatherService`**, and an **abstracted `TimeProvider`** (for debounce) | n/a | offline, deterministic |
| `WeatherPoC.EndToEnd` (not measured, not in the gate) | a **live** call to the real Open-Meteo Geocoding API asserting an **ambiguous** query deserializes into **multiple** candidate `Location`s | n/a | proves Seam 1's live wire |

`WeatherPoC.Core` stays plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41): the `HttpClient` and MAUI `Preferences` are reached through interfaces; the platform-bound persistence stays in the excluded app head (the same shape as F4's `IUnitPreferencesStore` and F1's `FileSystem.AppDataDirectory` lookup).

### 4.2 The Active Location resolver (pure, `Saved-or-absent`)

The PRD names this a **pure module** that "combines already-resolved inputs … No I/O." F5 lands the **Saved-or-absent** half of the glossary rule:

```
resolve(saved: Location?) → Location?      // F5: Active = saved ?? absent
```

- Saved present → the Active Location **is** the Saved Location.
- Saved absent → there is **no Active Location** (→ the empty state, §4.7).
- It is a **pure function** — it does **not** read the store, the clock, or any platform API; the **shell VM** supplies the current Saved Location (read from `ISavedLocationStore`) and consumes the result.
- **Feature 6** widens the signature to `resolve(saved: Location?, detected: Location?)` and adds the "Detected only" and "Saved cleared → Detected" arms; F5's arms are a strict subset, so F6 is purely additive (§7 R2). The glossary rule (Context.MD *Active Location*) is the authority for both halves.

### 4.3 The Geocoding service (the second typed Open-Meteo client)

A typed client `IGeocodingService` — **separate** from `IWeatherService` (Overriding Principle 3 governs the *weather* client; geocoding is a distinct concern on a **different host**, and the PRD *Implementation Decisions* names it as its own service):

```
Task<Result<IReadOnlyList<Location>>> SearchAsync(string query, CancellationToken ct)
```

- One HTTP GET to `https://geocoding-api.open-meteo.com/v1/search` carrying `name={query}` + `count={N}` + `language={device language}` + `format=json`. **Keyless** — no API key, no wire auth (Seam 1 (e); Overriding Principle 1).
- The response `results` array is **zipped into candidate `Location`s**, each carrying its **coordinates** and a **composite human-readable name** built as `name` + `", " + admin1` *(only when present)* + `", " + country` — e.g. `"London, England, United Kingdom"`, `"London, Ontario, Canada"`, and (no `admin1`) `"Singapore, Singapore"`. This is the disambiguation content of story 9 (Seam 1).
- Same `Result<T>` contract as F2/F3: a transport/HTTP failure → a **friendly domain-level failure** (never an unhandled exception to the UI); **zero matches** (the `results` key **absent**) → a **success with an empty list** (→ the "no places found" state, §4.4), **not** a failure. Each geocoding call is **logged exactly once** (endpoint, status, latency) via the same Serilog mechanism as F2's Seam 4, now applied to the geocoding host (Technical-Context *Instrumentation*).

### 4.4 The Place Search ViewModel (debounced, latest-wins)

`PlaceSearchViewModel` (gated Core) drives the as-you-type search:

- **Debounce + min length:** a query is dispatched to `IGeocodingService` only after a short **typing pause** (`TimeProvider`-driven) and only when the trimmed query meets a **minimum length** (the live API returns no `results` for empty/single-character names — §4.3, Seam 1 — so calling below the threshold is wasted I/O and a logged no-op). Below the threshold the VM sits in an **idle/hint** state and makes **no** call.
- **Latest-wins cancellation:** each new dispatch **cancels** the prior in-flight search (its `CancellationToken`), so a slow earlier response can **never** overwrite a newer query's results. At most the **latest** query's results are applied.
- **States:** **idle/hint** (below min length) · **searching** (in flight) · **results** (≥1 candidate) · **no-results** (success, empty list — "No places found for '…'") · **error** (friendly failure — "Couldn't search right now"). None of these block the UI thread.
- **Selecting** a candidate persists it via `ISavedLocationStore.Save` (§4.5) — which is the **choose = save** atomic step (no separate Save button; Roadmap; §7 R4) — then dismisses the search (navigation back to the main view triggers the re-fetch, §4.6).

### 4.5 The Saved Location store (ordinary local persistence)

- **`ISavedLocationStore`** (Core) exposes: `Get() → Location?` (**absent** when none saved), `Save(Location)`, and `Clear()`.
- Persistence is **MAUI `Preferences`** — ordinary local key-value; **no secrets, so not `SecureStorage`** (PRD *Implementation Decisions*; Technical-Context). The **concrete `Preferences`-backed implementation lives in the excluded app head**; Core depends only on the **interface**, which unit tests **fake** (§4.1). This is exactly F4's Unit Preferences store pattern (F4 R3).
- The saved value is a **single `Location`** (coordinates + the composite human-readable name) serialised to **JSON** in **one `Preferences` key** (`Location` is a small value, unlike F4's per-measurement token map). **Absent key = no Saved Location** = the empty state.
- **Round-trip / restart:** `Save` then `Get` (across a restart) returns the same `Location`; `Clear` removes it (→ `Get` returns absent). The **real** `Preferences` round-trip across restart is excluded app-head platform wiring, verified **manually / e2e** (the same conscious trade-off F4 recorded in its R4); the **layering logic** (`Save`/`Get`/`Clear` + "absent ⇒ no Active Location") is unit-tested with a **faked store** under the gate.

### 4.6 The shell VM rewiring (hard-coded `Location` → resolved Active Location)

This is the behavioural heart of the Feature, and it is **additive** to F3's shell VM:

- On **main-view activation** the shell VM **reads `ISavedLocationStore.Get()`**, calls the **pure resolver** (§4.2), and:
  - **Active Location present** → runs the existing combined `GetWeatherAsync(active, ct)` (F2/F3 unchanged) and renders Current Conditions + the Daily Forecast + the **location header** (§4.7).
  - **Active Location absent** → enters the **empty state** (§4.7) and makes **no** fetch (story 6).
- Because **Place Search lives in the Settings page** (a separate page), the User **navigates back** to the main view after choosing or clearing a place; that **re-activation re-resolves** and re-fetches — **no cross-page event** is needed (the brainstorm "activation-driven" decision). This reuses F2/F3's existing "fetch on activation" lifecycle; the pure resolver stays pure.
- All F2/F3 shell-VM rules carry over **unchanged**: at most one fetch in flight; the 15-min auto-refresh; manual refresh resets the countdown; timer + in-flight fetch cancelled on deactivation; timestamp = last successful fetch; the **empty state** is a new sibling of loading/loaded/couldn't-update/load-failed (it is the *no-Active-Location* state, distinct from *load-failed* which is a fetch failure for a present Active Location).

### 4.7 The Place Search UI, the location header, and the empty state

All XAML below is the excluded app head; the **state** behind each binding is gated Core.

- **Settings → Location section:** above the F4 Units section, a **Location section** holds the **search box** (drives `PlaceSearchViewModel`), the **candidate list** (each row: the composite name), and a **Clear Saved Location** control. Reuses F4's Settings page shell + gear/nav (§7 R1).
- **Main-view location header:** shows the **Active Location's name** and a marker that it is a **chosen** place (story 14) — the legibility affordance F6 extends with a *detected* variant — plus a control that navigates to **Settings → Location** to change it.
- **Empty state:** when there is **no Active Location**, the main view shows a clear empty state ("No location yet — search for a place") whose **call-to-action deep-links** into Settings → Location (story 6). In F6 this same empty state becomes the detection cascade's **terminal fallback**.

## 5. Seam inventory

The cross-boundary contracts this Feature crosses. Each carries a falsifiable contract (incl. data shape + nullability) and a real proof; the **external** seam additionally carries **(e) authority** and pins **first-contact auth**. The **Open-Meteo *weather* wire** is **not** an F5 seam — it is F2/F3's Seam 1, reused **unchanged** (F5 only changes the `Location` fed into it). **Open-Meteo call logging** is F2's Seam 4, here **extended** to the geocoding client (one geocoding call logged once, endpoint/status/latency) — referenced, not re-proven.

### Seam 1 — Open-Meteo Geocoding response → domain candidate `Location`s *(headline, external)*

- **(a) class:** **network-protocol** + **cross-process I/O**, **data-format** facet (HTTP JSON → domain types). **External** — Open-Meteo is third-party; its response shape can drift.
- **(b) sides:** the `IGeocodingService` implementation ↔ the Open-Meteo Geocoding API.
- **(c) contract:** a GET to `https://geocoding-api.open-meteo.com/v1/search?name={query}&count={N}&language={lang}&format=json` returns `{ "results"?: [ … ], "generationtime_ms": number }`. Each `results[i]` carries **`name` (string), `latitude` (number), `longitude` (number), `country` (string) — present on every result** — and **optional `admin1` (string), `admin2`, `timezone`, `population`, `feature_code`, `country_code`, `postcodes`**. The mapper zips each result into a candidate `Location` = `{ Latitude, Longitude, Name }` where `Name` is **`name` + (`", " + admin1` *iff present*) + `", " + country`**. **Nullability/presence:** the **`results` key is ABSENT** (not `[]`) when there are **zero matches** — and for **empty / single-character** `name` — → the service returns a **success with an empty candidate list** (the "no places found" state), **never** a failure; an individual result **missing `admin1`** → the composite name **omits the region** (e.g. `"Singapore, Singapore"`); a **transport/HTTP error or unparseable body** → the **friendly domain-level failure** (no unhandled exception to the UI). **No API key is sent.**
- **(d) proof:** **Unit (offline, deterministic):** geocoding JSON **fixtures captured from real Open-Meteo responses** — a normal **ambiguous multi-candidate** payload ("London" → GB/Ontario/US rows), a candidate **lacking `admin1`** ("Singapore"), a **zero-results** payload (`{"generationtime_ms":…}`, **no `results` key**), and a **malformed** body — fed through a **faked `HttpMessageHandler`** and asserted to map to the expected candidate `Location`s / empty list / friendly failure. A **round-trip** assertion confirms the real captured payload parses to the expected candidates, **including the absent-`results` and absent-`admin1` cases**. **End-to-end (live network, outside the gate):** a real GET asserting an ambiguous query deserializes into **multiple** candidate `Location`s — this is what catches real wire drift.
- **(e) authority:** the **live Open-Meteo Geocoding API** (`geocoding-api.open-meteo.com/v1/search`; docs `open-meteo.com/en/docs/geocoding-api`). **Grounded live 2026-06-16** (egress open): `name=London&count=5&language=en&format=json` (no key) returned **HTTP 200** with a `results` array whose every element carried `name`/`latitude`/`longitude`/`country` and most carried `admin1` (`"England"`, `"Ontario"`, `"Ohio"`, …); `name=Singapore` returned results **without `admin1`** (confirming its optionality); a gibberish query, an **empty** `name`, and a **single character** each returned **HTTP 200 with no `results` key** (confirming zero-matches is an **absent key**, not `[]` and not an error). **First-contact auth (this is first contact with the geocoding host):** the Geocoding API offers **no authentication** — it is **keyless** (no API key, no wire auth), confirmed by the 200s above with no credential sent; this matches Open-Meteo's keyless posture established for the Forecast host in F2 but is **independently confirmed** for `geocoding-api.open-meteo.com`. The **binding proof remains the end-to-end test**, and the offline fixtures must be **captured from real responses** at implementation time — including the absent-`results` and absent-`admin1` cases, which a hand-written mock would only re-encode as an assumption (taxonomy: mock-on-both-sides is not proof).

### Seam 2 — Place Search debounced-search lifecycle *(in-process, internal)*

- **(a) class:** **in-process** (typed text ↔ `PlaceSearchViewModel` ↔ `IGeocodingService` ↔ a debounce timer). **Internal.** Concurrency-/lifetime-sensitive (Overriding Principle 2); a **host-OS/runtime** facet (the clock) is abstracted via `TimeProvider`.
- **(b) sides:** the `PlaceSearchViewModel` ↔ the device clock (`TimeProvider`) and `IGeocodingService`.
- **(c) contract:** a query is dispatched **only** after a debounce interval elapses **and** the trimmed query meets the **minimum length**; below the threshold the VM is **idle** and makes **no** call. Each dispatch **cancels** the prior in-flight search, so **only the latest query's results are applied** (a slow earlier response is dropped). The VM transitions **idle → searching → {results | no-results | error}**; **no** transition blocks the UI thread. A `Result` failure → **error**; a success with an empty list → **no-results**; a success with ≥1 candidate → **results**.
- **(d) proof:** behavioural unit tests over the VM with a **faked `IGeocodingService`** and an **abstracted `TimeProvider`** (no real waiting): typing below the minimum length fires **no** geocoding call; advancing virtual time past the debounce with a valid query fires **exactly one**; two quick keystrokes fire **one** call for the **latest** text (debounce coalesces); a slow first search followed by a second whose result returns first → the **first is cancelled and its late result is ignored** (latest-wins); an empty-list result → **no-results**; a faked failure → **error**.

### Seam 3 — Active Location resolver: `(Saved?) → Active?` *(pure, internal)*

- **(a) class:** **pure function.** **Internal** (Core only).
- **(b) sides:** the shell ViewModel ↔ the resolver.
- **(c) contract:** `resolve(saved)` returns the **Saved Location** when one is present, and **absent** when it is not. The function reads **no** store, clock, or platform API — `saved` is supplied by the caller. It never throws and is total over `{present, absent}`. **Nullability:** `saved` absent is the **legitimate empty-state input**, not an error; the result absent is the **no-Active-Location** signal the shell VM routes to the empty state.
- **(d) proof:** pure unit tests: `saved` present → Active **is** that Location; `saved` absent → Active **absent**. (The F6 "Detected" arms are explicitly **not** present and not tested here — §7 R2.)

### Seam 4 — Saved Location store ↔ persisted `Location` (MAUI `Preferences`) *(persistent-on-disk-state)*

- **(a) class:** **persistent-on-disk-state.** **Internal** at the `ISavedLocationStore` interface boundary; the concrete persistence is **MAUI `Preferences`** (host platform), living in the **excluded app head**.
- **(b) sides:** the shell VM / `PlaceSearchViewModel` ↔ `ISavedLocationStore`; the concrete impl ↔ MAUI `Preferences` (on-disk, per-user).
- **(c) contract:** `Get()` returns the persisted `Location` or **absent**; `Save(location)` persists it (replacing any prior — there is only ever **one**); `Clear()` removes it (→ `Get()` absent). The saved value **survives an app restart** (story 12). **Data shape:** a **single `Location`** (`{ Latitude, Longitude, Name }`) serialised to **JSON** under **one `Preferences` key**. **Nullability/presence:** an **absent key ⇒ no Saved Location ⇒ no Active Location** (the empty state); there is **no sentinel** "empty" Location.
- **(d) proof:** the **layering logic** (`Save`-then-`Get` returns the saved `Location`; `Clear` ⇒ `Get` absent; absent ⇒ the resolver yields no Active Location) is unit-tested with a **faked `ISavedLocationStore`** (gated, 100%). The **real MAUI `Preferences` round-trip across restart** is **excluded app-head platform wiring**, verified **manually / e2e** — the same conscious trade-off F4 recorded (its R4), since `Preferences` is a static platform API not exercisable in offline xUnit.

### Seam 5 — Shell VM re-resolve-on-activation → weather re-fetch *(in-process, internal)*

- **(a) class:** **in-process** (page-activation lifecycle ↔ shell VM ↔ `ISavedLocationStore` + resolver + `IWeatherService`). **Internal.** Lifetime-sensitive.
- **(b) sides:** the shell ViewModel ↔ the main-view activation lifecycle and the F2/F3 combined fetch.
- **(c) contract:** on **every main-view activation** the shell VM reads `ISavedLocationStore.Get()`, calls the resolver, and **either** runs `GetWeatherAsync(active)` (Active Location present) **or** enters the **empty state** with **no** fetch (absent). Returning from Settings after a **choose** or **clear** therefore re-resolves and re-fetches (or empties) **without any cross-page event**. All F2/F3 lifecycle invariants hold: **at most one fetch in flight**; the 15-min timer and manual refresh behave as before; deactivation cancels timer + in-flight fetch; the UI thread never blocks. The **empty state** is distinct from **load-failed** (the former = no Active Location, no fetch attempted; the latter = a present Active Location whose first fetch failed).
- **(d) proof:** behavioural unit tests over the shell VM with a **faked `ISavedLocationStore`**, a **faked `IWeatherService`**, and an **abstracted `TimeProvider`**: activation with a saved `Location` → exactly one `GetWeatherAsync(thatLocation)` and **Loaded**; activation with **no** saved Location → **empty state**, `IWeatherService` **never** called; a **re-activation** after the faked store's value **changes** → a fetch for the **new** Location; a re-activation after `Clear` → empty state with no fetch; overlapping activations never produce two concurrent fetches.

## 6. Acceptance criteria

1. With a Saved Location set, the app renders Current Conditions + the Daily Forecast for that place and a **location header** showing its name + a **chosen-place** marker (stories 5, 10, 11, 14; Seam 3, Seam 5).
2. Typing a place name (debounced, ≥ min length) shows **candidate `Location`s** labelled **name + region + country**; an ambiguous query shows **multiple** candidates; region is **omitted** when `admin1` is absent (stories 8, 9; Seam 1).
3. **Choosing** a candidate persists it as the **Saved Location**, makes it Active, fetches its weather, and the app **reopens on it after a restart** (stories 10, 11, 12; Seam 4, Seam 5).
4. **Clearing** the Saved Location drops to the **empty state** inviting a Place Search — never to a Detected Location (no detection yet) (stories 6, 13; Seam 5).
5. **Zero matches** show "no places found" (not an error); a geocoding **failure** shows a friendly message (raw detail to the log only); **superseded** searches are cancelled (latest wins); the UI thread never blocks (stories 8, 9; Seam 1, Seam 2; Principles 1 & 2).
6. The geocoding DTOs + mapper, the resolver, the store-layering logic, the Place Search VM, the shell VM's resolve-on-activation + empty state, and the location-header state are **100% covered** by unit tests that **fake** the provider/store/clock and **never touch the network or platform persistence** (Principles 4 & 5); the geocoding **end-to-end** test hits the **real** API and is **not** in the deterministic gate.
7. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41); the geocoding `HttpClient`, the MAUI `Preferences` store, and the device language enter Core through interfaces/injected values, and the XAML + concrete store stay in the excluded app head.
8. Place Search is reached via the **Settings page Location section** (reusing F4's page shell); the main-view **empty state** deep-links into it (stories 6, 8; §7 R1).

## 7. Reconciliations with upstream artefacts

- **R1 — Place Search hosted in F4's Settings page; Roadmap F5 dependency amended (brainstorming decision, 2026-06-16).** The Feature owner chose to host Place Search + Clear in a **Location section of the Settings page** F4 introduces, over a standalone surface — consolidating the User's two persisted choices (Saved Location + Unit Preferences) on one surface, both behind the MAUI-`Preferences`-interface pattern (F4 R3). This creates a **presentation dependency F5 → F4** that contradicts `Roadmap.md`'s "Feature 5 … independent of 4." Because the **Roadmap outranks the Spec** (and per the F2 R1 / F3 R1 precedent of amending the Roadmap when a Spec diverges), `Roadmap.md` is **amended in this same change**: the dependency-chain line and the Feature 5 *Dependencies* line now read **"domain-independent of Feature 4 (units ⊥ location), but reuses F4's Settings page shell"**. The **domain** orthogonality the Roadmap asserts still holds (F5 touches no unit code); only a **presentation** coupling is added, and the 1→…→6 delivery order already builds F4 first, so nothing operational changes.
- **R2 — Resolver lands only the `Saved-or-absent` half (consistent with PRD *Testing Decisions* + Roadmap).** Roadmap F5 explicitly scopes the resolver to "Saved-or-absent (Saved set → Active is Saved; cleared → no Active Location → empty state); the full Saved-over-Detected matrix completes in Feature 6," and the PRD *Testing Decisions* list the full matrix under what gets tested **once Detected exists**. F5 therefore builds and tests **only** the Saved/absent arms (§4.2, Seam 3); F6 widens `resolve` to take a `detected` input and adds the remaining arms — a strict superset, no rework. **No divergence** — recorded because the resolver's *shape* (which arms exist) is a deliberate scope line.
- **R3 — As-you-type debounced search (brainstorming decision, 2026-06-16).** Roadmap F5 / PRD stories 8–9 specify only "type a human-readable place name" and "show a list of matching places when ambiguous" — they do not fix the **trigger**. The Feature owner chose **as-you-type with a debounce + minimum length + latest-wins cancellation** over an explicit Search button, accepting the extra VM concurrency machinery (Seam 2) and the higher count of (logged) geocoding calls for a snappier search. This is a UX/implementation shape, **not** a scope change; recorded because the alternative (explicit search) was explicitly declined.
- **R4 — Choosing a candidate atomically persists it as the Saved Location (Roadmap-aligned).** Roadmap F5: "choosing one makes it the Active Location and persists it as the Saved Location." In F5 there is **no Detected Location**, so any Active Location **is** a Saved Location — choosing and saving **collapse into one atomic step** (no separate "Save" affordance). PRD stories 10 (choose as Active) and 11 (keep as Saved) are distinct stories that F5 satisfies with one action; they only **diverge** in F6, where Place Search can override an existing Detected Location. **No contradiction** — recorded because the story split could otherwise imply a two-step flow.
- **R5 — Geocoding is a *second* typed client; Overriding Principle 3 unaffected (consistent).** Principle 3 mandates **one** typed client for **weather-provider** access (`IWeatherService`). The Geocoding API is a **distinct concern** on a **different host** (`geocoding-api.open-meteo.com`), and the PRD *Implementation Decisions* names a separate **Geocoding service**. Adding `IGeocodingService` therefore **honours**, not violates, Principle 3 (which is about not scattering *weather* calls). Its **first-contact auth** (keyless) is pinned in Seam 1 (e). **No contradiction.**

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary: **Active Location** (the Saved-or-Detected-or-absent rule the resolver encodes — its *absent* arm is the empty state), **Saved Location**, **Detected Location** (for the F6 boundary — *not* built here), **Location** (coordinates + human-readable place name — the candidate + persisted shape), **Place Search**, **User** (single-user; the Saved Location belongs to that User). Governs test + type naming.
- `Technical-Context.MD` — **Overriding Principles 1–5** (Open-Meteo keyless; UI thread never blocks; **one *weather* client** — geocoding is a second, distinct client per §7 R5; unit tests fake the provider/platform / E2E hits the real API; 100% gate with UI/wiring excluded), Frameworks (MAUI/.NET 10, MVVM), Packages (CommunityToolkit.Mvvm; `IHttpClientFactory` + Microsoft.Extensions.Http.Resilience for the typed geocoding client; System.Text.Json source-gen for the geocoding DTOs **and** the persisted `Location`; **MAUI `Preferences`** for the Saved Location store — *not* `SecureStorage`; Serilog), Instrumentation (every Open-Meteo call logged — now incl. geocoding), User Feedback (friendly, no raw codes — the no-results vs error split).
- `PRD.md` — stories **5, 6** (one Active Location; the empty state), **8–15** (Place Search, candidate disambiguation, choose/keep/persist/clear, detected-vs-saved legibility), **33–36** (loading/error/responsive/plain-language), **41** (macOS-viable); *Implementation Decisions* (**Active Location resolver** pure/no-I/O; **Geocoding service**; **Saved Location store** — ordinary local persistence, not `SecureStorage`; the ViewModel owning Active-Location → fetch → display incl. the **empty** state and feeding **Place Search**); *Testing Decisions* (resolver full matrix tested once Detected exists; geocoding candidate mapping + friendly failures; store round-trip + clear).
- `Roadmap.md` — **Feature 5** entry (scope, out-of-scope, the `Saved-or-absent` resolver split, dependency on F2 + F3) — **as amended by R1** (the F4 Settings-page-shell reuse).
- `docs/adr/0001-location-detection-cascade.md` — the cascade **F6** implements; F5 builds the resolver's Saved arm and the empty state that becomes the cascade's terminal fallback. **Not** implemented here (no detection); referenced for the F5/F6 boundary.
- `docs/adr/0002-per-measurement-unit-defaults.md` — for awareness only; F5 touches no unit code (units ⊥ location).
- `docs/superpowers/specs/0002-live-current-conditions.md`, `docs/superpowers/specs/0003-daily-forecast.md` — the `IWeatherService` combined `GetWeatherAsync`/`WeatherSnapshot` surface and the **shell VM / state machine** F5 rewires from a constant to the resolved Active Location (Seam 5), reused **unchanged** otherwise.
- `docs/superpowers/specs/0004-per-measurement-unit-preferences.md` — the **Settings page shell** F5's Location section is hosted in (§4.7, R1) and the **MAUI-`Preferences`-behind-an-interface** persistence pattern F5's Saved Location store reuses (its R3, Seam 4).
- `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` — the shell, coverage gate, project structure, and the "platform API stays in the excluded app head" pattern this Feature follows.
- `docs/seam-taxonomy.md` — the seam class vocabulary §5 uses (network-protocol + cross-process I/O + data-format for Seam 1; in-process for Seams 2 & 5; pure for Seam 3; persistent-on-disk-state for Seam 4; external first-contact auth pinned in Seam 1 (e)).

## 9. Open questions / deferred to the Plan

- **`Location` name composition + candidate richness** — the composite `"name, region, country"` is the agreed disambiguation content (Seam 1); whether the search-results candidate also retains the **structured components** (`admin1`/`country`) for richer View styling (bold name, muted region) before collapsing to a `Location` on selection is a Plan/View detail. The domain contract is only Seam 1's composite name + the absent-`admin1` omission.
- **Debounce interval, minimum query length, and `count`** — the working choices are a short debounce, a 2-character minimum (the live API returns nothing useful below that — Seam 1), and a small `count` (the live grounding used 5); the exact values are Plan/UX tuning. The contract is only Seam 2's behaviour (debounce coalesces, below-threshold makes no call, latest-wins).
- **`language` parameter source** — the device language (e.g. `CultureInfo.CurrentUICulture.TwoLetterISOLanguageName`) supplied into Core as an **injected value** (never a platform call in Core, per Acceptance 7); the exact injection shape is a Plan detail (mirrors F4's region/culture injection question).
- **Persisted-`Location` JSON shape + key name** — the single-key JSON serialisation is agreed (§4.5); the exact key name, the `System.Text.Json` source-gen context, and schema-versioning (if any) are Plan/TDD details. The contract is only Seam 4 (one key, round-trips, absent ⇒ no Active Location).
- **Empty-state + location-header copy/affordances** — the empty state invites a Place Search and the header marks the place as *chosen* (stories 6, 14); exact wording, the chosen-place glyph, and the navigation control are Plan/UI details (excluded app head).
- **Captured fixture provenance** — the offline geocoding fixtures must be **captured from real Open-Meteo responses** at implementation time (Seam 1 (d)/(e)) — including the absent-`results` and absent-`admin1` cases a normal response does not always exhibit — never hand-invented; which queries they are captured from is a Plan/TDD detail.
- **Package versions** — the geocoding `HttpClient` + resilience and `System.Text.Json` pieces pinned against the live feed at implementation time, as in specs 0001–0004.

## Feature-doc-gauntlet sign-off

- **Status:** Pending — runs on the Spec **and** the Plan together, after `/writing-plans` produces the Plan and before `/enate-to-stories`. Not yet run for Feature 5.
