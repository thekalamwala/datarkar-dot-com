# PR → /community auto-poster: complete build guide

One file, everything. Rebuild the whole "every merged PR posts a tweet to my
community feed, written in my voice by Claude" pipeline in any codebase.

Two kinds of thing live here:
- **REAL** — lifted from the running system (DB schema, owner resolver, milestone
  trigger, CI check, the voice doc). Copy as-is.
- **REFERENCE IMPL** — the webhook handler, `shouldAnnounce`, `extractTweet`,
  template pool. These run in production but the source wasn't in the checkout I
  read; I reconstructed them from their documented contracts. Correct by contract,
  but diff against your own once wired.

---

## 0. The shape of it

```
 PR opened/edited ──► GitHub Action: "require a Tweet: line"  (blocks merge if missing)
                                   │
 PR merged ──► GitHub webhook (pull_request closed+merged)
                                   │
                         your /api/github/webhook
                                   │
              verify HMAC sig ─► shouldAnnounce(pr)? ─no─► 200, done
                                   │ yes
                         extractTweet(pr.body)
                            │                  │
                       found line         no line
                            │                  │
                         use it      pickTemplate(pr)  (fallback pool)
                            │                  │
                            └──────┬───────────┘
                                   ▼
             INSERT community_posts (owner_id, 'text', body, auto_key='pr:{repo}#{n}')
                                   │  ON CONFLICT (auto_key) DO NOTHING   ← idempotent
                                   ▼
                          appears on /community under the owner's name
```

Writing the line itself (the hard part) is a **separate, offline** step: a Claude-API
helper reads the PR diff and drafts the `Tweet:` line for you to paste into the PR
body before merge. The webhook never calls Claude — it only reads what's already in
the body. See §7.

Key decisions worth copying:
- **Idempotency via a DB unique index on `auto_key`**, not app-level dedupe. A retried
  webhook, a re-merge, a backfill — all collapse to one row. `auto_key = 'pr:{owner/repo}#{number}'`.
- **The webhook writes with the service-role key** (bypasses RLS) but **fences every
  write to `community_owner_id()`** so it can only ever post as the owner.
- **The voice line lives in the PR body**, human-reviewed, not generated at merge time.
  Merge-time generation = unreviewed copy under your name. Don't.

---

## 1. Data model (REAL — `community_posts` + friends)

Postgres / Supabase. Only the columns the poster needs are load-bearing; the rest is
the wider community feature. `auto_key` is the one you must add.

```sql
create table if not exists public.community_posts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  parent_id      uuid references public.community_posts(id) on delete cascade,
  reblog_of      uuid references public.community_posts(id) on delete cascade,
  type           text not null check (type in ('text','image','poll','youtube')),
  body           text check (body is null or char_length(body) <= 500),
  images         jsonb,
  youtube_id     text,
  poll           jsonb,
  up_count       int not null default 0,
  down_count     int not null default 0,
  reply_count    int not null default 0,
  reblog_count   int not null default 0,
  hidden         boolean not null default false,
  hidden_reason  text,
  hidden_notified boolean not null default false,
  demoted        boolean not null default false,
  created_at     timestamptz not null default now()
);

-- Idempotency key. Nullable + partial-unique: manual posts leave it null (Postgres
-- allows many nulls), auto-posts set a stable key so retries can't double-post.
alter table public.community_posts add column if not exists auto_key text;
create unique index if not exists community_posts_auto_key_key
  on public.community_posts (auto_key) where auto_key is not null;

create index if not exists community_posts_feed_idx
  on public.community_posts (created_at desc)
  where parent_id is null and reblog_of is null;
```

An auto-post is the minimal insert: `user_id`, `type='text'`, `body`, `auto_key`.
Everything else defaults.

`auto_key` namespaces (REAL, from the live data):
- `pr:{owner/repo}#{number}` — a PR post, e.g. `pr:bookasloth/shubham-datarkar#213`.
  (Older posts used a bare `pr:{number}`; the repo-qualified form is current because
  the feed spans multiple repos.)
- `member-milestone:{n}` — a community-size milestone (§3).
- `genesis` — the one hand-placed first post.

---

## 2. The owner resolver (REAL)

Single source of truth for "who is the owner." `security definer` so it can read
`auth.users` from a trigger and from the service-role client. Swap the email literal.

```sql
create or replace function public.community_owner_id()
returns uuid language sql stable security definer set search_path = public as $$
  select p.id
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(u.email) = 'owner@example.com'   -- ← your owner's email
  limit 1;
$$;
grant execute on function public.community_owner_id() to anon, authenticated, service_role;
```

