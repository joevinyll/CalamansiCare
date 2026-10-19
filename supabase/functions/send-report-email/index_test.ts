import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  approvedImageUrl,
  buildReportHtml,
  cityOnlyReportLocation,
  handleRequest,
} from "./index.ts";

Deno.test("report locations are reduced to a city or municipality", () => {
  assertEquals(cityOnlyReportLocation("Calinan, Davao City"), "Davao City");
  assertEquals(cityOnlyReportLocation("Digos City, Davao del Sur"), "Digos City");
  assertEquals(cityOnlyReportLocation("Bansalan, Davao del Sur"), "Bansalan");
  assertEquals(cityOnlyReportLocation("Purok 4, Barangay San Roque"), "General area");
  assertEquals(cityOnlyReportLocation(null), "General area");

  const html = buildReportHtml({
    local_report_id: "report-1",
    office_email: "office@example.com",
    disease: "Anthracnose",
    confidence: 0.9,
    farmer_name: "Farmer",
    farmer_location: "Purok 4, Calinan, Davao City",
    device_signature: null,
    image_url: null,
    reported_at: null,
  }, 90);
  assertEquals(html.includes("Davao City"), true);
  assertEquals(html.includes("Purok 4"), false);
});

Deno.test("rejects missing authorization before requiring secrets", async () => {
  const response = await handleRequest(new Request("https://local.test", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ local_report_id: "valid-report-id" }),
  }));
  assertEquals(response.status, 401);
});

Deno.test("rejects non-POST requests", async () => {
  const response = await handleRequest(new Request("https://local.test", { method: "GET" }));
  assertEquals(response.status, 405);
});

Deno.test("only accepts report images from this Supabase project", () => {
  const base = "https://project.supabase.co";
  assertEquals(approvedImageUrl(
    `${base}/storage/v1/object/public/report-images/reports/id.webp`, base),
  `${base}/storage/v1/object/public/report-images/reports/id.webp`);
  assertEquals(approvedImageUrl("https://attacker.test/track", base), null);
  assertEquals(approvedImageUrl("http://project.supabase.co/image", base), null);
  assertEquals(approvedImageUrl(
    "https://project.supabase.co/storage/v1/object/public/private/secret", base), null);
});
