/**
 * Single source of truth for site-wide identity, navigation, and contact.
 * Swap these values (or back them with a CMS) without touching components.
 */

export const site = {
  name: "Shubham Datarkar",
  alias: "The Kalamwala",
  shortName: "SD",
  role: "Founder · Marketer · Copywriter",
  domain: "datarkar.com",
  url: "https://datarkar.com",
  email: "hello@datarkar.com",
  location: "Nagpur, India",
  tagline: "The builder who markets, the marketer who builds.",
  description:
    "Shubham Datarkar (The Kalamwala) is a founder and product builder from Nagpur. He builds software products and runs the marketing that grows them — through Rajmudra Media and products like Meeticulous and Book A Sloth.",
  // External booking software — Book A Sloth, his own scheduling product.
  bookingUrl: "https://bookasloth.com/sndatarkar",
  spotifyUrl: "https://open.spotify.com/playlist/1p5XuC8FEI1iYrBRZIxVSW",
  youtubeUrl: "https://www.youtube.com/@sndatarkar",
  // GitHub username for the activity graph. Empty → module hidden. [CONFIRM]
  github: "",
  photo: "https://company-assets.bookasloth.in/images/sd/website/profile.webp",
} as const;

export const companies = [
  {
    name: "Rajmudra Media",
    image: "/ventures/rajmudra-logo.svg",
    kind: "Design · Build · Grow",
    since: "2024",
    status: "Live",
    blurb: "One team to design, build and grow your business online — on systems you own, not rent.",
    url: "https://rajmudramedia.com",
  },
  {
    name: "Meeticulous",
    image: "/ventures/meeticulous2.png",
    kind: "Booking SaaS",
    since: "2026",
    status: "Building",
    blurb: "Bookings, payments, calendar sync, WhatsApp reminders and GST invoicing — in one system.",
  },
  {
    name: "Alluminaty",
    image: "/ventures/alluminaty2.png",
    kind: "Alumni Management",
    since: "2025",
    status: "Live",
    blurb: "Alumni directory, batch groups, paid events and memberships for schools & colleges.",
  },
  {
    name: "Coffee and Toffee",
    image: "/ventures/coffee-toffee.png",
    kind: "Tips & Donations",
    since: "2025",
    status: "Live",
    blurb: "One-tap creator support with a 0% platform fee and instant payouts.",
  },
  {
    name: "Ticket Dino",
    image: "/ventures/ticket-dino.png",
    kind: "Events & Ticketing",
    since: "2025",
    status: "Live",
    blurb: "Sell tickets, scan QR check-ins, and track attendance live.",
  },
  {
    name: "Book A Sloth",
    kind: "Booking SaaS · CMO",
    since: "2026",
    status: "Building",
    blurb: "Replacing “appointment milega kya?” with “Booked.” India's calmest booking platform.",
    url: "https://bookasloth.com",
  },
  {
    name: "The Bogus Company",
    kind: "Creative & Ads Studio",
    since: "2021",
    status: "Active",
    blurb: "Where ideas dress up as ads and refuse to be ignored.",
  },
  {
    name: "The Kalamwala",
    kind: "Writing Identity",
    since: "2021",
    status: "Active",
    blurb: "The pen name behind the copy, the essays, and the puns.",
  },
] as const;

// Status → chip tone. Keep the vocabulary small and honest.
export const statusTone: Record<string, string> = {
  Live: "border-success text-success",
  Active: "border-foreground text-foreground",
  Building: "border-brand text-brand",
  Idea: "border-border text-muted-foreground",
  Sold: "border-border text-muted-foreground line-through",
  Paused: "border-border text-muted-foreground",
};

export type NavItem = {
  label: string;
  href: string;
  description?: string;
};

export type NavGroup = {
  label: string;
  items: NavItem[];
};

