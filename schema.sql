-- Uncommon Path Brewing — Back-of-House schema
-- v1, single-org. An `organization_id` column and tenant-scoped RLS are a
-- mechanical future migration; see architecture.md §5.8.

set search_path = public;

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type user_role_t as enum ('owner', 'manager', 'kitchen_lead', 'line_cook');

create type stock_unit_t as enum (
  'lb','oz','g','kg','gal','qt','pt','fl_oz','ml','l','each','case'
);

create type adjustment_source_t as enum (
  'receiving','prep_batch','waste','count','transfer','manual'
);

create type waste_reason_t as enum (
  'spoilage','over_prep','dropped','comp','staff_meal','other'
);

create type recipe_status_t as enum ('draft','testing','active','retired');

create type shift_t as enum ('open','mid','close');

create type line_check_status_t as enum ('open','passed','failed','closed');

create type line_check_item_t as enum (
  'pass_fail','temperature','photo','numeric','text','signature'
);

create type prep_task_source_t as enum ('par','forecast','manual');
create type prep_task_status_t as enum ('todo','in_progress','done','skipped');

-- ---------------------------------------------------------------------------
-- Settings singleton (seed of a future `organizations` table)
-- ---------------------------------------------------------------------------

create table settings (
  id boolean primary key default true,
  name text not null,
  timezone text not null default 'America/Denver',
  default_target_margin numeric(4,3) not null default 0.700,
  updated_at timestamptz not null default now(),
  constraint settings_singleton check (id is true)
);

-- ---------------------------------------------------------------------------
-- Users & roles
-- ---------------------------------------------------------------------------

create table user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  display_name text,
  created_at timestamptz not null default now()
);

create table user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role user_role_t not null
);

create or replace function current_role_of(uid uuid) returns user_role_t
language sql stable security definer set search_path = public as $$
  select role from user_roles where user_id = uid
$$;

create or replace function is_owner() returns boolean
language sql stable as $$ select current_role_of(auth.uid()) = 'owner' $$;

create or replace function is_manager_or_above() returns boolean
language sql stable as $$ select current_role_of(auth.uid()) in ('owner','manager') $$;

create or replace function is_kitchen_lead_or_above() returns boolean
language sql stable as $$ select current_role_of(auth.uid()) in ('owner','manager','kitchen_lead') $$;

create or replace function can_see_costs() returns boolean
language sql stable as $$ select current_role_of(auth.uid()) in ('owner','manager','kitchen_lead') $$;

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

create table inventory_items (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  name text not null,
  description text,
  stock_unit stock_unit_t not null,
  case_size numeric(12,4),                 -- e.g. 10 lb per case, 24 per case
  case_unit stock_unit_t,                  -- nullable; unit inside a case
  par_level numeric(12,4),
  on_hand numeric(12,4) not null default 0, -- denormalized cache of ledger
  last_cost numeric(12,4),
  avg_cost numeric(12,4),                  -- rolling 30-day, weighted
  is_produced boolean not null default false, -- sub-recipes that are also SKUs
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index inventory_items_name_idx on inventory_items (name);
create index inventory_items_produced_idx on inventory_items (is_produced) where is_produced;

-- Per-SKU unit conversions for recipe math (e.g. 3 oz of a SKU stocked in lb).
-- Global conversions (lb<->oz, gal<->fl_oz) live in a constant table below.
create table unit_conversions (
  inventory_item_id uuid not null references inventory_items(id) on delete cascade,
  from_unit stock_unit_t not null,
  to_unit stock_unit_t not null,
  factor numeric(16,8) not null,           -- 1 from_unit = factor * to_unit
  primary key (inventory_item_id, from_unit, to_unit)
);

-- Global constants. Seeded, not user-editable.
create table unit_conversions_global (
  from_unit stock_unit_t not null,
  to_unit stock_unit_t not null,
  factor numeric(16,8) not null,
  primary key (from_unit, to_unit)
);

create table stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  qty numeric(12,4) not null,              -- positive or negative, in stock_unit
  source adjustment_source_t not null,
  source_ref uuid,                         -- receiving line, prep batch, etc.
  waste_reason waste_reason_t,
  note text,
  user_id uuid references auth.users(id),
  occurred_at timestamptz not null default now()
);
create index stock_adjustments_item_idx on stock_adjustments (inventory_item_id, occurred_at desc);
create index stock_adjustments_source_idx on stock_adjustments (source, source_ref);

