import { cn } from "@/lib/utils";

type Intent = "neutral" | "success" | "danger" | "warning";

export function StatCard({
  label,
  value,
  delta,
  hint,
  intent = "neutral",
  numeric = true,
}: {
  label: string;
  value: string;
  delta?: string;
  hint?: string;
  intent?: Intent;
  numeric?: boolean;
}) {
  return (
    <div className="bg-surface-raised border border-border rounded-sm p-6">
      <div className="text-xs uppercase tracking-wide text-ink-muted">
        {label}
      </div>
      <div
        className={cn(
          "mt-3 leading-none",
          numeric ? "font-mono text-xl" : "font-display text-xl",
        )}
      >
        {value}
      </div>
      {delta ? (
        <div
          className={cn(
            "mt-4 text-sm font-mono",
            intent === "success" && "text-success",
            intent === "danger" && "text-danger",
            intent === "warning" && "text-warning",
            intent === "neutral" && "text-ink-muted",
          )}
        >
          {delta}
        </div>
      ) : null}
      {hint ? (
        <div className="mt-2 text-xs text-ink-muted">{hint}</div>
      ) : null}
    </div>
  );
}
