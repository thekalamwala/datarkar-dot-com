import Link from "next/link";
import { ArrowUpRight, ArrowRight, Play } from "lucide-react";

import { buildMetadata } from "@/lib/seo";
import { site, companies, socials, statusTone } from "@/lib/site";
import { getPublishedPosts } from "@/lib/blog/queries";

import { Container, Section } from "@/components/layout/container";
import { buttonVariants } from "@/components/ui/button";
import { NewsletterForm } from "@/components/sections/newsletter-form";
import { HomeHero } from "@/components/landing/home-hero";
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

export default async function HomePage() {
  const posts = await getPublishedPosts().catch(() => []);
  const latest = posts.slice(0, 3);
  const socialLinks = socials.filter((s) => s.href !== site.bookingUrl);
  const liveCount = companies.filter((c) => c.status === "Live").length;

  return (
    <>
      {/* ───────────── Scroll-morph hero: giant name → compact left profile + products ───────────── */}
      <Section bleed className="relative border-b border-border">
        <Container>
          <HomeHero
            name={site.name}
            firstWord="SN"
            photo={site.photo}
            socialLinks={socialLinks}
            companies={companies as unknown as Parameters<typeof HomeHero>[0]["companies"]}
            liveCount={liveCount}
            bookingUrl={site.bookingUrl}
          />
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
      <Section bleed className="border-b border-border">
        <Container className="py-10 md:py-12">
          <div className="grid gap-6 md:grid-cols-[1fr_auto] md:items-center md:gap-10">
            <div>
              <h2 className="max-w-md font-display text-xl font-bold leading-snug tracking-tight sm:text-2xl">
                One idea on building and marketing, every week.
              </h2>
              <p className="mt-2 max-w-md text-sm text-muted-foreground">
                No noise, no fluff — just the one thing worth your attention. Unsubscribe anytime.
              </p>
            </div>
            <NewsletterForm variant="inline" className="w-full md:w-80" />
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
