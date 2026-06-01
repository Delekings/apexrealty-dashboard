// supabase/functions/email-automation-runner/index.ts
// Runs daily. Evaluates active automations, dispatches emails to matching
// clients via Resend, updates last_run_at.

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
        if (!RESEND_API_KEY) {
            return json({ error: "RESEND_API_KEY not configured" }, 500);
        }
        if (!SERVICE_ROLE_KEY) {
            return json({ error: "SUPABASE_SERVICE_ROLE_KEY not configured" }, 500);
        }

        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            SERVICE_ROLE_KEY,
        );

        const { data: automations, error: aErr } = await supabase
            .from("email_automations_due_today")
            .select("*");

        console.log(
            `[runner] Loaded ${automations?.length ?? 0} automations from view`,
        );
        if (aErr) {
            console.log(`[runner] View load error: ${JSON.stringify(aErr)}`);
            return json({ error: "Could not load automations", details: aErr }, 500);
        }

        const results: AutomationResult[] = [];

        for (const auto of (automations ?? []) as Array<any>) {
            const result = await processAutomation(supabase, auto);
            results.push(result);

            await supabase.from("email_automations").update({
                last_run_at: new Date().toISOString(),
                total_sent_count: (auto.total_sent_count ?? 0) + result.sentCount,
            }).eq("id", auto.id);
        }

        return json({
            success: true,
            automationsProcessed: results.length,
            results,
        });
    } catch (e) {
        return json({ error: String(e) }, 500);
    }
});

interface AutomationResult {
    automationId: string;
    automationName: string;
    matchedCount: number;
    sentCount: number;
    failedCount: number;
    error?: string;
}

async function processAutomation(
    supabase: ReturnType<typeof createClient>,
    auto: any,
): Promise<AutomationResult> {
    console.log(
        `[automation] Processing: ${auto.name} (${auto.id}), trigger=${auto.trigger_type}`,
    );

    const result: AutomationResult = {
        automationId: auto.id,
        automationName: auto.name,
        matchedCount: 0,
        sentCount: 0,
        failedCount: 0,
    };

    try {
        const matches = await findMatchingClients(supabase, auto);
        console.log(`[automation] Found ${matches.length} matching clients`);
        result.matchedCount = matches.length;

        if (matches.length === 0) {
            console.log(`[automation] No matches, returning early`);
            return result;
        }

        const { data: cfg } = await supabase
            .from("email_provider_config")
            .select("from_name, reply_to_email")
            .eq("agency_id", auto.agency_id)
            .maybeSingle();

        const { data: agency } = await supabase
            .from("agencies")
            .select("name, email")
            .eq("id", auto.agency_id)
            .single();

        const fromName = cfg?.from_name ?? agency?.name ?? "Lintel";
        const replyTo = cfg?.reply_to_email ?? agency?.email ?? undefined;
        const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ?? "hello@mail.getlintel.org";
        const fromHeader = `${fromName} <${fromEmail}>`;

        const { data: unsubRows } = await supabase
            .from("email_unsubscribes")
            .select("email")
            .eq("agency_id", auto.agency_id);
        const unsubSet = new Set(
            ((unsubRows ?? []) as Array<{ email: string }>).map((r) =>
                r.email.toLowerCase()
            ),
        );
        const eligible = matches.filter(
            (m) => m.email && !unsubSet.has(m.email.toLowerCase()),
        );

        console.log(
            `[automation] Eligible after unsubscribe filter: ${eligible.length}`,
        );

        if (eligible.length === 0) return result;

        const { data: campaign, error: cErr } = await supabase
            .from("email_campaigns")
            .insert({
                agency_id: auto.agency_id,
                name: `Auto: ${auto.name}`,
                subject: auto.subject_template,
                body_html: auto.body_html_template,
                from_name: fromName,
                reply_to_email: replyTo,
                recipient_filter: { type: "automation", automation_id: auto.id },
                recipient_count: eligible.length,
                total_recipients: eligible.length,
                status: "sending",
                send_started_at: new Date().toISOString(),
                automation_id: auto.id,
            })
            .select("id")
            .single();

        if (cErr || !campaign) {
            result.error = "Could not create campaign: " + JSON.stringify(cErr);
            console.log(`[automation] ${result.error}`);
            return result;
        }
        const campaignId = campaign.id;

        const messageRows = eligible.map((r) => ({
            campaign_id: campaignId,
            agency_id: auto.agency_id,
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
            result.error = "Could not log messages: " + JSON.stringify(mErr);
            console.log(`[automation] ${result.error}`);
            return result;
        }

        const sleepMs = 600;

        for (const m of messages as Array<any>) {
            try {
                const personalisedSubject = auto.subject_template.replaceAll(
                    "{{name}}",
                    m.to_name ?? "",
                );
                const personalisedHtml = auto.body_html_template.replaceAll(
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
                        reply_to: replyTo,
                    }),
                });

                const resendData = await resendRes.json();

                if (resendRes.ok) {
                    await supabase.from("email_messages").update({
                        status: "sent",
                        sent_at: new Date().toISOString(),
                        provider_message_id: resendData.id,
                    }).eq("id", m.id);
                    result.sentCount++;
                } else {
                    await supabase.from("email_messages").update({
                        status: "failed",
                        failed_at: new Date().toISOString(),
                        error_message: JSON.stringify(resendData).substring(0, 500),
                    }).eq("id", m.id);
                    result.failedCount++;
                }
            } catch (e) {
                await supabase.from("email_messages").update({
                    status: "failed",
                    failed_at: new Date().toISOString(),
                    error_message: String(e).substring(0, 500),
                }).eq("id", m.id);
                result.failedCount++;
            }

            await new Promise((r) => setTimeout(r, sleepMs));
        }

        const finalStatus = result.failedCount === 0
            ? "sent"
            : result.sentCount === 0
                ? "failed"
                : "partially_failed";

        await supabase.from("email_campaigns").update({
            status: finalStatus,
            send_completed_at: new Date().toISOString(),
            sent_count: result.sentCount,
            failed_count: result.failedCount,
        }).eq("id", campaignId);

        return result;
    } catch (e) {
        result.error = String(e);
        console.log(`[automation] Caught exception: ${result.error}`);
        return result;
    }
}

