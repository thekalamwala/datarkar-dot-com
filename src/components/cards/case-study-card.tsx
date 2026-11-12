import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import type { CaseStudy } from "@/lib/data/types";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export function CaseStudyCard({ study }: { study: CaseStudy }) {
  const tone = ["text-brand", "text-plum", "text-green"][study.slug.length % 3];
  const bar = ["bg-brand", "bg-plum", "bg-green"][study.slug.length % 3];
  return (
    <Card interactive className="group relative flex h-full flex-col overflow-hidden p-6 pt-7">
      <span className={`absolute inset-x-0 top-0 h-1 ${bar}`} aria-hidden />
      <Badge variant="outline" className="w-fit">
        {study.sector}
      </Badge>
      <div className="mt-6">
        <div className={`font-display text-4xl font-extrabold tracking-tight ${tone}`}>{study.heroMetric.value}</div>
        <div className="mt-1 text-sm text-muted-foreground">{study.heroMetric.label}</div>
      </div>
      <h3 className="mt-6 text-base font-semibold leading-snug">
        <Link href={`/case-studies/${study.slug}`} className="after:absolute after:inset-0 focus-visible:outline-none">
          {study.title}
        </Link>
      </h3>
      <p className="mt-2 flex-1 text-sm text-muted-foreground">{study.client}</p>
      <span className={`mt-4 inline-flex items-center gap-1 text-sm font-medium ${tone}`}>
        Read case study
        <ArrowUpRight className="size-4" />
      </span>
    </Card>
  );
}
