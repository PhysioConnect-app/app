-- ============================================================
-- PhysioConnect – HEP (Home Exercise Program) Tables
-- Date: 2026-06-21
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hep_programs (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id   uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  patient_id  uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title       text        NOT NULL DEFAULT '',
  notes_en    text        NOT NULL DEFAULT '',
  status      text        NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active', 'archived')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
  -- No clinic_id column; ownership is doctor-centric.
  -- A nullable clinic_id FK can be added later without restructuring.
);

CREATE TABLE IF NOT EXISTS public.hep_items (
  id             uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  hep_id         uuid    NOT NULL REFERENCES public.hep_programs(id) ON DELETE CASCADE,
  exercise_id    text    NOT NULL,
  sets           integer NOT NULL DEFAULT 3  CHECK (sets           > 0),
  reps           integer NOT NULL DEFAULT 10 CHECK (reps           > 0),
  hold_sec       integer NOT NULL DEFAULT 2  CHECK (hold_sec       >= 0),
  freq_per_week  integer NOT NULL DEFAULT 7  CHECK (freq_per_week  BETWEEN 1 AND 7),
  custom_note_en text    NOT NULL DEFAULT '',
  sort_order     integer NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION public.hep_programs_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER hep_programs_updated_at
  BEFORE UPDATE ON public.hep_programs
  FOR EACH ROW EXECUTE FUNCTION public.hep_programs_set_updated_at();

CREATE INDEX IF NOT EXISTS idx_hep_programs_doctor_id  ON public.hep_programs (doctor_id);
CREATE INDEX IF NOT EXISTS idx_hep_programs_patient_id ON public.hep_programs (patient_id);
CREATE INDEX IF NOT EXISTS idx_hep_items_hep_id        ON public.hep_items    (hep_id);

ALTER TABLE public.hep_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hep_items    ENABLE ROW LEVEL SECURITY;

-- hep_programs ──────────────────────────────────────────────────────────────

CREATE POLICY "hep_programs_select"
  ON public.hep_programs FOR SELECT TO authenticated
  USING (doctor_id = auth.uid() OR patient_id = auth.uid());

CREATE POLICY "hep_programs_insert"
  ON public.hep_programs FOR INSERT TO authenticated
  WITH CHECK (doctor_id = auth.uid());

CREATE POLICY "hep_programs_update"
  ON public.hep_programs FOR UPDATE TO authenticated
  USING     (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

CREATE POLICY "hep_programs_delete"
  ON public.hep_programs FOR DELETE TO authenticated
  USING (doctor_id = auth.uid());

-- hep_items ─────────────────────────────────────────────────────────────────

CREATE POLICY "hep_items_select"
  ON public.hep_items FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.hep_programs p
      WHERE  p.id = hep_id
      AND   (p.doctor_id = auth.uid() OR p.patient_id = auth.uid())
    )
  );

CREATE POLICY "hep_items_insert"
  ON public.hep_items FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.hep_programs p
      WHERE  p.id = hep_id AND p.doctor_id = auth.uid()
    )
  );

CREATE POLICY "hep_items_update"
  ON public.hep_items FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.hep_programs p
      WHERE  p.id = hep_id AND p.doctor_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.hep_programs p
      WHERE  p.id = hep_id AND p.doctor_id = auth.uid()
    )
  );

CREATE POLICY "hep_items_delete"
  ON public.hep_items FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.hep_programs p
      WHERE  p.id = hep_id AND p.doctor_id = auth.uid()
    )
  );
