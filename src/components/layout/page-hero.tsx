import * as React from "react";
import { Container, Section } from "@/components/layout/container";
import { Breadcrumb, type Crumb } from "@/components/ui/breadcrumb";
import { Reveal } from "@/components/motion/reveal";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

/** Consistent page header used across every interior page. */
export function PageHero({
  eyebrow,
  title,
  description,
  crumbs,
  actions,
  align = "left",
  className,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  crumbs?: Crumb[];
  actions?: React.ReactNode;
  align?: "left" | "center";
  /** Deprecated — kept for call-site compatibility; no longer renders a grid. */
  blueprint?: boolean;
  className?: string;
}) {
  return (
    <Section
      bleed
      className={cn(
        "relative overflow-hidden border-b border-border bg-[radial-gradient(70%_60%_at_50%_-5%,color-mix(in_oklab,var(--brand)_8%,transparent),transparent_70%)]",
        className,
      )}
    >
      <Container className="relative py-14 md:py-20">
        {crumbs && <Breadcrumb items={crumbs} className="mb-6" />}
        <div className={cn("flex flex-col gap-4", align === "center" && "items-center text-center")}>
          {eyebrow && (
            <Badge variant="outline" className="w-fit rounded-full">
              {eyebrow}
            </Badge>
          )}
          <Reveal>
            <h1 className="max-w-3xl text-balance font-display text-4xl font-extrabold tracking-tight md:text-5xl">{title}</h1>
          </Reveal>
          {description && (
            <Reveal delay={0.05}>
              <p className={cn("max-w-2xl text-lg text-muted-foreground", align === "center" && "mx-auto")}>
                {description}
              </p>
            </Reveal>
          )}
          {actions && <div className="mt-2 flex flex-wrap gap-3">{actions}</div>}
        </div>
      </Container>
    </Section>
  );
}
