# XploreMY Final Fixes

This build is the final consolidated version based on `XploreMY_Enhanced_Admin_Full`.

## Requested fixes

### 1. Reset password deep link
- Added explicit `app_links` handling for `xploremy://reset-password`.
- Cold-start and already-running app links set the authentication gate to password-recovery mode.
- The reset-password screen waits until the Supabase recovery session is ready before accepting a new password.
- Android manifest already contains the `reset-password` custom-scheme intent filter.

Supabase Auth must allow both redirects:

```text
xploremy://login-callback
xploremy://reset-password
```

### 2. Saved Address Add crash
- Replaced the temporary bottom-sheet `TextEditingController` lifecycle with a dedicated stateful stop picker.
- Async search results use a request id so a stale response cannot update a disposed/replaced search state.
- Address save now catches failures and restores the Save button instead of leaving the screen stuck.
- Home/Work still synchronise with Journey Planner shortcuts.

### 3. Multiple reviews/comments per user
- Removed the one-user/one-stop unique database rule.
- New submissions use `insert` so each comment/review is independent.
- Users can write multiple reviews at the same stop.
- Users can edit/delete each of their own review rows independently.
- New and edited reviews are Pending until an admin approves them.

### 4. Review typing crash
- Replaced the temporary dialog controller with a dedicated stateful review editor dialog.
- The dialog owns/disposes its controller only when Flutter disposes the dialog widget.
- Multiline comment entry supports up to 500 characters.

### 5. Public rating logic
- All approved comments can be displayed.
- Only each user's latest approved rating contributes to the average rating.
- This allows multiple comments without letting one account multiply its rating weight.

### 6. Admin moderation
- Pending / Reports / All tabs remain available to admin accounts.
- Review cards explicitly show the comment, star rating, user reference, review reference, status and update time.
- Admin can Approve, Reject, Hide or Delete.
- Report handling supports Hide review, Delete review, or Dismiss report.
- Admin action failures now show a SnackBar instead of becoming unhandled async errors.

### 7. Security / RLS
- Reporters can insert reports and read their own reports.
- Only admins can update/resolve report status.
- Review ownership and admin moderation policies remain enforced by RLS and triggers.

## Additional stability audit fixes
- Global FilledButton/OutlinedButton themes no longer use an infinite minimum width (`Size.fromHeight`). They now use a finite `Size(0, 52)`, preventing layout failures when buttons are used in dialogs, rows or list tiles.
- Travel Preferences stop picker was converted to a controller-owning stateful sheet.
- Delete Account confirmation was converted to a controller-owning stateful dialog.
- Favorites Folder naming was already using a safe stateful dialog and remains intact.
- Bus ↔ Rail one-transfer planning and known pedestrian interchanges from the previous build are preserved.

## Database migration
Run the complete latest file:

```text
supabase/xploremy_enhanced.sql
```

The migration drops the old `stop_reviews_user_id_operator_id_stop_id_key` constraint, so multiple reviews per user/stop are allowed.

## Final v2 — Delete Account transition

- Fixed the transient Flutter `_dependents.isEmpty` assertion shown during a successful account deletion.
- `AuthService.deleteAccount()` can now defer its UI notification while Supabase signs the deleted user out.
- The Account Settings flow clears local user data, pops the deleting route, waits for Flutter to finish disposing it, and only then notifies the top-level AuthGate.
- The final result is still the same successful behavior (account deleted and Login shown), but without the intermediate red error screen.
- Local preference/cache cleanup is best-effort so a local cleanup failure cannot make a successfully deleted cloud account appear to have failed.


## Review edit rule (Final v3)
- Owners may edit a review only while it is Pending.
- Approved, Rejected, and Hidden reviews are read-only for the author and can only be deleted.
- Supabase RLS and trigger enforce the same rule server-side.
- The non-public section label now correctly includes Pending/Rejected/Hidden reviews.

## Final v5 - Planner saved-address integration

- Profile Saved Addresses are loaded into Route Planner and shown in a dedicated card.
- Every saved address can be applied explicitly as the From or To stop.
- Home/Work roles in Saved Addresses feed the Home → Work and Work → Home shortcuts.
- Planner refreshes saved addresses and travel preferences whenever the Planner tab is entered, so Profile changes appear without restarting the app.
- Added a Clear all action that resets the current planner inputs/results without deleting saved addresses, saved journeys or recent history.