create or replace function apply_stock_adjustment() returns trigger
language plpgsql as $$
begin
  update inventory_items
     set on_hand = on_hand + new.qty,
         updated_at = now()
   where id = new.inventory_item_id;
  return new;
end $$;

create trigger stock_adjustment_cache
after insert on stock_adjustments
for each row execute function apply_stock_adjustment();

-- ---------------------------------------------------------------------------
-- Recipes, Design Management, cost rollup
-- ---------------------------------------------------------------------------

create table recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status recipe_status_t not null default 'draft',
  yield_qty numeric(12,4) not null,
  yield_unit stock_unit_t not null,
  output_inventory_item_id uuid references inventory_items(id), -- sub-recipe SKU
  sell_price numeric(12,2),                -- nullable for sub-recipes
  target_margin numeric(4,3),              -- nullable => fall back to settings
  last_computed_cost numeric(12,4),
  cost_computed_at timestamptz,
  cost_stale boolean not null default true,
  pinned_version_id uuid,                  -- FK added below to recipe_versions
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index recipes_status_idx on recipes (status);

-- A recipe_item references either another recipe (sub-recipe) or an
-- inventory SKU. Enforced by a check constraint: exactly one of the two.
create table recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  inventory_item_id uuid references inventory_items(id) on delete restrict,
  component_recipe_id uuid references recipes(id) on delete restrict,
  qty numeric(12,4) not null,
  unit stock_unit_t not null,
  sort_order int not null default 0,
  note text,
  constraint recipe_item_xor check (
    (inventory_item_id is not null)::int + (component_recipe_id is not null)::int = 1
  ),
  constraint recipe_item_no_self_ref check (component_recipe_id is distinct from recipe_id)
);
create index recipe_items_recipe_idx on recipe_items (recipe_id);
create index recipe_items_item_idx on recipe_items (inventory_item_id);
create index recipe_items_component_idx on recipe_items (component_recipe_id);

-- Snapshots for Design Management. One row per save of an `active` recipe
-- and one per draft/testing -> active promotion.
create table recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  version_number int not null,
  composition jsonb not null,              -- full recipe_items snapshot
  yield_qty numeric(12,4) not null,
  yield_unit stock_unit_t not null,
  sell_price numeric(12,2),
  target_margin numeric(4,3),
  computed_cost numeric(12,4),
  margin numeric(6,4),
  status_at_snapshot recipe_status_t not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (recipe_id, version_number)
);

alter table recipes
  add constraint recipes_pinned_version_fk
  foreign key (pinned_version_id) references recipe_versions(id) on delete set null;

