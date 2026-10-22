begin;
alter table public.community_posts add column author_avatar_path text;
alter table public.community_comments add column author_avatar_path text;

-- Publish only the display name and the author's own avatar, never farm details.
create function public.community_author_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare p public.farmer_profiles;
begin
  select * into p from public.farmer_profiles where user_id = new.user_id;
  if found then
    new.author_name := left(coalesce(nullif(trim(p.farmer_name), ''), 'Farmer'), 80);
    new.author_avatar_path := case when split_part(p.avatar_object_path, '/', 1) = new.user_id::text
      then p.avatar_object_path else null end;
  end if;
  return new;
end; $$;
revoke all on function public.community_author_profile() from public, anon, authenticated;
create trigger community_post_author before insert on public.community_posts
for each row execute function public.community_author_profile();
create trigger community_comment_author before insert on public.community_comments
for each row execute function public.community_author_profile();

create function public.community_sync_author_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare display_name text;
  avatar text;
begin
  display_name := left(coalesce(nullif(trim(new.farmer_name), ''), 'Farmer'), 80);
  avatar := case when split_part(new.avatar_object_path, '/', 1) = new.user_id::text
    then new.avatar_object_path else null end;
  update public.community_posts set author_name = display_name, author_avatar_path = avatar
    where user_id = new.user_id and (author_name, author_avatar_path) is distinct from (display_name, avatar);
  update public.community_comments set author_name = display_name, author_avatar_path = avatar
    where user_id = new.user_id and (author_name, author_avatar_path) is distinct from (display_name, avatar);
  return new;
end; $$;
revoke all on function public.community_sync_author_profile() from public, anon, authenticated;
create trigger community_profile_changed after insert or update of farmer_name, avatar_object_path
on public.farmer_profiles for each row execute function public.community_sync_author_profile();

update public.community_posts c set
  author_name = left(coalesce(nullif(trim(p.farmer_name), ''), 'Farmer'), 80),
  author_avatar_path = case when split_part(p.avatar_object_path, '/', 1) = c.user_id::text
    then p.avatar_object_path else null end
from public.farmer_profiles p where p.user_id = c.user_id;
update public.community_comments c set
  author_name = left(coalesce(nullif(trim(p.farmer_name), ''), 'Farmer'), 80),
  author_avatar_path = case when split_part(p.avatar_object_path, '/', 1) = c.user_id::text
    then p.avatar_object_path else null end
from public.farmer_profiles p where p.user_id = c.user_id;

-- Keep the bucket private; members may read only avatars attached to Community authors.
create policy "Members view community author avatars" on storage.objects
for select to authenticated using (
  bucket_id = 'profile-avatars' and (
    exists(select 1 from public.community_posts p where p.author_avatar_path = name)
    or exists(select 1 from public.community_comments c where c.author_avatar_path = name)
  )
);
create index community_posts_author on public.community_posts(user_id);
create index community_comments_author on public.community_comments(user_id);
commit;
