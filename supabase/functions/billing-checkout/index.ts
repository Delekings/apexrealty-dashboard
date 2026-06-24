// supabase/functions/billing-checkout/index.ts
//
// Starts a Flutterwave subscription checkout for the caller's agency.
// JWT-protected: only an authenticated agency admin can initiate billing.
// Reads the Flutterwave Payment Plan id from public.plans.flutterwave_plan_id,
// so no plan ids are hardcoded — set them with an UPDATE once created in FLW.
//
// Deploy:  supabase functions deploy billing-checkout
// Secrets: FLUTTERWAVE_SECRET_KEY  (FLWSECK-...)
//          PUBLIC_APP_URL          (optional, defaults to app.getlintel.org)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FLW_PAYMENTS_URL = "https://api.flutterwave.com/v3/payments";
const FLW_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const PUBLIC_APP_URL =
  Deno.env.get("PUBLIC_APP_URL") ?? "https://app.getlintel.org";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ ok: false, error: "Not authenticated" }, 401);

    const { planCode } = await req.json().catch(() => ({}));
    if (!planCode) return json({ ok: false, error: "Missing planCode" }, 400);

    // Identify the caller from their JWT.
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ ok: false, error: "Not authenticated" }, 401);
    }
    const userId = userData.user.id;
    const userEmail = userData.user.email ?? "";

    // Service-role client for trusted lookups/writes.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Caller must be an admin of an agency.
    const { data: profile } = await admin
      .from("profiles")
      .select("agency_id, role, full_name, email")
      .eq("id", userId)
      .maybeSingle();
    if (!profile?.agency_id) {
      return json({ ok: false, error: "No agency for this user" }, 403);
    }
    if (profile.role !== "admin") {
      return json(
        { ok: false, error: "Only an admin can manage billing" },
        403,
      );
    }
    const agencyId = profile.agency_id;

    // Resolve the plan + its Flutterwave plan id.
    const { data: plan } = await admin
      .from("plans")
      .select("code, name, price_naira, flutterwave_plan_id, is_active")
      .eq("code", planCode)
      .maybeSingle();
    if (!plan || !plan.is_active) {
      return json({ ok: false, error: "Unknown plan" }, 400);
    }
    if (plan.price_naira <= 0) {
      return json({ ok: false, error: "Free plan needs no checkout" }, 400);
    }
    if (!plan.flutterwave_plan_id) {
      return json(
        {
          ok: false,
          error:
            "Billing is not configured for this plan yet. Set its Flutterwave plan id.",
        },
        409,
      );
    }
    if (!FLW_SECRET_KEY) {
      return json({ ok: false, error: "Billing is not configured" }, 500);
    }

    // Customer email for the subscription: agency email, else the admin's.
    const { data: agency } = await admin
      .from("agencies")
      .select("email, name")
      .eq("id", agencyId)
      .maybeSingle();
    const customerEmail = agency?.email || profile.email || userEmail;
    const customerName = profile.full_name || agency?.name || "Lintel customer";

    const txRef = `lintel-${agencyId}-${plan.code}-${Date.now()}`;

    // Record a pending transaction we can reconcile from the webhook.
    await admin.from("billing_transactions").insert({
      agency_id: agencyId,
      plan_code: plan.code,
      amount_naira: plan.price_naira,
      currency: "NGN",
      status: "pending",
      flutterwave_tx_ref: txRef,
    });

    // Initiate the Flutterwave hosted checkout, attaching the payment plan so
    // Flutterwave sets up the recurring monthly subscription.
    const flwRes = await fetch(FLW_PAYMENTS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        tx_ref: txRef,
        amount: plan.price_naira,
        currency: "NGN",
        payment_plan: plan.flutterwave_plan_id,
        redirect_url: `${PUBLIC_APP_URL}/#/settings/billing?checkout=done`,
        customer: { email: customerEmail, name: customerName },
        customizations: {
          title: "Lintel",
          description: `${plan.name} plan subscription`,
        },
        meta: { agency_id: agencyId, plan_code: plan.code },
      }),
    });

    const flwData = await flwRes.json().catch(() => ({}));
    if (!flwRes.ok || flwData?.status !== "success" || !flwData?.data?.link) {
      console.error("Flutterwave init failed", flwRes.status, flwData);
      await admin
        .from("billing_transactions")
        .update({ status: "failed", raw: flwData })
        .eq("flutterwave_tx_ref", txRef);
      return json({ ok: false, error: "Could not start checkout" }, 502);
    }

    return json({ ok: true, link: flwData.data.link, txRef });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
