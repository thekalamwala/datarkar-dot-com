"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { ArrowUpRight } from "lucide-react";
import { XLogo, LinkedinLogo, YoutubeLogo, InstagramLogo, type Icon as PhosphorIcon } from "@phosphor-icons/react";
import { motion, useScroll, useTransform, useReducedMotion, type MotionValue } from "framer-motion";

import { cn } from "@/lib/utils";
import { NewsletterForm } from "@/components/sections/newsletter-form";

// Rotating colour accents for the venture cards (orange / plum / green).
const ACCENTS = [
  { soft: "bg-brand/10", text: "text-brand/30" },
  { soft: "bg-plum/10", text: "text-plum/30" },
  { soft: "bg-green/10", text: "text-green/30" },
];

const SOCIAL_ICON: Record<string, PhosphorIcon> = {
  "X / Twitter": XLogo,
  LinkedIn: LinkedinLogo,
  YouTube: YoutubeLogo,
  Instagram: InstagramLogo,
};

type Company = { name: string; kind: string; status: string; blurb: string; url?: string; image?: string };
type Social = { label: string; href: string };

export function HomeHero({
  name,
  firstWord,
  photo,
  socialLinks,
  companies,
  liveCount,
  bookingUrl,
}: {
  name: string;
  firstWord: string;
  photo: string;
  socialLinks: Social[];
  companies: Company[];
  liveCount: number;
  bookingUrl: string;
}) {
  const last = name.trim().split(/\s+/).pop() ?? name;
  const reduce = useReducedMotion();

  // The giant→card morph is a desktop treatment; mobile renders the static card.
  const [isDesktop, setIsDesktop] = useState(false);
  useEffect(() => {
    const m = window.matchMedia("(min-width: 1024px)");
    const u = () => setIsDesktop(m.matches);
    u();
    m.addEventListener("change", u);
    return () => m.removeEventListener("change", u);
  }, []);
  // Animation removed — render the profile card straight away, no giant intro.
  const motionOn = false;
  void isDesktop;
  void reduce;

  // Measure the name's intrinsic width so the giant fills the viewport width.
  const nameRef = useRef<HTMLDivElement>(null);
  const [big, setBig] = useState(2.4);
  useEffect(() => {
    const compute = () => {
      const el = nameRef.current;
      if (!el) return;
      const natW = el.scrollWidth; // w-max lockup → intrinsic text width
      const avail = window.innerWidth - 56;
      setBig(Math.max(1.5, Math.min(6, avail / natW)));
    };
    compute();
    requestAnimationFrame(compute);
    (document as Document & { fonts?: { ready: Promise<unknown> } }).fonts?.ready.then(compute);
    window.addEventListener("resize", compute);
    return () => window.removeEventListener("resize", compute);
  }, [isDesktop]);

  const { scrollY } = useScroll();
  const o = { clamp: true } as const;
  // Layer A — the giant lockup (approved shrink), then fades out.
  const aScale = useTransform(scrollY, [0, 300], [big, 1], o);
  const aOpacity = useTransform(scrollY, [250, 345], [1, 0], o);
  const aPE = useTransform(aOpacity, (v) => (v < 0.05 ? "none" : "auto"));
  // Layer B — the card assembles in (new components walk in).
  const walk = (from: number): { opacity: MotionValue<number>; y: MotionValue<number> } => ({
    opacity: useTransform(scrollY, [from, from + 90], [0, 1], o),
    y: useTransform(scrollY, [from, from + 90], [18, 0], o),
  });
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const photoIn = walk(315);
  const photoScale = useTransform(scrollY, [315, 405], [0.78, 1], o);
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const nameIn = walk(350);
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const bioIn = walk(375);
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const newsIn = walk(400);
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const iconsIn = walk(425);
  const rightOpacity = useTransform(scrollY, [300, 430], [0, 1], o);
  const rightY = useTransform(scrollY, [300, 430], [28, 0], o);

  const mStyle = (mv: { opacity: MotionValue<number>; y: MotionValue<number> }, extra?: Record<string, unknown>) =>
    motionOn ? { opacity: mv.opacity, y: mv.y, ...extra } : undefined;

  const avatar = (sizeCls: string) => (
    <span className={cn("inline-grid shrink-0 place-items-center overflow-hidden rounded-full bg-[#f6c9a4] shadow-sm", sizeCls)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={photo} alt={name} className="size-full object-cover" />
    </span>
  );

  // ── Marc Lou card (Layer B / mobile + reduced static) ────────────────────
  const card = (
    <div className="flex flex-col gap-5">
      <motion.div style={mStyle(photoIn, motionOn ? { scale: photoScale } : undefined)}>
        {avatar("size-20 ring-4 ring-[#f6c9a4]/30")}
      </motion.div>

      <motion.h1 style={mStyle(nameIn)} className="font-display text-4xl font-extrabold leading-[1.02] tracking-tight sm:text-5xl">
        {firstWord} {last}
      </motion.h1>

      <motion.div style={mStyle(bioIn)} className="max-w-sm">
        <p className="text-pretty text-lg leading-snug text-muted-foreground">
          I build businesses, products and brands — then{" "}
          <span className="font-semibold text-foreground">market what I build.</span>
        </p>
        <p className="mt-3 text-[15px] leading-relaxed text-muted-foreground">
          <span className="font-semibold text-foreground">{companies.length}</span> products, solo since{" "}
          <span className="font-semibold text-foreground">2021</span> — known as{" "}
          <span className="font-semibold text-foreground">The Kalamwala</span>, from Nagpur.
        </p>
      </motion.div>

      <motion.div style={mStyle(newsIn)}>
        <p className="mb-2 text-sm text-muted-foreground">
          Join the newsletter — one idea on building &amp; marketing, every week.
        </p>
        <NewsletterForm variant="inline" className="w-full max-w-sm" />
      </motion.div>

      <motion.div style={mStyle(iconsIn)} className="flex flex-wrap items-center gap-5 pt-1">
        {socialLinks.map((s) => {
          const Icon = SOCIAL_ICON[s.label];
          return (
            <a
              key={s.label}
              href={s.href}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={s.label}
              className="text-muted-foreground transition-ui hover:text-foreground"
            >
              {Icon ? <Icon size={22} weight="fill" /> : <span className="text-sm font-medium">{s.label}</span>}
            </a>
          );
        })}
      </motion.div>
    </div>
  );

  // ── Layer A: the giant Dev-Chauhan lockup (desktop morph only) ───────────
  const fold = (
    <motion.div
      aria-hidden
      style={{ opacity: aOpacity, pointerEvents: aPE }}
      className="pointer-events-none absolute inset-x-0 top-0 z-10 flex h-[92svh] flex-col"
    >
      <div className="flex flex-1 items-center">
        <motion.div
          ref={nameRef}
          style={{ scale: aScale }}
          className="flex w-max max-w-full origin-left flex-wrap items-center gap-x-[0.18em] gap-y-1 font-display text-4xl font-extrabold leading-[0.95] tracking-tight will-change-transform sm:text-5xl"
        >
          <span>{firstWord}</span>
          {avatar("size-[0.95em]")}
          <span>{last}</span>
        </motion.div>
      </div>
      <div className="flex flex-col gap-4 pb-[4vh] sm:flex-row sm:items-end sm:justify-between">
        <div className="max-w-sm">
          <p className="text-pretty text-base font-medium leading-snug sm:text-lg">
            I build businesses, products and brands — then <span className="text-brand">market what I build.</span>
          </p>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            Founder &amp; product builder from Nagpur, known as <strong className="text-foreground">The Kalamwala</strong>.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-x-6 gap-y-2 sm:justify-end">
          {socialLinks.map((s) => (
            <span key={s.label} className="text-sm font-medium text-muted-foreground">
              {s.label}
            </span>
          ))}
        </div>
      </div>
    </motion.div>
  );

  const products = (
    <motion.div style={motionOn ? { opacity: rightOpacity, y: rightY } : undefined}>
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
          const hasUrl = Boolean(c.url);
          const accent = ACCENTS[i % ACCENTS.length];
          const feature = i === 0;
          const initial = c.name.replace(/^The\s+/i, "").charAt(0);
          const inner = (
            <div className="flex h-full flex-col overflow-hidden rounded-2xl border border-border bg-card shadow-sm transition-ui hover:border-brand/30 hover:shadow-md">
              <div className={cn("relative overflow-hidden", accent.soft, feature ? "aspect-[21/9]" : "aspect-[16/10]")}>
                {c.image ? (
                  <Image
                    src={c.image}
                    alt={c.name}
                    fill
                    sizes="(max-width: 1024px) 50vw, 420px"
                    className={/logo|\.svg$/.test(c.image) ? "object-contain p-10" : "object-cover object-top"}
                  />
                ) : (
                  <span className={cn("absolute inset-0 grid place-items-center font-display text-5xl font-extrabold", accent.text)}>
                    {initial}
                  </span>
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
                <a href={c.url} target="_blank" rel="noopener noreferrer" className="block h-full">
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
    </motion.div>
  );

  return (
    <div className="relative">
      <div className="grid gap-12 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)] lg:items-start lg:gap-16">
        <div className="relative flex flex-col lg:sticky lg:top-24 lg:self-start">
          {card}
          {motionOn && fold}
        </div>
        {products}
      </div>
    </div>
  );
}
