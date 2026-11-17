"use client";

import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

/**
 * Real signature (public/sign.png — white strokes on transparency, produced by
 * scripts/process-sign.mjs), revealed left→right on scroll into view so it
 * reads like it's being written.
 */
export function Signature({ className }: { className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const [drawn, setDrawn] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    if (reduce || typeof IntersectionObserver === "undefined") {
      setDrawn(true);
      return;
    }
    const io = new IntersectionObserver(
      ([e]) => {
        if (e.isIntersecting) {
          setDrawn(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -15% 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <div ref={ref} className={cn("overflow-hidden", className)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/sign.png"
        alt="Signature"
        className="h-full w-auto select-none object-contain"
        style={{
          clipPath: drawn ? "inset(0 0 0 0)" : "inset(0 100% 0 0)",
          transition: "clip-path 1.9s cubic-bezier(0.6,0,0.35,1)",
        }}
        draggable={false}
      />
    </div>
  );
}
