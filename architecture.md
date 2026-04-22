# Uncommon Path Brewing — Back-of-House System Architecture

> A single-tenant back-of-house platform for a nano brewery + pizza kitchen.
> Inventory, recipes, food costing, prep lists, line checks, receiving, users.

---

## 1. Goals and non-goals

### Goals
- Give the owner/manager a single source of truth for **what we have, what it cost, and what we are making**.
- Give the kitchen a fast, touch-first tool for **prep, line checks, and receiving**.
- Keep **plate cost and margin live** against the current cost of goods — the day invoices land, menu math updates.
- Be operable on an iPad on the pizza line, a phone at the walk-in, and a laptop in the office.
- Stay shippable in small, useful increments. Every milestone has to earn its keep on its own.

### Non-goals (for now)
- POS / front-of-house ordering. We read sales data in, we do not take orders.
- Accounting. We export to CSV; QuickBooks integration is post-v1.
- Multi-location / multi-tenant. The schema is structured so that adding an `organization_id` later is mechanical, but v1 is single-org.
- Brewery production traceability (BCOP, batch genealogy). The brewing side only appears as finished-good inventory and ingredients consumed.
- Employee scheduling, payroll, tips.

---

## 2. Stack

| Layer | Choice | Why |
|------|--------|-----|
| Database | **Supabase Postgres** | Given. Strong relational model fits recipes/inventory/invoices; RLS maps cleanly to role-based access. |
| Auth | **Supabase Auth (email + magic link)** | One-tap login on shared iPads; no password resets at 6am. |
| File storage | **Supabase Storage** | Invoice photos, line-check photos, recipe photos. One private bucket per concern. |
| API | **PostgREST + Edge Functions** | Most CRUD goes through PostgREST + RLS. Edge Functions handle cost rollups, forecasting, invoice OCR. |
| Web client | **Next.js 15 (App Router) + React Server Components** | Server-rendered tables for speed, client components only where interactive. PWA-installable. |
| UI | **Tailwind + shadcn/ui base, overridden by the UPB design system** | Fast to build; overridden so it does not look like every other SaaS. |
| Forms & validation | **React Hook Form + Zod**, Zod schemas shared with Edge Functions | One source of truth for validation. |
| Realtime | **Supabase Realtime** on `prep_tasks`, `line_checks`, `invoices` | Two cooks on the same prep list should not fight each other. |
| Hosting | **Vercel** (web) + **Supabase** (db/auth/storage/functions) | Minimal ops. |
| Observability | Vercel Analytics + Supabase logs + Sentry | Enough for a single business. |

### Why not a separate Node/Express API
A custom backend is extra surface area we do not need. RLS + typed PostgREST + a handful of Edge Functions for the non-trivial stuff (cost rollup, forecast, OCR) keeps the moving parts low. If we outgrow this, we lift Edge Functions to a dedicated service; the schema does not change.

---

## 3. Modules and responsibilities

```
┌────────────────────────────────────────────────────────────────────┐
│                          Web client (Next.js)                          │
│ Dashboard · Inventory · Recipes · Design · Prep · Line Checks · Receiving │
└───────────────┬────────────────────────────────────┬───────────────────┘
              │ PostgREST (typed)                  │ Edge Functions
              ▼                                    ▼
┌─────────────────────────────────┐  ┌────────────────────────────┐
│      Postgres (Supabase)        │  │  cost_rollup               │
│  RLS by role + org              │  │  prep_forecast             │
│  Triggers:                      │  │  invoice_ocr               │
│   - recipe_cost_recalc          │  │  low_stock_digest          │
│   - stock_adjustment_on_receive │  └────────────────────────────┘
│   - waste_adjustment            │
└─────────────────────────────────┘
              ▲
              │
    ┌─────────┴──────────┐
    │  Supabase Storage  │  invoices/ · line-checks/ · recipes/
    └────────────────────┘
```

