/// <reference lib="deno.ns" />
import { careContent } from "./care-content.ts";

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

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.match(/^Bearer \S+$/i)) {
    return json({ error: "Authentication required." }, 401);
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

    // Validate the caller with Auth; never trust locally decoded JWT claims.
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: serviceRoleKey, Authorization: authorization },
    });
    if (!userResponse.ok) return json({ error: "Authentication required." }, 401);
    const rawBody = await req.text();
    if (rawBody.length > 2048) return json({ error: "Request too large." }, 413);
    const body = JSON.parse(rawBody);
    const localReportIds = body?.local_report_ids ?? [body?.local_report_id];
    if (!validReportIds(localReportIds)) {
      return json({ error: "One to ten unique report IDs are required." }, 400);
    }

    const reportResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/claim_batch_report_email`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: authorization,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ report_ids: localReportIds }),
      },
    );

    if (!reportResponse.ok) {
      return json({ error: "Unable to authorize report delivery." }, 503);
    }

    const claim = await reportResponse.json();
    if (claim.status === "already_claimed") return json({ ok: true, status: "already_claimed" });
    if (claim.status === "rate_limited") return json({ error: "Delivery limit reached." }, 429);
    if (claim.status !== "claimed" || !Array.isArray(claim.reports) || !claim.reports.length) return json({ error: "Report unavailable or partially delivered. Operator review required." }, 409);
    const reports = claim.reports as ReportRow[];
    const report = reports[0];
    // Only embed images from this project's public report bucket. HTML escaping
    // alone does not validate a URL's scheme or destination.
    for (const imageReport of reports) imageReport.image_url = approvedImageUrl(imageReport.image_url, supabaseUrl);

    if (!report.office_email) {
      await markEmailStatus(
        supabaseUrl,
        serviceRoleKey,
        localReportIds,
        "failed",
        "Missing office_email.",
      );
      return json({ error: "Missing office_email." }, 400);
    }

    const subject = buildBatchSubject(reports);
    const html = buildBatchReportHtml(reports);
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
        localReportIds,
        "failed",
        "Email provider rejected delivery. Operator review required.",
      );
      return json({ error: "Email delivery failed. Operator review required." }, 502);
    }

    await markEmailStatus(supabaseUrl, serviceRoleKey, localReportIds, "sent", null);
    return json({ ok: true, provider: emailResult.provider });
  } catch (_) {
    return json({ error: "Unable to deliver report." }, 500);
  }
}

if (import.meta.main) Deno.serve(handleRequest);

export function approvedImageUrl(value: string | null, supabaseUrl: string): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    const base = new URL(supabaseUrl);
    return url.protocol === "https:" && url.origin === base.origin &&
        !url.username && !url.password &&
        url.pathname.startsWith("/storage/v1/object/public/report-images/reports/")
      ? url.href : null;
  } catch { return null; }
}

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

export function buildReportHtml(report: ReportRow, confidencePercent: number) {
  const details = reportClassification(report.disease);
  const care = careContent[report.disease];
  const recommendations = care ? `
      <h3>Natural care</h3><p>${escapeHtml(care.cultural)}</p>
      <h3>Conventional treatment</h3><p>${escapeHtml(care.chemical)}</p>
      <h3>Prevention</h3><p>${escapeHtml(care.prevention)}</p>
      <p>Use only products approved for the crop and target problem. Follow label directions, protective clothing requirements, and waiting times. Confirm findings with an agriculture technician before treatment.</p>` : "";
  const image = report.image_url
    ? `<p><strong>Image:</strong><br><a href="${escapeHtml(report.image_url)}">View report image</a></p><img src="${escapeHtml(report.image_url)}" alt="Calamansi report image" style="max-width:520px;width:100%;border-radius:12px;border:1px solid #dfe8dd;" />`
    : "<p><strong>Image:</strong> No uploaded image.</p>";

  return `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#163224;">
      <h2>CalamansiCare Disease Report</h2>
      <p>A new calamansi disease report was submitted.</p>
      <p style="padding:12px;background:#f0f4ea;border-radius:8px;color:${details.color};"><strong>${escapeHtml(details.priority)} priority | ${escapeHtml(details.risk)}</strong></p>
      <table cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
        <tr><td><strong>Report ID</strong></td><td>${escapeHtml(report.local_report_id)}</td></tr>
        <tr><td><strong>Farmer</strong></td><td>${escapeHtml(report.farmer_name ?? "-")}</td></tr>
        <tr><td><strong>Farm location</strong></td><td>${escapeHtml(report.farmer_location ?? "Not set")}</td></tr>
        <tr><td><strong>Recipient</strong></td><td>${escapeHtml(report.office_email ?? "Not set")}</td></tr>
        <tr><td><strong>Disease</strong></td><td>${escapeHtml(report.disease)}</td></tr>
        <tr><td><strong>Confidence</strong></td><td>${confidencePercent}%</td></tr>
        <tr><td><strong>Disease type</strong></td><td>${escapeHtml(care?.kind ?? (details.risk === "No Risk" ? "Healthy plant" : "Needs field confirmation"))}</td></tr>
        <tr><td><strong>Reported at</strong></td><td>${escapeHtml(report.reported_at ?? "-")}</td></tr>
      </table>
      ${image}
      ${recommendations}
      <p style="font-size:12px;color:#52645a;">AI image prediction, not a confirmed laboratory diagnosis. Risk and priority are app triage labels, not an official severity assessment. This email covers one saved image; other batch images are delivered separately.</p>
    </div>
  `;
}

export function reportClassification(disease: string) {
  if (disease === "Healthy Fruit" || disease === "Healthy Leaf") {
    return { risk: "No Risk", priority: "Routine", color: "#2f6b3f" };
  }
  if (disease === "HLB (Greening)" || disease === "Citrus Canker") {
    return { risk: "High Risk", priority: "High", color: "#b91c1c" };
  }
  if (careContent[disease]) {
    return { risk: "Medium Risk", priority: "Medium", color: "#946512" };
  }
  return { risk: "Unassessed", priority: "Review required", color: "#52645a" };
}

export function buildReportSubject(disease: string) {
  const safeDisease = disease.replace(/[\r\n]/g, " ").slice(0, 100);
  return `[${reportClassification(disease).priority} priority] CalamansiCare Disease Report - ${safeDisease}`;
}

export function validReportIds(ids: unknown): ids is string[] {
  return Array.isArray(ids) && ids.length >= 1 && ids.length <= 10 &&
    ids.every(id => typeof id === "string" && /^[A-Za-z0-9_-]{1,200}$/.test(id)) &&
    new Set(ids).size === ids.length;
}

function highestPriority(reports: ReportRow[]) {
  const rank: Record<string, number> = { Routine: 0, Medium: 1, High: 2, "Review required": 3 };
  return reports.map(r => reportClassification(r.disease))
    .reduce((a, b) => rank[a.priority] >= rank[b.priority] ? a : b);
}

export function buildBatchSubject(reports: ReportRow[]) {
  return `[${highestPriority(reports).priority} priority] CalamansiCare Batch Report - ${reports.length} images`;
}

export function buildBatchReportHtml(reports: ReportRow[]) {
  const first = reports[0];
  const priority = highestPriority(reports);
  const groups = new Map<string, ReportRow[]>();
  for (const report of reports) groups.set(report.disease, [...(groups.get(report.disease) ?? []), report]);
  const rows = [...groups].map(([disease, images]) => {
    const risk = reportClassification(disease);
    return `<tr><td style="padding:12px;color:${risk.color}">${escapeHtml(disease)}</td><td>${images.length}</td><td>${Math.round(images.length / reports.length * 100)}%</td><td>${risk.risk}</td><td>${escapeHtml(careContent[disease]?.kind ?? (risk.risk === "No Risk" ? "Healthy plant" : "Unconfirmed"))}</td></tr>`;
  }).join("");
  const photos = reports.map((report, i) => `<div style="margin:20px 0;border-top:1px solid #dfe8dd;padding-top:12px">
    <h3>Image ${i + 1} - ${escapeHtml(report.disease)}</h3>
    <p>Confidence: ${Math.round(report.confidence * 100)}% | ${reportClassification(report.disease).risk}</p>
    <p>Report ID: ${escapeHtml(report.local_report_id)}<br>Reported at: ${escapeHtml(report.reported_at ?? "-")}</p>
    ${report.image_url ? `<a href="${escapeHtml(report.image_url)}">View image ${i + 1}</a><br><img src="${escapeHtml(report.image_url)}" alt="Report image ${i + 1}" style="width:100%;max-width:480px;border-radius:8px">` : "<p>Image unavailable.</p>"}
    </div>`).join("");
  const care = [...groups.keys()].filter(d => careContent[d]).map(d => {
    const content = careContent[d];
    return `<h3>${escapeHtml(d)}</h3><p><strong>Natural care:</strong> ${escapeHtml(content.cultural)}</p>
      <p><strong>Conventional treatment:</strong> ${escapeHtml(content.chemical)}</p>
      <p><strong>Prevention:</strong> ${escapeHtml(content.prevention)}</p>`;
  }).join("");
  return `<div style="font-family:Arial,sans-serif;line-height:1.5;color:#17251d;max-width:680px;margin:auto">
    <h2>CalamansiCare Batch Report</h2>
    <p style="padding:12px;background:#f0f4ea;color:${priority.color}"><strong>${priority.priority} priority | ${priority.risk}</strong></p>
    <p><strong>Farmer:</strong> ${escapeHtml(first.farmer_name ?? "Not set")}<br>
    <strong>Location:</strong> ${escapeHtml(first.farmer_location ?? "Not set")}<br>
    <strong>Recipient:</strong> ${escapeHtml(first.office_email ?? "Not set")}</p>
    <h3>Batch results - ${reports.length} images</h3>
    <table style="width:100%;border-collapse:collapse" cellpadding="8"><tr><th align="left">Condition</th><th>Images</th><th>Share</th><th>Risk</th><th>Type</th></tr>${rows}</table>
    <h3>Scanned images</h3>${photos}
    ${care ? `<h2>Recommendations</h2>${care}<p>Use only approved products. Follow labels, protective clothing requirements, and waiting times. Confirm findings with an agriculture technician before treatment.</p>` : ""}
    <p style="font-size:12px">AI predictions are not confirmed laboratory diagnoses. Risk and priority are app triage labels, not an official severity assessment.</p></div>`;
}

export function cityOnlyReportLocation(location: string | null): string {
  if (!location?.trim()) return "General area";

  const parts = location.split(",").map((part) => part.trim()).filter(Boolean);
  const city = parts.find((part) => /^[\p{L}][\p{L} .-]* City$/iu.test(part));
  if (city) return city;

  const municipality = parts.find((part) => /^Bansalan$/iu.test(part));
  return municipality ?? "General area";
}

async function markEmailStatus(
  supabaseUrl: string,
  serviceRoleKey: string,
  localReportIds: string[],
  status: "sent" | "failed",
  error: string | null,
) {
  await fetch(
    `${supabaseUrl}/rest/v1/diagnosis_reports?local_report_id=eq.${encodeURIComponent(
      localReportIds[0],
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
  for (const id of localReportIds.slice(1)) {
    await markEmailStatus(supabaseUrl, serviceRoleKey, [id], status, error);
  }
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
