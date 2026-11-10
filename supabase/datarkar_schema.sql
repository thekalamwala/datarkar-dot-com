-- ============================================================
-- Datarkar schema — all tables isolated in schema 'datarkar'.
-- Generated from kept migrations (timestamp order) with
-- public.* -> datarkar.* (auth.* untouched).
-- Run in Supabase SQL editor on nefmwittrybufjqhpxip, THEN
-- expose 'datarkar' in Settings > API > Exposed schemas.
-- Payments = Razorpay era (matches current code). Zoho re-added
-- later with its adapter.
-- ============================================================
create schema if not exists datarkar;
grant usage on schema datarkar to anon, authenticated, service_role;

-- ======== profiles (extracted from games_init; members/support depend on it) ========
-- Member identity, keyed to the shared auth.users. Must exist before members_platform.
create table if not exists datarkar.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  username   text unique not null,
  created_at timestamptz default now()
);

create or replace function datarkar.handle_new_user()
returns trigger language plpgsql security definer set search_path = datarkar, public as $$
begin
  insert into datarkar.profiles (id, username)
  values (
    new.id,
    lower(split_part(new.email, '@', 1)) || '_' || substr(md5(new.id::text), 1, 4)
  )
  on conflict (id) do nothing;
  return new;
end; $$;

-- datarkar-specific trigger name so it never clashes with another site's
-- trigger on the shared auth.users table.
drop trigger if exists datarkar_on_auth_user_created on auth.users;
create trigger datarkar_on_auth_user_created
  after insert on auth.users
  for each row execute function datarkar.handle_new_user();

alter table datarkar.profiles enable row level security;
drop policy if exists "profiles self read" on datarkar.profiles;
create policy "profiles self read" on datarkar.profiles for select using (true);
drop policy if exists "profiles self write" on datarkar.profiles;
create policy "profiles self write" on datarkar.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
grant select on datarkar.profiles to anon, authenticated;
grant update on datarkar.profiles to authenticated;

-- ======== 20260614000001_create_supports ========
-- Support module: persisted supports + public-safe derived views.
-- Target project: Shubham's OWN Supabase (ref oyzzgjrefkppqkxjccot). NOT the BAS project.
-- Apply via your own project's SQL editor or `supabase db push`.

-- digest() (used by support_lifetime.supporter_key) lives in pgcrypto.
create extension if not exists pgcrypto;

-- =====================================================================
-- Table: supports
-- One row per support attempt. Created 'pending' by the session route,
-- flipped to 'paid'/'failed' by the Zoho webhook. Service-role writes only.
-- =====================================================================
create table if not exists datarkar.supports (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),

  -- supporter-provided
  name            text,                       -- optional display name
  email           text not null,              -- receipt; NEVER exposed publicly
  message         text,                       -- <=250 chars (enforced below)

  -- items
  coffee_units    integer not null default 0 check (coffee_units >= 0),
  toffee_units    integer not null default 0 check (toffee_units >= 0),

  -- money (INR, whole rupees but numeric for safety)
  currency        text    not null default 'INR',
  base_amount     numeric(12,2) not null check (base_amount >= 0),  -- display total
  fee_amount      numeric(12,2) not null default 0 check (fee_amount >= 0),
  total_amount    numeric(12,2) not null check (total_amount >= 0),  -- charged
  covers_fee      boolean not null default true,
  anonymous       boolean not null default false,

  -- lifecycle
  status          text not null default 'pending'
                    check (status in ('pending', 'paid', 'failed')),
  zoho_session_id text,
  zoho_payment_id text,

  constraint supports_message_len check (message is null or char_length(message) <= 250),
  constraint supports_has_units   check (coffee_units > 0 or toffee_units > 0)
);

comment on table datarkar.supports is
  'Creator supports (Coffees/Toffees). Public reads go through views only; base table is service-role write + locked from anon/auth.';

-- Indexes for the derived reads (wall, strip, stats grouped by email).
create index if not exists supports_paid_created_idx
  on datarkar.supports (created_at desc) where status = 'paid';
create index if not exists supports_paid_email_idx
  on datarkar.supports (email) where status = 'paid';
create unique index if not exists supports_zoho_session_idx
  on datarkar.supports (zoho_session_id) where zoho_session_id is not null;

-- =====================================================================
-- RLS: lock the base table. No anon/authenticated policies => no access.
-- The service-role key bypasses RLS, so the server routes can read/write.
-- Public reads are served exclusively by the views below.
-- =====================================================================
alter table datarkar.supports enable row level security;
-- (intentionally no CREATE POLICY: anon + authenticated get zero rows)

-- =====================================================================
-- View: public_supporters
-- Paid rows, anonymized. Email never selected. Name hidden when anonymous.
-- Owned by the migration role => bypasses base-table RLS, exposing only
-- these safe columns. Newest first.
-- =====================================================================
create or replace view datarkar.public_supporters as
select
  id,
  created_at,
  case when anonymous then null else name end as name,
  coffee_units,
  toffee_units,
  base_amount,
  total_amount,
  anonymous
from datarkar.supports
where status = 'paid'
order by created_at desc;

comment on view datarkar.public_supporters is
  'Public-safe paid supporters. No email; name nulled when anonymous.';

-- =====================================================================
-- View: support_lifetime
-- Per-supporter lifetime totals (grouped by email) for tier computation.
-- Email is the grouping key but is NOT exposed; a stable anonymous hash is.
-- =====================================================================
create or replace view datarkar.support_lifetime as
select
  encode(digest(lower(email), 'sha256'), 'hex') as supporter_key,
  max(case when anonymous then null else name end) as name,
  sum(total_amount)  as lifetime_amount,
  sum(coffee_units)  as lifetime_coffees,
  sum(toffee_units)  as lifetime_toffees,
  count(*)           as support_count,
  max(created_at)    as last_supported_at,
  bool_and(anonymous) as anonymous
from datarkar.supports
where status = 'paid'
group by lower(email);

comment on view datarkar.support_lifetime is
  'Per-supporter lifetime aggregates for tiers. Keyed by sha256(email); email itself never exposed.';

-- =====================================================================
-- View: support_stats
-- Single-row headline metrics for the StatsBar.
-- =====================================================================
create or replace view datarkar.support_stats as
select
  count(distinct lower(email))           as supporters_total,
  coalesce(sum(coffee_units), 0)         as coffees_total,
  coalesce(sum(toffee_units), 0)         as toffees_total,
  coalesce(sum(total_amount), 0)         as raised_total
from datarkar.supports
where status = 'paid';

comment on view datarkar.support_stats is
  'Headline metrics derived from paid supports.';

-- Public read access to the derived views only.
grant select on datarkar.public_supporters to anon, authenticated;
grant select on datarkar.support_lifetime  to anon, authenticated;
grant select on datarkar.support_stats      to anon, authenticated;

-- ======== 20260614000002_admin_auth ========
-- Admin gate for RLS across content tables (posts, etc.).
-- Single-admin model: allowlist one email.
-- IMPORTANT: the email literal below must match your admin Auth user's email.
-- Target: your OWN Supabase project (NOT the BAS project). Run manually in the SQL editor.

create or replace function datarkar.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() ->> 'email') = 'bookasloth@gmail.com', false);
$$;

comment on function datarkar.is_admin() is
  'True when the current authenticated user is the site admin. Used by RLS policies on content tables.';

grant execute on function datarkar.is_admin() to anon, authenticated;

-- ======== 20260614000003_create_posts ========
-- Blog posts. body = ContentBlock[] (jsonb), unchanged from the static shape.
-- Public visibility is time-based: published_at <= now(). Drafts have null
-- published_at; scheduled posts have a future published_at and appear automatically.
-- Target: your OWN Supabase project. Run manually in the SQL editor.

