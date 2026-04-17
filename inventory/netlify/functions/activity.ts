import { readActivity } from "../lib/activity";

export default async (req: Request): Promise<Response> => {
  try {
    if (req.method !== "GET") {
      return json({ error: "GET required" }, 405);
    }
    const doc = await readActivity();
    return json(doc);
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}
