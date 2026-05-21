-- ============================================================
-- Dashboard helper RPCs
-- ============================================================

-- Returns the last 6 months of revenue (sum of payments), one row per month.
-- Used by the dashboard chart.
create or replace function public.monthly_revenue_last_6()
returns table (month_label text, total_ngn numeric)
language sql stable security invoker
as $$
  with months as (
    select date_trunc('month', current_date) - (i || ' month')::interval as m
    from generate_series(0, 5) i
  )
  select
    to_char(m, 'Mon') as month_label,
    coalesce(sum(p.amount_ngn), 0) as total_ngn
  from months
  left join public.payments p
    on date_trunc('month', p.paid_at) = months.m
    and p.agency_id = public.current_agency_id()
  group by m
  order by m asc;
$$;

-- Convenience: list installments grouped by client for the reminders queue.
create or replace function public.installments_due_in_next_n_days(n int default 7)
returns setof public.installments
language sql stable security invoker
as $$
  select *
  from public.installments
  where agency_id = public.current_agency_id()
    and status in ('pending', 'partial')
    and due_date between current_date and current_date + (n || ' days')::interval
  order by due_date asc;
$$;

-- ============================================================
-- Generate installment schedule for a new contract
-- ============================================================

create or replace function public.generate_installments(
  p_contract_id uuid
) returns void
language plpgsql
security invoker
as $$
declare
  v_contract public.contracts;
  v_balance numeric;
  v_per numeric;
  v_months int;
  v_i int;
  v_due date;
begin
  select * into v_contract from public.contracts where id = p_contract_id;
  if v_contract is null then
    raise exception 'Contract not found';
  end if;

  -- Outright: one installment due on start date
  if v_contract.payment_plan = 'outright' then
    insert into public.installments(
      agency_id, contract_id, sequence, due_date, amount_ngn
    ) values (
      v_contract.agency_id, v_contract.id, 1, v_contract.start_date,
      v_contract.total_price_ngn - coalesce(v_contract.initial_deposit_ngn, 0)
    );
    return;
  end if;

  v_balance := v_contract.total_price_ngn
             - coalesce(v_contract.initial_deposit_ngn, 0);
  v_months := coalesce(v_contract.plan_months, 12);

  -- Step depending on plan
  v_per := round(v_balance / v_months, 2);

  v_i := 1;
  while v_i <= v_months loop
    v_due := case v_contract.payment_plan
      when 'monthly' then v_contract.start_date + ((v_i) || ' month')::interval
      when 'quarterly' then v_contract.start_date + ((v_i * 3) || ' month')::interval
      when 'biannual' then v_contract.start_date + ((v_i * 6) || ' month')::interval
      when 'annual' then v_contract.start_date + ((v_i) || ' year')::interval
      else v_contract.start_date + ((v_i) || ' month')::interval
    end;

    insert into public.installments(
      agency_id, contract_id, sequence, due_date, amount_ngn
    ) values (
      v_contract.agency_id, v_contract.id, v_i, v_due, v_per
    );
    v_i := v_i + 1;
  end loop;
end$$;
