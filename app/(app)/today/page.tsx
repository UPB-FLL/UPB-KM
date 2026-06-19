import { PageHeader } from "@/components/upb/page-header";
import { StatCard } from "@/components/upb/stat-card";

export default function TodayPage() {
  const today = new Date().toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  return (
    <div className="flex flex-col gap-7">
      <PageHeader
        title="Today"
        meta={
          <>
            {today}
            <span className="mx-3 text-border-strong">·</span>
            Shell only — real numbers land with the Inventory, Prep, and
            Line-Check modules.
          </>
        }
      />

      <section>
        <div className="text-xs uppercase tracking-wide text-ink-muted mb-4">
          Money
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          <StatCard
            label="Avg plate cost"
            value="—"
            hint="Rolls up after the first invoice"
          />
          <StatCard
            label="Avg margin"
            value="—"
            hint="Target 70%"
          />
          <StatCard
            label="Stale recipes"
            value="—"
            intent="warning"
            hint="Cost cache out of date"
          />
          <StatCard
            label="Low stock"
            value="—"
            intent="danger"
            hint="Below par level"
          />
        </div>
      </section>

      <section>
        <div className="text-xs uppercase tracking-wide text-ink-muted mb-4">
          Kitchen
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          <StatCard label="Prep tasks open" value="—" />
          <StatCard
            label="Line checks open"
            value="—"
            hint="Cold / Pizza / Bar / Walk-in"
          />
          <StatCard
            label="Failed checks (7d)"
            value="—"
            intent="danger"
            hint="Corrective action required"
          />
          <StatCard
            label="Receiving this week"
            value="—"
            hint="Invoices + vendor count"
          />
        </div>
      </section>

      <section>
        <div className="text-xs uppercase tracking-wide text-ink-muted mb-4">
          Design
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          <StatCard
            label="In testing"
            value="—"
            hint="R&D recipes with test batches"
          />
          <StatCard label="Pending approval" value="—" />
          <StatCard
            label="Active menu items"
            value="—"
            hint="Published on current menu"
          />
          <StatCard
            label="Retired (30d)"
            value="—"
            hint="Pulled from service"
          />
        </div>
      </section>
    </div>
  );
}
