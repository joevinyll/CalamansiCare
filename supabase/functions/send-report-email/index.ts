const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type ReportRow = {
  local_report_id: string;
  office_email: string | null;
  disease: string;
  confidence: number;
  farmer_name: string | null;
  farmer_location: string | null;
  device_signature: string | null;
  image_url: string | null;
  reported_at: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const brevoApiKey = Deno.env.get("BREVO_API_KEY");
    const smtp2goApiKey = Deno.env.get("SMTP2GO_API_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const fromEmail =
      Deno.env.get("FROM_EMAIL") ?? "CalamansiCare Reports <reports@example.com>";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (
      (!brevoApiKey && !smtp2goApiKey && !resendApiKey) ||
      !supabaseUrl ||
      !serviceRoleKey
    ) {
      return json({ error: "Missing function secrets." }, 500);
    }

    const body = await req.json().catch(() => ({}));
    const localReportId = `${body.local_report_id ?? ""}`.trim();
    if (!localReportId) {
      return json({ error: "local_report_id is required." }, 400);
    }

    const reportResponse = await fetch(
      `${supabaseUrl}/rest/v1/diagnosis_reports?local_report_id=eq.${encodeURIComponent(
        localReportId,
      )}&select=local_report_id,office_email,disease,confidence,farmer_name,farmer_location,device_signature,image_url,reported_at`,
      {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      },
    );

    if (!reportResponse.ok) {
      const error = await reportResponse.text();
      await markEmailStatus(supabaseUrl, serviceRoleKey, localReportId, "failed", error);
      return json({ error }, 500);
    }

    const rows = (await reportResponse.json()) as ReportRow[];
    const report = rows[0];
    if (!report) {
      return json({ error: "Report not found." }, 404);
    }

    if (!report.office_email) {
      await markEmailStatus(
        supabaseUrl,
        serviceRoleKey,
        localReportId,
        "failed",
        "Missing office_email.",
      );
      return json({ error: "Missing office_email." }, 400);
    }

    const confidencePercent = Math.round((report.confidence ?? 0) * 100);
    const subject = `CalamansiCare Disease Report - ${report.disease}`;
    const html = buildReportHtml(report, confidencePercent);
    const emailResult = brevoApiKey
      ? await sendWithBrevo({
          apiKey: brevoApiKey,
          fromEmail,
          toEmail: report.office_email,
          subject,
          html,
        })
      : smtp2goApiKey
      ? await sendWithSmtp2go({
          apiKey: smtp2goApiKey,
          fromEmail,
          toEmail: report.office_email,
          subject,
          html,
        })
      : await sendWithResend({
          apiKey: resendApiKey!,
          fromEmail,
          toEmail: report.office_email,
          subject,
          html,
        });

    if (!emailResult.ok) {
      await markEmailStatus(
        supabaseUrl,
        serviceRoleKey,
        localReportId,
        "failed",
        emailResult.error,
      );
      return json({ error: emailResult.error }, 500);
    }

    await markEmailStatus(supabaseUrl, serviceRoleKey, localReportId, "sent", null);
    return json({ ok: true, provider: emailResult.provider, result: emailResult.result });
  } catch (error) {
    return json({ error: `${error}` }, 500);
  }
});

type EmailSendResult =
  | { ok: true; provider: string; result: unknown }
  | { ok: false; provider: string; error: string };

async function sendWithBrevo({
  apiKey,
  fromEmail,
  toEmail,
  subject,
  html,
}: {
  apiKey: string;
  fromEmail: string;
  toEmail: string;
  subject: string;
  html: string;
}): Promise<EmailSendResult> {
  const sender = parseFromEmail(fromEmail);
  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      accept: "application/json",
      "api-key": apiKey,
    },
    body: JSON.stringify({
      sender,
      to: [{ email: toEmail }],
      subject,
      htmlContent: html,
      textContent: stripHtml(html),
    }),
  });
  const text = await response.text();
  if (!response.ok) {
    return { ok: false, provider: "brevo", error: text };
  }
  return { ok: true, provider: "brevo", result: safeJson(text) };
}

