# Pedal for Empathy — Tier 1 Invite Kit

Last-mile push for the May 2 event. Three channels, one folder.

## Files

| File | Purpose |
|------|---------|
| `recipients.json` | Email contact list (you fill emails, flip `send: true` when ready) |
| `email-template.md` | Master copy + personalization rules — human-readable |
| `send.mjs` | Node script that renders + sends via Resend |
| `package.json` | Just the `resend` dep |
| `text-scripts.md` | Copy-paste blocks for SMS contacts |
| `dropby-checklist.md` | In-person walk-in stops |
| `sent-log.json` | Auto-generated record of sent emails (gitignored) |

## Send Workflow

### 1. Install once

```bash
cd /Applications/Apps/StoneBC/business-docs/pedal-for-empathy-invites
npm install
```

### 2. Set Resend key

Pull your existing key from Netlify (or `~/.private_keys/`) and export it:

```bash
export RESEND_API_KEY="re_xxxxxxxx"
```

### 3. Edit `recipients.json`

- Fill in `email` for each contact you want to reach by email.
- Flip `send: true` only on the ones ready to go.
- Tweak `personal_line` if you want different wording.

### 4. Dry-run

```bash
node send.mjs --dry-run
```

Prints every queued render to stdout. **No emails sent.** Read every body before continuing.

### 5. Test send to yourself

Set one entry to your own email + `send: true`, then:

```bash
node send.mjs --only T1-melissa-petersen   # or whichever ID you redirected
```

Check inbox. Verify subject, formatting, mobile rendering.

### 6. Live send

Flip the rest to `send: true` and run:

```bash
node send.mjs
```

Each successful send appends to `sent-log.json` with the Resend message ID.

### 7. Update the master tracker

After sends complete, update the **Status** column in `../pedal-for-empathy-invite-list.md` with the date sent. Source of truth lives there, not here.

## Other channels

- **SMS:** `text-scripts.md` — copy block, paste in Messages, tick the box.
- **In-person:** `dropby-checklist.md` — walk Thursday or Friday.

## Gotchas

- `info@stonebicyclecoalition.com` is the verified sender. Same domain `stonebicyclecoalition.com` already used by `submit-route.mjs` (`routes@`) and `magic-link.mjs` — Resend domain auth is set up.
- `sent-log.json` is gitignored — keep it that way (contains email addresses).
- Don't blast the Dharma CE attendees as a single batch with shared "to:" — recipients.json should have **one entry per attendee** so each one gets a personalized "Hi {{first_name}}". The script sends individually.
- Ignite RC contacts — replace the placeholder entry with one row per Ignite person you actually want to reach.
