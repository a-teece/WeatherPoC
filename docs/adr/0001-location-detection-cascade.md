---
Status: accepted
---

# Location detection cascades GPS → IP geolocation → manual search

To establish the Active Location with as little friction as possible, WeatherPoC tries device GPS first, falls back to IP-based geolocation when GPS is unavailable or denied, and only then asks the User to choose a place via Place Search. We accept a dedicated third-party IP-geolocation service as the cost of keeping location zero-touch even when the operating system withholds GPS.

## Considered options
- **GPS → manual search** (no IP service): one fewer dependency, but every GPS denial drops the User straight into a manual prompt on first run.
- **GPS → IP → manual search** (chosen): one extra third-party dependency, but most Users get a working Active Location without typing anything.

## Consequences
- A new third-party geolocation service joins the trust set and the **3rd-party tech** list in `Technical-Context.MD`. Per the testing principle it is faked in unit tests and exercised live only in end-to-end tests.
- IP geolocation is approximate (city-level); the resulting Detected Location is good enough for weather but not pinpoint.
- No additional privacy exposure in principle: the source IP is visible to every third party on any HTTP request regardless — this only adds one more party to that existing set, not a new class of leak.

## Provider resolved (amended 2026-06-16, Feature 6 spec — `docs/superpowers/specs/0006-automatic-location-detection.md`)
The provider deferred above is resolved to **BigDataCloud's keyless `reverse-geocode-client` endpoint**, grounded live 2026-06-16. It serves **both** cascade branches from one keyless HTTPS endpoint: called **with** the GPS coordinates it reverse-geocodes them to a named place (`lookupSource: "coordinates"`); called **without** coordinates it geolocates the caller's own IP (`lookupSource: "ip geolocation"`). This keeps the trust set to the **single** new third party this ADR anticipated, and keeps the app **keyless** (no secret, no `SecureStorage` — Overriding Principle 1 stays dormant). It also resolves a naming gap the cascade implies but this ADR did not name: a raw GPS fix is coordinates only and Context.MD requires a Detected Location to be a *named* place. The platform alternative — MAUI `Geocoding.GetPlacemarksAsync` — was **rejected** because on Windows (the first target) it **requires a Bing Maps API key** (introducing the app's first secret) and depends on the **retiring** Bing Maps platform.
