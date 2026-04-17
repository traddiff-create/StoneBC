import { getStore } from "@netlify/blobs";
import partsSeed from "../../parts.json";

type Part = {
  id: string;
  name: string;
  category?: string;
  specs?: string;
  qty: number;
  reorder_at?: number;
  cost_each?: number;
  supplier_id?: string;
  sku?: string;
  notes?: string;
  updated?: string;
};

type PartsDoc = {
  parts: Part[];
  purchases?: unknown[];
  suppliers?: unknown[];
  _schema?: unknown;
};

export default async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  let body: { partId?: string; qty?: number; bikeId?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const partId = (body.partId || "").trim();
  const qty = Number(body.qty ?? 1);
  const bikeId = (body.bikeId || "").trim();

  if (!partId) return json({ error: "partId required" }, 400);
  if (!Number.isFinite(qty) || qty === 0) {
    return json({ error: "qty must be a non-zero number (positive to consume, negative to restock)" }, 400);
  }

  const store = getStore("inventory");
  const existing = (await store.get("parts", { type: "json" })) as PartsDoc | null;
  const data: PartsDoc = existing ?? (partsSeed as PartsDoc);

  const idx = data.parts.findIndex((p) => p.id === partId);
  if (idx < 0) {
    return json({ error: `Part ${partId} not found` }, 404);
  }

  const before = data.parts[idx].qty || 0;
  const after = before - qty;
  data.parts[idx] = {
    ...data.parts[idx],
    qty: after,
    updated: new Date().toISOString(),
  };

  await store.setJSON("parts", data);

  const isLow =
    typeof data.parts[idx].reorder_at === "number" &&
    after <= (data.parts[idx].reorder_at as number);

  return json({
    ok: true,
    part: data.parts[idx],
    change: { before, after, delta: -qty, bikeId: bikeId || null },
    lowStock: isLow,
  });
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}
