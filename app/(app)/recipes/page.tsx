import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function RecipesPage() {
  return (
    <ModulePlaceholder
      title="Recipes"
      summary="Active catalog, plate cost, margins, cook view."
      next={[
        "Active-only list with plate cost, margin, sell price, staleness",
        "Recipe detail: components, yield math, suggested price",
        "Cook view (no costs) rendered from the recipes_public view",
      ]}
    />
  );
}
