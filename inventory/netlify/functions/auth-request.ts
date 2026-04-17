import { getStore } from "@netlify/blobs";
import { randomToken, isEmailAllowed } from "../lib/jwt";

const TOKEN_TTL_MIN = 15;
const SITE_NAME = "Stone Bicycle Coalition - Inventory";

export default async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  let body: { email?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const email = (body.email || "").trim().toLowerCase();
  if (!email || !email.includes("@")) {
    return json({ error: "Valid email required" }, 400);
  }

  const allowList = process.env.ALLOWED_EMAILS || "";
  if (!isEmailAllowed(email, allowList)) {
    // Don't leak whether an email is allowlisted — same response either way.
    // Logged internally for debugging.
    console.log(`[auth-request] denied: ${email} not in allowlist`);
    return json({ ok: true, message: "If that email is authorized, a link has been sent." });
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return json({ error: "Email sending not configured (RESEND_API_KEY missing)" }, 500);
  }

  const token = randomToken(24);
  const expiresAt = Date.now() + TOKEN_TTL_MIN * 60 * 1000;

  const store = getStore("auth");
  await store.setJSON(`token:${token}`, { email, expiresAt, used: false });

  const origin = new URL(req.url).origin;
  const verifyUrl = `${origin}/api/auth/verify?token=${encodeURIComponent(token)}`;

  const emailRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${resendKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from: "Stone Bicycle Coalition <noreply@traddiff.com>",
      reply_to: "info@stonebicyclecoalition.com",
      to: [email],
      subject: `Sign in to ${SITE_NAME}`,
      text:
        `Click this link to sign in:\n\n${verifyUrl}\n\n` +
        `Link expires in ${TOKEN_TTL_MIN} minutes. If you did not request this, ignore this email.\n\n` +
        `— Stone Bicycle Coalition`,
      html:
        `<p>Click this link to sign in:</p>` +
        `<p><a href="${verifyUrl}" style="display:inline-block;padding:12px 24px;background:#059669;color:#fff;text-decoration:none;border-radius:6px;font-weight:600">Sign in</a></p>` +
        `<p style="color:#666;font-size:0.9em">Or paste this URL into your browser:<br>${verifyUrl}</p>` +
        `<p style="color:#888;font-size:0.85em">Link expires in ${TOKEN_TTL_MIN} minutes. If you did not request this, ignore this email.</p>` +
        `<p style="color:#888;font-size:0.85em">— Stone Bicycle Coalition</p>`,
    }),
  });

  if (!emailRes.ok) {
    const err = await emailRes.text();
    console.error(`[auth-request] Resend failed for ${email}: ${emailRes.status} ${err}`);
    return json({ error: "Email send failed. Try again in a minute." }, 502);
  }

  return json({ ok: true, message: "Check your email for a sign-in link." });
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}
