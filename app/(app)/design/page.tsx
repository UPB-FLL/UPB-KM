import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function DesignPage() {
  return (
    <ModulePlaceholder
      title="Design"
      summary="Recipe R&D, version history, menu curation."
      next={[
        "Drafts board: draft / testing / active / retired",
        "Promote flow with version snapshot and cost/margin diff",
        "Menu builder: dated menu_items with effective ranges",
      ]}
    />
  );
}