create table if not exists datarkar.posts (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,
  title        text not null,
  excerpt      text not null default '',
  category     text not null,
  tags         text[] not null default '{}',
  words        integer not null default 0 check (words >= 0),
  featured     boolean not null default false,
  body         jsonb not null default '[]'::jsonb,
  status       text not null default 'draft'
                 check (status in ('draft', 'published', 'scheduled')),
  published_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table datarkar.posts is
  'Blog posts. Public reads via RLS (published_at <= now()); admin full access via is_admin().';

create index if not exists posts_visible_idx
  on datarkar.posts (published_at desc)
  where published_at is not null;
create index if not exists posts_category_idx on datarkar.posts (category);

-- keep updated_at fresh
create or replace function datarkar.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists posts_touch_updated_at on datarkar.posts;
create trigger posts_touch_updated_at
  before update on datarkar.posts
  for each row execute function datarkar.touch_updated_at();

-- RLS
alter table datarkar.posts enable row level security;

-- Public: only visible posts (published or past-scheduled).
drop policy if exists posts_public_read on datarkar.posts;
create policy posts_public_read on datarkar.posts
  for select
  to anon, authenticated
  using (published_at is not null and published_at <= now());

-- Admin: full read.
drop policy if exists posts_admin_read on datarkar.posts;
create policy posts_admin_read on datarkar.posts
  for select
  to authenticated
  using (datarkar.is_admin());

-- Admin: write (insert/update/delete).
drop policy if exists posts_admin_write on datarkar.posts;
create policy posts_admin_write on datarkar.posts
  for all
  to authenticated
  using (datarkar.is_admin())
  with check (datarkar.is_admin());

grant select on datarkar.posts to anon, authenticated;
grant insert, update, delete on datarkar.posts to authenticated;

-- ======== 20260615000001_create_subscribers ========
-- Newsletter subscribers. Anon can INSERT (signup); only admin can read.
-- Dedupe on lower(email). Target: your OWN Supabase project. Run manually.

create table if not exists datarkar.subscribers (
  id         uuid primary key default gen_random_uuid(),
  email      text not null,
  source     text,
  status     text not null default 'active' check (status in ('active', 'unsubscribed')),
  created_at timestamptz not null default now()
);

comment on table datarkar.subscribers is
  'Newsletter signups. Anon insert only; admin read. Email deduped case-insensitively.';

create unique index if not exists subscribers_email_lower_idx
  on datarkar.subscribers (lower(email));

alter table datarkar.subscribers enable row level security;

-- Anon (and authed visitors) may sign up: INSERT only, no read.
drop policy if exists subscribers_public_insert on datarkar.subscribers;
create policy subscribers_public_insert on datarkar.subscribers
  for insert
  to anon, authenticated
  with check (true);

-- Admin: read all.
drop policy if exists subscribers_admin_read on datarkar.subscribers;
create policy subscribers_admin_read on datarkar.subscribers
  for select
  to authenticated
  using (datarkar.is_admin());

-- Admin: update/delete (e.g. mark unsubscribed).
drop policy if exists subscribers_admin_write on datarkar.subscribers;
create policy subscribers_admin_write on datarkar.subscribers
  for all
  to authenticated
  using (datarkar.is_admin())
  with check (datarkar.is_admin());

grant insert on datarkar.subscribers to anon, authenticated;
grant select, update, delete on datarkar.subscribers to authenticated;

-- ======== 20260615000002_create_content ========
-- Content entities: case studies, projects, products, services, testimonials.
-- Uniform shape: the full typed object lives in `data` (jsonb), like posts.body.
-- Public reads = published rows; admin = full access via is_admin().
-- Reuses datarkar.touch_updated_at() created in the posts migration.
-- Target: your OWN Supabase project. Run manually.

-- Generic builder, run per table below.
do $$
declare
  t text;
  tables text[] := array['case_studies', 'projects', 'products', 'services', 'testimonials'];
begin
  foreach t in array tables loop
    execute format($f$
      create table if not exists datarkar.%I (
        id         uuid primary key default gen_random_uuid(),
        slug       text,
        data       jsonb not null default '{}'::jsonb,
        sort       integer not null default 0,
        published  boolean not null default true,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      );
    $f$, t);

    execute format(
      'create unique index if not exists %I on datarkar.%I (slug) where slug is not null;',
      t || '_slug_idx', t);
    execute format(
      'create index if not exists %I on datarkar.%I (sort);',
      t || '_sort_idx', t);

    execute format('alter table datarkar.%I enable row level security;', t);

    execute format('drop policy if exists %I on datarkar.%I;', t || '_public_read', t);
    execute format(
      'create policy %I on datarkar.%I for select to anon, authenticated using (published);',
      t || '_public_read', t);

    execute format('drop policy if exists %I on datarkar.%I;', t || '_admin_read', t);
    execute format(
      'create policy %I on datarkar.%I for select to authenticated using (datarkar.is_admin());',
      t || '_admin_read', t);

    execute format('drop policy if exists %I on datarkar.%I;', t || '_admin_write', t);
    execute format(
      'create policy %I on datarkar.%I for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());',
      t || '_admin_write', t);

    execute format('grant select on datarkar.%I to anon, authenticated;', t);
    execute format('grant insert, update, delete on datarkar.%I to authenticated;', t);

    execute format('drop trigger if exists %I on datarkar.%I;', t || '_touch_updated_at', t);
    execute format(
      'create trigger %I before update on datarkar.%I for each row execute function datarkar.touch_updated_at();',
      t || '_touch_updated_at', t);
  end loop;
end $$;

-- ======== 20260615000003_supports_admin_read ========
-- Admin read access to the supports base table (for the payments dashboard).
-- Public still reads only the email-free views; this grants the authenticated
-- admin full row access (incl. email + pending/failed) via is_admin().
-- Target: your OWN Supabase project. Run manually.

grant select on datarkar.supports to authenticated;

drop policy if exists supports_admin_read on datarkar.supports;
create policy supports_admin_read on datarkar.supports
  for select
  to authenticated
  using (datarkar.is_admin());

-- ======== 20260616000003_contacts_email ========
-- Contact form submissions + SMTP email integration.
-- Target project: Shubham's OWN Supabase. NOT the BAS project.
-- Apply via your own project's SQL editor or `supabase db push`.

create extension if not exists supabase_vault with schema vault cascade;

-- =====================================================================
-- Contact submissions. Written server-side (service-role); admin reads.
-- =====================================================================
create table if not exists datarkar.contacts (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  name          text not null,
  email         text not null,
  project_type  text,
  budget        text,
  message       text not null,
  status        text not null default 'new' check (status in ('new', 'read', 'archived')),
  notified      boolean not null default false,
  constraint contacts_message_len check (char_length(message) <= 5000)
);

create index if not exists contacts_created_at_idx on datarkar.contacts (created_at desc);

alter table datarkar.contacts enable row level security;

-- Authenticated admin may read. No public policy → inserts are service-role only.
drop policy if exists "contacts_authenticated_read" on datarkar.contacts;
create policy "contacts_authenticated_read"
  on datarkar.contacts
  for select
  to authenticated
  using (true);

-- =====================================================================
-- SMTP email integration: encrypted creds in Vault + status metadata.
-- =====================================================================
create table if not exists datarkar.email_integration (
  id                smallint primary key default 1,
  configured        boolean not null default false,
  last_test_at      timestamptz,
  last_test_ok      boolean,
  last_test_message text,
  updated_at        timestamptz not null default now(),
  constraint email_integration_singleton check (id = 1)
);

insert into datarkar.email_integration (id) values (1) on conflict (id) do nothing;

alter table datarkar.email_integration enable row level security;

drop policy if exists "email_integration_authenticated_read" on datarkar.email_integration;
create policy "email_integration_authenticated_read"
  on datarkar.email_integration
  for select
  to authenticated
  using (true);

create or replace function datarkar.set_email_secret(p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = datarkar, public, vault
as $$
declare
  v_id uuid;
begin
  select id into v_id from vault.secrets where name = 'email_smtp';
  if v_id is null then
    perform vault.create_secret(p_payload::text, 'email_smtp', 'SMTP email credentials (JSON)');
  else
    perform vault.update_secret(v_id, p_payload::text);
  end if;
end;
$$;

create or replace function datarkar.get_email_secret()
returns jsonb
language sql
security definer
set search_path = datarkar, public, vault
as $$
  select decrypted_secret::jsonb
  from vault.decrypted_secrets
  where name = 'email_smtp'
  limit 1;
$$;

revoke all on function datarkar.set_email_secret(jsonb) from public, anon, authenticated;
revoke all on function datarkar.get_email_secret() from public, anon, authenticated;
grant execute on function datarkar.set_email_secret(jsonb) to service_role;
grant execute on function datarkar.get_email_secret() to service_role;

-- ======== 20260617000002_post_reactions ========
-- Per-post reaction counters for blog posts. Counter only: never stores user
-- text, identity, or IP. All access via the service-role client (RLS bypass);
-- the apply_reaction RPC does the atomic -1 old / +1 new / toggle-off deltas.
-- Target: your OWN Supabase project. Run manually.

create table if not exists datarkar.post_reactions (
  post_slug text not null,
  reaction  text not null check (reaction in
    ('love','fire','insightful','meh','confused','down')),
  count     int  not null default 0,
  primary key (post_slug, reaction)
);

alter table datarkar.post_reactions enable row level security;
-- No anon/authenticated policy: counts are returned from the server action,
-- the browser never reads this table directly.

-- Atomic apply: decrement p_prev (if given), increment p_next (if given),
-- return the full count map for the post as jsonb.
create or replace function datarkar.apply_reaction(
  p_slug text, p_next text, p_prev text
) returns jsonb
language plpgsql security definer set search_path = datarkar, public as $$
declare result jsonb;
begin
  if p_prev is not null then
    update datarkar.post_reactions set count = greatest(count - 1, 0)
      where post_slug = p_slug and reaction = p_prev;
  end if;
  if p_next is not null then
    insert into datarkar.post_reactions (post_slug, reaction, count)
      values (p_slug, p_next, 1)
      on conflict (post_slug, reaction)
      do update set count = datarkar.post_reactions.count + 1;
  end if;
  select coalesce(jsonb_object_agg(reaction, count), '{}'::jsonb)
    into result from datarkar.post_reactions where post_slug = p_slug;
  return result;
end $$;

-- Lock the RPC to the service-role path only.
revoke all on function datarkar.apply_reaction(text, text, text) from public, anon;

-- ======== 20260617000003_support_updates ========
-- Support updates: DB-backed posts for /support/updates, each with a shareable
-- 6-digit code page. Types: text, image, video (manual) + thankyou (system,
-- created by the payment webhook in a later sub-project). No drafts — every row
-- is live; public reads all rows, admin writes via is_admin().
-- support_settings holds the up-to-5 reusable thank-you images.
-- Reuses datarkar.touch_updated_at() + datarkar.is_admin() from earlier migrations.
-- Target: your OWN Supabase project. Run manually.

create table if not exists datarkar.support_updates (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  type       text not null check (type in ('text','image','video','thankyou')),
  body       text not null default '',
  media      jsonb not null default '{}'::jsonb,
  author     jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_updates_created_idx
  on datarkar.support_updates (created_at desc);

alter table datarkar.support_updates enable row level security;

drop policy if exists support_updates_public_read on datarkar.support_updates;
create policy support_updates_public_read on datarkar.support_updates
  for select to anon, authenticated using (true);

drop policy if exists support_updates_admin_write on datarkar.support_updates;
create policy support_updates_admin_write on datarkar.support_updates
  for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

grant select on datarkar.support_updates to anon, authenticated;
grant insert, update, delete on datarkar.support_updates to authenticated;

drop trigger if exists support_updates_touch_updated_at on datarkar.support_updates;
create trigger support_updates_touch_updated_at before update on datarkar.support_updates
  for each row execute function datarkar.touch_updated_at();

-- Single-row settings table for the reusable thank-you images.
create table if not exists datarkar.support_settings (
  id              int primary key default 1 check (id = 1),
  thankyou_images jsonb not null default '[]'::jsonb,
  updated_at      timestamptz not null default now()
);
insert into datarkar.support_settings (id) values (1) on conflict (id) do nothing;

alter table datarkar.support_settings enable row level security;

drop policy if exists support_settings_public_read on datarkar.support_settings;
create policy support_settings_public_read on datarkar.support_settings
  for select to anon, authenticated using (true);

drop policy if exists support_settings_admin_write on datarkar.support_settings;
create policy support_settings_admin_write on datarkar.support_settings
  for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

grant select on datarkar.support_settings to anon, authenticated;
grant insert, update on datarkar.support_settings to authenticated;

drop trigger if exists support_settings_touch_updated_at on datarkar.support_settings;
create trigger support_settings_touch_updated_at before update on datarkar.support_settings
  for each row execute function datarkar.touch_updated_at();

-- ======== 20260617000004_comment_verifications ========
-- Transient OTP store for commenter email verification. Service-role only:
-- no anon/authenticated policy, so the OTP hash is never readable by clients.
-- One active OTP per email (pk on email). Target: your OWN Supabase project.
-- Run manually.

create table if not exists datarkar.comment_verifications (
  email        text primary key,
  code_hash    text not null,
  expires_at   timestamptz not null,
  attempts     int not null default 0,
  last_sent_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

alter table datarkar.comment_verifications enable row level security;
-- No policy on purpose: only the service-role client (RLS bypass) touches this.

revoke all on datarkar.comment_verifications from anon, authenticated;

-- ======== 20260618000001_support_comments ========
-- Threaded comments for support updates. Each comment is by a verified commenter
-- (email proven via OTP — see comment_verifications). The email is stored for
-- reply notifications + tier resolution but is PRIVATE: RLS denies all client
-- access, and the server strips the email column before returning rows to the
-- page. parent_id gives unbounded threading; the UI caps the visual indent.
-- Reuses datarkar.support_updates(code). Target: your OWN Supabase project.
-- Run manually.

create table if not exists datarkar.support_comments (
  id          uuid primary key default gen_random_uuid(),
  update_code text not null references datarkar.support_updates(code) on delete cascade,
  parent_id   uuid references datarkar.support_comments(id) on delete cascade,
  name        text not null,
  email       text not null,
  tier        text,
  body        text not null,
  created_at  timestamptz not null default now()
);

create index if not exists support_comments_code_idx
  on datarkar.support_comments (update_code, created_at);
create index if not exists support_comments_parent_idx
  on datarkar.support_comments (parent_id);

alter table datarkar.support_comments enable row level security;
-- No policy on purpose: only the service-role client (RLS bypass) reads/writes,
-- and it strips the email column before returning rows to the browser.
revoke all on datarkar.support_comments from anon, authenticated;

-- ======== 20260704000001_razorpay_payments ========
-- Razorpay payments: rename supports provider columns + drop the dead Zoho
-- integration surface. Target: OWN project (oyzzgjrefkppqkxjccot). Idempotent.
-- No paid rows exist yet, so the column renames are safe.

-- supports: rename provider columns (guard so re-runs don't error)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='datarkar' and table_name='supports' and column_name='zoho_session_id') then
    alter table datarkar.supports rename column zoho_session_id to razorpay_order_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='datarkar' and table_name='supports' and column_name='zoho_payment_id') then
    alter table datarkar.supports rename column zoho_payment_id to razorpay_payment_id;
  end if;
end $$;

alter index if exists datarkar.supports_zoho_session_idx rename to supports_rzp_order_idx;

-- Drop the dead Zoho integration objects (Kit/Email keep supabase_vault).
drop function if exists datarkar.set_zoho_secret(jsonb);
drop function if exists datarkar.get_zoho_secret();
drop table if exists datarkar.zoho_integration;

-- ======== 20260704000002_link_page ========
-- Linktree-style /link page: categories of links, admin-managed, publicly readable.
-- Public reads = published rows; admin = full access via is_admin().
-- Reuses datarkar.touch_updated_at() created in the posts migration.
-- Target: your OWN Supabase project. Run manually.

create table if not exists datarkar.link_categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text unique not null,
  sort       integer not null default 0,
  published  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists datarkar.links (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references datarkar.link_categories(id) on delete cascade,
  title       text not null,
  url         text not null,
  color       text not null default '#ffffff',
  sort        integer not null default 0,
  published   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists link_categories_sort_idx on datarkar.link_categories (sort);
create index if not exists links_category_sort_idx on datarkar.links (category_id, sort);

-- RLS: link_categories
alter table datarkar.link_categories enable row level security;

drop policy if exists link_categories_public_read on datarkar.link_categories;
create policy link_categories_public_read on datarkar.link_categories
  for select to anon, authenticated using (published);

drop policy if exists link_categories_admin_read on datarkar.link_categories;
create policy link_categories_admin_read on datarkar.link_categories
  for select to authenticated using (datarkar.is_admin());

drop policy if exists link_categories_admin_write on datarkar.link_categories;
create policy link_categories_admin_write on datarkar.link_categories
  for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

grant select on datarkar.link_categories to anon, authenticated;
grant insert, update, delete on datarkar.link_categories to authenticated;

drop trigger if exists link_categories_touch_updated_at on datarkar.link_categories;
create trigger link_categories_touch_updated_at
  before update on datarkar.link_categories
  for each row execute function datarkar.touch_updated_at();

-- RLS: links
alter table datarkar.links enable row level security;

drop policy if exists links_public_read on datarkar.links;
create policy links_public_read on datarkar.links
  for select to anon, authenticated using (published);

drop policy if exists links_admin_read on datarkar.links;
create policy links_admin_read on datarkar.links
  for select to authenticated using (datarkar.is_admin());

drop policy if exists links_admin_write on datarkar.links;
create policy links_admin_write on datarkar.links
  for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

grant select on datarkar.links to anon, authenticated;
grant insert, update, delete on datarkar.links to authenticated;

drop trigger if exists links_touch_updated_at on datarkar.links;
create trigger links_touch_updated_at
  before update on datarkar.links
  for each row execute function datarkar.touch_updated_at();

-- Seed data: 6 categories, 30 links, from reference bio page.
do $$
declare
  cat_start     uuid;
  cat_work      uuid;
  cat_resources uuid;
  cat_shop      uuid;
  cat_social    uuid;
  cat_games     uuid;
begin
  insert into datarkar.link_categories (name, slug, sort)
    values ('Start', 'start', 0)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_start;

  insert into datarkar.link_categories (name, slug, sort)
    values ('Work', 'work', 1)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_work;

  insert into datarkar.link_categories (name, slug, sort)
    values ('Resources', 'resources', 2)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_resources;

  insert into datarkar.link_categories (name, slug, sort)
    values ('Shop', 'shop', 3)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_shop;

  insert into datarkar.link_categories (name, slug, sort)
    values ('Social', 'social', 4)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_social;

  insert into datarkar.link_categories (name, slug, sort)
    values ('Games', 'games', 5)
    on conflict (slug) do update set name = excluded.name, sort = excluded.sort
    returning id into cat_games;

  -- Re-runnable seed: clear existing links for these categories before inserting.
  delete from datarkar.links
   where category_id in (cat_start, cat_work, cat_resources, cat_shop, cat_social, cat_games);

  -- Start
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_start, 'Fix Your Funnel in 30 Minutes', 'https://shubhamdatarkar.com/consult', '#FE5100', 0),
    (cat_start, 'Steal My SEO System (Blueprint)', 'https://tools.shubhamdatarkar.com/seo-systems.html', '#FF4D93', 1),
    (cat_start, 'Join Growth Newsletter', 'https://shubhamdatarkar.com/subscribe', '#269CEF', 2),
    (cat_start, 'Get Free Website Audit', 'https://tools.shubhamdatarkar.com/audit-website.html', '#2d9948', 3),
    (cat_start, 'Watch My Strategy Breakdown', 'https://youtube.com/@sndatarkar', '#FFCC1C', 4);

  -- Work
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_work, 'The Kalamwala''s Blog', 'https://shubhamdatarkar.com', '#000000', 0),
    (cat_work, 'Video Production', 'https://rajmudramudramedia.com', '#FE5100', 1),
    (cat_work, 'Digital Marketing', 'https://theboguscompany.com', '#2d9948', 2),
    (cat_work, 'Software Development', 'https://timewheel.co.in', '#FF4D93', 3),
    (cat_work, 'Creative Advertising', 'https://www.thegreyhawks.com/portfolio', '#269CEF', 4);

  -- Resources
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_resources, 'Marketing Frameworks', 'https://tools.shubhamdatarkar.com/marketing-frameworks.html', '#269CEF', 0),
    (cat_resources, 'Growth Playbooks', 'https://tools.shubhamdatarkar.com/growth-playbooks.html', '#FF4D93', 1),
    (cat_resources, 'Startup Tools', 'https://tools.shubhamdatarkar.com/startup-tools.html', '#2d9948', 2),
    (cat_resources, 'SEO Checklists', 'https://tools.shubhamdatarkar.com/seo-checklist.html', '#FFCC1C', 3),
    (cat_resources, 'Ad Copy Library', 'https://tools.shubhamdatarkar.com/ad-copy-library.html', '#FE5100', 4);

  -- Shop
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_shop, 'SEO Blueprint (Paid)', '#', '#FE5100', 0),
    (cat_shop, 'Growth Course', 'https://courses.shubhamdatarkar.com', '#FF4D93', 1),
    (cat_shop, 'Templates Bundle', 'https://shop.shubhamdatarkar.com/templates.html', '#269CEF', 2),
    (cat_shop, 'Funnel Kits', 'https://shop.shubhamdatarkar.com/funnle-kits.html', '#2d9948', 3),
    (cat_shop, 'Private Community', 'https://community.shubhamdatarkar.com/welcome.html', '#FFCC1C', 4);

  -- Social
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_social, 'LinkedIn', 'https://linkedin.com/in/sndatarkar', '#0A66C2', 0),
    (cat_social, 'Twitter', 'https://x.com/sndatarkar', '#000000', 1),
    (cat_social, 'YouTube', 'https://youtube.com/@sndatarkar', '#FF0000', 2),
    (cat_social, 'Instagram', 'https://instagram.com/sndatarkar', '#E1306C', 3),
    (cat_social, 'Facebook', 'https://facebook.com/sndatarkar', '#1877F2', 4);

  -- Games
  insert into datarkar.links (category_id, title, url, color, sort) values
    (cat_games, 'Tic Tac Toe', 'https://fun.shubhamdatarkar.com/tic-tac-toe.html', '#E53935', 0),
    (cat_games, '2048', 'https://fun.shubhamdatarkar.com/2048.html', '#7F00FF', 1),
    (cat_games, 'Wordle', 'https://fun.shubhamdatarkar.com/wordle.html', '#00BCD4', 2),
    (cat_games, 'Bulls and Cow', 'https://fun.shubhamdatarkar.com/bulls-and-cow.html', '#FFCBA4', 3),
    (cat_games, 'Guess the Face', 'https://fun.shubhamdatarkar.com/guess-the-face.html', '#FF00FF', 4);
