import { cn } from "@/lib/utils";

export function PageHeader({
  title,
  meta,
  actions,
  className,
}: {
  title: string;
  meta?: React.ReactNode;
  actions?: React.ReactNode;
  className?: string;
}) {
  return (
    <header
      className={cn(
        "flex items-end justify-between gap-6 pb-6 border-b border-border-strong",
        className,
      )}
    >
      <div>
        <h1 className="font-display text-display leading-none">{title}</h1>
        {meta ? <div className="text-ink-muted text-sm mt-3">{meta}</div> : null}
      </div>
      {actions ? <div className="flex items-center gap-4">{actions}</div> : null}
    </header>
  );
}
