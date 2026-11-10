# Shared Supabase Namespace Audit — `nefmwittrybufjqhpxip`

**Date:** 2026-11-10 · Shared across your official sites. **Rule: namespace, never wipe.**

## Current state: 18 tables, flat in `public`, no prefix/schema separation
```
academy_interest       downloads          payments
blog_authors           download_bookmarks profiles
blog_post_revisions    download_events    rate_limits
blog_posts             invoices           review_samples_used
blog_redirects         leads              memberships
community_posts        notifications
community_replies
```

## Classification (for the Datarkar site)
| Bucket | Tables | Note |
|---|---|---|
| **Shared / this-site uses** | `blog_posts`, `blog_authors`, `blog_post_revisions`, `blog_redirects`, `profiles`, `memberships`, `payments`, `invoices`, `leads`, `downloads`, `download_*`, `notifications`, `rate_limits` | Likely used by multiple official sites → **do not rename/drop**. Datarkar reads/writes via existing queries. |
| **Other-surface (removed here)** | `community_posts`, `community_replies` | Belong to the community product we stripped. Leave them; this site just won't touch them. |
| **Unclear** | `academy_interest`, `review_samples_used` | Another site's? Confirm owner before writing. |

## Build result (next build, exit 0, fail-soft)
App builds + prerenders clean — every missing-table read returns empty instead of crashing. Confirmed gap — **11 tables the code queries that this DB does NOT have**:
```
posts            services        resources        support_lifetime
case_studies     products        member_tools     support_stats
testimonials     link_categories public_supporters
```
**Naming mismatch proof:** code queries `public.posts`; this DB has `blog_posts`. Code ≠ this DB's schema. (More tables — bookings, support orders — will surface at runtime on dynamic routes, not caught at build.)

## ⚠️ Key gap to resolve — SCHEMA RECONCILIATION (decision needed)
The old shubhamdatarkar site ran on its **own** Supabase project (tables: `posts`, `services`, `products`…). This shared project was built for **other** sites (`blog_posts`, `memberships`, `payments`…). To run Datarkar on the shared DB, pick one:

- **Option A — Create the code's tables here (namespaced).** Add `posts`/`dk_posts`, `services`, `products`, `case_studies`, `resources`, `member_tools`, support tables, etc. to the shared project. Migrate old data from the old project. Least code change; grows the shared DB. **Recommended** — your content lives here, isolated by name.
- **Option B — Repoint code to the shared tables.** Rewrite queries (`posts`→`blog_posts`, etc.) + reconcile columns. Big code churn; shared tables likely lack columns the code needs. Not recommended.

**Good news — schema is recoverable.** Source repo `supabase/migrations/` has **37 migrations** = the full old schema (posts, content entities, supports, subscribers, members, bookings, links, contacts…), plus `20260616000001_zoho_integration.sql` (**your Zoho integration SQL**) and `20260704000001_razorpay_payments.sql`. Option A = apply the subset for **kept** surfaces, namespaced, skipping games/community/books/movies/gallery/photos/kalamai.

**⚠️ Collision risk:** some old migrations define tables the shared DB **already has** (`memberships`, `payments`, `profiles`). Applying blind would conflict. Each kept migration must be reviewed against the 18 existing tables before running. → confirm which tables are shared vs Datarkar-only (below).

## Original key gap
The **forked code expects tables that are NOT in this project** (e.g. content entities for services/case-studies/**products**, **bookings**, **support** tiers/updates, member resources/tools). This project has only the 18 above. So either:
1. The old site ran on a **different** Supabase project, and this shared one was never migrated for those surfaces → **we must create the missing tables here** (shop/products, bookings, support, content entities), namespaced; **or**
2. Those surfaces aren't wanted after all.

**The build (running) will surface exactly which table reads fail.** That failure list = the migration TODO.

## Recommendation
- Since sites share this DB with **flat, unprefixed** public tables, give Datarkar-specific new tables a clear namespace: **prefix `dk_`** (simplest, works with PostgREST) or a dedicated **`datarkar` schema** (cleaner, needs PostgREST schema exposure). Prefix is the lazy, zero-config choice.
- Reuse the genuinely shared tables as-is (`blog_posts`, `profiles`, `memberships`, `payments`, `leads`).
- **[NEEDS INPUT]** Confirm: are `blog_posts`/`profiles`/`memberships`/`payments` shared with your other sites (so schema changes there affect them), or Datarkar-only?
- **[NEEDS INPUT]** Owner of `academy_interest`, `review_samples_used`?
