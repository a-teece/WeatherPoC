---
Status: accepted
---

# Location detection cascades GPS → IP geolocation → manual search

To establish the Active Location with as little friction as possible, WeatherPoC tries device GPS first, falls back to IP-based geolocation when GPS is unavailable or denied, and only then asks the User to choose a place via Place Search. We accept a dedicated third-party IP-geolocation service as the cost of keeping location zero-touch even when the operating system withholds GPS.

## Considered options
- **GPS → manual search** (no IP service): one fewer dependency, but every GPS denial drops the User straight into a manual prompt on first run.
- **GPS → IP → manual search** (chosen): one extra third-party dependency, but most Users get a working Active Location without typing anything.

## Consequences
- A new third-party IP-geolocation service (provider TBD; chosen at spec time) joins the trust set and the **3rd-party tech** list in `Technical-Context.MD`. Per the testing principle it is faked in unit tests and exercised live only in end-to-end tests.
- IP geolocation is approximate (city-level); the resulting Detected Location is good enough for weather but not pinpoint.
- No additional privacy exposure in principle: the source IP is visible to every third party on any HTTP request regardless — this only adds one more party to that existing set, not a new class of leak.
