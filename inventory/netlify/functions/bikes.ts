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
      const data = await readResource("bikes");
      return jsonResponse(data);
    }

    if (req.method === "PUT") {
      const body = await req.json();
      if (!body || typeof body !== "object" || !Array.isArray((body as any).bikes)) {
        return errorResponse("Body must be {bikes: [...]}", 400);
      }
      const before = (await readResource("bikes")) as { bikes: any[] };
      await writeResource("bikes", body);
      const summary = diffBikes(before.bikes || [], (body as any).bikes);
      await logActivity(req, "edit", "bikes", summary.resourceId, summary.text);
      return jsonResponse({ ok: true });
    }

    return errorResponse("Method not allowed", 405);
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
};

function diffBikes(before: any[], after: any[]): { resourceId: string; text: string } {
  const beforeIds = new Set(before.map((b) => b.id));
  const afterIds = new Set(after.map((b) => b.id));
  const added = [...afterIds].filter((id) => !beforeIds.has(id));
  const removed = [...beforeIds].filter((id) => !afterIds.has(id));
  if (added.length === 1 && removed.length === 0) {
    return { resourceId: added[0], text: `added ${added[0]}` };
  }
  if (removed.length === 1 && added.length === 0) {
    return { resourceId: removed[0], text: `deleted ${removed[0]}` };
  }
  // field-level change detection on a single bike
  const changedIds: string[] = [];
  for (const b of after) {
    const prev = before.find((x) => x.id === b.id);
    if (prev && JSON.stringify(prev) !== JSON.stringify(b)) changedIds.push(b.id);
  }
  if (changedIds.length === 1) {
    const id = changedIds[0];
    const prev = before.find((x) => x.id === id);
    const curr = after.find((x) => x.id === id);
    if (prev && curr && prev.status !== curr.status) {
      return { resourceId: id, text: `${id} status: ${prev.status} → ${curr.status}` };
    }
    return { resourceId: id, text: `edited ${id}` };
  }
  if (changedIds.length > 1) {
    return { resourceId: "batch", text: `batch edit (${changedIds.length} bikes)` };
  }
  return { resourceId: "batch", text: `saved (${after.length} bikes)` };
}
