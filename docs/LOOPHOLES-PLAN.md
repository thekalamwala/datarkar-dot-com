# Loopholes — Audit & Fix Plan

_Read-only security/abuse audit, 2026-08-06. Four parallel reviewers over API routes, Supabase RLS/migrations, games + community abuse, and admin/auth/server-actions. No code changed._

**Overall:** the site is well-hardened. Webhooks (GitHub, Razorpay) are HMAC-verified and fail-closed; cron routes require `CRON_SECRET`; every admin Server Action re-calls `requireAdmin()` (not just the page); no `getSession()` footgun; open-redirect closed via `safeNext()`; payment amounts recomputed server-side. The findings below are the genuine gaps, ranked.

---

## P0 — Games leaderboard/streak forgery (HIGH, confirmed x2)

**Where:** `supabase/migrations/20260705000001_games_init.sql:182` (grant), `20260717000001_games_streak_idempotent.sql:24` (`submit_result`), `20260716000001_games_archive_results.sql:35` (`submit_archive_result`).

**Loophole:** both submit RPCs are `security definer`, granted `EXECUTE to authenticated`, and PostgREST-exposed. They **trust client-supplied `p_status`, `p_guesses`, `p_guess_data`** (and `p_time_ms` on archive) and never re-derive whether the guesses actually solve the puzzle. The only answer validation (`validate-result.ts` / `validateResult`) runs in the Next.js server action — which a direct REST call skips entirely.

**Exploit:** any logged-in user, with their own JWT:
```
POST /rest/v1/rpc/submit_result
{ p_game, p_puzzle: <today>, p_status: 'won', p_guesses: 1, p_guess_data: [...] }
```
→ forged guess-1 win, tops the daily board (ranked by fewest guesses), builds an unbroken streak. Archive variant forges `p_time_ms: 1` across the whole back catalogue → all-time "fastest" + solved-count boards. The earlier migration closed the direct-*table-insert* hole but left the *RPC* (the real write path) unvalidated. The app-layer anti-cheat is decorative.

**Fix (lazy = root cause):** make validation unskippable by moving the write behind the trusted boundary.
- Revoke `EXECUTE ... FROM authenticated` (and `public`) on both RPCs; grant to `service_role` only.
- Have the Next server action call them via `supabaseAdmin()` (`src/lib/supabase/server.ts`) **after** `validateResult` passes and **after** the server computes `time_ms` and `guesses` itself (never pass client-declared status/time).
- Keep the existing `where status='in_progress'` idempotency guard.
- Migration is SQL-only (grant flip) + one server-action edit; hand SQL to user per the manual-migration workflow.

_Alt if you want defense-in-depth: re-derive the answer inside the RPC. Rejected as lazy-wrong — it means porting `secretFor`/word-of-day generation into PL/pgSQL. The grant-flip closes it with a fraction of the code._

---

## P1 — Public LLM endpoints, no auth + no rate limit (MEDIUM, confirmed x3)

**Where:** `src/app/api/tools/analyze/route.ts:9`, `src/app/api/tools/content-brief/route.ts:7`, `src/app/api/tools/seo-audit/route.ts:9`.

**Loophole:** all three are unauthenticated and unthrottled. `analyze` and `content-brief` fire a Claude call per request on your `ANTHROPIC_API_KEY`. Per-call cost is capped (input truncation, `max_tokens`), request volume is not.

**Exploit:** scripted loop → bill inflation / provider-quota exhaustion (financial DoS). `seo-audit` is a free server-fetch amplifier (bandwidth/cost).

**Fix (one line each):** add the existing `allow()` IP rate-limiter — `src/lib/rate-limit.ts`, already used in `subscribers/actions.ts` and `support/order`. Mirror that pattern at the top of each handler (e.g. 5/60s per IP). No new dependency, no auth wall needed (tools are meant to be public-facing).

---

## P2 — SSRF via DNS-rebinding TOCTOU (MEDIUM)

**Where:** `src/app/api/tools/seo-audit/route.ts` → `src/lib/tools/safe-fetch.ts:83-123`.

**Loophole:** `assertPublicHost()` resolves + validates the hostname, then `fetch(url)` **re-resolves DNS independently**. A domain with low-TTL records alternating public ↔ private passes the guard but connects to the private IP.

**Exploit:** attacker-controlled domain flips its A record between the validation lookup (returns public IP) and fetch's lookup (returns `169.254.169.254` / `10.x`) → SSRF to cloud metadata / internal services despite the guard.

