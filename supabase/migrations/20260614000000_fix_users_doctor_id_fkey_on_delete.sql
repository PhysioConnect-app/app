-- ============================================================
-- Fix users_doctor_id_fkey to ON DELETE SET NULL
--
-- The live `users_doctor_id_fkey` constraint (added out-of-band,
-- not previously tracked in migrations) was:
--   FOREIGN KEY (doctor_id) REFERENCES users(id)
-- i.e. default ON DELETE NO ACTION (RESTRICT).
--
-- This blocked admin deletion of any doctor who still has a patient
-- with that doctor set as their primary `doctor_id`, surfacing as:
--   "update or delete on table users violates foreign key
--    constraint users_doctor_id_fkey on table users"
--
-- Changing to ON DELETE SET NULL lets the doctor (or patient) row be
-- deleted; any patient row that referenced the deleted user via
-- `doctor_id` simply has that column cleared.
-- ============================================================

alter table public.users
  drop constraint if exists users_doctor_id_fkey;

alter table public.users
  add constraint users_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete set null;
