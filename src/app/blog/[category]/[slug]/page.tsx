import { ViewTransition } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { site } from "@/lib/site";
import { buildMetadata, articleSchema, breadcrumbSchema } from "@/lib/seo";
import { blogCategories, author } from "@/lib/data/posts";
import { getPublishedPost, getPublishedPosts } from "@/lib/blog/queries";
import { autolinkBlocks, buildLinkIndex } from "@/lib/blog/autolink";
import { buildExternalIndex } from "@/lib/blog/external-links";
import type { Post } from "@/lib/data/types";
import { Container, Section } from "@/components/layout/container";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { ArticleBody } from "@/components/content/article-body";
import { getAffiliateDomains } from "@/lib/content/affiliate-queries";
import { ReadingProgress } from "@/components/content/reading-progress";
import { PostFooter } from "@/components/blog/post-footer";
import { ShareBar } from "@/components/blog/share-bar";
import { JsonLd } from "@/components/seo/json-ld";
import { formatDate, readingTime } from "@/lib/utils";

export const revalidate = 300; // ISR: static HTML from CDN, refresh every 5 min

// Prerender every published article at build so first visit is CDN-instant.
export async function generateStaticParams() {
  const posts = await getPublishedPosts();
  return posts.map((p) => ({ category: p.category, slug: p.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ category: string; slug: string }> }) {
  const { category, slug } = await params;
  const post = await getPublishedPost(slug);
  if (!post) return buildMetadata({ title: "Article", path: `/blog/${category}/${slug}` });
  // queries.ts now selects seo_title/og_title/og_description (migration
  // 20260711000002 is applied), so these are populated per-post when an author
  // fills them in the editor; the `?? post.title` fallback covers empty ones.
  return buildMetadata({
    title: post.seoTitle ?? post.title,
    description: post.excerpt,
    ogTitle: post.ogTitle,
    ogDescription: post.ogDescription,
    path: `/blog/${post.category}/${post.slug}`,
    type: "article",
    publishedTime: post.date,
    modifiedTime: post.dateModified,
  });
}

export default async function ArticlePage({ params }: { params: Promise<{ category: string; slug: string }> }) {
  const { category, slug } = await params;
  const post = await getPublishedPost(slug);
  if (!post || post.category !== category) notFound();

  const cat = blogCategories.find((c) => c.slug === post.category);
  const allPublished = await getPublishedPosts();
  const candidates = allPublished.filter((p) => p.slug !== post.slug);

  // Read Next: rank by shared-tag overlap (topical relevance), then same
  // category, then recency — stronger SEO signal than category+recency alone.
  const overlap = (p: Post) => p.tags.filter((t) => post.tags.includes(t)).length;
  const relatedPosts = [...candidates]
    .sort(
      (a, b) =>
        overlap(b) - overlap(a) ||
        Number(b.category === post.category) - Number(a.category === post.category) ||
        b.date.localeCompare(a.date),
    )
    .slice(0, 4);

  // Automatic in-body internal links to canonical posts for shared tags, then
  // outbound contextual links to the founder's ventures (topical deep links).
  const internallyLinked = autolinkBlocks(post.body, buildLinkIndex(post, candidates));
  const linkedBody = autolinkBlocks(internallyLinked, buildExternalIndex(post), 2);
  const affiliateDomains = await getAffiliateDomains();

  return (
    <>
      <ReadingProgress />
      <JsonLd
        data={[
          articleSchema({
            title: post.title,
            description: post.excerpt,
            path: `/blog/${post.category}/${post.slug}`,
            datePublished: post.date,
            dateModified: post.dateModified,
            image: `${site.url}/blog/${post.category}/${post.slug}/opengraph-image`,
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Blog", path: "/blog" },
            { name: cat?.label ?? post.category, path: `/blog/${post.category}` },
            { name: post.title, path: `/blog/${post.category}/${post.slug}` },
          ]),
        ]}
      />

      {/* Editorial header — kicker, title, lead, author */}
      <Section bleed className="relative border-b border-border">
        <span aria-hidden className="absolute inset-x-0 top-0 h-1 bg-brand" />
        <Container size="prose" className="py-14 md:py-20">
          <Breadcrumb
            items={[
              { label: "Home", href: "/" },
              { label: "Blog", href: "/blog" },
              { label: cat?.label ?? post.category, href: `/blog/${post.category}` },
            ]}
            className="mb-8"
          />
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-semibold uppercase tracking-[0.14em]">
            <Link href={`/blog/${post.category}`} className="text-brand transition-ui hover:opacity-80">
              {cat?.label ?? post.category}
            </Link>
            <span className="text-muted-foreground/50" aria-hidden>·</span>
            <time dateTime={post.date} className="text-muted-foreground">{formatDate(post.date)}</time>
            <span className="text-muted-foreground/50" aria-hidden>·</span>
            <span className="text-muted-foreground">{readingTime(post.words)} min read</span>
          </div>
          <ViewTransition name={`post-title-${post.slug}`}>
            <h1 className="mt-5 text-balance font-display text-4xl font-extrabold leading-[1.1] tracking-tight md:text-5xl">
              {post.title}
            </h1>
          </ViewTransition>
          <p className="mt-5 text-pretty text-xl leading-relaxed text-muted-foreground">{post.excerpt}</p>
          <div className="mt-8 flex items-center justify-between gap-4 border-t border-border pt-6">
            <div className="flex items-center gap-3">
              <Avatar>
                <AvatarFallback>{author.initials}</AvatarFallback>
              </Avatar>
              <div className="text-sm">
                <Link href="/about" className="font-semibold underline-offset-4 hover:underline">
                  {author.name}
                </Link>
                <div className="text-muted-foreground">{author.role}</div>
                {post.dateModified &&
                new Date(post.dateModified).getTime() - new Date(post.date).getTime() > 86_400_000 ? (
                  <div className="text-xs text-muted-foreground">
                    Updated <time dateTime={post.dateModified}>{formatDate(post.dateModified)}</time>
                  </div>
                ) : null}
              </div>
            </div>
            <ShareBar url={`${site.url}/blog/${post.category}/${post.slug}`} title={post.title} className="hidden sm:flex" />
          </div>
        </Container>
      </Section>

      {/* Body — centered prose with a sticky share rail on wide screens */}
      <Section>
        <div className="relative mx-auto w-full max-w-[var(--container-prose)] px-6 md:px-8">
          <div aria-hidden className="pointer-events-none absolute right-full top-0 hidden h-full pr-8 xl:block">
            <div className="sticky top-28 flex flex-col items-center gap-2 pointer-events-auto">
              <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Share</span>
              <ShareBar vertical url={`${site.url}/blog/${post.category}/${post.slug}`} title={post.title} />
            </div>
          </div>
          <article>
            <ArticleBody blocks={linkedBody} affiliateDomains={affiliateDomains} relatedPosts={allPublished} />
          </article>
        </div>
      </Section>

      <PostFooter
        post={post}
        categoryLabel={cat?.label ?? post.category}
        authorName={author.name}
        related={relatedPosts.map((p) => ({ slug: p.slug, category: p.category, title: p.title, date: p.date }))}
      />
    </>
  );
}
