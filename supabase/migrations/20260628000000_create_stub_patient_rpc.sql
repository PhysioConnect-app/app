-- ============================================================
-- Doctor stub-patient creation RPC
--
-- The tighten_rls migration (20260625000000) set INSERT on public.users
-- to service-role only.  Doctors must now create stub patient rows via
-- this SECURITY DEFINER function, which mirrors the pattern used by
-- doctor_add_patient / doctor_remove_patient.
--
-- Called from:
--   doctor_dashboard_screen.dart  – quick-add patient dialog
--   doctor_dashboard_screen.dart  – unified Excel import (_importUnifiedFromExcel)
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_stub_patient(
  p_name        text,
  p_phone       text        DEFAULT '',
  p_diagnosis   text        DEFAULT '',
  p_dob         timestamptz DEFAULT NULL,
  p_imported    boolean     DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doctor_id  uuid := auth.uid();
  v_patient_id uuid := gen_random_uuid();
  v_doc_ids    uuid[];
BEGIN
  -- Caller must be a doctor
  IF (SELECT role FROM public.users WHERE id = v_doctor_id) <> 'doctor' THEN
    RAISE EXCEPTION 'caller is not a doctor';
  END IF;

  -- Create the stub patient row (SECURITY DEFINER bypasses RLS INSERT restriction)
  INSERT INTO public.users (
    id, name, role, doctor_ids,
    phone, primary_diagnosis, date_of_birth,
    imported, created_at
  ) VALUES (
    v_patient_id,
    p_name,
    'patient',
    ARRAY[v_doctor_id],
    COALESCE(p_phone, ''),
    COALESCE(p_diagnosis, ''),
    p_dob,
    COALESCE(p_imported, false),
    now()
  );

  -- Atomically add the new patient to the doctor's assigned_patient_ids
  SELECT COALESCE(assigned_patient_ids, '{}') INTO v_doc_ids
    FROM public.users WHERE id = v_doctor_id FOR UPDATE;

  IF NOT (v_patient_id = ANY(v_doc_ids)) THEN
    v_doc_ids := v_doc_ids || v_patient_id;
  END IF;

  UPDATE public.users
    SET assigned_patient_ids = v_doc_ids,
        updated_at           = now()
    WHERE id = v_doctor_id;

  RETURN v_patient_id;
END;
$$;
