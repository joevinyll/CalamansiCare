-- Apply AFTER auth_setup.sql on existing installations. No report/image data
-- is deleted. Keep the public feed's column contract, but never publish PII.
begin;

-- The existing setup scripts define the same feed with a different column
-- order. Drop/recreate inside this transaction so the public field contract
-- remains intact while the latitude and longitude columns are added.
drop view if exists public.community_reports;
create view public.community_reports as
select id::text as id, disease, confidence,
  'Anonymous farmer'::text as farmer_name,
  'Barangay area'::text as farmer_location,
  null::double precision as latitude, null::double precision as longitude,
  case
    when disease ilike '%HLB%' or disease ilike '%Greening%' or disease ilike '%Canker%' then 'High risk'
    when disease ilike '%Healthy%' or disease ilike '%Sooty%' then 'Low risk'
    else 'Medium risk'
  end as priority,
  image_url, coalesce(reported_at, received_at, created_at) as reported_at
from public.diagnosis_reports where consent = true;
-- Deliberately owner-executed: the public projection is the sharing boundary.
-- Invoker mode would prevent farmers from seeing the community feed.
revoke all on public.community_reports from anon, authenticated;
grant select on public.community_reports to anon, authenticated;

drop policy if exists "Anon can submit diagnosis reports" on public.diagnosis_reports;
drop policy if exists "Allow report image uploads" on storage.objects;
drop policy if exists "Allow report image updates" on storage.objects;
drop policy if exists "Authenticated farmers can upload report images" on storage.objects;
drop policy if exists "Authenticated farmers can update report images" on storage.objects;
drop policy if exists "Public can read consented report images" on storage.objects;

update storage.buckets set file_size_limit = 5242880,
  allowed_mime_types = array['image/webp'] where id = 'report-images';

create policy "Authenticated farmers can upload report images" on storage.objects
for insert to authenticated with check (
  bucket_id = 'report-images' and owner_id = (select auth.uid())::text
  and name ~ '^reports/[A-Za-z0-9_-]+\.webp$'
);
create policy "Authenticated farmers can update report images" on storage.objects
for update to authenticated
using (bucket_id = 'report-images' and owner_id = (select auth.uid())::text)
with check (bucket_id = 'report-images' and owner_id = (select auth.uid())::text
  and name ~ '^reports/[A-Za-z0-9_-]+\.webp$');

-- Only operators/service_role maintain this list; never derive it from a
-- farmer profile or untrusted report. Seed verified offices before deployment.
create table if not exists public.report_email_offices (
  email text primary key check (email = lower(trim(email))),
  enabled boolean not null default true
);
alter table public.report_email_offices enable row level security;
revoke all on public.report_email_offices from public, anon, authenticated;
grant all on public.report_email_offices to service_role;

-- Separate from client-writable reports: changing email_status or a recipient
-- cannot reset a claim. No automatic replay after an ambiguous provider result.
create table if not exists public.report_email_deliveries (
  local_report_id text primary key references public.diagnosis_reports(local_report_id),
  user_id uuid not null references auth.users(id),
  claimed_at timestamptz not null default now()
);
create index if not exists report_email_deliveries_user_time
  on public.report_email_deliveries(user_id, claimed_at);
alter table public.report_email_deliveries enable row level security;
revoke all on public.report_email_deliveries from public, anon, authenticated;
grant all on public.report_email_deliveries to service_role;

create or replace function public.claim_report_email(report_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  report public.diagnosis_reports%rowtype;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  -- Serialize quota checks/claims per account, including simultaneous requests.
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into report from public.diagnosis_reports
    where local_report_id = report_id and user_id = caller and consent = true
    for update;
  if not found then return jsonb_build_object('status', 'unavailable'); end if;
  if exists (select 1 from public.report_email_deliveries where local_report_id = report_id)
     or report.email_status = 'sent' then
    return jsonb_build_object('status', 'already_claimed');
  end if;
  if not exists (select 1 from public.report_email_offices
      where email = lower(trim(report.office_email)) and enabled) then
    return jsonb_build_object('status', 'recipient_not_approved');
  end if;
  if (select count(*) from public.report_email_deliveries
      where user_id = caller and claimed_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  insert into public.report_email_deliveries(local_report_id, user_id)
    values (report_id, caller);
  update public.diagnosis_reports set email_status = 'sending', email_error = null
    where local_report_id = report_id;
  -- Snapshot prevents a concurrent report edit changing the authorized payload.
  return jsonb_build_object('status', 'claimed', 'report', jsonb_build_object(
    'local_report_id', report.local_report_id,
    'office_email', lower(trim(report.office_email)), 'disease', report.disease,
    'confidence', report.confidence, 'farmer_name', report.farmer_name,
    'farmer_location', report.farmer_location, 'device_signature', report.device_signature,
    'image_url', report.image_url, 'reported_at', report.reported_at));
end;
$$;
revoke all on function public.claim_report_email(text) from public, anon;
grant execute on function public.claim_report_email(text) to authenticated;

-- RLS controls rows, not columns. Protect delivery state while retaining the
-- existing report upsert API (including inserts that omit these fields).
create or replace function public.protect_report_email_state()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.email_status := 'pending'; new.email_sent_at := null; new.email_error := null;
    else
      new.email_status := old.email_status;
      new.email_sent_at := old.email_sent_at; new.email_error := old.email_error;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists protect_report_email_state on public.diagnosis_reports;
create trigger protect_report_email_state before insert or update on public.diagnosis_reports
for each row execute function public.protect_report_email_state();

commit;
