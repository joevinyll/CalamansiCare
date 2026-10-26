# CalamansiCare Supabase setup

## 1. Create the table

Easiest path for a capstone project (no Supabase CLI needed):

1. Open your project at https://supabase.com/dashboard
2. Go to **SQL Editor** → **New query**
3. Paste the contents of `migrations/20260823000000_create_diagnosis_reports.sql`
4. Run it

This creates `public.diagnosis_reports` with Row Level Security enabled and
one policy: the public `anon` key (used by the app on farmers' phones) can
**insert** reports but cannot read, update, or delete them — so one farmer's
phone can't see another farmer's submitted reports.

If you later add a web dashboard for the barangay agriculture office with
Supabase Auth login, uncomment the `authenticated` select policy at the
bottom of the migration so staff accounts can read submitted reports.

## 2. Get your project credentials

In the Supabase dashboard: **Project Settings → API**
- `Project URL` → goes in `SUPABASE_URL`
- `anon` `public` key → goes in `SUPABASE_ANON_KEY`

Never use the `service_role` key in the Flutter app — that key bypasses Row
Level Security and must never ship on a device.

## 3. Wire it into the Flutter app

Fill in the real values in `env/dev.json` (already git-ignored — see
`env/dev.example.json` for the template). Then run either:

```bash
flutter run --dart-define-from-file=env/dev.json
```

or use the "CalamansiCare (dev, Supabase env)" launch config in VS Code,
which already points at `env/dev.json`.

`DiagnosisRepository.initialise()` in `lib/data/diagnosis_repository.dart`
only calls `Supabase.initialize(...)` when both env values are non-empty, so
the app still runs fully offline (SQLite-only) if you skip this step —
queued reports will just sit in `queued_reports` until credentials are
provided and `syncQueuedReports()` is called again.

## 4. Report images

Run `report_images_setup.sql` in the Supabase SQL Editor. This adds
`image_url`, recreates `community_reports`, and creates the public
`report-images` storage bucket used by the app.

## 5. Farmer accounts and restore

Run `auth_setup.sql` in the Supabase SQL Editor. This adds:

- `public.farmer_profiles`
- `user_id` on reports
- authenticated report policies
- community report risk labels
- storage policies for signed-in uploads

After the original setup scripts have run, apply the migrations in
`supabase/migrations/` in timestamp order. They redact public community
identities and coordinates, restrict image writes to their owner, remove
legacy anonymous table access, and install the server-side email claim
ledger. The report owner can enter the recipient email address. Ownership,
consent, replay, and rate-limit checks are enforced, but the recipient is not
verified as an official barangay office.

In the Supabase dashboard, go to **Authentication → Providers**:

- Enable **Email** for email/password sign up and forgot password.
- Enable **Google** only after creating Google OAuth credentials.

For the app to log users in immediately after account creation, go to
**Authentication → Providers → Email** and turn off email confirmation. If email
confirmation is on, Supabase will require the farmer to confirm the email first,
then sign in.

For Android callbacks, add these redirect URLs in **Authentication → URL Configuration**:

```txt
io.supabase.calamansicare://login-callback/
io.supabase.calamansicare://reset-password/
```

If Google sign-in opens a page like `http://localhost:3000/?code=...`, the
Supabase auth redirect is still using the default local development URL. In
**Authentication → URL Configuration**, replace the localhost site URL with the
app callback and make sure the same callback is also in the redirect allow list:

```txt
Site URL:
io.supabase.calamansicare://login-callback/

Redirect URLs:
io.supabase.calamansicare://login-callback/
io.supabase.calamansicare://reset-password/
```

In Google Cloud OAuth, the authorized redirect URI remains the Supabase callback:

```txt
https://zulvusdgxegdiyulbiwv.supabase.co/auth/v1/callback
```

Farmers can still scan offline without an account. The app only requires
sign-in before uploading reports online. After reinstall, signing in restores
the saved farmer profile and synced reports from Supabase.

If a user clears app data or reinstalls, Settings are restored from
`farmer_profiles`. If that profile row is missing or incomplete, the app fills
missing farmer name, farm location, and barangay email from the user's latest
synced `diagnosis_reports` row.

## 6. Report email delivery

Run `report_email_setup.sql` in the Supabase SQL Editor. Then create these
Edge Function secrets:

- `BREVO_API_KEY`
- `FROM_EMAIL`

`BREVO_API_KEY` is preferred for this project because Brevo supports
transactional email and can verify a sender email address. `FROM_EMAIL` must
match the verified sender email in Brevo, for example
`CalamansiCare Reports <yourverifiedemail@gmail.com>`.

`SMTP2GO_API_KEY` is still supported, but SMTP2GO may require a work/domain
email during signup.

`RESEND_API_KEY` is still supported as a fallback, but Resend testing only
sends to the account owner's email unless you verify a domain.

Deploy the Edge Function in `functions/send-report-email` with gateway JWT
verification enabled. The function also validates each token with Supabase
Auth and calls the ownership, consent, rate-limit, and replay checks in
`claim_report_email` before accessing provider credentials. The recipient is
the address entered on the report and is not independently verified as an
official office address.

Report emails include the consented farm location, recipient, authenticated farmer email,
diagnosis, confidence, uploaded image, disease type, risk and priority. Device
identifiers are not displayed. High priority follows the app's HLB/Citrus Canker
classification; other recognized diseases use Medium, and healthy results use
Routine / No Risk without treatment sections. These are app triage labels, not
an official severity assessment. Delivery is one email per scan batch and
recipient (up to ten images), after all queued images in that batch upload.
Legacy scans without a batch ID remain individual reports.

### Updated report letter rollout

1. Run `migrations/20261027000000_report_scan_timestamps.sql` in this project's
   Supabase SQL Editor before running the updated app. It only adds a nullable
   `scanned_at` timestamp; it does not delete or rewrite existing reports.
2. Deploy the updated function from the repository root:

   ```powershell
   supabase functions deploy send-report-email --project-ref YOUR_PROJECT_REF
   ```

   Keep JWT verification enabled. Existing email-provider secrets remain in use;
   no new provider keys are required. Include the imported `care-content.ts` file.
3. Hot reload a running debug app, or rebuild/run an installed profile app, then
   send a new batch. The app now sends each saved diagnosis's actual timestamp.
   Old clients do not supply that timestamp; old emails cannot be changed.

The letter starts with the farmer's name and email, location and recipient,
followed by compact scan/submission timestamps in Philippine time. The farmer
email comes only from Supabase Auth's validated caller, never from request JSON
or the recipient field. It is not added to Community's public views.

The results table is followed immediately by a red warning when any image has
an HLB or Citrus Canker prediction. The notice explains the suspected bacterial
disease, asks staff to arrange prompt assessment and prevent spread, and warns
against ordering destructive or pesticide interventions solely from AI output.
An unknown label never hides an otherwise High priority batch.

Recommendations come before the photos, use coloured headings and highlighted
keywords, and split the existing guidance into bullets without changing it.
Healthy results have no disease-treatment section or high-risk warning.
All photos remain embedded at the bottom, labelled `Image N: Disease (Type)`,
with confidence, risk and each original scan time. They are not attachments.
Internal device/report identifiers remain in delivery records for replay
protection but are not displayed in the letter. Existing storage URLs are not
renamed; some older image URLs may still contain legacy identifiers.

Missing legacy scan timestamps explicitly show `Not recorded`; submission time
is never substituted for scan time. Email clients may require image loading
to be enabled before displaying the embedded photos.

The backend English guidance in `functions/send-report-email/care-content.ts`
mirrors `lib/data/treatment_content.dart`. Verify content parity and templates
with `node --test supabase/functions/send-report-email/template.test.mjs` from
the repository root. Deploy the updated `send-report-email` function, including
its imported content module, for changes to reach received emails. A Flutter
hot reload or Android build does not deploy email templates.

### Batch email rollout

1. Apply `migrations/20261022000000_batch_report_email.sql` in the SQL Editor
   of the app's Supabase project. It adds an ownership/consent-checked atomic
   batch claim, not a new report table. Do not rerun older setup SQL.
2. Deploy `send-report-email` with JWT verification enabled. Deploy the
   migration first: the updated function requires `claim_batch_report_email`.
3. Rebuild/restart the updated Flutter app. Old app versions still request
   single-image deliveries; only the new client submits the full batch.
4. Send a new batch and confirm one message containing all images. Existing
   emails cannot be merged retroactively.

Batch claims serialize per user, validate a single recipient and 1-10 unique
owned/consented report IDs, and rate-limit to ten delivery claims per hour.
All image claims are inserted together. Retries cannot re-email claimed
images. An ambiguous provider failure or partially claimed legacy batch needs
operator review rather than an automatic replay that could spam recipients.
The client retries uploads before requesting delivery and retains a failed
local queue state if the function rejects the batch. An already-claimed
response acknowledges an existing delivery attempt, not guaranteed receipt.

### Profile avatar persistence

For farmer-named report image folders, apply
`migrations/20261023010000_named_report_image_paths.sql` before using the updated
app. New objects use `reports/farmer-name/report-<opaque-id>.webp`; IDs are
SHA-256 hashes of the stable report identifier, so device identifiers and emails
are not exposed in the filename. Farmer names remain visible in public links.
Existing objects and emailed image links are not renamed or removed. The
migration preserves owner-only writes and also accepts the legacy flat paths.

Apply `migrations/20261022010000_profile_avatars.sql` to enable account avatar
restore alongside the other farmer profile settings. It adds a private
`profile-avatars` bucket and `farmer_profiles.avatar_object_path`. Storage
policies allow users to access only their own user-ID folder. Local file paths
are never stored in the remote profile. Photos are re-encoded before upload.
The current device keeps its local photo or pending removal; a fresh sign-in
on a device without a local avatar downloads the account photo. Signing out
clears the local cache, not the account's saved photo. Migration and real
upload/restore behavior must be verified against the target project.
