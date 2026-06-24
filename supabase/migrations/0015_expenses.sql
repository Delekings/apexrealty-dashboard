-- 0015_expenses.sql
--
-- Phase Q, slice 1: business expenses (outflows).
--
-- Income already lives in public.payments (amount_ngn). This is the matching
-- outflow ledger. Categories are a fixed, app-enforced list (see
-- kExpenseCategories in expenses_repository.dart) stored as text — no separate
-- categories table — which keeps P&L grouping clean. receipt_url is reserved
-- for the later receipts slice.

create table if not exists public.expenses (
  id          uuid primary key default gen_random_uuid(),
  agency_id   uuid not null references public.agencies(id) on delete cascade,
  category    text not null,
  amount_ngn  numeric not null,
  spent_on    date not null,
  payee       text,
  notes       text,
  receipt_url text,
  recorded_by uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_expenses_agency_date
  on public.expenses (agency_id, spent_on desc);

alter table public.expenses enable row level security;

-- RLS scoped to the authenticated role (never {public}), agency-isolated.
create policy "expenses_read"
  on public.expenses
  for select
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "expenses_insert"
  on public.expenses
  for insert
  to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "expenses_update"
  on public.expenses
  for update
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()))
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "expenses_delete"
  on public.expenses
  for delete
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

grant select, insert, update, delete on public.expenses to authenticated;
grant all on public.expenses to service_role;
