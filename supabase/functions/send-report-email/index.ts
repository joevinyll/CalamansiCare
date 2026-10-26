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
  scanned_at?: string | null;
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
    const authUser = await userResponse.json();
    if (typeof authUser?.id !== "string") return json({ error: "Authentication required." }, 401);
    const farmerEmail = typeof authUser.email === "string" ? authUser.email : null;
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
    const html = buildBatchReportHtml(reports, farmerEmail);
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

export function buildReportHtml(report: ReportRow, confidencePercent: number, farmerEmail: string | null = null) {
  return buildBatchReportHtml([{ ...report, confidence: confidencePercent / 100 }], farmerEmail);
}

export function reportClassification(disease: string) {
  if (disease === "Healthy Fruit" || disease === "Healthy Leaf") {
    return { risk: "No Risk", priority: "Routine", color: "#2f6b3f" };
  }
  if (disease === "HLB (Greening)" || disease === "Citrus Canker") {
    return { risk: "High Risk", priority: "High", color: "#b91c1c" };
  }
  if (Object.hasOwn(careContent, disease)) {
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
  const rank: Record<string, number> = { Routine: 0, Medium: 1, "Review required": 2, High: 3 };
  return reports.map(r => reportClassification(r.disease))
    .reduce((a, b) => rank[a.priority] >= rank[b.priority] ? a : b);
}

export function buildBatchSubject(reports: ReportRow[]) {
  return `[${highestPriority(reports).priority} priority] CalamansiCare Batch Report - ${reports.length} images`;
}

function diseaseType(disease: string): string {
  const care = Object.hasOwn(careContent, disease) ? careContent[disease] : undefined;
  return care?.kind ?? (reportClassification(disease).risk === "No Risk" ? "Healthy plant" : "Needs field confirmation");
}

function formatReportTime(value: string | null | undefined): string {
  if (!value || !Number.isFinite(Date.parse(value))) return "Not recorded";
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Manila", year: "numeric", month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit", hour12: true,
  }).formatToParts(new Date(value));
  const get = (type: string) => parts.find(part => part.type === type)?.value ?? "";
  return `${get("month")} ${get("day")}, ${get("year")} at ${get("hour")}:${get("minute")}${get("dayPeriod").toLowerCase()}`;
}

function reportTimeRange(reports: ReportRow[], field: "scanned_at" | "reported_at"): string {
  const times = reports.map(report => report[field]).filter((value): value is string =>
    typeof value === "string" && Number.isFinite(Date.parse(value)))
    .sort((a, b) => Date.parse(a) - Date.parse(b));
  if (!times.length) return "Not recorded";
  const start = formatReportTime(times[0]);
  const end = formatReportTime(times[times.length - 1]);
  const partial = times.length < reports.length ? ` (${times.length} of ${reports.length} images recorded)` : "";
  return `${start === end ? start : `${start} - ${end}`}${partial}`;
}

function careList(text: string, color: string): string {
  const keywords = /\b(disease-free seedlings|dead twigs|dead wood|copper-based spray|no proven spray that cures HLB|does not cure the tree|cannot remove existing spots|infected|disinfect|psyllids|technician|approved|confirmation|confirmed|prevention)\b/gi;
  return `<ul style="margin:6px 0 16px;padding-left:22px">${text.split(/(?<=[.!?])\s+/).map(sentence =>
    `<li style="margin:5px 0">${escapeHtml(sentence).replace(keywords, `<strong style="color:${color}">$1</strong>`)}</li>`).join("")}</ul>`;
}

function highRiskNotice(reports: ReportRow[]): string {
  const high = reports.filter(report => reportClassification(report.disease).risk === "High Risk");
  if (!high.length) return "";
  const diseases = new Set(high.map(report => report.disease));
  const explanations = [
    diseases.has("HLB (Greening)") ? "<li><strong>Suspected HLB (Greening) - bacterial disease:</strong> Citrus psyllids can spread infection between trees. Established HLB infections have no known cure, so prompt assessment and measures to limit spread are important.</li>" : "",
    diseases.has("Citrus Canker") ? "<li><strong>Suspected Citrus Canker - bacterial disease:</strong> Wind-driven rain, contaminated tools and infected planting material can spread the bacteria. Prompt assessment helps limit further spread.</li>" : "",
  ].join("");
  return `<div role="note" style="margin:18px 0;padding:16px;background:#fff1f0;border:1px solid #e3aaa4;border-left:5px solid #b91c1c;border-radius:6px">
    <h3 style="margin:0 0 8px;color:#b91c1c">HIGH-RISK NOTICE - Prompt agricultural assessment needed</h3>
    <p><strong>${high.length} of ${reports.length} images</strong> show suspected high-risk bacterial disease. These AI findings are <strong>not confirmed infections</strong>.</p>
    <ul style="padding-left:22px">${explanations}</ul>
    <h4 style="color:#b91c1c;margin-bottom:6px">For barangay agriculture staff</h4>
    <ul style="padding-left:22px">
      <li><strong>Contact the farmer promptly</strong> and refer the findings to the municipal/city agriculture office for assessment.</li>
      <li><strong>Limit movement:</strong> Advise against moving suspect seedlings, budwood or cuttings while awaiting assessment.</li>
      <li><strong>Reduce spread:</strong> Avoid working on wet trees and disinfect tools between trees. Ask a technician about monitoring citrus psyllids.</li>
      <li><strong>Confirm before intervention:</strong> Do not order tree removal or prescribe pesticide treatment solely from these AI results.</li>
    </ul></div>`;
}

