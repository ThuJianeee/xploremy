# XploreMY Enhanced Plus additions

This build extends `XploreMY_Enhanced_Full_Fixed2` with five requested feature groups.

## 1. Profile favorites folders (CRUD)
- Create, view, rename and delete custom favorites folders from Profile.
- Add/remove favorite stops.
- Add/remove saved planned journeys.
- Tap a stored stop to reopen Stop Detail.
- Tap a stored journey to restore it in Journey Planner.
- Folder data is isolated per signed-in user on the device using SharedPreferences.
- Supabase folder tables are also included in the SQL migration for future cross-device sync.

## 2. Trip timetable screen
- Select a departure in Stop Detail, then open **Timetable** from Route Timeline.
- Shows every stop in GTFS stop sequence with scheduled time.
- Highlights the current stop.
- Supports service-day times beyond midnight (`+1`).

## 3. Service alerts and per-operator feed health
- Alerts Centre is upgraded to Service Alerts.
- Each operator shows Fresh/Stale/Missing status, last sync, cached stop count, trip count and route count.
- Service notices can be read from the Supabase `alerts` table.
- Offline Data cards also show stop/trip/route cache counts.

## 4. Avatar upload
- Profile header now supports gallery avatar selection and removal.
- Avatar binary is uploaded to the Supabase Storage `avatars` bucket.
- `profiles.avatar_url` is updated and shown on the Profile screen.
- Storage bucket and RLS policies are included in `supabase/xploremy_enhanced.sql`.

## 5. Stop ratings and comments
- Stop Detail now contains Ratings & Comments.
- Signed-in users can create one 1–5 star review per stop, edit it, or delete it.
- Displays average rating, review count and recent comments.
- `stop_reviews` table, constraints, indexes and RLS policies are included in the SQL migration.

## Required setup
After pulling this version:

```bash
flutter pub get
flutter analyze
flutter test
```

Run `supabase/xploremy_enhanced.sql` in the Supabase SQL Editor before testing avatar upload, stop reviews, or stored service notices.
