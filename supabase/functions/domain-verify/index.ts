// supabase/functions/domain-verify/index.ts
//
// Checks verification status of the caller's agency custom domain.
//
// Flow:
//   1. Authenticate, resolve agency, load its resend_domain_id.
//   2. Ask Resend to (re)verify the domain (POST /domains/:id/verify).
//   3. Read the domain back (GET /domains/:id) for the authoritative status.
//   4. Update custom_domain_status + records + verified_at accordingly.
//   5. Return the current status and records.
//
// Resend domain status values map to ours:
//   "verified"                      -> verified
//   "pending" | "not_started"       -> pending
//   "failure" | "temporary_failure" -> failed

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_DOMAINS_URL = "https://api.resend.com/domains";

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

function mapStatus(resendStatus: string): string {
  switch (resendStatus) {
    case "verified":
      return "verified";
    case "failure":
    case "temporary_failure":
      return "failed";
    default:
      return "pending";
  }
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

    const { data: profile } = await supabase
      .from("profiles")
      .select("agency_id")
      .eq("id", user.id)
      .single();
    if (!profile?.agency_id) return json({ error: "No agency on profile" }, 403);
    const agencyId = profile.agency_id as string;

    // Load the agency's Resend domain id.
    const { data: cfg } = await supabase
      .from("email_provider_config")
      .select("resend_domain_id, custom_domain")
      .eq("agency_id", agencyId)
      .maybeSingle();

    const domainId = cfg?.resend_domain_id as string | undefined;
    if (!domainId) {
      return json({ error: "No custom domain to verify" }, 400);
    }

    // 1. Read the CURRENT status first. Calling the verify endpoint resets the
    //    domain to "pending" while it re-checks, so if the domain is already
    //    verified on Resend's side, reading first avoids a false "pending".
    const readStatus = async () => {
      const r = await fetch(`${RESEND_DOMAINS_URL}/${domainId}`, {
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}` },
      });
      const d = await r.json();
      return { ok: r.ok, data: d };
    };

    let { ok: getOk, data: getData } = await readStatus();
    if (!getOk) {
      return json({
        error: "Could not read domain status from our email provider.",
        details: getData,
      }, 502);
    }

    // 2. If not yet verified, trigger a re-check, then read again so the user
    //    gets an up-to-date result. If already verified, skip the trigger
    //    entirely (triggering would momentarily flip it back to pending).
    if (String(getData?.status ?? "") !== "verified") {
      await fetch(`${RESEND_DOMAINS_URL}/${domainId}/verify`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}` },
      }).catch(() => {/* non-fatal */});
      // Give Resend a moment, then re-read.
      await new Promise((r) => setTimeout(r, 1500));
      const second = await readStatus();
      if (second.ok) getData = second.data;
    }
    const resendStatus = String(getData?.status ?? "pending");
    const status = mapStatus(resendStatus);
    const records = getData?.records ?? undefined;

    // 3. Persist.
    const patch: Record<string, unknown> = {
      custom_domain_status: status,
    };
    if (records) patch.custom_domain_records = records;
    if (status === "verified") {
      patch.custom_domain_verified_at = new Date().toISOString();
    }
    await supabase
      .from("email_provider_config")
      .update(patch)
      .eq("agency_id", agencyId);

    return json({
      ok: true,
      status,
      resendStatus,
      records: records ?? null,
      domain: cfg?.custom_domain ?? null,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
