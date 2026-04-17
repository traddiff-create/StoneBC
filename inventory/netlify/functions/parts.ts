import {
  readResource,
  writeResource,
  jsonResponse,
  errorResponse,
} from "../lib/store";
import { logActivity } from "../lib/activity";

export default async (req: Request): Promise<Response> => {
  try {
    if (req.method === "GET") {
      const data = await readResource("parts");
      return jsonResponse(data);
    }

    if (req.method === "PUT") {
      const body = await req.json();
      if (!body || typeof body !== "object" || !Array.isArray((body as any).parts)) {
        return errorResponse("Body must be {parts: [...], purchases: [...], suppliers: [...]}", 400);
      }
      const before = (await readResource("parts")) as { parts: any[] };
      await writeResource("parts", body);
      const summary = diffParts(before.parts || [], (body as any).parts);
      await logActivity(req, "edit", "parts", summary.resourceId, summary.text);
      return jsonResponse({ ok: true });
    }

    return errorResponse("Method not allowed", 405);
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
};

function diffParts(before: any[], after: any[]): { resourceId: string; text: string } {
  const beforeIds = new Set(before.map((p) => p.id));
  const afterIds = new Set(after.map((p) => p.id));
  const added = [...afterIds].filter((id) => !beforeIds.has(id));
  const removed = [...beforeIds].filter((id) => !afterIds.has(id));
  if (added.length === 1 && removed.length === 0) {
    const p = after.find((x) => x.id === added[0]);
    return { resourceId: added[0], text: `added ${p?.name || added[0]}` };
  }
  if (removed.length === 1 && added.length === 0) {
    return { resourceId: removed[0], text: `removed ${removed[0]}` };
  }
  const changedIds: string[] = [];
  for (const p of after) {
    const prev = before.find((x) => x.id === p.id);
    if (prev && JSON.stringify(prev) !== JSON.stringify(p)) changedIds.push(p.id);
  }
  if (changedIds.length === 1) {
    const id = changedIds[0];
    const curr = after.find((x) => x.id === id);
    return { resourceId: id, text: `edited ${curr?.name || id}` };
  }
  return { resourceId: "batch", text: `saved (${after.length} parts)` };
}