end $$;

-- ======== 20260707000001_members_platform ========
-- Members platform: resources, taxonomy, membership, member features.
-- Everything is a Resource. Type-specific data lives in meta jsonb.

-- ============ guard: park any pre-existing ad-hoc resources table ============
-- Prod had an unrelated `resources` table (no `search` column, not created by
-- any migration, unused by app code). `create table if not exists` would skip
-- ours and the search index would then fail with 42703. Rename it aside —
-- nothing is dropped; inspect/remove `resources_legacy` manually later.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'datarkar' and table_name = 'resources'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'datarkar' and table_name = 'resources'
      and column_name = 'search'
  ) then
    alter table datarkar.resources rename to resources_legacy;
  end if;
end $$;

-- ============ taxonomy ============
create table if not exists datarkar.resource_types (
  key text primary key,
  label text not null,
  icon text,
  sort int not null default 0,
  active boolean not null default true
);

insert into datarkar.resource_types (key, label, sort) values
  ('article','Article',1),('prompt','Prompt',2),('template','Template',3),
  ('workflow','Workflow',4),('tool','Tool',5),('checklist','Checklist',6),
  ('case-study','Case Study',7),('download','Download',8),('video','Video',9),
  ('snippet','Snippet',10)
on conflict (key) do nothing;

