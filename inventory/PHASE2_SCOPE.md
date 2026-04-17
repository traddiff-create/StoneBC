# Inventory Dashboard — Phase 2 Scope

**Goal:** Make the inventory dashboard multi-user, authenticated, and integrated with parts tracking. Caden and Rory see the same data in real time. No more "export JSON and email it."

**Current state (Phase 1, shipped 2026-04-17):**
- Live at https://stonebc-inventory.netlify.app (primary URL `inventory.stonebicyclecoalition.com` pending DNS)
- Basic-auth gate (shared password `QuarryBike2026`)
- Read-only wait list panel fetching `waitlist.json`
- POS form using browser localStorage — per-device, not shared

---

## Phase 2 Deliverables

### 2a. Shared Data Backend (foundation)
- [ ] Migrate `PARTS.md` → `parts.json` (structured parts catalog with id, name, category, sku, stock, cost, supplier, lastUpdated)
- [ ] Keep `PARTS.md` as human-readable mirror generated from `parts.json`
- [ ] Netlify Blobs store for: `bikes.json`, `waitlist.json`, `parts.json`
- [ ] Netlify Functions for CRUD:
  - `GET /api/bikes`, `PUT /api/bikes/:id`, `POST /api/bikes`, `DELETE /api/bikes/:id`
  - `GET /api/waitlist`, `PUT /api/waitlist/:id`, `POST /api/waitlist`
  - `GET /api/parts`, `PUT /api/parts/:id`, `POST /api/parts/:id/consume` (decrements stock when a line item is added to a bike)
- [ ] Repo files remain source-of-truth for initial seed; Blobs becomes live state
- [ ] Seed script: `Scripts/seed_blobs.py` — pushes repo JSON into Blobs (one-time + rerunnable for recovery)
- [ ] Backup script: `Scripts/dump_blobs.py` — pulls Blobs state back into repo JSON (weekly cron or manual)

### 2b. Frontend Migration
- [ ] pos.html: replace localStorage reads/writes with `fetch('/api/...')` calls
- [ ] Loading states + error toasts
- [ ] Optimistic UI with rollback on error
- [ ] Multi-user awareness: show "last edited by Caden · 3 min ago" on each bike

### 2c. Auth Upgrade (Magic-Link)
- [ ] Replace basic-auth edge function with magic-link flow
- [ ] Resend + `info@stonebicyclecoalition.com` as sender (already DNS-verified domain — add Resend verification)
- [ ] Allowlist stored in Blobs: `allowed_users.json` — `[{email, role, name}]` where role ∈ `admin|mechanic|viewer`
- [ ] Login page: email field → receive link → click link → HTTP-only cookie → authenticated session (7-day TTL)
- [ ] Edge function on `/*` checks cookie, redirects to `/login` if missing/expired
- [ ] Role gates: only `admin` can edit the waitlist; `mechanic` can CRUD bikes + parts; `viewer` is read-only

### 2d. Parts Integration (the feature you asked about)
- [ ] Parts autocomplete in the refurb table's "Item" field — dropdown searches `parts.json` by name
- [ ] When a line is added, `POST /api/parts/:id/consume { qty: 1, bikeId: "SBC-XXX" }` decrements stock
- [ ] Per-bike refurb rows store `partId` (not just free text) so reports can aggregate usage
- [ ] Low-stock pill at the top: "3 items low in stock" → click expands a quick-order list
- [ ] Optional: email alert to Rory when any part crosses a reorder threshold
- [ ] Backwards compat: free-text items still accepted (for one-offs that aren't in the catalog)

### 2e. Nice-to-haves (defer if running long)
- [ ] Photo upload per bike (Netlify Blobs for binary, thumbnails via Netlify Image CDN)
- [ ] Parts catalog admin page (`/parts.html`) — separate UI for adding/editing catalog entries
- [ ] Activity feed (`/activity.html`) — chronological log of every edit across bikes/waitlist/parts
- [ ] Export-to-repo button: triggers a backup dump so git history captures a snapshot

---

## Build Order (what I'll ship in what order)

1. **parts.json schema + seed** — (no deploy, repo-only commit)
2. **Netlify Functions for GET on all three resources** — read-only API, deploy, verify auth still gates
3. **Frontend: pos.html fetches /api/waitlist instead of /waitlist.json** — deploy, verify
4. **Netlify Functions for PUT/POST on bikes** — deploy
5. **Frontend: pos.html writes via API** — deploy, verify Caden and Rory see same data from two browsers
6. **Parts autocomplete + consume endpoint** — deploy
7. **Magic-link auth replacing basic auth** — deploy, remove SITE_PASSWORD, add allowlist in Blobs
8. **Cleanup + how-to-use doc update**

Clean checkpoints: after steps 3, 5, 6, 7 — any of these is a safe stop point.

---

## Risks & Decisions Needed

| Risk / Decision | Mitigation / Answer |
|----------------|---------------------|
| Netlify Blobs eventual consistency | Acceptable for this scale (2–5 writers). If race conditions bite, add version field for optimistic concurrency. |
| Cost of Functions invocations | Free tier = 125k requests/mo. We'd hit that with ~4k writes/day. Not a near-term concern. |
| Resend sender domain | Use `info@stonebicyclecoalition.com` after adding the domain to Resend and verifying DKIM/SPF. Fallback: `codes@traddiff.com` (already verified). |
| Data loss if Blobs fails | Nightly `dump_blobs.py` cron to repo + git commit. Means last-24hr window of risk max. |
| Auth migration breaks Caden's access mid-session | Keep basic auth and magic-link both working for 24hr overlap; remove basic auth after Caden confirms magic-link works. |

---

## Out of Scope for Phase 2

- Public-facing bike marketplace (that's the StoneBC iOS app)
- Stripe integration for sponsor payments (Phase 3)
- Multi-coalition tenancy (open-source toolkit concern, not immediate)
- Fine-grained audit log with IP/device (role-level audit is enough)
