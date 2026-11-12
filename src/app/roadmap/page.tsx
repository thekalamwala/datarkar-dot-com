import { buildMetadata, breadcrumbSchema } from "@/lib/seo";
import { roadmap } from "@/lib/data/site-content";
import type { RoadmapItem } from "@/lib/data/types";
import { Container, Section } from "@/components/layout/container";
import { PageHero } from "@/components/layout/page-hero";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Stagger, StaggerItem } from "@/components/motion/reveal";
import { JsonLd } from "@/components/seo/json-ld";

export const metadata = buildMetadata({
  title: "Public Product Roadmap",
  description: "What's shipped, in progress, planned, and being explored — a public, transparent view of where the products and this site are heading.",
  ogTitle: "Where this is going — the public roadmap",
  ogDescription: "Shipped, in progress, planned, exploring. Transparency is a trust builder.",
  path: "/roadmap",
});

const columns: {
  status: RoadmapItem["status"];
  variant: "success" | "default" | "muted" | "outline";
  tone: string;
  bar: string;
}[] = [
  { status: "Shipped", variant: "success", tone: "text-green", bar: "bg-green" },
  { status: "In Progress", variant: "default", tone: "text-brand", bar: "bg-brand" },
  { status: "Planned", variant: "muted", tone: "text-plum", bar: "bg-plum" },
  { status: "Exploring", variant: "outline", tone: "text-muted-foreground", bar: "bg-border" },
];

export default function RoadmapPage() {
  return (
    <>
      <JsonLd data={breadcrumbSchema([{ name: "Home", path: "/" }, { name: "Roadmap", path: "/roadmap" }])} />
      <PageHero
        eyebrow="Roadmap"
        title="Where this is going"
        description="Transparency is a trust builder. Here's what's done, what's underway, and what's on the horizon."
        crumbs={[{ label: "Home", href: "/" }, { label: "Roadmap" }]}
      />
      <Section>
        <Container>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {columns.map((col) => {
              const items = roadmap.filter((r) => r.status === col.status);
              return (
                <div key={col.status} className="flex flex-col gap-4">
                  <div className="flex items-center justify-between border-b-2 border-border pb-2">
                    <h2 className={`font-display text-sm font-bold uppercase tracking-[0.12em] ${col.tone}`}>
                      {col.status}
                    </h2>
                    <span className="text-xs text-muted-foreground">{items.length}</span>
                  </div>
                  <Stagger className="flex flex-col gap-3">
                    {items.map((item) => (
                      <StaggerItem key={item.title}>
                        <Card className="relative overflow-hidden p-5 pt-6">
                          <span className={`absolute inset-x-0 top-0 h-1 ${col.bar}`} aria-hidden />
                          <div className="flex items-center justify-between gap-2">
                            <Badge variant={col.variant}>{col.status}</Badge>
                            <span className="text-xs text-muted-foreground">{item.quarter}</span>
                          </div>
                          <h3 className="mt-3 font-semibold">{item.title}</h3>
                          <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{item.description}</p>
                        </Card>
                      </StaggerItem>
                    ))}
                  </Stagger>
                </div>
              );
            })}
          </div>
        </Container>
      </Section>
    </>
  );
}
