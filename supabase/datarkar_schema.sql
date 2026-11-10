-- ============================================================
-- Datarkar schema (CORE) — generated from the LIVE old project
-- (oyzzgjrefkppqkxjccot) column introspection. Isolated schema
-- 'datarkar'. Self-contained: no cross-table FKs, no member
-- subsystem, no derived views. Run in SQL editor, then expose
-- 'datarkar' in Settings > API > Exposed schemas.
-- ============================================================
create extension if not exists pgcrypto;
create schema if not exists datarkar;
grant usage on schema datarkar to anon, authenticated, service_role;

create or replace function datarkar.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

-- ---- posts ----
create table if not exists datarkar.posts (
  "id" uuid default gen_random_uuid() not null,
  "slug" text not null,
  "title" text not null,
  "excerpt" text default '' not null,
  "category" text not null,
  "tags" text[] default '{}' not null,
  "words" integer default 0 not null,
  "featured" boolean default false not null,
  "body" jsonb not null,
  "status" text default 'draft' not null,
  "published_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "seo_title" text,
  "og_title" text,
  "og_description" text,
  primary key ("id")
);
alter table datarkar.posts enable row level security;
grant select, insert, update, delete on datarkar.posts to service_role;
grant select on datarkar.posts to anon, authenticated;
drop policy if exists posts_public_read on datarkar.posts;
create policy posts_public_read on datarkar.posts for select to anon, authenticated using (published_at is not null and published_at <= now());
create unique index if not exists posts_slug_uniq on datarkar.posts (slug) where slug is not null;
drop trigger if exists posts_touch on datarkar.posts;
create trigger posts_touch before update on datarkar.posts for each row execute function datarkar.touch_updated_at();

