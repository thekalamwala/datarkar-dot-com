import { ogImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/seo/og";

export const alt = "Shubham Datarkar — the builder who markets, the marketer who builds";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;

export default async function Image() {
  return ogImage({
    category: "Shubham Datarkar",
    title: "The builder who markets, the marketer who builds",
    subtitle: "Founder & product builder. What I'm building, and how.",
    kind: "home",
  });
}
