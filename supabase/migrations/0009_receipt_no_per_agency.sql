begin;

-- Drop the global unique constraint on receipt_no
alter table public.payments
  drop constraint if exists payments_receipt_no_key;

-- Add per-agency unique constraint
alter table public.payments
  add constraint payments_agency_receipt_no_key
  unique (agency_id, receipt_no);

-- Backfill agency_counters from existing payments
insert into public.agency_counters (agency_id, counter_name, current_value)
select
  p.agency_id,
  'receipt_' || extract(year from p.created_at)::int,
  max(
    coalesce(
      nullif(regexp_replace(p.receipt_no, '^RCP-\d{4}-', ''), '')::int,
      0
    )
  )
from public.payments p
where p.receipt_no is not null
group by p.agency_id, extract(year from p.created_at)
on conflict (agency_id, counter_name)
do update set current_value = greatest(
  public.agency_counters.current_value,
  excluded.current_value
);

commit;
