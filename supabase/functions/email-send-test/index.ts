// supabase/functions/email-send-test/index.ts
// Sends a single email through Resend, logs to email_messages,
// respects the agency's unsubscribe list, uses agency's from-name/reply-to.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface SendRequest {
    clientId: string;       // recipient client UUID
    subject: string;
    html: string;
    campaignName?: string;  // optional internal name for the campaign row
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        if (!RESEND_API_KEY) {
            return json({ error: "RESEND_API_KEY not configured" }, 500);
        }

        // 1. Authenticate caller
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) return json({ error: "Not authenticated" }, 401);

        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            { global: { headers: { Authorization: authHeader } } }
        );

        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) return json({ error: "Invalid session" }, 401);

        // 2. Resolve caller's agency
        const { data: profile, error: pErr } = await supabase
            .from("profiles")
            .select("agency_id")
            .eq("id", user.id)
            .single();
        if (pErr || !profile?.agency_id) {
            return json({ error: "No agency on profile" }, 403);
        }
        const agencyId = profile.agency_id as string;

        // 3. Parse body
        const body: SendRequest = await req.json();
        if (!body.clientId || !body.subject || !body.html) {
            return json({ error: "Missing clientId/subject/html" }, 400);
        }

        // 4. Load client (verify same agency, get email)
        const { data: client, error: cErr } = await supabase
            .from("clients")
            .select("id, full_name, email, agency_id, email_subscribed")
            .eq("id", body.clientId)
            .single();
        if (cErr || !client) return json({ error: "Client not found" }, 404);
        if (client.agency_id !== agencyId) {
            return json({ error: "Client belongs to another agency" }, 403);
        }
        if (!client.email) {
            return json({ error: "Client has no email address" }, 400);
        }
        if (client.email_subscribed === false) {
            return json({ error: "Client has unsubscribed from emails" }, 400);
        }

        // 5. Check unsubscribe list
        const { data: unsub } = await supabase
            .from("email_unsubscribes")
            .select("id")
            .eq("agency_id", agencyId)
            .eq("email", client.email)
            .maybeSingle();
        if (unsub) {
            return json({ error: "Recipient unsubscribed" }, 400);
        }

        // 6. Load agency email config (optional; falls back to defaults)
        const { data: cfg } = await supabase
            .from("email_provider_config")
            .select("from_name, reply_to_email")
            .eq("agency_id", agencyId)
            .maybeSingle();

        const { data: agency } = await supabase
            .from("agencies")
            .select("name, email")
            .eq("id", agencyId)
            .single();

        const fromName = cfg?.from_name ?? agency?.name ?? "Lintel";
        const replyTo = cfg?.reply_to_email ?? agency?.email ?? undefined;
        const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ?? "hello@mail.getlintel.org";
        const fromHeader = `${fromName} <${fromEmail}>`;

        // 7. Create campaign + message rows (queued)
        const campaignName = body.campaignName ??
            `Single: ${body.subject.substring(0, 60)}`;

        const { data: campaign, error: cpErr } = await supabase
            .from("email_campaigns")
            .insert({
                agency_id: agencyId,
                created_by: user.id,
                name: campaignName,
                subject: body.subject,
                body_html: body.html,
                from_name: fromName,
                reply_to_email: replyTo,
                recipient_filter: { type: "specific", client_ids: [client.id] },
                recipient_count: 1,
                total_recipients: 1,
                status: "sending",
                send_started_at: new Date().toISOString(),
            })
            .select("id")
            .single();
        if (cpErr || !campaign) {
            return json({ error: "Could not create campaign", details: cpErr }, 500);
        }

        const { data: message, error: mErr } = await supabase
            .from("email_messages")
            .insert({
                campaign_id: campaign.id,
                agency_id: agencyId,
                client_id: client.id,
                to_email: client.email,
                to_name: client.full_name,
                status: "sending",
            })
            .select("id")
            .single();
        if (mErr || !message) {
            return json({ error: "Could not log message", details: mErr }, 500);
        }

        // 8. Send via Resend
        const resendRes = await fetch(RESEND_API_URL, {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${RESEND_API_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                from: fromHeader,
                to: [client.email],
                subject: body.subject,
                html: body.html,
                reply_to: replyTo,
            }),
        });

        const resendData = await resendRes.json();

        if (!resendRes.ok) {
            // Mark as failed
            await supabase.from("email_messages").update({
                status: "failed",
                failed_at: new Date().toISOString(),
                error_message: JSON.stringify(resendData),
            }).eq("id", message.id);

            await supabase.from("email_campaigns").update({
                status: "failed",
                send_completed_at: new Date().toISOString(),
                failed_count: 1,
            }).eq("id", campaign.id);

            return json({
                error: "Resend rejected the email",
                details: resendData,
            }, 500);
        }

        // 9. Mark sent
        const now = new Date().toISOString();
        await supabase.from("email_messages").update({
            status: "sent",
            sent_at: now,
            provider_message_id: resendData.id,
        }).eq("id", message.id);

        await supabase.from("email_campaigns").update({
            status: "sent",
            send_completed_at: now,
            sent_count: 1,
        }).eq("id", campaign.id);

        return json({
            success: true,
            campaignId: campaign.id,
            messageId: message.id,
            providerMessageId: resendData.id,
        });
    } catch (e) {
        return json({ error: String(e) }, 500);
    }
});

function json(payload: unknown, status = 200): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}