### 3.1 Inventory
- Canonical entity: `inventory_items` (SKUs). Every SKU has a **stock unit** (`lb`, `gal`, `each`, `case`).
- `unit_conversions` lets recipes express `3 oz` of a SKU stocked in `lb`.
- **Sub-recipes are inventory.** A 20 lb batch of dough is both a recipe output and an SKU you can count and waste. This is the single most important modeling decision in the system.
- Stock is a derived quantity: `current_stock = sum(stock_adjustments.qty)` per SKU. A denormalized `on_hand` is kept fresh by trigger for speed; a weekly reconciliation job verifies it against the ledger.
- Par levels are stored per SKU and feed the prep-list generator and the low-stock digest.

### 3.2 Recipes & Food Costing
- `recipes` has: yield qty, yield unit, sell price (nullable for sub-recipes), target margin.
- `recipe_items` can reference **an inventory SKU or another recipe** (sub-recipe). One row, one or the other, enforced by check constraint.
- Plate cost = Σ (item qty in stock unit × latest unit cost). Sub-recipes recurse to their own cost per yield unit.
- Computed by `cost_rollup` Edge Function on invoice save (costs changed) or recipe save (composition changed). Result written to `recipes.last_computed_cost` + `cost_computed_at`. We do not do it on every read.
- Suggested menu price = `last_computed_cost / (1 - target_margin)` rounded to whole dollars. Displayed alongside the cook's actual `sell_price`.
- `recipes.status` (`draft`/`testing`/`active`/`retired`) controls downstream visibility. Prep lists, line-cook views, and menus only see `active`. See §3.7 for the full lifecycle.

### 3.3 Prep Lists
- A `prep_list` is a dated worksheet. Tasks can be:
  - **Par-driven** (generated): `par - on_hand`, converted into batches of the relevant recipe.
  - **Forecast-driven**: `forecast_sales - on_hand` for items with sales velocity data.
  - **Manual**: the kitchen lead drops in a task.
- Assignees pulled from `users` with role `kitchen_lead` or `line_cook`.
- Completing a prep task with a linked recipe creates a `prep_batch`, which creates a positive `stock_adjustment` on the output SKU and negative adjustments on the component SKUs. The ledger stays honest.

### 3.4 Line Checks
- Templates are per-station (`stations` table: pizza line, cold line, bar, walk-in, beer cooler).
- A template is a sequence of `line_check_template_items` of type: `pass_fail`, `temperature`, `photo`, `numeric`, `text`, `signature`.
- A `line_check` instance belongs to a station, a shift (open/mid/close), a user, and a timestamp. Responses hang off it.
- Out-of-range temps flag the check as `failed` and surface to the manager dashboard. A failed check cannot be closed without a corrective-action note.

### 3.5 Invoices & Receiving
- A receiving session logs a vendor invoice: invoice #, date, photo, line items.
- Line items match to `inventory_items` via vendor SKU code (stored on `vendor_items`, an edge table between vendors and SKUs).
- On save, each line writes:
  1. A `stock_adjustment` (+qty, source = 'receiving').
  2. An update to `inventory_items.last_cost` and `avg_cost` (rolling-30-day, weighted).
- `recipes.last_computed_cost` is invalidated for every recipe touching a changed SKU. A background rollup refills it. UIs show `stale` until rollup completes (usually < 2s).

### 3.6 Users & Roles
Four roles; permissions are per-module, not per-table-column.

| Role | Inventory | Recipes | Prep | Line Checks | Receiving | Users |
|------|-----------|---------|------|-------------|-----------|-------|
| owner | full | full | full | full | full | full |
| manager | full | full | full | full | full | view |
| kitchen_lead | view + adjust | view + suggest | full | full | full | — |
| line_cook | view own station | view (no costs) | own tasks | own checks | — | — |

"view (no costs)" is enforced at the view layer: line cooks query `recipes_public` which omits cost columns. RLS backs this up.

### 3.7 Design Management
The "design" layer is where a recipe moves from idea to menu item. It is split off from day-to-day recipe editing because the rhythm is different — R&D is slow, exploratory, and needs gates; the line needs a clean, approved catalog.

