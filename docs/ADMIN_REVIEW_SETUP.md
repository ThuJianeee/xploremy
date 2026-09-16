# Admin Review Moderation Setup

1. Run `supabase/xploremy_enhanced.sql` in Supabase SQL Editor.
2. Find the target account UUID in Authentication > Users.
3. Promote that profile:

```sql
update public.profiles
set role = 'admin'
where id = '<AUTH_USER_UUID>';
```

4. Sign out and sign in again, or refresh Profile, so the app reloads `profiles.role`.
5. Open **More → Admin · Review Moderation**.

The dashboard contains:
- **Pending**: new/edited reviews waiting for approval.
- **Reports**: reviews reported by users.
- **All**: all review moderation states.

Admin actions:
- Approve
- Reject
- Hide
- Delete
- Resolve report by hiding/deleting review
- Dismiss report

User flow:
- A user may write multiple reviews/comments for the same stop. Each submission is a separate row and starts as Pending.
- Admin Approve -> the comment appears publicly. Only the user's latest approved rating is counted in the public average, so multiple comments do not multiply one user's rating weight.
- Editing an approved review sends that review back to Pending.
- Other users can Report approved reviews.
- Users can edit/delete each of their own reviews independently and can still see pending/rejected/hidden statuses.
