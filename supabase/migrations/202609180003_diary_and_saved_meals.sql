-- Confirmed diary records, immutable nutrition snapshots, templates, and weight.
create or replace function public.set_meal_local_date()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  profile_timezone text;
begin
  select p.timezone into profile_timezone
  from public.profiles p
  where p.id = new.user_id;

  if profile_timezone is null then
    raise exception 'Profile with timezone is required for meal owner' using errcode = '23503';
  end if;

  if tg_op = 'INSERT' or new.eaten_at is distinct from old.eaten_at or new.user_id is distinct from old.user_id then
    new.local_date = (new.eaten_at at time zone profile_timezone)::date;
  elsif new.local_date is distinct from old.local_date then
    raise exception 'local_date is derived from eaten_at and the profile timezone' using errcode = '22023';
  end if;
  return new;
end;
$$;

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  meal_type text not null,
  eaten_at timestamptz not null,
  local_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint meals_type_allowed check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'other')),
  constraint meals_notes_length check (notes is null or char_length(notes) <= 2000),
  constraint meals_deleted_after_creation check (deleted_at is null or deleted_at >= created_at)
);

create trigger meals_set_local_date
before insert or update of user_id, eaten_at, local_date on public.meals
for each row execute function public.set_meal_local_date();

create trigger meals_set_updated_at
before update on public.meals
for each row execute function public.set_updated_at();

create index meals_user_local_date_idx
  on public.meals (user_id, local_date, eaten_at)
  where deleted_at is null;

create table public.meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals(id) on delete cascade,
  food_id uuid references public.foods(id) on delete set null,
  display_name text not null,
  entered_quantity numeric(12,3) not null,
  entered_unit text not null,
  canonical_quantity numeric(12,3) not null,
  canonical_unit text not null,
  energy_kcal_snapshot numeric(10,3) not null,
  protein_g_snapshot numeric(10,3) not null,
  carbohydrate_g_snapshot numeric(10,3) not null,
  fat_g_snapshot numeric(10,3) not null,
  created_at timestamptz not null default now(),
  constraint meal_items_display_name_not_blank check (char_length(btrim(display_name)) between 1 and 200),
  constraint meal_items_entered_unit_not_blank check (char_length(btrim(entered_unit)) between 1 and 40),
  constraint meal_items_positive_quantities check (entered_quantity > 0 and canonical_quantity > 0),
  constraint meal_items_canonical_unit_allowed check (canonical_unit in ('g', 'ml')),
  constraint meal_items_snapshot_nonnegative check (
    energy_kcal_snapshot >= 0 and protein_g_snapshot >= 0
    and carbohydrate_g_snapshot >= 0 and fat_g_snapshot >= 0
  )
);

create index meal_items_meal_id_idx on public.meal_items (meal_id);
create index meal_items_food_id_idx on public.meal_items (food_id) where food_id is not null;

create or replace function public.prevent_meal_item_snapshot_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(
    new.food_id, new.display_name, new.entered_quantity, new.entered_unit,
    new.canonical_quantity, new.canonical_unit, new.energy_kcal_snapshot,
    new.protein_g_snapshot, new.carbohydrate_g_snapshot, new.fat_g_snapshot
  ) is distinct from row(
    old.food_id, old.display_name, old.entered_quantity, old.entered_unit,
    old.canonical_quantity, old.canonical_unit, old.energy_kcal_snapshot,
    old.protein_g_snapshot, old.carbohydrate_g_snapshot, old.fat_g_snapshot
  ) then
    raise exception 'Confirmed meal item snapshots are immutable; replace the item instead' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger meal_items_prevent_snapshot_update
before update on public.meal_items
for each row execute function public.prevent_meal_item_snapshot_update();

create table public.saved_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  default_meal_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint saved_meals_name_not_blank check (char_length(btrim(name)) between 1 and 120),
  constraint saved_meals_type_allowed check (
    default_meal_type is null or default_meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'other')
  ),
  constraint saved_meals_user_name_unique unique (user_id, name)
);

create trigger saved_meals_set_updated_at
before update on public.saved_meals
for each row execute function public.set_updated_at();

create table public.saved_meal_items (
  id uuid primary key default gen_random_uuid(),
  saved_meal_id uuid not null references public.saved_meals(id) on delete cascade,
  food_id uuid references public.foods(id) on delete set null,
  display_name text not null,
  entered_quantity numeric(12,3) not null,
  entered_unit text not null,
  canonical_quantity numeric(12,3) not null,
  canonical_unit text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint saved_meal_items_display_name_not_blank check (char_length(btrim(display_name)) between 1 and 200),
  constraint saved_meal_items_entered_unit_not_blank check (char_length(btrim(entered_unit)) between 1 and 40),
  constraint saved_meal_items_positive_quantities check (entered_quantity > 0 and canonical_quantity > 0),
  constraint saved_meal_items_canonical_unit_allowed check (canonical_unit in ('g', 'ml')),
  constraint saved_meal_items_sort_order_nonnegative check (sort_order >= 0),
  constraint saved_meal_items_order_unique unique (saved_meal_id, sort_order)
);

create index saved_meal_items_saved_meal_id_idx on public.saved_meal_items (saved_meal_id);

create trigger saved_meal_items_set_updated_at
before update on public.saved_meal_items
for each row execute function public.set_updated_at();

create table public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  measured_at timestamptz not null,
  weight_kg numeric(6,3) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint weight_logs_plausible_weight check (weight_kg > 0 and weight_kg <= 1000),
  constraint weight_logs_user_measured_at_unique unique (user_id, measured_at)
);

create index weight_logs_user_measured_at_idx on public.weight_logs (user_id, measured_at desc);

create trigger weight_logs_set_updated_at
before update on public.weight_logs
for each row execute function public.set_updated_at();
