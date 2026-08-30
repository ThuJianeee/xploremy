# XploreMY

A unified Malaysian public transport companion built on MAMPU's DTSA open data
platform (`api.data.gov.my`), supporting **SDG 9: Industry, Innovation and
Infrastructure**.

## Quick start

```bash
flutter pub get
flutter run
```

Requires Flutter 3.22+ (Dart 3.4+).

## What's implemented

| Module | Where | Notes |
| --- | --- | --- |
| 1. Data & API layer | `lib/data/gtfs_api.dart`, `lib/data/local_store.dart`, `lib/data/transit_repository.dart` | Downloads GTFS-static ZIPs, parses `stops.txt` / `routes.txt` / `trips.txt` / `stop_times.txt`, caches everything in SQLite. Public API: `getNearbyStops()`, `getDeparturesForStop()`, `liveVehicles()`, `crowdLevel()`. |
| 2. Home / Nearby stops | `lib/features/home/home_screen.dart` | Geolocation via `geolocator`, list **and** OpenStreetMap map view, distance sorting, operator filter chips, adjustable radius. |
| 3. Stop detail / live departures | `lib/features/stop/stop_detail_screen.dart` | Route number, destination, ETA countdown, static route line on a map, live vehicle dots, reliability + crowding badges. |
| 4. User profiles | `lib/features/auth/*`, `lib/features/profile/profile_screen.dart` | Register with email **or** phone (SMS OTP), sign in, forgot password, edit profile, saved stops. |

### Reliability layer

`TransitRepository._estimateDelaySeconds()` matches a live GTFS-realtime vehicle
to its trip, finds the nearest scheduled stop on that trip, and compares the
scheduled time at that stop with the wall clock. The delta drives the
`On time / Late / Early` badge. "Usually crowded" comes from
`hourlyDensity()` — departures in the current hour versus the stop's peak hour.

### Offline mode (SDG 9.c)

Every static feed is written to SQLite (`xploremy_gtfs.db`). Once an operator is
downloaded from the **Offline data** tab, nearby stops and timetables work with
no connection. On very first launch a small built-in demo feed
(`lib/data/mock_feed.dart`, Kelana Jaya Line + a feeder bus) is loaded so the UI
is never empty.

## Data sources

All feeds are open and require no API key:

- GTFS-static: `https://api.data.gov.my/gtfs-static/{ktmb | prasarana?category=… | mybas-johor}`
- GTFS-realtime vehicle positions: `https://api.data.gov.my/gtfs-realtime/vehicle-position/…`

Operators are declared in `lib/core/config.dart` — add more categories there.

## Backend

Auth and profiles run on Supabase (Postgres + Auth). The publishable URL and
client key live in `lib/core/config.dart`; never place a service-role key or
other secret in the client.

Tables:

- `profiles` — `full_name`, `phone`, `avatar_url`, `home_city`, `preferred_operator`. A row is created automatically on sign-up by a database trigger.
- `favourite_stops` — `stop_id`, `stop_name`, `operator`, `nickname`.

To enable phone/SMS sign-up you must configure an SMS provider in the Cloud auth
settings; email/password works out of the box.

## Current limitations

- The archive contains the Flutter application layer only. Generate the native
  Android and iOS folders with `flutter create .` before running on a device,
  then apply the platform configuration below.
- Phone recovery sends an SMS OTP, but the current screens do not include an
  OTP sign-in flow. Email recovery uses the configured deep link.

## Platform setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Add the deep link for password resets inside the main `<activity>`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="xploremy" android:host="reset-password"/>
</intent-filter>
```

Set `minSdkVersion 23` in `android/app/build.gradle`.

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>XploreMY uses your location to show the transit stops closest to you.</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>xploremy</string></array>
  </dict>
</array>
```

## Tests

```bash
flutter test
```

`test/gtfs_parsing_test.dart` covers GTFS time parsing, haversine distance and
the countdown formatter.

## Project layout

```
lib/
  core/        config, theme, geo maths, location service
  data/        GTFS API client, SQLite store, repository, models, mock feed
  features/
    auth/      login, register, forgot password, AuthService
    home/      nearby stops (Module 2)
    stop/      stop detail + live departures (Module 3)
    profile/   profile management (Module 4)
    data_sync/ offline feed downloads
    shell/     bottom navigation
  widgets/     shared UI pieces
```
