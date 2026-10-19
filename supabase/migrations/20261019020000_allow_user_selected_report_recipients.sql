-- Recipients are entered by the report owner for their own barangay office.
-- Keep ownership, consent, replay protection, and rate limits; do not require
-- an operator-maintained global office list.
begin;

create or replace function public.claim_report_email(report_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  report public.diagnosis_reports%rowtype;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into report from public.diagnosis_reports
    where local_report_id = report_id and user_id = caller and consent = true
    for update;
  if not found then return jsonb_build_object('status', 'unavailable'); end if;
  if exists (select 1 from public.report_email_deliveries where local_report_id = report_id)
     or report.email_status = 'sent' then
    return jsonb_build_object('status', 'already_claimed');
  end if;
  if (select count(*) from public.report_email_deliveries
      where user_id = caller and claimed_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  insert into public.report_email_deliveries(local_report_id, user_id)
    values (report_id, caller);
  update public.diagnosis_reports set email_status = 'sending', email_error = null
    where local_report_id = report_id;
  return jsonb_build_object('status', 'claimed', 'report', jsonb_build_object(
    'local_report_id', report.local_report_id,
    'office_email', lower(trim(report.office_email)), 'disease', report.disease,
    'confidence', report.confidence, 'farmer_name', report.farmer_name,
    'farmer_location', report.farmer_location, 'device_signature', report.device_signature,
    'image_url', report.image_url, 'reported_at', report.reported_at));
end;
$$;

commit;
