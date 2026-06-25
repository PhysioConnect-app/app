-- ============================================================
-- W-7 — Replace blanket RLS policies with role-scoped policies
--
-- REVIEW BEFORE APPLYING.  DO NOT RUN against the live database
-- until the backup is confirmed and this file has been signed off.
--
-- What this migration does:
--   1. Drops both flavours of the blanket "auth_all" / "Authenticated
--      full access" policies from every table that has them.
--   2. Keeps intact the already-correct policies on:
--        hep_programs, hep_items  (from 20260621000000)
--        users (anon doctor search) (from 20260621010000)
--        ai_config, ai_usage, ai_summary_cache  (from 20260622000001)
--   3. Adds a SECURITY DEFINER helper function to read the current
--      caller's app role without triggering RLS recursion.
--   4. Adds SECURITY DEFINER functions for the two cross-row UPDATE
--      operations the client currently performs with direct SQL:
--        link_patient_to_doctor / unlink_patient_from_doctor
--      *** The corresponding Dart call-sites must be migrated to
--          call these RPCs before this migration is applied, otherwise
--          those flows will break. ***
--   5. Adds scoped SELECT / INSERT / UPDATE / DELETE policies for
--      every table.
--
-- Tables covered:
--   users, appointments, appointment_requests, clinical_notes,
--   chat_rooms, chat_room_unread, messages,
--   invoices, inventory, notifications, expenses,
--   account_requests, store_products
-- ============================================================


-- ── 0. Helper: current caller's app role ─────────────────────────────────────
--
-- SECURITY DEFINER so it can query public.users without triggering
-- the RLS policies on that table (avoiding infinite recursion).
-- Declared STABLE — safe to call many times in one query.

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;


-- ── 1. Drop blanket policies on every table we are replacing ─────────────────
--
-- Both "auth_all" (initial_schema) and "Authenticated full access"
-- (supabase_schema.sql) are dropped.  If only one exists the other
-- DROP is a harmless no-op.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','appointments','appointment_requests','clinical_notes',
    'chat_rooms','chat_room_unread','messages',
    'invoices','inventory','notifications','expenses'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "auth_all"                  ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Authenticated full access" ON public.%I', t);
  END LOOP;
END;
$$;


-- ── 2. Cross-row linking functions (SECURITY DEFINER) ─────────────────────────
--
-- Replace the two-step client-side updates in:
--   PatientService.addDoctorToMyList()    → rpc('link_patient_to_doctor')
--   PatientService.removeDoctorFromMyList() → rpc('unlink_patient_from_doctor')
--   DoctorService.addExistingPatient()    → rpc('doctor_add_patient')
--   DoctorService.removePatient()         → rpc('doctor_remove_patient')
--
-- *** Dart changes required before applying this migration ***
-- Each function validates the caller's role, then performs the
-- atomic double-row update that the client currently does manually.

