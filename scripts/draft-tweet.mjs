#!/usr/bin/env node
// Draft a /community Tweet: line for a PR, using a GitHub token to read the PR
// and the Claude API to write it in the owner's voice (prompt: scripts/pr-tweet-prompt.md).
//
//   GITHUB_TOKEN=ghp_... ANTHROPIC_API_KEY=sk-ant-... \
//     node scripts/draft-tweet.mjs <owner/repo> <pr-number>
//
// Prints the model's five drafts + interrogation, then the final `Tweet:` line.
// It does NOT post anything — you read it, and paste the line into the PR body.
//
// ponytail: raw REST, no SDKs. node 24 fetch + strip-types already in this repo.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pick the LAST `Tweet:` line — the model may show the word mid-reasoning; the contract
// says the winner is the final line. One guard here is the whole correctness story.
const pickTweet = (text) => text.split('\n').reverse().find((l) => /^Tweet:\s*/.test(l.trim()))?.trim();

if (process.argv[2] === '--self-check') {
  const a = (c, m) => { if (!c) { console.error('FAIL ' + m); process.exit(1); } };
  a(pickTweet('draft: Tweet: no\nreasoning\nTweet: yes') === 'Tweet: yes', 'takes last');
  a(pickTweet('  Tweet: spaced ') === 'Tweet: spaced', 'trims indent');
  a(pickTweet('no line here') === undefined, 'none → undefined');
  a(pickTweet('Tweet: SKIP') === 'Tweet: SKIP', 'skip passes through');
  console.log('ok');
  process.exit(0);
}

const [repo, prNumber] = process.argv.slice(2);
const GH = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
const AK = process.env.ANTHROPIC_API_KEY;
const MODEL = process.env.CLAUDE_MODEL || 'claude-opus-4-8';

if (!repo || !prNumber || !/^[^/]+\/[^/]+$/.test(repo)) die('usage: draft-tweet.mjs <owner/repo> <pr-number>');
if (!GH) die('set GITHUB_TOKEN (needs read access to the repo)');
if (!AK) die('set ANTHROPIC_API_KEY');

function die(m) { console.error(m); process.exit(1); }

async function gh(path, accept = 'application/vnd.github+json') {
  const r = await fetch(`https://api.github.com/repos/${repo}/${path}`, {
    headers: { Authorization: `Bearer ${GH}`, Accept: accept, 'User-Agent': 'draft-tweet' },
  });
  if (!r.ok) die(`GitHub ${path}: ${r.status} ${await r.text()}`);
  return accept.includes('json') ? r.json() : r.text();
}

const pr = await gh(`pulls/${prNumber}`);
// .diff accept header returns the raw unified diff. Cap it so a huge PR can't blow the context.
let diff = await gh(`pulls/${prNumber}`, 'application/vnd.github.v3.diff');
const CAP = 60_000;
if (diff.length > CAP) diff = diff.slice(0, CAP) + '\n\n[diff truncated]';

const system = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'pr-tweet-prompt.md'), 'utf8');

const userMsg = [
  `PR #${prNumber}: ${pr.title}`,
  `Labels: ${(pr.labels || []).map((l) => l.name).join(', ') || '(none)'}`,
  '',
  '--- PR body ---',
  pr.body || '(empty)',
  '',
  '--- diff ---',
  diff,
].join('\n');

const res = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: { 'x-api-key': AK, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
  body: JSON.stringify({
    model: MODEL,
    max_tokens: 2000,
    system,
    messages: [{ role: 'user', content: userMsg }],
  }),
});
if (!res.ok) die(`Anthropic: ${res.status} ${await res.text()}`);

const out = (await res.json()).content.map((b) => b.text || '').join('');
console.log(out);

const line = pickTweet(out);
if (line) {
  console.log('\n────────────────────\nPaste into the PR body:\n' + line);
}
