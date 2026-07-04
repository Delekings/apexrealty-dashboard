// supabase/functions/domain-create/index.ts
//
// Provisions a custom sending domain for the caller's agency via Resend.
//
// Flow:
//   1. Authenticate caller, resolve their agency.
//   2. Gate: agency must have an ACTIVE subscription (paid feature).
//   3. Cap: refuse if the account already has >= DOMAIN_CAP domains on Resend
//      (current Resend plan allows 10).
//   4. Call Resend "Create Domain" API with the agency's domain.
//   5. Store the Resend domain id + DNS records + prefix on email_provider_config.
//   6. Return the DNS records for the UI to display.
//
// Uses the existing RESEND_API_KEY secret (same key used for sending).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_DOMAINS_URL = "https://api.resend.com/domains";
const DOMAIN_CAP = 10; // current Resend plan limit; bump when the plan upgrades.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Basic domain shape check (not exhaustive — Resend does the real validation).
function isValidDomain(d: string): boolean {
  return /^(?!-)[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/.test(d) && !d.includes(" ");
}
function isValidPrefix(p: string): boolean {
  // Local-part: letters, digits, dot, hyphen, underscore, plus. No spaces/@.
  return /^[A-Za-z0-9._+-]+$/.test(p);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    if (!RESEND_API_KEY) {
      return json({ error: "RESEND_API_KEY not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authenticated" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return json({ error: "Invalid session" }, 401);

    // Resolve agency.
    const { data: profile } = await supabase
      .from("profiles")
      .select("agency_id")
      .eq("id", user.id)
      .single();
    if (!profile?.agency_id) return json({ error: "No agency on profile" }, 403);
    const agencyId = profile.agency_id as string;

    // ---- Gate: active subscription required (paid feature) ---------------
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("status")
      .eq("agency_id", agencyId)
      .maybeSingle();
    if (sub?.status !== "active") {
      return json({
        error: "Custom sending domains are available on a paid plan.",
        code: "upgrade_required",
      }, 403);
    }

    // ---- Parse input -----------------------------------------------------
    const body = await req.json().catch(() => ({}));
    const domain = String(body.domain ?? "").trim().toLowerCase();
    const prefix = String(body.prefix ?? "").trim().toLowerCase();

    if (!domain || !isValidDomain(domain)) {
      return json({ error: "Enter a valid domain, e.g. sosoinvestment.com" }, 400);
    }
    if (!prefix || !isValidPrefix(prefix)) {
      return json({ error: "Enter a valid sender prefix, e.g. hello" }, 400);
    }

    // ---- Cap: how many domains does the Resend account already have? -----
    const listRes = await fetch(RESEND_DOMAINS_URL, {
      headers: { "Authorization": `Bearer ${RESEND_API_KEY}` },
    });
    if (listRes.ok) {
      const listData = await listRes.json();
      const existing = (listData?.data ?? listData ?? []) as Array<unknown>;
      if (Array.isArray(existing) && existing.length >= DOMAIN_CAP) {
        return json({
          error:
            "Domain limit reached on our email provider. Please contact support.",
          code: "domain_cap_reached",
        }, 409);
      }
    }

    // ---- Create the domain on Resend ------------------------------------
    const createRes = await fetch(RESEND_DOMAINS_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ name: domain }),
    });
    const createData = await createRes.json();

    if (!createRes.ok) {
      return json({
        error: "Could not create the domain with our email provider.",
        details: createData,
      }, 502);
    }

    const resendDomainId = createData?.id as string | undefined;
    const records = createData?.records ?? [];

    // ---- Persist on the agency's config row ------------------------------
    // Upsert so agencies without an existing config row still work.
    const now = new Date().toISOString();
    const { error: upErr } = await supabase
      .from("email_provider_config")
      .upsert({
        agency_id: agencyId,
        custom_domain: domain,
        custom_from_prefix: prefix,
        resend_domain_id: resendDomainId,
        custom_domain_status: "pending",
        custom_domain_records: records,
        custom_domain_created_at: now,
        custom_domain_verified_at: null,
      }, { onConflict: "agency_id" });

    if (upErr) {
      return json({ error: "Could not save domain config", details: upErr }, 500);
    }

    return json({
      ok: true,
      domain,
      prefix,
      status: "pending",
      records,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
