-- 0019_account_deletion_requests.sql
--
-- Records a user's request to delete their account. Requests are processed by
-- the Lintel team in line with the Account Deletion Policy. This table only
-- captures the request; the actual deletion is handled out of band so there is
-- a reviewable, auditable trail and a grace period before anything is removed.

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid references public.agencies(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade,
  requester_email text,
  reason text,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.account_deletion_requests enable row level security;

-- A user may file a deletion request for themselves.
drop policy if exists "adr_insert_own" on public.account_deletion_requests;
create policy "adr_insert_own"
  on public.account_deletion_requests
  for insert
  to authenticated
  with check (requested_by = auth.uid());

-- A user may see their own requests (and admins their agency's).
drop policy if exists "adr_select_own" on public.account_deletion_requests;
create policy "adr_select_own"
  on public.account_deletion_requests
  for select
  to authenticated
  using (
    requested_by = auth.uid()
    or agency_id = (select agency_id from public.profiles where id = auth.uid())
  );

grant select, insert on public.account_deletion_requests to authenticated;
grant all on public.account_deletion_requests to service_role;
