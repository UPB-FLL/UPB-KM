import { ModulePlaceholder } from "@/components/upb/placeholder";

export default function UsersPage() {
  return (
    <ModulePlaceholder
      title="Users"
      summary="Invite, role, station assignment."
      next={[
        "Invite by email → magic-link only, no passwords",
        "Role set: owner / manager / kitchen_lead / line_cook",
        "Per-station default for line cooks (controls their dashboard)",
      ]}
    />
  );
}
