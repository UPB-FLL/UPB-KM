import { signInWithEmail } from "./actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

type SearchParams = Promise<{ sent?: string; error?: string; next?: string }>;

export default async function SignInPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { sent, error, next } = await searchParams;

  return (
    <main className="min-h-screen grid place-items-center bg-surface px-5">
      <div className="w-full max-w-[420px] bg-surface-raised border border-border p-7">
        <h1 className="font-display text-display mb-2">Uncommon Path</h1>
        <p className="text-ink-muted text-base mb-7">
          Enter your email. We&apos;ll send a one-tap link.
        </p>

        {sent ? (
          <div
            className="border border-lichen text-ink bg-surface p-5 mb-5"
            role="status"
          >
            Check your email. The link expires in 60 minutes.
          </div>
        ) : null}

        {error ? (
          <div
            className="border border-rust text-rust p-5 mb-5"
            role="alert"
          >
            {error === "email"
              ? "Email required."
              : error === "send"
                ? "Couldn't send the link. Try again."
                : "Sign-in failed. Try again."}
          </div>
        ) : null}

        <form action={signInWithEmail} className="flex flex-col gap-5">
          <label className="flex flex-col gap-2">
            <span className="text-xs uppercase tracking-wide text-ink-muted">
              Email
            </span>
            <Input
              type="email"
              name="email"
              required
              autoComplete="email"
              inputMode="email"
              placeholder="you@uncommonpath.co"
            />
          </label>
          <input type="hidden" name="next" value={next ?? "/today"} />
          <Button type="submit">Send link</Button>
        </form>
      </div>
    </main>
  );
}
