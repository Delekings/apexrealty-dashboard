-- 0018_email_unsubscribes.sql
--
-- Recipients who have opted out of an agency's emails, keyed by agency + email.
-- This table already exists in production (it was created ad hoc and is read by
-- the email-send-bulk / email-scheduler / email-automation-runner functions to
-- filter recipients). This migration makes it reproducible for fresh
-- environments and ensures RLS + grants. It is written to be safe to run against
-- the live database: the table/index/policy are created only if missing.

create table if not exists public.email_unsubscribes (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  email text not null,
  source text not null default 'link',
  unsubscribed_at timestamptz not null default now()
);

create index if not exists email_unsubscribes_agency_email_idx
  on public.email_unsubscribes (agency_id, lower(email));

alter table public.email_unsubscribes enable row level security;

-- Agency members may read their own agency's unsubscribe list.
drop policy if exists "email_unsubscribes_read" on public.email_unsubscribes;
create policy "email_unsubscribes_read"
  on public.email_unsubscribes
  for select
  to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

grant select on public.email_unsubscribes to authenticated;
grant all on public.email_unsubscribes to service_role;
