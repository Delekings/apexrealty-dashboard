-- 0021_custom_sending_domain.sql
--
-- Per-agency custom sending domains (paid feature).
--
-- Agencies on an active subscription can verify their own domain (e.g.
-- sosoinvestment.com) and send campaigns from their own address
-- (e.g. hello@sosoinvestment.com) instead of the shared hello@mail.getlintel.org.
--
-- Verification is delegated to Resend: we create the domain via Resend's API,
-- store the returned domain id + DNS records, and poll Resend for status.
--
-- These columns extend the existing email_provider_config table (one row per
-- agency). The table pre-dates the migrations folder, so we ALTER defensively.

alter table public.email_provider_config
  add column if not exists custom_domain          text,     -- e.g. "sosoinvestment.com"
  add column if not exists custom_from_prefix      text,     -- e.g. "hello"  -> hello@sosoinvestment.com
  add column if not exists resend_domain_id        text,     -- Resend's domain uuid
  add column if not exists custom_domain_status     text default 'none',
                                                             -- none | pending | verified | failed
  add column if not exists custom_domain_records    jsonb,    -- DNS records from Resend (SPF/DKIM/CNAME)
  add column if not exists custom_domain_created_at  timestamptz,
  add column if not exists custom_domain_verified_at timestamptz;

-- Helpful when counting how many domains an account has provisioned (the
-- Resend plan cap — currently 10).
create index if not exists idx_epc_custom_domain
  on public.email_provider_config (custom_domain)
  where custom_domain is not null;

comment on column public.email_provider_config.custom_domain is
  'Agency-owned sending domain; when status=verified, campaigns send from custom_from_prefix@custom_domain.';
