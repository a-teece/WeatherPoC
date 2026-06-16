# WeatherPoC — Product Requirements (v1)

## Problem Statement

A person at their desktop wants to know what the weather is doing — right now and
over the next few days — for where they are, without ceremony. Existing options
get in the way: web weather pages are cluttered and ad-laden, OS widgets are
shallow, and almost every app forces a single "metric or imperial" switch that
cannot express how people in places like the UK actually read weather (°C for
temperature but mph for wind). The User also doesn't want to hand-type their
location every time they open the app, and doesn't want their habits or location
shipped off to an analytics service just to see a forecast.

In short: the User wants a clean, single-purpose desktop weather app that shows
the right place automatically, lets them correct or override it when needed,
displays current conditions and a short daily forecast, and respects the way
*they* personally read each kind of measurement — all while keeping their data on
their own machine.

## Solution

WeatherPoC is a single-user desktop application that shows the weather for exactly
one **Active Location** at a time.

On launch it establishes the Active Location with no typing required: it detects
where the User is (a **Detected Location**), and if it cannot, it asks the User to
pick a place via **Place Search**. The User can override detection at any time by
searching for a place and keeping it as their **Saved Location**, and can later
clear that override to fall back to detection again.

For the Active Location, WeatherPoC presents **Current Conditions** (the live,
right-now reading) and a **Daily Forecast** (today plus the following days, one
summary per day). Both are built from **Weather Variables** — temperature,
feels-like, humidity, wind, precipitation, and the categorical **Weather
Condition** shown as an icon and label.

Every Weather Variable is displayed in the **Measurement Unit** the User prefers,
chosen **independently per kind of measurement**. Defaults come from the User's
locale (so a UK User starts with °C and mph), and the User can override any single
unit without disturbing the others.

Everything that is purely diagnostic stays on the machine: there is no analytics
or crash-reporting service. The only data that leaves the device is the functional
API traffic needed to actually fetch weather, resolve place names, and approximate
location.

## User Stories

**Establishing the Active Location**

1. As the User, I want WeatherPoC to detect my location automatically on first
   launch, so that I see local weather without typing anything.
2. As the User, I want detection to try device GPS first, so that I get the most
   accurate Detected Location when my device can provide one.
3. As the User, I want WeatherPoC to fall back to IP-based geolocation when GPS is
   unavailable or I've denied location permission, so that I still get a working
   Detected Location without being dropped into a manual prompt.
4. As the User, I want to be asked to choose a place via Place Search only when
   automatic detection fails entirely, so that manual entry is the last resort,
   not the default.
5. As the User, I want WeatherPoC to show weather for exactly one Active Location
   at a time, so that the app stays focused and uncluttered.
6. As the User, when there is no Active Location yet (nothing detected and nothing
   chosen), I want a clear empty state that invites me to search for a place, so
   that I know what to do next instead of staring at a blank screen.
7. As the User, I want the Detected Location to be re-derived each run rather than
   remembered, so that the app follows me when I move between locations without
   stale data.

**Place Search and the Saved Location**

8. As the User, I want to search for a place by its human-readable name, so that I
   can pick the exact Location I care about.
9. As the User, I want Place Search to show me a list of matching named places when
   my query is ambiguous, so that I can disambiguate between places that share a
   name.
10. As the User, I want to choose a searched place as my Active Location, so that I
    can see weather somewhere other than where I am.
11. As the User, I want to keep a chosen place as my Saved Location, so that
    WeatherPoC opens on that place every time instead of re-detecting.
12. As the User, I want my Saved Location to persist across restarts, so that my
    deliberate choice survives closing the app.
13. As the User, I want to clear my Saved Location, so that the Active Location
    reverts to the Detected Location and the app tracks me automatically again.
14. As the User, I want it to be obvious whether I'm currently viewing a detected
    place or a place I chose, so that I'm never confused about why the location is
    what it is.
15. As the User, I want to use Place Search to set a location even when detection
    succeeded, so that I can deliberately look at somewhere else's weather.

**Current Conditions**

16. As the User, I want to see the current temperature at my Active Location, so
    that I know how warm or cold it is right now.
17. As the User, I want to see the "feels-like" (apparent) temperature, so that I
    can judge how it will actually feel outside.
18. As the User, I want to see the current Weather Condition as an icon and a
    label, so that I can grasp the weather at a glance.
19. As the User, I want to see current humidity, wind speed, wind direction, and
    precipitation, so that I have the detail I need to plan.
20. As the User, I want Current Conditions to reflect the present moment, so that I
    trust it as a live reading rather than a stale snapshot.
