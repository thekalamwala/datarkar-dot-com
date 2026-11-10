import type { MetadataRoute } from "next";
import { site } from "@/lib/site";
import { getPublishedPosts } from "@/lib/blog/queries";
import { getPublishedEntityDates } from "@/lib/content/queries";
import { discoverPages } from "@/lib/seo/discovery";
import { isIndexable } from "@/lib/seo/routes";

// ponytail: movies/playlists/books/collections/services modules removed — their
// sitemap expansions and lastmod loops went with them. Blog + case studies +
// products are the remaining DB-driven URL sources.

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = site.url;
  const posts = await getPublishedPosts();
  const pages = await discoverPages(posts, []);

  const [caseStudyDates, productDates] = await Promise.all([
    getPublishedEntityDates("case_studies"),
    getPublishedEntityDates("products"),
  ]);
  const lastMod = new Map<string, Date>();
  for (const p of posts) {
    lastMod.set(`/blog/${p.category}/${p.slug}`, new Date(p.dateModified ?? p.date));
  }
  for (const d of caseStudyDates) lastMod.set(`/case-studies/${d.slug}`, new Date(d.updatedAt));
  for (const d of productDates) lastMod.set(`/products/${d.slug}`, new Date(d.updatedAt));

  const newest = (dates: Date[]) => dates.reduce((a, b) => (b > a ? b : a), new Date(0));
  if (posts.length) lastMod.set("/blog", newest(posts.map((p) => new Date(p.dateModified ?? p.date))));

  const HIGH_PRIORITY_PREFIXES = ["/blog", "/case-studies", "/products", "/building"];
  const WEEKLY_PATHS = new Set(["/", "/me", "/blog"]);

  const OG_STATIC = new Set(["/", "/me", "/book"]);
  const OG_DYNAMIC = [/^\/case-studies\/[^/]+$/, /^\/products\/[^/]+$/, /^\/blog\/[^/]+\/[^/]+$/];
  const ogImage = (route: string) => {
    if (!OG_STATIC.has(route) && !OG_DYNAMIC.some((re) => re.test(route))) return undefined;
    return `${base}${route === "/" ? "" : route}/opengraph-image`;
  };

  return pages
    .filter((p) => isIndexable(p.route))
    .map((p) => {
      const modified = lastMod.get(p.route);
      const image = ogImage(p.route);
      return {
        url: `${base}${p.route === "/" ? "" : p.route}`,
        ...(modified ? { lastModified: modified } : {}),
        ...(image ? { images: [image] } : {}),
        changeFrequency: (WEEKLY_PATHS.has(p.route) ? "weekly" : "monthly") as MetadataRoute.Sitemap[number]["changeFrequency"],
        priority: p.route === "/"
          ? 1
          : HIGH_PRIORITY_PREFIXES.some((prefix) => p.route.startsWith(prefix))
            ? 0.8
            : 0.7,
      };
    });
}