Every auto-post inserts `user_id = public.community_owner_id()`. The webhook can't
post as anyone else even if the service-role key leaks into that code path.

---

## 3. Milestone trigger (REAL — optional, the "no app hook" case)

Not PR-related, but the same pattern and worth stealing: some events (a new signup)
only exist at the DB level, so the auto-post must also live in the DB. Fires once per
threshold via `auto_key`. Note the swallow-all-errors block — an auto-post must never
abort the signup transaction it rides inside.

```sql
create or replace function public.community_size_milestone()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n int; owner_id uuid;
  msgs text[] := array[
    'The community just crossed {n} members. Glad you''re all here.',
    'We just hit {n} members. Thanks for being part of this.'
    -- ...more variants so repeat milestones don't read identically
  ];
  body text;
begin
  select count(*) into n from public.profiles;
  if n not in (10, 25, 50, 100, 250, 500, 1000) then return null; end if;
  owner_id := public.community_owner_id();
  if owner_id is null then return null; end if;
  body := replace(msgs[1 + floor(random() * array_length(msgs,1))::int], '{n}', n::text);
  begin
    insert into public.community_posts (user_id, type, body, auto_key)
    values (owner_id, 'text', body, 'member-milestone:' || n)
    on conflict do nothing;
  exception when others then null;   -- never break a signup over a tweet
  end;
  return null;
end $$;

drop trigger if exists community_size_milestone_trg on public.profiles;
create trigger community_size_milestone_trg
  after insert on public.profiles
  for each row execute function public.community_size_milestone();
```

Known ceiling (kept on purpose): the `count(*)` check can miss a threshold under
concurrent signups (READ COMMITTED). Upgrade to a locked counter/sequence only if
signup volume ever makes that real.

---

## 4. The webhook handler (REFERENCE IMPL)

Next.js route handler. Receives GitHub's `pull_request` event, verifies the HMAC
signature, and on a real merge inserts one post. Framework-agnostic in spirit — the
three jobs are: **verify, decide, insert idempotently.**

```ts
// src/app/api/github/webhook/route.ts
import { createHmac, timingSafeEqual } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';            // needs node:crypto + raw body

const SECRET = process.env.GITHUB_WEBHOOK_SECRET!;   // the webhook's shared secret
const admin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,            // bypasses RLS — writes as owner only
  { auth: { persistSession: false } },
);

function verify(raw: string, sigHeader: string | null): boolean {
  if (!sigHeader) return false;
  const mac = 'sha256=' + createHmac('sha256', SECRET).update(raw).digest('hex');
  const a = Buffer.from(mac), b = Buffer.from(sigHeader);
  return a.length === b.length && timingSafeEqual(a, b);   // constant-time
}

export async function POST(req: Request) {
  const raw = await req.text();                            // raw body, pre-parse, for the HMAC
  if (!verify(raw, req.headers.get('x-hub-signature-256')))
    return new Response('bad signature', { status: 401 });
  if (req.headers.get('x-github-event') !== 'pull_request')
    return new Response('ignored', { status: 200 });

  const { action, pull_request: pr, repository: repo } = JSON.parse(raw);
  // Only a real merge. action 'closed' + merged===true. A closed-without-merge is a no-op.
  if (action !== 'closed' || !pr?.merged) return new Response('not a merge', { status: 200 });

  if (!shouldAnnounce(pr)) return new Response('silent by rule', { status: 200 });

  const body = extractTweet(pr.body) ?? pickTemplate(pr, repo.name);
  if (!body) return new Response('nothing to say', { status: 200 });

  const owner = await admin.rpc('community_owner_id');
  const ownerId = owner.data as string | null;
  if (!ownerId) return new Response('no owner', { status: 200 });

  const { error } = await admin.from('community_posts').insert({
    user_id: ownerId,
    type: 'text',
    body,
    auto_key: `pr:${repo.full_name}#${pr.number}`,       // e.g. pr:owner/repo#213
  });
  // Unique-index violation on auto_key = a duplicate delivery. That's success, not failure.
  if (error && !/duplicate key|unique/i.test(error.message)) {
    console.error('community auto-post failed', error);
    return new Response('insert failed', { status: 500 });
  }
  return new Response('posted', { status: 200 });
}
```

Register the webhook on the repo (Settings → Webhooks, or `gh api`): payload URL =
your route, content type `application/json`, secret = `GITHUB_WEBHOOK_SECRET`, events
= "Pull requests" only. Both repos in a multi-repo feed point at the same URL; the
`repo.full_name` in the payload keeps their `auto_key`s distinct.

---

## 5. `shouldAnnounce` (REFERENCE IMPL)

Decides *whether* a PR posts at all. From the documented rule: announce
`feat/fix/perf/chore` with a non-noise scope and no `no-announce` label.

```ts
// A PR announces when its conventional-commit type is interesting, its scope isn't
// noise, and nobody slapped the no-announce label on it.
const ANNOUNCE_TYPES = new Set(['feat', 'fix', 'perf', 'chore']);
const NOISE_SCOPES   = new Set(['deps', 'ci', 'release', 'typo', 'lint', 'format']);

