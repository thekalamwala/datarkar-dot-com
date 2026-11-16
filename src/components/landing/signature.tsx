"use client";

import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

/**
 * Hand-written signature that "draws itself" on scroll into view.
 *
 * To use YOUR real signature: export it as a single SVG <path> (or a few
 * paths) and replace `SIGN_PATH` + `viewBox` below — the stroke-draw animation
 * works on any path. Keep it a stroke (no fill) so the draw reads as writing.
 */
const VIEWBOX = "0 0 600 200";
// Placeholder cursive flourish — swap for the real signature path.
const SIGN_PATH =
  "M20 120 C40 60 70 50 78 86 s-14 72-26 64 6-96 54-92 40 70 66 62 14-72 42-64 18 66 8 78 M150 120 c30-6 36-70 20-70s-22 60 2 66 40-30 44-54 M250 118 c18-4 20-46 8-46s-14 44 6 48 30-16 34-40 M330 118 c16-2 18-44 8-46s-14 40 4 46 30-14 36-40 M410 70 c0 40 2 56-4 56s-8-34 16-40 M300 150 c120-10 240-6 300-40";
const LEN = 2600;

export function Signature({ className }: { className?: string }) {
  const ref = useRef<SVGSVGElement>(null);
  const [draw, setDraw] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof IntersectionObserver === "undefined") {
      setDraw(true);
      return;
    }
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
      setDraw(true);
      return;
    }
    const io = new IntersectionObserver(
      ([e]) => {
        if (e.isIntersecting) {
          setDraw(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -15% 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <svg
      ref={ref}
      viewBox={VIEWBOX}
      className={cn("text-foreground", className)}
      fill="none"
      aria-label="Signature"
      role="img"
    >
      <path
        d={SIGN_PATH}
        stroke="currentColor"
        strokeWidth="4"
        strokeLinecap="round"
        strokeLinejoin="round"
        style={{
          strokeDasharray: LEN,
          strokeDashoffset: draw ? 0 : LEN,
          transition: "stroke-dashoffset 2s cubic-bezier(0.65,0,0.35,1)",
        }}
      />
    </svg>
  );
}
