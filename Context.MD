# Domain Glossary

Precise definitions of the domain terms WeatherPoC uses. This is a glossary only — no implementation details, no architecture, no process. It exists so every conversation speaks the project's language from the first message.

## User
The individual using WeatherPoC on their desktop. WeatherPoC is single-user: there is one User per running instance, and all preferences — the Saved Location, the Unit System override — belong to that User.

## Active Location
The single Location whose weather is currently displayed. It is the Saved Location when the User has set one, otherwise the Detected Location. WeatherPoC shows weather for exactly one Active Location at a time — never several at once. The Active Location may be absent: until a Location has been detected or the User has chosen one via Place Search, there is no Active Location and no weather to show.

## Detected Location
A Location WeatherPoC determines automatically — without the User naming a place — by best-effort detection of where the User is. It is the default Active Location whenever the User has not set a Saved Location. Approximate by nature and not always available: when detection cannot place the User at all, there is no Detected Location and the User must choose one via Place Search. Not chosen by the User and not persisted — it is re-derived rather than remembered, which distinguishes it from a Saved Location.

## Location
A geographic point on Earth, identified by coordinates and carrying a human-readable place name, that weather can be reported for. It is the thing Current Conditions and a Daily Forecast attach to. Distinct from a raw device position: a position becomes a Detected Location only once it has been resolved to a named place.

## Place Search
Finding a Location by its human-readable place name so the User can choose one explicitly. It is how the User overrides the Detected Location, and the only way to obtain an Active Location when automatic detection fails. A Location chosen through Place Search and kept becomes the Saved Location.

## Saved Location
A Location the User has explicitly chosen — via Place Search — and persisted, overriding the Detected Location. While a Saved Location is set, it is the Active Location. Distinct from the Detected Location (automatic and transient) — a Saved Location is a deliberate, remembered choice.

## Current Conditions
The present-time weather at the Active Location: the set of Weather Variables describing the weather right now. Distinct from the Daily Forecast, which describes expected future weather rather than the present moment.

## Daily Forecast
The expected weather for upcoming days at the Active Location, expressed as one summary per day — each day being a set of Weather Variables such as high/low temperature and a Weather Condition. Distinct from Current Conditions (the present moment); not an hour-by-hour breakdown (WeatherPoC has no hourly view).

## Weather Condition
The categorical state of the weather at a point in time — clear, cloudy, rain, snow, fog, and so on — surfaced to the User as an icon and label. A particular kind of Weather Variable: where most Weather Variables are numeric measurements, a Weather Condition is a category.

## Weather Variable
An individual property of the weather — temperature, apparent ("feels-like") temperature, humidity, wind speed, wind direction, precipitation, and similar. Weather Variables are the building blocks that make up Current Conditions and each day of the Daily Forecast. The Weather Condition is the one categorical Weather Variable; the rest are numeric.

## Unit System
The set of measurement units in which Weather Variables are displayed — metric (°C, km·h⁻¹, mm) or imperial (°F, mph, in). WeatherPoC selects the Unit System automatically from the device locale by default, and the User may override that choice. A display concern only: it changes how a Weather Variable is shown, never the underlying value.
