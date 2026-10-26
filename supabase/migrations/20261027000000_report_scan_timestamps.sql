-- Keep capture/analysis time distinct from report-submission time.
begin;
alter table public.diagnosis_reports
  add column if not exists scanned_at timestamptz;
comment on column public.diagnosis_reports.scanned_at is
  'Original saved diagnosis timestamp. NULL for legacy reports without a recorded scan time.';
commit;
