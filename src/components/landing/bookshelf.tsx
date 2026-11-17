"use client";

import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";

import { cn } from "@/lib/utils";

type Accent = "brand" | "plum" | "green";

export type Book = {
  id: string;
  title: string;
  author: string;
  accent: Accent;
  isbn?: string;
};

// Real front covers from the Open Library covers API (public book catalog).
// `default=false` → 404 when no cover exists, so onError drops to the CSS cover.
const coverUrl = (isbn?: string) =>
  isbn ? `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg?default=false` : undefined;

// Static class strings per accent so Tailwind keeps them (no dynamic `bg-${x}`).
const ACCENT: Record<Accent, { spine: string; edge: string; cover: string }> = {
  brand: { spine: "bg-brand text-brand-foreground", edge: "bg-brand", cover: "bg-brand/10" },
  plum: { spine: "bg-plum text-plum-foreground", edge: "bg-plum", cover: "bg-plum/10" },
  green: { spine: "bg-green text-green-foreground", edge: "bg-green", cover: "bg-green/10" },
};

const ACCENTS: Accent[] = ["brand", "plum", "green"];
const withAccent = (
  shelf: Omit<Book, "accent">[],
): Book[] => shelf.map((b, i) => ({ ...b, accent: ACCENTS[i % ACCENTS.length] }));

export const DEFAULT_BOOKS: Book[] = withAccent([
  { id: "mom-test", title: "The Mom Test", author: "Rob Fitzpatrick", isbn: "9781492180746" },
  { id: "zero-to-sold", title: "Zero to Sold", author: "Arvid Kahl", isbn: "9783982195728" },
  { id: "make", title: "Make", author: "Pieter Levels", isbn: "9798671211565" },
  { id: "hooked", title: "Hooked", author: "Nir Eyal", isbn: "9780241184837" },
  { id: "obviously-awesome", title: "Obviously Awesome", author: "April Dunford", isbn: "9781999023003" },
  { id: "this-is-marketing", title: "This Is Marketing", author: "Seth Godin", isbn: "9780241370148" },
  { id: "almanack-naval", title: "The Almanack of Naval Ravikant", author: "Eric Jorgenson", isbn: "9781544514215" },
  { id: "deep-work", title: "Deep Work", author: "Cal Newport", isbn: "9780349411903" },
]);

export function Bookshelf({ books = DEFAULT_BOOKS, className }: { books?: Book[]; className?: string }) {
  const reduce = useReducedMotion();
  const [openId, setOpenId] = useState<string | null>(null);
  const [failed, setFailed] = useState<Set<string>>(new Set());
  const railRef = useRef<HTMLDivElement>(null);
  const markFailed = (id: string) => setFailed((prev) => new Set(prev).add(id));

  // Escape or a click outside the rail closes the open book.
  useEffect(() => {
    if (!openId) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpenId(null);
    const onDown = (e: PointerEvent) => {
      if (railRef.current && !railRef.current.contains(e.target as Node)) setOpenId(null);
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onDown);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onDown);
    };
  }, [openId]);

  const toggle = (book: Book, el: HTMLElement) => {
    const next = openId === book.id ? null : book.id;
    setOpenId(next);
    if (next) el.scrollIntoView({ inline: "center", block: "nearest", behavior: reduce ? "auto" : "smooth" });
  };

  const lift = reduce
    ? undefined
    : { y: -10, transition: { type: "spring" as const, stiffness: 340, damping: 25, mass: 0.7 } };

  return (
    <div
      ref={railRef}
      className={cn(
        "flex gap-4 overflow-x-auto px-1 pb-5 pt-2",
        "border-b border-border", // shelf ledge
        "[-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
        className,
      )}
    >
      {books.map((book) => {
        const open = openId === book.id;
        const accent = ACCENT[book.accent];
        return (
          <motion.button
            key={book.id}
            layout
            type="button"
            aria-pressed={open}
            aria-label={`${book.title} by ${book.author}`}
            onClick={(e) => toggle(book, e.currentTarget)}
            whileHover={open ? undefined : lift}
            transition={reduce ? { duration: 0 } : { layout: { duration: 0.38, ease: "easeOut" } }}
            className={cn(
              "relative h-[180px] shrink-0 rounded-2xl shadow-sm outline-none",
              "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand",
              open ? "w-[130px]" : "w-[40px]",
            )}
          >
            <AnimatePresence initial={false} mode="wait">
              {open ? (
                <motion.span
                  key="cover"
                  initial={{ opacity: reduce ? 1 : 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: reduce ? 1 : 0 }}
                  transition={{ duration: reduce ? 0 : 0.38, ease: "easeOut" }}
                  className="absolute inset-0 overflow-hidden rounded-2xl border border-border bg-card"
                >
                  {coverUrl(book.isbn) && !failed.has(book.id) ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={coverUrl(book.isbn)}
                      alt={`${book.title} cover`}
                      loading="lazy"
                      onError={() => markFailed(book.id)}
                      className="size-full object-cover"
                    />
                  ) : (
                    <span className={cn("flex size-full flex-col justify-end gap-1 p-3 text-left", accent.cover)}>
                      <span className={cn("absolute inset-y-0 left-0 w-1.5", accent.edge)} aria-hidden />
                      <span className="font-display text-sm font-bold leading-tight text-foreground">{book.title}</span>
                      <span className="text-xs text-muted-foreground">{book.author}</span>
                    </span>
                  )}
                </motion.span>
              ) : (
                <motion.span
                  key="spine"
                  initial={{ opacity: reduce ? 1 : 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: reduce ? 1 : 0 }}
                  transition={{ duration: reduce ? 0 : 0.38, ease: "easeOut" }}
                  className={cn(
                    "absolute inset-0 flex items-center justify-center overflow-hidden rounded-2xl",
                    accent.spine,
                  )}
                >
                  <span
                    className="font-display text-xs font-semibold tracking-wide [writing-mode:vertical-rl]"
                    style={{ transform: "rotate(180deg)" }}
                  >
                    {book.title}
                  </span>
                </motion.span>
              )}
            </AnimatePresence>
          </motion.button>
        );
      })}
    </div>
  );
}
