import { buildMetadata, breadcrumbSchema, itemListPageSchema } from "@/lib/seo";
import type { Product } from "@/lib/data/types";
import { getPublishedEntities } from "@/lib/content/queries";
import { Container, Section } from "@/components/layout/container";
import { PageHero } from "@/components/layout/page-hero";
import { CtaBand } from "@/components/sections/cta-band";
import { Stagger, StaggerItem } from "@/components/motion/reveal";
import { ProductCard } from "@/components/cards/product-card";
import { JsonLd } from "@/components/seo/json-ld";

export const metadata = buildMetadata({
  title: "Products",
  description: "Software products from the Rajmudra ecosystem and beyond — booking, ticketing, alumni management, creator tools. Each built calm, fast, and on systems you own.",
  ogTitle: "Products I'm building",
  ogDescription: "A family of focused products, each with its own job to do. Built calm, fast, and free of bloat.",
  path: "/products",
});

export const revalidate = 300; // ISR: static HTML from CDN, refresh every 5 min

export default async function ProductsPage() {
  const products = await getPublishedEntities<Product>("products");
  return (
    <>
      <JsonLd
        data={[
          breadcrumbSchema([{ name: "Home", path: "/" }, { name: "Products", path: "/products" }]),
          itemListPageSchema({
            name: "Products by Shubham Datarkar",
            description:
              "Software products from the Rajmudra ecosystem and beyond — booking, ticketing, alumni management, creator tools.",
            path: "/products",
            items: products.map((p) => ({ name: p.name, path: `/products/${p.slug}`, description: p.tagline })),
          }),
        ]}
      />
      <PageHero
        eyebrow="Products"
        title="Software that compounds"
        description="Focused products — booking, ticketing, alumni management, creator tools — each with its own job to do. Built calm, fast, and on systems you own."
        crumbs={[{ label: "Home", href: "/" }, { label: "Products" }]}
      />
      <Section>
        <Container>
          <Stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {products.map((p) => (
              <StaggerItem key={p.slug}>
                <ProductCard product={p} />
              </StaggerItem>
            ))}
          </Stagger>
        </Container>
      </Section>
      <CtaBand title="Want early access?" description="The newest products ship to the newsletter first. Join to get in early." />
    </>
  );
}
