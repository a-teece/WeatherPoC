# Spec — Feature 6: Automatic location detection 📍🛰️

**Feature:** 6 (Roadmap.md)
**Status:** Draft (ready for `/writing-plans`)
**Date:** 2026-06-16
**Depends on:** Feature 5 — reuses this Feature's **Active Location resolver** (widening `resolve(saved)` → `resolve(saved, detected)` to complete the full matrix) and its **empty state** as the cascade's terminal fallback; the **`ISavedLocationStore`** (read to supply the Saved input); the **shell ViewModel** resolve-on-activation lifecycle (F5 Seam 5) that F6 feeds a Detected input. Indirectly **Features 2 & 3** — the Detected Location drives the same combined `GetWeatherAsync(Location, ct) → Result<WeatherSnapshot>` fetch/display, reused **unchanged**.
**Downstream:** none — Feature 6 is the last Roadmap Feature. It retires the hard-coded `Location` for good (the tracer-bullet constant that F2–F4 used and F5 replaced with Saved-or-empty is now also fed by detection).

---

## 1. Intent

On launch, establish the **Active Location with no typing** (PRD stories 1–4). WeatherPoC runs the **ADR 0001 cascade** — **device GPS first**, falling back to **IP-based geolocation** when GPS is unavailable or denied, and only dropping to **Place Search** (F5's empty state) when both fail. A resolved position becomes a **named Detected Location**; the Detected Location is **re-derived every run and never persisted**, so the app follows the User as they move (PRD story 7; Context.MD *Detected Location*). The **Active Location resolver** now completes: a **Saved Location still overrides** detection, and **clearing** the Saved Location **reverts** the Active Location to the Detected Location (Context.MD *Active Location*; stories 13, 15). The UI keeps **detected vs saved legible at all times** (story 14), extending F5's *chosen* marker with a *detected* variant. When detection fails entirely, friendly messaging **nudges** the User to Place Search — a gentle redirect, not a dead end (story 37).

Per the brainstorm decisions (2026-06-16): the cascade runs **once per app run, eagerly at startup**, regardless of any Saved Location, and its result is cached in **session memory** (never disk); the shell VM combines that Detected input with the Saved Location via the widened resolver on each main-view activation (reusing F5's resolve-on-activation). Naming is done by **BigDataCloud's keyless `reverse-geocode-client`**, which serves **both** branches: called **with** the GPS coordinates it reverse-geocodes them (`lookupSource: "coordinates"`), and called **without** coordinates it geolocates the caller's IP (`lookupSource: "ip geolocation"`).

The scary unknowns this Feature de-risks are **(1) the detection provider** — ADR 0001 deferred the choice to now, and the obvious platform path (MAUI `Geocoding`) turns out to **need a Bing Maps API key on Windows** (a secret, on a retiring platform); **(2) the GPS-naming gap** — a raw device position is coordinates only, but a Detected Location must be a *named* place (Context.MD); and **(3) the cascade lifecycle** — permission prompts, fall-through on denial/timeout, short-circuit on GPS success, and a once-per-run session cache that the pure resolver reads but never re-triggers. The well-trodden parts — a pure resolver widening, reusing the F2/F3 fetch unchanged, and the F5 store/empty-state — stay thin.

This Feature lands the pieces the Roadmap and PRD *Implementation Decisions* name:

1. the **Location detection cascade orchestration** — `ILocationDetector`, pure ordering logic over its sources (ADR 0001);
2. the **geolocation/naming client** — the third typed HTTP client (`IGeoNamingClient`, BigDataCloud), the Roadmap's "IP-geolocation client" expanded to also reverse-geocode the GPS branch (§7 R1);
3. a **platform GPS position source** — `IDevicePositionSource`, abstracted so a macOS implementation follows without touching cascade logic (Roadmap; story 41);
4. the **widened Active Location resolver** — `resolve(saved, detected)`, completing F5's deferred matrix; and
5. the **shell VM** startup-detection + session Detected holder + the **detected/empty** UI states and the **detected-vs-saved** header marker.

## 2. Goals — what "done" proves

1. On a **first launch** (no Saved Location), the cascade establishes a **named Detected Location** with **no typing**, and Current Conditions + the Daily Forecast render for it; the **location header** marks it a **detected** place (stories 1–4, 7, 14; §4.4, §4.7, Seams 1–3).
2. **GPS first:** when the device returns a position, that GPS coordinate (reverse-geocoded to a name) is the Detected Location; the IP branch is **not** called (stories 2, 3; §4.3, Seam 3).
3. **IP fallback:** when GPS is **unavailable or denied**, the IP branch produces a **named, city-level** Detected Location (story 3; §4.3, Seam 3).
4. **Terminal fallback:** when **both** GPS and IP fail, the app shows **F5's empty state** with a friendly nudge to Place Search — never an error, never a dead end (stories 4, 37; §4.5, Seam 3, Seam 5).
5. **Full resolver matrix:** a **Saved Location overrides** detection; **clearing** the Saved Location **reverts** the Active Location to the Detected Location (or to the empty state if none); a Place Search still overrides a Detected Location (stories 5, 13, 15; §4.6, Seam 4).
6. The Detected Location is **re-derived each run and never persisted** — a restart with no Saved Location re-detects from scratch; detection runs **once per run** (activations read the session cache, never re-prompt) (story 7; §4.2, §4.6, Seam 5).
7. The new logic — the geolocation/naming DTO + mapper, the cascade, the widened resolver, the shell VM's startup-detect + session holder + detected/empty states, and the header marker — is **100% unit-tested with the provider + platform faked** (Overriding Principles 4 & 5); the BigDataCloud **live wire** is pinned by **end-to-end tests** that stay **outside** the deterministic gate.
8. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41): the GPS source, the device language, and the geolocation `HttpClient` enter Core through interfaces/injected values; the MAUI `Geolocation`/`Permissions` impl and XAML stay in the excluded app head.

## 3. Non-goals / out of scope

Per Roadmap Feature 6, the PRD, and ADR 0001:

- **Choosing the provider earlier, or a keyed provider.** The provider is resolved **here** (§7 R1) to BigDataCloud's **keyless** client endpoint; no API key, **no `SecureStorage`** — the app stays secret-free (Overriding Principle 1 stays dormant). A **Bing Maps key** for MAUI `Geocoding` is explicitly **rejected** (§7 R2).
- **A macOS GPS implementation.** Only the **`IDevicePositionSource` abstraction** is built; the concrete impl is Windows-only (MAUI `Geolocation`). Shipping macOS stays a future target (Roadmap; story 41).
- **Pinpoint accuracy.** IP geolocation is **city-level** by nature (ADR 0001); the GPS branch is as accurate as the OS provides. Good enough for weather, not precise.
- **Persisting the Detected Location.** It lives in an **in-memory, session-scoped holder** and is **never** written to disk (story 7; Context.MD). Only the **Saved Location** persists (F5, unchanged).
- **Continuous/background location tracking.** Detection is a **one-shot per run** at startup — no live position updates, no geofencing, no re-detection on activation (§4.2, Seam 5).
- **Changing the weather or geocoding wires.** F2/F3's combined `GetWeatherAsync` and F5's Open-Meteo **forward** Geocoding (Place Search) are reused **unchanged**; F6 only changes the `Location` fed into the fetch and reuses the empty state.
- **Unit Preferences / the formatter.** Units ⊥ location; F6 touches no unit code (Roadmap F4). Weather Variables render exactly as F2–F4 leave them.
- **Release signing / installer packaging.** Unchanged from Features 1–5; still deferred.

## 4. Design

### 4.1 Where the code lives (coverage map)

Feature 1's four-project structure and the gate line carry over. F6 adds code on both sides of the line; **all** of F6's new logic except the XAML and the two platform-bound impls is gated Core:

| Lands in | Project | Coverage | What |
|---|---|---|---|
| `WeatherPoC.Core` (`net10.0`, gated) | the new `Coordinates` value type (an un-named position); the **`IGeoNamingClient`** interface + impl (the typed-client request build + the **BigDataCloud JSON → named `Location` mapper**, incl. empty-`city` and malformed handling); the **`IDevicePositionSource`** interface; the **`ILocationDetector`** cascade (GPS→name→IP→absence ordering + the reverse-geocode-failure degradation); the **widened resolver** `resolve(saved, detected)`; the **shell VM** startup-detect + the **session Detected holder** + the detected/empty state + the **detected-vs-chosen** header state | **100% gated** | the real domain + presentation logic |
| `WeatherPoC` (app head, excluded) | the Windows **`IDevicePositionSource`** impl (MAUI `Geolocation` + `Permissions<LocationWhenInUse>`); the **DI registration** of the typed `HttpClient` for the **BigDataCloud host** + resilience handlers + the injected device `localityLanguage`; the **"Detecting…" + detected-header + empty-state** XAML and the startup hook wiring | `[ExcludeFromCodeCoverage]` (untestable platform / UI wiring) | thin binding + platform position |
| `WeatherPoC.Tests` (`net10.0`, not measured) | unit tests with a **faked `HttpMessageHandler`** fed **BigDataCloud JSON fixtures captured from the real API**, a **faked `IDevicePositionSource`**, a **faked `IGeoNamingClient`**, a **faked `ILocationDetector`**, a **faked `ISavedLocationStore`** (F5), a **faked `IWeatherService`** (F2/F3), and an **abstracted `TimeProvider`** | n/a | offline, deterministic |
| `WeatherPoC.EndToEnd` (not measured, not in the gate) | **live** BigDataCloud calls: one **with** coordinates (asserts `lookupSource:"coordinates"` → a named `Location`) and one **without** (asserts `lookupSource:"ip geolocation"` → a named `Location`) | n/a | proves Seam 1's two live wire modes |

`WeatherPoC.Core` stays plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41): MAUI `Geolocation` is reached only through `IDevicePositionSource`, the `HttpClient` through `IGeoNamingClient`, and the device language as an injected value — the same shape as F5's `ISavedLocationStore`/geocoding-client and F1's `FileSystem.AppDataDirectory` lookup.