// Dual-brain navigation. The header shows two entry points: a left burger
// (Growth & Systems — the analytical, business-of-building side) and a right
// kebab (Ideas & Play — the creative, human side). Each opens a themed drawer;
// a toggle inside flips between the two on any screen size.
// Dual-brain navigation, re-themed for the founder HQ:
//   left  = "Building" — the work, the products, how to work with me.
//   right = "Writing & Story" — the words and the human behind them.
export const leftBrain: NavGroup[] = [
  {
    label: "Building",
    items: [
      { label: "What I'm building", href: "/projects", description: "Products, companies, experiments" },
      { label: "Case Studies", href: "/case-studies", description: "Real outcomes, real numbers" },
      { label: "Changelog", href: "/changelog", description: "What shipped, and when" },
    ],
  },
  {
    label: "Work with me",
    items: [
      { label: "Shop", href: "/products", description: "Products you can buy" },
      { label: "Book a call", href: "/book", description: "Grab a slot" },
      { label: "Support", href: "/support", description: "Back the work" },
    ],
  },
  {
    label: "Current",
    items: [
      { label: "Now", href: "/now", description: "What I'm focused on" },
      { label: "Uses", href: "/uses", description: "Tools & setup" },
      { label: "Roadmap", href: "/roadmap", description: "Where this is going" },
    ],
  },
];

export const rightBrain: NavGroup[] = [
  {
    label: "Writing",
    items: [
      { label: "Blog", href: "/blog", description: "Essays, playbooks, teardowns" },
      { label: "Newsletter", href: "/newsletter", description: "One signal, by email" },
    ],
  },
  {
    label: "Story",
    items: [
      { label: "About", href: "/about", description: "Who I am, how I work" },
      { label: "My Story", href: "/my-story", description: "How I got here" },
      { label: "Me", href: "/me", description: "The short version" },
    ],
  },
  {
    label: "Connect",
    items: [
      { label: "Contact", href: "/contact", description: "Reach me" },
      { label: "Members", href: "/members", description: "The inner circle" },
    ],
  },
];

export const footerNav: NavGroup[] = [
  {
    label: "Explore",
    items: [
      { label: "Home", href: "/" },
      { label: "About", href: "/about" },
      { label: "My Story", href: "/my-story" },
      { label: "Now", href: "/now" },
      { label: "Uses", href: "/uses" },
      { label: "Roadmap", href: "/roadmap" },
    ],
  },
  {
    label: "Building",
    items: [
      { label: "Projects", href: "/projects" },
      { label: "Case Studies", href: "/case-studies" },
      { label: "Shop", href: "/products" },
      { label: "Changelog", href: "/changelog" },
    ],
  },
  {
    label: "Writing",
    items: [
      { label: "Blog", href: "/blog" },
      { label: "Newsletter", href: "/newsletter" },
    ],
  },
  {
    label: "More",
    items: [
      { label: "Book a call", href: "/book" },
      { label: "Support", href: "/support" },
      { label: "Members", href: "/members" },
      { label: "FAQ", href: "/faq" },
      { label: "Contact", href: "/contact" },
    ],
  },
];

export type SocialLink = { label: string; href: string; handle: string };

export const socials: SocialLink[] = [
  { label: "X / Twitter", href: "https://x.com/sndatarkar", handle: "@sndatarkar" },
  { label: "LinkedIn", href: "https://www.linkedin.com/in/sndatarkar", handle: "in/sndatarkar" },
  { label: "YouTube", href: "https://www.youtube.com/@sndatarkar", handle: "@sndatarkar" },
  { label: "Instagram", href: "https://www.instagram.com/sndatarkar", handle: "@sndatarkar" },
  { label: "Book A Sloth", href: site.bookingUrl, handle: "@sndatarkar" },
];

// sameAs feeds JSON-LD social-profile links — keep it to real identity
// profiles, not the Book A Sloth booking page.
export const sameAs = socials
  .filter((s) => s.label !== "Book A Sloth")
  .map((s) => s.href);