-- ---- services ----
create table if not exists datarkar.services (
  "id" uuid default gen_random_uuid() not null,
  "slug" text,
  "data" jsonb not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.services enable row level security;
grant select, insert, update, delete on datarkar.services to service_role;
grant select on datarkar.services to anon, authenticated;
drop policy if exists services_public_read on datarkar.services;
create policy services_public_read on datarkar.services for select to anon, authenticated using (published);
create unique index if not exists services_slug_uniq on datarkar.services (slug) where slug is not null;
drop trigger if exists services_touch on datarkar.services;
create trigger services_touch before update on datarkar.services for each row execute function datarkar.touch_updated_at();

-- ---- case_studies ----
create table if not exists datarkar.case_studies (
  "id" uuid default gen_random_uuid() not null,
  "slug" text,
  "data" jsonb not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.case_studies enable row level security;
grant select, insert, update, delete on datarkar.case_studies to service_role;
grant select on datarkar.case_studies to anon, authenticated;
drop policy if exists case_studies_public_read on datarkar.case_studies;
create policy case_studies_public_read on datarkar.case_studies for select to anon, authenticated using (published);
create unique index if not exists case_studies_slug_uniq on datarkar.case_studies (slug) where slug is not null;
drop trigger if exists case_studies_touch on datarkar.case_studies;
create trigger case_studies_touch before update on datarkar.case_studies for each row execute function datarkar.touch_updated_at();

-- ---- products ----
create table if not exists datarkar.products (
  "id" uuid default gen_random_uuid() not null,
  "slug" text,
  "data" jsonb not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.products enable row level security;
grant select, insert, update, delete on datarkar.products to service_role;
grant select on datarkar.products to anon, authenticated;
drop policy if exists products_public_read on datarkar.products;
create policy products_public_read on datarkar.products for select to anon, authenticated using (published);
create unique index if not exists products_slug_uniq on datarkar.products (slug) where slug is not null;
drop trigger if exists products_touch on datarkar.products;
create trigger products_touch before update on datarkar.products for each row execute function datarkar.touch_updated_at();

-- ---- testimonials ----
create table if not exists datarkar.testimonials (
  "id" uuid default gen_random_uuid() not null,
  "slug" text,
  "data" jsonb not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.testimonials enable row level security;
grant select, insert, update, delete on datarkar.testimonials to service_role;
grant select on datarkar.testimonials to anon, authenticated;
drop policy if exists testimonials_public_read on datarkar.testimonials;
create policy testimonials_public_read on datarkar.testimonials for select to anon, authenticated using (published);
create unique index if not exists testimonials_slug_uniq on datarkar.testimonials (slug) where slug is not null;
drop trigger if exists testimonials_touch on datarkar.testimonials;
create trigger testimonials_touch before update on datarkar.testimonials for each row execute function datarkar.touch_updated_at();

-- ---- projects ----
create table if not exists datarkar.projects (
  "id" uuid default gen_random_uuid() not null,
  "slug" text,
  "data" jsonb not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.projects enable row level security;
grant select, insert, update, delete on datarkar.projects to service_role;
grant select on datarkar.projects to anon, authenticated;
drop policy if exists projects_public_read on datarkar.projects;
create policy projects_public_read on datarkar.projects for select to anon, authenticated using (published);
create unique index if not exists projects_slug_uniq on datarkar.projects (slug) where slug is not null;
drop trigger if exists projects_touch on datarkar.projects;
create trigger projects_touch before update on datarkar.projects for each row execute function datarkar.touch_updated_at();

-- ---- subscribers ----
create table if not exists datarkar.subscribers (
  "id" uuid default gen_random_uuid() not null,
  "email" text not null,
  "source" text,
  "status" text default 'active' not null,
  "created_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.subscribers enable row level security;
grant select, insert, update, delete on datarkar.subscribers to service_role;

-- ---- newsletter_subscribers ----
create table if not exists datarkar.newsletter_subscribers (
  "id" uuid default gen_random_uuid() not null,
  "email" text not null,
  "name" text,
  "status" text default 'active',
  "subscribed_at" timestamp with time zone default now(),
  "source" text,
  primary key ("id")
);
alter table datarkar.newsletter_subscribers enable row level security;
grant select, insert, update, delete on datarkar.newsletter_subscribers to service_role;

-- ---- contacts ----
create table if not exists datarkar.contacts (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "name" text not null,
  "email" text not null,
  "project_type" text,
  "budget" text,
  "message" text not null,
  "status" text default 'new' not null,
  "notified" boolean default false not null,
  "first_landing_page" text,
  "referrer" text,
  "ai_source" text,
  "utm_source" text,
  "utm_medium" text,
  "utm_campaign" text,
  "pages_seen" integer,
  "utm_content" text,
  "utm_term" text,
  "fbclid" text,
  "gclid" text,
  primary key ("id")
);
alter table datarkar.contacts enable row level security;
grant select, insert, update, delete on datarkar.contacts to service_role;

-- ---- supports ----
create table if not exists datarkar.supports (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "name" text,
  "email" text not null,
  "message" text,
  "coffee_units" integer default 0 not null,
  "toffee_units" integer default 0 not null,
  "currency" text default 'INR' not null,
  "base_amount" numeric not null,
  "fee_amount" numeric default 0 not null,
  "total_amount" numeric not null,
  "covers_fee" boolean default true not null,
  "anonymous" boolean default false not null,
  "status" text default 'pending' not null,
  "razorpay_order_id" text,
  "razorpay_payment_id" text,
  primary key ("id")
);
alter table datarkar.supports enable row level security;
grant select, insert, update, delete on datarkar.supports to service_role;

-- ---- support_updates ----
create table if not exists datarkar.support_updates (
  "id" uuid default gen_random_uuid() not null,
  "code" text not null,
  "type" text not null,
  "body" text default '' not null,
  "media" jsonb not null,
  "author" jsonb,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.support_updates enable row level security;
grant select, insert, update, delete on datarkar.support_updates to service_role;
drop trigger if exists support_updates_touch on datarkar.support_updates;
create trigger support_updates_touch before update on datarkar.support_updates for each row execute function datarkar.touch_updated_at();

-- ---- support_comments ----
create table if not exists datarkar.support_comments (
  "id" uuid default gen_random_uuid() not null,
  "update_code" text not null,
  "parent_id" uuid,
  "name" text not null,
  "email" text not null,
  "tier" text,
  "body" text not null,
  "created_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.support_comments enable row level security;
grant select, insert, update, delete on datarkar.support_comments to service_role;

-- ---- support_settings ----
create table if not exists datarkar.support_settings (
  "id" integer default 1 not null,
  "thankyou_images" jsonb not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.support_settings enable row level security;
grant select, insert, update, delete on datarkar.support_settings to service_role;
drop trigger if exists support_settings_touch on datarkar.support_settings;
create trigger support_settings_touch before update on datarkar.support_settings for each row execute function datarkar.touch_updated_at();

-- ---- comment_verifications ----
create table if not exists datarkar.comment_verifications (
  "email" text not null,
  "code_hash" text not null,
  "expires_at" timestamp with time zone not null,
  "attempts" integer default 0 not null,
  "last_sent_at" timestamp with time zone default now() not null,
  "created_at" timestamp with time zone default now() not null,
  primary key ("email")
);
alter table datarkar.comment_verifications enable row level security;
grant select, insert, update, delete on datarkar.comment_verifications to service_role;

-- ---- bookings ----
create table if not exists datarkar.bookings (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "external_id" text not null,
  "name" text,
  "email" text,
  "source" text,
  "utm_source" text,
  "utm_medium" text,
  "utm_campaign" text,
  "utm_content" text,
  "utm_term" text,
  "fbclid" text,
  "gclid" text,
  "landing_page" text,
  "referrer" text,
  "ai_source" text,
  "booked_at" timestamp with time zone,
  "event_id" text,
  "raw" jsonb,
  primary key ("id")
);
alter table datarkar.bookings enable row level security;
grant select, insert, update, delete on datarkar.bookings to service_role;

-- ---- links ----
create table if not exists datarkar.links (
  "id" uuid default gen_random_uuid() not null,
  "category_id" uuid not null,
  "title" text not null,
  "url" text not null,
  "color" text default '#ffffff' not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.links enable row level security;
grant select, insert, update, delete on datarkar.links to service_role;
grant select on datarkar.links to anon, authenticated;
drop policy if exists links_public_read on datarkar.links;
create policy links_public_read on datarkar.links for select to anon, authenticated using (true);
drop trigger if exists links_touch on datarkar.links;
create trigger links_touch before update on datarkar.links for each row execute function datarkar.touch_updated_at();

-- ---- link_categories ----
create table if not exists datarkar.link_categories (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "slug" text not null,
  "sort" integer default 0 not null,
  "published" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.link_categories enable row level security;
grant select, insert, update, delete on datarkar.link_categories to service_role;
grant select on datarkar.link_categories to anon, authenticated;
drop policy if exists link_categories_public_read on datarkar.link_categories;
create policy link_categories_public_read on datarkar.link_categories for select to anon, authenticated using (true);
create unique index if not exists link_categories_slug_uniq on datarkar.link_categories (slug) where slug is not null;
drop trigger if exists link_categories_touch on datarkar.link_categories;
create trigger link_categories_touch before update on datarkar.link_categories for each row execute function datarkar.touch_updated_at();

-- ---- seo_audits ----
create table if not exists datarkar.seo_audits (
  "id" uuid default gen_random_uuid() not null,
  "url" text not null,
  "domain" text not null,
  "status" text default 'queued' not null,
  "progress" integer default 0 not null,
  "report_status" text default 'free' not null,
  "locked_at" timestamp with time zone,
  "page_budget" integer default 12 not null,
  "crawl_cursor" integer default 0 not null,
  "urls" jsonb not null,
  "crawl_meta" jsonb,
  "pages" jsonb not null,
  "scores" jsonb,
  "findings" jsonb,
  "report" jsonb,
  "email" text,
  "industry" text,
  "location" text,
  "page_count" integer,
  "lead_score" integer,
  "lead_bucket" text,
  "crawl_ms" integer,
  "error" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.seo_audits enable row level security;
grant select, insert, update, delete on datarkar.seo_audits to service_role;
drop trigger if exists seo_audits_touch on datarkar.seo_audits;
create trigger seo_audits_touch before update on datarkar.seo_audits for each row execute function datarkar.touch_updated_at();

-- ---- seo_audit_events ----
create table if not exists datarkar.seo_audit_events (
  "id" bigint not null,
  "event" text not null,
  "audit_id" uuid,
  "meta" jsonb,
  "created_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.seo_audit_events enable row level security;
grant select, insert, update, delete on datarkar.seo_audit_events to service_role;

-- ---- short_link ----
create table if not exists datarkar.short_link (
  "slug" text not null,
  "target_url" text not null,
  "clicks" integer default 0 not null,
  "created_at" timestamp with time zone default now() not null,
  primary key ("slug")
);
alter table datarkar.short_link enable row level security;
grant select, insert, update, delete on datarkar.short_link to service_role;
create unique index if not exists short_link_slug_uniq on datarkar.short_link (slug) where slug is not null;

-- ---- announcements ----
create table if not exists datarkar.announcements (
  "id" uuid default gen_random_uuid() not null,
  "message" text not null,
  "href" text,
  "active" boolean default false not null,
  "starts_at" timestamp with time zone default now() not null,
  "ends_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  primary key ("id")
);
alter table datarkar.announcements enable row level security;
grant select, insert, update, delete on datarkar.announcements to service_role;
grant select on datarkar.announcements to anon, authenticated;
drop policy if exists announcements_public_read on datarkar.announcements;
create policy announcements_public_read on datarkar.announcements for select to anon, authenticated using (true);

-- ---- site_settings ----
create table if not exists datarkar.site_settings (
  "key" text not null,
  "value" jsonb not null,
  "updated_at" timestamp with time zone default now(),
  primary key ("key")
);
alter table datarkar.site_settings enable row level security;
grant select, insert, update, delete on datarkar.site_settings to service_role;
grant select on datarkar.site_settings to anon, authenticated;
drop policy if exists site_settings_public_read on datarkar.site_settings;
create policy site_settings_public_read on datarkar.site_settings for select to anon, authenticated using (true);
drop trigger if exists site_settings_touch on datarkar.site_settings;
create trigger site_settings_touch before update on datarkar.site_settings for each row execute function datarkar.touch_updated_at();

-- ---- tags ----
create table if not exists datarkar.tags (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "slug" text not null,
  primary key ("id")
);
alter table datarkar.tags enable row level security;
grant select, insert, update, delete on datarkar.tags to service_role;
create unique index if not exists tags_slug_uniq on datarkar.tags (slug) where slug is not null;

-- service_role bypasses RLS for all writes (admin + API routes use it).