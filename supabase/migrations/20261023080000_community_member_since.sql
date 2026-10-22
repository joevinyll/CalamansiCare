begin;
-- Share only the join date of authors the signed-in viewer can already see.
create function public.community_member_since(member_id uuid)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select u.created_at from auth.users u
  where u.id = member_id and (select auth.uid()) is not null and (
    u.id = (select auth.uid())
    or exists(select 1 from public.community_posts p
      where p.user_id = u.id and p.visibility = 'community')
    or exists(select 1 from public.community_comments c
      join public.community_posts p on p.id = c.post_id
      where c.user_id = u.id and
        (p.visibility = 'community' or p.user_id = (select auth.uid())))
  );
$$;
revoke all on function public.community_member_since(uuid) from public, anon;
grant execute on function public.community_member_since(uuid) to authenticated;
commit;
