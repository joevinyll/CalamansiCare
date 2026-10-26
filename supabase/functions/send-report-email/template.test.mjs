import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildReportHtml, buildReportSubject, reportClassification, buildBatchReportHtml, buildBatchSubject, validReportIds, handleRequest } from './index.ts';
import { careContent } from './care-content.ts';

const base = {
  local_report_id: 'report-1', office_email: 'office@example.com',
  disease: 'Melanose', confidence: .99, farmer_name: '<Farmer>',
  farmer_location: 'Purok 4, Calinan, Davao City', device_signature: 'SECRET-DEVICE',
  image_url: 'https://project.supabase.co/storage/v1/object/public/report-images/test.webp',
  reported_at: '2026-10-22T08:00:00Z', scanned_at: '2026-10-22T07:30:00Z',
};
const plainText = html => html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').replace(/\s+([.,;:])/g, '$1');
test('email includes report details, image, risk, priority and existing recommendations', () => {
  const html = buildReportHtml(base, 99);
  for (const value of ['office@example.com', '&lt;Farmer&gt;', base.farmer_location,
    base.image_url, '99%', 'Medium Risk', 'Medium priority', 'Fungal disease',
    'Natural care', 'Conventional treatment', 'Prevention', 'dead twigs']) {
    assert.ok(html.includes(value), value);
  }
  assert.ok(!html.includes('SECRET-DEVICE'));
  assert.ok(!html.includes('<strong>Device</strong>'));
  assert.ok(!html.includes('<Farmer>'));
  assert.ok(!html.includes('report-1'));
  assert.ok(html.indexOf('Recommendations') < html.indexOf('<img'));
  for (const value of [careContent.Melanose.cultural, careContent.Melanose.chemical, careContent.Melanose.prevention]) {
    assert.ok(plainText(html).includes(value), value);
  }
});
test('disease determines subject priority, healthy has no treatment', () => {
  for (const disease of ['HLB (Greening)', 'Citrus Canker']) {
    assert.equal(reportClassification(disease).risk, 'High Risk');
    assert.ok(buildReportSubject(disease).startsWith('[High priority]'));
  }
  for (const disease of ['Healthy Fruit', 'Healthy Leaf']) {
    const html = buildReportHtml({...base, disease}, 99);
    assert.ok(html.includes('No Risk'));
    assert.ok(!html.includes('Natural care'));
    assert.ok(!html.includes('Conventional treatment'));
  }
  assert.equal(reportClassification('Unknown').risk, 'Unassessed');
  assert.ok(!buildReportSubject('bad\nsubject').includes('\n'));
});
test('backend recommendations match the existing Flutter guidance', () => {
  const dart = readFileSync(new URL('../../../lib/data/treatment_content.dart', import.meta.url), 'utf8');
  for (const content of Object.values(careContent)) {
    for (const value of Object.values(content)) assert.ok(dart.includes(value));
  }
});

test('bullet formatting preserves every condition\'s complete care guidance', () => {
  for (const [disease, content] of Object.entries(careContent)) {
    const text = plainText(buildBatchReportHtml([{...base, disease}]));
    for (const value of [content.cultural, content.chemical, content.prevention]) {
      assert.ok(text.includes(value), `${disease}: ${value}`);
    }
  }
});

test('batch email includes every image, grouped care once and highest priority', () => {
  const reports = [base, {...base, local_report_id: 'report-2', disease: 'HLB (Greening)'},
    {...base, local_report_id: 'report-3'}];
  const html = buildBatchReportHtml(reports);
  assert.equal(buildBatchSubject(reports), '[High priority] CalamansiCare Batch Report - 3 images');
  for (let i = 1; i <= 3; i++) assert.ok(html.includes(`Image ${i}:`));
  assert.equal(plainText(html).split(careContent.Melanose.cultural).length - 1, 1);
  assert.ok(!html.includes('SECRET-DEVICE'));
  assert.ok(html.includes('67%'));
  assert.ok(html.includes('High Risk'));
});

test('email puts verified farmer email first, alerts after results, and labelled photos last', () => {
  const html = buildBatchReportHtml([
    {...base, local_report_id:'device-secret-1', disease:'Citrus Canker'},
    {...base, local_report_id:'device-secret-2', disease:'HLB (Greening)'},
    {...base, disease:'Healthy Fruit'},
  ], 'farmer@example.com');
  assert.ok(html.indexOf('farmer@example.com') < html.indexOf('Batch results'));
  assert.ok(!html.includes('device-secret'));
  assert.ok(!html.includes('Report ID'));
  const tableEnd = html.indexOf('</table>', html.indexOf('Batch results'));
  const warning = html.indexOf('HIGH-RISK NOTICE');
  assert.ok(tableEnd < warning);
  assert.ok(warning < html.indexOf('Recommendations'));
  assert.ok(html.indexOf('Recommendations') < html.indexOf('Scanned images'));
  assert.ok(html.includes('Image 1: Citrus Canker (Bacterial disease)'));
  assert.ok(html.includes('Image 3: Healthy Fruit (Healthy plant)'));
  assert.ok(html.includes('2 of 3 images'));
  assert.ok(html.includes('psyllids'));
  assert.ok(html.toLowerCase().includes('wind-driven rain'));
  assert.ok(html.includes('suspected'));
  assert.ok(html.includes('not confirmed'));
  assert.ok(html.includes('3:30pm'));
  assert.ok(html.includes('4:00pm'));
  assert.ok(html.includes('Philippine time'));
  assert.ok(html.includes('<ul'));
  assert.ok(html.includes('<li'));
});

