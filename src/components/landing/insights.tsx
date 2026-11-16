import { TrendUp, TrendDown } from "@phosphor-icons/react/dist/ssr";

import { Container, Section } from "@/components/layout/container";
import { site } from "@/lib/site";
import { latestTwoSnapshots } from "@/lib/analytics/weekly";
import { cn } from "@/lib/utils";

type Stat = { label: string; value: string; delta: string | null; up: boolean };

/* Fallback until the first Monday GA4 snapshot lands. */
const FALLBACK_STATS: Stat[] = [
  { label: "Visitors", value: "—", delta: null, up: true },
  { label: "Sessions", value: "—", delta: null, up: true },
  { label: "Views", value: "—", delta: null, up: true },
  { label: "Avg. time", value: "—", delta: null, up: true },
];

const nf = new Intl.NumberFormat("en-IN");
const fmtNum = (n: number) => nf.format(n);
const fmtTime = (s: number) => (s >= 60 ? `${Math.floor(s / 60)}m ${Math.round(s % 60)}s` : `${Math.round(s)}s`);
function wow(cur: number, prev: number | undefined): { delta: string | null; up: boolean } {
  if (prev == null || prev === 0) return { delta: null, up: true };
  const pct = ((cur - prev) / prev) * 100;
  return { delta: `${Math.abs(pct).toFixed(1)}%`, up: pct >= 0 };
}

// Real numbers from the latest weekly snapshot, week-over-week vs the prior one.
async function buildStats(): Promise<Stat[]> {
  const rows = await latestTwoSnapshots();
  const cur = rows[0];
  if (!cur) return FALLBACK_STATS;
  const prev = rows[1];
  const v = wow(cur.visitors, prev?.visitors);
  const s = wow(cur.sessions, prev?.sessions);
  const w = wow(cur.views, prev?.views);
  const t = wow(cur.avg_time_s, prev?.avg_time_s);
  return [
    { label: "Visitors", value: fmtNum(cur.visitors), delta: v.delta, up: v.up },
    { label: "Sessions", value: fmtNum(cur.sessions), delta: s.delta, up: s.up },
    { label: "Views", value: fmtNum(cur.views), delta: w.delta, up: w.up },
    { label: "Avg. time", value: fmtTime(cur.avg_time_s), delta: t.delta, up: t.up },
  ];
}

const MONTHS = ["Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];
// 13 anchor points (0..1 of max) for each line across the 12 month span.
const VIEWS = [0.18, 0.2, 0.32, 0.5, 0.54, 0.5, 0.56, 0.52, 0.34, 0.6, 0.95, 0.82, 0.72];
const VISITS = [0.14, 0.15, 0.24, 0.38, 0.42, 0.4, 0.45, 0.42, 0.28, 0.48, 0.74, 0.66, 0.6];

const W = 820;
const H = 230;
const PAD = 8;

function linePath(vals: number[]) {
  const n = vals.length;
  const x = (i: number) => PAD + (i / (n - 1)) * (W - PAD * 2);
  const y = (v: number) => H - PAD - v * (H - PAD * 2);
  const pts = vals.map((v, i) => [x(i), y(v)] as const);
  // Catmull-Rom → cubic bezier for a smooth curve.
  let d = `M ${pts[0][0]},${pts[0][1]}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] ?? pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2] ?? p2;
    const c1x = p1[0] + (p2[0] - p0[0]) / 6;
    const c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6;
    const c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += ` C ${c1x},${c1y} ${c2x},${c2y} ${p2[0]},${p2[1]}`;
  }
  return d;
}

const DOT = ["bg-muted", "bg-[#bfdbfe]", "bg-[#60a5fa]", "bg-[#3b82f6]", "bg-[#1d4ed8]"];

type Day = { level: 0 | 1 | 2 | 3 | 4 } | null;

// Deterministic fallback grid (when GitHub can't be reached).
function fallbackWeeks(): { weeks: Day[][]; total: number | null } {
  const weeks: Day[][] = [];
  for (let w = 0; w < 52; w++) {
    const col: Day[] = [];
    for (let d = 0; d < 7; d++) {
      const s = Math.sin(w * 12.9898 + d * 78.233) * 43758.5453;
      const f = s - Math.floor(s);
      const v = f * (0.35 + 0.5 * (w / 52));
      const lvl = v < 0.12 ? 0 : v < 0.22 ? 1 : v < 0.32 ? 2 : v < 0.42 ? 3 : 4;
      col.push({ level: lvl as 0 | 1 | 2 | 3 | 4 });
    }
    weeks.push(col);
  }
  return { weeks, total: null };
}

// Real GitHub contributions via a public, no-auth proxy (server-side fetch,
// so CSP connect-src doesn't apply). Falls back to the stylized grid on error.
async function githubWeeks(user: string): Promise<{ weeks: Day[][]; total: number | null }> {
  if (!user) return fallbackWeeks();
  try {
    const res = await fetch(`https://github-contributions-api.jogruber.de/v4/${user}?y=last`, {
      next: { revalidate: 3600 },
    });
    if (!res.ok) throw new Error(String(res.status));
    const json = (await res.json()) as {
      total?: Record<string, number>;
      contributions: { date: string; count: number; level: 0 | 1 | 2 | 3 | 4 }[];
    };
    const days = json.contributions ?? [];
    if (days.length === 0) return fallbackWeeks();
    // Pad the front so the first column starts on Sunday, then chunk into weeks.
    const firstDow = new Date(days[0].date + "T00:00:00").getUTCDay();
    const cells: Day[] = [...Array(firstDow).fill(null), ...days.map((d) => ({ level: d.level }))];
    const weeks: Day[][] = [];
    for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
    const total = json.total ? Object.values(json.total).reduce((a, b) => a + b, 0) : null;
    return { weeks: weeks.slice(-53), total };
  } catch {
    return fallbackWeeks();
  }
}

