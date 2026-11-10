import "server-only";

// ponytail: games rail + community ad-slot removed (those modules deleted).
// Kept the Hostinger sponsored card — the only non-games rail content.

const HOSTINGER_PURPLE = "#673DE6";
const HOSTINGER_HREF = "https://www.hostinger.com/in/pricing?REFERRALCODE=SND1995";

function SponsoredCard() {
  return (
    <section className="rounded-card border border-border bg-card p-4 shadow-sm">
      <a
        href={HOSTINGER_HREF}
        target="_blank"
        rel="noopener sponsored"
        className="block text-sm transition-ui hover:opacity-90"
      >
        <div className="flex items-center gap-2">
          <span
            className="rounded-btn px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-white"
            style={{ background: HOSTINGER_PURPLE }}
          >
            Ad
          </span>
          <span className="line-clamp-1 font-medium" style={{ color: HOSTINGER_PURPLE }}>
            Fast, reliable hosting from Hostinger
          </span>
        </div>
        <span className="mt-0.5 block text-xs text-muted-foreground">
          Ship your next site on infrastructure that just works.
        </span>
      </a>
    </section>
  );
}

export async function MembersRail() {
  return (
    <div className="space-y-4">
      <SponsoredCard />
    </div>
  );
}
