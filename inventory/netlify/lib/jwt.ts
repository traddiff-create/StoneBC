/**
 * Minimal HS256 JWT helpers using WebCrypto.
 * Works in both Netlify Functions (Node) and Edge Functions (Deno).
 */

function b64urlEncode(input: string | Uint8Array): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/") +
    "===".slice(0, (4 - (input.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function hmacKey(secret: string, usage: "sign" | "verify"): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    [usage]
  );
}

export async function signJWT(
  payload: Record<string, unknown>,
  secret: string,
  ttlSeconds = 60 * 60 * 24 * 7 // 7 days default
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = { ...payload, iat: now, exp: now + ttlSeconds };
  const header = { alg: "HS256", typ: "JWT" };
  const headerB64 = b64urlEncode(JSON.stringify(header));
  const payloadB64 = b64urlEncode(JSON.stringify(fullPayload));
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const key = await hmacKey(secret, "sign");
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, data));
  return `${headerB64}.${payloadB64}.${b64urlEncode(sig)}`;
}

export async function verifyJWT(
  token: string,
  secret: string
): Promise<Record<string, unknown> | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sig = b64urlDecode(sigB64);
  const key = await hmacKey(secret, "verify");
  const valid = await crypto.subtle.verify("HMAC", key, sig, data);
  if (!valid) return null;
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(new TextDecoder().decode(b64urlDecode(payloadB64)));
  } catch {
    return null;
  }
  const exp = payload.exp as number | undefined;
  if (exp && Math.floor(Date.now() / 1000) > exp) return null;
  return payload;
}

export function randomToken(bytes = 24): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return b64urlEncode(buf);
}

export function parseCookies(cookieHeader: string | null): Record<string, string> {
  if (!cookieHeader) return {};
  const out: Record<string, string> = {};
  for (const pair of cookieHeader.split(";")) {
    const i = pair.indexOf("=");
    if (i < 0) continue;
    const k = pair.slice(0, i).trim();
    const v = pair.slice(i + 1).trim();
    if (k) out[k] = decodeURIComponent(v);
  }
  return out;
}

export function isEmailAllowed(email: string, allowList: string): boolean {
  const target = email.trim().toLowerCase();
  if (!target) return false;
  return allowList
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean)
    .includes(target);
}
