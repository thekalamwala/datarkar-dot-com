import Link from "next/link";
import { ArrowRight, ArrowUpRight } from "lucide-react";

import { site, companies, statusTone } from "@/lib/site";
import { buildMetadata, breadcrumbSchema, faqSchema, profilePageSchema } from "@/lib/seo";
import { Container, Section } from "@/components/layout/container";
import { Reveal } from "@/components/motion/reveal";
import { buttonVariants } from "@/components/ui/button";
import { JsonLd } from "@/components/seo/json-ld";
import { cn } from "@/lib/utils";

export const metadata = buildMetadata({
  title: "About",
  description:
    "Shubham Datarkar — founder and product builder known as The Kalamwala. He builds software products and runs the marketing that grows them, through Rajmudra Media and products like Meeticulous and Book A Sloth.",
  ogTitle: "The builder who markets, the marketer who builds",
  ogDescription: "Who I am, how I work, and what I'm building — from Nagpur, for founders everywhere.",
  path: "/about",
  type: "profile",
});

// Entity-answer FAQ (FAQPage JSON-LD + visible copy) so answer engines can cite
// a clean, current description.
const aboutFaqs = [
  {
    question: "Who is Shubham Datarkar?",
    answer:
      "Shubham Datarkar is a founder and product builder from Nagpur, India, known online as The Kalamwala. He builds software products and runs the marketing that grows them — through Rajmudra Media (design, build and grow) and products like Meeticulous and Book A Sloth.",
  },
  {
    question: "What does 'The Kalamwala' mean?",
    answer:
      "Kalam means pen; wala means one who works with it. The Kalamwala is Shubham Datarkar's alias for writing and content — the name Shubham Datarkar is for the business and the building.",
  },
  {
    question: "What does Shubham Datarkar do?",
    answer:
      "He designs, builds and markets internet products. The through-line is being both: a marketer who can build and a builder who can market — so the product and the growth are never two different teams.",
  },
  {
    question: "What is Rajmudra Media?",
    answer:
      "Rajmudra Media is Shubham's studio — one team to design, build and grow a business online, on systems you own rather than rent. Its ecosystem includes products like Meeticulous, Alluminaty, Coffee and Toffee and Ticket Dino.",
  },
  {
    question: "Where is Shubham Datarkar based?",
    answer: "Nagpur, Maharashtra, India — working with founders and teams worldwide.",
  },
];

const principles = [
  {
    title: "Build what you can market.",
    body: "A product nobody can explain doesn't ship. I design the thing and the story it tells at the same time.",
  },
  {
    title: "Own the stack.",
    body: "Your code, your data, your infrastructure — no platform rent, no lock-in. Systems you control compound; systems you rent expire.",
  },
  {
    title: "Compound, don't spike.",
    body: "Campaigns spike and die. I'd rather build the mechanism that keeps paying out quietly, long after launch.",
  },
  {
    title: "Ship, then write it down.",
    body: "Building in public isn't a flex — it's how the lessons stop being private. If I learned it the hard way, I write it down.",
  },
];