### 4.2 The detection model (once per run, eager, session-cached)

Per the brainstorm decision (§7 R4) and Context.MD *Detected Location* ("re-derived rather than remembered"):

- On **app startup** the shell VM invokes `ILocationDetector.DetectAsync(ct)` **once**, **eagerly**, **regardless** of any Saved Location, and stores the result — a Detected `Location` **or absence** — in an **in-memory, session-scoped holder**. The holder is **never serialised, never written to `Preferences`/disk**; a restart re-runs detection from scratch.
- Eager (not lazy) means the detected fallback is **ready the instant** the User clears their Saved Location, with no mid-session prompt. GPS permission is a **one-time OS grant**, so eager detection does not re-prompt on later launches.
- The pure resolver (§4.6) **reads** the cached Detected input on each activation; activations **never** re-invoke the detector. Detection is one-shot per run (out of scope: continuous tracking).

### 4.3 The detection cascade (`ILocationDetector`, ordering over sources)

```
Task<Location?> DetectAsync(CancellationToken ct)
```

The ADR-0001 order, as deterministic logic over two injected sources (`IDevicePositionSource`, `IGeoNamingClient`):

1. **GPS first** — `await IDevicePositionSource.TryGetCoordinatesAsync(ct)`:
   - **coordinates present** → `await IGeoNamingClient.ResolveAsync(coords, ct)`:
     - success → a **named** Detected Location (GPS-accurate position, reverse-geocoded name);
     - failure → **degrade** to a coordinate-derived label on the **GPS coordinates** (the usable fix is **retained**, not discarded — §7 R5), logged. Either way, **Detected Location present** → the IP branch is **not** called (short-circuit).
