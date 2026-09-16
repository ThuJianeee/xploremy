# Admin Management Final

The admin area is opened from `More -> Admin dashboard` and is visible only when the signed-in profile has the `admin` role.

## Dashboard

The overview displays:

- Total users
- Pending reviews
- Open reports
- Active service alerts

The management section links to User Management, Review Moderation and Service Alert Management.

## User Management

Admin users can:

- View registered users
- Search by name, email or role
- See Active or Suspended status
- Suspend a normal user
- Restore a suspended user

Admin accounts are protected from suspension, including the currently signed-in admin account. Suspended users are rejected during sign-in and are signed out when the app refreshes a suspended profile.

## Review Moderation

The existing review workflow remains available:

- Pending reviews
- Approve
- Reject
- Hide
- Delete
- View reports
- Hide or delete reported reviews
- Dismiss reports

## Service Alert Management

Admin users can:

- Create an alert
- View all alerts including future and expired alerts
- Edit an alert
- Delete an alert
- Select an affected operator or All operators
- Select Info, Warning or Critical severity
- Set start time and optional end time

Active alerts continue to appear in the normal user `Service Alerts` screen.

## Supabase

Run the latest `supabase/xploremy_enhanced.sql` before testing these features. It adds suspension fields, admin RPC functions and admin-only alert write policies.
