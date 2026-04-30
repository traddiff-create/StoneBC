import { getStore } from '@netlify/blobs';

const STORE_NAME = 'mailer-opt-outs';
const TOKEN_PATTERN = /^[0-9a-f-]{32,64}$/i;

export default async function handler(req) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return html(responsePage(), 405);
  }

  const url = new URL(req.url);
  const token = extractToken(url);

  if (token && TOKEN_PATTERN.test(token)) {
    const store = getStore(STORE_NAME);
    await store.setJSON(`token:${token}`, {
      token,
      optedOutAt: new Date().toISOString(),
      source: 'stonebc-mailer',
      userAgent: req.headers.get('user-agent') || null,
    });
  }

  return html(responsePage());
}

function extractToken(url) {
  const queryToken = url.searchParams.get('token');
  if (queryToken) return queryToken.trim();

  const parts = url.pathname.split('/').filter(Boolean);
  return parts.at(-1)?.trim() || '';
}

function responsePage() {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Unsubscribed - Stone Bicycle Coalition</title>
  <style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0f172a;color:#e2e8f0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    main{max-width:420px;padding:32px;text-align:center}
    h1{color:#f97316;font-size:28px;margin:0 0 12px}
    p{color:#94a3b8;line-height:1.5;margin:0}
  </style>
</head>
<body>
  <main>
    <h1>You're unsubscribed</h1>
    <p>Stone Bicycle Coalition has recorded your request. You will be removed from future mass emails.</p>
  </main>
</body>
</html>`;
}

function html(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}
