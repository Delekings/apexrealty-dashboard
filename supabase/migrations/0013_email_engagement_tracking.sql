begin;

-- ============================================================================
-- 1. Relax campaign_id constraint and add fields for non-campaign sends
-- ============================================================================
-- email_messages was originally campaign-scoped. We extend it to be the
-- universal "one row per email Lintel sent" table, used by signing emails,
-- automations, invites, etc.

alter table public.email_messages
    alter column campaign_id drop not null;

alter table public.email_messages
    add column if not exists email_type text not null default 'campaign'
    check (email_type in ('campaign', 'signing_request', 'automation', 'invite', 'receipt', 'transactional')),
    add column if not exists related_entity_type text,
    add column if not exists related_entity_id uuid,
    add column if not exists subject text;

-- Index for finding the email send associated with a given entity
create index if not exists idx_email_messages_related_entity
    on public.email_messages (related_entity_type, related_entity_id)
    where related_entity_id is not null;

-- Index for matching webhook events to email_messages by Resend ID
create index if not exists idx_email_messages_provider_id
    on public.email_messages (provider_message_id)
    where provider_message_id is not null;

-- ============================================================================
-- 2. Per-event history table for multi-open, multi-click tracking
-- ============================================================================
-- email_messages.opened_at only stores the FIRST open. For accurate
-- engagement metrics (e.g., "this person opened the email 5 times"),
-- we store every individual event.

create table if not exists public.email_message_events (
                                                           id uuid primary key default gen_random_uuid(),
    message_id uuid not null references public.email_messages(id) on delete cascade,
    agency_id uuid not null references public.agencies(id) on delete cascade,
    event_type text not null
    check (event_type in (
           'delivered', 'opened', 'clicked', 'bounced', 'complained',
           'delivery_delayed', 'failed'
                         )),
    occurred_at timestamptz not null default now(),
    link_url text,        -- only for clicks
    user_agent text,
    ip text,
    raw_payload jsonb not null,
    created_at timestamptz not null default now()
    );

create index if not exists idx_email_message_events_message
    on public.email_message_events (message_id, occurred_at desc);

create index if not exists idx_email_message_events_agency_recent
    on public.email_message_events (agency_id, occurred_at desc);

-- ============================================================================
-- 3. RLS
-- ============================================================================
alter table public.email_message_events enable row level security;

-- Agency members can read their agency's email events
create policy "email_events_read"
  on public.email_message_events
  for select
                 to authenticated
                 using (
                 agency_id = (select agency_id from public.profiles where id = auth.uid())
                 );

-- Only the service role inserts events (via the webhook). No client-side insert.
grant select on public.email_message_events to authenticated;
grant all on public.email_message_events to service_role;

commit;