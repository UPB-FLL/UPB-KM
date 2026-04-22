import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function PrepPage() {
  return (
    <ModulePlaceholder
      title="Prep"
      summary="Daily prep list — par-driven, forecast-driven, manual."
      next={[
        "Today's list with assignees, target batches, actual yield entry",
        "Completing a task writes a prep_batch and flows the ledger",
        "Forecast column once sales velocity data is imported",
      ]}
    />
  );
}
