-- Storage buckets for the identity domain.
--
--   avatars           -- public bucket. Object name = {user_id}.png (flat,
--                         always overwritten -- no orphaned old avatars).
--                         2 MB limit, PNG only.
--   project-archives   -- private bucket. Object name =
--                         {owner_id}/{project_id}.tar.zst. No bucket-level
--                         size limit (falls back to the project plan's
--                         global upload cap). Direct client access is
--                         owner-only; team-member reads go through the
--                         projects edge function, which mints a signed URL
--                         with the service role after checking
--                         identity.projects RLS -- so cross-member access
--                         control lives in one place (the domain layer),
--                         not duplicated in Storage RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152, array['image/png']),
  ('project-archives', 'project-archives', false, null, array['application/zstd', 'application/octet-stream'])
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- avatars: public read, self-only write, flat {user_id}.png naming
-- ---------------------------------------------------------------------

create policy "avatars_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'avatars');

create policy "avatars_self_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.png');

create policy "avatars_self_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.png')
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.png');

create policy "avatars_self_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.png');

-- ---------------------------------------------------------------------
-- project-archives: owner-only direct access, {owner_id}/{project_id}.tar.zst
-- (team-member reads happen exclusively via signed URLs from the
-- projects edge function, not direct Storage access -- see note above).
-- ---------------------------------------------------------------------

create policy "project_archives_owner_read"
  on storage.objects for select
  to authenticated
  using (
  bucket_id = 'project-archives'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_archives_owner_write"
  on storage.objects for insert
  to authenticated
  with check (
  bucket_id = 'project-archives'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_archives_owner_update"
  on storage.objects for update
  to authenticated
  using (
  bucket_id = 'project-archives'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
  bucket_id = 'project-archives'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_archives_owner_delete"
  on storage.objects for delete
  to authenticated
  using (
  bucket_id = 'project-archives'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
