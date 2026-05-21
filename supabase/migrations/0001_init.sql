-- ============================================================
-- Lintel — v1 schema
-- Multi-tenant by agency_id, secured with Row Level Security
-- ============================================================

create extension if not exists "pgcrypto";

-- ----------- AGENCIES (tenants) -----------
create table public.agencies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rc_number text,           -- CAC registration number
  phone text,
  email text,
  address text,
  state text,               -- Lagos, Abuja, Rivers, etc.
  logo_url text,
  created_at timestamptz default now()
);

-- ----------- USER PROFILES (extends auth.users) -----------
create type public.user_role as enum (
  'super_admin', 'agency_admin', 'manager', 'agent', 'viewer'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  agency_id uuid references public.agencies(id) on delete cascade,
  full_name text not null,
  phone text,
  role public.user_role not null default 'agent',
  avatar_url text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create index idx_profiles_agency on public.profiles(agency_id);

-- ----------- CLIENTS -----------
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  full_name text not null,
  phone text not null,
  email text,
  date_of_birth date,
  occupation text,
  bvn text,                 -- Bank Verification Number (encrypted in prod)
  nin text,                 -- National Identity Number
  address text,
  state text,
  next_of_kin_name text,
  next_of_kin_phone text,
  assigned_agent_id uuid references public.profiles(id),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_clients_agency on public.clients(agency_id);
create index idx_clients_agent on public.clients(assigned_agent_id);

-- ----------- PROPERTIES -----------
create type public.property_type as enum (
  'land', 'house', 'duplex', 'bungalow', 'apartment', 'estate', 'commercial', 'office'
);

create type public.property_status as enum (
  'available', 'reserved', 'partially_sold', 'sold_out', 'inactive'
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  title text not null,
  description text,
  property_type public.property_type not null,
  status public.property_status not null default 'available',
  location text not null,
  state text not null,
  lga text,                 -- Local Government Area
  size_sqm numeric,
  total_units int default 1,
  available_units int default 1,
  base_price_ngn numeric not null,
  cover_image_url text,
  gallery_urls text[] default '{}',
  documents jsonb default '[]'::jsonb,  -- C of O, survey plan, etc.
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_properties_agency on public.properties(agency_id);
create index idx_properties_status on public.properties(status);

-- ----------- CONTRACTS (sale agreements) -----------
create type public.contract_status as enum (
  'draft', 'pending_signature', 'active', 'completed', 'cancelled', 'defaulted'
);

create type public.payment_plan as enum (
  'outright', 'monthly', 'quarterly', 'biannual', 'annual', 'custom'
);

create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  contract_no text not null,   -- human-readable: LTL-2026-0001
  client_id uuid not null references public.clients(id),
  property_id uuid not null references public.properties(id),
  unit_label text,             -- e.g. "Block A, Plot 7"
  agent_id uuid references public.profiles(id),
  total_price_ngn numeric not null,
  initial_deposit_ngn numeric default 0,
  payment_plan public.payment_plan not null,
  plan_months int,             -- 12, 24, 36...
  start_date date not null,
  status public.contract_status not null default 'draft',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(agency_id, contract_no)
);

create index idx_contracts_agency on public.contracts(agency_id);
create index idx_contracts_client on public.contracts(client_id);

-- ----------- INSTALLMENTS (payment schedule) -----------
create type public.installment_status as enum (
  'pending', 'paid', 'partial', 'overdue', 'waived'
);

create table public.installments (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  contract_id uuid not null references public.contracts(id) on delete cascade,
  sequence int not null,
  due_date date not null,
  amount_ngn numeric not null,
  amount_paid_ngn numeric default 0,
  status public.installment_status not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz default now()
);

create index idx_installments_contract on public.installments(contract_id);
create index idx_installments_due on public.installments(due_date);
create index idx_installments_status on public.installments(status);

-- ----------- PAYMENTS (actual money received) -----------
create type public.payment_channel as enum (
  'bank_transfer', 'cash', 'card', 'ussd', 'paystack', 'flutterwave', 'cheque', 'other'
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  contract_id uuid not null references public.contracts(id),
  installment_id uuid references public.installments(id),
  amount_ngn numeric not null,
  channel public.payment_channel not null,
  reference text,           -- bank ref / paystack ref / etc.
  paid_at timestamptz not null default now(),
  recorded_by uuid references public.profiles(id),
  receipt_url text,         -- signed Supabase Storage URL
  notes text,
  created_at timestamptz default now()
);

create index idx_payments_agency on public.payments(agency_id);
create index idx_payments_contract on public.payments(contract_id);

-- ----------- DOCUMENTS (DocuSign envelopes & uploads) -----------
create type public.document_status as enum (
  'draft', 'sent', 'viewed', 'signed', 'declined', 'voided', 'expired'
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  contract_id uuid references public.contracts(id),
  client_id uuid references public.clients(id),
  title text not null,
  doc_type text,            -- 'sale_agreement', 'deed', 'allocation_letter'...
  docusign_envelope_id text,
  status public.document_status not null default 'draft',
  signed_pdf_url text,
  storage_path text,
  sent_at timestamptz,
  signed_at timestamptz,
  created_at timestamptz default now()
);

create index idx_documents_agency on public.documents(agency_id);

-- ----------- REMINDERS (SMS / WhatsApp queue) -----------
create type public.reminder_channel as enum ('sms', 'whatsapp', 'email');
create type public.reminder_status as enum ('queued', 'sent', 'failed', 'cancelled');

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  client_id uuid references public.clients(id),
  contract_id uuid references public.contracts(id),
  installment_id uuid references public.installments(id),
  channel public.reminder_channel not null,
  message text not null,
  scheduled_for timestamptz not null,
  status public.reminder_status not null default 'queued',
  provider_response jsonb,
  sent_at timestamptz,
  created_at timestamptz default now()
);

