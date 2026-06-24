-- 0014_email_audiences.sql
--
-- Saved, reusable campaign audiences.
--
-- An audience is a named wrapper around a recipient *filter* — the exact JSON
-- shape already used by send_bulk / previewRecipientCount (e.g. {"type":"all"},
-- {"type":"by_state","states":[...]}, {"type":"has_active_contract"},
-- {"type":"has_overdue"}). Because an audience just stores one of those existing
-- filter shapes, saved audiences resolve through the current send path with no
-- edge-function changes.

create table if not exists public.email_audiences (
  id          uuid primary key default gen_random_uuid(),
  agency_id   uuid not null references public.agencies(id) on delete cascade,
  name        text not null,
  description text,
  filter      jsonb not null default '{"type":"all"}'::jsonb,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_email_audiences_agency
  on public.email_audiences (agency_id, created_at desc);

alter table public.email_audiences enable row level security;

-- RLS scoped to the authenticated role (never {public}), agency-isolated.
create policy "email_audiences_read"
  on public.email_audiences
  for select
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "email_audiences_insert"
  on public.email_audiences
  for insert
  to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "email_audiences_update"
  on public.email_audiences
  for update
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()))
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "email_audiences_delete"
  on public.email_audiences
  for delete
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

-- Explicit grants (service_role needs them for Edge Functions / scheduler).
grant select, insert, update, delete on public.email_audiences to authenticated;
grant all on public.email_audiences to service_role;
