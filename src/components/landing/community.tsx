import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

import { Container, Section } from "@/components/layout/container";
import { cn } from "@/lib/utils";

type Quote = { quote: string; name: string; role: string; accent: string };

// Sample wall — replace with real testimonials (or load from /community).
const QUOTES: Quote[] = [
  { quote: "I like the minimalistic look — good work.", name: "Garv J.", role: "Creator", accent: "bg-brand/20 text-brand" },
  { quote: "Thanks! Lovely — what more can I say, just build and build and build…", name: "Kabir R.", role: "Designer", accent: "bg-plum/20 text-plum" },
  { quote: "Wait, how did I miss this?", name: "Meera S.", role: "Engineer", accent: "bg-green/20 text-green" },
  { quote: "Coolest site I've seen this week.", name: "Daniel S.", role: "Indie builder", accent: "bg-brand/20 text-brand" },
  { quote: "Nice aesthetics — really liked the details.", name: "Arindam B.", role: "Founder", accent: "bg-plum/20 text-plum" },
  { quote: "The build-in-public energy is contagious.", name: "Priya N.", role: "Marketer", accent: "bg-green/20 text-green" },
];

const TOTAL = 22;

function initials(name: string) {
  return name.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
}

export function Community() {
  return (
    <Section bleed className="border-b border-border">
      <div className="border-b border-border bg-muted/30">
        <Container className="py-4">
          <h2 className="font-display text-lg font-semibold tracking-tight">Community</h2>
        </Container>
      </div>
      <Container className="py-10 md:py-14">
        <p className="mb-6 text-sm italic text-muted-foreground">Big thanks to these folks ↘</p>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {QUOTES.map((q) => (
            <figure key={q.name} className="flex flex-col justify-between gap-6 rounded-2xl border border-border bg-card p-5 shadow-sm transition-ui hover:border-brand/30 hover:shadow-md">
              <blockquote className="text-pretty leading-relaxed text-foreground">“{q.quote}”</blockquote>
              <figcaption className="flex items-center gap-3">
                <span className={cn("grid size-9 shrink-0 place-items-center rounded-full text-xs font-bold", q.accent)}>{initials(q.name)}</span>
                <span className="min-w-0">
                  <span className="block truncate text-sm font-semibold">{q.name}</span>
                  <span className="block truncate font-mono text-xs text-muted-foreground">{q.role}</span>
                </span>
              </figcaption>
            </figure>
          ))}
        </div>

        <div className="mt-6 flex justify-center">
          <Link href="/community" className="inline-flex items-center gap-1 text-sm font-medium text-muted-foreground transition-ui hover:text-brand">
            View all {TOTAL} testimonials <ArrowUpRight className="size-4" />
          </Link>
        </div>
      </Container>
    </Section>
  );
}
