import Link from "next/link";
import { ArrowRight, User, Inbox } from "lucide-react";
import { requireMember } from "@/lib/members/session";

export const metadata = { title: "Dashboard" };

const links = [
  { href: "/members/account", label: "Account", detail: "Your profile and membership.", Icon: User, tone: "text-brand" },
  { href: "/members/requests", label: "Requests", detail: "What you've asked me to build or write.", Icon: Inbox, tone: "text-plum" },
];

export default async function MembersDashboard() {
  const { user } = await requireMember("/members");
  const name = user!.email?.split("@")[0] ?? "there";

  return (
    <div className="space-y-8">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight">Welcome back, {name}</h1>
        <p className="mt-1 text-sm text-muted-foreground">Your member space.</p>
      </header>

      <div className="grid gap-4 sm:grid-cols-2">
        {links.map(({ href, label, detail, Icon, tone }) => (
          <Link
            key={href}
            href={href}
            className="group flex h-full flex-col rounded-card border border-border bg-card p-6 transition-ui hover:border-brand/30"
          >
            <Icon className={`size-6 ${tone}`} />
            <h2 className="mt-4 flex items-center gap-1 font-semibold tracking-tight">
              {label}
              <ArrowRight className="size-4 text-muted-foreground" />
            </h2>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{detail}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
