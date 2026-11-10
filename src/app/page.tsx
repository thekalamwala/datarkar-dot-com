import Link from "next/link";
import { ArrowUpRight, ArrowRight, Play } from "lucide-react";

import { buildMetadata } from "@/lib/seo";
import { site, companies, socials, statusTone } from "@/lib/site";
import { getPublishedPosts } from "@/lib/blog/queries";

import { Container, Section } from "@/components/layout/container";
import { Reveal } from "@/components/motion/reveal";
import { buttonVariants } from "@/components/ui/button";
import { NewsletterForm } from "@/components/sections/newsletter-form";
import { cn } from "@/lib/utils";

export const metadata = buildMetadata({
  path: "/",
  titleAbsolute: true,
  description:
    "Shubham Datarkar — founder and product builder. I build software products and internet businesses, then market what I build. Building in public, writing it down.",
  ogTitle: "The builder who markets, the marketer who builds",
  ogDescription:
    "Founder, product builder and marketer. What I'm building, and how I think about building it.",
});

export const revalidate = 300;

const pill = "rounded-full";

const fmtDate = (iso: string) =>
  iso ? new Date(iso).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" }) : "";

function Eyebrow({ label }: { label: string }) {
  return (
    <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
      {label}
    </p>
  );
}

export default async function HomePage() {
  const posts = await getPublishedPosts().catch(() => []);
  const latest = posts.slice(0, 3);
  const socialLinks = socials.filter((s) => s.href !== site.bookingUrl);

  return (
    <>
      {/* ───────────── Hero ───────────── */}
      <Section
        bleed
        className="relative overflow-hidden border-b border-border bg-[radial-gradient(70%_55%_at_50%_-5%,color-mix(in_oklab,var(--brand)_9%,transparent),transparent_70%)]"
      >
        <Container className="py-20 md:py-28">
          <Reveal>
            <Eyebrow label={`${site.name} — ${site.location}`} />
          </Reveal>
          <Reveal delay={0.05}>
            <h1 className="mt-6 max-w-4xl text-balance font-display text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-6xl md:text-7xl">
              I build businesses,
              <br className="hidden sm:block" /> products and brands —
              <br className="hidden sm:block" /> then <span className="text-brand">market what I build.</span>
            </h1>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="mt-8 max-w-2xl text-lg leading-relaxed text-muted-foreground">
              Founder and product builder. I ship software, run internet experiments, and work
              across product, marketing and SEO — building in public and writing down what I learn.
            </p>
          </Reveal>
          <Reveal delay={0.15}>
            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <Link href="/projects" className={cn(buttonVariants({ size: "lg" }), pill)}>
                See what I&rsquo;m building
                <ArrowRight className="size-4" />
              </Link>
              <Link href="/blog" className={cn(buttonVariants({ variant: "outline", size: "lg" }), pill)}>
                Read the writing
              </Link>
            </div>
          </Reveal>
          <Reveal delay={0.2}>
            <div className="mt-8 flex flex-wrap items-center gap-2">
              {socialLinks.map((s) => (
                <a
                  key={s.label}
                  href={s.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="rounded-full border border-border px-3.5 py-1.5 text-sm font-medium text-muted-foreground transition-ui hover:border-brand/40 hover:text-brand"
                >
                  {s.label}
                </a>
              ))}
            </div>
          </Reveal>
          <Reveal delay={0.25}>
            <p className="mt-8 inline-flex items-center gap-2 rounded-full border border-border bg-card/60 px-3.5 py-1.5 text-sm font-medium shadow-sm">
              <span className="size-2 rounded-full bg-brand" aria-hidden />
              Currently building <span className="font-semibold">Meeticulous</span> — an AI-powered appointment booking app.
            </p>
          </Reveal>
        </Container>
      </Section>

      {/* ───────────── Building (breadth) ───────────── */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="flex items-end justify-between gap-4">
            <div>
              <Eyebrow label="Building" />
              <h2 className="mt-2 font-display text-2xl font-bold tracking-tight sm:text-3xl">
                Everything I&rsquo;m building
              </h2>
            </div>
            <Link
              href="/projects"
              className="hidden shrink-0 items-center gap-1 text-sm font-medium transition-ui hover:text-brand sm:inline-flex"
            >
              Full index <ArrowUpRight className="size-4" />
            </Link>
          </div>

          <ol className="mt-8 flex flex-col gap-1">
            {companies.map((c, i) => {
              const hasUrl = "url" in c && Boolean(c.url);
              const Row = (
                <div className="group grid grid-cols-[2rem_1fr] items-start gap-4 rounded-2xl px-3 py-4 transition-ui hover:bg-muted/50 sm:grid-cols-[2.5rem_1fr_auto] sm:items-center">
                  <span className="font-display text-sm font-bold text-muted-foreground">
                    {String(i + 1).padStart(2, "0")}
                  </span>
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                      <h3 className="font-display text-lg font-bold tracking-tight group-hover:text-brand sm:text-xl">
                        {c.name}
                      </h3>
                      <span
                        className={cn(
                          "rounded-full border px-2.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide",
                          statusTone[c.status] ?? statusTone.Idea,
                        )}
                      >
                        {c.status}
                      </span>
                      <span className="text-xs text-muted-foreground">{c.kind}</span>
                    </div>
                    <p className="mt-1.5 max-w-xl text-sm leading-relaxed text-muted-foreground">{c.blurb}</p>
                  </div>
                  {hasUrl ? (
                    <ArrowUpRight className="col-start-2 size-5 text-muted-foreground transition-ui group-hover:text-brand sm:col-start-3" />
                  ) : (
                    <span className="col-start-2 hidden sm:col-start-3 sm:block" />
                  )}
                </div>
              );
              return (
                <li key={c.name}>
                  {hasUrl ? (
                    <a href={(c as { url: string }).url} target="_blank" rel="noopener noreferrer" className="block">
                      {Row}
                    </a>
                  ) : (
                    Row
                  )}
                </li>
              );
            })}
          </ol>
        </Container>
      </Section>

      {/* ───────────── Writing ───────────── */}
      <Section bleed className="border-b border-border bg-card">
        <Container className="py-16 md:py-24">
          <div className="flex items-end justify-between gap-4">
            <div>
              <Eyebrow label="Writing" />
              <h2 className="mt-2 font-display text-2xl font-bold tracking-tight sm:text-3xl">Thinking out loud</h2>
            </div>
            <Link
              href="/blog"
              className="hidden shrink-0 items-center gap-1 text-sm font-medium transition-ui hover:text-brand sm:inline-flex"
            >
              All writing <ArrowUpRight className="size-4" />
            </Link>
          </div>

          {latest.length > 0 ? (
            <ul className="mt-8 flex flex-col gap-1">
              {latest.map((p) => (
                <li key={p.slug}>
                  <Link
                    href={`/blog/${p.category}/${p.slug}`}
                    className="group flex items-baseline justify-between gap-4 rounded-2xl px-3 py-4 transition-ui hover:bg-muted/50"
                  >
                    <span className="min-w-0">
                      <span className="block font-display text-lg font-semibold tracking-tight group-hover:text-brand">
                        {p.title}
                      </span>
                      {p.excerpt && (
                        <span className="mt-1 line-clamp-1 block text-sm text-muted-foreground">{p.excerpt}</span>
                      )}
                    </span>
                    <span className="shrink-0 text-xs text-muted-foreground">{fmtDate(p.date)}</span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-8 max-w-xl rounded-2xl border border-border bg-background/60 p-5 text-muted-foreground">
              Essays on building products, marketing, and SEO — the first ones land soon.{" "}
              <Link href="/newsletter" className="font-medium text-foreground underline-offset-4 hover:underline">
                Get them by email
              </Link>
              .
            </p>
          )}
        </Container>
      </Section>

      {/* ───────────── Watch (YouTube) ───────────── */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <Eyebrow label="Watch" />
          <div className="mt-6 flex flex-col items-start justify-between gap-6 sm:flex-row sm:items-end">
            <h2 className="max-w-xl font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
              Build logs, teardowns and the occasional rant — on YouTube.
            </h2>
            <a
              href={site.youtubeUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={cn(buttonVariants({ size: "lg" }), pill, "shrink-0")}
            >
              <Play className="size-4 fill-current" />
              Watch on YouTube
            </a>
          </div>
        </Container>
      </Section>

      {/* ───────────── GitHub activity (only when handle set) ───────────── */}
      {site.github ? (
        <Section bleed className="border-b border-border bg-card">
          <Container className="py-16 md:py-24">
            <div className="flex items-end justify-between gap-4">
              <div>
                <Eyebrow label="In the open" />
                <h2 className="mt-2 font-display text-2xl font-bold tracking-tight sm:text-3xl">Shipping, publicly</h2>
              </div>
              <a
                href={`https://github.com/${site.github}`}
                target="_blank"
                rel="noopener noreferrer"
                className="hidden shrink-0 items-center gap-1 text-sm font-medium transition-ui hover:text-brand sm:inline-flex"
              >
                @{site.github} <ArrowUpRight className="size-4" />
              </a>
            </div>
            <div className="mt-8 overflow-x-auto rounded-2xl border border-border bg-background p-5 shadow-sm">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={`https://ghchart.rshah.org/ff4800/${site.github}`}
                alt={`GitHub contribution graph for ${site.github}`}
                className="min-w-[640px]"
              />
            </div>
          </Container>
        </Section>
      ) : null}

      {/* ───────────── Newsletter ───────────── */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="grid gap-8 rounded-3xl border border-border bg-card p-8 shadow-sm md:grid-cols-[1fr_1fr] md:items-center md:p-10">
            <div>
              <Eyebrow label="Newsletter" />
              <h2 className="mt-2 max-w-md font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
                One idea on building and marketing, every week.
              </h2>
              <p className="mt-3 max-w-md text-muted-foreground">
                No noise, no fluff — just the one thing worth your attention. Unsubscribe anytime.
              </p>
            </div>
            <div>
              <NewsletterForm variant="block" />
            </div>
          </div>
        </Container>
      </Section>

      {/* ───────────── Now / About ───────────── */}
      <Section bleed>
        <Container className="py-16 md:py-24">
          <div className="grid gap-10 md:grid-cols-[1fr_auto] md:items-end">
            <div>
              <Eyebrow label="The short version" />
              <p className="mt-4 max-w-2xl text-balance font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
                {site.tagline}
              </p>
              <p className="mt-4 max-w-xl text-muted-foreground">
                I care about products that compound and marketing that isn&rsquo;t noise. If
                that&rsquo;s your kind of thing, there&rsquo;s a lot here to dig into.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row md:flex-col">
              <Link href="/about" className={cn(buttonVariants({ size: "lg" }), pill)}>
                About me
                <ArrowRight className="size-4" />
              </Link>
              <Link href="/now" className={cn(buttonVariants({ variant: "outline", size: "lg" }), pill)}>
                What I&rsquo;m doing now
              </Link>
            </div>
          </div>
        </Container>
      </Section>
    </>
  );
}
