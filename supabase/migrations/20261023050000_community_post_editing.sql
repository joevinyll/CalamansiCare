begin;
-- Members can edit only their own post text, not ownership or engagement counts.
grant update(body) on public.community_posts to authenticated;
create policy "Members edit own post text" on public.community_posts
for update to authenticated
using(user_id = (select auth.uid()))
with check(user_id = (select auth.uid()));
commit;
