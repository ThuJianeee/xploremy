# Account deletion transition fix

Observed behavior: the Supabase account was successfully deleted and the app returned to Login, but Flutter briefly showed a red `_dependents.isEmpty` assertion.

Cause: the auth SDK could emit `signedOut` while the Account Settings route was still being disposed. That caused the top-level AuthGate to replace the signed-in app subtree during the same route teardown frame.

Fix:
1. The delete flow asks `AuthService` to defer AuthGate notifications.
2. Supabase account deletion and local sign-out complete normally.
3. User-specific local data is cleared on a best-effort basis.
4. Account Settings is popped back to the root route.
5. The flow waits for the current Flutter frame to finish disposing the route.
6. The deferred auth notification is released and AuthGate switches cleanly to Login.
