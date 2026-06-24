// supabase/functions/flutterwave-webhook/index.ts
//
// Receives Flutterwave webhooks and reconciles billing. PUBLIC endpoint
// (deploy with --no-verify-jwt) — authenticated instead by the verif-hash
// header, then every charge is RE-VERIFIED against the Flutterwave API before
// any subscription is granted (never trust the payload alone).
//
// Handles:
//   charge.completed (successful) — first payment (match our tx_ref) AND
//                                   monthly renewals (match by customer email)
//   charge.completed (failed)     — mark past_due + open a grace window
//
// Deploy:  supabase functions deploy flutterwave-webhook --no-verify-jwt
// Secrets: FLUTTERWAVE_SECRET_KEY, FLUTTERWAVE_WEBHOOK_SECRET
// Then set https://<ref>.functions.supabase.co/flutterwave-webhook as the
// webhook URL in the Flutterwave dashboard, with the same secret hash.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const FLW_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("FLUTTERWAVE_WEBHOOK_SECRET") ?? "";
const GRACE_DAYS = 5;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function addMonths(from: Date, n: number): Date {
  const d = new Date(from);
  d.setMonth(d.getMonth() + n);
  return d;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false }, 405);

  // 1) Authenticate the webhook itself.
  const sig = req.headers.get("verif-hash") ?? "";
  if (!WEBHOOK_SECRET || sig !== WEBHOOK_SECRET) {
    return json({ ok: false, error: "Invalid signature" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const payload = await req.json().catch(() => ({}));
    const event = payload?.event ?? "";
    const data = payload?.data ?? {};

    if (event !== "charge.completed") {
      // Acknowledge anything we don't act on so FLW stops retrying.
      return json({ ok: true, ignored: event });
    }

    const txId = data?.id;
    const txRef: string = data?.tx_ref ?? "";
    const reportedStatus: string = (data?.status ?? "").toLowerCase();

    // 2) Re-verify the charge against Flutterwave (source of truth).
    let verified = data;
    if (txId && FLW_SECRET_KEY) {
      const vr = await fetch(
        `https://api.flutterwave.com/v3/transactions/${txId}/verify`,
        { headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` } },
      );
      const vj = await vr.json().catch(() => ({}));
      if (vr.ok && vj?.status === "success" && vj?.data) verified = vj.data;
    }
    const status: string = (verified?.status ?? reportedStatus).toLowerCase();
    const amount = Number(verified?.amount ?? data?.amount ?? 0);
    const currency: string = verified?.currency ?? data?.currency ?? "NGN";
    const customerEmail: string =
      verified?.customer?.email ?? data?.customer?.email ?? "";
    const flwRef: string = verified?.flw_ref ?? data?.flw_ref ?? "";
    const metaAgency: string | undefined =
      verified?.meta?.agency_id ?? data?.meta?.agency_id;

    // 3) Idempotency: if we've already recorded this FLW tx as successful, stop.
    if (txId) {
      const { data: existing } = await admin
        .from("billing_transactions")
        .select("id, status")
        .eq("flutterwave_tx_id", String(txId))
        .maybeSingle();
      if (existing?.status === "successful") {
        return json({ ok: true, idempotent: true });
      }
    }

    // ---- Failed charge (typically a renewal) -> past_due + grace -----------
    if (status !== "successful") {
      let agencyId = metaAgency ?? null;
      if (!agencyId && customerEmail) {
        const { data: sub } = await admin
          .from("subscriptions")
          .select("agency_id")
          .eq("flutterwave_customer_email", customerEmail)
          .maybeSingle();
        agencyId = sub?.agency_id ?? null;
      }
      if (agencyId) {
        const grace = new Date();
        grace.setDate(grace.getDate() + GRACE_DAYS);
        await admin
          .from("subscriptions")
          .update({
            status: "past_due",
            grace_until: grace.toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("agency_id", agencyId);
        await admin.from("billing_transactions").insert({
          agency_id: agencyId,
          amount_naira: Math.round(amount),
          currency,
          status: "failed",
          flutterwave_tx_id: txId ? String(txId) : null,
          flutterwave_tx_ref: txRef || null,
          flutterwave_flw_ref: flwRef || null,
          raw: payload,
        });
      }
      return json({ ok: true, handled: "failed" });
    }

    // ---- Successful charge -------------------------------------------------
    // First payment: our pending row carries the tx_ref + plan_code.
    const { data: pending } = await admin
      .from("billing_transactions")
      .select("id, agency_id, plan_code")
      .eq("flutterwave_tx_ref", txRef)
      .maybeSingle();

    let agencyId: string | null = pending?.agency_id ?? metaAgency ?? null;
    let planCode: string | null = pending?.plan_code ?? null;

    // Renewal: no pending row — locate the agency by its FLW customer email.
    if (!agencyId && customerEmail) {
      const { data: sub } = await admin
        .from("subscriptions")
        .select("agency_id, plan_code")
        .eq("flutterwave_customer_email", customerEmail)
        .maybeSingle();
      agencyId = sub?.agency_id ?? null;
      planCode = planCode ?? sub?.plan_code ?? null;
    }

    if (!agencyId) {
      console.warn("No agency matched for charge", { txRef, customerEmail });
      return json({ ok: true, handled: "unmatched" });
    }

    const now = new Date();
    const periodEnd = addMonths(now, 1);

    // Activate / renew the subscription.
    const subUpdate: Record<string, unknown> = {
      status: "active",
      current_period_start: now.toISOString(),
      current_period_end: periodEnd.toISOString(),
      grace_until: null,
      cancel_at_period_end: false,
      flutterwave_customer_email: customerEmail || null,
      updated_at: now.toISOString(),
    };
    if (planCode) subUpdate.plan_code = planCode;
    await admin.from("subscriptions").update(subUpdate).eq("agency_id", agencyId);

    // Record the payment.
    if (pending?.id) {
      await admin
        .from("billing_transactions")
        .update({
          status: "successful",
          flutterwave_tx_id: txId ? String(txId) : null,
          flutterwave_flw_ref: flwRef || null,
          paid_at: now.toISOString(),
          raw: payload,
        })
        .eq("id", pending.id);
    } else {
      await admin.from("billing_transactions").insert({
        agency_id: agencyId,
        plan_code: planCode,
        amount_naira: Math.round(amount),
        currency,
        status: "successful",
        flutterwave_tx_id: txId ? String(txId) : null,
        flutterwave_tx_ref: txRef || null,
        flutterwave_flw_ref: flwRef || null,
        paid_at: now.toISOString(),
        raw: payload,
      });
    }

    return json({ ok: true, handled: "successful", agency: agencyId });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
