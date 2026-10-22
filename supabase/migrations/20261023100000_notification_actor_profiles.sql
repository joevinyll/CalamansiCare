begin;
alter table public.community_notifications add column actor_avatar_path text;
create function public.community_notification_actor_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare p public.farmer_profiles;
begin
  select * into p from public.farmer_profiles where user_id = new.actor_id;
  if found then
    new.actor_name := left(coalesce(nullif(trim(p.farmer_name),''),'Farmer'),80);
    new.actor_avatar_path := case when split_part(p.avatar_object_path,'/',1) = new.actor_id::text
      then p.avatar_object_path else null end;
  end if;
  return new;
end; $$;
revoke all on function public.community_notification_actor_profile() from public, anon, authenticated;
create trigger community_notification_actor_before_insert before insert
on public.community_notifications for each row
execute function public.community_notification_actor_profile();

update public.community_notifications n set
  actor_name = left(coalesce(nullif(trim(p.farmer_name),''),'Farmer'),80),
  actor_avatar_path = case when split_part(p.avatar_object_path,'/',1) = n.actor_id::text
    then p.avatar_object_path else null end
from public.farmer_profiles p where p.user_id = n.actor_id;

create function public.community_sync_notification_actor() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.community_notifications set
    actor_name = left(coalesce(nullif(trim(new.farmer_name),''),'Farmer'),80),
    actor_avatar_path = case when split_part(new.avatar_object_path,'/',1) = new.user_id::text
      then new.avatar_object_path else null end
  where actor_id = new.user_id;
  return new;
end; $$;
revoke all on function public.community_sync_notification_actor() from public, anon, authenticated;
create trigger community_notification_profile_changed after update of farmer_name, avatar_object_path
on public.farmer_profiles for each row execute function public.community_sync_notification_actor();
create index community_notifications_actor on public.community_notifications(actor_id);
create policy "Recipients view notification actor avatars" on storage.objects
for select to authenticated using(bucket_id = 'profile-avatars' and exists(
  select 1 from public.community_notifications n where n.actor_avatar_path = name
));
commit;
