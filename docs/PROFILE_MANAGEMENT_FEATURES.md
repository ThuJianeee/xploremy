# XploreMY Profile Management Additions

## Wong Kah Jian – User Account & Profile

### 1. Delete Account
- Profile -> Account settings -> Delete account.
- Requires typing `DELETE` before the destructive action is enabled.
- Calls `AuthService.deleteAccount()` -> Supabase RPC `delete_my_account()`.
- The RPC deletes only `auth.uid()` and does not expose a service-role key in Flutter.
- After successful deletion, local saved addresses, notification settings, favorites folders, Home/Work preferences, saved/recent journeys and XploreRewards are cleared.
- Apply `supabase/xploremy_enhanced.sql` before testing this function.

### 2. Saved Address Management (CRUD)
- Profile -> Saved addresses.
- Create, read, edit and delete saved places.
- Types: Home, Work, Other.
- The saved location is selected from downloaded GTFS stops/stations.
- Only one saved Home and one saved Work are kept as the active roles; replacing either converts the previous one to Other.
- Home/Work stay linked to Journey Planner shortcuts.

### 3. Notification Management
- Profile -> Notification management.
- Manage Service Disruption, Journey Reminder, Departure Reminder, Rewards/Missions and Data Freshness categories.
- Reminder lead time: 5, 10, 15 or 30 minutes.
- Current build stores these preferences locally/offline. Device OS notification permission remains controlled by Android/iOS settings.

### 4. Default Preferred Transport
- Profile -> Travel preferences.
- Options: Any transport, Rail, Bus.
- The selected default is persisted in `TravelPreferencesStore`.
- Journey Planner uses it when ranking `Recommended` route results.

## Backend additions

`supabase/xploremy_enhanced.sql` now also contains:
- `saved_addresses`
- `notification_preferences`
- `travel_preferences.default_transport`
- RLS policies for the new user-owned tables
- `delete_my_account()` secure self-service deletion RPC

The address/notification screens are local-first in this build; the Supabase tables are ready for future cross-device sync.
