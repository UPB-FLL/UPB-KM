# Uncommon Path — Back of House

Inventory, recipes, prep, line checks, receiving. Single-tenant, Next.js 15
on Supabase. See `architecture.md` for the long-form design and
`design-system.md` for the visual vocabulary.

## What's in the tree

```
architecture.md           Long-form system design
design-system.md          Visual + interaction vocabulary
schema.sql                Human-readable canonical schema
seed.sql                  Human-readable canonical seed

supabase/
  config.toml             Supabase CLI config (ports, auth, edge)
  migrations/
    20260422000000_initial_schema.sql   Applied by `supabase db push`
  seed.sql                Applied by `supabase db seed`
  templates/magic_link.html

app/                      Next.js 15 App Router
  layout.tsx              Fonts + design tokens
  page.tsx                → redirects to /today
  sign-in/                Public: magic-link request
  auth/callback/          Public: code → session exchange
  (app)/                  Protected route group
    layout.tsx            Sidebar + user context
    today/                Dashboard (placeholder stat cards)
    inventory/ recipes/ design/ prep/ line-checks/ receiving/ users/

components/
  ui/                     Primitives (button, input, card)
  upb/                    Opinionated compositions (sidebar, stat-card, …)

lib/supabase/
  client.ts server.ts middleware.ts   @supabase/ssr wrappers
lib/utils.ts              `cn()` helper

middleware.ts             Session refresh + protected-route gate
tailwind.config.ts        Design tokens wired to Tailwind
app/globals.css           Token definitions + night-mode swap
```

## Local development

```bash
# 1. Install
npm install

# 2. Start Supabase locally (requires the Supabase CLI)
supabase start

# 3. Apply migrations + seed
supabase db reset          # wipes local, re-applies migrations, runs seed

# 4. Copy env and fill in from `supabase status` output
cp .env.local.example .env.local
#   NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
#   NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
#   SUPABASE_SERVICE_ROLE_KEY=<from supabase status>
#   NEXT_PUBLIC_SITE_URL=http://localhost:3000

# 5. Run
npm run dev
```

Magic-link emails are captured by the local Inbucket server
(`http://127.0.0.1:54324`) — no real SMTP needed in development.

## Deploying to a real Supabase project

```bash
# 1. Create the project in the Supabase dashboard (cost confirmed with you
#    first: free tier is $0; shared Postgres is $25/mo per project).
# 2. Link the CLI to it:
supabase link --project-ref <your-project-ref>

# 3. Apply schema and seed
supabase db push        # runs supabase/migrations/*.sql against prod
supabase db seed        # runs supabase/seed.sql; skip in prod if unwanted

# 4. In the Supabase dashboard → Auth → URL Configuration:
#    Site URL         = https://<your-deploy>.vercel.app
#    Redirect URLs   += https://<your-deploy>.vercel.app/auth/callback
```

## Deploying to Vercel

1. Push the repo (already done on the feature branch).
2. In Vercel, **New Project → Import Git Repository** and pick this repo.
3. Framework preset: **Next.js** (auto-detected).
4. Environment variables — copy from your `.env.local`:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `NEXT_PUBLIC_SITE_URL` = your Vercel deploy URL
5. Deploy. The first build also runs `next lint` and `tsc --noEmit`.

## Conventions

- **Design system is the source of truth.** `design-system.md` governs
  colors, type, spacing, radius (capped at 4px), and density modes.
  Tailwind only exposes the tokens; raw hex belongs in `app/globals.css`.
- **Primitives don't know about business.** `components/ui/` stays generic;
  all UPB flavor lives in `components/upb/`.
- **Auth is magic-link only.** Passwords are explicitly out of scope.
- **Every protected route passes through `middleware.ts`.** The middleware
  both refreshes the session and guards `(app)/*`.
- **RLS is the first line of defense.** Do not rely on UI visibility; any
  query from the client is re-checked by Postgres policies in `schema.sql`.
