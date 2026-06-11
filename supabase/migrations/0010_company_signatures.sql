begin;

-- ============================================================================
-- 1. Receipt signer flag on agency_signatures
-- ============================================================================
alter table public.agency_signatures
    add column if not exists is_receipt_signer boolean not null default false;

create unique index if not exists uniq_agency_receipt_signer
    on public.agency_signatures (agency_id)
    where is_receipt_signer = true;

-- ============================================================================
-- 2. Agency-level branding fields
-- ============================================================================
alter table public.agencies
    add column if not exists common_seal_url text,
    add column if not exists vendor_block_style text not null default 'directors_only'
    check (vendor_block_style in ('directors_only', 'seal_only', 'directors_and_seal')),
    add column if not exists receipt_block_style text not null default 'director_only'
    check (receipt_block_style in ('director_only', 'seal_only', 'director_and_seal'));

-- ============================================================================
-- 3. Per-contract escape hatch (currently unused, reserved for future use)
-- ============================================================================
alter table public.contracts
    add column if not exists requires_vendor_signing boolean not null default false;

commit;