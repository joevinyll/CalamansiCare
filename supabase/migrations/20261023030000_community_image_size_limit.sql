-- Safe to rerun after creating the Community bucket; existing files are unchanged.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/webp']::text[]
where id = 'community-images';
