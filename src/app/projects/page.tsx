import { ArrowUpRight } from "lucide-react";
import { buildMetadata, breadcrumbSchema } from "@/lib/seo";
import { site, companies, statusTone } from "@/lib/site";
import { Container, Section } from "@/components/layout/container";
import { Reveal } from "@/components/motion/reveal";
import { JsonLd } from "@/components/seo/json-ld";
import { cn } from "@/lib/utils";

export const metadata = buildMetadata({
  title: "Building",
  description:
    "The companies and products Shubham Datarkar is building — Rajmudra Media, Meeticulous, Alluminaty, Coffee and Toffee, Ticket Dino and more. Some live, some in progress.",
  ogTitle: "What I'm building",
  ogDescription: "The companies and products taking shape — some live, some in progress.",
  path: "/projects",
});

function itemList() {
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Projects by Shubham Datarkar",
    itemListElement: companies.map((c, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: c.name,
      ...("url" in c && c.url ? { url: c.url } : {}),
    })),
  };
}

// Group order: what I'm actively building first, then what's live, then the rest.
const GROUPS: { status: string; label: string }[] = [
  { status: "Building", label: "Building now" },
  { status: "Live", label: "Live" },
  { status: "Active", label: "Active" },
];

type Company = (typeof companies)[number];

function VentureCard({ c }: { c: Company }) {
  const hasUrl = "url" in c && Boolean(c.url);
  const inner = (
    <div className="flex h-full flex-col rounded-2xl border border-border bg-card p-6 shadow-sm transition-ui hover:border-brand/30 hover:shadow-md">
      <div className="flex items-start justify-between gap-3">
        <h3 className="font-display text-xl font-bold tracking-tight">{c.name}</h3>
        {hasUrl && (
          <ArrowUpRight className="size-5 shrink-0 text-muted-foreground transition-ui group-hover:text-brand" />
        )}
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <span
          className={cn(
            "rounded-full border px-2.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide",
            statusTone[c.status] ?? statusTone.Idea,
          )}
        >
          {c.status}
        </span>
        <span className="text-xs text-muted-foreground">{c.kind} · since {c.since}</span>
      </div>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">{c.blurb}</p>
    </div>
  );
  return hasUrl ? (
    <a
      href={(c as { url: string }).url}
      target="_blank"
      rel="noopener noreferrer"
      className="group block h-full"
    >
      {inner}
    </a>
  ) : (
    <div className="group h-full">{inner}</div>
  );
}

export default function ProjectsPage() {
  return (
    <>
      <JsonLd data={breadcrumbSchema([{ name: "Home", path: "/" }, { name: "Building", path: "/projects" }])} />
      <JsonLd data={itemList()} />

      {/* Hero */}
      <Section
        bleed
        className="border-b border-border bg-[radial-gradient(70%_55%_at_50%_-5%,color-mix(in_oklab,var(--brand)_9%,transparent),transparent_70%)]"
      >
        <Container className="py-16 md:py-24">
          <Reveal>
            <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              Building
            </p>
          </Reveal>
          <Reveal delay={0.05}>
            <h1 className="mt-5 max-w-3xl text-balance font-display text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-5xl md:text-6xl">
              Everything I&rsquo;m building.
            </h1>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
              Companies and products taking shape right now — some live and in your hands, others
              still being built in the open. The honest list, with status.
            </p>
          </Reveal>
        </Container>
      </Section>

      {/* Grouped grid */}
      {GROUPS.map(({ status, label }) => {
        const items = companies.filter((c) => c.status === status);
        if (items.length === 0) return null;
        return (
          <Section key={status} bleed className="border-b border-border last:border-b-0">
            <Container className="py-14 md:py-20">
              <h2 className="font-display text-sm font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                {label}
                <span className="ml-2 text-muted-foreground/60">{items.length}</span>
              </h2>
              <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {items.map((c) => (
                  <VentureCard key={c.name} c={c} />
                ))}
              </div>
            </Container>
          </Section>
        );
      })}
    </>
  );
}
