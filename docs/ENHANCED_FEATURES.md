# XploreMY Enhanced Full

This build keeps the existing authentication, nearby stops, GTFS cache, route planner, saved stops, saved/recent journeys, profile and theme features and adds:

- XploreRewards: XP, level progression, daily streak, badges, missions and in-app rewards.
- Departure filtering by route and future departure date/time selection.
- Route timeline based on the selected GTFS trip.
- First/last service display for the chosen service date.
- Realtime vehicle detail cards, feed freshness and relevant trip/route/nearby filtering.
- Map legend for stop, route line and relevant realtime vehicle markers.
- Home/Work shortcuts plus travel preferences used to rank recommended journey options.
- Alerts Centre for offline data freshness and supported alert surfaces.
- Offline/Data Freshness summary.
- About & Data Sources screen documenting official GTFS/GTFS-Realtime and OpenStreetMap use.
- Supabase SQL/RLS migration in `supabase/xploremy_enhanced.sql` for future cross-device sync of rewards, journeys, preferences and alert read state.
- Additional automated tests for enhanced models/stores.

## Storage choices

Existing Supabase Auth/profile/favourite-stop behavior is preserved. New preference and reward features work immediately with local `SharedPreferences`, so the app does not require a database migration just to launch. The supplied Supabase SQL is an opt-in backend schema for cross-device sync.

## Validation note

The modification environment did not contain the Flutter or Dart CLI. Commands for `flutter pub get`, `flutter analyze` and `flutter test` were attempted but could not execute because `flutter` was not installed. A source-structure validation report is included in `docs/VALIDATION_REPORT.txt`.