2. **IP fallback** — GPS **absent** (denied / unavailable / no fix in time) → `await IGeoNamingClient.ResolveAsync(null, ct)` (IP mode):
   - success → a **named, city-level** Detected Location;
   - failure → **absence**.
3. **Absence** → no Detected Location → the resolver routes to the **empty state** (§4.5).

`DetectAsync` **never throws** — every source failure maps to a fall-through or to absence. Each branch is attempted **at most once**. The UI thread never blocks (async, `CancellationToken`).

### 4.4 The geolocation/naming client (the third typed HTTP client)

A typed client `IGeoNamingClient` — **distinct** from `IWeatherService` (weather; Principle 3) and `IGeocodingService` (F5, forward geocoding); this is reverse-geocoding + IP geolocation, a distinct concern on a **different host** (§7 R6):

```
Task<Result<Location>> ResolveAsync(Coordinates? position, CancellationToken ct)
```

- One HTTP GET to `https://api.bigdatacloud.net/data/reverse-geocode-client` carrying `localityLanguage={device language}` and, **when `position` is non-null**, `latitude` + `longitude`. **Keyless** — no API key, no wire auth (Seam 1 (e); Overriding Principle 1).
- The response is mapped to a **named `Location`** `{ Latitude, Longitude, Name }` where `Name` is composed `city` + (`", " + principalSubdivision` *iff non-empty*) + `", " + countryName` (tidied). `latitude`/`longitude` come from the response body (so the IP-mode call returns coordinates the caller didn't have).
- Same `Result<T>` contract as F2/F3/F5: a transport/HTTP failure → a **friendly domain-level failure** (`ILocationDetector` turns it into fall-through/absence; never an unhandled exception to the UI). A **successful-but-sparse** body (e.g. empty `city` over the ocean) is **still a success** — the mapper falls back to `principalSubdivision`/`countryName`, or a coordinate-derived label if all are empty (not a failure). Each call is **logged exactly once** (endpoint, status, latency) via the same Serilog mechanism as F2's Seam 4, now applied to the BigDataCloud host (Technical-Context *Instrumentation*, amended).

### 4.5 The platform GPS source and the failure-to-empty-state path

- **`IDevicePositionSource`** (Core interface; Windows impl in the excluded app head) exposes `Task<Coordinates?> TryGetCoordinatesAsync(ct)`. The Windows impl requests `Permissions<LocationWhenInUse>` and calls MAUI `Geolocation.GetLocationAsync(GeolocationRequest, ct)`, mapping **denied/restricted permission**, a returned **`null`** location, `FeatureNotSupportedException`, `PermissionException`, or a **timeout** → **absence**. The interface is **platform-free** (no MAUI types in Core); macOS adds a sibling impl without touching the cascade.
- When `DetectAsync` returns **absence** and there is **no Saved Location**, the shell VM enters **F5's empty state** ("No location yet — search for a place"), now serving as the cascade's **terminal fallback**, with a friendly nudge to Place Search (story 37). This is the *no-Active-Location* state — distinct from *load-failed* (a present Active Location whose fetch failed).

### 4.6 The widened Active Location resolver and the shell VM rewiring

The resolver completes F5's deferral (its R2) — a strict superset, so F5's tests stay green:

```
resolve(saved: Location?, detected: Location?) → Location?
```

| Saved | Detected | Active | Story |
|---|---|---|---|
| present | (either) | **Saved** (overrides) | 5, 15 |
| absent | present | **Detected** | 1–3, 7 |
| absent | absent | **absent → empty state** | 4, 37 |
| *cleared* | present | reverts to **Detected** | 13 |

- It is a **pure function** — reads no store, clock, detector, or platform API; the shell VM supplies `saved` (from `ISavedLocationStore.Get()`) and `detected` (from the session holder). Total over the 2×2 of {present, absent}; never throws. **F5's `resolve(saved)` is exactly the `detected: absent` column.**
- The **shell VM** (additive to F5): at **startup** runs `DetectAsync` once → session holder, showing a **"Detecting…"** state until the first resolution. On **every main-view activation** it reads Saved + Detected, calls the resolver, and **either** runs the F2/F3 combined `GetWeatherAsync(active, ct)` and renders the header (marking **chosen** vs **detected**) **or** enters the **empty state** with no fetch. **Clearing** the Saved Location (in F5's Settings → Location) → on return, re-activation re-resolves → reverts to the **Detected** Location (holder) or the empty state — no cross-page event (F5's activation-driven model). All F2/F3/F5 lifecycle invariants hold (§4 below).

### 4.7 UI — the "Detecting…" state, the detected header, and reuse

All XAML is the excluded app head; the **state** behind each binding is gated Core.

- **"Detecting your location…" state** — a new sibling of F5's loading / loaded / couldn't-update / load-failed / empty, shown at startup while the cascade runs and no Active Location is yet resolvable. The UI thread never blocks.
- **Main-view location header** — extends F5's *chosen* marker with a **detected** variant, so the header always tells the User **why** this place is showing (story 14): a Saved Location reads as *chosen*; a Detected Location reads as *detected* (e.g. "detected"/"current location"). The control still navigates to **Settings → Location** to override via Place Search.
- **Empty state** — F5's, reused verbatim as the cascade's terminal fallback (§4.5).

The F2/F3/F5 shell-VM rules carry over **unchanged**: at most one weather fetch in flight; the 15-min auto-refresh; manual refresh resets the countdown; timer + in-flight fetch cancelled on deactivation; timestamp = last successful fetch.

## 5. Seam inventory

The cross-boundary contracts this Feature crosses. Each carries a falsifiable contract (incl. data shape + nullability) and a real proof; the **external** seams additionally carry **(e) authority** and pin **first-contact auth**. **Reused, not re-proven:** the Open-Meteo **weather** wire (F2/F3 Seam 1 — F6 only changes the `Location` fed in), the Open-Meteo **forward Geocoding** wire (F5 Seam 1 — Place Search, the terminal fallback), the **Saved Location store** (F5 Seam 4 — read here for the `saved` input). **Open-Meteo call logging** (F2 Seam 4) is **extended** to the BigDataCloud host (one detection call logged once, endpoint/status/latency) — referenced.

### Seam 1 — BigDataCloud `reverse-geocode-client` JSON → domain named `Location` *(headline, external)*

- **(a) class:** **network-protocol** + **cross-process I/O**, **data-format** facet (HTTP JSON → domain types). **External** — BigDataCloud is third-party; its response shape can drift.
- **(b) sides:** the `IGeoNamingClient` implementation ↔ the BigDataCloud reverse-geocode-client API.
- **(c) contract:** a GET to `https://api.bigdatacloud.net/data/reverse-geocode-client?localityLanguage={lang}` **optionally** carrying `latitude`+`longitude`. **Two modes keyed on whether coordinates are supplied:** **with** coords → `lookupSource: "coordinates"` (reverse-geocode the GPS fix); **without** → `lookupSource: "ip geolocation"` (geolocate the caller's IP). Both return **HTTP 200** JSON carrying `latitude` (number), `longitude` (number), `city` (string), `principalSubdivision` (string), `countryName` (string), `countryCode` (string). The mapper builds `Location = { Latitude, Longitude, Name }`, `Name = city` + (`", " + principalSubdivision` *iff non-empty*) + `", " + countryName` (tidied). **Nullability/presence:** `city`/`locality` may be the **empty string** for remote/ocean coordinates → the name falls back to `principalSubdivision`/`countryName`, or a coordinate-derived label if all are empty — **still a success, not a failure**; a transport/HTTP error or unparseable body → a **friendly domain-level failure** (no unhandled exception; the cascade turns it into fall-through/absence). **No API key, no auth header is sent.**
- **(d) proof:** **Unit (offline, deterministic):** BigDataCloud JSON **fixtures captured from real responses** — a coords-mode payload (`lookupSource:"coordinates"`, e.g. London), an IP-mode payload (`lookupSource:"ip geolocation"`, no coords sent), an **empty-`city`** payload (remote coordinate), and a **malformed** body — fed through a **faked `HttpMessageHandler`** and asserted to map to the expected named `Location` / coordinate-label fallback / friendly failure. A **round-trip** assertion confirms the captured payloads parse to the expected `Location`s, **including the empty-`city` case**. **End-to-end (live network, outside the gate):** two real GETs — one **with** coordinates asserting `lookupSource:"coordinates"` → a named `Location`, one **without** asserting `lookupSource:"ip geolocation"` → a named `Location` — which is what catches real wire drift across both modes.
- **(e) authority:** the **live BigDataCloud reverse-geocode-client API** (`api.bigdatacloud.net/data/reverse-geocode-client`; docs `bigdatacloud.com/docs/api/reverse-geocoding-to-city-api`). **Grounded live 2026-06-16 (egress open):** `?latitude=51.5072&longitude=-0.1276&localityLanguage=en` (no key) → **HTTP 200**, `lookupSource:"coordinates"`, `city:"London"`, `principalSubdivision:"England"`, `countryName:"United Kingdom of Great Britain and Northern Ireland (the)"`, `countryCode:"GB"`; the **same endpoint with no coordinates** → **HTTP 200**, `lookupSource:"ip geolocation"`, `city:"Council Bluffs"`, `principalSubdivision:"Iowa"`, with `latitude`/`longitude` present — **confirming the dual-mode behaviour** and that the keyless client endpoint geolocates the caller's IP when coordinates are omitted. **First-contact auth (first contact with BigDataCloud):** the reverse-geocode-**client** endpoint offers **no authentication** — keyless, no API key, no wire auth — confirmed by the 200s above with no credential sent (BigDataCloud's *other* APIs are keyed; we deliberately use the keyless client endpoint). This is a **distinct external system** from Open-Meteo, so its keyless posture is **independently confirmed**, not inherited. The **binding proof remains the end-to-end test**, and the offline fixtures must be **captured from real responses** at implementation time — incl. the empty-`city` case a hand-written mock would only re-encode as an assumption (taxonomy: mock-on-both-sides is not proof). **ADR 0001 and Technical-Context *3rd-party tech* are amended in this same change to name BigDataCloud** (the ADR deferred the choice to this Feature).

### Seam 2 — Device GPS position source ↔ MAUI `Geolocation` + `Permissions` *(host-OS / runtime, external platform)*

- **(a) class:** **host-OS / runtime** (GPS availability + permission behaviour vary by OS). **External** — the OS / MAUI platform is not our code — at the concrete impl; the `IDevicePositionSource` interface boundary is **internal**.
- **(b) sides:** `ILocationDetector` (Core) ↔ `IDevicePositionSource`; the Windows impl ↔ MAUI `Geolocation.GetLocationAsync` + `Permissions<LocationWhenInUse>` (host OS).
- **(c) contract:** `TryGetCoordinatesAsync(ct)` returns `Coordinates { Latitude, Longitude }` (both `double`) on a successful fix, or **absence** when permission is **denied/restricted**, location services are **unavailable**, the platform throws **`FeatureNotSupportedException`/`PermissionException`**, `GetLocationAsync` returns **`null`**, or **no fix arrives within** the configured `GeolocationRequest` timeout. **Nullability:** `GetLocationAsync` is documented to return **`Location?` — `null` when the platform cannot determine location**; absence is a **first-class, common** result (desktop machines frequently lack GPS) → the cascade falls through to IP, **never** a re-thrown exception. The interface is **platform-free** (no MAUI types leak into Core). UI thread never blocks.
- **(d) proof:** **Core unit tests** drive `ILocationDetector` with a **faked `IDevicePositionSource`**: returned coordinates → GPS branch (name then Detected); absence → fall-through to IP. The **real MAUI `Geolocation` + permission mapping is excluded app-head platform wiring**, verified **manually / e2e** (a static platform API not exercisable in offline xUnit — the same conscious trade-off F5 recorded for `Preferences`, its R4).
- **(e) authority:** **Microsoft Learn**, grounded 2026-06-16: `IGeolocation.GetLocationAsync(GeolocationRequest, CancellationToken)` returns `Task<Location?>` — *"A `Location` object … or `null` if no location could be determined"* and *"can return `null` in some scenarios … the underlying platform is unable to obtain the current location"*; permissions via `Permissions.CheckStatusAsync/RequestAsync<LocationWhenInUse>` → `PermissionStatus`; `FeatureNotSupportedException` on unsupported platforms (`learn.microsoft.com/dotnet/api/microsoft.maui.devices.sensors.geolocation`, `…/microsoft.maui.applicationmodel.permissions`). **Geolocation requires no key on any platform** — distinct from MAUI `Geocoding`, which needs a Bing Maps key on Windows (§7 R2), the reason naming is done over HTTP (Seam 1) rather than via the platform.

### Seam 3 — Location detection cascade ordering `(GPS, naming) → Detected?` *(in-process, internal)*

- **(a) class:** **in-process** (deterministic ordering logic over two async sources). **Internal.** Lifetime-sensitive (Overriding Principle 2).
- **(b) sides:** `ILocationDetector` ↔ its injected `IDevicePositionSource` + `IGeoNamingClient`.
- **(c) contract:** `DetectAsync(ct)` executes the ADR-0001 order: **(1)** `IDevicePositionSource` → **coordinates** → `IGeoNamingClient.ResolveAsync(coords)`; on naming **success** a named Detected Location, on naming **failure** a **coordinate-labelled** Detected Location (the GPS fix is **retained**) — either way **present**, and the IP call is **not** made (**short-circuit**); **(2)** GPS **absent** → `IGeoNamingClient.ResolveAsync(null)` (IP mode) → a named Detected Location **or**, on failure, **(3) absence**. Each branch is attempted **at most once**; the method **never throws** (every failure → fall-through or absence). **Nullability:** the all-fail result is **absence** — the legitimate empty-state signal. UI thread never blocks.
- **(d) proof:** Core unit tests with **`IDevicePositionSource` faked** and **`IGeoNamingClient` faked**: GPS coords + naming-ok → Detected (named), IP **not** called; GPS coords + naming-fail → Detected (coordinate-label), IP **not** called; GPS absence → IP called → Detected (named); GPS absence + IP fail → **absence**; a source that throws → treated as fall-through/absence (no exception escapes).

### Seam 4 — Active Location resolver `(saved, detected) → active` *(pure, internal — completes F5 Seam 3)*

- **(a) class:** **pure function.** **Internal** (Core only).
- **(b) sides:** the shell ViewModel ↔ the widened resolver.
- **(c) contract:** `resolve(saved, detected)` returns: **Saved present → Saved** (overrides Detected, **regardless** of `detected`); **Saved absent + Detected present → Detected**; **both absent → absent** (→ empty state). Reads **no** store, clock, detector, or platform API — both inputs are supplied by the caller. Total over the 2×2 of {present, absent}; never throws. **Nullability:** both inputs are independently nullable; **all-absent is the legitimate empty-state signal**, not an error. **F5's `resolve(saved)` arms are exactly the `detected: absent` column** — a strict superset, so F5's resolver tests pass unchanged.
- **(d) proof:** pure unit tests over the full 2×2: `(Saved✓, Detected✓) → Saved`; `(Saved✓, Detected✗) → Saved`; `(Saved✗, Detected✓) → Detected`; `(Saved✗, Detected✗) → absent`; plus a **regression** asserting the F5 `resolve(saved)` behaviour is preserved (the new `detected` arm does not disturb the Saved-or-absent arms).

### Seam 5 — Shell VM: startup detection → session Detected holder → resolve-on-activation *(in-process, internal — extends F5 Seam 5)*

- **(a) class:** **in-process** (app lifecycle ↔ shell VM ↔ session holder + store + resolver + weather fetch). **Internal.** Lifetime-sensitive; an **in-memory-state** facet (the session holder, **never persisted**).
- **(b) sides:** the shell ViewModel ↔ the startup hook + the in-memory session Detected holder + `ISavedLocationStore` (F5) + the resolver + `IWeatherService` (F2/F3).
- **(c) contract:** at **app startup** the VM runs `ILocationDetector.DetectAsync` **exactly once** (eager, regardless of any Saved Location) and stores the result (Detected Location **or** absence) in an **in-memory, session-scoped holder NEVER written to disk** (story 7 — re-derived every run); a **"Detecting…" state** shows while it runs and no Active Location is yet resolvable. On **every main-view activation** the VM reads Saved (store) + Detected (holder), calls the resolver, and **either** runs the F2/F3 combined `GetWeatherAsync(active)` (unchanged) **or** enters the **empty state** (no Active Location, no fetch). **Clearing** the Saved Location mid-session → the next activation re-resolves → **reverts to the Detected Location** (if the holder has one) else the empty state. **All F2/F3/F5 invariants hold:** at most **one** weather fetch in flight; the 15-min auto-refresh; manual refresh resets the countdown; deactivation cancels timer + in-flight fetch; the UI thread never blocks. **Detection runs once per run** — activations **read** the holder, **never** re-invoke the detector.
- **(d) proof:** behavioural Core unit tests with a **faked `ILocationDetector`**, **faked `ISavedLocationStore`**, **faked `IWeatherService`**, and an **abstracted `TimeProvider`**: startup (detector→Detected, no Saved) → exactly one `GetWeatherAsync(Detected)` + header marks **detected**; startup (detector→Detected, Saved present) → fetch for **Saved** + header marks **chosen** (Detected held in reserve, **never** fetched); startup (detector→absence, no Saved) → **empty state**, `IWeatherService` **never** called; **clear** Saved mid-session (holder has Detected) → re-activation fetches **Detected**; clear Saved (holder absent) → empty; the detector is invoked **exactly once** across multiple activations; the "Detecting…" state precedes the first resolution; overlapping activations never start two concurrent fetches.

## 6. Acceptance criteria

1. First launch (no Saved Location) establishes a **named Detected Location** with no typing and renders Current Conditions + the Daily Forecast for it; the header marks it **detected** (stories 1–4, 7, 14; Seams 1–3, 5).
2. **GPS first:** a device position → reverse-geocoded GPS Detected Location, IP branch **not** called; **IP fallback:** GPS denied/unavailable → named city-level Detected Location (stories 2, 3; Seams 2, 3).
3. **Terminal fallback:** GPS **and** IP both fail → **F5's empty state** with a friendly Place-Search nudge — never an error (stories 4, 37; Seams 3, 5).
4. **Full matrix:** a Saved Location **overrides** detection; **clearing** it **reverts** to the Detected Location (or empty if none); Place Search still overrides a Detected Location (stories 5, 13, 15; Seam 4).
5. The Detected Location is **never persisted** — restart with no Saved Location re-detects; detection runs **once per run** (activations don't re-prompt) (story 7; Seam 5).
6. **Keyless throughout** — no API key is sent and **no `SecureStorage` is introduced** (Overriding Principle 1 stays dormant); the GPS source needs no key (Seams 1, 2).
7. The geolocation/naming DTO + mapper, the cascade, the widened resolver, the shell VM's startup-detect + session holder + detected/empty states, and the header marker are **100% covered** by unit tests that **fake** the provider/GPS/store/clock and **never touch the network or platform** (Principles 4 & 5); the BigDataCloud **end-to-end** tests hit the **real** API (both modes) and are **not** in the deterministic gate.
8. `WeatherPoC.Core` remains plain `net10.0` with no Windows-only dependencies (macOS-viable — story 41); MAUI `Geolocation`, the `HttpClient`, and the device language enter Core through interfaces/injected values, and the platform impls + XAML stay in the excluded app head.

## 7. Reconciliations with upstream artefacts

- **R1 — BigDataCloud chosen as the detection provider; ADR 0001 + Technical-Context amended (brainstorming decision, 2026-06-16).** ADR 0001 deferred the IP-geolocation provider "to spec time" and the *3rd-party tech* list carried "provider TBD." Resolved to **BigDataCloud's keyless `reverse-geocode-client`**, grounded live (Seam 1 (e)). It serves **both** branches from one keyless endpoint (coords → reverse-geocode; no coords → IP geolocation), so the Roadmap's "**IP-geolocation client**" is **expanded** to also name the GPS branch — keeping the trust set to the **single** new third party the ADR anticipated. ADR 0001 (Consequences) and `Technical-Context.MD` (*3rd-party tech*, *Instrumentation*) are **amended in this same change** (the F5 R1 precedent of amending the outranking artefact when a Spec resolves a deferral). **No contradiction** — the ADR explicitly left this to the spec.
- **R2 — MAUI `Geocoding` rejected for naming; keyless HTTP reverse-geocoding chosen instead (grounding finding, 2026-06-16).** The obvious platform path for naming a GPS coordinate — MAUI `Geocoding.GetPlacemarksAsync` — was **rejected**: Microsoft Learn (grounded) states it **requires a Bing Maps API key on Windows** (the first target), which would introduce the **app's first secret** (forcing `SecureStorage`, Overriding Principle 1) **and** depend on the **retiring** Bing Maps platform. The brainstorm therefore chose a **keyless HTTP** reverse-geocoder (BigDataCloud, R1), preserving the **secret-free, keyless** posture established for Open-Meteo. **Honours** Principle 1 (no secret introduced); recorded because the platform alternative was explicitly declined.
- **R3 — Resolver widened to the full matrix (completes F5 R2; Roadmap/Context-aligned).** F5 deliberately shipped only the `Saved-or-absent` arms and named the completion as F6. F6 widens `resolve` to `(saved, detected)` and adds the "Detected only" and "Saved cleared → Detected" arms — a strict superset, so F5's tests pass unchanged (Seam 4). The matrix matches Context.MD *Active Location* verbatim. **No divergence.**
- **R4 — Eager, once-per-run, session-cached detection (brainstorming decision, 2026-06-16).** Roadmap F6 / Context.MD fix that the Detected Location is "re-derived every run, never persisted" but not **when** within a run it runs relative to a Saved Location. The Feature owner chose **eager detection at startup regardless of any Saved Location**, cached in **session memory**, over lazy/on-demand detection — so the detected fallback is ready the instant a Saved Location is cleared, at the cost of one detection per launch even for Saved-Location Users (GPS permission is a one-time OS grant). A lifecycle shape, **not** a scope change; recorded because the lazy alternative was declined.
- **R5 — A `Coordinates` value type + reverse-geocode-failure degradation (design decision).** Context.MD distinguishes a "raw device position" from a named Location ("a position becomes a Detected Location only once resolved to a named place"). F6 introduces a small Core `Coordinates` type for the un-named GPS fix, and — when reverse-geocoding a present GPS fix **fails** — **degrades** to a coordinate-derived label on the **retained** GPS coordinates rather than discarding a usable position or falling to the less-accurate IP branch. A minor, **logged** tension with "named place" (a coordinate-labelled Detected Location). **Consistent** with the glossary's position-vs-Location distinction; recorded because the degradation rule is a deliberate choice.
- **R6 — A *third* typed HTTP client; Overriding Principle 3 unaffected (consistent).** Principle 3 mandates **one** typed client for **weather-provider** access (`IWeatherService`). `IGeoNamingClient` is a **distinct concern** (reverse-geocoding + IP geolocation) on a **different host** (`api.bigdatacloud.net`), exactly as F5's `IGeocodingService` was a second client for a distinct concern (its R5). Adding it **honours**, not violates, Principle 3. Its **first-contact auth** (keyless) is pinned in Seam 1 (e). **No contradiction.**

## 8. Context references (load these for `/writing-plans` and the AFK Developer Agent)

- `Context.MD` — domain glossary: **Detected Location** (automatic, approximate, **re-derived not remembered**, absent when detection fails), **Active Location** (the full Saved-over-Detected-or-absent rule the widened resolver encodes), **Saved Location** (the override, read for the `saved` input), **Location** (coordinates + human-readable name — *"a position becomes a Detected Location only once resolved to a named place"*, the GPS-naming requirement), **Place Search** (the terminal fallback when detection fails), **User** (single-user). Governs test + type naming.
- `Technical-Context.MD` — **Overriding Principles 1–5** (Principle 1 secrets-in-`SecureStorage` stays **dormant** — keyless throughout; UI thread never blocks; **one *weather* client** — BigDataCloud is a third, distinct client per §7 R6; unit tests fake the provider/platform / E2E hits the real API; 100% gate with platform/UI excluded), **3rd-party tech** (**BigDataCloud `reverse-geocode-client`** + **Device GPS via MAUI Essentials** — both amended in this change), Packages (`IHttpClientFactory` + Microsoft.Extensions.Http.Resilience for the typed BigDataCloud client; System.Text.Json source-gen for its DTO; MAUI Essentials `Geolocation`/`Permissions`), Instrumentation (every detection call logged — amended), User Feedback (friendly nudge, no raw codes).
- `PRD.md` — stories **1–4** (detect on launch, no typing, GPS→IP→manual), **5** (one Active Location), **7** (Detected re-derived, never persisted), **13** (clear Saved → revert to Detected), **14** (detected-vs-saved legibility), **15** (Place Search overrides detection), **33–37** (loading/error/responsive/plain-language/friendly nudge), **41** (macOS-viable); *Implementation Decisions* (detection cascade as pure ordering logic; the geolocation client; the GPS abstraction; the resolver full matrix; the shell VM owning detect→resolve→fetch/empty).
- `docs/adr/0001-location-detection-cascade.md` — the cascade this Feature **implements** — **as amended by R1** (provider resolved to BigDataCloud).
- `docs/adr/0002-per-measurement-unit-defaults.md` — for awareness only; F6 touches no unit code (units ⊥ location).
- `docs/superpowers/specs/0005-place-search-and-saved-location.md` — the **Active Location resolver** (`resolve(saved)`, widened here), the **`ISavedLocationStore`** (read for `saved`), the **empty state** (terminal fallback), and the **shell VM resolve-on-activation** lifecycle (F5 Seam 5) F6 extends.
- `docs/superpowers/specs/0002-live-current-conditions.md`, `docs/superpowers/specs/0003-daily-forecast.md` — the combined `GetWeatherAsync`/`WeatherSnapshot` surface and the shell-VM state machine, reused **unchanged** (F6 only changes the `Location` fed in and adds the *detecting*/*detected* states).
- `docs/superpowers/specs/0001-blank-box-walking-skeleton.md` — the shell, coverage gate, project structure, and the "platform API stays in the excluded app head" pattern this Feature follows.
- `docs/seam-taxonomy.md` — the seam class vocabulary §5 uses (network-protocol + cross-process I/O + data-format for Seam 1; host-OS/runtime for Seam 2; in-process for Seams 3 & 5; pure for Seam 4; external first-contact auth pinned in Seam 1 (e); Seam 2 (e) grounded against Microsoft Learn).

## 9. Open questions / deferred to the Plan

- **`Location` name composition from BigDataCloud fields** — the agreed disambiguation content is `city` + `principalSubdivision` (iff non-empty) + a **tidied** `countryName` (the raw `countryName` is verbose, e.g. *"United Kingdom of Great Britain and Northern Ireland (the)"*); the exact tidy rule (use `countryCode`? trim the parenthetical?) and the empty-`city` fallback ordering are Plan/View details. The domain contract is only Seam 1's composite name + the empty-`city` fallback.
- **`GeolocationRequest` accuracy + timeout, and the cascade's overall budget** — the working choices are a modest accuracy and a short per-source timeout so a slow/absent GPS fix falls through promptly; exact values are Plan/UX tuning. The contract is only Seam 2 (absence on denial/null/timeout) and Seam 3 (short-circuit + at-most-once).
- **`localityLanguage` source** — the device language (e.g. `CultureInfo.CurrentUICulture.TwoLetterISOLanguageName`) supplied into Core as an **injected value** (never a platform call in Core, per Acceptance 8); the exact injection shape mirrors F5's geocoding `language` and F4's culture injection.
- **The "Detecting…" + detected-header copy and the chosen-vs-detected glyphs** — the states and markers are fixed (§4.7); exact wording and iconography are Plan/UI details (excluded app head).
- **Coordinate-label format for the degraded GPS case** — the fallback label when reverse-geocoding fails but a GPS fix exists (§7 R5); the exact text (e.g. rounded lat/long, or "Current location") is a Plan/UI detail. The contract is only Seam 3 (the fix is retained, not discarded).
- **Session Detected holder shape + startup hook** — an in-memory, session-scoped holder read by the shell VM (Seam 5); whether it is a tiny injected `IDetectedLocationSession` singleton or VM-owned field, and exactly where startup detection is kicked off (app lifecycle vs first activation), are Plan details. The contract is only Seam 5 (once per run, never persisted, activations read-only).
- **Captured fixture provenance + package versions** — the offline BigDataCloud fixtures must be **captured from real responses** at implementation time (Seam 1 (d)/(e)), incl. the IP-mode and empty-`city` cases; the geocoding `HttpClient` + resilience and `System.Text.Json` pieces pinned against the live feed, as in specs 0001–0005.

## Feature-doc-gauntlet sign-off

- **Status:** Pending — runs on the Spec **and** the Plan together, after `/writing-plans` produces the Plan and before `/enate-to-stories`. Not yet run for Feature 6.