export default function AboutPage() {
  const featured = companies.slice(0, 5);
  return (
    <>
      <JsonLd
        data={[
          profilePageSchema(),
          faqSchema(aboutFaqs),
          breadcrumbSchema([{ name: "Home", path: "/" }, { name: "About", path: "/about" }]),
        ]}
      />

      {/* Hero */}
      <Section
        bleed
        className="border-b border-border bg-[radial-gradient(70%_55%_at_50%_-5%,color-mix(in_oklab,var(--brand)_9%,transparent),transparent_70%)]"
      >
        <Container className="py-16 md:py-24">
          <Reveal>
            <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">About</p>
          </Reveal>
          <Reveal delay={0.05}>
            <h1 className="mt-5 max-w-3xl text-balance font-display text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-5xl md:text-6xl">
              The builder who markets, <span className="text-brand">the marketer who builds.</span>
            </h1>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
              I&rsquo;m Shubham Datarkar — known online as <strong className="text-foreground">The Kalamwala</strong>.
              I build software products and run the marketing that grows them, from Nagpur, for founders everywhere.
            </p>
          </Reveal>
          <Reveal delay={0.15}>
            <div className="mt-9 flex flex-col gap-3 sm:flex-row">
              <Link href="/book" className={cn(buttonVariants({ size: "lg" }), "rounded-full")}>
                Book a call
                <ArrowRight className="size-4" />
              </Link>
              <Link href="/projects" className={cn(buttonVariants({ variant: "outline", size: "lg" }), "rounded-full")}>
                See what I&rsquo;m building
              </Link>
            </div>
          </Reveal>
        </Container>
      </Section>

      {/* Story */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="max-w-2xl">
            <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              The story
            </p>
            <div className="mt-6 space-y-5 text-lg leading-relaxed text-muted-foreground">
              <p>
                I started with words — copy, content, the craft of making people care. That&rsquo;s where{" "}
                <span className="text-foreground">The Kalamwala</span> comes from: <em>kalam</em>, the pen.
              </p>
              <p>
                But writing about products I couldn&rsquo;t change got frustrating. So I learned to build them. Now I
                do both — design and ship the software, then run the SEO, content and growth that fill it. The two
                stopped being separate jobs a long time ago.
              </p>
              <p>
                Today that happens through <span className="text-foreground">Rajmudra Media</span> and a handful of
                products in its ecosystem — built on systems I own, not rent. Some are live; one or two are still
                taking shape. I build in public and write down what I learn along the way.
              </p>
            </div>
          </div>
        </Container>
      </Section>

      {/* How I work */}
      <Section bleed className="border-b border-border bg-card">
        <Container className="py-16 md:py-24">
          <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
            How I work
          </p>
          <div className="mt-8 grid gap-5 sm:grid-cols-2">
            {principles.map((p) => (
              <div key={p.title} className="rounded-2xl border border-border bg-background p-6 shadow-sm">
                <h3 className="font-display text-lg font-bold tracking-tight">{p.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
              </div>
            ))}
          </div>
        </Container>
      </Section>

      {/* Companies */}
      <Section bleed className="border-b border-border">
        <Container className="py-16 md:py-24">
          <div className="flex items-end justify-between gap-4">
            <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              What I&rsquo;m building
            </p>
            <Link href="/projects" className="inline-flex items-center gap-1 text-sm font-medium transition-ui hover:text-brand">
              Full index <ArrowUpRight className="size-4" />
            </Link>
          </div>
          <ul className="mt-8 flex flex-col gap-1">
            {featured.map((c) => (
              <li
                key={c.name}
                className="grid grid-cols-[1fr_auto] items-center gap-4 rounded-2xl px-3 py-4 transition-ui hover:bg-muted/50"
              >
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span className="font-display text-lg font-bold tracking-tight">{c.name}</span>
                    <span
                      className={cn(
                        "rounded-full border px-2.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide",
                        statusTone[c.status] ?? statusTone.Idea,
                      )}
                    >
                      {c.status}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">{c.blurb}</p>
                </div>
              </li>
            ))}
          </ul>
        </Container>
      </Section>

      {/* FAQ */}
      <Section bleed className="border-b border-border bg-card">
        <Container className="py-16 md:py-24">
          <p className="font-display text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
            In short
          </p>
          <dl className="mt-8 max-w-3xl divide-y divide-border">
            {aboutFaqs.map((f) => (
              <div key={f.question} className="py-5">
                <dt className="font-display text-base font-semibold tracking-tight">{f.question}</dt>
                <dd className="mt-2 text-sm leading-relaxed text-muted-foreground">{f.answer}</dd>
              </div>
            ))}
          </dl>
        </Container>
      </Section>

      {/* CTA */}
      <Section bleed>
        <Container className="py-16 md:py-24">
          <div className="flex flex-col items-start justify-between gap-6 rounded-3xl border border-border bg-card p-8 shadow-sm sm:flex-row sm:items-center md:p-10">
            <div>
              <h2 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">Let&rsquo;s build something.</h2>
              <p className="mt-2 max-w-md text-muted-foreground">
                Partner, client, founder or fellow builder — if it&rsquo;s interesting, I want to hear it.
              </p>
            </div>
            <div className="flex shrink-0 flex-col gap-3 sm:flex-row">
              <Link href="/contact" className={cn(buttonVariants({ size: "lg" }), "rounded-full")}>
                Get in touch
                <ArrowRight className="size-4" />
              </Link>
              <Link href="/book" className={cn(buttonVariants({ variant: "outline", size: "lg" }), "rounded-full")}>
                Book a call
              </Link>
            </div>
          </div>
        </Container>
      </Section>
    </>
  );
}
