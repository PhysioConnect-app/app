-- ============================================================
-- Add missing doctor-profile columns to public.users
--
-- These columns are read/written throughout the admin, doctor, and
-- patient screens but were never added to production. An `update()`
-- call that includes a non-existent column throws a Postgres
-- "column does not exist" error:
--
--  - `allow_home_visit` — included in EVERY admin "Apply Changes"
--    save (lib/features/admin/admin_dashboard_screen.dart), so any
--    subscription/plan change for a doctor throws and leaves the
--    save button spinning forever.
--
--  - `show_dr_prefix` / `dr_prefix_request` — written when admin
--    approves/declines a doctor's "Dr." prefix request, and read by
--    doctor/patient screens to decide whether to show "Dr." before a
--    doctor's name. With the columns missing, the approval write
--    throws (silently) and the prefix never persists.
--
--  - `pending_name` / `name_change_request` — same admin "profile
--    change requests" panel, for doctor name-change approvals.
-- ============================================================

alter table public.users
  add column if not exists allow_home_visit boolean not null default true,
  add column if not exists show_dr_prefix boolean not null default false,
  add column if not exists dr_prefix_request text,
  add column if not exists pending_name text,
  add column if not exists name_change_request text;
