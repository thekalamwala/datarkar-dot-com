import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import type { Product } from "@/lib/data/types";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const statusVariant = {
  Live: "success",
  Beta: "warning",
  Building: "muted",
  Concept: "outline",
} as const;

export function ProductCard({ product }: { product: Product }) {
  return (
    <Link href={`/products/${product.slug}`} className="group block focus-visible:outline-none">
      <Card
        interactive
        className="relative flex h-full flex-col overflow-hidden p-6 pt-7"
        style={{ ["--brand" as string]: product.color }}
      >
        <span className="absolute inset-x-0 top-0 h-1" style={{ backgroundColor: "var(--brand)" }} aria-hidden />
        <div className="flex items-start justify-between">
          <span
            className="grid size-9 place-items-center rounded-full font-display text-sm font-bold"
            style={{ backgroundColor: "color-mix(in srgb, var(--brand) 14%, transparent)", color: "var(--brand)" }}
            aria-hidden
          >
            {product.name.charAt(0)}
          </span>
          <Badge variant={statusVariant[product.status]}>{product.status}</Badge>
        </div>
        <h3 className="mt-5 text-lg font-semibold tracking-tight">{product.name}</h3>
        <p className="mt-1 text-sm font-medium text-muted-foreground">{product.tagline}</p>
        <p className="mt-3 flex-1 text-sm leading-relaxed text-muted-foreground">{product.category}</p>
        <span className="mt-5 inline-flex items-center gap-1 text-sm font-medium" style={{ color: "var(--brand)" }}>
          Explore
          <ArrowUpRight className="size-4" />
        </span>
      </Card>
    </Link>
  );
}
