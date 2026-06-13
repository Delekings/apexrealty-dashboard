// supabase/functions/email-send-bulk/index.ts
// Sends a campaign to multiple clients. Resolves the recipient filter
// server-side, creates campaign + message rows, dispatches to Resend
// with light rate limiting, updates stats as it goes.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface BulkSendRequest {
    campaignName: string;
    subject: string;
    html: string;
    filter: RecipientFilter;
}

interface RecipientFilter {
    type: "all" | "by_state" | "has_active_contract" | "has_overdue" | "specific";
    states?: string[]; // for by_state
    clientIds?: string[]; // for specific
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        if (!RESEND_API_KEY) {
            return json({ error: "RESEND_API_KEY not configured" }, 500);
        }

        // Authenticate
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) return json({ error: "Not authenticated" }, 401);

        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            { global: { headers: { Authorization: authHeader } } }
        );

        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) return json({ error: "Invalid session" }, 401);

        // Resolve agency
        const { data: profile } = await supabase
            .from("profiles")
            .select("agency_id")
            .eq("id", user.id)
            .single();
        if (!profile?.agency_id) {
            return json({ error: "No agency on profile" }, 403);
        }
        const agencyId = profile.agency_id as string;

        // Parse body
        const body: BulkSendRequest = await req.json();
        if (!body.subject || !body.html || !body.filter) {
            return json({ error: "Missing subject/html/filter" }, 400);
        }

        // Resolve recipient list
        const recipients = await resolveRecipients(supabase, agencyId, body.filter);
        if (recipients.length === 0) {
            return json({ error: "No recipients match the filter" }, 400);
        }

        // Filter out unsubscribed
        const unsubRes = await supabase
            .from("email_unsubscribes")
            .select("email")
            .eq("agency_id", agencyId);
        const unsubSet = new Set(
            ((unsubRes.data ?? []) as Array<{ email: string }>).map((r) =>
                r.email.toLowerCase()
            )
        );
        const eligible = recipients.filter(
            (r) => r.email && !unsubSet.has(r.email.toLowerCase())
        );

        if (eligible.length === 0) {
            return json({
                error: "All recipients are unsubscribed or have no email",
            }, 400);
        }

        // Load agency config
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

        // Create campaign row
        const { data: campaign, error: cpErr } = await supabase
            .from("email_campaigns")
            .insert({
                agency_id: agencyId,
                created_by: user.id,
                name: body.campaignName,
                subject: body.subject,
                body_html: body.html,
                from_name: fromName,
                reply_to_email: replyTo,
                recipient_filter: body.filter,
                recipient_count: eligible.length,
                total_recipients: eligible.length,
                status: "sending",
                send_started_at: new Date().toISOString(),
            })
            .select("id")
            .single();
        if (cpErr || !campaign) {
            return json({ error: "Could not create campaign", details: cpErr }, 500);
        }
        const campaignId = campaign.id as string;

        // Bulk-insert message rows (status: sending)
        // Bulk-insert message rows (status: sending)
        const messageRows = eligible.map((r) => ({
            campaign_id: campaignId,
            agency_id: agencyId,
            client_id: r.id,
            to_email: r.email,
            to_name: r.full_name,
            status: "sending",
            email_type: "campaign",
            related_entity_type: "campaign",
            related_entity_id: campaignId,
            subject: body.subject,
        }));
        const { data: insertedMessages, error: mErr } = await supabase
            .from("email_messages")
            .insert(messageRows)
            .select("id, to_email, to_name, client_id");
        if (mErr || !insertedMessages) {
            return json({ error: "Could not log messages", details: mErr }, 500);
        }

        // Dispatch to Resend with rate limiting (Resend free: 2/sec)
        let sentCount = 0;
        let failedCount = 0;
        const sleepMs = 600; // ~1.67/sec, well under limit

        for (const msg of insertedMessages) {
            // Personalise body with client's name
            const clientName = msg.to_name ?? "";
            const personalisedHtml = body.html.replaceAll("{{name}}", clientName);
            const personalisedSubject =
                body.subject.replaceAll("{{name}}", clientName);

            try {
                const resendRes = await fetch(RESEND_API_URL, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${RESEND_API_KEY}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        from: fromHeader,
                        to: [msg.to_email],
                        subject: personalisedSubject,
                        html: personalisedHtml,
                        reply_to: replyTo,
                        tracking: { opens: true, clicks: true },
                    }),
                });

                const resendData = await resendRes.json();

                if (resendRes.ok) {
                    await supabase.from("email_messages").update({
                        status: "sent",
                        sent_at: new Date().toISOString(),
                        provider_message_id: resendData.id,
                    }).eq("id", msg.id);
                    sentCount++;
                } else {
                    await supabase.from("email_messages").update({
                        status: "failed",
                        failed_at: new Date().toISOString(),
                        error_message: JSON.stringify(resendData).substring(0, 500),
                    }).eq("id", msg.id);
                    failedCount++;
                }
            } catch (e) {
                await supabase.from("email_messages").update({
                    status: "failed",
                    failed_at: new Date().toISOString(),
                    error_message: String(e).substring(0, 500),
                }).eq("id", msg.id);
                failedCount++;
            }

            // Rate-limit
            await new Promise((r) => setTimeout(r, sleepMs));
        }

        // Final campaign status
        const finalStatus = failedCount === 0
            ? "sent"
            : sentCount === 0
                ? "failed"
                : "partially_failed";

        await supabase.from("email_campaigns").update({
            status: finalStatus,
            send_completed_at: new Date().toISOString(),
            sent_count: sentCount,
            failed_count: failedCount,
        }).eq("id", campaignId);

        return json({
            success: true,
            campaignId,
            totalRecipients: eligible.length,
            sentCount,
            failedCount,
        });
    } catch (e) {
        return json({ error: String(e) }, 500);
    }
});