export function buildBatchReportHtml(reports: ReportRow[], farmerEmail: string | null = null) {
  const first = reports[0];
  const priority = highestPriority(reports);
  const groups = new Map<string, ReportRow[]>();
  for (const report of reports) groups.set(report.disease, [...(groups.get(report.disease) ?? []), report]);
  const rows = [...groups].map(([disease, images]) => {
    const risk = reportClassification(disease);
    return `<tr style="border-bottom:1px solid #dfe8dd"><td style="color:${risk.color};font-weight:bold">${escapeHtml(disease)}</td><td>${images.length}</td><td>${Math.round(images.length / reports.length * 100)}%</td><td style="color:${risk.color}">${risk.risk}</td><td>${escapeHtml(diseaseType(disease))}</td></tr>`;
  }).join("");
  const photos = reports.map((report, i) => `<div style="margin:20px 0;border:1px solid #dfe8dd;border-radius:6px;padding:14px">
    <h3 style="margin:0 0 8px;color:#24583c;font-size:16px">Image ${i + 1}: ${escapeHtml(report.disease)} (${escapeHtml(diseaseType(report.disease))})</h3>
    <p style="font-size:13px;color:#52645a">Confidence: ${Math.round(report.confidence * 100)}% | <strong style="color:${reportClassification(report.disease).color}">${reportClassification(report.disease).risk}</strong><br>Scanned: ${formatReportTime(report.scanned_at)} (Philippine time)</p>
    ${report.image_url ? `<a href="${escapeHtml(report.image_url)}" style="color:#24583c">Open image ${i + 1}</a><br><img src="${escapeHtml(report.image_url)}" alt="Image ${i + 1}: ${escapeHtml(report.disease)}" style="display:block;width:100%;max-width:600px;height:auto;margin-top:10px;border-radius:6px">` : "<p>Image unavailable.</p>"}
    </div>`).join("");
  const care = [...groups.keys()].filter(d => Object.hasOwn(careContent, d)).sort((a, b) =>
    Number(reportClassification(b).risk === "High Risk") - Number(reportClassification(a).risk === "High Risk")).map(d => {
    const content = careContent[d];
    return `<h3 style="margin-top:24px;color:${reportClassification(d).color}">${escapeHtml(d)} - ${escapeHtml(content.kind)}</h3>
      <h4 style="color:#24583c;margin-bottom:6px">Natural care</h4>${careList(content.cultural, "#24583c")}
      <h4 style="color:#1d5b96;margin-bottom:6px">Conventional treatment</h4>${careList(content.chemical, "#1d5b96")}
      <h4 style="color:#835b0b;margin-bottom:6px">Prevention</h4>${careList(content.prevention, "#835b0b")}`;
  }).join("");
  return `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.6;color:#17251d;max-width:680px;margin:auto">
    <h2 style="color:#24583c">CalamansiCare ${reports.length === 1 ? "Disease" : "Batch"} Report</h2>
    <p style="padding:12px;background:#f0f4ea;color:${priority.color}"><strong>${priority.priority} priority | ${priority.risk}</strong></p>
    <p><strong>Farmer:</strong> ${escapeHtml(first.farmer_name ?? "Not set")}<br>
    <strong>Farmer email:</strong> ${escapeHtml(farmerEmail ?? "Not available")}<br>
    <strong>Location:</strong> ${escapeHtml(first.farmer_location ?? "Not set")}<br>
    <strong>Recipient:</strong> ${escapeHtml(first.office_email ?? "Not set")}</p>
    <p style="font-size:12px;color:#52645a"><strong>Scanned:</strong> ${reportTimeRange(reports, "scanned_at")}<br><strong>Reported:</strong> ${reportTimeRange(reports, "reported_at")}<br>All times shown in Philippine time.</p>
    <h3 style="color:#24583c">Batch results - ${reports.length} ${reports.length === 1 ? "image" : "images"}</h3>
    <table style="width:100%;border-collapse:collapse;font-size:12px" cellpadding="6"><tr style="background:#eef4ef"><th align="left">Condition</th><th>Images</th><th>Share</th><th>Risk</th><th>Type</th></tr>${rows}</table>
    ${highRiskNotice(reports)}
    ${care ? `<h2 style="color:#24583c">Recommendations</h2>${care}<p style="padding:12px;background:#fff7df"><strong>Safety reminder:</strong> Use only approved products. Follow labels, protective clothing requirements, and waiting times. Confirm findings with an agriculture technician before treatment.</p>` : ""}
    <p style="font-size:12px;color:#52645a">AI predictions are not confirmed laboratory diagnoses. Risk and priority are app triage labels, not an official severity assessment.</p>
    <h2 style="color:#24583c;border-top:2px solid #dfe8dd;padding-top:20px">Scanned images</h2>${photos}</div>`;
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
