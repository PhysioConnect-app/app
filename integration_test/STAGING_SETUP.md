# Staging Setup Guide

Integration tests run against a dedicated staging Supabase project —
**never against production** (`curvmfmrodvkczwhgevy`).

---

## Schema-chain assessment (read before running Step 3)

### Production column types — verified 2026-06-25

Direct query against the production DB via `supabase db query --linked`:

| Column | data_type | udt_name | Meaning |
|---|---|---|---|
| `doctor_id` | `uuid` | `uuid` | scalar uuid |
| `doctor_ids` | `ARRAY` | `_uuid` | `uuid[]` |
| `assigned_patient_ids` | `ARRAY` | `_uuid` | `uuid[]` |

**W-7 migration is safe for production.** The RLS check
`doctor_ids @> ARRAY[auth.uid()]` is `uuid[] @> uuid[]` — type-compatible.

### Migration chain inconsistency (future task, do not fix now)

`20240101000000_initial_schema.sql` declares `doctor_id text`,
`doctor_ids text[]`, `assigned_patient_ids text[]`. Production has `uuid`
types. The two are inconsistent because production was bootstrapped from
`supabase_schema.sql` (uuid types) directly, not from the migration file.
`20240101000000` was registered in the tracking table after the fact.

Consequence: `supabase db push` on a blank project fails at migration
`20260614000000`, which tries to add a FK from `text → uuid` — impossible in
PostgreSQL. **That is why Step 3 below uses Option A (SQL Editor) instead of
a bare `supabase db push`.**

Recommended future fix (one-time, low-risk): edit
`20240101000000_initial_schema.sql` to use `uuid`/`uuid[]` for the three
columns and add the FK constraints that `supabase_schema.sql` carries.
Supabase tracks applied migrations by filename (timestamp prefix), not by
content hash, so editing an already-applied file does not re-apply it to
production. Also: add a `# DO NOT APPLY — historical bootstrap reference only`
header to `supabase_schema.sql` so it is never confused with a runnable
migration. Do not merge this fix until the integration test suite is stable.

---

## Step 1 — Create the staging project (dashboard)

