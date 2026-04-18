import { getStore } from '@netlify/blobs';
import { Resend } from 'resend';

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'stonebc2026';
const FROM_EMAIL = 'routes@stonebicyclecoalition.com';

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function parseGpx(gpxString) {
  const points = [...gpxString.matchAll(/<trkpt[^>]+lat="([^"]+)"[^>]+lon="([^"]+)"/g)]
    .map(m => [parseFloat(m[1]), parseFloat(m[2])]);
  if (!points.length) return null;

  let totalMeters = 0;
  for (let i = 1; i < points.length; i++) {
    totalMeters += haversineMeters(points[i-1][0], points[i-1][1], points[i][0], points[i][1]);
  }

  const elevations = [...gpxString.matchAll(/<ele>([^<]+)<\/ele>/g)].map(m => parseFloat(m[1]));
  let elevGain = 0;
  for (let i = 1; i < elevations.length; i++) {
    const diff = elevations[i] - elevations[i - 1];
    if (diff > 0) elevGain += diff;
  }

  return {
    lat: points[0][0],
    lon: points[0][1],
    distanceMiles: Math.round(totalMeters / 1609.34 * 10) / 10,
    elevationGainFeet: Math.round(elevGain * 3.28084),
  };
}

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

    // On approve: parse GPX, write to approved-routes store, trigger rebuild
    if (action === 'approve') {
      try {
        const gpxB64 = await store.get(`${id}/gpx`);
        if (gpxB64) {
          const gpxString = Buffer.from(gpxB64, 'base64').toString('utf8');
          const stats = parseGpx(gpxString) || {};
          const approvedRoute = {
            id,
            name: meta.name,
            description: meta.description || '',
            difficulty: meta.difficulty || 'moderate',
            category: meta.category || 'gravel',
            region: 'Community',
            distanceMiles: stats.distanceMiles ?? 0,
            elevationGainFeet: stats.elevationGainFeet ?? 0,
            lat: stats.lat ?? 0,
            lon: stats.lon ?? 0,
            submittedBy: meta.email,
            approvedAt: meta.reviewedAt,
            community: true,
          };
          const approvedStore = getStore('approved-routes');
          await approvedStore.setJSON(id, approvedRoute);
        }
      } catch {
        // Non-fatal — route approved but stats unavailable
      }

      if (process.env.BUILD_HOOK_URL) {
        try {
          await fetch(process.env.BUILD_HOOK_URL, { method: 'POST' });
        } catch {
          // Non-fatal — rebuild can be triggered manually
        }
      }
    }

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