export function shouldAnnounce(pr: { title: string; labels?: { name: string }[] }): boolean {
  if ((pr.labels ?? []).some((l) => l.name === 'no-announce')) return false;
  // "feat(scope): subject" / "fix: subject"
  const m = /^(\w+)(?:\(([^)]+)\))?!?:/.exec(pr.title.trim());
  if (!m) return false;
  const [, type, scope] = m;
  if (!ANNOUNCE_TYPES.has(type.toLowerCase())) return false;
  if (scope && NOISE_SCOPES.has(scope.toLowerCase())) return false;
  return true;
}
```

Tune the sets to your conventions. The `no-announce` label is the manual escape hatch —
it also clears the CI check in §8 without needing a `Tweet:` line.

---

## 6. `extractTweet` + `humanizeSubject` (REFERENCE IMPL)

Pull the one `Tweet:` line out of the PR body, verbatim, untouched. The one guard that
matters: take the **last** such line (the author may show the word while reasoning in
the body; the contract says the winner is the final line). `SKIP` means "I decided this
one stays silent" → treat as no line and let `shouldAnnounce` have already gated it, or
return null to fall through to the pool — pick one policy and keep it.

```ts
// The Tweet: line is NEVER sanitized — it posts exactly as written (handles linkify
// and email, so a real @handle notifies a real person; that's intended, see the voice doc).
export function extractTweet(body: string | null): string | null {
  if (!body) return null;
  const lines = body.split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {         // last line wins
    const m = /^\s*Tweet:\s*(.+)$/.exec(lines[i]);
    if (m) {
      const copy = m[1].trim();
      if (!copy || copy === 'SKIP') return null;        // explicit "don't post"
      return copy.slice(0, 500);                        // house cap
    }
  }
  return null;
}

// Only the FALLBACK path is sanitized — a raw PR title becomes safe tweet copy.
// Strip the conventional-commit prefix, drop bare @handles so the template pool can't
// accidentally notify someone, collapse whitespace.
export function humanizeSubject(title: string): string {
  return title
    .replace(/^\w+(\([^)]+\))?!?:\s*/, '')   // "feat(games): " → ""
    .replace(/(^|\s)@[\w-]+/g, '$1')         // kill @handles on the auto path
    .replace(/\s+/g, ' ')
    .trim();
}
```

---

## 7. The fallback template pool (REFERENCE IMPL)

Fires only when the PR has **no** `Tweet:` line. It is a safety net, never a target —
the whole point of the voice doc (§9) is that you write the line so this doesn't run.
Keep the pool deliberately generic and slightly self-aware, so a fallback reads as "a
quiet update" rather than faking a punchline it didn't earn.

```ts
// Deterministic pick by PR number so re-delivery of the same PR yields the same line
// (belt-and-suspenders behind the auto_key unique index).
const POOL = [
  (s: string) => `Shipped: ${s}.`,
  (s: string) => `${s}. Small one, but it's in.`,
  (s: string) => `Pushed a change — ${s}.`,
  (s: string) => `${s}. Done.`,
];

export function pickTemplate(
  pr: { number: number; title: string },
  _repo: string,
): string {
  const subject = humanizeSubject(pr.title);
  if (!subject) return '';
  return POOL[pr.number % POOL.length](subject).slice(0, 500);
}
```

Real-world note from the system this came from: #221/#222 both merged with no `Tweet:`
line 20 minutes apart and the pool posted the *same* sentence twice to the public feed.
That incident is exactly why §8 exists — the pool stays (a PR can genuinely have nothing
to say) but *needing* it is treated as the bug, and the bug fails in CI instead of on
the timeline.

---

## 8. CI guard: require a `Tweet:` line (REAL contract, REFERENCE script)

A GitHub Action that fails an announce-worthy PR which has no `Tweet:` line and no
`no-announce` label — so the fallback pool only ever runs on PRs you *chose* to leave
to it. Fires on edit/label too, so adding the line (or the label) clears the check
without a new commit.

```yaml
# .github/workflows/pr-tweet.yml
name: PR tweet
on:
  pull_request:
    types: [opened, edited, reopened, synchronize, labeled, unlabeled]
