import Link from "next/link";
import { cn } from "@/lib/utils";
import { SignOutButton } from "./sign-out-button";

type NavItem = { href: string; label: string; hotkey?: string };

const NAV: NavItem[] = [
  { href: "/today", label: "Today", hotkey: "G T" },
  { href: "/inventory", label: "Inventory", hotkey: "G I" },
  { href: "/recipes", label: "Recipes", hotkey: "G R" },
  { href: "/design", label: "Design", hotkey: "G D" },
  { href: "/prep", label: "Prep", hotkey: "G P" },
  { href: "/line-checks", label: "Line Checks", hotkey: "G L" },
  { href: "/receiving", label: "Receiving", hotkey: "G V" },
  { href: "/users", label: "Users", hotkey: "G U" },
];

export function Sidebar({
  currentPath,
  user,
}: {
  currentPath: string;
  user: { email?: string | null } | null;
}) {
  return (
    <aside className="w-[240px] shrink-0 border-r border-border-strong bg-surface flex flex-col">
      <div className="px-6 py-6 border-b border-border-strong">
        <div className="font-display text-lg leading-none">Uncommon Path</div>
        <div className="text-xs uppercase tracking-wide text-ink-muted mt-2">
          Back of house
        </div>
      </div>

      <nav className="flex-1 py-5">
        <div className="px-6 text-xs uppercase tracking-wide text-ink-muted mb-3">
          Modules
        </div>
        <ul className="flex flex-col">
          {NAV.map((item) => {
            const active =
              currentPath === item.href ||
              currentPath.startsWith(item.href + "/");
            return (
              <li key={item.href}>
                <Link
                  href={item.href as never}
                  className={cn(
                    "flex items-center justify-between px-6 py-3 text-base",
                    "border-l-2 border-transparent",
                    active
                      ? "border-accent text-ink bg-surface-raised"
                      : "text-ink-muted hover:text-ink hover:bg-surface-raised",
                  )}
                >
                  <span>{item.label}</span>
                  {item.hotkey ? (
                    <span className="font-mono text-xs text-ink-muted">
                      {item.hotkey}
                    </span>
                  ) : null}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="px-6 py-5 border-t border-border-strong flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="text-xs uppercase tracking-wide text-ink-muted">
            Signed in
          </div>
          <div className="text-sm text-ink truncate" title={user?.email ?? ""}>
            {user?.email ?? "—"}
          </div>
        </div>
        <SignOutButton />
      </div>
    </aside>
  );
}
