import type { Context } from "https://edge.netlify.com";
import { verifyJWT, parseCookies } from "../lib/jwt.ts";

const COOKIE_NAME = "sbc_session";

const PUBLIC_PATHS = new Set([
  "/login",
  "/login.html",
  "/favicon.ico",
]);

function isPublicPath(pathname: string): boolean {
  if (PUBLIC_PATHS.has(pathname)) return true;
  if (pathname.startsWith("/api/auth/")) return true;
  if (pathname.startsWith("/.netlify/")) return true;
  return false;
}

export default async (request: Request, context: Context): Promise<Response> => {
  const url = new URL(request.url);

  if (isPublicPath(url.pathname)) {
    return context.next();
  }

  const secret = Netlify.env.get("SESSION_SECRET");
  if (!secret) {
    return new Response("Server misconfigured: SESSION_SECRET missing.", {
      status: 500,
    });
  }

  const cookies = parseCookies(request.headers.get("cookie"));
  const token = cookies[COOKIE_NAME];

  if (!token) {
    return unauthorized(url);
  }

  const payload = await verifyJWT(token, secret);
  if (!payload) {
    return unauthorized(url);
  }

  return context.next();
};

function unauthorized(originalUrl: URL): Response {
  // API endpoints get a JSON 401 so the frontend can react; everything else redirects to login
  if (originalUrl.pathname.startsWith("/api/")) {
    return new Response(
      JSON.stringify({ error: "Not authenticated", login: "/login" }),
      {
        status: 401,
        headers: {
          "content-type": "application/json",
          "cache-control": "no-store",
        },
      }
    );
  }
  return new Response(null, {
    status: 302,
    headers: {
      "location": "/login",
      "cache-control": "no-store",
    },
  });
}

export const config = { path: "/*" };
