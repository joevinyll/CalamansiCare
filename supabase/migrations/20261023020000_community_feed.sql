begin;
create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author_name text not null check(length(author_name) between 1 and 80),
  body text not null default '' check(length(body) <= 3000),
  image_path text,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now(),
  check(length(trim(body)) > 0 or image_path is not null),
  check(image_path is null or image_path = user_id::text || '/' || id::text || '.webp')
);
create table public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author_name text not null check(length(author_name) between 1 and 80),
  body text not null check(length(trim(body)) between 1 and 2000),
  parent_id uuid references public.community_comments(id) on delete cascade,
  like_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index community_posts_created on public.community_posts(created_at desc);
create index community_comments_post on public.community_comments(post_id, created_at);
create function public.check_community_reply() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.parent_id is not null and not exists (
    select 1 from public.community_comments c where c.id = new.parent_id
      and c.post_id = new.post_id and c.parent_id is null) then
    raise exception 'Reply must reference a top-level comment in this post';
  end if;
  return new;
end; $$;
create trigger validate_community_reply before insert or update on public.community_comments
for each row execute function public.check_community_reply();
create table public.community_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  post_id uuid references public.community_posts(id) on delete cascade,
  comment_id uuid references public.community_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  check((post_id is null) <> (comment_id is null)),
  unique(user_id, post_id), unique(user_id, comment_id)
);
create index community_likes_post on public.community_likes(post_id);
create index community_likes_comment on public.community_likes(comment_id);
create table public.community_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  created_at timestamptz not null default now(), unique(user_id, post_id)
);
alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes enable row level security;
alter table public.community_flags enable row level security;
revoke all on public.community_posts, public.community_comments, public.community_likes, public.community_flags from authenticated;
grant select, delete on public.community_posts, public.community_comments, public.community_likes to authenticated;
grant insert(id,user_id,author_name,body,image_path) on public.community_posts to authenticated;
grant insert(id,post_id,user_id,author_name,body,parent_id) on public.community_comments to authenticated;
grant insert on public.community_likes to authenticated;
grant insert on public.community_flags to authenticated;
revoke all on public.community_posts, public.community_comments, public.community_likes, public.community_flags from anon;
create policy "Members read posts" on public.community_posts for select to authenticated using(true);
create policy "Members create own posts" on public.community_posts for insert to authenticated with check(user_id = (select auth.uid()));
create policy "Members delete own posts" on public.community_posts for delete to authenticated using(user_id = (select auth.uid()));
create policy "Members read comments" on public.community_comments for select to authenticated using(true);
create policy "Members create own comments" on public.community_comments for insert to authenticated with check(user_id = (select auth.uid()));
create policy "Members delete own comments" on public.community_comments for delete to authenticated using(user_id = (select auth.uid()));
create policy "Members read likes" on public.community_likes for select to authenticated using(true);
create policy "Members like as themselves" on public.community_likes for insert to authenticated with check(user_id = (select auth.uid()));
create policy "Members remove own likes" on public.community_likes for delete to authenticated using(user_id = (select auth.uid()));
create policy "Members flag posts" on public.community_flags for insert to authenticated with check(user_id = (select auth.uid()));
create function public.community_update_counts() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  target_post uuid;
  target_comment uuid;
  delta integer := case when tg_op = 'INSERT' then 1 else -1 end;
begin
  if tg_table_name = 'community_comments' then
    target_post := case when tg_op = 'INSERT' then new.post_id else old.post_id end;
    update public.community_posts set comment_count = greatest(0,comment_count + delta) where id = target_post;
  else
    target_post := case when tg_op = 'INSERT' then new.post_id else old.post_id end;
    target_comment := case when tg_op = 'INSERT' then new.comment_id else old.comment_id end;
    if target_post is not null then
      update public.community_posts set like_count = greatest(0,like_count + delta) where id = target_post;
    else
      update public.community_comments set like_count = greatest(0,like_count + delta) where id = target_comment;
    end if;
  end if;
  return null;
end; $$;
revoke all on function public.community_update_counts() from public, anon, authenticated;
create trigger community_count_comments after insert or delete on public.community_comments
for each row execute function public.community_update_counts();
create trigger community_count_likes after insert or delete on public.community_likes
for each row execute function public.community_update_counts();
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('community-images', 'community-images', false, 5242880, array['image/webp']);
create policy "Members view community photos" on storage.objects for select to authenticated
using(bucket_id = 'community-images');
create policy "Members upload community photos" on storage.objects for insert to authenticated
with check(bucket_id = 'community-images' and (storage.foldername(name))[1] = (select auth.uid())::text
  and name ~ '^[a-f0-9-]+/[a-f0-9-]+\.webp$');
create policy "Members delete own community photos" on storage.objects for delete to authenticated
using(bucket_id = 'community-images' and owner_id = (select auth.uid())::text);
alter publication supabase_realtime add table public.community_posts;
alter publication supabase_realtime add table public.community_comments;
alter publication supabase_realtime add table public.community_likes;
commit;