21. As the User, I want to refresh the weather on demand, so that I can get the
    latest reading without restarting the app.

**Daily Forecast**

22. As the User, I want to see a forecast for today and the following days, so that
    I can plan ahead.
23. As the User, I want each forecast day summarised as a high and low temperature
    plus an overall Weather Condition, so that I can scan the week quickly.
24. As the User, I want the first forecast day (today) to coexist with Current
    Conditions, so that I can see both today's high/low summary and the live
    reading without them contradicting each other.
25. As the User, I want each forecast day's Weather Condition shown as an icon and
    label, so that the week reads visually at a glance.

**Unit Preferences**

26. As the User, I want each kind of Weather Variable displayed in a unit I choose,
    so that the numbers match how I personally read weather.
27. As the User in the UK, I want temperature in °C but wind in mph by default, so
    that the app matches my local convention out of the box rather than forcing me
    into all-metric or all-imperial.
28. As the User, I want my default units derived from my device locale, so that the
    app is usable immediately without configuring anything.
29. As the User, I want to override the unit for any single measurement
    independently, so that I can read temperature in °C while keeping wind in mph
    (or any other mix) without one choice forcing the others.
30. As the User, I want my unit overrides to persist across restarts, so that I set
    them once.
31. As the User, I want changing a Measurement Unit to change only how the value is
    displayed, never the underlying reading, so that switching units back and forth
    is lossless and instant.
32. As the User, I want sensible unit choices offered for each measurement (e.g. °C
    or °F for temperature, mph or km·h⁻¹ for wind, mm or in for precipitation), so
    that I'm choosing from real options rather than free-typing.

**Feedback, errors, and trust**

33. As the User, I want a clear loading state while weather is being fetched, so
    that I know the app is working and hasn't frozen.
34. As the User, I want a friendly, actionable message when the weather service
    can't be reached, so that I know what happened and what to try next instead of
    seeing a raw error.
35. As the User, I want the app's interface to stay responsive at all times — never
    frozen while data loads — so that it always feels alive.
36. As the User, I want errors explained in plain language without error codes or
    stack traces, so that the app stays approachable.
37. As the User, I want to be told clearly when location detection failed and be
    guided to Place Search, so that a detection failure is a gentle nudge, not a
    dead end.
38. As the User, I want WeatherPoC to never send my usage habits or location to an
    analytics or crash-reporting service, so that using the app doesn't cost me my
    privacy.
39. As the User, I want diagnostic logs kept locally on my machine, so that
    problems can be investigated without my data leaving the device.

**Platform**

40. As the User, I want WeatherPoC to run as a native desktop app on Windows, so
    that it fits naturally into my desktop environment.
41. As the User, I want the app to be built so a macOS version can follow later, so
    that I'm not locked out if I switch platforms.

## Implementation Decisions

**Scope.** This is the single foundational PRD for WeatherPoC v1, covering the
whole product: Active Location resolution, Current Conditions and Daily Forecast
display, Place Search, and per-measurement Unit Preferences. It is intended to be
broken into sequenced Features by `/roadmap` next.

**Architecture.** .NET MAUI on .NET 10 (LTS), MVVM throughout. Views bind to
ViewModels; no business logic in code-behind. Windows is the first target; macOS
is a planned future target, so no Windows-only APIs without an abstraction.
Dependency injection via `MauiAppBuilder`.

The implementation is decomposed into deep modules with simple, testable
interfaces, separating pure domain logic from I/O:

- **Active Location resolver** — a pure module encoding the glossary rule: the
  Active Location is the Saved Location when one is set, otherwise the Detected
  Location; clearing the Saved Location reverts the Active Location to the Detected
  Location; the Active Location may be absent when neither exists. No I/O — it
  combines already-resolved inputs.
- **Location detection cascade** — orchestrates GPS → IP-geolocation → Place Search
  per **ADR 0001**, producing a Detected Location or signalling absence. It depends
  on a platform GPS position source (abstracted so macOS can follow) and an
  IP-geolocation client; the cascade ordering itself is pure logic over those
  sources.
- **Weather service (`IWeatherService`)** — the single typed client for all
  Open-Meteo weather access (**Overriding Principle 3**): given a Location, returns
  Current Conditions and a Daily Forecast as domain types. Encapsulates HTTP, JSON
  deserialization, and resilience. No ad-hoc `HttpClient` use anywhere else.
- **Geocoding service** — Place Search: a place-name query returns candidate named
  Locations via the Open-Meteo Geocoding API. Also routed through a typed client.
