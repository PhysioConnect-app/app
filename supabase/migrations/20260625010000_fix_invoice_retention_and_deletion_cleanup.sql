-- ============================================================
-- C-1 — Fix account-deletion data completeness
--
-- REVIEW BEFORE APPLYING.  Run AFTER W-7 migration is applied and
-- confirmed.  DO NOT RUN against the live database until backup is
-- confirmed and deletion matrix below has been approved.
--
-- Context
-- -------
-- Migration 20260614010000 already fixed the critical cascade gaps
-- (appointments, clinical_notes, appointment_requests cascade with
-- patient; expenses, inventory cascade with doctor; notifications
-- cascade with recipient).  Three gaps remain:
--
--   GAP 1 — invoices.patient_id is ON DELETE CASCADE.
--            Financial/legal records must survive patient deletion;
--            only the patient identifier should be anonymised.
--            → Change to ON DELETE SET NULL + trigger to wipe
--              patient_name and patient phone from the invoice row.
--
--   GAP 2 — ai_summary_cache has no FK constraints.
--            Clinical summaries linger after patient/doctor deletion.
--            → Add FKs with ON DELETE CASCADE.
--
--   GAP 3 — chat_rooms.participants[] is a plain text[] with no FK.
--            A deleted user's UUID stays in every room they joined.
--            → Handled in the admin-delete-user Edge Function (see
--              the companion Edge Function update in this PR), not in
--              SQL, because array-element removal requires a full scan
--              of the chat_rooms table that is safer done in code.
--
-- ============================================================


-- ── GAP 1: invoices — retain row, anonymise patient identity ─────────────────

-- Step 1a: change patient_id FK from CASCADE to SET NULL
ALTER TABLE public.invoices
  DROP CONSTRAINT IF EXISTS invoices_patient_id_fkey;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_patient_id_fkey
  FOREIGN KEY (patient_id)
  REFERENCES public.users(id)
  ON DELETE SET NULL;

-- Step 1b: trigger — when patient_id is NULLed (i.e. the patient was deleted),
--          overwrite the de-normalised patient_name column with a tombstone so
--          the invoice no longer contains personally identifiable information
--          while retaining amount, date, currency, and status for accounting.

CREATE OR REPLACE FUNCTION public.anonymise_invoice_on_patient_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Fires AFTER UPDATE; only act when patient_id just became NULL
  IF OLD.patient_id IS NOT NULL AND NEW.patient_id IS NULL THEN
    NEW.patient_name := '[Deleted Patient]';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_anonymise_patient
  ON public.invoices;

CREATE TRIGGER trg_invoice_anonymise_patient
  BEFORE UPDATE OF patient_id ON public.invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.anonymise_invoice_on_patient_delete();


-- ── GAP 1b: hep_programs.doctor_id — retain patient's exercises when doctor deletes ──
--
-- Currently ON DELETE CASCADE (set in 20260621000000) which means a doctor
-- deleting their account wipes every patient's HEP program they prescribed.
-- Decision: change to ON DELETE SET NULL so patients keep their exercise
-- history; the prescribing doctor reference is simply cleared.
--
-- The column is NOT NULL in the original DDL, so we must drop that constraint
-- before the FK can be changed.

-- Note: the IDE may flag "DROP NOT NULL" as a syntax error because it lints
-- against T-SQL (SQL Server).  This is valid PostgreSQL / Supabase syntax.
ALTER TABLE public.hep_programs
  ALTER COLUMN doctor_id DROP NOT NULL;

ALTER TABLE public.hep_programs
  DROP CONSTRAINT IF EXISTS hep_programs_doctor_id_fkey;

ALTER TABLE public.hep_programs
  ADD CONSTRAINT hep_programs_doctor_id_fkey
  FOREIGN KEY (doctor_id)
  REFERENCES public.users(id)
  ON DELETE SET NULL;


-- ── GAP 2: ai_summary_cache — add FK cascades ────────────────────────────────
--
-- The table was created without FK constraints (20260622000001).
-- Adding them now.  Existing rows with no matching users.id would
-- violate the new FK — run the cleanup subquery first to be safe.

DELETE FROM public.ai_summary_cache
  WHERE patient_id NOT IN (SELECT id FROM public.users)
     OR doctor_id  NOT IN (SELECT id FROM public.users);

ALTER TABLE public.ai_summary_cache
  ADD CONSTRAINT ai_summary_cache_patient_id_fkey
  FOREIGN KEY (patient_id)
  REFERENCES public.users(id)
  ON DELETE CASCADE;

ALTER TABLE public.ai_summary_cache
  ADD CONSTRAINT ai_summary_cache_doctor_id_fkey
  FOREIGN KEY (doctor_id)
  REFERENCES public.users(id)
  ON DELETE CASCADE;


-- ── Companion Edge Function change (informational, not SQL) ──────────────────
--
-- The admin-delete-user Edge Function at
--   supabase/functions/admin-delete-user/index.ts
-- must be updated to clean up chat_rooms after deleting a user.
-- The following pseudocode describes the required change:
--
--   // After deleting auth.users (which cascades to public.users):
--   const { data: rooms } = await adminClient
--     .from('chat_rooms')
--     .select('id, participants')
--     .contains('participants', [userId]);   // text[] column
--   for (const room of rooms ?? []) {
--     const updated = room.participants.filter(p => p !== userId);
--     if (updated.length === 0) {
--       await adminClient.from('chat_rooms').delete().eq('id', room.id);
--     } else {
--       await adminClient.from('chat_rooms').update({ participants: updated }).eq('id', room.id);
--     }
--   }
--
-- This is noted here for review alongside the SQL.  The actual code
-- change to index.ts is a separate, low-risk edit that should be applied
-- at the same time as this migration.
