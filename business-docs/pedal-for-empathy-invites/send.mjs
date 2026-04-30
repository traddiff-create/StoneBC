#!/usr/bin/env node
// Pedal for Empathy — Tier 1 personalized invite sender
// Reads recipients.json, renders per-recipient email, sends via Resend.
// Usage:
//   node send.mjs --dry-run          # print all renders, send nothing
//   node send.mjs --only T1-melissa  # render/send only one ID
//   node send.mjs                    # live send for every recipient with send: true
// Requires: RESEND_API_KEY in env. Logs successes to sent-log.json.

import { readFileSync, existsSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RECIPIENTS_PATH = join(__dirname, 'recipients.json');
const LOG_PATH = join(__dirname, 'sent-log.json');
const FROM_EMAIL = 'Stone Bicycle Coalition <info@stonebicyclecoalition.com>';
const SUBJECT = 'Pedal for Empathy — Saturday May 2, 10:30 at Hanson-Larsen';
const RSVP_URL = 'https://mobilize.us/s/JFgFN6';

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const onlyIdx = args.indexOf('--only');
const ONLY_ID = onlyIdx >= 0 ? args[onlyIdx + 1] : null;

function renderHtml({ first_name, personal_line }) {
  const greeting = first_name ? `Hi ${first_name},` : 'Hi there,';
  return [
    `<p>${greeting}</p>`,
    `<p>${escapeHtml(personal_line)}</p>`,
    `<p>Quick rundown in case it helps:</p>`,
    `<ul>`,
    `  <li><strong>What:</strong> Pedal for Empathy — community bike ride + bike-path cleanup</li>`,
    `  <li><strong>When:</strong> Saturday, May 2, 2026 — 10:30 AM</li>`,
    `  <li><strong>Where:</strong> Coffee + donuts at Hanson-Larsen Memorial Park, then ride out</li>`,
    `  <li><strong>Who:</strong> Family-friendly, all levels, free</li>`,
    `  <li><strong>Partners:</strong> City Parks & Rec, Acme Bikes, Minneluzahan Senior Center, Nell's Gourmet</li>`,
    `</ul>`,
    `<p>We were picked out of 600+ applicants nationwide for an American Empathy Project grant to make this happen. Part of the grant goes to Feeding South Dakota.</p>`,
    `<p>RSVP (and please share with anyone you think would love it): <a href="${RSVP_URL}">${RSVP_URL}</a></p>`,
    `<p>Thanks — would mean a lot to see you there.</p>`,
    `<p>Rory<br/>Stone Bicycle Coalition<br/><a href="https://stonebicyclecoalition.com">stonebicyclecoalition.com</a></p>`,
  ].join('\n');
}

function renderText({ first_name, personal_line }) {
  const greeting = first_name ? `Hi ${first_name},` : 'Hi there,';
  return [
    greeting,
    '',
    personal_line,
    '',
    'Quick rundown in case it helps:',
    '',
    '- What: Pedal for Empathy — community bike ride + bike-path cleanup',
    '- When: Saturday, May 2, 2026 — 10:30 AM',
    '- Where: Coffee + donuts at Hanson-Larsen Memorial Park, then ride out',
    '- Who: Family-friendly, all levels, free',
    "- Partners: City Parks & Rec, Acme Bikes, Minneluzahan Senior Center, Nell's Gourmet",
    '',
    'We were picked out of 600+ applicants nationwide for an American Empathy Project grant to make this happen. Part of the grant goes to Feeding South Dakota.',
    '',
    `RSVP (and please share with anyone you think would love it): ${RSVP_URL}`,
    '',
    'Thanks — would mean a lot to see you there.',
    '',
    'Rory',
    'Stone Bicycle Coalition',
    'stonebicyclecoalition.com',
  ].join('\n');
}

function escapeHtml(s = '') {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function loadLog() {
  if (!existsSync(LOG_PATH)) return [];
  try {
    return JSON.parse(readFileSync(LOG_PATH, 'utf8'));
  } catch {
    return [];
  }
}

function appendLog(entry) {
  const log = loadLog();
  log.push(entry);
  writeFileSync(LOG_PATH, JSON.stringify(log, null, 2) + '\n');
}

async function main() {
  const data = JSON.parse(readFileSync(RECIPIENTS_PATH, 'utf8'));
  const recipients = data.recipients || [];

  let queue = recipients.filter(r => r.send === true);
  if (ONLY_ID) queue = queue.filter(r => r.id === ONLY_ID);

  if (queue.length === 0) {
    console.log('No recipients with send: true' + (ONLY_ID ? ` matching --only ${ONLY_ID}` : '') + '. Nothing to do.');
    return;
  }

  console.log(`${DRY_RUN ? '[DRY-RUN] ' : ''}Queue: ${queue.length} recipient(s)`);
  console.log('—'.repeat(60));

  if (DRY_RUN) {
    for (const r of queue) {
      console.log(`\n# ${r.id} → ${r.name} <${r.email || '(no email)'}>`);
      console.log(`Subject: ${SUBJECT}`);
      console.log(`From:    ${FROM_EMAIL}`);
      console.log('');
      console.log(renderText(r));
      console.log('—'.repeat(60));
    }
    console.log('\n[DRY-RUN] No emails sent. Re-run without --dry-run to send.');
    return;
  }

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.error('ERROR: RESEND_API_KEY not set in env. Export it before running:');
    console.error('  export RESEND_API_KEY="re_xxxxx"');
    process.exit(1);
  }
  const { Resend } = await import('resend');
  const resend = new Resend(apiKey);

  for (const r of queue) {
    if (!r.email || !r.email.includes('@')) {
      console.log(`SKIP ${r.id} (${r.name}): missing/invalid email`);
      continue;
    }

    try {
      const result = await resend.emails.send({
        from: FROM_EMAIL,
        to: r.email,
        subject: SUBJECT,
        html: renderHtml(r),
        text: renderText(r),
      });

      if (result.error) {
        console.error(`FAIL ${r.id} (${r.name}): ${result.error.message || JSON.stringify(result.error)}`);
        appendLog({
          id: r.id,
          name: r.name,
          email: r.email,
          sent_at: new Date().toISOString(),
          status: 'failed',
          error: result.error.message || JSON.stringify(result.error),
        });
        continue;
      }

      const sendId = result.data?.id || 'unknown';
      console.log(`SENT ${r.id} (${r.name}) → ${r.email} [resend_id=${sendId}]`);
      appendLog({
        id: r.id,
        name: r.name,
        email: r.email,
        sent_at: new Date().toISOString(),
        status: 'sent',
        resend_id: sendId,
      });
    } catch (err) {
      console.error(`FAIL ${r.id} (${r.name}): ${err.message}`);
      appendLog({
        id: r.id,
        name: r.name,
        email: r.email,
        sent_at: new Date().toISOString(),
        status: 'failed',
        error: err.message,
      });
    }
  }

  console.log('\nDone. See sent-log.json for the per-recipient record.');
}

main().catch(err => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
