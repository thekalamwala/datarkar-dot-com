"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "framer-motion";
import { cn } from "@/lib/utils";

export type Skill = { label: string; icon?: string };

export const DEFAULT_SKILLS: Skill[] = [
  { label: "Design" },
  { label: "Code" },
  { label: "Marketing" },
  { label: "Copywriting" },
  { label: "SEO" },
  { label: "Branding" },
  { label: "Next.js" },
  { label: "React" },
  { label: "TypeScript" },
  { label: "Tailwind" },
  { label: "Supabase" },
  { label: "Node" },
  { label: "Framer Motion" },
  { label: "Figma" },
  { label: "Product" },
  { label: "Growth" },
];

const PILL_HEIGHT = 34;
const PILL_MIN_WIDTH = 56;
const PILL_PAD_X = 14; // px padding each side added to measured text
const MAX_TILT = Math.PI / 4; // ~45deg

type Props = {
  skills?: Skill[];
  className?: string;
  /** Arena height in px. */
  height?: number;
};

export function SkillCloud({
  skills = DEFAULT_SKILLS,
  className,
  height = 360,
}: Props) {
  const reduced = useReducedMotion();
  const [mounted, setMounted] = useState(false);
  const arenaRef = useRef<HTMLDivElement>(null);
  // Per-pill DOM nodes, in skills order.
  const pillRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (reduced || !mounted) return;
    const arena = arenaRef.current;
    if (!arena) return;

    let disposed = false;
    let cleanup: (() => void) | undefined;

    // Client-only: never let matter-js touch the server bundle.
    import("matter-js").then((Matter) => {
      if (disposed || !arena) return;
      const { Engine, Runner, Bodies, Body, Composite, Mouse, MouseConstraint, Events } = Matter;

      const rect = arena.getBoundingClientRect();
      let W = rect.width;
      const H = height;

      const engine = Engine.create({ enableSleeping: true });
      engine.gravity.y = 1;

      // Measure each pill's rendered width, then size its body to match.
      const pills = pillRefs.current.filter(Boolean) as HTMLDivElement[];
      const bodies = pills.map((el, i) => {
        const textW = el.getBoundingClientRect().width;
        const w = Math.max(PILL_MIN_WIDTH, textW + PILL_PAD_X * 2);
        el.style.width = `${w}px`;
        const body = Bodies.rectangle(
          40 + Math.random() * Math.max(1, W - 80),
          -40 - i * 46, // stagger spawn above the top so they drop in
          w,
          PILL_HEIGHT,
          { restitution: 0.35, friction: 0.4, frictionAir: 0.01, chamfer: { radius: 0 } },
        );
        Body.setAngle(body, (Math.random() - 0.5) * 0.6);
        Body.setAngularVelocity(body, (Math.random() - 0.5) * 0.2);
        return body;
      });

      // Static walls: left, right, floor, ceiling (high, catches flings).
      const wallOpts = { isStatic: true };
      const T = 200; // wall thickness
      const walls = {
        left: Bodies.rectangle(-T / 2, H / 2, T, H * 3, wallOpts),
        right: Bodies.rectangle(W + T / 2, H / 2, T, H * 3, wallOpts),
        floor: Bodies.rectangle(W / 2, H + T / 2, W * 3, T, wallOpts),
        ceiling: Bodies.rectangle(W / 2, -H - T / 2, W * 3, T, wallOpts),
      };

      Composite.add(engine.world, [walls.left, walls.right, walls.floor, walls.ceiling, ...bodies]);

      const mouse = Mouse.create(arena);
      const mouseConstraint = MouseConstraint.create(engine, {
        mouse,
        constraint: { stiffness: 0.2, render: { visible: false } },
      });
      Composite.add(engine.world, mouseConstraint);

      // Gentle restoring torque to keep labels roughly upright (readable).
      Events.on(engine, "beforeUpdate", () => {
        for (const b of bodies) {
          if (b.isSleeping) continue;
          let a = b.angle % (Math.PI * 2);
          if (a > Math.PI) a -= Math.PI * 2;
          if (a < -Math.PI) a += Math.PI * 2;
          if (a > MAX_TILT || a < -MAX_TILT) {
            Body.setAngularVelocity(b, b.angularVelocity - a * 0.002);
          }
        }
      });

      // Sync DOM transforms to bodies each frame.
      let raf = 0;
      const render = () => {
        for (let i = 0; i < pills.length; i++) {
          const b = bodies[i];
          const el = pills[i];
          // Body position is the pill center; shift the top-left DOM node by -50%.
          el.style.transform = `translate(${b.position.x}px, ${b.position.y}px) translate(-50%, -50%) rotate(${b.angle}rad)`;
        }
        raf = requestAnimationFrame(render);
      };

      const runner = Runner.create();
      Runner.run(runner, engine);
      raf = requestAnimationFrame(render);

      // Pause/resume when scrolled off/on screen.
      let running = true;
      const io = new IntersectionObserver(
        ([entry]) => {
          if (entry.isIntersecting && !running) {
            running = true;
            Runner.run(runner, engine);
            raf = requestAnimationFrame(render);
          } else if (!entry.isIntersecting && running) {
            running = false;
            Runner.stop(runner);
            cancelAnimationFrame(raf);
          }
        },
        { threshold: 0 },
      );
      io.observe(arena);

      // Reposition walls on container resize so pills stay bounded.
      const ro = new ResizeObserver(() => {
        const r = arena.getBoundingClientRect();
        if (r.width === W || r.width === 0) return;
        W = r.width;
        Body.setPosition(walls.right, { x: W + T / 2, y: H / 2 });
        Body.setPosition(walls.floor, { x: W / 2, y: H + T / 2 });
        Body.setPosition(walls.ceiling, { x: W / 2, y: -H - T / 2 });
      });
      ro.observe(arena);

      cleanup = () => {
        cancelAnimationFrame(raf);
        io.disconnect();
        ro.disconnect();
        Runner.stop(runner);
        Events.off(engine, "beforeUpdate");
        Composite.clear(engine.world, false);
        Engine.clear(engine);
      };
    });

    return () => {
      disposed = true;
      cleanup?.();
    };
  }, [reduced, mounted, height, skills]);

  // Reduced motion / pre-mount (SSR): static wrap, no physics.
  if (reduced || !mounted) {
    return (
      <div className={cn("flex flex-wrap gap-2", className)}>
        {skills.map((s) => (
          <span
            key={s.label}
            className="inline-flex h-[34px] items-center gap-1.5 rounded-full border border-border bg-card px-3.5 font-mono text-xs font-medium text-foreground"
          >
            {s.icon ? null : <span className="size-1.5 rounded-full bg-brand" />}
            {s.label}
          </span>
        ))}
      </div>
    );
  }

  return (
    <div
      ref={arenaRef}
      className={cn(
        "relative w-full overflow-hidden rounded-2xl border border-border bg-background/50",
        "cursor-grab active:cursor-grabbing",
        className,
      )}
      style={{ height }}
    >
      {skills.map((s, i) => (
        <div
          key={s.label}
          ref={(el) => {
            pillRefs.current[i] = el;
          }}
          className="pointer-events-none absolute left-0 top-0 inline-flex h-[34px] items-center justify-center gap-1.5 whitespace-nowrap rounded-full border border-border bg-card px-3.5 font-mono text-xs font-medium text-foreground will-change-transform"
          style={{ minWidth: PILL_MIN_WIDTH }}
        >
          <span className="size-1.5 shrink-0 rounded-full bg-brand" />
          {s.label}
        </div>
      ))}
    </div>
  );
}
