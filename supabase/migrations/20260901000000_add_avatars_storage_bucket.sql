-- Adds the "avatars" Storage bucket used by ProfileShellScreen's new
-- profile-picture upload feature (see lib/repositories/
-- supabase_profile_repository.dart's uploadAvatar()).
--
-- profiles.avatar_url already exists (added in
-- 20260806000000_extend_arrival_itinerary_add_profiles_rsvp_favorites.sql)
-- — no table change needed here, just the bucket + its access policies.
--
-- Files are stored as avatars/{user_id}/avatar.jpg — a fixed filename per
-- user (re-uploads overwrite via upsert, not accumulate), so the RLS
-- policies below scope INSERT/UPDATE/DELETE to a user's own folder by
-- checking the path's first segment against auth.uid().

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Public read: avatars are shown across the app (not just to their owner),
-- and the bucket is public so the app can just use the plain public URL
-- returned by getPublicUrl() rather than a signed one.
DROP POLICY IF EXISTS "Public read access for avatars" ON storage.objects;
CREATE POLICY "Public read access for avatars" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
