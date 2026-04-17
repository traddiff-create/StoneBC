import {
  readResource,
  writeResource,
  jsonResponse,
  errorResponse,
} from "../lib/store";

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
      await writeResource("waitlist", body);
      return jsonResponse({ ok: true });
    }

    return errorResponse("Method not allowed", 405);
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
};
