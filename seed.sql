-- Uncommon Path Brewing — development seed
-- Idempotent: safe to re-run against an empty or freshly-migrated database.
-- Real auth.users rows are expected to be created via Supabase Auth; this
-- seed references them by a known uuid that you should replace for your
-- own dev environment.

begin;

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

insert into settings (id, name, timezone, default_target_margin)
values (true, 'Uncommon Path Brewing', 'America/Denver', 0.700)
on conflict (id) do update
  set name = excluded.name,
      timezone = excluded.timezone,
      default_target_margin = excluded.default_target_margin,
      updated_at = now();

-- ---------------------------------------------------------------------------
-- Global unit conversions (constants)
-- ---------------------------------------------------------------------------

insert into unit_conversions_global (from_unit, to_unit, factor) values
  ('lb','oz', 16),
  ('oz','lb', 0.0625),
  ('kg','g', 1000),
  ('g','kg', 0.001),
  ('kg','lb', 2.20462),
  ('lb','kg', 0.453592),
  ('gal','qt', 4),
  ('qt','gal', 0.25),
  ('gal','pt', 8),
  ('pt','gal', 0.125),
  ('gal','fl_oz', 128),
  ('fl_oz','gal', 0.0078125),
  ('qt','pt', 2),
  ('pt','qt', 0.5),
  ('l','ml', 1000),
  ('ml','l', 0.001),
  ('l','fl_oz', 33.814),
  ('fl_oz','ml', 29.5735)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Stations
-- ---------------------------------------------------------------------------

insert into stations (name, description) values
  ('Pizza Line', 'Wood-fired oven and makeline'),
  ('Cold Line', 'Salads, cold apps, dressings'),
  ('Bar', 'Taps, glassware, bar cooler'),
  ('Walk-in', 'Main walk-in cooler, produce rack'),
  ('Beer Cooler', 'Keg and packaged cooler')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Vendors
-- ---------------------------------------------------------------------------

insert into vendors (id, name, contact, phone, email) values
  ('11111111-1111-1111-1111-111111111001', 'Shamrock Foods', 'Dawn', '303-555-0101', 'orders@shamrock.example'),
  ('11111111-1111-1111-1111-111111111002', 'Mile High Produce', 'Pete', '303-555-0102', 'pete@mhproduce.example'),
  ('11111111-1111-1111-1111-111111111003', 'Front Range Flour Co.', 'Ana', '303-555-0103', 'ana@frfc.example'),
  ('11111111-1111-1111-1111-111111111004', 'Avery / Odell Distribution', 'Sam', '303-555-0104', 'sam@aodist.example')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Inventory items (raw + produced/sub-recipe SKUs)
-- ---------------------------------------------------------------------------

insert into inventory_items
  (id, sku, name, stock_unit, case_size, case_unit, par_level, last_cost, avg_cost, is_produced)
values
  -- Flour / pantry
  ('22222222-0000-0000-0000-000000000001', 'FLR-00', '00 Pizza Flour', 'lb', 55, 'lb', 110, 0.92, 0.92, false),
  ('22222222-0000-0000-0000-000000000002', 'SALT-01', 'Fine Sea Salt', 'lb', 25, 'lb', 10, 1.40, 1.40, false),
  ('22222222-0000-0000-0000-000000000003', 'YST-01', 'Instant Dry Yeast', 'lb', 1, 'lb', 2, 12.00, 12.00, false),
  ('22222222-0000-0000-0000-000000000004', 'OIL-EVOO', 'Extra Virgin Olive Oil', 'gal', 1, 'gal', 4, 28.00, 28.00, false),

  -- Dairy / meat
  ('22222222-0000-0000-0000-000000000010', 'CHE-MOZ', 'Fresh Mozzarella', 'lb', 10, 'lb', 30, 5.20, 5.20, false),
  ('22222222-0000-0000-0000-000000000011', 'CHE-PARM', 'Parmesan, wheel', 'lb', 1, 'lb', 6, 14.50, 14.50, false),
  ('22222222-0000-0000-0000-000000000012', 'PEP-01', 'Pepperoni Cup', 'lb', 10, 'lb', 20, 7.80, 7.80, false),

  -- Produce
  ('22222222-0000-0000-0000-000000000020', 'TOM-SAN', 'San Marzano Tomatoes, #10', 'case', 6, 'each', 2, 42.00, 42.00, false),
  ('22222222-0000-0000-0000-000000000021', 'BSL-FR', 'Basil, fresh', 'lb', 1, 'lb', 2, 12.00, 12.00, false),
  ('22222222-0000-0000-0000-000000000022', 'GAR-PL', 'Garlic, peeled', 'lb', 5, 'lb', 4, 6.50, 6.50, false),

  -- Produced sub-recipe SKUs (is_produced = true)
  ('22222222-1111-0000-0000-000000000001', 'DGH-NEO', 'Neapolitan Dough, 280g balls', 'each', null, null, 60, null, null, true),
  ('22222222-1111-0000-0000-000000000002', 'SCE-RED', 'Red Sauce', 'qt', null, null, 10, null, null, true),
  ('22222222-1111-0000-0000-000000000003', 'OIL-GAR', 'Garlic Oil', 'qt', null, null, 4, null, null, true),

  -- Beer (finished goods from the brewery side)
  ('22222222-2222-0000-0000-000000000001', 'BER-UPA', 'Uncommon Pale Ale, keg', 'gal', 15.5, 'gal', 31, 0.00, 0.00, false),
  ('22222222-2222-0000-0000-000000000002', 'BER-SIT', 'Side Trail IPA, keg', 'gal', 15.5, 'gal', 31, 0.00, 0.00, false)
