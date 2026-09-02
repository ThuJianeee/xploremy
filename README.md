# XploreMY

XploreMY is a Flutter public-transport companion for Malaysia built around the
official `api.data.gov.my` GTFS APIs and Supabase authentication.

## Quick start

```bash
flutter pub get
flutter run
```

The project currently targets Android. Location and Internet permissions are
already declared in `android/app/src/main/AndroidManifest.xml`.

## What is implemented

| Area | Implementation |
| --- | --- |
| Auth | Email/phone registration, sign in/out, password reset/update, Supabase profile persistence |
| Nearby stops | Real device GPS, distance sorting, operator filters, list/map view |
| Static GTFS | Downloads and caches official GTFS ZIP feeds in SQLite |
| Correct service dates | Parses `calendar.txt` and `calendar_dates.txt` so only services running on the selected day are shown |
| Frequency schedules | Parses `frequencies.txt` and expands template trips at query time; this is essential for Rapid Rail KL |
| Stop detail | Correct upcoming schedule, route/destination, countdown, map and favourite stops |
| Realtime | Official GTFS-Realtime vehicle-position dots for operators that publish a stable feed |
| Offline | Cached static stops and schedules continue to work without Internet |

## Important realtime behaviour

The official data.gov.my GTFS-Realtime API currently publishes **vehicle
positions**. It does not currently provide public GTFS-RT TripUpdates for this
app to consume. Therefore XploreMY does **not fabricate live arrival times**:

- departure times/countdowns come from the official static GTFS schedule;
- live vehicle dots come from the GTFS-Realtime vehicle-position feed;
- operators without a stable realtime endpoint are clearly marked
  `Scheduled data only`.

Rapid Rail KL has an official static GTFS feed but the public realtime rail
feed is not currently documented as stable, so LRT/MRT/Monorail departures are
schedule-based.

## Why the timetable engine was changed

Rapid Rail KL includes `frequencies.txt`. Earlier code read only
`stop_times.txt`, which exposed template times such as `06:00` and `06:26` and
could incorrectly wrap a past departure by 24 hours. The current engine:

1. checks the service date using `calendar.txt` + `calendar_dates.txt`;
2. expands frequency windows using the template trip stop offset;
3. removes duplicate departures from overlapping service definitions;
4. converts GTFS times >= 24:00 to a real local `DateTime`;
5. labels tomorrow's service explicitly instead of silently adding 24 hours.

## Data sources

Static API pattern:

```text
https://api.data.gov.my/gtfs-static/<agency>
```

Realtime vehicle positions:

```text
https://api.data.gov.my/gtfs-realtime/vehicle-position/<agency>
```

`lib/core/config.dart` contains the supported operator endpoints, including
KTMB, Prasarana Rapid Rail/Bus services and the currently documented BAS.MY
services.

Static feeds are refreshed at most once per day unless the user forces a
refresh from **Offline data**.

## First run / database upgrade

SQLite schema version 2 adds service calendars and frequency windows. If an
older v1 cache exists, XploreMY clears that old timetable cache once because it
cannot produce trustworthy departures without those tables.

After upgrading, open **Offline data** and download the operator feed(s) you
want. XploreMY no longer silently inserts demo timetable data into the main
cache.

## Supabase

Client-side publishable Supabase settings live in `lib/core/config.dart`.
Never place a Supabase service-role key in the mobile app.

Expected tables:

- `profiles`: `id`, `full_name`, `phone`, `avatar_url`, `home_city`,
  `preferred_operator`
- `favourite_stops`: `user_id`, `stop_id`, `stop_name`, `operator`,
  `created_at`

## Tests and checks

Run before committing:

```bash
flutter analyze
flutter test
```

The existing unit tests cover GTFS time parsing, countdown formatting,
distance formatting and haversine calculations.

## Main project layout

```text
lib/
  core/        configuration, theme, geolocation helpers
  data/        GTFS API, SQLite cache, models, repository
  features/
    auth/      authentication screens + AuthService
    home/      nearby stops
    stop/      timetable + realtime vehicle map
    profile/   profile + saved stops
    data_sync/ official feed downloads
    shell/     bottom navigation
```
