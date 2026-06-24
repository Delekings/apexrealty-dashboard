// supabase/functions/email-unsubscribe/index.ts
//
// Public endpoint that records a recipient's unsubscribe. It is linked from the
// footer of outgoing campaign emails. The link carries an HMAC signature so it
// cannot be forged to unsubscribe arbitrary addresses.
//
// Link shape (built by the send functions):
//   {APP_URL}/#/unsubscribe?a={agencyId}&e={base64(email)}&s={hmacHex}
// where hmacHex = HMAC_SHA256( `${agencyId}:${email.toLowerCase()}`, UNSUBSCRIBE_SECRET )
//
// Deploy WITHOUT JWT verification so recipients (who are not logged in) can use it:
//   supabase functions deploy email-unsubscribe --no-verify-jwt
//
// Required secret:
//   supabase secrets set UNSUBSCRIBE_SECRET="<a long random string>"

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    let a: string | null = null;
    let e: string | null = null;
    let s: string | null = null;

    const url = new URL(req.url);
    a = url.searchParams.get("a");
    e = url.searchParams.get("e");
    s = url.searchParams.get("s");
    if ((!a || !e || !s) && req.method !== "GET") {
      const body = await req.json().catch(() => ({} as Record<string, unknown>));
      a = a ?? ((body.a as string) ?? null);
      e = e ?? ((body.e as string) ?? null);
      s = s ?? ((body.s as string) ?? null);
    } else {
      const body = await req.json().catch(() => ({} as Record<string, unknown>));
      a = (body.a as string) ?? null;
      e = (body.e as string) ?? null;
      s = (body.s as string) ?? null;
    }

    if (!a || !e || !s) {
      return json({ error: "Missing parameters" }, 400);
    }

    const secret = Deno.env.get("UNSUBSCRIBE_SECRET");
    if (!secret) {
      return json({ error: "Server not configured for unsubscribe" }, 500);
    }

    let email: string;
    try {
      email = atob(e);
    } catch (_) {
      return json({ error: "Invalid link" }, 400);
    }

    const expected = await hmacHex(secret, `${a}:${email.toLowerCase()}`);
    if (expected !== s) {
      return json({ error: "Invalid or expired link" }, 403);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Idempotent: only insert if not already present (no reliance on a unique
    // constraint, so this is safe whatever the existing table shape is).
    const { data: existing, error: selErr } = await supabase
      .from("email_unsubscribes")
      .select("email")
      .eq("agency_id", a)
      .ilike("email", email)
      .limit(1);

    if (selErr) {
      return json({ error: selErr.message }, 500);
    }

    if (!existing || existing.length === 0) {
      const { error: insErr } = await supabase
        .from("email_unsubscribes")
        .insert({ agency_id: a, email });
      if (insErr) {
        return json({ error: insErr.message }, 500);
      }
    }

    return json({ ok: true, email });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
