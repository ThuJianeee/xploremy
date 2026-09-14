# XploreMY

XploreMY is a Flutter public-transport companion for Malaysia built on official `api.data.gov.my` GTFS data, local SQLite caching, device location, OpenStreetMap tiles, and Supabase account services. The project supports SDG 9 by improving access to public-transport information through a unified mobile interface.

## Quick start

```bash
flutter pub get
flutter run
```

The final application targets Android with application ID `com.xploremy.app`. Internet and location permissions are declared in `android/app/src/main/AndroidManifest.xml`.

## Final features

| Area | Implementation |
| --- | --- |
| User account | Gmail-only registration and login, email verification, forgot password, password recovery, profile editing, password change, logout |
| Nearby stops | Device GPS, radius search, operator and rail/bus filters, list view and OpenStreetMap view |
| Route planner | Direct journeys, one-transfer journeys, walking-transfer estimation, recent journeys and saved journeys |
| Official GTFS | Downloads static GTFS feeds from `api.data.gov.my` and stores them in SQLite |
| Service calendar | Uses `calendar.txt` and `calendar_dates.txt` to show services that run on the selected date |
| Frequency schedules | Uses `frequencies.txt` when an operator publishes frequency-based service |
| Stop detail | Station information, scheduled departures, countdowns, route destination, service activity and route map |
| Realtime vehicles | Shows official GTFS-Realtime vehicle-position markers for operators with a configured public feed |
| Favourite stops | Saves and removes favourite stops through Supabase and opens them again from Profile |
| Offline data | Downloaded stops and timetables remain available without an Internet connection |
| Appearance | Light, dark and system theme modes |

## Departure and realtime behaviour

XploreMY separates scheduled departures from realtime vehicle information. Departure times are calculated from the official static GTFS timetable. Operators with a configured GTFS-Realtime vehicle-position feed can additionally show live vehicle markers. The app does not label a scheduled departure as a live arrival when realtime TripUpdates are unavailable.

Service activity on Stop Detail is a timetable-density indicator derived from the number of scheduled departures during the current hour compared with the busiest hour for that stop. It is not a passenger-count or crowd-measurement dataset.

## Route planner scope

The planner searches for direct journeys first. If no suitable direct journey is available, it can search for a one-transfer journey and estimate a short walking connection between nearby interchange stops. Walking-transfer time is an estimate based on stop distance rather than pedestrian turn-by-turn routing.

## Data sources

Static GTFS pattern:

```text
https://api.data.gov.my/gtfs-static/<agency>
```

Realtime vehicle positions pattern:

```text
https://api.data.gov.my/gtfs-realtime/vehicle-position/<agency>
```

Supported operator endpoints are defined in `lib/core/config.dart`. Static feeds are refreshed at most once per day unless the user forces an update from Offline data.

Map tiles are provided by OpenStreetMap and the application displays `© OpenStreetMap contributors` on map views.

## Supabase

Client-side publishable Supabase settings are stored in `lib/core/config.dart`. A service-role key must never be placed in the mobile application.

Expected tables:

- `profiles`: `id`, `full_name`, `avatar_url`, `home_city`, `preferred_operator`
- `favourite_stops`: `user_id`, `stop_id`, `stop_name`, `operator`, `created_at`

Authentication is Gmail-only at the application-validation layer. Password-reset and email-verification links use the custom `xploremy://` deep-link scheme.
For the final Supabase project, Email OTP/link expiration should be configured to `300` seconds so verification and password-reset links expire after five minutes.

## Team module ownership

| Member | Final module | Main responsibility |
| --- | --- | --- |
| Thu Jianee | Data & API / Offline Data | GTFS download, parsing, SQLite caching, service calendars, frequency data and offline synchronization |
| Thean Zhi Hao | Nearby Stops & Route Planner | GPS, nearby-stop discovery, filters, map view, direct journey planning, one-transfer planning and journey history |
| Yeoh Ka Hou | Stop Detail / Scheduled Departures & Realtime Vehicle Information | Stop detail, timetable retrieval, countdowns, route map, vehicle markers, service activity and favourite-stop integration |
| Wong Kah Jian | User Account & Profile | Gmail authentication, verification, forgot/reset password, profile editing, password change, theme and logout |

`lib/main.dart`, `lib/features/shell/app_shell.dart`, shared theme files and integration/testing are shared system-integration work.

## Main project layout

```text
lib/
  core/        configuration, theme, location and station helpers
  data/        GTFS API, SQLite store, models and transport repositories
  features/
    auth/      Gmail authentication and password recovery
    data_sync/ official GTFS feed download and offline management
    home/      nearby stops, filtering and map view
    planner/   direct and one-transfer journey planning
    profile/   profile, password change, theme and saved stops
    shell/     bottom navigation
    stop/      stop detail, timetable and realtime vehicle map
  widgets/     shared UI components
```

## Final checks

Run before submission:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --release
git diff --check
```

Recommended smoke-test flow:

```text
Register -> Verify email -> Login
Forgot password -> Reset password -> Login with new password
Profile -> Change password -> Logout -> Login with new password
Offline data -> Download operator feed
Nearby -> Search/filter -> Map -> Open stop
Stop Detail -> Departures -> Favourite
Planner -> Direct journey -> One-transfer journey -> Saved/recent journeys
Theme -> Light/Dark/System
```

## Enhanced Full build

The Enhanced Full variant adds XploreRewards, route/departure filtering, future departure lookup, trip timelines, first/last service information, realtime vehicle filtering/details/freshness, map legends, Home/Work travel preferences, Alerts Centre, expanded offline freshness reporting, and an About/Data Sources screen while retaining the original app flow.

See `docs/ENHANCED_FEATURES.md` for the feature map and `supabase/xploremy_enhanced.sql` for optional Supabase tables and RLS policies.