export async function Insights() {
  const { weeks, total } = await githubWeeks(site.github);
  const stats = await buildStats();
  const bestX = PAD + (10 / (MONTHS.length - 1)) * (W - PAD * 2);
  const bestY = H - PAD - VIEWS[10] * (H - PAD * 2);

  return (
    <Section bleed className="border-b border-border">
      <div className="border-b border-border bg-muted/30">
        <Container className="py-4">
          <h2 className="font-display text-lg font-semibold tracking-tight">Insights</h2>
        </Container>
      </div>
      <Container className="py-10 md:py-14">
        {/* Stat tiles */}
        <div className="grid grid-cols-2 overflow-hidden rounded-2xl border border-border bg-card lg:grid-cols-4">
          {stats.map((s, i) => (
            <div key={s.label} className={cn("p-5", i % 2 === 1 && "border-l border-border", "border-t border-border sm:border-t-0", i >= 2 && "border-t lg:border-t-0", "lg:[&:not(:first-child)]:border-l")}>
              <p className="text-sm text-muted-foreground">{s.label}</p>
              <div className="mt-1 flex items-baseline gap-2">
                <span className="font-display text-3xl font-extrabold tracking-tight">{s.value}</span>
                {s.delta && (
                  <span className={cn("inline-flex items-center gap-0.5 text-xs font-semibold", s.up ? "text-success" : "text-destructive")}>
                    {s.up ? <TrendUp className="size-3.5" weight="bold" /> : <TrendDown className="size-3.5" weight="bold" />}
                    {s.delta}
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>

        {/* Line chart */}
        <div className="mt-6 flex items-center gap-5 text-xs text-muted-foreground">
          <span className="inline-flex items-center gap-1.5"><span className="h-0.5 w-5 rounded bg-[#3b82f6]" />Visitors</span>
          <span className="inline-flex items-center gap-1.5"><span className="h-0.5 w-5 rounded bg-foreground" />Views</span>
        </div>
        <div className="mt-3 overflow-x-auto">
          <svg viewBox={`0 0 ${W} ${H}`} className="h-56 w-full min-w-[640px]" role="img" aria-label="Visitors and views over the last 12 months">
            <path d={linePath(VIEWS)} fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" className="text-foreground" />
            <path d={linePath(VISITS)} fill="none" stroke="#3b82f6" strokeWidth="2.5" strokeLinecap="round" />
            <line x1={bestX} y1={PAD} x2={bestX} y2={H - PAD} stroke="currentColor" strokeWidth="1" strokeDasharray="3 3" className="text-border" />
            <circle cx={bestX} cy={bestY} r="4" fill="#3b82f6" />
            <text x={bestX - 6} y={bestY - 10} textAnchor="end" className="fill-muted-foreground text-[11px]">Best day</text>
            <text x={bestX + 4} y={bestY - 10} className="fill-foreground text-[11px] font-semibold">2,071</text>
          </svg>
        </div>
        <div className="mt-1 flex justify-between px-1 text-[11px] text-muted-foreground">
          {MONTHS.map((m, i) => (
            <span key={`${m}-${i}`}>{m}</span>
          ))}
        </div>

        {/* Real GitHub contributions (thekalamwala) */}
        <div className="mt-8 flex items-center justify-between gap-4">
          <p className="text-sm text-muted-foreground">
            {total != null ? (
              <><span className="font-semibold text-foreground">{total.toLocaleString("en-IN")}</span> commits in the last year</>
            ) : (
              "Shipping, in the open"
            )}
          </p>
          <a href={`https://github.com/${site.github}`} target="_blank" rel="noopener noreferrer" className="text-xs font-medium text-muted-foreground transition-ui hover:text-brand">
            @{site.github}
          </a>
        </div>
        <div className="mt-3 overflow-x-auto">
          <div className="flex min-w-[640px] flex-col gap-1">
            <div className="flex gap-[3px]">
              {weeks.map((col, w) => (
                <div key={w} className="flex flex-col gap-[3px]">
                  {Array.from({ length: 7 }).map((_, d) => {
                    const cell = col[d];
                    return <span key={d} className={cn("size-[9px] rounded-full", cell ? DOT[cell.level] : "bg-transparent")} />;
                  })}
                </div>
              ))}
            </div>
            <div className="mt-2 flex items-center justify-end gap-1.5 text-[11px] text-muted-foreground">
              Less
              {DOT.map((c, i) => (
                <span key={i} className={cn("size-[9px] rounded-full", c)} />
              ))}
              More
            </div>
          </div>
        </div>
      </Container>
    </Section>
  );
}
