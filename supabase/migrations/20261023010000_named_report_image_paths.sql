-- Keep existing objects readable and writable; allow new farmer-name folders.
begin;
drop policy if exists "Authenticated farmers can upload report images" on storage.objects;
drop policy if exists "Authenticated farmers can update report images" on storage.objects;
create policy "Authenticated farmers can upload report images" on storage.objects
for insert to authenticated with check (
  bucket_id = 'report-images' and owner_id = (select auth.uid())::text
  and (name ~ '^reports/[A-Za-z0-9_-]+\.webp$'
    or name ~ '^reports/[a-z0-9-]{1,64}/report-[a-f0-9]{64}\.webp$')
);
create policy "Authenticated farmers can update report images" on storage.objects
for update to authenticated
using (bucket_id = 'report-images' and owner_id = (select auth.uid())::text)
with check (
  bucket_id = 'report-images' and owner_id = (select auth.uid())::text
  and (name ~ '^reports/[A-Za-z0-9_-]+\.webp$'
    or name ~ '^reports/[a-z0-9-]{1,64}/report-[a-f0-9]{64}\.webp$')
);
commit;
