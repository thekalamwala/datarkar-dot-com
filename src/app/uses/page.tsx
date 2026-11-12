import { buildMetadata } from "@/lib/seo";
import { uses } from "@/lib/data/site-content";
import { Container, Section } from "@/components/layout/container";
import { PageHero } from "@/components/layout/page-hero";
import { Stagger, StaggerItem } from "@/components/motion/reveal";

export const metadata = buildMetadata({
  title: "The Tools Behind the Work",
  description: "The hardware, software, and services I use to build, write, and ship products. Boring, deliberate, and kept minimal on purpose.",
  ogTitle: "The tools behind the work",
  ogDescription: "Everything I use to build, write, and ship products. Boring, deliberate, minimal on purpose.",
  path: "/uses",
});

export default function UsesPage() {
  return (
    <>
      <PageHero
        eyebrow="Uses"
        title="The tools behind the work"
        description="Everything I use to build, write, and ship products. Boring, deliberate, and kept minimal on purpose."
        crumbs={[{ label: "Home", href: "/" }, { label: "Uses" }]}
      />
      <Section>
        <Container size="narrow">
          <Stagger className="flex flex-col gap-10">
            {uses.map((group, i) => {
              const tone = ["text-brand", "text-plum", "text-green"][i % 3];
              const bar = ["bg-brand", "bg-plum", "bg-green"][i % 3];
              return (
                <StaggerItem key={group.category}>
                  <h2 className={`font-display text-sm font-bold uppercase tracking-[0.12em] ${tone}`}>
                    {group.category}
                  </h2>
                  <ul className="relative mt-4 divide-y divide-border overflow-hidden rounded-card border border-border">
                    <span className={`absolute inset-y-0 left-0 w-1 ${bar}`} aria-hidden />
                    {group.items.map((item) => (
                      <li key={item.name} className="flex flex-col gap-1 p-4 pl-5 sm:flex-row sm:items-baseline sm:gap-4">
                        <span className="w-48 shrink-0 font-medium">{item.name}</span>
                        <span className="text-sm text-muted-foreground">{item.note}</span>
                      </li>
                    ))}
                  </ul>
                </StaggerItem>
              );
            })}
          </Stagger>
        </Container>
      </Section>
    </>
  );
}
