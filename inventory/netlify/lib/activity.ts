import { getStore } from "@netlify/blobs";
import { verifyJWT, parseCookies } from "./jwt";

const STORE_NAME = "inventory";
const KEY = "activity";
const MAX_ENTRIES = 500;
const COOKIE_NAME = "sbc_session";

export type ActivityEntry = {
  ts: string;
  actor: string;
  action: string;
  resource: string;
  resource_id: string;
  summary: string;
};

export type ActivityDoc = {
  entries: ActivityEntry[];
};

async function getActor(req: Request): Promise<string> {
  const cookies = parseCookies(req.headers.get("cookie"));
  const token = cookies[COOKIE_NAME];
  if (!token) return "unknown";
  const secret = process.env.SESSION_SECRET;
  if (!secret) return "unknown";
  try {
    const payload = await verifyJWT(token, secret);
    return (payload?.email as string) || (payload?.sub as string) || "unknown";
  } catch {
    return "unknown";
  }
}

/**
 * Append an activity entry. Swallows errors so a logging failure never
 * breaks the main request.
 */
export async function logActivity(
  req: Request,
  action: string,
  resource: string,
  resourceId: string,
  summary: string
): Promise<void> {
  try {
    const actor = await getActor(req);
    const entry: ActivityEntry = {
      ts: new Date().toISOString(),
      actor,
      action,
      resource,
      resource_id: resourceId,
      summary: (summary || "").slice(0, 200),
    };

    const store = getStore(STORE_NAME);
    const existing = (await store.get(KEY, { type: "json" })) as ActivityDoc | null;
    const entries = existing?.entries ?? [];
    const next: ActivityDoc = {
      entries: [entry, ...entries].slice(0, MAX_ENTRIES),
    };
    await store.setJSON(KEY, next);
  } catch (err) {
    console.error("[activity] log failed:", (err as Error).message);
  }
}

export async function readActivity(): Promise<ActivityDoc> {
  const store = getStore(STORE_NAME);
  const existing = (await store.get(KEY, { type: "json" })) as ActivityDoc | null;
  return existing ?? { entries: [] };
}
