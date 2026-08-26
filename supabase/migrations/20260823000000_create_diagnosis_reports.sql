-- CalamansiCare: diagnosis_reports table
-- Matches the payload inserted by DiagnosisRepository.syncQueuedReports()
-- in lib/data/diagnosis_repository.dart:
--   local_report_id, office_email, disease, confidence, reported_at

create table if not exists public.diagnosis_reports (
  id bigint generated always as identity primary key,
  local_report_id bigint,
  office_email text not null,
  disease text not null,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  reported_at timestamptz not null,
  received_at timestamptz not null default now()
);

comment on table public.diagnosis_reports is
  'Farmer-submitted disease reports synced from the CalamansiCare Flutter app once the device is back online. SQLite on-device is the source of truth; this table is the barangay agriculture office''s copy.';

-- Helpful for the agriculture office dashboard (e.g. "show me all Citrus
-- Canker reports this week", or dedupe by device-local id).
create index if not exists diagnosis_reports_disease_idx
  on public.diagnosis_reports (disease);
create index if not exists diagnosis_reports_reported_at_idx
  on public.diagnosis_reports (reported_at desc);

-- Row Level Security: the app uses the public anon key on farmers' phones,
-- so anon must be able to INSERT, but should NOT be able to read back other
-- farmers' reports, or update/delete anything. Give the agriculture office
-- dashboard a separate authenticated/service role for reading.
alter table public.diagnosis_reports enable row level security;

drop policy if exists "Anon can submit diagnosis reports" on public.diagnosis_reports;
create policy "Anon can submit diagnosis reports"
  on public.diagnosis_reports
  for insert
  to anon
  with check (true);

-- Uncomment and adapt this once you have authenticated agriculture-office
-- accounts (e.g. via Supabase Auth) and want them to read submitted reports:
-- drop policy if exists "Authenticated staff can read reports" on public.diagnosis_reports;
-- create policy "Authenticated staff can read reports"
--   on public.diagnosis_reports
--   for select
--   to authenticated
--   using (true);
