begin;
create table public.community_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  actor_name text not null,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  comment_id uuid references public.community_comments(id) on delete cascade,
  like_id uuid references public.community_likes(id) on delete cascade,
  kind text not null check(kind in ('like_post','like_comment','comment','reply')),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique(recipient_id, like_id), unique(recipient_id, comment_id, kind)
);
create index community_notifications_recipient on public.community_notifications(recipient_id, created_at desc);
alter table public.community_notifications enable row level security;
revoke all on public.community_notifications from anon, authenticated;
grant select on public.community_notifications to authenticated;
grant update(read_at) on public.community_notifications to authenticated;
create policy "Recipients read visible notifications" on public.community_notifications
for select to authenticated using(recipient_id = (select auth.uid()) and
  exists(select 1 from public.community_posts p where p.id = post_id));
create policy "Recipients mark notifications read" on public.community_notifications
for update to authenticated using(recipient_id = (select auth.uid()))
with check(recipient_id = (select auth.uid()));

create function public.community_notify_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  target_post uuid;
  target_owner uuid;
  reply_owner uuid;
  actor text;
  event_kind text;
begin
  if tg_table_name = 'community_comments' then
    target_post := new.post_id;
    select user_id into target_owner from public.community_posts where id = target_post;
    actor := new.author_name;
    if target_owner <> new.user_id then
      insert into public.community_notifications(recipient_id,actor_id,actor_name,post_id,comment_id,kind)
      values(target_owner,new.user_id,actor,target_post,new.id,'comment');
    end if;
    if new.parent_id is not null then
      select user_id into reply_owner from public.community_comments where id = new.parent_id;
      if reply_owner <> new.user_id and reply_owner <> target_owner then
        insert into public.community_notifications(recipient_id,actor_id,actor_name,post_id,comment_id,kind)
        values(reply_owner,new.user_id,actor,target_post,new.id,'reply');
      end if;
    end if;
  else
    if new.post_id is not null then
      target_post := new.post_id;
      select user_id into target_owner from public.community_posts where id = target_post;
      event_kind := 'like_post';
    else
      select post_id,user_id into target_post,target_owner from public.community_comments where id = new.comment_id;
      event_kind := 'like_comment';
    end if;
    select left(coalesce(nullif(trim(farmer_name),''),'Farmer'),80) into actor
      from public.farmer_profiles where user_id = new.user_id;
    if target_owner <> new.user_id then
      insert into public.community_notifications(recipient_id,actor_id,actor_name,post_id,like_id,kind)
      values(target_owner,new.user_id,coalesce(actor,'Farmer'),target_post,new.id,event_kind);
    end if;
  end if;
  return new;
end; $$;
revoke all on function public.community_notify_activity() from public, anon, authenticated;
create trigger community_comment_notification after insert on public.community_comments
for each row execute function public.community_notify_activity();
create trigger community_like_notification after insert on public.community_likes
for each row execute function public.community_notify_activity();
alter publication supabase_realtime add table public.community_notifications;
commit;
