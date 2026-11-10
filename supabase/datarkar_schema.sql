-- ============================================================
-- Datarkar schema (CORE) — isolated schema 'datarkar'.
-- Scope: publishing + capture + commerce core ONLY.
-- DEFERRED to a later milestone: members/profiles/avatars/
-- onboarding/capabilities subsystem (build when that page is).
-- Run in Supabase SQL editor, then expose 'datarkar' in
-- Settings > API > Exposed schemas.
-- ============================================================
create schema if not exists datarkar;
grant usage on schema datarkar to anon, authenticated, service_role;

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