create table if not exists datarkar.resource_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  sort int not null default 0,
  active boolean not null default true
);

insert into datarkar.resource_categories (name, slug, sort) values
  ('AI','ai',1),('SEO','seo',2),('GEO','geo',3),('AEO','aeo',4),
  ('Copywriting','copywriting',5),('Ads','ads',6),('Analytics','analytics',7),
  ('Branding','branding',8),('Landing Pages','landing-pages',9),
  ('Email Marketing','email-marketing',10),('Social Media','social-media',11),
  ('Automation','automation',12),('Business','business',13),
  ('Product','product',14),('Development','development',15)
on conflict (slug) do nothing;

create table if not exists datarkar.tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique
);

-- ============ resources ============
create table if not exists datarkar.resources (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  excerpt text,
  cover_image text,
  type text not null references datarkar.resource_types(key),
  category_id uuid references datarkar.resource_categories(id) on delete set null,
  difficulty text check (difficulty in ('beginner','intermediate','advanced')),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  visibility text not null default 'free' check (visibility in ('free','members','premium','hidden')),
  content jsonb not null default '[]'::jsonb,
  meta jsonb not null default '{}'::jsonb,
  featured boolean not null default false,
  author text not null default 'Shubham Datarkar',
  reading_time int,
  view_count int not null default 0,
  download_count int not null default 0,
  bookmark_count int not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(description,'') || ' ' || coalesce(excerpt,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(content::text,'')), 'C')
  ) stored
);

create index if not exists resources_search_idx on datarkar.resources using gin (search);
create index if not exists resources_list_idx on datarkar.resources (status, visibility, published_at desc);
create index if not exists resources_type_idx on datarkar.resources (type);
create index if not exists resources_category_idx on datarkar.resources (category_id);

drop trigger if exists resources_touch on datarkar.resources;
create trigger resources_touch before update on datarkar.resources
  for each row execute function datarkar.touch_updated_at();

create table if not exists datarkar.resource_tag (
  resource_id uuid not null references datarkar.resources(id) on delete cascade,
  tag_id uuid not null references datarkar.tags(id) on delete cascade,
  primary key (resource_id, tag_id)
);

-- ============ membership ============
create table if not exists datarkar.membership_plans (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  amount int not null,               -- paise
  interval text not null check (interval in ('monthly','yearly')),
  razorpay_plan_id text,             -- filled from Razorpay dashboard
  active boolean not null default false,
  sort int not null default 0
);

insert into datarkar.membership_plans (key, name, description, amount, interval, sort) values
  ('premium-monthly','Premium Monthly','Full access to everything, billed monthly', 9900, 'monthly', 1),
  ('premium-yearly','Premium Yearly','Full access to everything, billed yearly', 99900, 'yearly', 2)
on conflict (key) do nothing;

create table if not exists datarkar.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  plan_key text not null references datarkar.membership_plans(key),
  status text not null default 'pending' check (status in ('pending','active','cancelled','expired')),
  razorpay_subscription_id text unique,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists memberships_touch on datarkar.memberships;
create trigger memberships_touch before update on datarkar.memberships
  for each row execute function datarkar.touch_updated_at();

-- ============ member features ============
create table if not exists datarkar.resource_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  resource_id uuid not null references datarkar.resources(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);

create table if not exists datarkar.resource_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  resource_id uuid not null references datarkar.resources(id) on delete cascade,
  progress numeric(4,3) not null default 0 check (progress >= 0 and progress <= 1),
  completed boolean not null default false,
  last_viewed_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);

create index if not exists resource_progress_recent_idx
  on datarkar.resource_progress (user_id, last_viewed_at desc);

create table if not exists datarkar.member_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('template','prompt','tool','article','review')),
  title text not null,
  details text,
  status text not null default 'open' check (status in ('open','planned','shipped','declined')),
  created_at timestamptz not null default now()
);