async function findMatchingClients(
    supabase: ReturnType<typeof createClient>,
    auto: any,
): Promise<Array<{ id: string; full_name: string; email: string | null }>> {
    const triggerType = auto.trigger_type as string;
    const offsetDays = (auto.trigger_offset_days as number) ?? 0;
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    if (triggerType === "client_birthday") {
        const month = today.getUTCMonth() + 1;
        const day = today.getUTCDate();
        console.log(
            `[birthday] Looking for clients with birthday ${month}/${day} in agency ${auto.agency_id}`,
        );

        const { data, error } = await supabase
            .from("clients")
            .select("id, full_name, email, date_of_birth, email_subscribed")
            .eq("agency_id", auto.agency_id)
            .not("date_of_birth", "is", null);

        if (error) {
            console.log(`[birthday] Query error: ${JSON.stringify(error)}`);
            return [];
        }

        console.log(
            `[birthday] Initial client pool: ${(data ?? []).length} clients`,
        );

        const matches = ((data ?? []) as Array<any>).filter((c) => {
            const reason: string[] = [];
            if (!c.date_of_birth) reason.push("no DOB");
            if (!c.email) reason.push("no email");
            if (c.email_subscribed === false) reason.push("unsubscribed");

            if (reason.length > 0) {
                console.log(`[birthday] Skip ${c.full_name}: ${reason.join(", ")}`);
                return false;
            }

            const d = new Date(c.date_of_birth);
            const clientMonth = d.getUTCMonth() + 1;
            const clientDay = d.getUTCDate();
            const isMatch = clientMonth === month && clientDay === day;
            console.log(
                `[birthday] ${c.full_name}: DOB=${c.date_of_birth} -> ${clientMonth}/${clientDay} vs today ${month}/${day} -> match=${isMatch}`,
            );
            return isMatch;
        });

        console.log(`[birthday] Final matches: ${matches.length}`);

        return matches.map((c) => ({
            id: c.id,
            full_name: c.full_name,
            email: c.email,
        }));
    }

    if (triggerType === "days_after_client_onboarded") {
        const target = new Date(today);
        target.setUTCDate(target.getUTCDate() - offsetDays);
        const targetStart = target.toISOString().substring(0, 10);

        const { data } = await supabase
            .from("clients")
            .select("id, full_name, email, created_at")
            .eq("agency_id", auto.agency_id)
            .gte("created_at", `${targetStart}T00:00:00Z`)
            .lt("created_at", `${targetStart}T23:59:59Z`)
            .eq("email_subscribed", true)
            .not("email", "is", null);

        return ((data ?? []) as Array<any>).map((c) => ({
            id: c.id,
            full_name: c.full_name,
            email: c.email,
        }));
    }

    if (triggerType === "days_before_installment_due") {
        const target = new Date(today);
        target.setUTCDate(target.getUTCDate() + offsetDays);
        const targetDate = target.toISOString().substring(0, 10);

        const { data } = await supabase
            .from("installments")
            .select(`
        due_date, status,
        contract:contracts!inner(
          client:clients!inner(id, full_name, email, email_subscribed, agency_id)
        )
      `)
            .eq("due_date", targetDate)
            .eq("status", "pending");

        const seen = new Set<string>();
        const out: Array<{ id: string; full_name: string; email: string | null }> =
            [];
        for (const row of (data ?? []) as Array<any>) {
            const client = row.contract?.client;
            if (!client) continue;
            if (client.agency_id !== auto.agency_id) continue;
            if (client.email_subscribed === false || !client.email) continue;
            if (seen.has(client.id)) continue;
            seen.add(client.id);
            out.push({
                id: client.id,
                full_name: client.full_name,
                email: client.email,
            });
        }
        return out;
    }

    if (triggerType === "days_after_installment_overdue") {
        const target = new Date(today);
        target.setUTCDate(target.getUTCDate() - offsetDays);
        const targetDate = target.toISOString().substring(0, 10);

        const { data } = await supabase
            .from("installments")
            .select(`
        due_date, status,
        contract:contracts!inner(
          client:clients!inner(id, full_name, email, email_subscribed, agency_id)
        )
      `)
            .eq("due_date", targetDate)
            .eq("status", "overdue");

        const seen = new Set<string>();
        const out: Array<{ id: string; full_name: string; email: string | null }> =
            [];
        for (const row of (data ?? []) as Array<any>) {
            const client = row.contract?.client;
            if (!client) continue;
            if (client.agency_id !== auto.agency_id) continue;
            if (client.email_subscribed === false || !client.email) continue;
            if (seen.has(client.id)) continue;
            seen.add(client.id);
            out.push({
                id: client.id,
                full_name: client.full_name,
                email: client.email,
            });
        }
        return out;
    }

    if (triggerType === "contract_anniversary") {
        const month = today.getUTCMonth() + 1;
        const day = today.getUTCDate();

        const { data } = await supabase
            .from("contracts")
            .select(`
        start_date,
        client:clients!inner(id, full_name, email, email_subscribed, agency_id)
      `)
            .eq("agency_id", auto.agency_id)
            .lt("start_date", today.toISOString().substring(0, 10));

        const seen = new Set<string>();
        const out: Array<{ id: string; full_name: string; email: string | null }> =
            [];
        for (const row of (data ?? []) as Array<any>) {
            const d = new Date(row.start_date);
            if (d.getUTCMonth() + 1 !== month || d.getUTCDate() !== day) continue;
            const client = row.client;
            if (!client) continue;
            if (client.email_subscribed === false || !client.email) continue;
            if (seen.has(client.id)) continue;
            seen.add(client.id);
            out.push({
                id: client.id,
                full_name: client.full_name,
                email: client.email,
            });
        }
        return out;
    }

    if (triggerType === "on_contract_signed") {
        return [];
    }

    return [];
}

function json(payload: unknown, status = 200): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}