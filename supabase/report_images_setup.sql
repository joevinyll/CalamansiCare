alter table public.diagnosis_reports
add column if not exists image_url text,
add column if not exists latitude double precision,
add column if not exists longitude double precision;

drop view if exists public.community_reports;

create or replace function public.city_only_report_location(location text)
returns text
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  segment text;
begin
  if location is null or btrim(location) = '' then
    return 'General area';
  end if;

  foreach segment in array string_to_array(location, ',') loop
    segment := btrim(segment);
    if segment ~* '^[[:alpha:]][[:alpha:] .-]* City$' then
      return segment;
    end if;
  end loop;

  foreach segment in array string_to_array(location, ',') loop
    if lower(btrim(segment)) = 'bansalan' then
      return 'Bansalan';
    end if;
  end loop;

  return 'General area';
end;
$$;
revoke all on function public.city_only_report_location(text) from public;
grant execute on function public.city_only_report_location(text) to anon, authenticated;

create or replace view public.community_reports as
select
  id::text as id,
  disease,
  confidence,
  'Anonymous farmer'::text as farmer_name,
  public.city_only_report_location(farmer_location) as farmer_location,
  null::double precision as latitude,
  null::double precision as longitude,
  case
    when disease ilike '%HLB%' or disease ilike '%Greening%' or disease ilike '%Canker%' then 'High risk'
    when disease ilike '%Healthy%' or disease ilike '%Sooty%' then 'Low risk'
    else 'Medium risk'
  end as priority,
  image_url,
  coalesce(reported_at, received_at, created_at) as reported_at
from public.diagnosis_reports
where consent = true;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-images', 'report-images', true, 5242880, array['image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/webp'];

drop policy if exists "Allow report image uploads" on storage.objects;
drop policy if exists "Allow report image updates" on storage.objects;
drop policy if exists "Allow public report image reads" on storage.objects;
drop policy if exists "Allow report image uploads" on storage.objects;
drop policy if exists "Allow report image updates" on storage.objects;
drop policy if exists "Public can read consented report images" on storage.objects;

create policy "Allow report image uploads"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'report-images' and owner_id = (select auth.uid())::text);

create policy "Allow report image updates"
on storage.objects
for update
to authenticated
using (bucket_id = 'report-images' and owner_id = (select auth.uid())::text)
with check (bucket_id = 'report-images' and owner_id = (select auth.uid())::text);

create policy "Public can read consented report images"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'report-images' and exists (select 1 from public.diagnosis_reports r
  where r.image_url like '%/report-images/' || storage.objects.name));