create table if not exists datarkar.announcements (
  id uuid primary key default gen_random_uuid(),
  message text not null,
  href text,
  active boolean not null default false,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

-- Analytics events (views/downloads/bookmarks/search). Service-role only.
create table if not exists datarkar.resource_events (
  id bigint generated always as identity primary key,
  resource_id uuid references datarkar.resources(id) on delete cascade,
  user_id uuid,
  event text not null check (event in ('view','download','bookmark','search')),
  query text,
  created_at timestamptz not null default now()
);

create index if not exists resource_events_kind_idx on datarkar.resource_events (event, created_at desc);

-- Comments: architecture only in V1 (no UI, no client policies).
create table if not exists datarkar.resource_comments (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references datarkar.resources(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references datarkar.resource_comments(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

-- Interactive tool registry.
create table if not exists datarkar.member_tools (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  icon text,
  component text not null,           -- key into the client component registry
  category_id uuid references datarkar.resource_categories(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','live','archived')),
  sort int not null default 0
);

insert into datarkar.member_tools (slug, name, description, component, status, sort) values
  ('utm-builder','UTM Link Builder','Build tagged campaign URLs and copy them in one click.','utm-builder','live',1)
on conflict (slug) do nothing;

-- ============ RPCs ============
create or replace function datarkar.search_resources(q text, lim int default 20)
returns table (
  id uuid, slug text, title text, description text, type text,
  category_id uuid, difficulty text, visibility text, cover_image text,
  featured boolean, published_at timestamptz
)
language sql stable security definer set search_path = datarkar, public as $$
  select r.id, r.slug, r.title, r.description, r.type, r.category_id,
         r.difficulty, r.visibility, r.cover_image, r.featured, r.published_at
  from resources r
  where r.status = 'published' and r.visibility <> 'hidden'
    and (
      r.search @@ plainto_tsquery('english', q)
      or r.title ilike '%' || q || '%'
      or exists (
        select 1 from resource_tag rt join tags t on t.id = rt.tag_id
        where rt.resource_id = r.id and t.name ilike '%' || q || '%'
      )
    )
  order by ts_rank(r.search, plainto_tsquery('english', q)) desc,
           r.published_at desc nulls last
  limit lim;
$$;

create or replace function datarkar.bump_resource_counter(rid uuid, kind text)
returns void language sql security definer set search_path = datarkar, public as $$
  update resources set
    view_count = view_count + (kind = 'view')::int,
    download_count = download_count + (kind = 'download')::int,
    bookmark_count = greatest(0, bookmark_count
      + case when kind = 'bookmark' then 1 when kind = 'unbookmark' then -1 else 0 end)
  where id = rid;
$$;

revoke execute on function datarkar.bump_resource_counter(uuid, text) from public, anon, authenticated;

-- ============ RLS ============
alter table datarkar.resource_types enable row level security;
alter table datarkar.resource_categories enable row level security;
alter table datarkar.tags enable row level security;
alter table datarkar.resources enable row level security;
alter table datarkar.resource_tag enable row level security;
alter table datarkar.membership_plans enable row level security;
alter table datarkar.memberships enable row level security;
alter table datarkar.resource_bookmarks enable row level security;
alter table datarkar.resource_progress enable row level security;
alter table datarkar.member_requests enable row level security;
alter table datarkar.announcements enable row level security;
alter table datarkar.resource_events enable row level security;
alter table datarkar.resource_comments enable row level security;
alter table datarkar.member_tools enable row level security;

-- taxonomy: public read, admin write
create policy resource_types_public_read on datarkar.resource_types for select to anon, authenticated using (active);
create policy resource_types_admin_all on datarkar.resource_types for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());
create policy resource_categories_public_read on datarkar.resource_categories for select to anon, authenticated using (active);
create policy resource_categories_admin_all on datarkar.resource_categories for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());
create policy tags_public_read on datarkar.tags for select to anon, authenticated using (true);
create policy tags_admin_all on datarkar.tags for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- resources + join: admin session CRUD; member-facing reads go through service role server-side
create policy resources_admin_all on datarkar.resources for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());
create policy resource_tag_admin_all on datarkar.resource_tag for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- membership: self read, admin read; writes via service role only
create policy membership_plans_public_read on datarkar.membership_plans for select to anon, authenticated using (active);
create policy membership_plans_admin_all on datarkar.membership_plans for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());
create policy memberships_self_read on datarkar.memberships for select to authenticated using (auth.uid() = user_id);
create policy memberships_admin_read on datarkar.memberships for select to authenticated using (datarkar.is_admin());

-- member features: self-scoped
create policy bookmarks_self_all on datarkar.resource_bookmarks for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy progress_self_all on datarkar.resource_progress for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy requests_self_read on datarkar.member_requests for select to authenticated using (auth.uid() = user_id or datarkar.is_admin());
create policy requests_self_insert on datarkar.member_requests for insert to authenticated with check (auth.uid() = user_id);
create policy requests_admin_update on datarkar.member_requests for update to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- announcements: public read within active window, admin all
create policy announcements_public_read on datarkar.announcements for select to anon, authenticated
  using (active and starts_at <= now() and (ends_at is null or ends_at > now()));
create policy announcements_admin_all on datarkar.announcements for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- tools: public read live, admin all
create policy member_tools_public_read on datarkar.member_tools for select to anon, authenticated using (status = 'live');
create policy member_tools_admin_all on datarkar.member_tools for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- resource_events, resource_comments: no client policies (service-role only)

-- ============ storage: private bucket for member downloads ============
insert into storage.buckets (id, name, public)
values ('member-files', 'member-files', false)
on conflict (id) do nothing;
-- No storage.objects policies: service-role only (signed URLs minted server-side after access check).

-- ======== 20260708000001_capabilities ========
-- Capability-based membership: plans bundle capabilities; content requires them.

-- Free plan needs a non-billing interval; relax the check and add the row.
alter table datarkar.membership_plans drop constraint if exists membership_plans_interval_check;
alter table datarkar.membership_plans
  add constraint membership_plans_interval_check check (interval in ('monthly','yearly','free'));

insert into datarkar.membership_plans (key, name, description, amount, interval, active, sort)
values ('free','Free','Today''s puzzle, yesterday''s puzzle, and public resources.',0,'free',true,0)
on conflict (key) do nothing;

-- Plan -> capability bundle (admin-editable).
create table if not exists datarkar.plan_capabilities (
  plan_key text not null references datarkar.membership_plans(key) on delete cascade,
  capability text not null,
  primary key (plan_key, capability)
);

-- Member tier = both paid plans get every grantable capability.
insert into datarkar.plan_capabilities (plan_key, capability)
select p.key, c.cap
from (values ('premium-monthly'), ('premium-yearly')) as p(key)
cross join (values
  ('view_archive'),('view_premium_blog'),('view_premium_case_study'),
  ('view_premium_video'),('view_premium_course'),('view_premium_album'),
  ('view_premium_resource'),('download_assets'),('download_templates'),
  ('access_prompt_library'),('play_unlimited_games'),('earn_achievements'),
  ('streak_history'),('join_private_community'),('attend_live_sessions'),
  ('access_beta_features'),('early_access')
) as c(cap)
on conflict do nothing;

-- Resources declare the capability they need (null = public).
alter table datarkar.resources add column if not exists required_capability text;

update datarkar.resources set required_capability = case
  when visibility = 'hidden' then 'admin_only'
  when visibility in ('members','premium') then case type
    when 'article'    then 'view_premium_blog'
    when 'case-study' then 'view_premium_case_study'
    when 'video'      then 'view_premium_video'
    when 'prompt'     then 'access_prompt_library'
    when 'template'   then 'download_templates'
    when 'download'   then 'download_assets'
    else 'view_premium_resource'
  end
  else null
end
where required_capability is null;

create index if not exists resources_required_capability_idx
  on datarkar.resources (required_capability);

-- RLS for the new table: public read, admin write.
alter table datarkar.plan_capabilities enable row level security;
create policy plan_capabilities_public_read on datarkar.plan_capabilities
  for select to anon, authenticated using (true);
create policy plan_capabilities_admin_all on datarkar.plan_capabilities
  for all to authenticated using (datarkar.is_admin()) with check (datarkar.is_admin());

-- ======== 20260708000002_search_required_capability ========
-- Point the search RPC at required_capability instead of visibility.
-- Return-type changed (column swap), so drop before recreate.
drop function if exists datarkar.search_resources(text, integer);

create function datarkar.search_resources(q text, lim int default 20)
returns table (
  id uuid, slug text, title text, description text, type text,
  category_id uuid, difficulty text, required_capability text, cover_image text,
  featured boolean, published_at timestamptz
)
language sql stable security definer set search_path = datarkar, public as $$
  select r.id, r.slug, r.title, r.description, r.type, r.category_id,
         r.difficulty, r.required_capability, r.cover_image, r.featured, r.published_at
  from resources r
  where r.status = 'published' and coalesce(r.required_capability,'') <> 'admin_only'
    and (
      r.search @@ plainto_tsquery('english', q)
      or r.title ilike '%' || q || '%'
      or exists (
        select 1 from resource_tag rt join tags t on t.id = rt.tag_id
        where rt.resource_id = r.id and t.name ilike '%' || q || '%'
      )
    )
  order by ts_rank(r.search, plainto_tsquery('english', q)) desc,
           r.published_at desc nulls last
  limit lim;
$$;

-- ======== 20260709000001_membership_source ========
-- Distinguish paid subscriptions from admin-granted gifts.
-- Gifts are activated manually (no Razorpay subscription) and must NOT be
-- counted as paid members. Lifetime gifts use a far-future period end.
alter table datarkar.memberships
  add column if not exists source text not null default 'paid'
    check (source in ('paid', 'gift'));

-- ======== 20260711000001_contact_attribution ========
-- First-touch attribution on contact submissions.
-- All nullable: rows written before this migration, and visitors with
-- localStorage disabled, legitimately have no attribution.
alter table datarkar.contacts
  add column if not exists first_landing_page text,
  add column if not exists referrer          text,
  add column if not exists ai_source         text,
  add column if not exists utm_source        text,
  add column if not exists utm_medium        text,
  add column if not exists utm_campaign      text,
  add column if not exists pages_seen        integer;

-- The two questions this table now has to answer fast:
--   "which page produces retainer leads?"  and  "did AI send them?"
create index if not exists contacts_first_landing_page_idx on datarkar.contacts (first_landing_page);
create index if not exists contacts_ai_source_idx on datarkar.contacts (ai_source) where ai_source is not null;

-- ======== 20260711000002_blog_seo_fields ========
-- Per-post SEO copy. All nullable: an unset column falls back to the post's
-- title/excerpt, which is exactly today's behaviour.
alter table datarkar.posts
  add column if not exists seo_title      text,
  add column if not exists og_title       text,
  add column if not exists og_description text;

comment on column datarkar.posts.seo_title is
  'Keyword <title> phrase, 15-40 chars, no brand name (the layout template appends it). Falls back to title.';
comment on column datarkar.posts.og_title is
  'Social-card headline. Falls back to the branded full title.';
comment on column datarkar.posts.og_description is
  'Social-card body. Falls back to excerpt.';

-- ======== 20260713000001_security_hardening ========
-- =====================================================================
-- Security hardening — RLS, column privileges, and a crawler-job lock.
-- Target: OWN Supabase (ref oyzzgjrefkppqkxjccot). NOT the BAS project.
-- Apply MANUALLY via the SQL editor. Idempotent — safe to re-run.
--
-- Fixes (audit 2026-07-11):
--   1. contacts: any logged-in user could read every lead's PII. Gate to admin,
--      matching the subscribers/supports read policies.
--   2. profiles: the self-update policy scoped the row but not the columns, so a
--      user could self-set is_founder (fake gold badge) or banned=false (evade a
--      moderator ban). Restrict UPDATE to identity columns only.
--   3. profiles: the public self-read exposed the moderation columns (banned,
--      banned_reason) to the anon key. Hide them; keep identity columns datarkar.
--   4. kalamai_analyses: add a claim column so /step can't be fanned out into
--      duplicate paid LLM calls (paired with the runStep single-flight claim).
-- =====================================================================

-- 1. contacts — reads are admin-only.
drop policy if exists "contacts_authenticated_read" on datarkar.contacts;
drop policy if exists "contacts_admin_read" on datarkar.contacts;
create policy "contacts_admin_read"
  on datarkar.contacts
  for select
  to authenticated
  using (datarkar.is_admin());

-- 2. profiles — authenticated may edit ONLY their own identity fields. The
--    badge/moderation columns (is_founder, banned, banned_reason) are written by
--    admin-only definer RPCs, never by the user.
--    NOTE: a column-level REVOKE alone is not enough — a table-level UPDATE grant
--    covers every column regardless. So drop the table grant, then re-grant only
--    the safe columns. (Row inserts happen via the handle_new_user definer
--    trigger, so authenticated/anon need no INSERT.)
revoke insert, update, delete on datarkar.profiles from anon, authenticated;
grant update (username, display_name, bio) on datarkar.profiles to authenticated;

-- 3. profiles — hide moderation columns from the public anon key; keep the
--    public identity columns readable (usernames, badges).
revoke select on datarkar.profiles from anon;
grant select (id, username, display_name, bio, is_founder, created_at)
  on datarkar.profiles to anon;

-- 4. kalamai_analyses — single-flight claim column for the step state machine.
alter table datarkar.kalamai_analyses add column if not exists locked_at timestamptz;

-- ======== 20260713000002_storage_upload_hardening — SKIPPED ========
-- Was a community-media bucket RLS policy (community removed). Omitted.

-- ======== 20260714000001_member_account_fields ========
-- Member account: optional personal fields + birthday-greeting plumbing.
--
-- profiles has a permissive read policy ("profiles: self read" USING (true)) so
-- ANY authenticated user can read ANY row. New fields DOB / WhatsApp / location
-- are PII and must not ride that policy. So we:
--   1. add the columns (all nullable),
--   2. re-scope authenticated SELECT to only the pre-existing (non-PII) columns
--      — every column that existed before, so no existing query breaks,
--   3. expose owner read/write of the PII through security-definer RPCs that
--      check auth.uid(), and the birthday cron through service_role-only RPCs.

-- ---------- 1. columns ----------
alter table datarkar.profiles add column if not exists full_name             text;
alter table datarkar.profiles add column if not exists date_of_birth         date;
alter table datarkar.profiles add column if not exists location              text;
alter table datarkar.profiles add column if not exists whatsapp              text;
alter table datarkar.profiles add column if not exists birthday_greeted_year smallint; -- last year we emailed them

-- ---------- 2. re-scope authenticated SELECT (withhold only the new PII) ----------
revoke select on datarkar.profiles from authenticated;
grant  select (id, username, created_at, display_name, bio, is_founder, banned, banned_reason)
  on datarkar.profiles to authenticated;

-- ---------- 3a. owner read of own PII ----------
create or replace function datarkar.get_my_account()
returns table (full_name text, date_of_birth date, location text, whatsapp text)
language sql security definer set search_path = datarkar, public stable as $$
  select full_name, date_of_birth, location, whatsapp
  from datarkar.profiles
  where id = auth.uid();
$$;
revoke execute on function datarkar.get_my_account() from anon;
grant  execute on function datarkar.get_my_account() to authenticated;

-- ---------- 3b. owner write of own PII ----------
create or replace function datarkar.update_my_account(
  p_full_name text,
  p_dob       date,
  p_location  text,
  p_whatsapp  text
) returns void
language plpgsql security definer set search_path = datarkar, public as $$
begin
  update datarkar.profiles set
    full_name     = nullif(btrim(p_full_name), ''),
    date_of_birth = p_dob,
    location      = nullif(btrim(p_location), ''),
    whatsapp      = nullif(btrim(p_whatsapp), '')
  where id = auth.uid();
end; $$;
revoke execute on function datarkar.update_my_account(text, date, text, text) from anon;
grant  execute on function datarkar.update_my_account(text, date, text, text) to authenticated;

-- ---------- 3c. birthday cron: whose birthday is today (IST), not yet greeted this year ----------
-- ponytail: Feb-29 births only fire in leap years (no fallback to Feb-28). Upgrade if it matters.
create or replace function datarkar.birthdays_today()
returns table (id uuid, email text, full_name text)
language sql security definer set search_path = datarkar, public stable as $$
  select p.id, u.email::text, p.full_name
  from datarkar.profiles p
  join auth.users u on u.id = p.id
  where p.date_of_birth is not null
    and u.email is not null
    and extract(month from p.date_of_birth) = extract(month from (now() at time zone 'Asia/Kolkata'))
    and extract(day   from p.date_of_birth) = extract(day   from (now() at time zone 'Asia/Kolkata'))
    and coalesce(p.birthday_greeted_year, 0)
        <> extract(year from (now() at time zone 'Asia/Kolkata'))::int;
$$;
revoke execute on function datarkar.birthdays_today() from anon, authenticated;
grant  execute on function datarkar.birthdays_today() to service_role;

-- ---------- 3d. birthday cron: mark greeted (idempotent within the year) ----------
create or replace function datarkar.mark_birthday_greeted(p_id uuid)
returns void
language sql security definer set search_path = datarkar, public as $$
  update datarkar.profiles
    set birthday_greeted_year = extract(year from (now() at time zone 'Asia/Kolkata'))::int
    where id = p_id;
$$;
revoke execute on function datarkar.mark_birthday_greeted(uuid) from anon, authenticated;
grant  execute on function datarkar.mark_birthday_greeted(uuid) to service_role;

-- ======== 20260714000005_short_link ========
-- =====================================================================
-- Link shortener for /community — shubhamdatarkar.com/s/{7-char}.
-- Target: OWN Supabase (ref oyzzgjrefkppqkxjccot). Apply MANUALLY. Idempotent.
--
-- Any http(s) URL in a post body renders as shubhamdatarkar.com/s/{slug} and
-- /s/{slug} 307s to the original. Codes are minted on READ (feed render), so
-- old seed + auto-posted links get shortened with no backfill and without
-- touching the 5+ insert paths.
--
-- Table is fully locked (RLS on, no policies): every access goes through the
-- two SECURITY DEFINER RPCs below, so anon never touches rows directly.
-- =====================================================================

create table if not exists datarkar.short_link (
  slug        text primary key,
  target_url  text not null unique,
  clicks      integer not null default 0,
  created_at  timestamptz not null default now()
);

alter table datarkar.short_link enable row level security;
-- No policies on purpose — reads/writes only via the definer RPCs.

-- ---------- 7-char base62 slug generator ----------
create or replace function datarkar.gen_short_slug()
returns text language plpgsql volatile as $$
declare
  alphabet text := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  s text := '';
  i int;
begin
  for i in 1..7 loop
    -- random() is [0,1) -> floor(random()*62) is 0..61 -> substr is 1-indexed
    s := s || substr(alphabet, 1 + floor(random() * 62)::int, 1);
  end loop;
  return s;
end $$;

-- ---------- mint-or-lookup a code per URL (render path) ----------
-- Returns one (url, slug) row per distinct http(s) URL. Non-http inputs are
-- skipped (never shortened). Same URL always maps to the same slug.
create or replace function datarkar.ensure_short_links(p_urls text[])
returns table(url text, slug text)
language plpgsql security definer set search_path = datarkar, public as $$
declare
  u text;
  new_slug text;
begin
  foreach u in array coalesce(p_urls, '{}') loop
    continue when u !~* '^https?://';

    -- fast path: already mapped
    if exists (select 1 from short_link sl where sl.target_url = u) then
      return query select u, sl.slug from short_link sl where sl.target_url = u;
      continue;
    end if;

    -- mint, retrying on a slug (PK) collision; a concurrent insert of the SAME
    -- url surfaces as unique_violation on target_url -> use the winner's row.
    loop
      new_slug := gen_short_slug();
      begin
        insert into short_link (slug, target_url) values (new_slug, u);
        exit;
      exception when unique_violation then
        exit when exists (select 1 from short_link sl where sl.target_url = u);
        -- else the slug collided: loop and regenerate
      end;
    end loop;

    return query select u, sl.slug from short_link sl where sl.target_url = u;
  end loop;
end $$;

grant execute on function datarkar.ensure_short_links(text[]) to anon, authenticated;

-- ---------- resolve a code -> target, bumping the click counter ----------
create or replace function datarkar.resolve_short_link(p_slug text)
returns text
language plpgsql security definer set search_path = datarkar, public as $$
declare v_url text;
begin
  update short_link set clicks = clicks + 1
   where slug = p_slug
   returning target_url into v_url;
  return v_url;  -- null when the slug is unknown
end $$;

grant execute on function datarkar.resolve_short_link(text) to anon, authenticated;

-- ======== 20260714000006_support_lifetime_message ========
-- =====================================================================
-- Expose the supporter's latest note on the public support_lifetime view.
--
-- Feeds the "click a supporter → see the message they left" modal on
-- /support/supporters. Product decision: the note shows for EVERYONE,
-- including anonymous supporters (their NAME stays hidden — nulled above —
-- but the note itself is shown). Email is still never exposed.
--
-- CREATE OR REPLACE with the column appended at the end (allowed for views).
-- Replacing a view preserves existing grants; re-granted below to be safe.
-- =====================================================================
create or replace view datarkar.support_lifetime as
select
  encode(digest(lower(email), 'sha256'), 'hex') as supporter_key,
  max(case when anonymous then null else name end) as name,
  sum(total_amount)  as lifetime_amount,
  sum(coffee_units)  as lifetime_coffees,
  sum(toffee_units)  as lifetime_toffees,
  count(*)           as support_count,
  max(created_at)    as last_supported_at,
  bool_and(anonymous) as anonymous,
  -- Latest non-null note across this supporter's paid rows.
  (array_remove(array_agg(message order by created_at desc), null))[1] as message
from datarkar.supports
where status = 'paid'
group by lower(email);

comment on view datarkar.support_lifetime is
  'Per-supporter lifetime aggregates for tiers. Keyed by sha256(email); email never exposed. Includes the latest note (shown for all, incl. anonymous).';

grant select on datarkar.support_lifetime to anon, authenticated;

-- ======== 20260715000010_email_log ========
-- =====================================================================
-- email_log — dedupe ledger for scheduled/branded emails (SP4 dispatcher).
-- Target: OWN Supabase (ref oyzzgjrefkppqkxjccot). Apply MANUALLY. Idempotent.
--
-- One row per (recipient, template_key, period) that has been sent. The
-- dispatcher claims a send by inserting first; a unique-violation (23505)
-- means it was already sent for that period, so the caller skips it. This
-- makes a re-run (or an overlapping cron invocation) safe without locks.
--
-- `period` is whatever granularity the template needs (a day "YYYY-MM-DD",
-- a month "YYYY-MM", an ISO week "YYYY-Www", etc. — see istParts()).
--
-- Table is fully locked (RLS on, no policies): only the service-role client
-- (supabaseAdmin, used by the cron route) ever touches it.
-- =====================================================================

create table if not exists datarkar.email_log (
  id           bigint generated always as identity primary key,
  recipient    text not null,
  template_key text not null,
  period       text not null,
  created_at   timestamptz not null default now(),
  unique (recipient, template_key, period)
);

create index if not exists email_log_template_period_idx
  on datarkar.email_log (template_key, period);

alter table datarkar.email_log enable row level security;
-- No policies on purpose — service-role only (bypasses RLS).

-- ======== 20260718000001_block_unverified ========
-- Hard-block accounts that never verified their email within 48h. The app's
-- in-code gate (isUnverifiedPastGrace) already refuses their logins; this bans
-- dormant accounts so a stale session can't keep acting. Idempotent: skips rows
-- already banned into the future.
create or replace function datarkar.block_unverified_accounts()
returns integer
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  n integer;
begin
  with blocked as (
    update auth.users
       set banned_until = now() + interval '100 years'
     where email_confirmed_at is null
       and created_at < now() - interval '48 hours'
       and (banned_until is null or banned_until < now())
    returning id
  )
  select count(*) into n from blocked;
  return n;
end;
$$;

revoke all on function datarkar.block_unverified_accounts() from public, anon, authenticated;
grant execute on function datarkar.block_unverified_accounts() to service_role;

-- ======== 20260718000001_member_avatars ========
-- =====================================================================
-- Member profile photos. Target: OWN Supabase (ref oyzzgjrefkppqkxjccot).
-- NOT the BAS project. Apply MANUALLY. Idempotent.
-- Mirrors the community-media bucket pattern (20260710000004 / _13000002).
-- =====================================================================

-- PRE-CHECK (owner): confirm anon column grants before applying.
-- Run this query to see what columns anon already reads on profiles.
-- The avatar_url grant below must match the existing pattern.
--
-- select grantee, string_agg(column_name, ', ' order by column_name) as cols
-- from information_schema.column_privileges
-- where table_schema = 'datarkar' and table_name = 'profiles' and privilege_type = 'SELECT'
-- group by grantee;
--
-- Expected: authenticated has the named column list from 20260714000001.
-- If anon has table-wide SELECT, the grant below is a harmless idempotent superset.

-- 1. column
alter table datarkar.profiles add column if not exists avatar_url text;

-- 2. make avatar_url readable. The account-fields migration re-scoped
-- authenticated SELECT to a named column list; add avatar_url to it. anon
-- renders public profile pages, so it needs the column too.
grant select (avatar_url) on datarkar.profiles to authenticated, anon;

-- 3. bucket
insert into storage.buckets (id, name, public)
values ('member-avatars', 'member-avatars', true)
on conflict (id) do nothing;

-- 4a. public read
drop policy if exists member_avatars_public_read on storage.objects;
create policy member_avatars_public_read
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'member-avatars');

