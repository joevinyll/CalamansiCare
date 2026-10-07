alter table public.diagnosis_reports
add column if not exists image_url text;

drop view if exists public.community_reports;

create or replace view public.community_reports as
select
  id::text as id,
  disease,
  confidence,
  coalesce(nullif(farmer_location, ''), 'Barangay area') as farmer_location,
  case
    when disease ilike '%HLB%' or disease ilike '%Greening%' then 'High priority'
    when confidence >= 80 then 'Open'
    else 'Review'
  end as priority,
  device_signature,
  image_url,
  coalesce(reported_at, received_at, created_at) as reported_at
from public.diagnosis_reports
where consent = true;

insert into storage.buckets (id, name, public)
values ('report-images', 'report-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Allow report image uploads" on storage.objects;
drop policy if exists "Allow report image updates" on storage.objects;
drop policy if exists "Allow public report image reads" on storage.objects;

create policy "Allow report image uploads"
on storage.objects
for insert
to anon
with check (bucket_id = 'report-images');

create policy "Allow report image updates"
on storage.objects
for update
to anon
using (bucket_id = 'report-images')
with check (bucket_id = 'report-images');

create policy "Allow public report image reads"
on storage.objects
for select
to anon
using (bucket_id = 'report-images');
