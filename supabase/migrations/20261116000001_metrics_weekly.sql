-- Weekly analytics snapshots for the homepage "Insights" tiles.
-- One row per measured week (Mon–Sun), written by the Monday 06:00 IST cron
-- (/api/cron/weekly-metrics) from the GA4 Data API. Read server-side via
-- supabaseAdmin(), which targets the `datarkar` schema — so the table lives
-- there, not in public.

create schema if not exists datarkar;

create table if not exists datarkar.metrics_weekly (
  id          uuid primary key default gen_random_uuid(),
  week_start  date not null unique,              -- Monday of the measured week
  visitors    integer not null default 0,
  sessions    integer not null default 0,
  views       integer not null default 0,
  avg_time_s  numeric(10, 2) not null default 0, -- average session duration, seconds
  captured_at timestamptz not null default now()
);

create index if not exists metrics_weekly_captured_idx
  on datarkar.metrics_weekly (week_start desc);

-- Service-role only: the cron writes it and server reads it with supabaseAdmin()
-- (RLS-bypass). No anon/authenticated access — these numbers surface through
-- the server component, never the public API.
grant usage on schema datarkar to service_role;
grant select, insert, update on datarkar.metrics_weekly to service_role;