-- 4b. owner-folder write (defense in depth: real uploads use the service role).
-- Own {auth.uid()}/ folder only; raster extensions only (no svg/html).
drop policy if exists member_avatars_owner_write on storage.objects;
create policy member_avatars_owner_write
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'member-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and lower(storage.extension(name)) in ('jpg','jpeg','png','webp','gif','avif')
  );

-- 4c. admin delete (moderation)
drop policy if exists member_avatars_admin_delete on storage.objects;
create policy member_avatars_admin_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'member-avatars' and datarkar.is_admin());

-- ======== 20260718000002_onboarding ========
-- Onboarding state + self-serve username.
alter table datarkar.profiles add column if not exists onboarded_at   timestamptz;
alter table datarkar.profiles add column if not exists referral_source text;

-- member_account_fields.sql re-scoped authenticated SELECT to an explicit column
-- list (withholding PII). onboarded_at is not sensitive and the /welcome page
-- reads it via the session client to gate re-onboarding, so grant it. Column
-- grants are additive. referral_source stays withheld — it is only ever written.
grant select (onboarded_at) on datarkar.profiles to authenticated;

-- security_hardening.sql revoked base UPDATE on profiles and allowlisted only
-- (username, display_name, bio). The onboarding flow writes these two columns
-- from the user's own session, so add them to the UPDATE allowlist. RLS
-- ("profiles: self write", auth.uid() = id) still restricts writes to the
-- caller's own row. Column grants are additive.
grant update (onboarded_at, referral_source) on datarkar.profiles to authenticated;

