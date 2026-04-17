import { getStore } from "@netlify/blobs";

const PHOTOS_STORE = "bike-photos";
const META_STORE = "inventory";
const META_KEY = "bike-photo-index";
const MAX_PHOTOS_PER_BIKE = 5;
const MAX_PHOTO_BYTES = 2 * 1024 * 1024;

type PhotoMeta = {
  id: string;
  bikeId: string;
  ts: string;
  contentType: string;
  size: number;
  caption?: string;
};

type PhotoIndex = Record<string, PhotoMeta[]>;

export default async (req: Request): Promise<Response> => {
  try {
    const url = new URL(req.url);
    // Path pattern (original URL preserved by Netlify): /api/bikes/{bikeId}/photos[/{photoId}]
    // Fallback to query params for direct function testing.
    const pathMatch = /\/api\/bikes\/([^/]+)\/photos(?:\/([^/?]+))?/.exec(url.pathname);
    const bikeId = (pathMatch?.[1] || url.searchParams.get("bikeId") || "").trim();
    const photoId = (pathMatch?.[2] || url.searchParams.get("photoId") || "").trim();

    if (!bikeId) return json({ error: "bikeId required" }, 400);
    if (!/^SBC-[A-Za-z0-9-]+$/.test(bikeId)) {
      return json({ error: "bikeId must match SBC-XXX" }, 400);
    }

    if (req.method === "GET") {
      if (photoId) return serveBinary(bikeId, photoId);
      return listPhotos(bikeId);
    }
    if (req.method === "POST") return addPhoto(req, bikeId);
    if (req.method === "DELETE" && photoId) return deletePhoto(bikeId, photoId);

    return json({ error: "Method not allowed" }, 405);
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
};

async function readIndex(): Promise<PhotoIndex> {
  const store = getStore(META_STORE);
  const data = (await store.get(META_KEY, { type: "json" })) as PhotoIndex | null;
  return data ?? {};
}

async function writeIndex(index: PhotoIndex): Promise<void> {
  const store = getStore(META_STORE);
  await store.setJSON(META_KEY, index);
}

async function listPhotos(bikeId: string): Promise<Response> {
  const index = await readIndex();
  const list = index[bikeId] ?? [];
  return json({ bikeId, photos: list });
}

async function serveBinary(bikeId: string, photoId: string): Promise<Response> {
  const index = await readIndex();
  const meta = (index[bikeId] ?? []).find((p) => p.id === photoId);
  if (!meta) return json({ error: "Photo not found" }, 404);

  const photoStore = getStore(PHOTOS_STORE);
  const key = `${bikeId}/${photoId}`;
  const arrayBuffer = await photoStore.get(key, { type: "arrayBuffer" });
  if (!arrayBuffer) return json({ error: "Photo blob missing" }, 404);

  return new Response(arrayBuffer, {
    status: 200,
    headers: {
      "content-type": meta.contentType,
      "cache-control": "private, max-age=3600",
    },
  });
}

async function addPhoto(req: Request, bikeId: string): Promise<Response> {
  let body: { dataUrl?: string; caption?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const dataUrl = body.dataUrl || "";
  const m = /^data:(image\/(?:jpeg|png|webp|heic|heif));base64,(.+)$/i.exec(dataUrl);
  if (!m) {
    return json({ error: "dataUrl must be a base64 image (jpeg/png/webp/heic)" }, 400);
  }

  const contentType = m[1].toLowerCase();
  const bytes = Uint8Array.from(atob(m[2]), (c) => c.charCodeAt(0));
  if (bytes.byteLength > MAX_PHOTO_BYTES) {
    return json(
      { error: `Photo too large: ${bytes.byteLength} bytes (max ${MAX_PHOTO_BYTES})` },
      413
    );
  }

  const index = await readIndex();
  const existing = index[bikeId] ?? [];
  if (existing.length >= MAX_PHOTOS_PER_BIKE) {
    return json(
      { error: `Max ${MAX_PHOTOS_PER_BIKE} photos per bike. Delete one before adding another.` },
      409
    );
  }

  const ts = new Date();
  const photoId =
    `${ts.toISOString().replace(/[-:T.Z]/g, "").slice(0, 14)}-` +
    Math.random().toString(36).slice(2, 8);

  const meta: PhotoMeta = {
    id: photoId,
    bikeId,
    ts: ts.toISOString(),
    contentType,
    size: bytes.byteLength,
    caption: (body.caption || "").slice(0, 200),
  };

  const photoStore = getStore(PHOTOS_STORE);
  await photoStore.set(`${bikeId}/${photoId}`, bytes, {
    metadata: { bikeId, contentType },
  });

  index[bikeId] = [...existing, meta];
  await writeIndex(index);

  return json({ ok: true, photo: meta });
}

async function deletePhoto(bikeId: string, photoId: string): Promise<Response> {
  const index = await readIndex();
  const list = index[bikeId] ?? [];
  const filtered = list.filter((p) => p.id !== photoId);
  if (filtered.length === list.length) {
    return json({ error: "Photo not found" }, 404);
  }

  const photoStore = getStore(PHOTOS_STORE);
  await photoStore.delete(`${bikeId}/${photoId}`);

  index[bikeId] = filtered;
  await writeIndex(index);
  return json({ ok: true });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}