test('healthy and medium risk reports do not produce a high-risk warning', () => {
  for (const disease of ['Healthy Fruit', 'Healthy Leaf', 'Melanose']) {
    assert.ok(!buildBatchReportHtml([{...base, disease}]).includes('HIGH-RISK NOTICE'));
  }
  assert.ok(buildBatchSubject([{...base, disease:'Unknown'}, {...base, disease:'HLB (Greening)'}]).startsWith('[High priority]'));
});

test('missing scan time is not fabricated from report time and HTML remains escaped', () => {
  const html = buildBatchReportHtml([{...base, scanned_at:null,
    disease:'<script>alert(1)</script>'}], '<img src=x onerror=alert(1)>');
  assert.ok(html.includes('Not recorded'));
  assert.ok(html.includes('&lt;script&gt;'));
  assert.ok(!html.includes('<script>'));
  assert.ok(!html.includes('<img src=x'));
  for (const disease of ['constructor', '__proto__']) {
    assert.equal(reportClassification(disease).risk, 'Unassessed');
    assert.ok(!buildBatchReportHtml([{...base, disease}]).includes('Natural care'));
  }
});

test('batch IDs are bounded, unique and validated', () => {
  assert.ok(validReportIds(['a', 'b']));
  for (const ids of [[], ['a', 'a'], Array(11).fill('a'), ['bad/id'], null]) {
    assert.equal(validReportIds(ids), false);
  }
});

test('one authenticated batch request calls the email provider only once', async () => {
  const savedFetch = globalThis.fetch;
  const savedDeno = globalThis.Deno;
  const calls = [];
  globalThis.Deno = {env: {get: name => ({BREVO_API_KEY:'test', SUPABASE_URL:'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY:'test', FROM_EMAIL:'reports@example.com'})[name]}};
  globalThis.fetch = async (url, options = {}) => {
    calls.push(String(url));
    if (String(url).endsWith('/auth/v1/user')) return Response.json({id:'owner', email:'verified-farmer@example.com'});
    if (String(url).includes('/rpc/claim_batch_report_email')) {
      assert.deepEqual(JSON.parse(options.body).report_ids, ['report-1', 'report-2']);
      return Response.json({status:'claimed', reports:[base, {...base, local_report_id:'report-2'}]});
    }
    if (String(url).includes('api.brevo.com')) {
      const payload = JSON.parse(options.body);
      assert.ok(payload.htmlContent.includes('verified-farmer@example.com'));
      assert.ok(!payload.htmlContent.includes('spoofed@example.com'));
      assert.ok(!('attachment' in payload));
    }
    return Response.json({messageId:'sent'});
  };
  try {
    const response = await handleRequest(new Request('https://local.test', {
      method:'POST', headers:{Authorization:'Bearer test'},
      body:JSON.stringify({local_report_ids:['report-1','report-2'], farmer_email:'spoofed@example.com'})}));
    assert.equal(response.status, 200);
    assert.equal(calls.filter(url => url.includes('api.brevo.com')).length, 1);
    assert.equal(calls.filter(url => url.includes('/rest/v1/diagnosis_reports?')).length, 2);
  } finally { globalThis.fetch = savedFetch; globalThis.Deno = savedDeno; }
});

test('claimed or partially delivered batches never call the provider again', async () => {
  const savedFetch = globalThis.fetch;
  const savedDeno = globalThis.Deno;
  globalThis.Deno = {env:{get:name => ({BREVO_API_KEY:'test',
    SUPABASE_URL:'https://project.supabase.co', SUPABASE_SERVICE_ROLE_KEY:'test'})[name]}};
  try {
    for (const status of ['already_claimed', 'partial_claim', 'rate_limited']) {
      let providerCalls = 0;
      globalThis.fetch = async url => {
        if (String(url).endsWith('/auth/v1/user')) return Response.json({id:'owner'});
        if (String(url).includes('/rpc/')) return Response.json({status});
        providerCalls++;
        return Response.json({});
      };
      const response = await handleRequest(new Request('https://local.test', {
        method:'POST', headers:{Authorization:'Bearer test'},
        body:JSON.stringify({local_report_ids:['report-1','report-2']})}));
      assert.equal(response.status, status === 'already_claimed' ? 200 : status === 'rate_limited' ? 429 : 409);
      assert.equal(providerCalls, 0);
    }
  } finally { globalThis.fetch = savedFetch; globalThis.Deno = savedDeno; }
});