permissions:
  contents: read
jobs:
  tweet-line:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24 }
      - name: "Require a Tweet: line on announce-worthy PRs"
        run: node --experimental-strip-types scripts/check-pr-tweet.mts
        env:
          # Passed as env, NEVER interpolated into the shell — PR titles/bodies are
          # attacker-controlled text. (An unquoted colon in the step name would also
          # turn this YAML into a mapping and silently break the workflow.)
          PR_TITLE:  ${{ github.event.pull_request.title }}
          PR_BODY:   ${{ github.event.pull_request.body }}
          PR_LABELS: ${{ toJSON(github.event.pull_request.labels.*.name) }}
```

```ts
// scripts/check-pr-tweet.mts  — no imports, runs under node --experimental-strip-types
// Reuse the same shouldAnnounce/extractTweet logic as the webhook (inline here to keep
// the check dependency-free, or import if your build allows).
const title  = process.env.PR_TITLE  ?? '';
const body   = process.env.PR_BODY   ?? '';
const labels: string[] = JSON.parse(process.env.PR_LABELS ?? '[]');

const ANNOUNCE = new Set(['feat', 'fix', 'perf', 'chore']);
const NOISE    = new Set(['deps', 'ci', 'release', 'typo', 'lint', 'format']);

function announces(): boolean {
  if (labels.includes('no-announce')) return false;
  const m = /^(\w+)(?:\(([^)]+)\))?!?:/.exec(title.trim());
  if (!m) return false;
  if (!ANNOUNCE.has(m[1].toLowerCase())) return false;
  if (m[2] && NOISE.has(m[2].toLowerCase())) return false;
  return true;
}
function hasTweet(): boolean {
  return body.split(/\r?\n/).some((l) => /^\s*Tweet:\s*\S/.test(l));
}

if (announces() && !hasTweet()) {
  console.error(
    'This PR will auto-post to /community but has no `Tweet:` line.\n' +
    'Add one to the PR body (see the voice doc), or add the `no-announce` label.',
  );
  process.exit(1);
}
console.log('ok');
```

---

## 9. The voice — how the line is written (REAL)

This is the actual product. The pipeline is plumbing; the line is the thing. Full doc:
keep it as `docs/PR-TWEET.md` and `scripts/pr-tweet-prompt.md` (the Claude system
prompt). Condensed essence:

- **Who's posting:** solo founder, no marketing team, posting at 2am. Raw, funny, mean
  about the right targets, never proud of itself. The reader sees a person — never a
  bot, webhook, or "auto-posted."
- **Read the PR, not the title.** Write about what a non-developer could notice, who it
  helps, the bug that bit someone, what's funny about it. If nothing is interesting,
  that's a real answer — say so and let the pool take it.
- **Voice bands** (what works, not a menu): self-roast (on you and the code, never the
  user), gaslight (about memory of a UI, never a false fact), ragebait (aimed up — bloat,
  agencies, industry; never users, never a named person), life-choices, dig/flex, absurd/dry.
  Best line hits two at once.
- **Word craft:** specific nouns beat adjectives (name the 400ms, the cookie banner),
  funniest word last, cut every word that survives its own deletion, no throat-clearing.
- **Dead on arrival:** the pool's own spent lines, internet stock cuts ("rent free",
  "built different", "just shipped"), generic dev punchlines ("took longer than I'll
  admit"). Read it before → no voltage left.
- **Say which project, softly:** the noun doing comedic work IS the context. A cold
  reader must know which product this is about.
- **Process:** write FIVE drafts (different angles), interrogate each, ship the one that
  hits multiple bands AND is legible cold, discard the other four. Quality over shipping
  now — a mediocre tweet posts under your name forever.
- **Hard limits (the only real rules):** never lie about what shipped; punch up never at
  users; no `@handle` unless you mean to notify that real person (the line isn't
  sanitized); security/privacy PRs get the boring voice — "Fixed. Moving on."

### The Claude-API drafting helper (REAL — ships in this repo)

Offline, pre-merge. Reads the PR via a GitHub token, drafts the line via the Claude API
using the voice prompt, prints it for you to paste. **Does not post** and the webhook
**does not call Claude** — the line is human-reviewed in the PR body. Raw REST, no SDKs,
Node 24 `fetch`.

```bash
GITHUB_TOKEN=ghp_... ANTHROPIC_API_KEY=sk-ant-... \
  node scripts/draft-tweet.mjs <owner/repo> <pr-number>
