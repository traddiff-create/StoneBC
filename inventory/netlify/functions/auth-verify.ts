import { getStore } from "@netlify/blobs";
import { signJWT } from "../lib/jwt";

const SESSION_TTL_SECONDS = 60 * 60 * 24 * 7; // 7 days
const COOKIE_NAME = "sbc_session";

export default async (req: Request): Promise<Response> => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  if (!token) {
    return errorPage("Missing token", "No sign-in token in the link. Try requesting a new one.");
  }

  const store = getStore("auth");
  const key = `token:${token}`;
  const record = (await store.get(key, { type: "json" })) as
    | { email: string; expiresAt: number; used: boolean }
    | null;

  if (!record) {
    return errorPage(
      "Link not found",
      "This sign-in link is invalid or has already been used."
    );
  }
  if (record.used) {
    return errorPage(
      "Link already used",
      "This sign-in link has already been used. For security, each link works only once. Request a new one."
    );
  }
  if (Date.now() > record.expiresAt) {
    return errorPage("Link expired", "This sign-in link has expired. Request a new one.");
  }

  await store.setJSON(key, { ...record, used: true });

  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    return errorPage("Not configured", "SESSION_SECRET is not set on this site.");
  }

  const jwt = await signJWT({ sub: record.email, email: record.email }, secret, SESSION_TTL_SECONDS);

  const cookie = [
    `${COOKIE_NAME}=${jwt}`,
    `Path=/`,
    `Max-Age=${SESSION_TTL_SECONDS}`,
    `HttpOnly`,
    `Secure`,
    `SameSite=Lax`,
  ].join("; ");

  return new Response(null, {
    status: 302,
    headers: {
      "location": "/",
      "set-cookie": cookie,
    },
  });
};

function errorPage(title: string, message: string): Response {
  const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>${escapeHtml(title)}</title>
<style>
body { font-family: -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; }
.card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 32px; max-width: 440px; text-align: center; }
h1 { color: #f87171; margin: 0 0 16px; font-size: 1.5rem; }
p { color: #cbd5e1; margin: 8px 0 16px; line-height: 1.5; }
a { color: #60a5fa; text-decoration: none; font-weight: 600; }
a:hover { text-decoration: underline; }
</style></head>
<body><div class="card">
<h1>${escapeHtml(title)}</h1>
<p>${escapeHtml(message)}</p>
<p><a href="/login">&larr; Back to sign-in</a></p>
</div></body></html>`;
  return new Response(html, {
    status: 400,
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
