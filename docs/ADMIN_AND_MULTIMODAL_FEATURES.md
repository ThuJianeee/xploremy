# XploreMY Admin + Multimodal Enhancements

## Bus ↔ Rail journey planning
The one-transfer planner now treats Bus ↔ Rail as a supported multimodal interchange. Rail covers LRT/MRT/KTM/Monorail-compatible GTFS route types. When a bus stop and rail stop are within a practical walking radius (up to 600 m), the planner can create a walking transfer between the two services.

Requirements:
- Both relevant operator GTFS feeds must be downloaded/refreshed.
- The journey must still fit the current direct/one-transfer planner scope.

## Stop ratings and comments
- Public average uses approved reviews only.
- Approved reviews are sorted so higher-rated comments appear first as Top comments.
- New/edited user reviews become Pending.
- The author can see the Pending/Rejected/Hidden state and moderation note.
- Approved reviews from other users can be reported.

## Admin review moderation
Admin dashboard: **More → Admin · Review Moderation**

Tabs:
- Pending
- Reports
- All

Admin actions:
- Approve
- Reject
- Hide
- Delete
- Hide/delete a reported review
- Dismiss a report

## Database security
- `profiles.role` supports `user` and `admin`.
- Normal users cannot promote themselves.
- RLS only exposes approved reviews publicly, plus the user's own review.
- Admins can inspect all review states and reports.
- New/edited normal-user reviews are forced back to `pending` by a database trigger.
