begin;

-- Drop the existing overload (CREATE OR REPLACE won't replace different signature).
drop function if exists public.create_signature_request(
    p_contract_id uuid,
    p_agency_signature_id uuid,
    p_unsigned_pdf_path text,
    p_vendor_witness_name text,
    p_vendor_witness_email text,
    p_buyer_witness_name text,
    p_buyer_witness_email text,
    p_expires_in_days integer
    );

-- Recreate without vendor_witness. The Nigerian legal model treats a company
-- (vendor) executing via two directors as already attested — no external
-- witness is needed on that side. We keep buyer_witness as required because
-- the typical buyer is still an individual.
--
-- Existing vendor_witness rows in document_signers are left untouched as
-- historical audit data.
create or replace function public.create_signature_request(
  p_contract_id uuid,
  p_agency_signature_id uuid,
  p_unsigned_pdf_path text,
  p_buyer_witness_name text default null,
  p_buyer_witness_email text default null,
  p_expires_in_days integer default 14
)
returns table(document_id uuid, client_signing_token text, client_email text)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
v_contract record;
  v_doc_id uuid;
  v_agency_id uuid;
  v_actor_id uuid;
  v_expires_at timestamptz;
  v_client_token text;
  v_buyer_w_token text;
begin
  v_agency_id := current_agency_id();
  v_actor_id := auth.uid();
  if v_agency_id is null then raise exception 'Not authenticated'; end if;

select c.*, cl.email as client_email, cl.full_name as client_full_name,
       cl.id as client_id, cl.phone as client_phone
into v_contract
from public.contracts c
         join public.clients cl on cl.id = c.client_id
where c.id = p_contract_id and c.agency_id = v_agency_id;

if v_contract is null then raise exception 'Contract not found'; end if;
  if v_contract.client_email is null then
    raise exception 'Client has no email on file. Please add one before sending.';
end if;

  v_expires_at := now() + (p_expires_in_days || ' days')::interval;
  v_client_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_buyer_w_token := encode(extensions.gen_random_bytes(24), 'hex');

insert into public.documents (
    agency_id, contract_id, client_id, doc_type, status,
    agency_signature_id, agency_signed_at, agency_signed_by,
    unsigned_pdf_path, current_pdf_path, expires_at
) values (
             v_agency_id, p_contract_id, v_contract.client_id, 'sale_agreement', 'sent',
             p_agency_signature_id, now(), v_actor_id,
             p_unsigned_pdf_path, p_unsigned_pdf_path, v_expires_at
         ) returning id into v_doc_id;

-- Client signer (the buyer)
insert into public.document_signers (
    document_id, signer_role, signer_order,
    full_name, email, phone, added_by,
    signing_token, token_expires_at, status, notified_at
) values (
             v_doc_id, 'client', 1,
             v_contract.client_full_name, v_contract.client_email, v_contract.client_phone,
             'agency', v_client_token, v_expires_at, 'awaiting_signer', now()
         );

-- Buyer's witness (still required; buyer is typically an individual)
-- signer_order is now 2 instead of 3 since vendor_witness is gone.
insert into public.document_signers (
    document_id, signer_role, signer_order,
    full_name, email, added_by,
    signing_token, token_expires_at, status
) values (
             v_doc_id, 'buyer_witness', 2,
             p_buyer_witness_name, p_buyer_witness_email,
             case when p_buyer_witness_name is not null then 'agency' else 'client' end,
             v_buyer_w_token, v_expires_at, 'pending'
         );

insert into public.activity_log (
    agency_id, actor_id, action, entity_type, entity_id, metadata
) values (
             v_agency_id, v_actor_id,
             'document.sent_for_signature', 'document', v_doc_id,
             jsonb_build_object(
                     'contract_id', p_contract_id,
                     'client_email', v_contract.client_email
             )
         );

return query select v_doc_id, v_client_token, v_contract.client_email::text;
end;
$function$;

commit;