create table menus (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  starts_on date,
  ends_on date,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table menu_items (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references menus(id) on delete cascade,
  recipe_id uuid not null references recipes(id) on delete restrict,
  recipe_version_id uuid references recipe_versions(id) on delete set null,
  starts_on date,
  ends_on date,
  sort_order int not null default 0,
  sell_price_override numeric(12,2)
);
create index menu_items_menu_idx on menu_items (menu_id);

-- Recipe assets (plating photos, build diagrams) live in Supabase Storage.
-- Metadata here ties the asset to a recipe (and optionally a version).
create table recipe_assets (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  recipe_version_id uuid references recipe_versions(id) on delete set null,
  storage_path text not null,
  kind text not null check (kind in ('plating','diagram','allergen','other')),
  caption text,
  created_at timestamptz not null default now()
);
create index recipe_assets_recipe_idx on recipe_assets (recipe_id);

-- Views for cost-hidden and active-only catalogs.
create view recipes_public as
  select id, name, status, yield_qty, yield_unit, sell_price, updated_at
    from recipes;

create view recipes_active as
  select r.*
    from recipes r
   where r.status = 'active';

-- ---------------------------------------------------------------------------
-- Prep lists
-- ---------------------------------------------------------------------------

create table prep_lists (
  id uuid primary key default gen_random_uuid(),
  for_date date not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique (for_date)
);

create table prep_tasks (
  id uuid primary key default gen_random_uuid(),
  prep_list_id uuid not null references prep_lists(id) on delete cascade,
  recipe_id uuid references recipes(id),
  inventory_item_id uuid references inventory_items(id),
  batches numeric(8,2),
  target_qty numeric(12,4),
  target_unit stock_unit_t,
  source prep_task_source_t not null,
  status prep_task_status_t not null default 'todo',
  assigned_to uuid references auth.users(id),
  note text,
  sort_order int not null default 0,
  completed_at timestamptz,
  actual_yield numeric(12,4)
);
create index prep_tasks_list_idx on prep_tasks (prep_list_id);
create index prep_tasks_assignee_idx on prep_tasks (assigned_to);

create table prep_batches (
  id uuid primary key default gen_random_uuid(),
  prep_task_id uuid references prep_tasks(id) on delete set null,
  recipe_id uuid not null references recipes(id),
  recipe_version_id uuid references recipe_versions(id),
  actual_yield numeric(12,4) not null,
  is_test boolean not null default false,   -- R&D batch; goes to test_kitchen
  user_id uuid references auth.users(id),
  occurred_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Stations & line checks
-- ---------------------------------------------------------------------------

create table stations (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  description text,
  is_active boolean not null default true
);

create table line_check_templates (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations(id) on delete cascade,
  shift shift_t not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (station_id, shift, name)
);

create table line_check_template_items (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references line_check_templates(id) on delete cascade,
  label text not null,
  item_type line_check_item_t not null,
  min_value numeric(12,4),
  max_value numeric(12,4),
  is_required boolean not null default true,
  sort_order int not null default 0
);

create table line_checks (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations(id) on delete restrict,
  template_id uuid not null references line_check_templates(id) on delete restrict,
  shift shift_t not null,
  status line_check_status_t not null default 'open',
  user_id uuid references auth.users(id),
  started_at timestamptz not null default now(),
  closed_at timestamptz,
  corrective_action text
);
create index line_checks_station_shift_idx on line_checks (station_id, shift, started_at desc);

create table line_check_responses (
  id uuid primary key default gen_random_uuid(),
  line_check_id uuid not null references line_checks(id) on delete cascade,
  template_item_id uuid not null references line_check_template_items(id) on delete restrict,
  value_numeric numeric(12,4),
  value_text text,
  value_bool boolean,
  photo_path text,
  signature_path text,
  flagged boolean not null default false,
  answered_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Vendors, invoices, receiving
-- ---------------------------------------------------------------------------

create table vendors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact text,
  phone text,
  email citext,
  is_active boolean not null default true
);

create table vendor_items (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references vendors(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  vendor_sku text,
  pack_size numeric(12,4),
  pack_unit stock_unit_t,
  last_price numeric(12,4),
  unique (vendor_id, vendor_sku)
);

create table invoices (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references vendors(id) on delete restrict,
  invoice_number text,
  invoice_date date not null,
  photo_path text,
  subtotal numeric(12,2),
  tax numeric(12,2),
  total numeric(12,2),
  notes text,
  received_by uuid references auth.users(id),
  received_at timestamptz not null default now()
);
create index invoices_vendor_date_idx on invoices (vendor_id, invoice_date desc);

create table invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  qty numeric(12,4) not null,
  unit stock_unit_t not null,
  unit_price numeric(12,4) not null,
  line_total numeric(12,2) generated always as (qty * unit_price) stored,
  note text
);

-- On invoice_item insert: +stock adjustment, refresh last_cost, mark touched
-- recipes stale. The cost_rollup Edge Function picks the stale set up.
create or replace function invoice_item_on_insert() returns trigger
language plpgsql as $$
begin
  insert into stock_adjustments (inventory_item_id, qty, source, source_ref)
    values (new.inventory_item_id, new.qty, 'receiving', new.invoice_id);

  update inventory_items
     set last_cost = new.unit_price,
         updated_at = now()
   where id = new.inventory_item_id;

  update recipes r
     set cost_stale = true
   where exists (
     select 1 from recipe_items ri
      where ri.recipe_id = r.id and ri.inventory_item_id = new.inventory_item_id
   );

  return new;
end $$;

create trigger invoice_item_receiving
after insert on invoice_items
for each row execute function invoice_item_on_insert();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table settings                     enable row level security;
alter table user_profiles                enable row level security;
alter table user_roles                   enable row level security;
alter table inventory_items              enable row level security;
alter table unit_conversions             enable row level security;
alter table unit_conversions_global      enable row level security;
alter table stock_adjustments            enable row level security;
alter table recipes                      enable row level security;
alter table recipe_items                 enable row level security;
alter table recipe_versions              enable row level security;
alter table recipe_assets                enable row level security;
alter table menus                        enable row level security;
alter table menu_items                   enable row level security;
alter table prep_lists                   enable row level security;
alter table prep_tasks                   enable row level security;
alter table prep_batches                 enable row level security;
alter table stations                     enable row level security;
alter table line_check_templates         enable row level security;
alter table line_check_template_items    enable row level security;
alter table line_checks                  enable row level security;
alter table line_check_responses         enable row level security;
alter table vendors                      enable row level security;
alter table vendor_items                 enable row level security;
alter table invoices                     enable row level security;
alter table invoice_items                enable row level security;

-- Everyone signed in can read their profile; managers see all.
create policy user_profiles_self_read on user_profiles
  for select using (user_id = auth.uid() or is_manager_or_above());
create policy user_profiles_self_update on user_profiles
  for update using (user_id = auth.uid() or is_owner());
create policy user_profiles_owner_insert on user_profiles
  for insert with check (is_owner());

create policy user_roles_read on user_roles
  for select using (user_id = auth.uid() or is_manager_or_above());
create policy user_roles_owner_write on user_roles
  for all using (is_owner()) with check (is_owner());

create policy settings_read on settings for select using (auth.uid() is not null);
create policy settings_owner_write on settings
  for all using (is_owner()) with check (is_owner());

-- Inventory: all staff read. Line cooks cannot write except via prep/line-check
-- flows (those use definer functions). Kitchen lead + above can adjust.
create policy inventory_read on inventory_items for select using (auth.uid() is not null);
create policy inventory_write on inventory_items
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy unit_conversions_read on unit_conversions for select using (auth.uid() is not null);
create policy unit_conversions_write on unit_conversions
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy unit_conversions_global_read on unit_conversions_global
  for select using (auth.uid() is not null);
create policy unit_conversions_global_write on unit_conversions_global
  for all using (is_owner()) with check (is_owner());

create policy stock_adjustments_read on stock_adjustments for select using (auth.uid() is not null);
create policy stock_adjustments_write on stock_adjustments
  for insert with check (is_kitchen_lead_or_above() or source in ('prep_batch'));

-- Recipes: line cooks see only `active`. Costs are hidden via the
-- `recipes_public` view; RLS guards the base table for writes.
create policy recipes_read on recipes
  for select using (
    auth.uid() is not null
    and (is_kitchen_lead_or_above() or status = 'active')
  );
create policy recipes_write on recipes
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy recipe_items_read on recipe_items
  for select using (
    exists (
      select 1 from recipes r
       where r.id = recipe_items.recipe_id
         and (is_kitchen_lead_or_above() or r.status = 'active')
    )
  );
create policy recipe_items_write on recipe_items
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy recipe_versions_read on recipe_versions for select using (is_kitchen_lead_or_above());
create policy recipe_versions_write on recipe_versions
  for insert with check (is_manager_or_above());

create policy recipe_assets_read on recipe_assets for select using (auth.uid() is not null);
create policy recipe_assets_write on recipe_assets
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy menus_read on menus for select using (auth.uid() is not null);
create policy menus_write on menus
  for all using (is_manager_or_above()) with check (is_manager_or_above());

create policy menu_items_read on menu_items for select using (auth.uid() is not null);
create policy menu_items_write on menu_items
  for all using (is_manager_or_above()) with check (is_manager_or_above());

-- Prep lists: line cooks see and update their own tasks; leads see all.
create policy prep_lists_read on prep_lists for select using (auth.uid() is not null);
create policy prep_lists_write on prep_lists
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy prep_tasks_read on prep_tasks
  for select using (is_kitchen_lead_or_above() or assigned_to = auth.uid());
create policy prep_tasks_update_own on prep_tasks
  for update using (is_kitchen_lead_or_above() or assigned_to = auth.uid())
             with check (is_kitchen_lead_or_above() or assigned_to = auth.uid());
create policy prep_tasks_lead_insert on prep_tasks
  for insert with check (is_kitchen_lead_or_above());
create policy prep_tasks_lead_delete on prep_tasks
  for delete using (is_kitchen_lead_or_above());

create policy prep_batches_read on prep_batches for select using (auth.uid() is not null);
create policy prep_batches_insert on prep_batches
  for insert with check (auth.uid() is not null);

create policy stations_read on stations for select using (auth.uid() is not null);
create policy stations_write on stations
  for all using (is_manager_or_above()) with check (is_manager_or_above());

create policy lc_templates_read on line_check_templates for select using (auth.uid() is not null);
create policy lc_templates_write on line_check_templates
  for all using (is_manager_or_above()) with check (is_manager_or_above());
create policy lc_template_items_read on line_check_template_items for select using (auth.uid() is not null);
create policy lc_template_items_write on line_check_template_items
  for all using (is_manager_or_above()) with check (is_manager_or_above());

create policy line_checks_read on line_checks
  for select using (is_kitchen_lead_or_above() or user_id = auth.uid());
create policy line_checks_write on line_checks
  for all using (is_kitchen_lead_or_above() or user_id = auth.uid())
          with check (is_kitchen_lead_or_above() or user_id = auth.uid());

create policy lc_responses_read on line_check_responses
  for select using (
    exists (
      select 1 from line_checks c
       where c.id = line_check_responses.line_check_id
         and (is_kitchen_lead_or_above() or c.user_id = auth.uid())
    )
  );
create policy lc_responses_write on line_check_responses
  for all using (
    exists (
      select 1 from line_checks c
       where c.id = line_check_responses.line_check_id
         and (is_kitchen_lead_or_above() or c.user_id = auth.uid())
    )
  ) with check (
    exists (
      select 1 from line_checks c
       where c.id = line_check_responses.line_check_id
         and (is_kitchen_lead_or_above() or c.user_id = auth.uid())
    )
  );

-- Receiving is kitchen_lead + above.
create policy vendors_read on vendors for select using (auth.uid() is not null);
create policy vendors_write on vendors
  for all using (is_manager_or_above()) with check (is_manager_or_above());
create policy vendor_items_read on vendor_items for select using (auth.uid() is not null);
create policy vendor_items_write on vendor_items
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());

create policy invoices_read on invoices for select using (is_kitchen_lead_or_above());
create policy invoices_write on invoices
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());
create policy invoice_items_read on invoice_items for select using (is_kitchen_lead_or_above());
create policy invoice_items_write on invoice_items
  for all using (is_kitchen_lead_or_above()) with check (is_kitchen_lead_or_above());