- **IP-geolocation client** — approximates the User's Location from their IP when
  GPS is unavailable. The concrete provider is **TBD and chosen at spec time** per
  ADR 0001; the module presents a stable interface regardless of provider.
- **Locale unit-default resolver** — maps the User's locale/region to a default
  Measurement Unit per kind of Weather Variable, sourced from Unicode CLDR
  `unitPreferenceData` with the `weather` usage, per **ADR 0002**. This is the
  guardrail against `RegionInfo.IsMetric`: it must express mixed conventions such
  as the UK's °C-with-mph. A pure module.
- **Weather Variable formatter** — converts a raw canonical value into the User's
  chosen Measurement Unit and produces a localized display string using UnitsNet.
  Pure; changing the unit is a display concern only and never mutates the
  underlying value.
- **Saved Location store** and **Unit Preferences store** — persist the User's
  deliberate choices (the Saved Location, and per-measurement unit overrides layered
  on top of the CLDR-derived defaults) across runs. These hold no secrets, so they
  use ordinary local persistence, not `SecureStorage`. (`SecureStorage` remains the
  rule for any future keyed provider, telemetry DSN, or signing credential.)
- **ViewModels** — presentation/orchestration logic: a shell ViewModel drives the
  Active Location → fetch → display flow and owns inline loading / empty / error
  state; dedicated ViewModels back Current Conditions, the Daily Forecast, Place
  Search, and the Unit Preferences settings surface.
- **Views (XAML)** + **DI composition root** + **Serilog wiring** — thin, declarative
  binding and application bootstrap. *(The rolling-file **configuration** — the log path
  and the rolling/retention policy — is factored into a small, plain tested module so its
  on-disk write is unit-tested; only the **wiring** that registers Serilog with the host stays
  untestable bootstrap. See "Excluded from unit tests" below.)*

**Networking and resilience.** Weather, geocoding, and IP-geolocation access use
`IHttpClientFactory` typed clients with `Microsoft.Extensions.Http.Resilience`
(retry, timeout, circuit-breaker). Serialization uses source-generated
`System.Text.Json`. All such I/O is `async`; the UI thread never blocks (no
`.Result` / `.Wait()` / `.GetAwaiter().GetResult()` on the UI thread).

**Units.** Conversion and localized formatting use UnitsNet. The CLDR
unit-preference data source spike is **resolved** (Feature 4 brainstorm, 2026-06-16):
`Porticle.CLDR.Units` proved to be formatting-only with no usage+region→unit routing
API, so the required CLDR slice (`weather`/`wind`/`rainfall` usages) is **embedded** and
a pure resolver routes region→unit over it. The User's per-measurement
overrides always sit on top of the CLDR-derived defaults.

**Feedback.** The app's own UI is the only feedback channel: inline view state for
loading/empty/error, Snackbar/Toast (CommunityToolkit.Maui) for transient notices,
and dialogs for blocking errors that need acknowledgement. Tone is friendly and
actionable; raw error codes and stack traces go to the log only, never to the User.

**Logging and privacy.** Serilog writes to a rolling file in the per-user app-data
folder, with a Debug sink mirroring output in development. No telemetry leaves the
machine — there is no analytics or crash-reporting service. The local-only rule
governs diagnostics, not functional API calls: fetching weather, geocoding, and
IP-based location necessarily send requests (and the source IP) to third parties,
which is expected. Always logged regardless of level: every Open-Meteo call
(endpoint, response status, latency) and every unhandled exception.

## Testing Decisions

**What makes a good test here.** Tests assert observable behaviour through a
module's public interface, not its internals — given inputs and faked
collaborators, assert the outputs and externally visible effects. Tests are named
in the project's domain language (Active Location, Detected Location, Saved
Location, Current Conditions, Daily Forecast, Weather Variable, Measurement Unit,
Unit Preferences) so they read as statements about the product, not the code.
Refactoring a module's internals must not require rewriting its tests.

**The coverage gate.** Per Technical-Context Overriding Principle 5, 100% unit-test
coverage is a hard gate: new production code arrives with the unit tests that cover
it. Per Principle 4, unit tests never touch the network — the weather service,
geocoding service, and IP-geolocation client are always faked in unit tests; a
separate end-to-end suite exercises the real Open-Meteo, Geocoding, and
IP-geolocation endpoints deliberately.

**Modules unit-tested (all non-UI modules):**

- **Active Location resolver** — the full rule matrix: Detected only → Active is
  Detected; Saved set → Active is Saved; Saved cleared → Active reverts to Detected;
  neither present → Active absent.
