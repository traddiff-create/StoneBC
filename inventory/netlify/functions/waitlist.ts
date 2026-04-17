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
      const data = await readResource("waitlist");
      return jsonResponse(data);
    }

    if (req.method === "PUT") {
      const body = await req.json();
      if (!body || typeof body !== "object" || !Array.isArray((body as any).applicants)) {
        return errorResponse("Body must be {applicants: [...]}", 400);
      }
      const before = (await readResource("waitlist")) as { applicants: any[] };
      await writeResource("waitlist", body);
      const summary = diffApplicants(before.applicants || [], (body as any).applicants);
      await logActivity(req, "edit", "waitlist", summary.resourceId, summary.text);
      return jsonResponse({ ok: true });
    }

    return errorResponse("Method not allowed", 405);
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
};

function diffApplicants(before: any[], after: any[]): { resourceId: string; text: string } {
  const beforeIds = new Set(before.map((a) => a.id));
  const afterIds = new Set(after.map((a) => a.id));
  const added = [...afterIds].filter((id) => !beforeIds.has(id));
  const removed = [...beforeIds].filter((id) => !afterIds.has(id));
  if (added.length === 1 && removed.length === 0) {
    const a = after.find((x) => x.id === added[0]);
    return { resourceId: added[0], text: `added ${a?.name || added[0]}` };
  }
  if (removed.length === 1 && added.length === 0) {
    return { resourceId: removed[0], text: `removed ${removed[0]}` };
  }
  const changedIds: string[] = [];
  for (const a of after) {
    const prev = before.find((x) => x.id === a.id);
    if (prev && JSON.stringify(prev) !== JSON.stringify(a)) changedIds.push(a.id);
  }
  if (changedIds.length === 1) {
    const id = changedIds[0];
    const prev = before.find((x) => x.id === id);
    const curr = after.find((x) => x.id === id);
    if (prev && curr && prev.status !== curr.status) {
      return { resourceId: id, text: `${id} status: ${prev.status} → ${curr.status}` };
    }
    return { resourceId: id, text: `edited ${curr?.name || id}` };
  }
  return { resourceId: "batch", text: `saved (${after.length} applicants)` };
}