1. [supabase.com](https://supabase.com) → **New project**.
2. Organisation: same org as production.
3. Name: `physioconnect-staging` (or any name — it must never hold real patient data).
4. Database password: strong, random. **Save it** — needed for the CLI link step.
5. Region: same as production for realistic latency.
6. Click **Create new project** and wait ~2 min.

---

## Step 2 — Collect staging credentials

**Project Settings → API**:

| Field | Dashboard location | `.test_env` key |
|---|---|---|
| Project URL | "Project URL" | `SUPABASE_TEST_URL` |
| `anon` key | "Project API keys → anon/public" | `SUPABASE_TEST_ANON_KEY` |
| `service_role` key | "Project API keys → service_role" | `SUPABASE_TEST_SERVICE_ROLE_KEY` |

Also note the **Project Ref** (the slug in your dashboard URL, e.g. `abcdefghijklmnop`).

---

## Step 3 — Apply schema to staging

> **Do not use a bare `supabase db push` on a fresh project** — the migration
> chain is broken (see assessment above). Use Option A.

### Option A — SQL Editor (recommended)

Open **SQL Editor → New Query** in the staging dashboard and run each block in
order. Each paste-and-run is one query:

**Block 1 — Base schema**
Paste and run the entire contents of `supabase_schema.sql` from the project
root. This creates all tables with the correct uuid types.

**Blocks 2–14 — Incremental migrations** (skip `20240101000000` — superseded
by `supabase_schema.sql`):

```
supabase/migrations/20240102000000_storage_buckets.sql
supabase/migrations/20240103000000_add_allow_home_visit.sql
supabase/migrations/20260614000000_fix_users_doctor_id_fkey_on_delete.sql
supabase/migrations/20260614010000_fix_user_referencing_fk_on_delete.sql
supabase/migrations/20260615000000_add_missing_doctor_profile_columns.sql
supabase/migrations/20260615010000_add_users_to_realtime_publication.sql
supabase/migrations/20260617030000_add_published_at_trigger.sql
supabase/migrations/20260617040000_add_image_urls_to_store_products.sql
supabase/migrations/20260618010000_add_awaiting_review_and_appointment_id.sql
supabase/migrations/20260618020000_schedule_session_reminders.sql
supabase/migrations/20260621000000_add_hep_tables.sql
supabase/migrations/20260621010000_allow_anon_read_doctors.sql
supabase/migrations/20260622000001_ai_tables.sql
```

**Blocks 15–16 — Pending migrations (double-rehearsal before production)**:
```
supabase/migrations/20260625000000_tighten_rls.sql
supabase/migrations/20260625010000_fix_invoice_retention_and_deletion_cleanup.sql
```

Run each file as a separate query. If any block errors, **stop and investigate
before continuing** — do not skip over a failure.

### Option B — CLI hybrid (if you want CLI to track staging migration state)

```powershell
# 1. Apply base schema via SQL Editor (same as Option A Block 1)

# 2. Mark migration 20240101 as applied so the CLI skips the broken file
#    Run in staging SQL Editor:
#    INSERT INTO supabase_migrations.schema_migrations (version)
#    VALUES ('20240101000000');

# 3. Link CLI to staging and push the remaining migrations
supabase link --project-ref <STAGING_REF>
supabase db push

# 4. Re-link CLI to production when done
supabase link --project-ref curvmfmrodvkczwhgevy
```

---

## Step 4 — Deploy Edge Functions to staging

```powershell
supabase link --project-ref <STAGING_REF>

supabase functions deploy ai-doctor-assistant
supabase functions deploy admin-delete-user
supabase functions deploy admin-create-user
supabase functions deploy admin-merge-patients
supabase functions deploy session-reminders

supabase link --project-ref curvmfmrodvkczwhgevy   # re-link to production
```

**Set secrets in the staging dashboard → Edge Functions → Manage secrets.**
Only set the two custom secrets — do NOT set `SUPABASE_URL` or
`SUPABASE_SERVICE_ROLE_KEY` (Supabase injects those automatically; setting
them manually would override the wrong environment's values):

| Secret | Which function | What it is |
|---|---|---|
| `GROQ_API_KEY` | `ai-doctor-assistant` only | Your Groq API key |
| `FCM_SERVER_KEY` | `session-reminders` only | Firebase Cloud Messaging server key |

No other secrets need to be set manually.

---

## Step 5 — Create five test accounts (dashboard)

**Authentication → Users → Add User** (use "Create user", not "Invite").
These accounts are permanent staging fixtures — never delete them between runs.

| Account | Email |
|---|---|
| Admin | `admin@test.physioconnect.dev` |
| Doctor | `doctor@test.physioconnect.dev` |
| Patient | `patient@test.physioconnect.dev` |
| Store manager | `store@test.physioconnect.dev` |
| Polyclinic | `polyclinic@test.physioconnect.dev` |

After creating all five, note the **UUID** for Doctor and Patient — needed in
Step 7.

---

## Step 6 — Seed `public.users` rows

Run in **staging SQL Editor**. Replace every `<..._UUID>` with the UUID from
Step 5:

```sql
INSERT INTO public.users (id, email, name, role, is_enabled,
                          subscription, features, show_in_search)
VALUES
  ('<ADMIN_UUID>',
   'admin@test.physioconnect.dev', 'Test Admin', 'admin',
   true, 'premium',
   '{"statistics":true,"billing":true,"expenses":true,"ai_enabled":true}'::jsonb,
   false),

  ('<DOCTOR_UUID>',
   'doctor@test.physioconnect.dev', 'Test Doctor', 'doctor',
   true, 'premium',
   '{"statistics":true,"billing":true,"expenses":true,"ai_enabled":true}'::jsonb,
   true),

  ('<PATIENT_UUID>',
   'patient@test.physioconnect.dev', 'Test Patient', 'patient',
   true, 'basic', '{}'::jsonb, false),

  ('<STORE_UUID>',
   'store@test.physioconnect.dev', 'Test Store', 'store_manager',
   true, 'basic', '{}'::jsonb, false),

  ('<POLYCLINIC_UUID>',
   'polyclinic@test.physioconnect.dev', 'Test Polyclinic', 'polyclinic',
   true, 'basic', '{}'::jsonb, false)
ON CONFLICT (id) DO NOTHING;

-- Link test patient ↔ test doctor
-- No explicit ::uuid[] cast — PostgreSQL coerces the literal to the column type
UPDATE public.users
SET assigned_patient_ids = ARRAY['<PATIENT_UUID>']
WHERE id = '<DOCTOR_UUID>';

UPDATE public.users
SET doctor_ids = ARRAY['<DOCTOR_UUID>'],
    doctor_id  = '<DOCTOR_UUID>'
WHERE id = '<PATIENT_UUID>';
```

---

## Step 7 — Fill in `integration_test/.test_env`

```powershell
Copy-Item integration_test\.test_env.example integration_test\.test_env
```

Edit the file:

```env
SUPABASE_TEST_URL=https://<YOUR_STAGING_REF>.supabase.co
SUPABASE_TEST_ANON_KEY=<staging anon key>
SUPABASE_TEST_SERVICE_ROLE_KEY=<staging service role key>

ADMIN_EMAIL=admin@test.physioconnect.dev
ADMIN_PASSWORD=<password chosen in Step 5>

DOCTOR_EMAIL=doctor@test.physioconnect.dev
DOCTOR_PASSWORD=<password chosen in Step 5>

PATIENT_EMAIL=patient@test.physioconnect.dev
PATIENT_PASSWORD=<password chosen in Step 5>

STORE_MANAGER_EMAIL=store@test.physioconnect.dev
STORE_MANAGER_PASSWORD=<password chosen in Step 5>

POLYCLINIC_EMAIL=polyclinic@test.physioconnect.dev
POLYCLINIC_PASSWORD=<password chosen in Step 5>

DOCTOR_UID=<DOCTOR_UUID from Step 5>
PATIENT_UID=<PATIENT_UUID from Step 5>
```

Verify it is gitignored:

```powershell
git status integration_test/.test_env   # must show nothing (gitignored)
```

---

## Step 8 — Smoke-check the connection

```powershell
$url    = 'https://<YOUR_STAGING_REF>.supabase.co/rest/v1/users?select=id,role&limit=5'
$apikey = '<staging anon key>'
Invoke-RestMethod -Uri $url `
    -Headers @{ 'apikey' = $apikey; 'Authorization' = "Bearer $apikey" }
```

Expected: JSON array with 5 rows (one per test account).

If empty or 401: credentials are wrong or the seed INSERT did not run.
If 0 rows but no error: the W-7 RLS policy is active and blocking the anon
read — that is correct behaviour after W-7. In that case, use the service role
key instead to verify row presence.

---

## When staging is confirmed

Tell me **"staging is up, smoke-check returns 5 rows"** (or the RLS-gated
equivalent). I will then run Step B:

- **RLS cross-access check**: patient B cannot SELECT/UPDATE/DELETE patient A's
  `clinical_notes` or `invoices`.
- **Deletion matrix**: doctor + patient fixture created, patient deleted,
  verify `clinical_notes` cascaded, `invoices` anonymised (`patient_id = NULL`,
  `patient_name = '[Deleted Patient]'`), `hep_programs.doctor_id → NULL` on
  doctor delete, chat participants cleaned.

If either check fails, work stops until the issue is understood and fixed
before production ever sees W-7 or C-1.

**Production migrations stay queued — nothing in Step B touches
`curvmfmrodvkczwhgevy`.**
