-- ============================================================
-- AI Doctor Assistant — Phase 1
-- Three new tables: ai_config, ai_usage, ai_summary_cache
-- Plus an atomic-increment helper function used by the Edge Function.
-- ============================================================

-- ── ai_config ─────────────────────────────────────────────────────────────
-- Admin-controlled settings per user. Row is created by the admin (via
-- service role) when AI is assigned to a user. If no row exists for a user
-- the Edge Function falls back to enabled=true / 100 req/month defaults.

CREATE TABLE IF NOT EXISTS public.ai_config (
  user_id        uuid        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  enabled        boolean     NOT NULL DEFAULT true,
  monthly_limit  integer     NOT NULL DEFAULT 100,
  reset_day      integer     NOT NULL DEFAULT 1,       -- day of month to reset counters
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- ── ai_usage ──────────────────────────────────────────────────────────────
-- One row per (user, feature, month). The UNIQUE constraint makes upserts
-- safe; the atomic-increment function below is the only writer.

CREATE TABLE IF NOT EXISTS public.ai_usage (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  feature        text        NOT NULL,  -- 'SOAP_GENERATION' | 'PATIENT_HISTORY_SUMMARY' | ...
  month          text        NOT NULL,  -- 'YYYY-MM'
  requests_used  integer     NOT NULL DEFAULT 0,
  tokens_used    integer     NOT NULL DEFAULT 0,
  last_used_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, feature, month)
);

CREATE INDEX IF NOT EXISTS ai_usage_user_month_idx
  ON public.ai_usage (user_id, month);

-- ── ai_summary_cache ──────────────────────────────────────────────────────
-- Caches a generated patient-history summary so the therapist can view it
-- without burning an AI request. Invalidated by the Flutter client when
-- note_count in the cache is lower than the current clinical-notes count.

CREATE TABLE IF NOT EXISTS public.ai_summary_cache (
  patient_id     uuid        NOT NULL,
  doctor_id      uuid        NOT NULL,
  summary        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  generated_at   timestamptz NOT NULL DEFAULT now(),
  note_count     integer     NOT NULL DEFAULT 0,
  PRIMARY KEY (patient_id, doctor_id)
);

-- ── RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE public.ai_config        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_summary_cache ENABLE ROW LEVEL SECURITY;

-- Users read their own config (admin writes via service role)
CREATE POLICY "ai_config_select_own"
  ON public.ai_config FOR SELECT
  USING (auth.uid() = user_id);

-- Users read their own monthly usage counters
CREATE POLICY "ai_usage_select_own"
  ON public.ai_usage FOR SELECT
  USING (auth.uid() = user_id);

-- Doctors read cached summaries they generated
CREATE POLICY "ai_cache_select_doctor"
  ON public.ai_summary_cache FOR SELECT
  USING (auth.uid() = doctor_id);

-- Doctors write / update cached summaries they own
CREATE POLICY "ai_cache_upsert_doctor"
  ON public.ai_summary_cache FOR ALL
  USING (auth.uid() = doctor_id);

-- ── Atomic increment ──────────────────────────────────────────────────────
-- Called from the Edge Function (which runs with SUPABASE_SERVICE_ROLE_KEY)
-- to safely increment usage counters without race conditions.

CREATE OR REPLACE FUNCTION public.ai_increment_usage(
  p_user_id uuid,
  p_feature text,
  p_month   text,
  p_tokens  integer
) RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.ai_usage
    (user_id, feature, month, requests_used, tokens_used, last_used_at)
  VALUES
    (p_user_id, p_feature, p_month, 1, p_tokens, now())
  ON CONFLICT (user_id, feature, month) DO UPDATE
    SET requests_used = public.ai_usage.requests_used + 1,
        tokens_used   = public.ai_usage.tokens_used   + EXCLUDED.tokens_used,
        last_used_at  = now();
$$;
