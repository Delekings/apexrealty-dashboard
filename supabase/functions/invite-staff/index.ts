// supabase/functions/invite-staff/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
// Try both env var names — Supabase has been renaming things
const SERVICE_ROLE_KEY =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SB_SERVICE_ROLE_KEY") ??
    "";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}

interface Payload {
    email: string;
    full_name: string;
    role: "manager" | "accountant" | "agent";
    is_external?: boolean;
    commission_rate_pct?: number | null;
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    // Sanity-check secrets at boot
    if (!SUPABASE_URL) {
        console.error("Missing SUPABASE_URL env var");
        return json({ error: "Server misconfigured: SUPABASE_URL missing" }, 500);
    }
    if (!SERVICE_ROLE_KEY) {
        console.error("Missing SUPABASE_SERVICE_ROLE_KEY env var");
        return json({ error: "Server misconfigured: service role key missing" }, 500);
    }

    try {
        const authHeader = req.headers.get("Authorization") ?? "";
        if (!authHeader.startsWith("Bearer ")) {
            return json({ error: "Missing bearer token" }, 401);
        }
        const userJwt = authHeader.replace("Bearer ", "");

        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

        const { data: userResp, error: userErr } =
            await admin.auth.getUser(userJwt);
        if (userErr || !userResp.user) {
            console.error("auth.getUser failed", userErr);
            return json(
                { error: `Auth failed: ${userErr?.message ?? "no user"}` },
                401,
            );
        }
        const caller = userResp.user;
        console.log("Caller resolved to:", caller.id, caller.email);

        const { data: callerProfile, error: profErr } = await admin
            .from("profiles")
            .select("id, agency_id, role")
            .eq("id", caller.id)
            .maybeSingle();

        if (profErr) {
            console.error("profile lookup error", profErr);
            return json(
                { error: `Profile lookup failed: ${profErr.message}` },
                500,
            );
        }
        if (!callerProfile) {
            console.error("no profile row for user", caller.id, caller.email);
            return json(
                {
                    error: `No profile row in DB for ${caller.email}. Try signing out and back in, or contact support.`,
                },
                403,
            );
        }
        if (callerProfile.role !== "agency_admin") {
            return json(
                { error: `Only agency admins can invite. Your role: ${callerProfile.role}` },
                403,
            );
        }
        if (!callerProfile.agency_id) {
            return json({ error: "Your profile has no agency_id" }, 403);
        }

        const p = (await req.json()) as Payload;
        const email = (p.email ?? "").trim().toLowerCase();
        if (!email || !email.includes("@")) {
            return json({ error: "Valid email is required" }, 400);
        }
        const fullName = (p.full_name ?? "").trim();
        if (!fullName) {
            return json({ error: "Full name is required" }, 400);
        }
        if (!["manager", "accountant", "agent"].includes(p.role)) {
            return json({ error: "Invalid role" }, 400);
        }

        const { data: inviteData, error: inviteErr } =
            await admin.auth.admin.inviteUserByEmail(email, {
                data: {
                    agency_id: callerProfile.agency_id,
                    role: p.role,
                    full_name: fullName,
                    is_external: !!p.is_external,
                    commission_rate_pct:
                        p.commission_rate_pct == null
                            ? null
                            : Number(p.commission_rate_pct),
                    invited_by: caller.id,
                },
                redirectTo: "https://app.getlintel.org/",
            });

        if (inviteErr) {
            console.error("inviteUserByEmail failed", inviteErr);
            return json({ error: inviteErr.message }, 400);
        }

        return json({
            user_id: inviteData.user?.id,
            email,
            invited_at: new Date().toISOString(),
        });
    } catch (e) {
        console.error("unexpected error", e);
        return json({ error: String(e) }, 500);
    }
});