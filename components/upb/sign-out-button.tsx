import { signOut } from "@/app/sign-in/actions";
import { Button } from "@/components/ui/button";

export function SignOutButton() {
  return (
    <form action={signOut}>
      <Button type="submit" variant="ghost" size="office">
        Sign out
      </Button>
    </form>
  );
}
