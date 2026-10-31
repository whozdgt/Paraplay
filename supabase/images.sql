-- Music app: profile pictures and banners (GIF banners allowed).
-- Run ONCE: Supabase Dashboard > SQL Editor > New query > paste all of this > Run.
-- Safe to run again. If it shows an error, copy the message back to Claude.

-- ============ BUCKETS ============
-- avatars: still pictures, up to 2 MB (the app shrinks them to 512 x 512 first, so they are far smaller).
-- banners: still pictures or GIFs, up to 3 MB. GIFs are stored exactly as uploaded.
-- SVG is deliberately NOT allowed (an SVG file can carry scripts).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/png','image/jpeg','image/webp']),
  ('banners', 'banners', true, 3145728, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ============ WHO MAY TOUCH THE FILES ============
-- Files live in a folder named after the owner's id: <user-id>/avatar-123.jpg
-- Showing a picture needs no permission (the buckets are public, by address), but the address
-- only appears on a profile row the viewer is allowed to read. Listing and changing files is
-- limited to the owner, so other signed-in people cannot browse everybody's pictures.
drop policy if exists "avatars read" on storage.objects;
drop policy if exists "avatars read own" on storage.objects;
drop policy if exists "avatars write own" on storage.objects;
drop policy if exists "avatars update own" on storage.objects;
drop policy if exists "avatars delete own" on storage.objects;

create policy "avatars read own" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars write own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars update own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "banners read own" on storage.objects;
drop policy if exists "banners write own" on storage.objects;
drop policy if exists "banners update own" on storage.objects;
drop policy if exists "banners delete own" on storage.objects;

create policy "banners read own" on storage.objects for select to authenticated
  using (bucket_id = 'banners' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "banners write own" on storage.objects for insert to authenticated
  with check (bucket_id = 'banners' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "banners update own" on storage.objects for update to authenticated
  using (bucket_id = 'banners' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "banners delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'banners' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============ A PROFILE CAN ONLY POINT AT ITS OWN FILES ============
alter table public.profiles drop constraint if exists avatar_in_own_folder;
alter table public.profiles add constraint avatar_in_own_folder
  check (avatar_path is null or avatar_path like (id::text || '/avatar-%'));

alter table public.profiles drop constraint if exists banner_in_own_folder;
alter table public.profiles add constraint banner_in_own_folder
  check (banner_path is null or banner_path like (id::text || '/banner-%'));
