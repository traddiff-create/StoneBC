import { getStore } from "@netlify/blobs";
import bikesSeed from "../../bikes.json";
import waitlistSeed from "../../waitlist.json";
import partsSeed from "../../parts.json";

const STORE_NAME = "inventory";

export type ResourceKey = "bikes" | "waitlist" | "parts";

const SEEDS: Record<ResourceKey, unknown> = {
  bikes: bikesSeed,
  waitlist: waitlistSeed,
  parts: partsSeed,
};

export async function readResource(key: ResourceKey): Promise<unknown> {
  const store = getStore(STORE_NAME);
  const existing = await store.get(key, { type: "json" });
  if (existing) return existing;

  const seed = SEEDS[key];
  await store.setJSON(key, seed);
  return seed;
}

export async function writeResource(
  key: ResourceKey,
  data: unknown
): Promise<void> {
  const store = getStore(STORE_NAME);
  await store.setJSON(key, data);
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

export function errorResponse(message: string, status = 500): Response {
  return jsonResponse({ error: message }, status);
}