async function sendWithSmtp2go({
  apiKey,
  fromEmail,
  toEmail,
  subject,
  html,
}: {
  apiKey: string;
  fromEmail: string;
  toEmail: string;
  subject: string;
  html: string;
}): Promise<EmailSendResult> {
  const response = await fetch("https://api.smtp2go.com/v3/email/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Smtp2go-Api-Key": apiKey,
      accept: "application/json",
    },
    body: JSON.stringify({
      sender: fromEmail,
      to: [toEmail],
      subject,
      html_body: html,
      text_body: stripHtml(html),
    }),
  });
  const text = await response.text();
  const result = safeJson(text);
  const failed =
    typeof result === "object" &&
    result !== null &&
    "data" in result &&
    typeof (result as { data?: { failed?: unknown } }).data?.failed === "number" &&
    ((result as { data: { failed: number } }).data.failed > 0);

  if (!response.ok || failed) {
    return {
      ok: false,
      provider: "smtp2go",
      error: typeof result === "string" ? result : JSON.stringify(result),
    };
  }
  return { ok: true, provider: "smtp2go", result };
}

async function sendWithResend({
  apiKey,
  fromEmail,
  toEmail,
  subject,
  html,
}: {
  apiKey: string;
  fromEmail: string;
  toEmail: string;
  subject: string;
  html: string;
}): Promise<EmailSendResult> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [toEmail],
      subject,
      html,
    }),
  });
  const text = await response.text();
  if (!response.ok) {
    return { ok: false, provider: "resend", error: text };
  }
  return { ok: true, provider: "resend", result: safeJson(text) };
}

function buildReportHtml(report: ReportRow, confidencePercent: number) {
  const image = report.image_url
    ? `<p><strong>Image:</strong><br><a href="${escapeHtml(report.image_url)}">View report image</a></p><img src="${escapeHtml(report.image_url)}" alt="Calamansi report image" style="max-width:520px;width:100%;border-radius:12px;border:1px solid #dfe8dd;" />`
    : "<p><strong>Image:</strong> No uploaded image.</p>";

  return `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#163224;">
      <h2>CalamansiCare Disease Report</h2>
      <p>A new calamansi disease report was submitted.</p>
      <table cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
        <tr><td><strong>Farmer</strong></td><td>${escapeHtml(report.farmer_name ?? "-")}</td></tr>
        <tr><td><strong>Location</strong></td><td>${escapeHtml(report.farmer_location ?? "-")}</td></tr>
        <tr><td><strong>Disease</strong></td><td>${escapeHtml(report.disease)}</td></tr>
        <tr><td><strong>Confidence</strong></td><td>${confidencePercent}%</td></tr>
        <tr><td><strong>Device</strong></td><td>${escapeHtml(report.device_signature ?? "-")}</td></tr>
        <tr><td><strong>Reported at</strong></td><td>${escapeHtml(report.reported_at ?? "-")}</td></tr>
      </table>
      ${image}
    </div>
  `;
}

async function markEmailStatus(
  supabaseUrl: string,
  serviceRoleKey: string,
  localReportId: string,
  status: "sent" | "failed",
  error: string | null,
) {
  await fetch(
    `${supabaseUrl}/rest/v1/diagnosis_reports?local_report_id=eq.${encodeURIComponent(
      localReportId,
    )}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        email_status: status,
        email_sent_at: status === "sent" ? new Date().toISOString() : null,
        email_error: error,
      }),
    },
  );
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function safeJson(value: string) {
  try {
    return JSON.parse(value);
  } catch (_) {
    return value;
  }
}

function stripHtml(value: string) {
  return value
    .replaceAll(/<br\s*\/?>/gi, "\n")
    .replaceAll(/<\/p>/gi, "\n")
    .replaceAll(/<[^>]*>/g, "")
    .replaceAll("&nbsp;", " ")
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&#039;", "'")
    .trim();
}

function parseFromEmail(value: string) {
  const match = value.match(/^(.*)<([^>]+)>$/);
  if (!match) {
    return { email: value.trim() };
  }
  const name = match[1].trim().replace(/^"|"$/g, "");
  return { name: name || "CalamansiCare Reports", email: match[2].trim() };
}