on conflict (id) do nothing;

-- Per-item unit conversions (e.g. San Marzano case -> #10 cans)
insert into unit_conversions (inventory_item_id, from_unit, to_unit, factor) values
  ('22222222-0000-0000-0000-000000000020', 'case','each', 6),
  ('22222222-0000-0000-0000-000000000020', 'each','case', 0.16666667)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Recipes — a couple of sub-recipes and one menu item, all active
-- ---------------------------------------------------------------------------

insert into recipes
  (id, name, status, yield_qty, yield_unit, output_inventory_item_id, sell_price, target_margin)
values
  ('33333333-0000-0000-0000-000000000001',
   'Neapolitan Dough (20 lb batch)', 'active',
   60, 'each', '22222222-1111-0000-0000-000000000001',
   null, 0.800),
  ('33333333-0000-0000-0000-000000000002',
   'Red Sauce', 'active',
   4, 'qt', '22222222-1111-0000-0000-000000000002',
   null, 0.800),
  ('33333333-0000-0000-0000-000000000003',
   'Garlic Oil', 'active',
   1, 'qt', '22222222-1111-0000-0000-000000000003',
   null, 0.800),
  ('33333333-0000-0000-0000-000000000100',
   'Margherita Pizza', 'active',
   1, 'each', null, 17.00, 0.700),
  ('33333333-0000-0000-0000-000000000101',
   'Pepperoni Cup Pizza', 'active',
   1, 'each', null, 19.00, 0.700)
on conflict (id) do nothing;

-- Dough components (per 20 lb batch yielding 60 balls, rounded)
insert into recipe_items (recipe_id, inventory_item_id, qty, unit, sort_order) values
  ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 18,   'lb', 1),
  ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000002', 0.45, 'lb', 2),
  ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000003', 0.08, 'lb', 3)
on conflict do nothing;

-- Red sauce components
insert into recipe_items (recipe_id, inventory_item_id, qty, unit, sort_order) values
  ('33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000020', 2, 'each', 1),
  ('33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000002', 0.06, 'lb', 2),
  ('33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000022', 0.10, 'lb', 3)
on conflict do nothing;

-- Garlic oil
insert into recipe_items (recipe_id, inventory_item_id, qty, unit, sort_order) values
  ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000004', 1, 'qt', 1),
  ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000022', 0.25, 'lb', 2)
on conflict do nothing;

-- Margherita (uses two sub-recipes + mozz + basil)
insert into recipe_items (recipe_id, component_recipe_id, inventory_item_id, qty, unit, sort_order) values
  ('33333333-0000-0000-0000-000000000100', '33333333-0000-0000-0000-000000000001', null, 1,    'each', 1),
  ('33333333-0000-0000-0000-000000000100', '33333333-0000-0000-0000-000000000002', null, 0.25, 'qt',   2),
  ('33333333-0000-0000-0000-000000000100', null, '22222222-0000-0000-0000-000000000010', 0.3, 'lb', 3),
  ('33333333-0000-0000-0000-000000000100', null, '22222222-0000-0000-0000-000000000021', 0.015,'lb', 4)
on conflict do nothing;

-- Pepperoni cup (dough + red sauce + mozz + pepperoni)
insert into recipe_items (recipe_id, component_recipe_id, inventory_item_id, qty, unit, sort_order) values
  ('33333333-0000-0000-0000-000000000101', '33333333-0000-0000-0000-000000000001', null, 1,    'each', 1),
  ('33333333-0000-0000-0000-000000000101', '33333333-0000-0000-0000-000000000002', null, 0.25, 'qt',   2),
  ('33333333-0000-0000-0000-000000000101', null, '22222222-0000-0000-0000-000000000010', 0.3, 'lb', 3),
  ('33333333-0000-0000-0000-000000000101', null, '22222222-0000-0000-0000-000000000012', 0.2, 'lb', 4)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

insert into menus (id, name, description, starts_on, is_published)
values ('44444444-0000-0000-0000-000000000001',
        'Spring 2026 Dinner',
        'Core menu, wood-fired pizza side',
        date '2026-03-01', true)
on conflict (id) do nothing;

insert into menu_items (menu_id, recipe_id, sort_order, starts_on) values
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000100', 1, date '2026-03-01'),
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000101', 2, date '2026-03-01')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Line check templates (one per station, close shift)
-- ---------------------------------------------------------------------------

insert into line_check_templates (id, station_id, shift, name)
select '55555555-0000-0000-0000-000000000001', s.id, 'close', 'Pizza Line — Close'
  from stations s where s.name = 'Pizza Line'
on conflict (station_id, shift, name) do nothing;

insert into line_check_template_items (template_id, label, item_type, min_value, max_value, sort_order)
values
  ('55555555-0000-0000-0000-000000000001', 'Makeline reach-in temp (F)', 'temperature', 34, 40, 1),
  ('55555555-0000-0000-0000-000000000001', 'Dough walk-in temp (F)',     'temperature', 34, 40, 2),
  ('55555555-0000-0000-0000-000000000001', 'Oven deck swept',            'pass_fail',   null, null, 3),
  ('55555555-0000-0000-0000-000000000001', 'Dough pans labeled & dated', 'pass_fail',   null, null, 4),
  ('55555555-0000-0000-0000-000000000001', 'Station photo',              'photo',       null, null, 5),
  ('55555555-0000-0000-0000-000000000001', 'Closer signature',           'signature',   null, null, 6)
on conflict do nothing;

commit;