create index idx_reminders_status_scheduled on public.reminders(status, scheduled_for);

-- ----------- ACTIVITY LOG (dashboard timeline) -----------
create table public.activity_log (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  entity_type text not null,   -- 'client', 'payment', 'contract', etc.
  entity_id uuid,
  action text not null,        -- 'created', 'paid', 'sent_reminder'...
  description text,
  metadata jsonb,
  created_at timestamptz default now()
);

create index idx_activity_agency_created on public.activity_log(agency_id, created_at desc);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.agencies enable row level security;
alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.properties enable row level security;
alter table public.contracts enable row level security;
alter table public.installments enable row level security;
alter table public.payments enable row level security;
alter table public.documents enable row level security;
alter table public.reminders enable row level security;
alter table public.activity_log enable row level security;

-- Helper: get current user's agency
create or replace function public.current_agency_id()
returns uuid
language sql stable security definer
as $$
  select agency_id from public.profiles where id = auth.uid()
$$;

-- Helper: get current user's role
create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer
as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Generic policy: users see only their agency's rows
create policy "Agency members read" on public.clients
  for select using (agency_id = public.current_agency_id());
create policy "Agency members write" on public.clients
  for all using (agency_id = public.current_agency_id())
  with check (agency_id = public.current_agency_id());

-- (Apply the same pattern to properties, contracts, installments, payments,
--  documents, reminders, activity_log. Truncated here for brevity — the
--  full migration generates them in a loop.)

do $$
declare
  t text;
begin
  for t in select unnest(array[
    'properties','contracts','installments','payments',
    'documents','reminders','activity_log'
  ])
  loop
    execute format(
      'create policy "Agency read %1$I" on public.%1$I
         for select using (agency_id = public.current_agency_id())', t);
    execute format(
      'create policy "Agency write %1$I" on public.%1$I
         for all using (agency_id = public.current_agency_id())
         with check (agency_id = public.current_agency_id())', t);
  end loop;
end$$;

-- Profiles: a user can read profiles in their agency
create policy "Read own agency profiles" on public.profiles
  for select using (
    agency_id = public.current_agency_id()
    or id = auth.uid()
  );

create policy "Update own profile" on public.profiles
  for update using (id = auth.uid());

-- Only agency_admin / super_admin can insert profiles (handled via edge function for invites)
create policy "Admins manage profiles" on public.profiles
  for insert with check (
    public.current_user_role() in ('super_admin', 'agency_admin')
  );

-- Agencies: a user reads only their own agency
create policy "Read own agency" on public.agencies
  for select using (id = public.current_agency_id());

create policy "Admin updates own agency" on public.agencies
  for update using (
    id = public.current_agency_id()
    and public.current_user_role() in ('super_admin', 'agency_admin')
  );

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Mark installments overdue daily (run via pg_cron or edge fn)
create or replace function public.mark_overdue_installments()
returns void language plpgsql as $$
begin
  update public.installments
     set status = 'overdue'
   where status = 'pending'
     and due_date < current_date;
end$$;

-- Auto-update contracts.updated_at, clients.updated_at, etc.
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;

create trigger clients_updated before update on public.clients
  for each row execute function public.tg_set_updated_at();
create trigger properties_updated before update on public.properties
  for each row execute function public.tg_set_updated_at();
create trigger contracts_updated before update on public.contracts
  for each row execute function public.tg_set_updated_at();