// ----------------------------------------------------------------
// Resolve a filter to a list of {id, full_name, email}
// ----------------------------------------------------------------
async function resolveRecipients(
    supabase: ReturnType<typeof createClient>,
    agencyId: string,
    filter: RecipientFilter,
): Promise<Array<{ id: string; full_name: string; email: string | null }>> {
    if (filter.type === "specific") {
        const ids = filter.clientIds ?? [];
        if (ids.length === 0) return [];
        const { data } = await supabase
            .from("clients")
            .select("id, full_name, email, email_subscribed")
            .eq("agency_id", agencyId)
            .in("id", ids);
        return ((data ?? []) as Array<any>)
            .filter((r) => r.email_subscribed !== false)
            .map((r) => ({
                id: r.id,
                full_name: r.full_name,
                email: r.email,
            }));
    }

    if (filter.type === "by_state") {
        const states = filter.states ?? [];
        if (states.length === 0) return [];
        const { data } = await supabase
            .from("clients")
            .select("id, full_name, email, email_subscribed")
            .eq("agency_id", agencyId)
            .in("state", states);
        return ((data ?? []) as Array<any>)
            .filter((r) => r.email_subscribed !== false && r.email)
            .map((r) => ({ id: r.id, full_name: r.full_name, email: r.email }));
    }

    if (filter.type === "has_active_contract") {
        // Clients who have at least one active contract
        const { data } = await supabase
            .from("clients")
            .select(
                "id, full_name, email, email_subscribed, contracts!inner(status)",
            )
            .eq("agency_id", agencyId)
            .eq("contracts.status", "active");
        return ((data ?? []) as Array<any>)
            .filter((r) => r.email_subscribed !== false && r.email)
            .map((r) => ({ id: r.id, full_name: r.full_name, email: r.email }));
    }

    if (filter.type === "has_overdue") {
        // Clients with at least one overdue installment
        const { data } = await supabase
            .from("installments")
            .select("contract:contracts!inner(client:clients!inner(id, full_name, email, email_subscribed, agency_id))")
            .eq("status", "overdue");
        const seen = new Set<string>();
        const out: Array<{ id: string; full_name: string; email: string | null }> = [];
        for (const row of (data ?? []) as Array<any>) {
            const c = row.contract?.client;
            if (!c || c.agency_id !== agencyId) continue;
            if (c.email_subscribed === false || !c.email) continue;
            if (seen.has(c.id)) continue;
            seen.add(c.id);
            out.push({ id: c.id, full_name: c.full_name, email: c.email });
        }
        return out;
    }

    // default: all clients with email
    const { data } = await supabase
        .from("clients")
        .select("id, full_name, email, email_subscribed")
        .eq("agency_id", agencyId);
    return ((data ?? []) as Array<any>)
        .filter((r) => r.email_subscribed !== false && r.email)
        .map((r) => ({ id: r.id, full_name: r.full_name, email: r.email }));
}

function json(payload: unknown, status = 200): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}