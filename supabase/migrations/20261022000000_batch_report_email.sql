-- Claim every image atomically. A replay cannot send another copy of any image.
begin;
create or replace function public.claim_batch_report_email(report_ids text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  reports jsonb;
  total integer;
  claimed integer;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if cardinality(report_ids) not between 1 and 10
     or cardinality(report_ids) <> (select count(distinct x) from unnest(report_ids) x) then
    return jsonb_build_object('status', 'unavailable');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select count(*), jsonb_agg(to_jsonb(r) order by r.reported_at, r.local_report_id)
    into total, reports from public.diagnosis_reports r
    where r.local_report_id = any(report_ids) and r.user_id = caller and r.consent = true;
  if total <> cardinality(report_ids) then return jsonb_build_object('status', 'unavailable'); end if;
  if (select count(distinct lower(trim(r.office_email))) from public.diagnosis_reports r
      where r.local_report_id = any(report_ids)) <> 1
     or exists(select 1 from public.diagnosis_reports r where r.local_report_id = any(report_ids)
       and (r.office_email is null or trim(r.office_email) = '')) then
    return jsonb_build_object('status', 'unavailable');
  end if;
  select count(*) into claimed from public.report_email_deliveries where local_report_id = any(report_ids);
  if claimed = total then return jsonb_build_object('status', 'already_claimed'); end if;
  if claimed > 0 then return jsonb_build_object('status', 'partial_claim'); end if;
  if (select count(distinct claimed_at) from public.report_email_deliveries
      where user_id = caller and claimed_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  insert into public.report_email_deliveries(local_report_id, user_id)
    select unnest(report_ids), caller;
  update public.diagnosis_reports set email_status = 'sending', email_error = null
    where local_report_id = any(report_ids);
  return jsonb_build_object('status', 'claimed', 'reports', reports);
end;
$$;
revoke all on function public.claim_batch_report_email(text[]) from public, anon;
grant execute on function public.claim_batch_report_email(text[]) to authenticated;
commit;
