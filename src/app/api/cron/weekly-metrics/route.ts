import { NextResponse } from "next/server";

import { recordWeeklySnapshot } from "@/lib/analytics/weekly";

/**
 * Weekly: snapshot last week's GA4 metrics into datarkar.metrics_weekly.
 * Vercel Cron hits this Monday 00:30 UTC (= 06:00 IST) with
 * `Authorization: Bearer ${CRON_SECRET}` — see vercel.json. Idempotent
 * (upsert on week_start), so a retry or manual re-run is safe.
 */
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    console.warn("[cron] CRON_SECRET not set; weekly-metrics disabled");
    return NextResponse.json({ error: "Cron not configured." }, { status: 503 });
  }
  if (request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const result = await recordWeeklySnapshot();
  if (!result.ok) {
    const code = result.reason === "ga4_not_configured" ? 503 : 500;
    console.error("[cron] weekly-metrics:", result.reason);
    return NextResponse.json({ ok: false, reason: result.reason }, { status: code });
  }
  return NextResponse.json(result);
}
