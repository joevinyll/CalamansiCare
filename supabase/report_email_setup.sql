alter table public.diagnosis_reports
add column if not exists email_status text default 'pending',
add column if not exists email_sent_at timestamptz,
add column if not exists email_error text;
