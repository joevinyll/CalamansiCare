-- Retire anonymous table access left by older manual Supabase setup scripts.
-- Public sharing remains available through the redacted community_reports view.
begin;

drop policy if exists "Allow community report read" on public.diagnosis_reports;
drop policy if exists "Allow report upload" on public.diagnosis_reports;
drop policy if exists "Allow report retry update" on public.diagnosis_reports;

commit;
