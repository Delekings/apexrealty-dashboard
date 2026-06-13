// supabase/functions/resend-webhook/index.ts
//
// Receives webhook events from Resend (delivered, opened, clicked, bounced,
// complained, etc.) and updates email_messages + email_message_events.
//
// Authenticity check: Resend signs each webhook using Svix HMAC-SHA256.
// We verify the svix-signature header before accepting the payload.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_WEBHOOK_SECRET = Deno.env.get("RESEND_WEBHOOK_SECRET") ?? "";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ResendEvent {
    type: string;
    created_at: string;
    data: {
        email_id: string;
        to?: string[];
        from?: string;
        subject?: string;
        // Click events include the URL
        click?: {
            link?: string;
            ipAddress?: string;
            userAgent?: string;
            timestamp?: string;
        };
        // Open events
        open?: {
            ipAddress?: string;
            userAgent?: string;
            timestamp?: string;
        };
        // Bounce events
        bounce?: {
            type?: string;
            message?: string;
        };
    };
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    if (req.method !== "POST") {
        return json({ error: "Method not allowed" }, 405);
    }

    try {
        if (!RESEND_WEBHOOK_SECRET) {
            return json({ error: "RESEND_WEBHOOK_SECRET not configured" }, 500);
        }

        // ---- Verify signature ----
        const svixId = req.headers.get("svix-id");
        const svixTimestamp = req.headers.get("svix-timestamp");
        const svixSignature = req.headers.get("svix-signature");
        const bodyText = await req.text();

        if (!svixId || !svixTimestamp || !svixSignature) {
            return json({ error: "Missing svix signature headers" }, 401);
        }

        const ok = await verifySvixSignature({
            secret: RESEND_WEBHOOK_SECRET,
            id: svixId,
            timestamp: svixTimestamp,
            signature: svixSignature,
            body: bodyText,
        });

        if (!ok) {
            return json({ error: "Invalid signature" }, 401);
        }

        // ---- Parse + process ----
        const event = JSON.parse(bodyText) as ResendEvent;
        const resendId = event.data?.email_id;
        const eventType = event.type;

        if (!resendId || !eventType) {
            return json({ error: "Malformed event payload" }, 400);
        }

        // Use the service-role client (bypasses RLS, since webhook events
        // need to write to email_message_events for any agency).
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
            { auth: { persistSession: false } }
        );

        // Find the message this event belongs to
        const { data: msg, error: lookupErr } = await supabase
            .from("email_messages")
            .select("id, agency_id")
            .eq("provider_message_id", resendId)
            .maybeSingle();

        if (lookupErr) {
            console.error("DB lookup error:", lookupErr);
            return json({ error: "Database lookup failed" }, 500);
        }

        if (!msg) {
            // Webhook for an email we don't have a record of (e.g., test sends
            // from the Resend dashboard). Acknowledge but don't error.
            console.log(`No matching message for resend_id ${resendId}`);
            return json({ ok: true, ignored: true });
        }

        // Map Resend event type to our enum
        const occurredAt = event.created_at ?? new Date().toISOString();

        switch (eventType) {
            case "email.delivered":
                await supabase
                    .from("email_messages")
                    .update({ delivered_at: occurredAt, status: "delivered" })
                    .eq("id", msg.id)
                    .is("delivered_at", null);
                await insertEvent(supabase, msg.id, msg.agency_id, "delivered",
                    occurredAt, null, null, null, event);
                break;

            case "email.opened":
                await supabase
                    .from("email_messages")
                    .update({ opened_at: occurredAt, status: "opened" })
                    .eq("id", msg.id)
                    .is("opened_at", null);
                await insertEvent(supabase, msg.id, msg.agency_id, "opened",
                    occurredAt,
                    null,
                    event.data.open?.userAgent ?? null,
                    event.data.open?.ipAddress ?? null,
                    event);
                break;

            case "email.clicked":
                await supabase
                    .from("email_messages")
                    .update({ clicked_at: occurredAt, status: "clicked" })
                    .eq("id", msg.id)
                    .is("clicked_at", null);
                await insertEvent(supabase, msg.id, msg.agency_id, "clicked",
                    occurredAt,
                    event.data.click?.link ?? null,
                    event.data.click?.userAgent ?? null,
                    event.data.click?.ipAddress ?? null,
                    event);
                break;

            case "email.bounced":
                await supabase
                    .from("email_messages")
                    .update({
                        bounced_at: occurredAt,
                        status: "bounced",
                        bounce_type: event.data.bounce?.type ?? null,
                        error_message: event.data.bounce?.message ?? null,
                    })
                    .eq("id", msg.id);
                await insertEvent(supabase, msg.id, msg.agency_id, "bounced",
                    occurredAt, null, null, null, event);
                break;

            case "email.complained":
                await supabase
                    .from("email_messages")
                    .update({ status: "complained" })
                    .eq("id", msg.id);
                await insertEvent(supabase, msg.id, msg.agency_id, "complained",
                    occurredAt, null, null, null, event);
                break;

            case "email.delivery_delayed":
                await insertEvent(supabase, msg.id, msg.agency_id, "delivery_delayed",
                    occurredAt, null, null, null, event);
                break;

            case "email.sent":
                // Already recorded when we sent; ignore.
                break;

            default:
                console.log(`Unknown event type: ${eventType}`);
        }

        return json({ ok: true });
    } catch (e) {
        console.error("Webhook error:", e);
        return json({ error: String(e) }, 500);
    }
});

async function insertEvent(
    supabase: ReturnType<typeof createClient>,
    messageId: string,
    agencyId: string,
    eventType: string,
    occurredAt: string,
    linkUrl: string | null,
    userAgent: string | null,
    ip: string | null,
    rawPayload: unknown,
) {
    await supabase.from("email_message_events").insert({
        message_id: messageId,
        agency_id: agencyId,
        event_type: eventType,
        occurred_at: occurredAt,
        link_url: linkUrl,
        user_agent: userAgent,
        ip,
        raw_payload: rawPayload,
    });
}

/// Verify a Svix-style webhook signature (used by Resend).
/// Algorithm: HMAC-SHA256 of `${id}.${timestamp}.${body}`, base64-encoded.
/// The header has format `v1,base64sig v1,base64sig2 ...` — match any.
async function verifySvixSignature(args: {
    secret: string;
    id: string;
    timestamp: string;
    signature: string;
    body: string;
}): Promise<boolean> {
    try {
        // Resend's secret is prefixed with "whsec_" — strip it and base64-decode
        const secretRaw = args.secret.startsWith("whsec_")
            ? args.secret.slice("whsec_".length)
            : args.secret;

        const secretBytes = Uint8Array.from(atob(secretRaw), (c) => c.charCodeAt(0));
        const signedPayload = `${args.id}.${args.timestamp}.${args.body}`;

        const key = await crypto.subtle.importKey(
            "raw",
            secretBytes,
            { name: "HMAC", hash: "SHA-256" },
            false,
            ["sign"],
        );

        const sigBuffer = await crypto.subtle.sign(
            "HMAC",
            key,
            new TextEncoder().encode(signedPayload),
        );

        const expectedSig = btoa(
            String.fromCharCode(...new Uint8Array(sigBuffer)),
        );

        // The svix-signature header has form: "v1,sig1 v1,sig2 ..."
        // We accept any matching v1 entry.
        const candidates = args.signature.split(" ").map((s) => {
            const [version, sig] = s.split(",");
            return version === "v1" ? sig : null;
        }).filter(Boolean) as string[];

        return candidates.includes(expectedSig);
    } catch (e) {
        console.error("Signature verification error:", e);
        return false;
    }
}

function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}