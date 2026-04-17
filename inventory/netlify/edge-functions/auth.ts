import type { Context } from "https://edge.netlify.com";

const REALM = 'Stone Bicycle Coalition - Inventory';

export default async (request: Request, context: Context) => {
  const expected = Netlify.env.get("SITE_PASSWORD");
  if (!expected) {
    return new Response(
      "Site not configured: SITE_PASSWORD env var missing.",
      { status: 500 }
    );
  }

  const auth = request.headers.get("authorization") ?? "";
  if (auth.startsWith("Basic ")) {
    const decoded = atob(auth.slice(6));
    const colonIdx = decoded.indexOf(":");
    const password = colonIdx >= 0 ? decoded.slice(colonIdx + 1) : "";
    if (password === expected) {
      return context.next();
    }
  }

  return new Response("Authentication required", {
    status: 401,
    headers: {
      "www-authenticate": `Basic realm="${REALM}"`,
      "content-type": "text/plain; charset=utf-8",
    },
  });
};

export const config = { path: "/*" };
