begin;

-- ============================================================================
-- 1. Drop the dead 10-argument overload (no callers — verified via pg_depend)
-- ============================================================================
drop function if exists public.create_contract_with_schedule(
    p_client_id uuid,
    p_property_id uuid,
    p_unit_label text,
    p_agent_id uuid,
    p_total_price numeric,
    p_initial_deposit numeric,
    p_payment_plan payment_plan,
    p_plan_months integer,
    p_start_date date,
    p_notes text
    );

-- ============================================================================
-- 2. Replace the live overload with one that accepts requires_vendor_signing
-- ============================================================================
create or replace function public.create_contract_with_schedule(
  p_client_id uuid,
  p_property_id uuid,
  p_property_unit_type_id uuid,
  p_unit_label text,
  p_agent_id uuid,
  p_total_price numeric,
  p_initial_deposit numeric,
  p_payment_plan text,
  p_plan_months integer,
  p_start_date date,
  p_notes text,
  p_requires_vendor_signing boolean default false
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
v_agency uuid := current_agency_id();
  v_contract_id uuid;
  v_contract_no text;
  v_year int := extract(year from now())::int;
  v_next bigint;
  v_per_installment numeric;
  v_remaining numeric;
  v_n int;
  v_due date;
begin
  if v_agency is null then
    raise exception 'No agency on profile';
end if;

  -- Reserve a unit of the chosen unit type
  perform public.reserve_unit_type(p_property_unit_type_id);

  -- Generate contract number via the per-agency counter
insert into public.agency_counters (agency_id, counter_name, current_value)
values (v_agency, 'contract_' || v_year, 0)
    on conflict (agency_id, counter_name) do nothing;

update public.agency_counters
set current_value = current_value + 1
where agency_id = v_agency and counter_name = 'contract_' || v_year
    returning current_value into v_next;

v_contract_no := 'LTL-' || v_year || '-' || lpad(v_next::text, 4, '0');

  -- Create the contract
insert into public.contracts (
    agency_id, contract_no, client_id, property_id, property_unit_type_id,
    unit_label, agent_id, total_price_ngn, initial_deposit_ngn,
    payment_plan, plan_months, start_date, notes, status,
    requires_vendor_signing
) values (
             v_agency, v_contract_no, p_client_id, p_property_id, p_property_unit_type_id,
             p_unit_label, p_agent_id, p_total_price, p_initial_deposit,
             p_payment_plan::payment_plan, p_plan_months, p_start_date, p_notes, 'active',
             coalesce(p_requires_vendor_signing, false)
         ) returning id into v_contract_id;

-- Generate installment schedule
if p_payment_plan = 'outright' then
    insert into public.installments (
      agency_id, contract_id, sequence, due_date, amount_ngn, status
    ) values (
      v_agency, v_contract_id, 1, p_start_date, p_total_price, 'pending'
    );
else
    v_remaining := p_total_price - coalesce(p_initial_deposit, 0);
    if p_plan_months is null or p_plan_months <= 0 then
      raise exception 'Plan months must be > 0 for installment plans';
end if;
    v_per_installment := round(v_remaining / p_plan_months, 2);

    -- Optional initial deposit as installment 1
    if coalesce(p_initial_deposit, 0) > 0 then
      insert into public.installments (
        agency_id, contract_id, sequence, due_date, amount_ngn, status
      ) values (
        v_agency, v_contract_id, 1, p_start_date, p_initial_deposit, 'pending'
      );
end if;

    -- Then N installments
    v_due := p_start_date;
for v_n in 1..p_plan_months loop
      v_due := case p_payment_plan
        when 'monthly' then v_due + interval '1 month'
        when 'quarterly' then v_due + interval '3 months'
        when 'biannual' then v_due + interval '6 months'
        when 'annual' then v_due + interval '12 months'
        else v_due + interval '1 month'
end;

insert into public.installments (
    agency_id, contract_id, sequence, due_date, amount_ngn, status
) values (
             v_agency,
             v_contract_id,
             v_n + case when coalesce(p_initial_deposit, 0) > 0 then 1 else 0 end,
             v_due,
             case when v_n = p_plan_months
                      then v_remaining - (v_per_installment * (p_plan_months - 1))
                  else v_per_installment
                 end,
             'pending'
         );
end loop;
end if;

  -- Log activity
insert into public.activity_log (
    agency_id, actor_id, action, entity_type, entity_id, metadata
) values (
             v_agency, auth.uid(), 'contract.created', 'contract', v_contract_id,
             jsonb_build_object(
                     'contract_no', v_contract_no,
                     'unit_type_id', p_property_unit_type_id,
                     'total_price', p_total_price,
                     'requires_vendor_signing', coalesce(p_requires_vendor_signing, false)
             )
         );

return v_contract_id;
end;
$function$;

commit;