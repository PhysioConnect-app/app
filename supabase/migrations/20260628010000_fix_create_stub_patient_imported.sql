-- ============================================================
-- Drop 'imported' from create_stub_patient INSERT
--
-- The 'imported' column is defined in the initial schema but was never
-- added to the production users table (same situation as has_account).
-- Keep the p_imported parameter in the function signature so the Dart
-- call-site (rpc('create_stub_patient', params: {'p_imported': true}))
-- continues to work without a client-side change.
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_stub_patient(
  p_name        text,
  p_phone       text        DEFAULT '',
  p_diagnosis   text        DEFAULT '',
  p_dob         timestamptz DEFAULT NULL,
  p_imported    boolean     DEFAULT false   -- accepted but not written (column absent)
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
  IF (SELECT role FROM public.users WHERE id = v_doctor_id) <> 'doctor' THEN
    RAISE EXCEPTION 'caller is not a doctor';
  END IF;

  INSERT INTO public.users (
    id, name, role, doctor_ids,
    phone, primary_diagnosis, date_of_birth,
    created_at
  ) VALUES (
    v_patient_id,
    p_name,
    'patient',
    ARRAY[v_doctor_id],
    COALESCE(p_phone, ''),
    COALESCE(p_diagnosis, ''),
    p_dob,
    now()
  );

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
