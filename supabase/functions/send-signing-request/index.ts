// supabase/functions/send-signing-request/index.ts
const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";

interface Payload {
    to_email: string;
    to_name: string;
    signing_url: string;
    signer_role: "client" | "vendor_witness" | "buyer_witness";
    agency_name: string;
    property_label: string;
    contract_no: string;
    expires_at?: string | null;
}

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}

function escapeHtml(s: string): string {
    return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function subjectFor(p: Payload): string {
    switch (p.signer_role) {
        case "client":
            return `Please sign your contract for ${p.property_label}`;
        case "vendor_witness":
            return `Witness signature requested — ${p.contract_no}`;
        case "buyer_witness":
            return `You've been asked to witness a contract signing`;
    }
}

function headingFor(role: Payload["signer_role"]): string {
    switch (role) {
        case "client":
            return "Your contract is ready to sign";
        case "vendor_witness":
            return "Please witness this contract";
        case "buyer_witness":
            return "You've been asked to witness a signing";
    }
}

function introFor(p: Payload): string {
    const property = escapeHtml(p.property_label);
    const agency = escapeHtml(p.agency_name);
    const contract = escapeHtml(p.contract_no);
    switch (p.signer_role) {
        case "client":
            return `${agency} has prepared your sale agreement for <strong>${property}</strong>. Click below to review and sign.`;
        case "vendor_witness":
            return `${agency} has asked you to witness their signature on contract <strong>${contract}</strong>.`;
        case "buyer_witness":
            return `The purchaser has asked you to witness their signature on contract <strong>${contract}</strong> with ${agency}.`;
    }
}

function ctaFor(role: Payload["signer_role"]): string {
    return role === "client" ? "Review & sign" : "Witness & sign";
}

function renderEmail(p: Payload): string {
    const expires = p.expires_at
        ? new Date(p.expires_at).toLocaleDateString("en-GB", {
            day: "numeric",
            month: "short",
            year: "numeric",
        })
        : null;

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(subjectFor(p))}</title>
</head>
<body style="margin:0; padding:0; background-color:#f4f6f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#1a1a1a; -webkit-font-smoothing:antialiased;">

  <div style="display:none; max-height:0; overflow:hidden; mso-hide:all;">
    ${escapeHtml(subjectFor(p))}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f6f5;">
    <tr>
      <td align="center" style="padding: 48px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px; background:#ffffff; border-radius:14px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); overflow:hidden;">

          <tr>
            <td style="padding: 36px 40px 0 40px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background:#1b4332; width:36px; height:36px; border-radius:8px; vertical-align:middle; text-align:center; font-size:18px; color:#ffffff;">
                    🏠
                  </td>
                  <td style="padding-left:12px; vertical-align:middle; font-size:20px; font-weight:600; color:#1b4332; letter-spacing:-0.3px;">
                    Lintel
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding: 32px 40px 8px 40px;">
              <p style="margin:0 0 8px 0; font-size:13px; color:#7a7a7a; text-transform:uppercase; letter-spacing:0.5px;">
                Hello ${escapeHtml(p.to_name)},
              </p>
              <h1 style="margin:0 0 16px 0; font-size:24px; font-weight:600; color:#1a1a1a; letter-spacing:-0.4px; line-height:1.3;">
                ${headingFor(p.signer_role)}
              </h1>
              <p style="margin:0 0 24px 0; font-size:15px; line-height:1.6; color:#4a4a4a;">
                ${introFor(p)}
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding: 0 40px 32px 40px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background:#1b4332; border-radius:8px;">
                    <a href="${escapeHtml(p.signing_url)}"
                       style="display:inline-block; padding:14px 28px; font-size:15px; font-weight:600; color:#ffffff; text-decoration:none; letter-spacing:-0.1px;">
                      ${ctaFor(p.signer_role)}
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding: 0 40px 24px 40px;">
              <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;">
                <tr>
                  <td style="background:#f4f6f5; border:1px solid #e6e8e7; border-radius:8px; padding:14px 16px;">
                    <p style="margin:0 0 6px 0; font-size:12px; color:#7a7a7a; text-transform:uppercase; letter-spacing:0.5px;">Contract</p>
                    <p style="margin:0 0 12px 0; font-size:14px; color:#1a1a1a; font-weight:500;">${escapeHtml(p.contract_no)}</p>
                    <p style="margin:0 0 6px 0; font-size:12px; color:#7a7a7a; text-transform:uppercase; letter-spacing:0.5px;">Property</p>
                    <p style="margin:0 0 ${expires ? "12px" : "0"} 0; font-size:14px; color:#1a1a1a; font-weight:500;">${escapeHtml(p.property_label)}</p>
                    ${
        expires
            ? `<p style="margin:0 0 6px 0; font-size:12px; color:#7a7a7a; text-transform:uppercase; letter-spacing:0.5px;">Expires</p>
                           <p style="margin:0; font-size:14px; color:#1a1a1a; font-weight:500;">${expires}</p>`
            : ""
    }
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding: 0 40px 32px 40px;">
              <p style="margin:0 0 8px 0; font-size:13px; color:#7a7a7a; line-height:1.6;">
                Button not working? Copy and paste this link:
              </p>
              <p style="margin:0; font-size:13px; color:#1b4332; line-height:1.6; word-break:break-all;">
                <a href="${escapeHtml(p.signing_url)}" style="color:#1b4332; text-decoration:underline;">${escapeHtml(p.signing_url)}</a>
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding: 0 40px;">
              <div style="border-top:1px solid #eeefee;"></div>
            </td>
          </tr>

          <tr>
            <td style="padding: 24px 40px 36px 40px;">
              <p style="margin:0 0 6px 0; font-size:13px; color:#7a7a7a; line-height:1.6;">
                This link is unique to you and expires after signing. If you weren't expecting this, you can safely ignore this email.
              </p>
              <p style="margin:16px 0 0 0; font-size:12px; color:#a0a0a0; line-height:1.6;">
                Sent by Lintel on behalf of ${escapeHtml(p.agency_name)} · Lagos, Nigeria
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        if (!RESEND_API_KEY) {
            return json({ error: "RESEND_API_KEY not configured" }, 500);
        }

        const fromEmail =
            Deno.env.get("RESEND_FROM_EMAIL") ?? "hello@mail.getlintel.org";
        const fromHeader = `Lintel <${fromEmail}>`;

        const p = (await req.json()) as Payload;
        if (!p.to_email || !p.signing_url || !p.signer_role) {
            return json(
                { error: "Missing required fields (to_email, signing_url, signer_role)" },
                400,
            );
        }

        const resendRes = await fetch(RESEND_API_URL, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${RESEND_API_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                from: fromHeader,
                to: [p.to_email],
                subject: subjectFor(p),
                html: renderEmail(p),
            }),
        });

        const resendData = await resendRes.json();
        if (!resendRes.ok) {
            return json({ error: resendData }, 500);
        }

        return json({ id: resendData.id, sent_to: p.to_email });
    } catch (e) {
        return json({ error: String(e) }, 500);
    }
});