-- ============================================================
-- PhysioConnect – Initial Schema
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- USERS
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'doctor',
  name text default '',
  bio text default '',
  specialization text default '',
  clinic_name text default '',
  clinic_address text default '',
  profile_photo_url text default '',
  phone text default '',
  subscription text default 'basic',
  features jsonb default '{"messages":false,"statistics":false,"billing":false,"expenses":false}'::jsonb,
  is_enabled boolean default true,
  show_in_search boolean default true,
  offers_home_visit boolean default false,
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  doctor_ids text[] default '{}',
  doctor_id text,
  assigned_patient_ids text[] default '{}',
  linked_doctor_ids text[] default '{}',
  polyclinic_id uuid,
  primary_diagnosis text default '',
  date_of_birth timestamptz,
  has_account boolean default true,
  imported boolean default false,
  fcm_token text,
  expires_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz,
  created_by uuid
);

-- APPOINTMENTS
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id) on delete cascade,
  patient_id uuid,
  patient_name text default '',
  appointment_time timestamptz not null,
  notes text default '',
  status text default 'scheduled',
  cancelled_at timestamptz,
  created_at timestamptz default now()
);

-- CLINICAL NOTES
create table if not exists public.clinical_notes (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id) on delete cascade,
  patient_id uuid,
  patient_name text default '',
  note_type text default 'soap',
  text_note text default '',
  subjective text default '',
  objective text default '',
  assessment text default '',
  plan text default '',
  reference_link text default '',
  photo_url text default '',
  attachments jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz
);

-- NOTIFICATIONS
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid,
  patient_id uuid,
  recipient_type text default 'patient',
  type text default '',
  title text default '',
  body text default '',
  read boolean default false,
  created_at timestamptz default now()
);

-- CHAT ROOMS
create table if not exists public.chat_rooms (
  id text primary key,
  participants text[] default '{}',
  participant_names jsonb default '{}'::jsonb,
  last_message text default '',
  last_message_time timestamptz default now(),
  last_sender_id uuid,
  created_at timestamptz default now()
);

-- MESSAGES
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id text references public.chat_rooms(id) on delete cascade,
  sender_id uuid,
  text text,
  image_url text,
  type text default 'text',
  timestamp timestamptz default now()
);

-- CHAT ROOM UNREAD COUNTS
create table if not exists public.chat_room_unread (
  room_id text references public.chat_rooms(id) on delete cascade,
  user_id uuid,
  count integer default 0,
  primary key (room_id, user_id)
);

-- INVOICES
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id) on delete cascade,
  patient_id uuid,
  patient_name text default '',
  service text default '',
  amount numeric default 0,
  paid_amount numeric,
  currency text default 'USD',
  status text default 'pending',
  note text default '',
  invoice_date timestamptz default now(),
  created_at timestamptz default now()
);

-- EXPENSES
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id) on delete cascade,
  category text default '',
  description text default '',
  amount numeric default 0,
  paid_amount numeric,
  status text default 'pending',
  note text default '',
  expense_date timestamptz default now(),
  created_at timestamptz default now()
);

-- INVENTORY
create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id) on delete cascade,
  name text default '',
  quantity integer default 0,
  unit text default '',
  notes text default '',
  created_at timestamptz default now()
);

-- APPOINTMENT REQUESTS (patient-initiated)
create table if not exists public.appointment_requests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid,
  patient_name text default '',
  doctor_id uuid,
  doctor_name text default '',
  requested_time timestamptz,
  notes text default '',
  status text default 'pending',
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.users enable row level security;
alter table public.appointments enable row level security;
alter table public.clinical_notes enable row level security;
alter table public.notifications enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;
alter table public.chat_room_unread enable row level security;
alter table public.invoices enable row level security;
alter table public.expenses enable row level security;
alter table public.inventory enable row level security;
alter table public.appointment_requests enable row level security;

-- Allow all authenticated users full access (clinic internal app)
create policy "auth_all" on public.users               for all to authenticated using (true) with check (true);
create policy "auth_all" on public.appointments        for all to authenticated using (true) with check (true);
create policy "auth_all" on public.clinical_notes      for all to authenticated using (true) with check (true);
create policy "auth_all" on public.notifications       for all to authenticated using (true) with check (true);
create policy "auth_all" on public.chat_rooms          for all to authenticated using (true) with check (true);
create policy "auth_all" on public.messages            for all to authenticated using (true) with check (true);
create policy "auth_all" on public.chat_room_unread    for all to authenticated using (true) with check (true);
create policy "auth_all" on public.invoices            for all to authenticated using (true) with check (true);
create policy "auth_all" on public.expenses            for all to authenticated using (true) with check (true);
create policy "auth_all" on public.inventory           for all to authenticated using (true) with check (true);
create policy "auth_all" on public.appointment_requests for all to authenticated using (true) with check (true);
