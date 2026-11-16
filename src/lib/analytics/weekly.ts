import "server-only";

import { supabaseAdmin } from "@/lib/supabase/server";
import { fetchGa4Metrics, ga4Configured } from "./ga4";

export type WeeklyRow = {
  week_start: string;
  visitors: number;
  sessions: number;
  views: number;
  avg_time_s: number;
};

const iso = (d: Date) => d.toISOString().slice(0, 10);

/** Monday→Sunday of the most recently COMPLETED week, relative to `now`. */
export function lastCompleteWeek(now = new Date()): { start: string; end: string } {
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const dow = d.getUTCDay(); // 0=Sun..6=Sat
  const daysSinceMonday = (dow + 6) % 7; // Mon→0, Sun→6
  const thisMonday = new Date(d);
  thisMonday.setUTCDate(d.getUTCDate() - daysSinceMonday);
  const lastMonday = new Date(thisMonday);
  lastMonday.setUTCDate(thisMonday.getUTCDate() - 7);
  const lastSunday = new Date(lastMonday);
  lastSunday.setUTCDate(lastMonday.getUTCDate() + 6);
  return { start: iso(lastMonday), end: iso(lastSunday) };
}

/** The two most recent weekly snapshots (newest first). Empty on any error. */
export async function latestTwoSnapshots(): Promise<WeeklyRow[]> {
  try {
    const { data, error } = await supabaseAdmin()
      .from("metrics_weekly")
      .select("week_start,visitors,sessions,views,avg_time_s")
      .order("week_start", { ascending: false })
      .limit(2);
    if (error || !data) return [];
    return data as WeeklyRow[];
  } catch {
    return [];
  }
}

/** Read last week from GA4 and upsert its snapshot. Idempotent on week_start. */
export async function recordWeeklySnapshot(now = new Date()): Promise<
  { ok: true; week: string; visitors: number } | { ok: false; reason: string }
> {
  if (!ga4Configured()) return { ok: false, reason: "ga4_not_configured" };
  const { start, end } = lastCompleteWeek(now);
  const m = await fetchGa4Metrics(start, end);
  if (!m) return { ok: false, reason: "ga4_fetch_failed" };

  const { error } = await supabaseAdmin()
    .from("metrics_weekly")
    .upsert(
      { week_start: start, visitors: m.visitors, sessions: m.sessions, views: m.views, avg_time_s: m.avgTimeS, captured_at: now.toISOString() },
      { onConflict: "week_start" },
    );
  if (error) return { ok: false, reason: error.message };
  return { ok: true, week: start, visitors: m.visitors };
}
