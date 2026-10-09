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

Deploy the Edge Function in `functions/send-report-email`. You can keep JWT
verification disabled because the function checks the report record from
Supabase and only sends data already stored by the app.
