-- Publish only a city or municipality in the community feed.
begin;

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
select id::text as id, disease, confidence,
  'Anonymous farmer'::text as farmer_name,
  public.city_only_report_location(farmer_location) as farmer_location,
  null::double precision as latitude, null::double precision as longitude,
  case
    when disease ilike '%HLB%' or disease ilike '%Greening%' or disease ilike '%Canker%' then 'High risk'
    when disease ilike '%Healthy%' or disease ilike '%Sooty%' then 'Low risk'
    else 'Medium risk'
  end as priority,
  image_url, coalesce(reported_at, received_at, created_at) as reported_at
from public.diagnosis_reports where consent = true;

revoke all on public.community_reports from anon, authenticated;
grant select on public.community_reports to anon, authenticated;

commit;
