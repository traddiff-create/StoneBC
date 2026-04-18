import { getStore } from '@netlify/blobs';
import { Resend } from 'resend';

const FROM_EMAIL = 'routes@stonebicyclecoalition.com';
const TOKEN_TTL_MS = 15 * 60 * 1000; // 15 minutes

export const config = { path: '/api/magic-link' };

export default async function handler(req) {
  if (req.method === 'POST') return handleSend(req);
  if (req.method === 'GET') return handleValidate(req);
  return json({ error: 'Method not allowed' }, 405);
}

async function handleSend(req) {
  let body;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  const email = (body.email || '').trim().toLowerCase();
  if (!email || !email.includes('@')) {
    return json({ error: 'Valid email required' }, 400);
  }

  const token = crypto.randomUUID().replace(/-/g, '');
  const expiresAt = Date.now() + TOKEN_TTL_MS;
  const encoded = encodeURIComponent(email);
  const deepLink = `stonebc://auth?token=${token}&email=${encoded}`;

  const store = getStore('magic-links');
  await store.setJSON(`token:${token}`, { email, expiresAt });

  const resend = new Resend(process.env.RESEND_API_KEY);
  await resend.emails.send({
    from: FROM_EMAIL,
    to: email,
    subject: 'Your Stone Bicycle Coalition login link',
    html: `
      <p>Tap the link below to sign in to the StoneBC app. It expires in 15 minutes.</p>
      <p><a href="${deepLink}" style="font-size:18px;font-weight:bold;">Sign in to StoneBC</a></p>
      <p style="color:#888;font-size:12px;">If you didn't request this, ignore this email.</p>
    `,
  });

  return json({ ok: true });
}

async function handleValidate(req) {
  const url = new URL(req.url);
  const token = url.searchParams.get('token');
  const email = (url.searchParams.get('email') || '').toLowerCase();

  if (!token || !email) return json({ valid: false }, 400);

  const store = getStore('magic-links');
  const record = await store.getJSON(`token:${token}`);

  if (!record || record.email !== email || Date.now() > record.expiresAt) {
    return json({ valid: false }, 401);
  }

  await store.delete(`token:${token}`);
  return json({ valid: true, email });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
