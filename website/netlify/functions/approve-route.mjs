import { getStore } from '@netlify/blobs';
import { Resend } from 'resend';

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'stonebc2026';
const FROM_EMAIL = 'routes@stonebicyclecoalition.com';

function cors(resp) {
  resp.headers.set('Access-Control-Allow-Origin', '*');
  resp.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  resp.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  return resp;
}

function authFail() {
  return cors(new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  }));
}

function checkAuth(req) {
  const auth = req.headers.get('Authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  return token === ADMIN_PASSWORD;
}

export default async function handler(req) {
  if (req.method === 'OPTIONS') {
    return cors(new Response(null, { status: 204 }));
  }

  if (!checkAuth(req)) return authFail();

  const store = getStore('route-submissions');

  // GET /api/approve-route — list pending submissions
  if (req.method === 'GET') {
    const { blobs } = await store.list({ prefix: '' });
    const metaKeys = blobs.map(b => b.key).filter(k => k.endsWith('/meta'));

    const submissions = await Promise.all(
      metaKeys.map(async key => {
        try {
          return await store.getJSON(key);
        } catch {
          return null;
        }
      })
    );

    const pending = submissions
      .filter(s => s && s.status === 'pending')
      .sort((a, b) => new Date(b.submittedAt) - new Date(a.submittedAt));

    return cors(new Response(JSON.stringify(pending), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }));
  }

  // POST /api/approve-route — approve or reject a submission
  if (req.method === 'POST') {
    let body;
    try {
      body = await req.json();
    } catch {
      return cors(new Response(JSON.stringify({ error: 'Invalid JSON' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      }));
    }

    const { id, action, note } = body;
    if (!id || !['approve', 'reject'].includes(action)) {
      return cors(new Response(JSON.stringify({ error: 'Invalid request' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      }));
    }

    const meta = await store.getJSON(`${id}/meta`);
    if (!meta) {
      return cors(new Response(JSON.stringify({ error: 'Submission not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      }));
    }

    meta.status = action === 'approve' ? 'approved' : 'rejected';
    meta.reviewedAt = new Date().toISOString();
    if (note) meta.reviewNote = note;
    await store.setJSON(`${id}/meta`, meta);

    // Email the submitter
    const resend = new Resend(process.env.RESEND_API_KEY);
    try {
      if (action === 'approve') {
        await resend.emails.send({
          from: FROM_EMAIL,
          to: meta.email,
          subject: `Your route "${meta.name}" is now live!`,
          html: [
            `<h2>Your route is live! 🎉</h2>`,
            `<p>Hi there,</p>`,
            `<p>Great news — your route submission <strong>${meta.name}</strong> has been reviewed and approved by the Stone Bicycle Coalition team.</p>`,
            `<p>It will appear in the StoneBC app and route library on the next update.</p>`,
            `<p>Thanks for contributing to the co-op's trail catalog. Keep riding!</p>`,
            `<p style="color:#666;font-size:13px">— Stone Bicycle Coalition, Rapid City SD</p>`,
          ].join(''),
        });
      } else {
        await resend.emails.send({
          from: FROM_EMAIL,
          to: meta.email,
          subject: `Update on your route submission: "${meta.name}"`,
          html: [
            `<h2>Route Submission Update</h2>`,
            `<p>Hi there,</p>`,
            `<p>Thank you for submitting <strong>${meta.name}</strong> to Stone Bicycle Coalition.</p>`,
            `<p>After review, we're unable to add this route to the catalog at this time.</p>`,
            note ? `<p><strong>Reviewer note:</strong> ${note}</p>` : '',
            `<p>Feel free to reach out to <a href="mailto:info@stonebicyclecoalition.com">info@stonebicyclecoalition.com</a> with any questions.</p>`,
            `<p style="color:#666;font-size:13px">— Stone Bicycle Coalition, Rapid City SD</p>`,
          ].join(''),
        });
      }
    } catch {
      // Email failure non-fatal
    }

    return cors(new Response(JSON.stringify({ ok: true, status: meta.status }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }));
  }

  return cors(new Response(JSON.stringify({ error: 'Method not allowed' }), {
    status: 405,
    headers: { 'Content-Type': 'application/json' },
  }));
}

export const config = { path: '/api/approve-route' };