-- Let a signed-in user set their own username, with uniqueness + format rules.
-- security definer so the unique-violation is caught server-side and surfaced
-- as a friendly error. Callable by the authenticated user for their own row only
-- (uses auth.uid()).
create or replace function datarkar.set_username(p_username text)
returns void
language plpgsql
security definer
set search_path = datarkar, public
as $$
declare
  v text := trim(p_username);
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- v is null when p_username is null; guard explicitly so a null doesn't skip
  -- the regex (NULL !~ pattern is NULL, which PL/pgSQL's IF treats as false).
  if v is null or v !~ '^[a-zA-Z0-9_.]{3,30}$' then
    raise exception 'username must be 3-30 chars: letters, numbers, dot, underscore';
  end if;
  update datarkar.profiles set username = v where id = auth.uid();
exception
  when unique_violation then raise exception 'username already taken';
end;
$$;

revoke all on function datarkar.set_username(text) from public, anon;
grant execute on function datarkar.set_username(text) to authenticated;

-- ======== 20260806000002_short_link_mint_service_role ========
-- =============================================================
--  Anonymous short-link minting: brand-abuse / open-redirect vector.
--
--  ensure_short_links(text[]) is security-definer and was granted to anon: any
--  unauthenticated caller could mint shubhamdatarkar.com/s/{slug} pointing at an
--  ARBITRARY http(s) URL (no auth, allowlist, or rate limit), and
--  resolve_short_link 307-redirects to it. That launders phishing/malware links
--  under the trusted domain and burns its reputation with spam filters.
--
--  Minting is only ever needed on the server render path (ensureShortLinks in
--  src/lib/community/short-link.ts), so make it trusted-server-only: revoke from
--  anon/authenticated AND from PUBLIC (functions get EXECUTE to PUBLIC by default,
--  so revoking only the two roles would leave the inherited PUBLIC grant intact),
--  and grant service_role. The render path now calls it via supabaseAdmin().
--
--  resolve_short_link stays anon: it's a read-only redirect of rows that were
--  already vetted at mint time, and /s/{slug} must work for logged-out visitors.
--
--  Graceful either deploy order: if this runs before the app redeploys, the old
--  anon render call is denied and ensureShortLinks falls back to the raw href
--  (best-effort catch) — links just render unshortened, nothing breaks.
-- =============================================================

revoke execute on function datarkar.ensure_short_links(text[]) from public, anon, authenticated;
grant execute on function datarkar.ensure_short_links(text[]) to service_role;

-- ======== 20260806000003_subscribers_no_anon_insert ========
-- =============================================================
--  Unbounded anonymous newsletter signup.
--
--  subscribers has `subscribers_public_insert` (for insert to anon with check
--  (true)) plus `grant insert to anon`. The subscribe() server action rate-limits
--  and validates the email — but that guard is toothless, because anon can skip
--  the action entirely and POST /rest/v1/subscribers directly with the public
--  anon key: unlimited arbitrary rows (other people's emails, spam, table bloat).
--
--  Close the direct write path. subscribe() now inserts via supabaseAdmin()
--  (service_role, bypasses RLS), so the ONLY way to add a subscriber is through
--  the rate-limited, email-validated action. Drop the anon insert policy and
--  revoke the grant. Admin read/write policies are untouched.
--
--  Deploy app-first for zero gap: the new action uses service_role and works
--  whether or not this migration has run; running the migration then removes the
--  direct hole. (Migration-first briefly fails signups — the old anon insert is
--  denied — until the redeploy.)
-- =============================================================

drop policy if exists subscribers_public_insert on datarkar.subscribers;
revoke insert on datarkar.subscribers from anon;
-- authenticated keeps table access via the admin policies (is_admin()); its
-- insert is still gated by those, not by an open with-check.

-- ======== 20260806000004_tighten_admin_read_policies ========
-- =============================================================
--  Latent grant fragility: two "admin only" tables have a read policy that
--  checks NOTHING.
--
--  email_integration and affiliate_domains both carry
--    for select to authenticated using (true)
--  and are safe today only because neither table has a `grant select` to
--  authenticated, so PostgREST denies the read. The policy itself is wide open —
--  a future broad grant (or a `grant on all tables`) would instantly expose SMTP
--  test metadata and the affiliate allowlist to every logged-in user.
--
--  Move the guard into the policy where it belongs: gate on is_admin(). This only
--  tightens (fewer rows visible), so it can't break anything — admin reads that
--  need these rows already go through the service-role client (RLS bypass).
-- =============================================================

drop policy if exists "email_integration_authenticated_read" on datarkar.email_integration;
create policy "email_integration_authenticated_read"
  on datarkar.email_integration
  for select
  to authenticated
  using (datarkar.is_admin());

drop policy if exists affiliate_domains_authenticated_read on datarkar.affiliate_domains;
create policy affiliate_domains_authenticated_read
  on datarkar.affiliate_domains
  for select
  to authenticated
  using (datarkar.is_admin());

-- ======== 20260909000003_seo_audits ========
-- Public SEO + AI-visibility audit tool: job rows + analytics events.
-- All writes go through service-role in the server routes; there are no anon
-- policies, so the tables are not reachable via PostgREST from the browser.
-- A specific audit is read back by the server route using its unguessable uuid.

create table if not exists datarkar.seo_audits (
  id uuid primary key default gen_random_uuid(),
  url text not null,
  domain text not null,
  status text not null default 'queued',        -- queued|discovering|crawling|scoring|ready|analyzing|complete|failed
  progress int not null default 0,
  report_status text not null default 'free',    -- free|unlocked
  locked_at timestamptz,
  page_budget int not null default 12,
  crawl_cursor int not null default 0,
  urls jsonb not null default '[]'::jsonb,        -- discovered {url,class,priority}[]
  crawl_meta jsonb,                               -- {robotsTxt, sitemapUrls[], faviconPresent}
  pages jsonb not null default '[]'::jsonb,       -- crawled per-page signals
  scores jsonb,                                   -- {seo,ai,overall,color,categories}
  findings jsonb,                                 -- deterministic + (post-unlock) LLM findings
  report jsonb,                                   -- opportunities, topic map, action plan (post-unlock)
  email text,
  industry text,
  location text,
  page_count int,
  lead_score int,
  lead_bucket text,                               -- HOT|WARM|COLD
  crawl_ms int,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists seo_audits_domain_idx on datarkar.seo_audits (domain);
create index if not exists seo_audits_created_idx on datarkar.seo_audits (created_at desc);

create table if not exists datarkar.seo_audit_events (
  id bigint generated always as identity primary key,
  event text not null,                            -- audit_started|audit_completed|audit_failed|email_gate_viewed|email_submitted|report_generated|report_opened|cta_clicked
  audit_id uuid references datarkar.seo_audits(id) on delete set null,
  meta jsonb,
  created_at timestamptz not null default now()
);

create index if not exists seo_audit_events_audit_idx on datarkar.seo_audit_events (audit_id);

alter table datarkar.seo_audits enable row level security;
alter table datarkar.seo_audit_events enable row level security;
-- Intentionally no policies: service-role bypasses RLS; anon/auth get nothing.

-- ======== 20260912000001_services_copy_citability ========
-- Services copy: answer-first citability rewrite (description + deliverables + process).
-- MERGE-only via jsonb '||': outcome, tagline, seo, name, icon are left at their live
-- values. Idempotent — re-running just re-applies the same keys.
-- Also reconciles the SEO startingAt price drift: prod ₹1.5L -> ₹6,999 (repo value).
-- Manual: run in the prod Supabase SQL editor (services are DB-driven, not from code).

-- SEO price: ₹1.5L -> ₹6,999 / month (make 6999 the single source of truth).
update datarkar.services set data = jsonb_set(data, '{startingAt}', '"₹6,999 / month"') where slug = 'seo';

update datarkar.services set data = data || '{"description":"SEO & Organic Growth is the work of earning durable search visibility by building content as infrastructure, not chasing keywords one at a time. I build three compounding layers: topic clusters that establish authority on a subject, programmatic pages that scale coverage across a repeatable pattern, and an answer-first content system written to be cited by Google and by LLMs like ChatGPT and Perplexity.","deliverables":["A technical SEO audit that returns a prioritised plan for the issues blocking your indexing and rankings.","A topic-cluster architecture — one pillar page plus interlinked supporting articles — that reads to search engines as subject authority.","A programmatic SEO build-out wherever a repeatable page pattern (location, template, or comparison pages) can rank at scale.","Schema markup, internal linking, and GEO optimisation so Google and AI answer engines can parse and cite your pages."],"process":[{"step":"Audit","detail":"A 30-day technical and content crawl that produces a prioritised list of what''s broken and what''s winnable."},{"step":"Architect","detail":"Design the topic clusters and the programmatic layer around the queries worth owning."},{"step":"Build","detail":"Ship the pillar pages, supporting articles, and programmatic templates, with schema and internal links in place."},{"step":"Compound","detail":"Refresh, expand, and instrument on a monthly cadence so the system keeps gaining ground."}]}'::jsonb where slug = 'seo';
update datarkar.services set data = data || '{"description":"Performance Marketing is paid acquisition on Google and Meta, run as a tunable system rather than a monthly spend you hope works. I restructure the ad account around buyer intent, stand up a creative-testing pipeline, and rebuild the post-click landing pages — so every rupee of spend is measured against profit, not just clicks.","deliverables":["An account restructure that groups campaigns by buyer-intent tier, so budget follows the traffic most likely to convert.","A creative-testing system with a fixed weekly production cadence, so fresh ads ship on schedule instead of in scrambles.","Landing-page rebuilds for message-match and load speed — the two biggest post-click conversion levers.","A pragmatic attribution setup your team can actually trust when deciding where spend goes."],"process":[{"step":"Diagnose","detail":"Find the real bottleneck — usually the post-click experience, not the ad."},{"step":"Restructure","detail":"Rebuild the account around intent tiers and a clean testing matrix."},{"step":"Systematise","detail":"Turn creative into a weekly pipeline with a defined testing cadence."},{"step":"Scale","detail":"Increase spend only on the segments where the unit economics hold."}]}'::jsonb where slug = 'performance';
update datarkar.services set data = data || '{"description":"Content Strategy is the system that turns one serious idea into a month of distribution. I set editorial pillars tied to business outcomes, build a repurposing pipeline that splits each flagship piece into around twenty channel-ready assets, and enforce a QA rubric so nothing thin ships under your name.","deliverables":["An editorial strategy with content pillars mapped to business outcomes, not just topics.","A repurposing pipeline that turns one flagship piece into roughly twenty channel-specific assets.","An editorial QA rubric and brand-voice guide that keep quality and tone consistent across writers.","A distribution calendar that schedules each asset across your owned channels."],"process":[{"step":"Strategy","detail":"Define content pillars tied to revenue, not traffic vanity metrics."},{"step":"System","detail":"Stand up the production and QA pipeline your team will run."},{"step":"Distribute","detail":"Repurpose each idea and place it across every owned surface."},{"step":"Review","detail":"Cut what underperforms each month and double down on what works."}]}'::jsonb where slug = 'content';
update datarkar.services set data = data || '{"description":"AI Automation is the work of wiring AI into the specific tasks where it adds leverage — research, drafting, analysis, and operations — while keeping human judgement in the loop. I map your highest-leverage workflows, build them with quality gates so accuracy holds as volume grows, and hand your team a documented system they can run without me.","deliverables":["A workflow audit and automation roadmap that ranks tasks by leverage and risk.","Prompt libraries grounded in your brand voice and your own data, not generic templates.","Human-in-the-loop pipelines with QA gates that catch errors before they ship.","Team enablement and documentation so the system outlives the engagement."],"process":[{"step":"Map","detail":"Identify the highest-leverage, lowest-risk tasks to automate first."},{"step":"Build","detail":"Wire each workflow with explicit quality gates."},{"step":"Validate","detail":"Prove output quality holds before scaling volume."},{"step":"Enable","detail":"Document and hand over a system the team can operate."}]}'::jsonb where slug = 'ai-workflows';
update datarkar.services set data = data || '{"description":"Startup Advisory is hands-on, founder-to-founder guidance for early and growth-stage founders. Across bi-weekly working sessions we pick the one growth lever that matters this quarter — distribution, positioning, or the unglamorous systems that compound — and work it together, with async access between sessions for fast decisions.","deliverables":["Bi-weekly working sessions focused on the current quarter''s single biggest lever.","A growth and distribution strategy built around how your product actually reaches people.","A positioning and messaging review that sharpens how the market understands you.","Async access between sessions, so decisions don''t wait two weeks."],"process":[{"step":"Context","detail":"Understand the business and its real constraints before advising."},{"step":"Focus","detail":"Identify the one lever that matters most this quarter."},{"step":"Execute","detail":"Work that lever together, week over week."},{"step":"Compound","detail":"Build the system so the gains outlast the engagement."}]}'::jsonb where slug = 'advisory';
update datarkar.services set data = data || '{"description":"Speaking & Workshops are practical sessions on SEO, AI workflows, and founder-led growth, built on real experiments and outcomes rather than recycled theory. Each keynote or workshop is tailored to the audience and sends the room home with frameworks and templates they can apply on Monday.","deliverables":["A keynote or workshop tailored to your audience and the outcome you want.","Practical frameworks and takeaway templates the room keeps after the session.","A live Q&A plus follow-up resources for attendees.","Optional recording and repurposing rights for your team."],"process":[{"step":"Brief","detail":"Understand the audience and the outcome the session must deliver."},{"step":"Craft","detail":"Build the session around real, first-hand receipts."},{"step":"Deliver","detail":"Engage the room and leave them with usable systems."},{"step":"Extend","detail":"Provide resources and templates that outlast the talk."}]}'::jsonb where slug = 'speaking';

-- ======== 20261001000001_booking_attribution ========
-- Measurable consultation funnel: booking conversions + fuller paid attribution.
-- Target project: Shubham's OWN Supabase. NOT the BAS project.
-- Apply via your own project's SQL editor or `supabase db push`.

-- =====================================================================
-- 1. Extend contact attribution with the paid-click fields that make
--    Instagram Reels / Google Ads attribution possible.
-- =====================================================================
alter table datarkar.contacts
  add column if not exists utm_content text,
  add column if not exists utm_term    text,
  add column if not exists fbclid      text,
  add column if not exists gclid       text;

-- =====================================================================
-- 2. Consultation bookings. Written server-side by the bookasloth webhook
--    (service-role); admin reads. One row per completed booking, keyed by the
--    scheduler's own id so retries don't double-count.
-- =====================================================================
create table if not exists datarkar.bookings (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  external_id   text not null unique,        -- bookasloth booking id (idempotency)
  name          text,
  email         text,
  source        text,                        -- convenience: 'instagram', etc.
  utm_source    text,
  utm_medium    text,
  utm_campaign  text,
  utm_content   text,
  utm_term      text,
  fbclid        text,
  gclid         text,
  landing_page  text,
  referrer      text,
  ai_source     text,
  booked_at     timestamptz,                 -- when the call is scheduled for
  event_id      text,                        -- shared Pixel/CAPI dedup id
  raw           jsonb                         -- full webhook payload, for audit
);

create index if not exists bookings_created_at_idx on datarkar.bookings (created_at desc);
-- "how many bookings came from Instagram Reels?" → this index answers it fast.
create index if not exists bookings_utm_source_idx on datarkar.bookings (utm_source) where utm_source is not null;

alter table datarkar.bookings enable row level security;

-- Authenticated admin may read. No public/insert policy → writes are service-role only.
drop policy if exists "bookings_authenticated_read" on datarkar.bookings;
create policy "bookings_authenticated_read"
  on datarkar.bookings
  for select
  to authenticated
  using (true);