- **Location detection cascade** — cascade ordering against faked GPS / IP sources:
  GPS success short-circuits; GPS denial/absence falls through to IP; both failing
  yields "no Detected Location" so the UI routes to Place Search (ADR 0001).
- **Locale unit-default resolver** — the convention cases that justify ADR 0002,
  above all UK → °C **and** mph (the `RegionInfo.IsMetric` regression this guards
  against), plus representative metric and US-customary locales, per Weather
  Variable kind.
- **Weather Variable formatter** — conversion + localized formatting for each unit
  option, and that changing the unit changes only the display string, never the
  underlying value.
- **Weather service** and **Geocoding service** — against a faked provider: correct
  mapping of provider responses to domain types (Current Conditions, Daily Forecast,
  candidate Locations), and friendly handling of provider failures/timeouts.
- **IP-geolocation client** — against a faked HTTP backend: success maps to a
  Detected Location; failure surfaces as absence to feed the cascade.
- **Saved Location store** and **Unit Preferences store** — round-trip persistence,
  clearing the Saved Location, and overrides layering correctly on top of defaults.
- **ViewModels** — behavioural tests of the Active Location → fetch → display flow
  and the loading / empty / error inline states, driven through faked services.

**Excluded from unit tests** (coverage-excluded as untestable UI/wiring): the XAML
Views, the DI composition root, and the Serilog **bootstrap** — i.e. the wiring that
registers Serilog with the host (`AddSerilog`, provider registration, the development-only
Debug sink). These are exercised by the end-to-end suite and manual verification.

The Serilog rolling-file **configuration** (the log path and the rolling/retention policy) is
**not** in this excluded set: it is factored into a small, plain module that is unit-tested with
a real on-disk round-trip, so it counts toward the 100% gate like any other production code. The
line is deliberate — *configuring* where and how logs are written is testable behaviour, while
*wiring* the configured logger into the MAUI host is untestable bootstrap.

**Prior art.** None yet — this is the first code in a greenfield repo, so this PRD
establishes the testing baseline. Stack: xUnit (runner), Moq (fakes), Awesome­
Assertions (fluent assertions), coverlet (the 100% coverage measurement). Later
work should follow these tests as the pattern.

## Out of Scope

- **Multiple simultaneous locations / a saved-locations list.** WeatherPoC shows
  exactly one Active Location at a time; there is no multi-location dashboard.
- **An hourly forecast view.** The Daily Forecast is one summary per day; there is
  no hour-by-hour breakdown.
- **Weather alerts, severe-weather warnings, radar/maps, air quality, pollen,** and
  other data beyond Current Conditions and the Daily Forecast.
- **A bundled metric/imperial "unit system" switch.** Units are chosen per
  measurement; there is deliberately no single toggle (ADR 0002).
- **Multi-user support, accounts, sign-in, or cloud sync.** WeatherPoC is
  single-user and local; preferences live on the one machine.
- **Analytics, crash reporting, or any telemetry leaving the device.**
- **macOS release.** The architecture keeps macOS viable (no Windows-only APIs
  without abstraction), but shipping it is a future target, not part of v1.
- **Choosing the concrete IP-geolocation provider** and **confirming the CLDR data
  package** — both are deferred to spec time / a spike per ADRs 0001 and 0002.
- **CI/CD pipeline, signing, and installer packaging** — release mechanics are
  separate from this product PRD.

## Further Notes

- **Today appears twice, by design.** Current Conditions and the first day of the
  Daily Forecast both cover today, at different granularities (a live instantaneous
  reading vs a high/low + overall-condition summary). This overlap is intentional;
  the UI should make the two read as complementary, not contradictory.
- **Detected vs Saved is a meaningful distinction.** The Detected Location is
  automatic and transient (re-derived each run, never persisted); the Saved
  Location is a deliberate, persisted choice that overrides detection until cleared.
  The UI should keep which one is active legible to the User at all times.
- **CLDR is the starting point, not the final say.** Locale-derived defaults seed
  the Unit Preferences; the User's overrides always win on top.
- **Privacy framing.** Adding the IP-geolocation provider introduces no new *class*
  of privacy leak — the source IP is already visible to every third party on any
  HTTP request — it only adds one more party to that existing set (ADR 0001).
- **Next step.** Run `/roadmap` to sequence this PRD into Features; each Feature
  then becomes a `/brainstorming` → Spec → Plan cycle.

> GitHub Issue: https://github.com/a-teece/WeatherPoC/issues/4
