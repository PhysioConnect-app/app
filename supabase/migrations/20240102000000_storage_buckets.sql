-- ============================================================
-- PhysioConnect – Storage Buckets
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Profile photos bucket (public read, authenticated write)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Chat images bucket (public read, authenticated write)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-images',
  'chat-images',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- ── Profile photos policies ───────────────────────────────────────────────

CREATE POLICY "profile_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-photos');

CREATE POLICY "profile_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'profile-photos');

CREATE POLICY "profile_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profile-photos');

CREATE POLICY "profile_photos_select"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'profile-photos');

-- ── Chat images policies ──────────────────────────────────────────────────

CREATE POLICY "chat_images_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'chat-images');

CREATE POLICY "chat_images_select"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'chat-images');
