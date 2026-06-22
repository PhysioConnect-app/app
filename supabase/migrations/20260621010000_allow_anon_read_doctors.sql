-- ============================================================
-- Allow unauthenticated (anon) users to read doctor profiles
-- that have opted in to public discovery (show_in_search = true).
-- Required for the "Continue as Guest" flow on mobile, where no
-- Supabase session exists and the Find a Therapist screen must
-- still return results.
-- ============================================================

CREATE POLICY "doctors_anon_select"
  ON public.users FOR SELECT TO anon
  USING (role = 'doctor' AND show_in_search = true);
