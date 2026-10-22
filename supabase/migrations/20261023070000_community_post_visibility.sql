begin;
alter table public.community_posts add column visibility text not null default 'community'
  check(visibility in ('community', 'only_me'));
grant insert(visibility), update(visibility) on public.community_posts to authenticated;
drop policy "Members read posts" on public.community_posts;
create policy "Members read visible posts" on public.community_posts
for select to authenticated using(visibility = 'community' or user_id = (select auth.uid()));

-- Restrictive policies also protect writes to a private post's related rows.
create policy "Comments require visible post" on public.community_comments
as restrictive for all to authenticated
using(exists(select 1 from public.community_posts p where p.id = post_id))
with check(exists(select 1 from public.community_posts p where p.id = post_id));
create policy "Likes require visible target" on public.community_likes
as restrictive for all to authenticated
using(
  exists(select 1 from public.community_posts p where p.id = post_id)
  or exists(select 1 from public.community_comments c where c.id = comment_id)
)
with check(
  exists(select 1 from public.community_posts p where p.id = post_id)
  or exists(select 1 from public.community_comments c where c.id = comment_id)
);
create policy "Flags require visible post" on public.community_flags
as restrictive for insert to authenticated
with check(exists(select 1 from public.community_posts p where p.id = post_id));

drop policy "Members view community photos" on storage.objects;
create policy "Members view visible community photos" on storage.objects
for select to authenticated using(bucket_id = 'community-images' and (
  (storage.foldername(name))[1] = (select auth.uid())::text
  or exists(select 1 from public.community_posts p where name = any(p.image_paths))
));
create index community_posts_visibility_created on public.community_posts(visibility, created_at desc);
commit;
