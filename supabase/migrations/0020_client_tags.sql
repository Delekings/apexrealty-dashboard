-- 0020_client_tags.sql
--
-- User-defined client tags (categories) for flexible campaign targeting.
--
-- Design:
--   * client_tags            — each agency's own named tags (e.g. "VIP",
--                              "Lekki Landlords"). Fully user-created; nothing
--                              hardcoded.
--   * client_tag_assignments — join table linking clients <-> tags, so a single
--                              client can carry MANY tags (multi-tag / "1B").
--
-- Campaigns target a tag via a new recipient filter shape:
--   {"type":"by_tag","tag_ids":["<uuid>", ...]}
-- resolved in email-send-bulk. Saved audiences can wrap this shape too.

-- ---- Tags ------------------------------------------------------------------
create table if not exists public.client_tags (
                                                  id         uuid primary key default gen_random_uuid(),
    agency_id  uuid not null references public.agencies(id) on delete cascade,
    name       text not null,
    color      text,                       -- optional hex like "#0F4F37"
    created_by uuid references public.profiles(id),
    created_at timestamptz not null default now(),
    -- one tag name per agency (case-insensitive), so "VIP" isn't created twice
    constraint client_tags_name_unique unique (agency_id, name)
    );

create index if not exists idx_client_tags_agency
    on public.client_tags (agency_id, name);

-- ---- Assignments (many-to-many) --------------------------------------------
create table if not exists public.client_tag_assignments (
                                                             client_id  uuid not null references public.clients(id) on delete cascade,
    tag_id     uuid not null references public.client_tags(id) on delete cascade,
    agency_id  uuid not null references public.agencies(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (client_id, tag_id)
    );

create index if not exists idx_cta_tag    on public.client_tag_assignments (tag_id);
create index if not exists idx_cta_client on public.client_tag_assignments (client_id);
create index if not exists idx_cta_agency on public.client_tag_assignments (agency_id);

-- ---- RLS -------------------------------------------------------------------
alter table public.client_tags            enable row level security;
alter table public.client_tag_assignments enable row level security;

-- client_tags: agency-isolated, authenticated role only.
create policy "client_tags_read" on public.client_tags
  for select to authenticated
                 using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "client_tags_insert" on public.client_tags
  for insert to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "client_tags_update" on public.client_tags
  for update to authenticated
                        using (agency_id = (select agency_id from public.profiles where id = auth.uid()))
      with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "client_tags_delete" on public.client_tags
  for delete to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

-- client_tag_assignments: same agency isolation.
create policy "cta_read" on public.client_tag_assignments
  for select to authenticated
                                     using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "cta_insert" on public.client_tag_assignments
  for insert to authenticated
  with check (agency_id = (select agency_id from public.profiles where id = auth.uid()));

create policy "cta_delete" on public.client_tag_assignments
  for delete to authenticated
  using (agency_id = (select agency_id from public.profiles where id = auth.uid()));

-- ---- Grants ----------------------------------------------------------------
grant select, insert, update, delete on public.client_tags            to authenticated;
grant select, insert, delete         on public.client_tag_assignments to authenticated;
grant all on public.client_tags            to service_role;
grant all on public.client_tag_assignments to service_role;