- **Status column on `recipes`**: `draft` → `testing` → `active` → `retired`. Only `active` rows feed prep lists, line-cook views, and the public menu. `draft` and `testing` are invisible to line cooks; `retired` is hidden from new work but kept for history.
- **`recipe_versions`**: every `active` → `active` edit, and every `testing` → `active` promotion, snapshots the full recipe (composition, yield, sell price, computed cost, margin, author, timestamp) into `recipe_versions`. One pinned version per recipe is the "menu truth"; others are history. This answers the M4 open question about version history.
- **`menus` and `menu_items`**: a `menu` is a named, dated set (e.g. "Spring 2026 Dinner", "Friday Pizza Special"). `menu_items` links a recipe version to a menu with an effective date range. A recipe can sit on multiple menus; a menu can contain recipes not yet promoted to `active`, so the menu doubles as a release plan.
- **Test kitchen batches**: cooking a `testing` recipe produces a `prep_batch` flagged `is_test = true`. Component SKUs still come out of stock (so R&D doesn't lie about inventory) but the output goes to a `test_kitchen` virtual location, not the line. Test cost is computed and attached to the draft for comparison against the target margin before approval.
- **Approval**: the `draft|testing` → `active` transition is restricted to `owner` and `manager`. The transition is a single Edge Function (`promote_recipe`) that snapshots to `recipe_versions`, flips the status, invalidates the cost cache, and — if a `menu_item` references the recipe — publishes it on its effective date.
- **Design assets**: each recipe owns optional plating photos, build diagrams, allergen tags, and plating notes. Stored in Supabase Storage under `recipes/{recipe_id}/`, served via signed URLs. Assets are versioned with the recipe: promoting a recipe version pins the assets of the moment.
- **Diff view**: the design screen shows the current `active` version side-by-side with the candidate, with cost/margin delta and a per-ingredient diff. This is the one place where a manager reviews a change before it hits the line.

Design Management is deliberately low-touch. It does not replace the quick recipe edit path for typos or price tweaks — those still update `recipes` directly and create a new `recipe_versions` row on save. It adds the gates, the history, and the staging ground around the decisions that matter.

The permissions table in §3.6 extends with a `Design` column:

| Role | Design |
|------|--------|
| owner | full |
| manager | full |
| kitchen_lead | draft + test, no promote |
| line_cook | — |

Line cooks never see the design surface; they query `recipes_active` (a view that filters `status = 'active'` and joins the pinned version).

---

## 4. Data flow — the three loops that matter

### 4.1 Money loop: receiving → cost → menu
```
Vendor invoice photo
   ↓ (manual entry or OCR suggestion)
invoices + invoice_items
   ↓ trigger
stock_adjustments (+) + inventory_items.last_cost ↑
   ↓ Edge Function: cost_rollup
recipes.last_computed_cost (for every affected recipe and any recipe using them as sub-recipes)
   ↓ view
Menu item shows new plate cost, new suggested price, new margin
```

### 4.2 Prep loop: par → tasks → stock
```
Nightly job: compare on_hand vs par, consult recent sales velocity
   ↓
Auto-generated prep_tasks on tomorrow's prep_list
   ↓ kitchen lead reviews, assigns, maybe adds manual tasks
Cook marks task complete with actual yield
   ↓
prep_batch row
   ↓ trigger
stock_adjustments: + output SKU, − each component SKU
```

### 4.3 Line loop: open → checks → close
```
Shift start: line_check instance created per station from template
   ↓
Cook walks the line, enters temps, snaps photos, taps pass/fail
   ↓ any failure or out-of-range value
Dashboard alert to manager; corrective action required before close
   ↓ sign-off
Check closed; historical log for health inspector and trend reporting
```

---

## 5. Key design decisions (and the trade-offs)

### 5.1 Sub-recipes are full inventory items
Most systems model "preps" as a separate thing. We collapse them: dough, pizza sauce, ranch, pickled peppers are `inventory_items` with `is_produced = true`. They have par levels, they get counted, they accumulate waste. The trade-off is that creating a recipe means also creating an SKU. We hide that behind a single "Create prep recipe" flow in the UI that does both.

**Why:** it makes prep lists, food cost, and waste all use the same math. No special cases.

### 5.2 Stock is a ledger, with a denormalized cache
`stock_adjustments` is append-only. `inventory_items.on_hand` is a cached sum kept current by trigger. We reconcile weekly. The trade-off is two places that can drift — but the ledger is always the truth, and a cache miss just means a re-sum.

**Why:** counting physical inventory against a sum-of-adjustments is the only story that holds up during an audit.

### 5.3 RLS does the heavy lifting for permissions
Every table has `select`, `insert`, `update`, `delete` policies keyed off `auth.uid()` and a `user_roles` lookup. The client can talk to PostgREST directly and still be safe. The trade-off is policy complexity — we keep them readable with helper functions (`is_owner()`, `is_manager_or_above()`, `can_see_costs()`).

**Why:** a line cook losing a phone on Friday night cannot leak cost data. The database refuses.

### 5.4 Unit conversions are per-item, not global
Flour and water both measure in grams, but a "case" of beer is 24 cans, a "case" of pepperoni is 10 lb, a "case" of canned tomatoes is six #10 cans. Case size lives on the item, not on a global conversion table. Global conversions (`lb` ↔ `oz`, `gal` ↔ `fl_oz`) are constants.

**Why:** vendors change case sizes constantly. We need to update one row, not a conversion table.

### 5.5 Cost is computed, not stored on recipe_items
`recipe_items` stores qty + unit + reference. Cost is derived at rollup time. Storing cost per line item means updating 10,000 rows every time flour goes up a nickel.

**Why:** cost drifts. The reference is what we want.

### 5.6 Touch-first UI, keyboard-second
Every primary action has a target area ≥ 48px. Line cooks wear gloves and work on iPads mounted on stainless. The desktop case (manager in the office) gets keyboard shortcuts and a denser layout, but the touch version is the canonical one.

### 5.7 Offline tolerance, not offline-first
Line checks and prep lists tolerate a dropped connection: responses queue in IndexedDB and sync on reconnect. We do not attempt full offline mode — invoices and recipes need server round-trips. The walk-in is where connectivity dies; that is also where line checks happen.

### 5.8 One org, built for more
Every domain table carries no `organization_id` today. The schema has a `settings` singleton that will become `organizations` in the first multi-tenant migration. RLS policies are written against that singleton so adding a tenant column later is mechanical.

---

## 6. Environments

- **local**: Supabase CLI, seeded with `schema.sql` + `seed.sql`. Stripe/email services mocked.
- **staging**: Real Supabase project, anonymized seed. Deployed on every PR merge to `main`.
- **prod**: Real Supabase project. Deployed on tagged release. Daily point-in-time backups via Supabase; weekly export to S3.

---

## 7. What lives outside the database

- **Invoice photos, line-check photos, recipe photos** → Supabase Storage, private buckets, signed URLs.
- **Background jobs** (nightly prep generation, weekly reconciliation, cost rollup debounce) → Supabase scheduled Edge Functions (pg_cron).
- **OCR for invoices** → Edge Function calls a vision model, returns a suggested `invoice_items[]`. The human confirms before save. OCR is never authoritative.

---

## 8. Open questions (to answer before / during M1)

1. Sales data source — POS CSV import, or direct integration (Toast/Square)? Forecasting depends on it.
2. ~~Do we need recipe version history (M4) or does "last edit wins" hold for now?~~ Answered in §3.7: `recipe_versions` snapshots on every active-state save and on promotion.
3. Line-cook visibility of sell price — yes or no? (Leaning no; they see cost-hidden recipe cards.)
4. Tax handling on invoices — per-line or per-invoice? (Leaning per-invoice, allocated pro-rata into cost.)
5. Waste reasons — free text or controlled vocabulary? (Leaning controlled: spoilage, over-prep, dropped, comp, staff meal.)
