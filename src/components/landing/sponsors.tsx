import Link from "next/link";
import { Plus } from "lucide-react";

import { Container, Section } from "@/components/layout/container";
import { Signature } from "@/components/landing/signature";
import { cn } from "@/lib/utils";

type Sponsor = { name: string; href: string; initial?: string; accent: string };

// Replace with real sponsors as they come in. Tiles draw from initials + accent.
const SPONSORS: Sponsor[] = [
  { name: "Rajmudra Media", href: "https://rajmudramedia.com", initial: "R", accent: "bg-foreground text-background" },
  { name: "Book A Sloth", href: "https://bookasloth.com", initial: "B", accent: "bg-green/20 text-green" },
  { name: "The Kalamwala", href: "/about", initial: "K", accent: "bg-brand/20 text-brand" },
];

const tile = "grid size-16 place-items-center rounded-2xl text-xl font-extrabold font-display shadow-sm transition-ui";

export function Sponsors() {
  return (
    <Section bleed className="border-b border-border">
      <div className="border-b border-border bg-muted/30">
        <Container className="py-4">
          <h2 className="font-display text-lg font-semibold italic tracking-tight">Sponsors</h2>
        </Container>
      </div>
      <Container className="py-10 md:py-14">
        <div className="grid gap-8 md:grid-cols-[1fr_auto] md:items-end">
          <div>
            <p className="max-w-md text-pretty leading-relaxed text-muted-foreground">
              You just scrolled to the most important section of the site. This tiny project is sponsored by:
            </p>

            <div className="mt-6 flex flex-wrap items-center gap-3">
              {SPONSORS.map((s) => (
                <a key={s.name} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.name} title={s.name} className={cn(tile, s.accent, "hover:-translate-y-0.5 hover:shadow-md")}>
                  {s.initial}
                </a>
              ))}

              {/* Add-a-sponsor */}
              <Link href="/support" aria-label="Become a sponsor" className={cn(tile, "border border-dashed border-border bg-card text-muted-foreground hover:border-brand/40 hover:text-brand")}>
                <Plus className="size-5" />
              </Link>
            </div>
          </div>

          {/* Signature — draws itself on scroll into view */}
          <Signature className="hidden h-24 w-52 md:block" />
        </div>
      </Container>
    </Section>
  );
}
