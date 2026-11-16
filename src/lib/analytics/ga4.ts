import "server-only";

import { BetaAnalyticsDataClient } from "@google-analytics/data";

/**
 * GA4 Data API reader. Reads a service account from env — nothing is committed.
 *
 * Required env (set in Vercel + .env.local):
 *   GA4_PROPERTY_ID   — numeric GA4 property id (e.g. "123456789")
 *   GA4_SA_JSON       — the full service-account JSON (one line), OR
 *   GA4_CLIENT_EMAIL + GA4_PRIVATE_KEY — the two fields on their own
 *
 * The service account must be added as a Viewer on the GA4 property.
 */
export type Metrics = {
  visitors: number;
  sessions: number;
  views: number;
  avgTimeS: number;
};

function credentials(): { client_email: string; private_key: string } | null {
  const raw = process.env.GA4_SA_JSON;
  if (raw) {
    try {
      const j = JSON.parse(raw) as { client_email?: string; private_key?: string };
      if (j.client_email && j.private_key) {
        return { client_email: j.client_email, private_key: j.private_key.replace(/\\n/g, "\n") };
      }
    } catch {
      /* fall through */
    }
  }
  const email = process.env.GA4_CLIENT_EMAIL;
  const key = process.env.GA4_PRIVATE_KEY;
  if (email && key) return { client_email: email, private_key: key.replace(/\\n/g, "\n") };
  return null;
}

export function ga4Configured(): boolean {
  return Boolean(process.env.GA4_PROPERTY_ID && credentials());
}

/** Pull core metrics for a date range (YYYY-MM-DD, inclusive). Null if unconfigured/failed. */
export async function fetchGa4Metrics(startDate: string, endDate: string): Promise<Metrics | null> {
  const propertyId = process.env.GA4_PROPERTY_ID;
  const creds = credentials();
  if (!propertyId || !creds) return null;

  try {
    const client = new BetaAnalyticsDataClient({ credentials: creds });
    const [report] = await client.runReport({
      property: `properties/${propertyId}`,
      dateRanges: [{ startDate, endDate }],
      metrics: [
        { name: "totalUsers" },
        { name: "sessions" },
        { name: "screenPageViews" },
        { name: "averageSessionDuration" },
      ],
    });
    const row = report.rows?.[0]?.metricValues;
    if (!row) return { visitors: 0, sessions: 0, views: 0, avgTimeS: 0 };
    const n = (i: number) => Number(row[i]?.value ?? 0) || 0;
    return { visitors: Math.round(n(0)), sessions: Math.round(n(1)), views: Math.round(n(2)), avgTimeS: n(3) };
  } catch (e) {
    console.error("[ga4] runReport failed:", (e as Error).message);
    return null;
  }
}
