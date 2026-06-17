-- ============================================================
-- Fix ON DELETE behavior for FK constraints referencing public.users
--
-- All of the constraints touched here were added out-of-band (not in
-- any tracked migration) as plain:
--   FOREIGN KEY (...) REFERENCES users(id)
-- i.e. default ON DELETE NO ACTION (RESTRICT). This blocks admin
-- deletion of any doctor/patient that has ever had an appointment,
-- clinical note, invoice, expense, inventory item, appointment
-- request, message, or notification, surfacing as e.g.:
--   "update or delete on table users violates foreign key
--    constraint appointments_doctor_id_fkey on table appointments"
--
-- Policy applied (split by record type):
--
--  1. A doctor's OWN operational records (expenses, inventory) are
--     deleted along with the doctor — ON DELETE CASCADE.
--
--  2. Patient-facing records (appointments, clinical notes, invoices,
--     appointment requests) keep their `patient_id` history but lose
--     the doctor link if that doctor is removed — `doctor_id`
--     ON DELETE SET NULL.
--
--  3. Deleting a PATIENT removes their appointments, clinical notes,
--     invoices, notifications and appointment requests with them
--     (`patient_id` ON DELETE CASCADE) — matches the manual cleanup
--     already performed for duplicate patient records.
--
--  4. Chat messages keep their history but lose the sender link if
--     that user is removed — `messages.sender_id` ON DELETE SET NULL.
--
--  5. Notifications are ephemeral: if the recipient account is
--     removed, the notification is removed with it
--     (`notifications.recipient_id` ON DELETE CASCADE).
--
--  6. Self-referencing `users.created_by` / `users.polyclinic_id`
--     just get cleared if the referenced account is removed
--     (ON DELETE SET NULL) — the row itself stays.
-- ============================================================

-- 1. Doctor's own records: cascade-delete with the doctor
alter table public.expenses
  drop constraint if exists expenses_doctor_id_fkey;
alter table public.expenses
  add constraint expenses_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete cascade;

alter table public.inventory
  drop constraint if exists inventory_doctor_id_fkey;
alter table public.inventory
  add constraint inventory_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete cascade;

-- 2. Patient-facing records: keep the row, clear the doctor link
alter table public.appointments
  drop constraint if exists appointments_doctor_id_fkey;
alter table public.appointments
  add constraint appointments_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete set null;

alter table public.clinical_notes
  drop constraint if exists clinical_notes_doctor_id_fkey;
alter table public.clinical_notes
  add constraint clinical_notes_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete set null;

alter table public.invoices
  drop constraint if exists invoices_doctor_id_fkey;
alter table public.invoices
  add constraint invoices_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete set null;

alter table public.appointment_requests
  drop constraint if exists appointment_requests_doctor_id_fkey;
alter table public.appointment_requests
  add constraint appointment_requests_doctor_id_fkey
  foreign key (doctor_id) references public.users(id) on delete set null;

-- 3. Deleting a patient cascades their records
alter table public.appointments
  drop constraint if exists appointments_patient_id_fkey;
alter table public.appointments
  add constraint appointments_patient_id_fkey
  foreign key (patient_id) references public.users(id) on delete cascade;

alter table public.clinical_notes
  drop constraint if exists clinical_notes_patient_id_fkey;
alter table public.clinical_notes
  add constraint clinical_notes_patient_id_fkey
  foreign key (patient_id) references public.users(id) on delete cascade;

alter table public.invoices
  drop constraint if exists invoices_patient_id_fkey;
alter table public.invoices
  add constraint invoices_patient_id_fkey
  foreign key (patient_id) references public.users(id) on delete cascade;

alter table public.notifications
  drop constraint if exists notifications_patient_id_fkey;
alter table public.notifications
  add constraint notifications_patient_id_fkey
  foreign key (patient_id) references public.users(id) on delete cascade;

alter table public.appointment_requests
  drop constraint if exists appointment_requests_patient_id_fkey;
alter table public.appointment_requests
  add constraint appointment_requests_patient_id_fkey
  foreign key (patient_id) references public.users(id) on delete cascade;

-- 4. Chat messages keep their history, lose the sender link
alter table public.messages
  drop constraint if exists messages_sender_id_fkey;
alter table public.messages
  add constraint messages_sender_id_fkey
  foreign key (sender_id) references public.users(id) on delete set null;

-- 5. Notifications are ephemeral: remove with their recipient
alter table public.notifications
  drop constraint if exists notifications_recipient_id_fkey;
alter table public.notifications
  add constraint notifications_recipient_id_fkey
  foreign key (recipient_id) references public.users(id) on delete cascade;

-- 6. Self-referencing user links: clear, don't block deletion
alter table public.users
  drop constraint if exists users_created_by_fkey;
alter table public.users
  add constraint users_created_by_fkey
  foreign key (created_by) references public.users(id) on delete set null;

alter table public.users
  drop constraint if exists users_polyclinic_id_fkey;
alter table public.users
  add constraint users_polyclinic_id_fkey
  foreign key (polyclinic_id) references public.users(id) on delete set null;
