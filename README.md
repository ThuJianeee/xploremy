# XploreMY Final Submission

XploreMY is a Flutter Android application that combines Malaysian Government open transport data from `api.data.gov.my` with local SQLite caching, Supabase account services, OpenStreetMap, journey planning, stop information, realtime vehicle positions where available, reviews, moderation, profile management and offline data tools.

## Run

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

For a release check:

```bash
flutter build apk --release
```

## Main modules

| Member | Module | Main functions |
| --- | --- | --- |
| Wong Kah Jian | User Account & Profile Management | Register/login/logout, email verification, forgot/reset password, profile editing, avatar, saved-address CRUD, notification preferences, travel preferences, favorites-folder CRUD, saved stops, password change, delete account, theme |
| Thean Zhi Hao | Nearby Stops & Journey Planner | GPS/nearby stops, search/filter/map, direct journey, one-transfer journey, Bus↔Rail walking transfer, Saved/Recent Journeys, Saved Addresses in Planner, Home→Work / Work→Home shortcuts, Clear All, recommendation sorting |
| Yeoh Ka Hou | Stop Detail, Timetable, Realtime & Reviews | Stop detail, departure filter, future departures, first/last service, trip timetable, route timeline, realtime vehicle details/freshness/filtering, ratings/comments, review reports, admin moderation |
| Thu Jianee | GTFS Data, Offline & Service/Data Status | GTFS download/parsing, SQLite cache, sync, operator freshness, last sync, cached stop/trip/route counts, realtime feed support, Offline screen, Service Alerts, About & Data Sources |

## Navigation

```text
Nearby | Planner | Offline | Profile | More
```

`More` contains XploreRewards, Service Alerts, About & Data Sources, and the Admin Dashboard for admin accounts.

## Data management

- Official static GTFS: stops, routes, trips, stop times, calendars and frequencies.
- Official GTFS-Realtime vehicle positions for configured operators.
- SQLite for downloaded transport data and offline access.
- SharedPreferences for local-first user settings, rewards and selected personal features.
- Supabase Auth for authentication and password recovery.
- Supabase Database/RLS for profiles, favourite stops, reviews, reports, alerts and enhanced schema tables.
- Supabase Storage for user avatars.

## Supabase

Run `supabase/xploremy_enhanced.sql` in the project SQL Editor after the core `profiles` and `favourite_stops` setup exists.

Add these redirect URLs to Supabase Auth:

```text
xploremy://login-callback
xploremy://reset-password
```

To assign an admin account, use the SQL Editor with the required authenticated user UUID:

```sql
update public.profiles
set role = 'admin'
where id = '<AUTH_USER_UUID>';
```

The Flutter client uses a Supabase publishable key only. Do not place a service-role key in the application.

## Final functional scope

- Profile Saved Addresses can be used directly as Planner origin or destination.
- Home→Work and Work→Home shortcuts use saved Home/Work entries.
- Clear All resets current Planner inputs/results without deleting saved data.
- Journey Planner supports direct and one-transfer planning, including supported Bus↔Rail walking connections.
- Stop Detail supports current/future departures, first/last service, trip timetable and route timeline.
- Realtime vehicle positions are shown only for operators with configured realtime feeds.
- Users may submit multiple stop comments. Each submission is moderated before becoming public.
- Pending reviews can be edited/deleted. Approved, rejected and hidden reviews are delete-only for the owner.
- Public average rating uses each user's latest approved rating so repeated comments do not multiply one user's weight.
- Admin Dashboard shows total users, pending reviews, open reports and active service alerts.
- Admin User Management can search users and suspend or restore account access.
- Admin Service Alert Management supports create, read, edit and delete for operator notices.
- Admin can approve/reject/hide/delete reviews and handle user reports.
- Delete Account removes the authenticated Supabase account and returns safely to Login.

## Submission checks

The source version in this package has standalone source-code comments removed from Dart and SQL files to match the assignment requirement. URLs such as `https://...` remain because they are data values, not comments.

Before submission on your own machine, run the full Flutter commands above and confirm the live demo on an Android emulator/device. Also confirm the private GitHub repository shows active contributions from every group member and prepare the required presentation and appendices.
