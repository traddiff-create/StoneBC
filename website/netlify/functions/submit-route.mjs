import { getStore } from '@netlify/blobs';
import { Resend } from 'resend';

const REVIEW_EMAIL = 'info@stonebicyclecoalition.com';
const FROM_EMAIL = 'routes@stonebicyclecoalition.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'stonebc2026';

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export default async function handler(req) {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let formData;
  try {
    formData = await req.formData();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid form data' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const name = String(formData.get('name') || '').trim().slice(0, 100);
  const description = String(formData.get('description') || '').trim().slice(0, 1000);
  const difficulty = String(formData.get('difficulty') || '').trim();
  const category = String(formData.get('category') || '').trim();
  const email = String(formData.get('email') || '').trim().slice(0, 200);
  const gpxFile = formData.get('gpx');

  if (!name || !difficulty || !category || !email) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const validDifficulties = ['easy', 'moderate', 'hard', 'expert'];
  const validCategories = ['road', 'gravel', 'trail', 'fatbike'];
  if (!validDifficulties.includes(difficulty) || !validCategories.includes(category)) {
    return new Response(JSON.stringify({ error: 'Invalid difficulty or category' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return new Response(JSON.stringify({ error: 'Invalid email address' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const id = `sub_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const submittedAt = new Date().toISOString();

  const meta = { id, name, description, difficulty, category, email, submittedAt, status: 'pending' };

  let gpxContent = null;
  if (gpxFile && typeof gpxFile.arrayBuffer === 'function') {
    const buf = await gpxFile.arrayBuffer();
    gpxContent = Buffer.from(buf).toString('base64');
    meta.hasGpx = true;
    meta.gpxFilename = gpxFile.name || 'route.gpx';
  }

  const store = getStore('route-submissions');
  await store.setJSON(`${id}/meta`, meta);
  if (gpxContent) {
    await store.set(`${id}/gpx`, gpxContent);
  }

  // Send review notification to SBC team
  const resend = new Resend(process.env.RESEND_API_KEY);
  try {
    await resend.emails.send({
      from: FROM_EMAIL,
      to: REVIEW_EMAIL,
      subject: `New Route Submission: ${name}`,
      html: [
        '<h2>New Route Submission</h2>',
        '<table style="border-collapse:collapse;font-family:sans-serif;font-size:14px">',
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Route Name</td><td>${escapeHtml(name)}</td></tr>`,
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Difficulty</td><td>${escapeHtml(difficulty)}</td></tr>`,
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Category</td><td>${escapeHtml(category)}</td></tr>`,
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Submitted by</td><td>${escapeHtml(email)}</td></tr>`,
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Submitted at</td><td>${escapeHtml(submittedAt)}</td></tr>`,
        description ? `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Description</td><td>${escapeHtml(description)}</td></tr>` : '',
        `<tr><td style="padding:4px 12px 4px 0;font-weight:bold">Submission ID</td><td style="font-family:monospace">${escapeHtml(id)}</td></tr>`,
        '</table>',
        '<p style="margin-top:20px"><a href="https://stonebicyclecoalition.com/admin" style="background:#2563eb;color:#fff;padding:10px 20px;text-decoration:none;border-radius:6px">Review in Admin Queue</a></p>',
      ].join(''),
    });
  } catch {
    // Email failure is non-fatal — submission is already saved
  }

  return new Response(JSON.stringify({ ok: true, id }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

export const config = { path: '/api/submit-route' };
