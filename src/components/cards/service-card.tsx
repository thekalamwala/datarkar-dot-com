import Link from "next/link";
import { ArrowRight } from "lucide-react";
import type { Service } from "@/lib/data/types";
import { Card } from "@/components/ui/card";
import { Icon } from "@/lib/icons";

export function ServiceCard({ service }: { service: Service }) {
  const tile = ["bg-brand/12 text-brand", "bg-plum/12 text-plum", "bg-green/12 text-green"][service.slug.length % 3];
  const tone = ["text-brand", "text-plum", "text-green"][service.slug.length % 3];
  return (
    <Card interactive className="group relative flex h-full flex-col p-6">
      <div className={`flex size-11 items-center justify-center rounded-card ${tile}`}>
        <Icon name={service.icon} />
      </div>
      <h3 className="mt-5 text-lg font-semibold tracking-tight">{service.name}</h3>
      <p className="mt-1 text-sm font-medium text-muted-foreground">{service.tagline}</p>
      <p className="mt-3 flex-1 text-sm leading-relaxed text-muted-foreground">{service.outcome}</p>
      <p className="mt-5 text-sm font-medium text-foreground">
        From <span className={`font-display font-bold ${tone}`}>{service.startingAt}</span>
      </p>
      <span className={`mt-3 inline-flex items-center gap-1 text-sm font-medium ${tone}`}>
        <Link href={`/services/${service.slug}`} className="after:absolute after:inset-0 focus-visible:outline-none">
          Explore service
        </Link>
        <ArrowRight className="size-4" />
      </span>
    </Card>
  );
}
