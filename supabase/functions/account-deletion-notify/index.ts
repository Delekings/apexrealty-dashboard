// supabase/functions/account-deletion-notify/index.ts
//
// Emails the Lintel team when a user files an account deletion request.
// Called (best-effort) by the app right after the request row is inserted.
// The row is fetched here with the service role so the notification is
// accurate and can't be spoofed by the client (which only sends the id).
//
// Deploy:  supabase functions deploy account-deletion-notify
// Secrets: RESEND_API_KEY (already set), DELETION_NOTIFY_TO (team inbox,
//          comma-separated), optionally RESEND_FROM_EMAIL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_FROM_EMAIL =
  Deno.env.get("RESEND_FROM_EMAIL") ?? "hello@mail.getlintel.org";
const NOTIFY_TO = (Deno.env.get("DELETION_NOTIFY_TO") ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
const PUBLIC_APP_URL =
  Deno.env.get("PUBLIC_APP_URL") ?? "https://app.getlintel.org";

function esc(s: string | null | undefined): string {
  return (s ?? "").replace(
    /[&<>"]/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string),
  );
}

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
    const { requestId } = await req.json().catch(() => ({}));
    if (!requestId) return json({ ok: false, error: "Missing requestId" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: row, error } = await admin
      .from("account_deletion_requests")
      .select(
        "id, agency_id, requested_by, requester_email, reason, status, created_at",
      )
      .eq("id", requestId)
      .maybeSingle();

    if (error || !row) {
      return json({ ok: false, error: "Request not found" }, 404);
    }

    // Enrich with agency + requester names (best-effort).
    let agencyName = "—";
    let agencyEmail = "";
    if (row.agency_id) {
      const { data: ag } = await admin
        .from("agencies")
        .select("name, email")
        .eq("id", row.agency_id)
        .maybeSingle();
      if (ag?.name) agencyName = ag.name;
      if (ag?.email) agencyEmail = ag.email;
    }
    let requesterName = "—";
    const { data: pr } = await admin
      .from("profiles")
      .select("full_name")
      .eq("id", row.requested_by)
      .maybeSingle();
    if (pr?.full_name) requesterName = pr.full_name;

    if (NOTIFY_TO.length === 0) {
      console.warn("DELETION_NOTIFY_TO not set — recorded but not emailed");
      return json({ ok: true, notified: false, reason: "no recipient" });
    }
    if (!RESEND_API_KEY) {
      console.warn("RESEND_API_KEY not set — recorded but not emailed");
      return json({ ok: true, notified: false, reason: "no resend key" });
    }

    const when = new Date(row.created_at).toUTCString();
    const reason = row.reason ? esc(row.reason) : "<em>None given</em>";
    const subject = `\u26A0\uFE0F Account deletion request \u2014 ${agencyName}`;
    const html = `
      <div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;color:#1A1F2C">
        <h2 style="color:#0F4F37;margin:0 0 4px">Account deletion request</h2>
        <p style="color:#6B7280;margin:0 0 16px">A user has asked to delete their Lintel account. Please review and process it per the Account Deletion Policy.</p>
        <table style="border-collapse:collapse;width:100%;font-size:14px">
          <tr><td style="padding:6px 0;color:#6B7280;width:130px">Agency</td><td style="padding:6px 0;font-weight:600">${esc(agencyName)}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Agency email</td><td style="padding:6px 0">${esc(agencyEmail) || "—"}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Requested by</td><td style="padding:6px 0">${esc(requesterName)}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Requester email</td><td style="padding:6px 0">${esc(row.requester_email) || "—"}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Reason</td><td style="padding:6px 0">${reason}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Filed</td><td style="padding:6px 0">${esc(when)}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Status</td><td style="padding:6px 0">${esc(row.status)}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Request ID</td><td style="padding:6px 0;font-family:monospace;font-size:12px">${esc(row.id)}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Agency ID</td><td style="padding:6px 0;font-family:monospace;font-size:12px">${esc(row.agency_id) || "—"}</td></tr>
        </table>
        <p style="color:#6B7280;font-size:12px;margin-top:18px">Lintel CRM \u00B7 ${esc(PUBLIC_APP_URL)}</p>
      </div>`;

    const r = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `Lintel <${RESEND_FROM_EMAIL}>`,
        to: NOTIFY_TO,
        subject,
        html,
        ...(row.requester_email ? { reply_to: row.requester_email } : {}),
      }),
    });

    if (!r.ok) {
      const t = await r.text();
      console.error("Resend error", r.status, t);
      return json({ ok: false, error: "Email send failed" }, 502);
    }

    return json({ ok: true, notified: true });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
