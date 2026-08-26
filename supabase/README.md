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
