import { PageHeader } from "./page-header";

export function ModulePlaceholder({
  title,
  summary,
  next,
}: {
  title: string;
  summary: string;
  next: string[];
}) {
  return (
    <div className="flex flex-col gap-7">
      <PageHeader title={title} meta={summary} />
      <section className="bg-surface-raised border border-border rounded-sm p-7">
        <div className="text-xs uppercase tracking-wide text-ink-muted mb-4">
          Not wired yet
        </div>
        <p className="text-base max-w-[640px]">
          The shell is in place. The module itself is scaffolded in a
          subsequent milestone.
        </p>
        <div className="mt-6">
          <div className="text-xs uppercase tracking-wide text-ink-muted mb-3">
            What ships next here
          </div>
          <ul className="flex flex-col gap-2 text-base">
            {next.map((line, i) => (
              <li
                key={i}
                className="border-l-2 border-border-strong pl-4 text-ink"
              >
                {line}
              </li>
            ))}
          </ul>
        </div>
      </section>
    </div>
  );
}
