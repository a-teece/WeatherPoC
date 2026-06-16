---
Status: accepted
---

# Per-measurement unit defaults come from CLDR unit preferences, not RegionInfo.IsMetric

WeatherPoC lets the User choose a Measurement Unit per kind of Weather Variable (temperature, wind speed, precipitation…) rather than one bundled metric/imperial switch, because real-world conventions are mixed — a UK User expects °C but mph. The locale-derived defaults are taken from Unicode CLDR `unitPreferenceData`, which has a dedicated `weather` usage and treats the UK as its own measurement system, because the BCL's `RegionInfo.IsMetric` is a single boolean that cannot express such mixes. Conversions and localized formatting use UnitsNet.

## Considered options
- **Bundled metric/imperial toggle** — trivial, but cannot represent °C-with-mph, so it is simply wrong for UK Users.
- **`RegionInfo.IsMetric`, applied per measurement** — still only metric-or-not; the UK resolves to all-metric (km·h⁻¹ wind), which is the exact bug being avoided.
- **Hand-curated region → units table** — works for a few regions but re-invents data CLDR already maintains, and drifts as conventions change.
- **CLDR `unitPreferenceData` (chosen)** — authoritative, per-usage (including `weather`), covers every region; the cost is a CLDR data dependency.

## Consequences
- Adds **UnitsNet** (conversion + formatting) and a **CLDR unit-preference data source** to the dependency set. The latter (e.g. `Porticle.CLDR.Units`) needs a spike to confirm it exposes the preference-routing API (usage + region → unit) before it is committed; otherwise embed the small CLDR slice required.
- A future maintainer must not "simplify" defaults back to `RegionInfo.IsMetric` — doing so silently breaks UK (and other mixed-convention) defaults. This ADR is the guardrail against that regression.
- The User's per-measurement overrides sit on top of the CLDR-derived defaults; CLDR provides only the starting point, not the final choice.
