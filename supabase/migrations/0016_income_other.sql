-- 0016_income_other.sql
--
-- Phase Q, slice 2: other income (inflows NOT tied to a sale contract).
--
-- Sale income already lives in public.payments. This captures everything else
-- an agency earns — agency/agent fees, inspection fees, management commission,
-- consultancy, etc. The P&L (slice 3) sums payments + income_other as total
-- income, minus expenses. Source is a fixed, app-enforced list (see
-- kIncomeSources in income_repository.dart) stored as text.

create table if not exists public.income_other (
  id          uuid primary key default gen_random_uuid(),
  agency_id   uuid not null references public.agencies(id) on delete cascade,
  source      text not null,
  amount_ngn  numeric not null,
  received_on date not null,
  payer       text,
  notes       text,
  recorded_by uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_income_other_agency_date
  on public.income_other (agency_id, received_on desc);

alter table public.income_other enable row level security;

create policy "income_other_read"
  on public.income_other
  for select
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "income_other_insert"
  on public.income_other
  for insert
  to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "income_other_update"
  on public.income_other
  for update
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()))
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "income_other_delete"
  on public.income_other
  for delete
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

grant select, insert, update, delete on public.income_other to authenticated;
grant all on public.income_other to service_role;
