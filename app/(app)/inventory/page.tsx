import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function InventoryPage() {
  return (
    <ModulePlaceholder
      title="Inventory"
      summary="SKUs, on-hand, par levels, sub-recipe items, waste log."
      next={[
        "SKU list with on-hand, par, last cost, trend sparkline",
        "Quick-adjust (count / waste) with ledger entry",
        "Per-SKU detail: conversion table, invoice history, waste history",
      ]}
    />
  );
}
