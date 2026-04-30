import { getStore } from '@netlify/blobs';

const STORE_NAME = 'mailer-opt-outs';

export default async function handler(req) {
  if (req.method !== 'GET') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const expected = process.env.MAILER_SYNC_SECRET;
  if (!expected) {
    return json({ error: 'Opt-out sync is not configured' }, 503);
  }

  const auth = req.headers.get('authorization') || '';
  if (auth !== `Bearer ${expected}`) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const store = getStore(STORE_NAME);
  const { blobs } = await store.list({ prefix: 'token:' });
  const optOuts = [];

  for (const blob of blobs) {
    const record = await store.get(blob.key, { type: 'json' });
    if (record?.token) optOuts.push(record);
  }

  return json({ optOuts });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}
