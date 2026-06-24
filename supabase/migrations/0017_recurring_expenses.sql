-- 0017_recurring_expenses.sql
--
-- Phase Q, slice 4: recurring expense rules.
--
-- A rule is a template (category, amount, frequency, next_due). The app
-- "materialises" due occurrences client-side when the Expenses list loads —
-- inserting a real row into public.expenses for each due date and advancing
-- next_due — so no pg_cron is required. next_due tracking makes generation
-- idempotent (each occurrence is created exactly once).

create table if not exists public.recurring_expenses (
  id          uuid primary key default gen_random_uuid(),
  agency_id   uuid not null references public.agencies(id) on delete cascade,
  category    text not null,
  amount_ngn  numeric not null,
  payee       text,
  notes       text,
  frequency   text not null,          -- weekly | monthly | quarterly | yearly
  start_date  date not null,
  next_due    date not null,
  active      boolean not null default true,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_recurring_expenses_agency
  on public.recurring_expenses (agency_id, active, next_due);

alter table public.recurring_expenses enable row level security;

create policy "recurring_expenses_read"
  on public.recurring_expenses
  for select
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "recurring_expenses_influtter sert"
  on public.recurring_expenses
  for insert
  to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "recurring_expenses_update"
  on public.recurring_expenses
  for update
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()))
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "recurring_expenses_delete"
  on public.recurring_expenses
  for delete
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

grant select, insert, update, delete on public.recurring_expenses to authenticated;
grant all on public.recurring_expenses to service_role;
