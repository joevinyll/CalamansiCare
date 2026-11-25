begin;

alter table public.diagnosis_reports
  add column if not exists batch_id text,
  add column if not exists batch_total_count integer,
  add column if not exists batch_image_index integer;

-- A single email claim inserts all its report IDs in one transaction.
with delivery_batches as (
  select r.user_id, r.local_report_id, d.claimed_at,
    count(*) over batch as total,
    row_number() over (
      batch order by coalesce(r.scanned_at, r.reported_at), r.local_report_id
    ) - 1 as image_index
  from public.diagnosis_reports r
  join public.report_email_deliveries d
    on d.local_report_id = r.local_report_id and d.user_id = r.user_id
  window batch as (partition by d.user_id, d.claimed_at)
)
update public.diagnosis_reports r
set batch_id = 'delivery-' || extract(epoch from b.claimed_at)::text,
    batch_total_count = b.total::integer,
    batch_image_index = b.image_index::integer
from delivery_batches b
where r.user_id = b.user_id and r.local_report_id = b.local_report_id
  and b.total > 1 and r.batch_id is null;

commit;
