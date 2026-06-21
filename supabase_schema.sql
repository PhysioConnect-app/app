-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users table (mirrors auth.users)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  role text, -- admin, doctor, patient, polyclinic
  bio text,
  profile_photo_url text,
  specialization text,
  clinic_name text,
  clinic_address text,
  offers_home_visit boolean default false,
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  show_in_search boolean default true,
  polyclinic_id uuid references public.users(id),
  linked_doctor_ids uuid[] default '{}',
  doctor_id uuid references public.users(id),
  doctor_ids uuid[] default '{}',
  assigned_patient_ids uuid[] default '{}',
  phone text,
  date_of_birth date,
  primary_diagnosis text,
  subscription text default 'basic',
  features jsonb default '{}',
  is_enabled boolean default true,
  fcm_token text,
  expires_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  created_by uuid references public.users(id)
);

-- Appointments
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.users(id),
  patient_name text,
  doctor_id uuid references public.users(id),
  appointment_time timestamptz,
  notes text,
  status text default 'scheduled',
  cancelled_at timestamptz,
  created_at timestamptz default now()
);

-- Appointment requests
create table public.appointment_requests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.users(id),
  patient_name text,
  doctor_id uuid references public.users(id),
  doctor_name text,
  requested_time timestamptz,
  notes text,
  status text default 'pending',
  created_at timestamptz default now()
);

-- Clinical notes (SOAP)
create table public.clinical_notes (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.users(id),
  patient_name text,
  doctor_id uuid references public.users(id),
  subjective text,
  objective text,
  assessment text,
  plan text,
  text_note text,
  reference_link text,
  photo_url text,
  note_type text default 'soap',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Chat rooms
create table public.chat_rooms (
  id text primary key,
  participants uuid[],
  participant_names jsonb default '{}',
  last_message text,
  last_message_time timestamptz,
  last_sender_id uuid,
  created_at timestamptz default now()
);

-- Unread counts per user per room
create table public.chat_room_unread (
  room_id text references public.chat_rooms(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  count integer default 0,
  primary key (room_id, user_id)
);

-- Messages
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id text references public.chat_rooms(id) on delete cascade,
  sender_id uuid references public.users(id),
  text text,
  image_url text,
  type text default 'text',
  timestamp timestamptz default now()
);

-- Invoices
create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id),
  patient_id uuid references public.users(id),
  patient_name text,
  amount numeric,
  currency text default 'USD',
  status text default 'pending',
  invoice_date timestamptz default now(),
  paid_amount numeric default 0,
  created_at timestamptz default now()
);

-- Inventory
create table public.inventory (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id),
  name text,
  category text,
  quantity integer default 0,
  min_quantity integer default 0,
  created_at timestamptz default now()
);

-- Notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.users(id),
  recipient_id uuid references public.users(id),
  recipient_type text,
  title text,
  body text,
  type text,
  read boolean default false,
  created_at timestamptz default now()
);

-- Expenses table (for expenses screen)
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.users(id),
  title text,
  amount numeric,
  category text,
  date timestamptz default now(),
  created_at timestamptz default now()
);

-- Enable Row Level Security
alter table public.users enable row level security;
alter table public.appointments enable row level security;
alter table public.appointment_requests enable row level security;
alter table public.clinical_notes enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.chat_room_unread enable row level security;
alter table public.messages enable row level security;
alter table public.invoices enable row level security;
alter table public.inventory enable row level security;
alter table public.notifications enable row level security;
alter table public.expenses enable row level security;

-- RLS: allow authenticated users to read/write their own data
-- (Simple policy — tighten in production)
create policy "Authenticated full access" on public.users for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.appointments for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.appointment_requests for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.clinical_notes for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.chat_rooms for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.chat_room_unread for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.messages for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.invoices for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.inventory for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.notifications for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Authenticated full access" on public.expenses for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Enable realtime on needed tables
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.chat_rooms;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.appointments;

-- ── Home Exercise Programs (HEP) ─────────────────────────────────────────────

create table public.hep_programs (
  id          uuid        primary key default gen_random_uuid(),
  doctor_id   uuid        not null references public.users(id) on delete cascade,
  patient_id  uuid        not null references public.users(id) on delete cascade,
  title       text        not null,
  notes_en    text        not null default '',
  status      text        not null default 'active',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger hep_programs_updated_at
  before update on public.hep_programs
  for each row execute function public.update_updated_at();

create table public.hep_items (
  id              uuid primary key default gen_random_uuid(),
  hep_id          uuid not null references public.hep_programs(id) on delete cascade,
  exercise_id     text not null,
  sets            int  not null default 3,
  reps            int  not null default 10,
  hold_sec        int  not null default 2,
  freq_per_week   int  not null default 7,
  custom_note_en  text not null default '',
  sort_order      int  not null default 0
);

-- RLS
alter table public.hep_programs enable row level security;
alter table public.hep_items    enable row level security;

create policy "doctor manages own hep_programs"
  on public.hep_programs for all
  using (doctor_id = auth.uid());

create policy "patient reads own hep_programs"
  on public.hep_programs for select
  using (patient_id = auth.uid());

create policy "hep_items follow program access"
  on public.hep_items for all
  using (
    hep_id in (
      select id from public.hep_programs
      where doctor_id = auth.uid() or patient_id = auth.uid()
    )
  );