```

```js
#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const [repo, prNumber] = process.argv.slice(2);
const GH = process.env.GITHUB_TOKEN, AK = process.env.ANTHROPIC_API_KEY;
const MODEL = process.env.CLAUDE_MODEL || 'claude-opus-4-8';
const die = (m) => { console.error(m); process.exit(1); };
if (!repo || !prNumber) die('usage: draft-tweet.mjs <owner/repo> <pr-number>');
if (!GH || !AK) die('set GITHUB_TOKEN and ANTHROPIC_API_KEY');

async function gh(path, accept = 'application/vnd.github+json') {
  const r = await fetch(`https://api.github.com/repos/${repo}/${path}`, {
    headers: { Authorization: `Bearer ${GH}`, Accept: accept, 'User-Agent': 'draft-tweet' },
  });
  if (!r.ok) die(`GitHub ${path}: ${r.status} ${await r.text()}`);
  return accept.includes('json') ? r.json() : r.text();
}

const pr = await gh(`pulls/${prNumber}`);
let diff = await gh(`pulls/${prNumber}`, 'application/vnd.github.v3.diff');
if (diff.length > 60_000) diff = diff.slice(0, 60_000) + '\n\n[diff truncated]';

const system = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), 'pr-tweet-prompt.md'), 'utf8');

const res = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: { 'x-api-key': AK, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
  body: JSON.stringify({ model: MODEL, max_tokens: 2000, system, messages: [{ role: 'user', content:
    `PR #${prNumber}: ${pr.title}\nLabels: ${(pr.labels||[]).map(l=>l.name).join(', ')||'(none)'}\n\n`
    + `--- PR body ---\n${pr.body||'(empty)'}\n\n--- diff ---\n${diff}` }] }),
});
if (!res.ok) die(`Anthropic: ${res.status} ${await res.text()}`);
const out = (await res.json()).content.map((b) => b.text || '').join('');
console.log(out);
const line = out.split('\n').reverse().find((l) => /^Tweet:\s*/.test(l.trim()));
if (line) console.log('\n────────\nPaste into the PR body:\n' + line.trim());
```

The system prompt (`scripts/pr-tweet-prompt.md`) is the condensed voice doc above plus
one output contract: *write five drafts, interrogate, end the reply with the winner on
its own final line as `Tweet: <copy>` (≤500 chars, no emojis), or `Tweet: SKIP`.*

---

## 10. Secrets & env

| Name | Where | What |
|---|---|---|
| `GITHUB_WEBHOOK_SECRET` | webhook host | HMAC shared secret, set on the repo webhook |
| `SUPABASE_URL` | webhook host | project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | webhook host | **server-only**, never ships to the client; bypasses RLS |
| `GITHUB_TOKEN` | your machine | read access to the repo, for the drafting helper |
| `ANTHROPIC_API_KEY` | your machine | for the drafting helper |
| `CLAUDE_MODEL` | optional | model override (default `claude-opus-4-8`) |

The service-role key is the only scary one. It's confined to the webhook route
(`runtime = 'nodejs'`), and the owner-fencing (§2) means even a bug there can only post
as the owner, not read or write other members' data.

---

## 11. Build checklist

1. **DB**: add `community_posts` (§1), the `auto_key` unique index, `community_owner_id()`
   (§2). Point the email literal at your owner. Optional: milestone trigger (§3).
2. **Webhook**: deploy the route (§4) with the three env vars. Register the repo webhook
   (Pull requests event, your secret). Verify a test delivery returns 200.
3. **Rules**: tune `shouldAnnounce` + `NOISE_SCOPES` to your conventions (§5), and the
   matching logic in the CI check (§8).
4. **Fallback**: write your own `POOL` (§7) in your voice. Keep it boring on purpose.
5. **CI guard**: add the Action + `check-pr-tweet.mts` (§8). Now an announce-worthy PR
   can't merge without a line or the `no-announce` label.
6. **Voice**: drop in `docs/PR-TWEET.md` + `scripts/pr-tweet-prompt.md`, and the
   `draft-tweet.mjs` helper (§9). This is where the actual quality comes from.
7. **Smoke test**: open a `feat:` PR with a `Tweet:` line, merge it, confirm one row in
   `community_posts` with `auto_key = pr:owner/repo#N`. Re-send the webhook delivery;
   confirm **no** second row. That last step is the whole idempotency story.

The pipeline is a weekend. The voice is forever — that's the part worth the care.
```
