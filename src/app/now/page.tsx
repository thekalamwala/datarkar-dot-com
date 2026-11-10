import { buildMetadata } from "@/lib/seo";
import { Container, Section } from "@/components/layout/container";
import { PageHero } from "@/components/layout/page-hero";
import { Card } from "@/components/ui/card";
import { Reveal, Stagger, StaggerItem } from "@/components/motion/reveal";
import { NewsletterForm } from "@/components/sections/newsletter-form";

export const metadata = buildMetadata({
  title: "What I'm Focused On Now",
  description: "A living snapshot of what Shubham Datarkar is building, writing, reading, and thinking about right now. Updated roughly monthly.",
  ogTitle: "What I'm focused on right now",
  ogDescription: "Building, writing, reading, thinking — a living snapshot of where my attention goes, updated monthly.",
  path: "/now",
});

const now = [
  {
    heading: "Building",
    items: [
      "Meeticulous — an AI-powered appointment booking app. My main focus right now.",
      "The Rajmudra Media ecosystem: Alluminaty, Coffee and Toffee and Ticket Dino, all live.",
      "Marketing at Book A Sloth as CMO.",
    ],
  },
  {
    heading: "Writing",
    items: [
      "Starting to publish essays on building products, marketing and SEO.",
      "The newsletter — one idea a week, no noise.",
      "Documenting what I learn shipping Meeticulous, in public.",
    ],
  },
  {
    heading: "Learning",
    items: [
      "Where LLM search (GEO) is taking SEO next.",
      "Wiring AI into real product flows, not demos.",
      "Running a small ecosystem on systems I own, not rent.",
    ],
  },
  {
    heading: "Thinking about",
    items: [
      "Distribution as a product feature, not a marketing afterthought.",
      "Why owning your stack beats renting someone else's platform.",
      "The smallest team that can ship and grow a product well.",
    ],
  },
];

export default function NowPage() {
  return (
    <>
      <PageHero
        eyebrow="Now"
        title="What I'm focused on right now"
        description="A living snapshot of where my attention goes. Updated roughly monthly — last updated November 2026."
        crumbs={[{ label: "Home", href: "/" }, { label: "Now" }]}
      />
      <Section>
        <Container size="narrow">
          <Stagger className="grid gap-4 sm:grid-cols-2">
            {now.map((block) => (
              <StaggerItem key={block.heading}>
                <Card className="h-full p-6">
                  <h2 className="text-sm font-semibold uppercase tracking-[0.12em] text-muted-foreground">
                    {block.heading}
                  </h2>
                  <ul className="mt-4 flex flex-col gap-3">
                    {block.items.map((item) => (
                      <li key={item} className="flex gap-3 text-[15px] leading-relaxed">
                        <span className="mt-2 size-1.5 shrink-0 rounded-full bg-foreground/40" aria-hidden />
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </Card>
              </StaggerItem>
            ))}
          </Stagger>
          <Reveal className="mt-10">
            <div className="rounded-card border border-border bg-card p-6 text-center">
              <p className="text-sm text-muted-foreground">Want to follow along? The newsletter is the best way.</p>
              <NewsletterForm variant="inline" className="mx-auto mt-4 max-w-md" />
            </div>
          </Reveal>
        </Container>
      </Section>
    </>
  );
}
