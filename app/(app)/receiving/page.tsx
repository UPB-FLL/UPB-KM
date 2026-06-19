import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function ReceivingPage() {
  return (
    <ModulePlaceholder
      title="Receiving"
      summary="Vendor invoices in; stock and cost out."
      next={[
        "Photo-first invoice entry with line-item capture",
        "Auto stock_adjustment + last_cost refresh on save",
        "OCR suggestion (non-authoritative) behind a human confirm",
      ]}
    />
  );
}