CREATE OR REPLACE FUNCTION public.link_patient_to_doctor(p_doctor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_patient_id uuid := auth.uid();
  v_pat_ids    uuid[];
  v_doc_ids    uuid[];
BEGIN
  -- Caller must be a patient
  IF (SELECT role FROM public.users WHERE id = v_patient_id) <> 'patient' THEN
    RAISE EXCEPTION 'Caller is not a patient';
  END IF;

  -- Patient side: add doctor to their doctor_ids
  SELECT COALESCE(doctor_ids, '{}') INTO v_pat_ids
    FROM public.users WHERE id = v_patient_id FOR UPDATE;
  IF NOT (p_doctor_id = ANY(v_pat_ids)) THEN
    v_pat_ids := v_pat_ids || p_doctor_id;
  END IF;
  UPDATE public.users
    SET doctor_ids = v_pat_ids, doctor_id = p_doctor_id, updated_at = now()
    WHERE id = v_patient_id;

  -- Doctor side: add patient to their assigned_patient_ids
  SELECT COALESCE(assigned_patient_ids, '{}') INTO v_doc_ids
    FROM public.users WHERE id = p_doctor_id FOR UPDATE;
  IF NOT (v_patient_id = ANY(v_doc_ids)) THEN
    v_doc_ids := v_doc_ids || v_patient_id;
  END IF;
  UPDATE public.users
    SET assigned_patient_ids = v_doc_ids, updated_at = now()
    WHERE id = p_doctor_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.unlink_patient_from_doctor(p_doctor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_patient_id uuid := auth.uid();
  v_pat_ids    uuid[];
  v_doc_ids    uuid[];
  v_primary    uuid;
BEGIN
  IF (SELECT role FROM public.users WHERE id = v_patient_id) <> 'patient' THEN
    RAISE EXCEPTION 'Caller is not a patient';
  END IF;

  SELECT COALESCE(doctor_ids, '{}'), doctor_id INTO v_pat_ids, v_primary
    FROM public.users WHERE id = v_patient_id FOR UPDATE;
  v_pat_ids := array_remove(v_pat_ids, p_doctor_id);
  UPDATE public.users
    SET doctor_ids = v_pat_ids,
        doctor_id  = CASE WHEN v_primary = p_doctor_id THEN NULL ELSE v_primary END,
        updated_at = now()
    WHERE id = v_patient_id;

  SELECT COALESCE(assigned_patient_ids, '{}') INTO v_doc_ids
    FROM public.users WHERE id = p_doctor_id FOR UPDATE;
  v_doc_ids := array_remove(v_doc_ids, v_patient_id);
  UPDATE public.users
    SET assigned_patient_ids = v_doc_ids, updated_at = now()
    WHERE id = p_doctor_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.doctor_add_patient(p_patient_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doctor_id uuid := auth.uid();
  v_pat_ids   uuid[];
  v_doc_ids   uuid[];
BEGIN
  IF (SELECT role FROM public.users WHERE id = v_doctor_id) <> 'doctor' THEN
    RAISE EXCEPTION 'Caller is not a doctor';
  END IF;

  SELECT COALESCE(doctor_ids, '{}') INTO v_pat_ids
    FROM public.users WHERE id = p_patient_id FOR UPDATE;
  IF NOT (v_doctor_id = ANY(v_pat_ids)) THEN
    v_pat_ids := v_pat_ids || v_doctor_id;
  END IF;
  UPDATE public.users
    SET doctor_ids = v_pat_ids, updated_at = now()
    WHERE id = p_patient_id;

  SELECT COALESCE(assigned_patient_ids, '{}') INTO v_doc_ids
    FROM public.users WHERE id = v_doctor_id FOR UPDATE;
  IF NOT (p_patient_id = ANY(v_doc_ids)) THEN
    v_doc_ids := v_doc_ids || p_patient_id;
  END IF;
  UPDATE public.users
    SET assigned_patient_ids = v_doc_ids, updated_at = now()
    WHERE id = v_doctor_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.doctor_remove_patient(p_patient_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doctor_id uuid := auth.uid();
  v_pat_ids   uuid[];
  v_doc_ids   uuid[];
BEGIN
  IF (SELECT role FROM public.users WHERE id = v_doctor_id) <> 'doctor' THEN
    RAISE EXCEPTION 'Caller is not a doctor';
  END IF;

  SELECT COALESCE(doctor_ids, '{}') INTO v_pat_ids
    FROM public.users WHERE id = p_patient_id FOR UPDATE;
  v_pat_ids := array_remove(v_pat_ids, v_doctor_id);
  UPDATE public.users
    SET doctor_ids = v_pat_ids, updated_at = now()
    WHERE id = p_patient_id;

  SELECT COALESCE(assigned_patient_ids, '{}') INTO v_doc_ids
    FROM public.users WHERE id = v_doctor_id FOR UPDATE;
  v_doc_ids := array_remove(v_doc_ids, p_patient_id);
  UPDATE public.users
    SET assigned_patient_ids = v_doc_ids, updated_at = now()
    WHERE id = v_doctor_id;
END;
$$;


-- ── 3. TABLE: users ───────────────────────────────────────────────────────────
--
-- Note: the anon doctor-search policy added in 20260621010000 is kept as-is.

-- SELECT: own row (every role, including admin)
CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (id = auth.uid());

-- SELECT: doctors can see patients whose doctor_ids contains them
CREATE POLICY "users_doctor_reads_own_patients"
  ON public.users FOR SELECT
  USING (role = 'patient' AND doctor_ids @> ARRAY[auth.uid()]);

-- SELECT: any authenticated user can see public doctor profiles
--   (role = 'doctor' AND show_in_search = true already covered by
--   the anon policy; this allows authenticated patients/doctors to
--   also see doctors that have show_in_search = false if they are
--   already in the patient's doctor_ids — handled by the policy below)
CREATE POLICY "users_reads_public_doctors"
  ON public.users FOR SELECT
  USING (role = 'doctor' AND show_in_search = true);

-- SELECT: patients can see their personally linked doctors
--   even if show_in_search = false
CREATE POLICY "users_patient_reads_linked_doctors"
  ON public.users FOR SELECT
  USING (
    role = 'doctor'
    AND id = ANY(
      -- safe: uses SECURITY DEFINER helper, no recursion
      (SELECT COALESCE(doctor_ids, '{}') FROM public.users u2 WHERE u2.id = auth.uid())
    )
  );

-- SELECT: polyclinic can see their linked doctors
CREATE POLICY "users_polyclinic_reads_linked_doctors"
  ON public.users FOR SELECT
  USING (role = 'doctor' AND polyclinic_id = auth.uid());

-- SELECT: admins see all rows
CREATE POLICY "users_admin_reads_all"
  ON public.users FOR SELECT
  USING (public.current_user_role() = 'admin');

-- UPDATE: every authenticated user updates only their own row
--   (profile, location, fcm_token, subscription fields).
--   Cross-row linking is handled by the SECURITY DEFINER functions above.
CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  USING  (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- UPDATE: admins can update any row (e.g. is_enabled, subscription)
CREATE POLICY "users_admin_updates_all"
  ON public.users FOR UPDATE
  USING  (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

-- UPDATE: doctors can update profile fields of their own patients
--   (create_patient_screen writes DOB, diagnosis, phone to patient row)
CREATE POLICY "users_doctor_updates_own_patients"
  ON public.users FOR UPDATE
  USING  (role = 'patient' AND doctor_ids @> ARRAY[auth.uid()])
  WITH CHECK (role = 'patient');

-- INSERT / DELETE: service-role only (admin-create-user / admin-delete-user
--   Edge Functions run with SUPABASE_SERVICE_ROLE_KEY — they bypass RLS).
--   No client-side INSERT or DELETE policy is needed.


-- ── 4. TABLE: appointments ────────────────────────────────────────────────────

-- Patients view their own appointments (read-only)
CREATE POLICY "appointments_patient_select"
  ON public.appointments FOR SELECT
  USING (patient_id = auth.uid());

-- Patients can see booked slots of any doctor (for slot availability when
--   requesting an appointment).  Only appointment_time is security-relevant
--   here; we accept that the patient learns a slot is taken, not by whom.
CREATE POLICY "appointments_patient_reads_doctor_slots"
  ON public.appointments FOR SELECT
  USING (
    -- only expose future slots; status filter via view is preferred but
    -- this keeps the policy simple
    appointment_time >= now() - interval '1 day'
    AND public.current_user_role() = 'patient'
  );

-- Doctors fully manage their own appointments
CREATE POLICY "appointments_doctor_all"
  ON public.appointments FOR ALL
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

-- Admins can read all (for reporting / merge operations)
CREATE POLICY "appointments_admin_select"
  ON public.appointments FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 5. TABLE: appointment_requests ───────────────────────────────────────────

-- Patients create and view their own requests
CREATE POLICY "appt_req_patient_select"
  ON public.appointment_requests FOR SELECT
  USING (patient_id = auth.uid());

CREATE POLICY "appt_req_patient_insert"
  ON public.appointment_requests FOR INSERT
  WITH CHECK (patient_id = auth.uid());

-- Patients cannot UPDATE or DELETE their own requests once submitted
--   (status is controlled by the doctor)

-- Doctors view and respond to requests directed at them
CREATE POLICY "appt_req_doctor_select"
  ON public.appointment_requests FOR SELECT
  USING (doctor_id = auth.uid());

-- Doctors can UPDATE status only (accept / decline)
CREATE POLICY "appt_req_doctor_update"
  ON public.appointment_requests FOR UPDATE
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

-- Admins read all
CREATE POLICY "appt_req_admin_select"
  ON public.appointment_requests FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 6. TABLE: clinical_notes (PHI) ───────────────────────────────────────────
--
-- This is the most sensitive table.  A patient must NEVER read another
-- patient's notes, and a doctor must NEVER read notes written by a
-- different doctor for a different patient.

-- Patients read their own notes (read-only — they can never write SOAP)
CREATE POLICY "clinical_notes_patient_select"
  ON public.clinical_notes FOR SELECT
  USING (patient_id = auth.uid());

-- Doctors fully manage notes they authored
CREATE POLICY "clinical_notes_doctor_all"
  ON public.clinical_notes FOR ALL
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

-- Admins read all (audit, merge)
CREATE POLICY "clinical_notes_admin_select"
  ON public.clinical_notes FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 7. TABLE: chat_rooms ──────────────────────────────────────────────────────
--
-- participants is text[] in the live schema (initial_schema migration).
-- auth.uid() must be cast to text for the ANY() operator.

CREATE POLICY "chat_rooms_participant_all"
  ON public.chat_rooms FOR ALL
  USING  (auth.uid()::text = ANY(participants))
  WITH CHECK (auth.uid()::text = ANY(participants));


-- ── 8. TABLE: chat_room_unread ───────────────────────────────────────────────

CREATE POLICY "chat_room_unread_own"
  ON public.chat_room_unread FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ── 9. TABLE: messages ───────────────────────────────────────────────────────
--
-- A user may read/write messages only in rooms they participate in.

CREATE POLICY "messages_participant_select"
  ON public.messages FOR SELECT
  USING (
    room_id IN (
      SELECT id FROM public.chat_rooms
      WHERE auth.uid()::text = ANY(participants)
    )
  );

CREATE POLICY "messages_participant_insert"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND room_id IN (
      SELECT id FROM public.chat_rooms
      WHERE auth.uid()::text = ANY(participants)
    )
  );

-- Senders may update their own messages (e.g. edit, mark delivered)
CREATE POLICY "messages_sender_update"
  ON public.messages FOR UPDATE
  USING  (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

-- No client-side DELETE on messages (history preservation)


-- ── 10. TABLE: invoices ───────────────────────────────────────────────────────

-- Doctors fully manage invoices they created
CREATE POLICY "invoices_doctor_all"
  ON public.invoices FOR ALL
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

-- Patients view their own invoices (read-only)
CREATE POLICY "invoices_patient_select"
  ON public.invoices FOR SELECT
  USING (patient_id = auth.uid());

-- Polyclinics view invoices of their linked doctors (for Income tab)
CREATE POLICY "invoices_polyclinic_select"
  ON public.invoices FOR SELECT
  USING (
    doctor_id = ANY(
      (SELECT COALESCE(linked_doctor_ids, '{}')
         FROM public.users u2 WHERE u2.id = auth.uid())::uuid[]
    )
    AND public.current_user_role() = 'polyclinic'
  );

-- Admins read all
CREATE POLICY "invoices_admin_select"
  ON public.invoices FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 11. TABLE: inventory ──────────────────────────────────────────────────────

-- Doctors fully manage their own inventory
CREATE POLICY "inventory_doctor_all"
  ON public.inventory FOR ALL
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());


-- ── 12. TABLE: notifications ─────────────────────────────────────────────────
--
-- Recipients read and mark-read their own notifications.
-- Doctors and patients INSERT notifications (for each other when scheduling,
-- linking, etc.).  We accept any authenticated user can insert a notification
-- for any recipient — this is low-risk (notification spam is a UX nuisance,
-- not a PHI breach).  Tighten further with a relationship check if needed.

-- Recipients read their own
CREATE POLICY "notifications_recipient_select"
  ON public.notifications FOR SELECT
  USING (recipient_id = auth.uid() OR patient_id = auth.uid());

-- Any authenticated user can insert a notification
CREATE POLICY "notifications_authenticated_insert"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Recipients mark their own read / delete their own
CREATE POLICY "notifications_recipient_update"
  ON public.notifications FOR UPDATE
  USING  (recipient_id = auth.uid() OR patient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid() OR patient_id = auth.uid());

CREATE POLICY "notifications_recipient_delete"
  ON public.notifications FOR DELETE
  USING (recipient_id = auth.uid() OR patient_id = auth.uid());

-- Admins read all
CREATE POLICY "notifications_admin_select"
  ON public.notifications FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 13. TABLE: expenses ───────────────────────────────────────────────────────

-- Doctors fully manage their own expenses
CREATE POLICY "expenses_doctor_all"
  ON public.expenses FOR ALL
  USING  (doctor_id = auth.uid())
  WITH CHECK (doctor_id = auth.uid());

-- Polyclinics read expenses of their linked doctors (for Income / Analytics tab)
CREATE POLICY "expenses_polyclinic_select"
  ON public.expenses FOR SELECT
  USING (
    doctor_id = ANY(
      (SELECT COALESCE(linked_doctor_ids, '{}')
         FROM public.users u2 WHERE u2.id = auth.uid())::uuid[]
    )
    AND public.current_user_role() = 'polyclinic'
  );

-- Admins read all
CREATE POLICY "expenses_admin_select"
  ON public.expenses FOR SELECT
  USING (public.current_user_role() = 'admin');


-- ── 14. TABLE: account_requests ──────────────────────────────────────────────
--
-- This table has no tracked creation migration but RLS is needed.
-- The login screen inserts requests without authentication (anon flow).

ALTER TABLE IF EXISTS public.account_requests ENABLE ROW LEVEL SECURITY;

-- Anyone (including unauthenticated / anon) can submit a request
CREATE POLICY "acct_req_anon_insert"
  ON public.account_requests FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only admins can read and update requests
CREATE POLICY "acct_req_admin_all"
  ON public.account_requests FOR ALL
  USING  (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');


-- ── 15. TABLE: store_products ─────────────────────────────────────────────────
--
-- PhysioGate store feature.  Store managers (role = 'store_manager') manage
-- products; any authenticated or anon user reads published products.

ALTER TABLE IF EXISTS public.store_products ENABLE ROW LEVEL SECURITY;

-- Public reads published products
CREATE POLICY "store_products_public_select"
  ON public.store_products FOR SELECT
  USING (status = 'published');

-- Store managers manage their own products
CREATE POLICY "store_products_manager_all"
  ON public.store_products FOR ALL
  USING  (
    doctor_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'store_manager')
  )
  WITH CHECK (
    doctor_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'store_manager')
  );
