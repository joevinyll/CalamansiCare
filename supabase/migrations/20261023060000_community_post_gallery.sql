begin;
alter table public.community_posts add column image_paths text[] not null default '{}';
update public.community_posts set image_paths = array[image_path] where image_path is not null;

create function public.valid_community_image_paths(owner_id uuid, post_id uuid, paths text[])
returns boolean language sql immutable set search_path = '' as $$
  select cardinality(paths) between 0 and 5
    and (cardinality(paths) = 0 or array_ndims(paths) = 1)
    and not exists (
      select 1 from unnest(paths) with ordinality as images(path, image_index)
      where path is null or path <> owner_id::text || '/' || post_id::text ||
        case when image_index = 1 then '' else '-' || image_index::text end || '.webp'
    );
$$;
alter table public.community_posts add constraint community_gallery_valid
check(public.valid_community_image_paths(user_id, id, image_paths));

-- Keep the first image compatible with older app versions and existing checks.
create function public.community_normalize_gallery() returns trigger
language plpgsql set search_path = '' as $$
begin
  if cardinality(new.image_paths) = 0 and new.image_path is not null then
    new.image_paths := array[new.image_path];
  elsif cardinality(new.image_paths) > 0 then
    new.image_path := new.image_paths[1];
  end if;
  return new;
end; $$;
create trigger community_gallery_before_write
before insert or update of image_paths, image_path on public.community_posts
for each row execute function public.community_normalize_gallery();
grant insert(image_paths) on public.community_posts to authenticated;
commit;
