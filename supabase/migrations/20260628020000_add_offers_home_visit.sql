-- Add offers_home_visit to users if it does not already exist.
-- The column appears in the initial schema file but was absent from the
-- production database (same pattern as has_account / imported), so doctor
-- profile saves silently failed (saveProfile swallows errors) and the
-- find-doctors Home Visit filter never matched any rows.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS offers_home_visit boolean DEFAULT false;