**Fix:** resolve the host once, validate that literal IP, then connect to **that IP** with the original `Host` header (pin the address; don't let fetch re-resolve). In Node, use a custom `lookup`/agent that returns the pre-validated IP. Combined with P1's rate limit, this closes the tools surface.

---

## P3 — Anonymous short-link minting → open redirect / brand abuse (LOW-MED)

**Where:** `supabase/migrations/20260714000005_short_link.sql:75` — `ensure_short_links(text[])` is `security definer`, granted to **anon**; `resolve_short_link` (anon) 307-redirects.

**Loophole:** any unauthenticated caller mints `shubhamdatarkar.com/s/{slug}` pointing at an arbitrary `http(s)` URL. No auth, allowlist, or rate limit.

**Exploit:** phishing/malware links laundered under the trusted domain → brand + trust abuse, and the domain's reputation with spam filters.

**Fix:** revoke `ensure_short_links` from `anon`; require `authenticated` (or admin, if it's only used by admin tooling — check callers first). Optionally add a per-user rate cap. `resolve_short_link` staying anon is fine (read-only redirect of already-vetted rows).

---

## P4 — Support-order griefing on the failure path (LOW)

**Where:** `src/app/api/support/confirm/route.ts:34-41`.

**Loophole:** the `failed:true` branch flips an order to `failed` with **only an `orderId`, no signature**. The paid path is HMAC-verified; the fail path is not.

**Exploit:** anyone who learns a pending `order_XXXX` id (it's returned to the client at creation) can POST `{razorpay_order_id, failed:true}` to force a not-yet-paid row off `pending`. Griefing only — cannot grant "paid".

**Fix:** require the Razorpay failure signature (or at least verify the order id belongs to the session / is genuinely pending and unowned) before writing `failed`. Small guard.

---

## P5 — Unbounded anonymous newsletter signup (LOW)

**Where:** `supabase/migrations/20260615000001_create_subscribers.sql:25,42` — `subscribers` INSERT is `with check (true)` + `grant insert to anon`, no rate limit.

**Loophole:** anon inserts unlimited arbitrary email rows (sign up other people, spam, table bloat). It's the intended signup path, just unbounded.

**Fix:** the API route (`api/members/subscribe`) already exists as the front door — route signups through it with `allow()` rate-limiting and drop the direct anon table grant, or add a DB-side rate/dedupe. Confirm double-opt-in email is on so forged signups can't be weaponized as spam-via-you.

---

## P6 — Latent grant fragility (LOW, not currently exploitable)

**Where:** `20260616000003_contacts_email.sql:57`, `20260617000001_affiliate_domains.sql:25` — `for select ... to authenticated using (true)` on tables labelled "admin only". Safe **only** because no table `GRANT` exists; the policy itself checks nothing.

**Risk:** a future broad `grant select` (or `grant on all tables`) instantly exposes SMTP/config metadata to every logged-in user. Fragile-by-omission.

**Fix:** tighten both policies to `using (public.is_admin())` so the guard lives in the policy, not in the accident of a missing grant. Cheap, prevents a future foot-gun.

---

## Non-issues (checked, clean — do not "fix")

- `game_results` direct-insert hole — already closed (`20260716000001:81`, select-only).
- `profiles` self-escalation (`is_founder`/`banned`) — closed, column-level grants only (`20260713000001`).
- `contacts` PII read — re-scoped to `is_admin()` (`20260713000001:21`).
- Community likes/bookmarks/reblog/follow/poll — unique-constraint + trigger-maintained counts; no inflation. Post-as-another-user impossible (all inserts use `auth.uid()`).
- `loadFeedPage` re-checks auth, clamps limit/offset, sanitizes query.
- GitHub + Razorpay webhooks HMAC-verified, fail-closed; cron routes `CRON_SECRET`-gated.
- Admin surface: every Server Action re-gates with `requireAdmin()`; no middleware-only bypass.
- `next.config.ts:85` CSP `script-src 'unsafe-inline'` — informational only; no user-HTML sink exists, `frame-ancestors/object-src/base-uri` all locked. Keep both asset CDNs if touched (project rule).

---

## Suggested order

1. **P0** (real integrity hole, cheap grant-flip + one action edit).
2. **P1 + P2** together (same three files — rate limit + pin the DNS).
3. **P3, P5** (anon grant tightening, batchable into one migration).
4. **P4, P6** (small guards, low urgency).

Each is a normal branch → PR → merge per project flow. P0/P3/P5/P6 need manual SQL handoff (Supabase manual-migration workflow).
