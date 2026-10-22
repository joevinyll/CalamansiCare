# Community Feed Setup

## Feed Fails Despite Working Internet

If Supabase returns `42703: column community_posts.visibility does not exist`,
the connection works but the visibility migration is missing. Run
`supabase/migrations/20261023070000_community_post_visibility.sql` once in
SQL Editor (after the earlier Community migrations), then tap Retry in the app.
Do not make tables or image buckets public or grant anonymous reads to fix it.
The updated app distinguishes schema errors from connection failures.

## Database and Storage

1. Open the Supabase project used by `env/dev.json` (do not share its keys).
2. Open SQL Editor -> New query.
3. Run `supabase/migrations/20261023020000_community_feed.sql` once in full.
   The transaction creates four new Community tables, policies, indexes,
   validation and counter triggers, a private image bucket, and Realtime
   publication entries. It does not change diagnosis reports or email delivery.
4. Confirm these tables exist: `community_posts`, `community_comments`,
   `community_likes`, and `community_flags`.
5. Confirm Storage -> `community-images` is private, with a 5 MB limit and
   `image/webp` as its allowed MIME type. Leave the existing avatar bucket private.
   If the bucket already exists, run
   `supabase/migrations/20261023030000_community_image_size_limit.sql`
   to enforce these limits without changing existing files. New photos are
   re-encoded to WebP with a maximum 1280-pixel edge and checked against the
   5 MB limit before upload; files are not padded to 5 MB.
6. Under Database -> Publications -> `supabase_realtime`, confirm posts,
   comments, and likes are enabled. The migration adds them automatically.
7. Sign-in must already be configured in Authentication. No new Edge Function,
   provider secret, service-role key in Flutter, or email deployment is needed.
8. After the avatar and Community migrations, run
   `supabase/migrations/20261023040000_community_profile_sync.sql` once.
   Settings display names and profile photos now identify Community authors.
   It backfills existing posts/comments and updates them whenever the cloud
   profile changes. Realtime delivers those row updates to other members.
9. Run `supabase/migrations/20261023050000_community_post_editing.sql` once
   to enable editing. It grants updates only to the post body, with RLS
   restricting edits to the author; ownership and counters remain protected.
   My posts (article icon beside the bell) lists the signed-in author's posts,
   independently of the main feed's 50-post limit. Its post menu supports text
   editing and confirmed deletion. Editing retains the original photo.
   Pull down on the post list to fetch fresh data. Community randomly orders
   the 50 recent posts each visit/refresh and keeps that order stable during
   live updates. My posts remains newest-first. This is not random sampling
   of the entire historical database.
10. Run `supabase/migrations/20261023060000_community_post_gallery.sql`
    once before using the multi-image app. Posts accept up to five images;
    the database validates their count and owner/post-specific object paths.
    Each image is compressed and limited to 5 MB. Existing single-image posts
    are backfilled without moving their files. Next/previous arrows browse
    the gallery in the feed, My posts, comments, and edit preview. Deleting a
    post removes all its referenced images. Editing still changes text only.
11. Run `supabase/migrations/20261023070000_community_post_visibility.sql`
    once before using the visibility dropdown. Community means signed-in
    members (not anonymous internet users). Only Me posts are owner-readable
    through RLS, and remain accessible in My posts. Authors can change text
    and visibility in Edit post. Existing posts remain Community-visible.
    The migration restricts related comments/likes/flags and image downloads
    too. Never add a broad bucket read policy or make the bucket public.
    Test direct API reads and image URL creation from a second account, not
    only whether the UI hides a post.
    Changing to Only Me cannot retract content already loaded or downloaded;
    previously issued signed image URLs can remain valid for up to one hour.
    Other devices may retain an already-loaded public card until refreshing,
    since Realtime does not deliver newly private rows to unauthorized users.
12. Run `supabase/migrations/20261023080000_community_member_since.sql`
    once to enable the real Member since date in other members' profile
    overlays. The RPC exposes only account creation time, and only for an
    author whose posts/comments the viewer can already access. Your own
    date comes directly from your signed-in account. A missing date or RPC
    shows an unavailable state, never a fabricated date. No new profile-table
    read access or anonymous access is granted.

## Run the Updated App

```powershell
cd D:\Projects\CalamansiCare
flutter pub get
flutter run -d 14388d2d --dart-define-from-file=env/dev.json
```

Use a full restart, not only hot reload, after adding the new screens.

## Verify Live Behavior With Two Accounts

1. Sign in on two devices with different accounts. Open Community on both.
2. Publish text and a gallery/camera photo from account A. It should appear
   on B without refreshing. A disabled Post button/spinner prevents repeat taps.
3. Like/unlike on B; confirm the count changes on A. A user can like each
   target once. The counts are server-maintained, not client-editable.
4. Comment and reply on B. Open Comments on A and check the new text appears.
   Reply-to-parent validation rejects cross-post replies and deeper nesting.
5. Delete a comment/post as its author; verify removal on the other device.
   Other accounts must not be able to delete it, even through a direct API call.
6. Search by author or post text. Search currently covers the 50 recent posts
   loaded into the feed, not all historical content.
7. Open the bell: it shows live engagement counts on your recent posts. It is
   not OS push notifications and does not have an unread inbox.
8. Check offline/error behavior. Failed actions retain typed drafts. Posting
   requires an online signed-in account; diagnosis scanning remains offline.

## Privacy and Operations

- Posts are member-visible. The API exposes display names, author user IDs,
  text, timestamps, and engagement counts; no emails, farm addresses, report
  images are copied into posts.
- Community authors share their Settings name and profile photo with signed-in
  members. The avatar bucket stays private; the added read policy allows only
  avatar paths referenced by Community posts/comments, not all profile files.
  No member read access to private `farmer_profiles` rows is added.
  Initials are the fallback if no photo exists or a photo cannot load.
  Local Settings edits appear immediately for the author. Other devices update
  after the profile sync succeeds online. Existing signed URLs can remain valid
  for up to one hour after a photo is changed or removed.
- Community images use authenticated, one-hour signed URLs. Photos are
  decoded and re-encoded before upload to remove metadata.
- Photo-post creation uploads the image first. An ambiguous network failure
  can leave an unreferenced image; review Storage for orphan files periodically.
  A failed photo cleanup after post deletion likewise needs operator review.
- Report post creates an entry in `community_flags`; operators must review
  these in the Dashboard and remove abusive content. This is not an automated
  moderation or spam-detection system. Add moderation/rate limits before a
  large public rollout.
- Verify RLS and Storage policies with two real accounts before rollout.
  Local widget tests use a fake stream repository; they do not prove live
  database permissions, network transport, or Realtime publication settings.
- Rollback: disable access to the Community tab in the app first. Do not drop
  tables containing member content merely to undo a UI deployment.
