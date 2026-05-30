// supabase/functions/email-scheduler/index.ts
// Runs every 5 minutes. Picks up campaigns where status='scheduled'
// and scheduled_for <= now(), then dispatches them via Resend.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        if (!RESEND_API_KEY || !SERVICE_ROLE_KEY) {
            return json({ error: "Server not fully configured" }, 500);
        }

        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            SERVICE_ROLE_KEY,
        );

        // Find scheduled campaigns whose time has come
        const nowIso = new Date().toISOString();
        const { data: campaigns, error: cErr } = await supabase
            .from("email_campaigns")
            .select("*")
            .eq("status", "scheduled")
            .lte("scheduled_for", nowIso)
            .order("scheduled_for", { ascending: true })
            .limit(20); // safety: never process more than 20 per tick

        if (cErr) {
            console.log(`[scheduler] Load error: ${JSON.stringify(cErr)}`);
            return json({ error: "Could not load campaigns", details: cErr }, 500);
        }

        console.log(
            `[scheduler] Found ${(campaigns ?? []).length} due campaigns`,
        );

        const results: any[] = [];

        for (const campaign of (campaigns ?? []) as Array<any>) {
            const r = await dispatchCampaign(supabase, campaign);
            results.push(r);
        }

        return json({
            success: true,
            processed: results.length,
            results,
        });
    } catch (e) {
        return json({ error: String(e) }, 500);
    }
});

async function dispatchCampaign(
    supabase: ReturnType<typeof createClient>,
    campaign: any,
) {
    console.log(`[scheduler] Dispatching campaign ${campaign.id} (${campaign.name})`);

    try {
        // 1. Mark as sending so concurrent ticks don't reprocess
        const { error: markErr } = await supabase
            .from("email_campaigns")
            .update({
                status: "sending",
                send_started_at: new Date().toISOString(),
            })
            .eq("id", campaign.id)
            .eq("status", "scheduled"); // optimistic concurrency

        if (markErr) {
            return { campaignId: campaign.id, error: "Could not claim campaign" };
        }

        // 2. Resolve recipients from the stored filter
        const recipients = await resolveRecipients(
            supabase,
            campaign.agency_id,
            campaign.recipient_filter,
        );

        // 3. Filter unsubscribes
        const { data: unsubRows } = await supabase
            .from("email_unsubscribes")
            .select("email")
            .eq("agency_id", campaign.agency_id);
        const unsubSet = new Set(
            ((unsubRows ?? []) as Array<{ email: string }>).map((r) =>
                r.email.toLowerCase()
            ),
        );
        const eligible = recipients.filter(
            (r) => r.email && !unsubSet.has(r.email.toLowerCase()),
        );

        if (eligible.length === 0) {
            await supabase.from("email_campaigns").update({
                status: "failed",
                send_completed_at: new Date().toISOString(),
                failed_count: 0,
            }).eq("id", campaign.id);
            return {
                campaignId: campaign.id,
                error: "No eligible recipients at send time",
            };
        }

        // 4. Insert message rows
        const messageRows = eligible.map((r) => ({
            campaign_id: campaign.id,
            agency_id: campaign.agency_id,
            client_id: r.id,
            to_email: r.email,
            to_name: r.full_name,
            status: "sending",
        }));
        const { data: messages, error: mErr } = await supabase
            .from("email_messages")
            .insert(messageRows)
            .select("id, to_email, to_name");

        if (mErr || !messages) {
            return {
                campaignId: campaign.id,
                error: "Could not log messages: " + JSON.stringify(mErr),
            };
        }

        // 5. Dispatch with rate limiting
        const fromHeader = `${campaign.from_name ?? "Lintel"} <onboarding@resend.dev>`;
        let sent = 0;
        let failed = 0;

        for (const m of messages as Array<any>) {
            try {
                const personalisedSubject = (campaign.subject as string).replaceAll(
                    "{{name}}",
                    m.to_name ?? "",
                );
                const personalisedHtml = (campaign.body_html as string).replaceAll(
                    "{{name}}",
                    m.to_name ?? "",
                );

                const resendRes = await fetch(RESEND_API_URL, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${RESEND_API_KEY}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        from: fromHeader,
                        to: [m.to_email],
                        subject: personalisedSubject,
                        html: personalisedHtml,
                        reply_to: campaign.reply_to_email ?? undefined,
                    }),
                });

                const resendData = await resendRes.json();

                if (resendRes.ok) {
                    await supabase.from("email_messages").update({
                        status: "sent",
                        sent_at: new Date().toISOString(),
                        provider_message_id: resendData.id,
                    }).eq("id", m.id);
                    sent++;
                } else {
                    await supabase.from("email_messages").update({
                        status: "failed",
                        failed_at: new Date().toISOString(),
                        error_message: JSON.stringify(resendData).substring(0, 500),
                    }).eq("id", m.id);
                    failed++;
                }
            } catch (e) {
                await supabase.from("email_messages").update({
                    status: "failed",
                    failed_at: new Date().toISOString(),
                    error_message: String(e).substring(0, 500),
                }).eq("id", m.id);
                failed++;
            }

            await new Promise((r) => setTimeout(r, 600));
        }

        // 6. Finalise
        const finalStatus = failed === 0
            ? "sent"
            : sent === 0
                ? "failed"
                : "partially_failed";

        await supabase.from("email_campaigns").update({
            status: finalStatus,
            send_completed_at: new Date().toISOString(),
            sent_count: sent,
            failed_count: failed,
        }).eq("id", campaign.id);

        return {
            campaignId: campaign.id,
            sent,
            failed,
            total: eligible.length,
        };
    } catch (e) {
        await supabase.from("email_campaigns").update({
            status: "failed",
            send_completed_at: new Date().toISOString(),
        }).eq("id", campaign.id);
        return { campaignId: campaign.id, error: String(e) };
    }
}

// Same logic as email-send-bulk's resolver — keep in sync
async function resolveRecipients(
    supabase: ReturnType<typeof createClient>,
    agencyId: string,
    filter: any,
): Promise<Array<{ id: string; full_name: string; email: string | null }>> {
    const type = filter?.type as string | undefined;

    if (type === "specific") {
        const ids = (filter.client_ids as string[] | undefined) ?? [];
        if (ids.length === 0) return [];
        const { data } = await supabase
            .from("clients")
            .select("id, full_name, email, email_subscribed")
            .eq("agency_id", agencyId)
            .in("id", ids);
        return ((data ?? []) as Array<any>)
            .filter((r) => r.email_subscribed !== false && r.email)
            .map((r) => ({ id: r.id, full_name: r.full_name, email: r.email }));
    }

    if (type === "by_state") {
        const states = (filter.states as string[] | undefined) ?? [];
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

    if (type === "has_active_contract") {
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

    if (type === "has_overdue") {
        const { data } = await supabase
            .from("installments")
            .select(
                "contract:contracts!inner(client:clients!inner(id, full_name, email, email_subscribed, agency_id))",
            )
            .eq("status", "overdue");
        const seen = new Set<string>();
        const out: Array<{ id: string; full_name: string; email: string | null }> =
            [];
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