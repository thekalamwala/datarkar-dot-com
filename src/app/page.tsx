import Link from "next/link";
import Image from "next/image";
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

// Rotating colour accents for the venture cards (orange / plum / green).
const ACCENTS = [
  { soft: "bg-brand/10", text: "text-brand/30" },
  { soft: "bg-plum/10", text: "text-plum/30" },
  { soft: "bg-green/10", text: "text-green/30" },
];

const fmtDate = (iso: string) =>
  iso ? new Date(iso).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" }) : "";

export default async function HomePage() {
  const posts = await getPublishedPosts().catch(() => []);
  const latest = posts.slice(0, 3);
  const socialLinks = socials.filter((s) => s.href !== site.bookingUrl);
  const liveCount = companies.filter((c) => c.status === "Live").length;

  return (
    <>
      {/* ───────────── Split hero: profile left, products right (marclou layout) ───────────── */}
      <Section
        bleed
        className="relative overflow-hidden border-b border-border"
      >
        <Container className="py-14 md:py-20">
          <div className="grid gap-12 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)] lg:gap-16">
            {/* Profile */}
            <div className="lg:sticky lg:top-24 lg:self-start">
              <Reveal>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={site.photo}
                  alt={site.name}
                  width={96}
                  height={96}
                  className="size-20 rounded-full border border-border object-cover shadow-sm md:size-24"
                />
              </Reveal>
              <Reveal delay={0.05}>
                <h1 className="mt-5 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">{site.name}</h1>
              </Reveal>
              <Reveal delay={0.1}>
                <p className="mt-3 text-pretty text-lg font-medium leading-snug">
                  I build businesses, products and brands — then <span className="text-brand">market what I build.</span>
                </p>
              </Reveal>
              <Reveal delay={0.15}>
                <p className="mt-4 max-w-md text-[15px] leading-relaxed text-muted-foreground">
                  Known as <strong className="text-foreground">The Kalamwala</strong>. Founder &amp; product builder from
                  Nagpur. {companies.length} products and companies, building since 2021 — on systems I own, not rent.
                </p>
              </Reveal>
              <Reveal delay={0.2}>
                <div className="mt-5 flex flex-wrap items-center gap-2">
                  {socialLinks.map((s) => (
                    <a
                      key={s.label}
                      href={s.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="rounded-full border border-border px-3 py-1 text-xs font-medium text-muted-foreground transition-ui hover:border-brand/40 hover:text-brand"
                    >
                      {s.label}
                    </a>
                  ))}
                </div>
              </Reveal>
              <Reveal delay={0.25}>
                <div className="mt-6 flex flex-wrap gap-3">
                  <Link href="/about" className={cn(buttonVariants({ size: "default" }), pill)}>
                    About me
                    <ArrowRight className="size-4" />
                  </Link>
                  <a href={site.bookingUrl} target="_blank" rel="noopener noreferrer" className={cn(buttonVariants({ variant: "outline", size: "default" }), pill)}>
                    Book a call
                  </a>
                </div>
              </Reveal>
            </div>

            {/* Products list */}
            <div>
              <div className="flex items-end justify-between gap-4">
                <h2 className="font-display text-sm font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                  What I&rsquo;m building
                  <span className="ml-2 text-muted-foreground/70">{companies.length}</span>
                </h2>
                <Link href="/projects" className="text-xs font-medium text-muted-foreground transition-ui hover:text-brand">
                  {liveCount} live
                </Link>
              </div>

              <div className="mt-5 grid grid-cols-2 gap-3">
                {companies.map((c, i) => {
                  const hasUrl = "url" in c && Boolean(c.url);
                  const image = "image" in c ? (c as { image?: string }).image : undefined;
                  const accent = ACCENTS[i % ACCENTS.length];
                  const feature = i === 0; // first card spans full width
                  const initial = c.name.replace(/^The\s+/i, "").charAt(0);
                  const inner = (
                    <div className="flex h-full flex-col overflow-hidden rounded-2xl border border-border bg-card shadow-sm transition-ui hover:border-brand/30 hover:shadow-md">
                      <div className={cn("relative overflow-hidden", accent.soft, feature ? "aspect-[21/9]" : "aspect-[16/10]")}>
                        {image ? (
                          <Image
                            src={image}
                            alt={c.name}
                            fill
                            sizes="(max-width: 1024px) 50vw, 420px"
                            className={image.endsWith(".svg") ? "object-contain p-10" : "object-cover object-top"}
                          />
                        ) : (
                          <span className={cn("absolute inset-0 grid place-items-center font-display text-5xl font-extrabold", accent.text)}>{initial}</span>
                        )}
                        <span className="absolute left-3 top-3 rounded-full border border-border bg-card/90 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide backdrop-blur">
                          {c.status}
                        </span>
                        {hasUrl && (
                          <span className="absolute right-3 top-3 grid size-7 place-items-center rounded-full bg-card/90 backdrop-blur">
                            <ArrowUpRight className="size-4 text-foreground transition-ui group-hover:text-brand" />
                          </span>
                        )}
                      </div>
                      <div className="flex flex-1 flex-col p-4">
                        <h3 className="font-display text-base font-bold tracking-tight group-hover:text-brand">{c.name}</h3>
                        <p className="mt-0.5 text-xs text-muted-foreground">{c.kind}</p>
                        <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{c.blurb}</p>
                      </div>
                    </div>
                  );
                  return (
                    <div key={c.name} className={cn("group", feature && "col-span-2")}>
                      {hasUrl ? (
                        <a href={(c as { url: string }).url} target="_blank" rel="noopener noreferrer" className="block h-full">
                          {inner}
                        </a>
                      ) : (
                        <div className="h-full">{inner}</div>
                      )}
                    </div>
                  );
                })}
              </div>

              <p className="mt-5 inline-flex items-center gap-2 rounded-full border border-border bg-card/60 px-3.5 py-1.5 text-sm font-medium shadow-sm">
                <span className="size-2 rounded-full bg-brand" aria-hidden />
                Currently building <span className="font-semibold">Meeticulous</span>.
              </p>
            </div>
          </div>
        </Container>
      </Section>

      {/* ───────────── GitHub (only when handle set) ───────────── */}
      {site.github ? (
        <Section bleed className="border-b border-border bg-card">
          <Container className="py-16 md:py-24">
            <div className="flex items-end justify-between gap-4">
              <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">Shipping, in the open</h2>
              <a href={`https://github.com/${site.github}`} target="_blank" rel="noopener noreferrer" className="text-sm font-medium transition-ui hover:text-brand">
                @{site.github}
              </a>
            </div>
            <div className="mt-8 overflow-x-auto rounded-2xl border border-border bg-background p-5 shadow-sm">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`https://ghchart.rshah.org/ff4800/${site.github}`} alt={`GitHub contributions for ${site.github}`} className="min-w-[640px]" />
            </div>
          </Container>
        </Section>
      ) : null}

      {/* ───────────── Newsletter ───────────── */}
      <Section bleed className="border-b border-border bg-card">
        <Container className="py-16 md:py-24">
          <div className="grid gap-8 rounded-3xl border border-border bg-background p-8 shadow-sm md:grid-cols-[1fr_1fr] md:items-center md:p-10">
            <div>
              <h2 className="max-w-md font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
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

      {/* ───────────── Writing ───────────── */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="flex items-end justify-between gap-4">
            <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">Writing</h2>
            <Link href="/blog" className="inline-flex items-center gap-1 text-sm font-medium transition-ui hover:text-brand">
              All writing <ArrowUpRight className="size-4" />
            </Link>
          </div>
          {latest.length > 0 ? (
            <ul className="mt-8 flex flex-col gap-1">
              {latest.map((p) => (
                <li key={p.slug}>
                  <Link href={`/blog/${p.category}/${p.slug}`} className="group flex items-baseline justify-between gap-4 rounded-2xl px-3 py-4 transition-ui hover:bg-muted/50">
                    <span className="min-w-0">
                      <span className="block font-display text-lg font-semibold tracking-tight group-hover:text-brand">{p.title}</span>
                      {p.excerpt && <span className="mt-1 line-clamp-1 block text-sm text-muted-foreground">{p.excerpt}</span>}
                    </span>
                    <span className="shrink-0 text-xs text-muted-foreground">{fmtDate(p.date)}</span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-6 max-w-xl rounded-2xl border border-border bg-card p-5 text-muted-foreground">
              Essays on building, marketing and SEO — the first ones land soon.{" "}
              <Link href="/newsletter" className="font-medium text-foreground underline-offset-4 hover:underline">Get them by email</Link>.
            </p>
          )}
        </Container>
      </Section>

      {/* ───────────── Watch (YouTube) ───────────── */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="flex flex-col items-start justify-between gap-6 sm:flex-row sm:items-center">
            <h2 className="max-w-xl font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
              Build logs and teardowns — on YouTube.
            </h2>
            <a href={site.youtubeUrl} target="_blank" rel="noopener noreferrer" className={cn(buttonVariants({ size: "lg" }), pill, "shrink-0")}>
              <Play className="size-4 fill-current" />
              Watch on YouTube
            </a>
          </div>
        </Container>
      </Section>

      {/* ───────────── Now / About ───────────── */}
      <Section bleed>
        <Container className="py-16 md:py-24">
          <div className="grid gap-10 md:grid-cols-[1fr_auto] md:items-end">
            <div>
              <p className="max-w-2xl text-balance font-display text-2xl font-bold leading-snug tracking-tight sm:text-3xl">
                {site.tagline}
              </p>
              <p className="mt-4 max-w-xl text-muted-foreground">
                I care about products that compound and marketing that isn&rsquo;t noise. If that&rsquo;s your kind of
                thing, there&rsquo;s a lot here to dig into.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row md:flex-col">
              <Link href="/projects" className={cn(buttonVariants({ size: "lg" }), pill)}>
                See everything
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
