import { createClient } from "@/lib/supabase/server";
import { Sidebar } from "@/components/upb/sidebar";
import { headers } from "next/headers";
import { redirect } from "next/navigation";

export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/sign-in");
  }

  const h = await headers();
  const currentPath = h.get("x-url-pathname") ?? "/today";

  return (
    <div className="min-h-screen flex bg-surface text-ink">
      <Sidebar currentPath={currentPath} user={{ email: user.email }} />
      <main className="flex-1 min-w-0 px-7 py-7">{children}</main>
    </div>
  );
}
