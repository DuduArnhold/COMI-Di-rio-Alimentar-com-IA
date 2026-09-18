-- Source-agnostic nutrition catalog and food-specific household portions.
create table public.foods (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  brand text,
  source text not null,
  source_food_id text,
  source_version text,
  source_metadata jsonb not null default '{}'::jsonb,
  basis_unit text not null,
  energy_kcal_per_100 numeric(10,3) not null,
  protein_g_per_100 numeric(10,3) not null,
  carbohydrate_g_per_100 numeric(10,3) not null,
  fat_g_per_100 numeric(10,3) not null,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint foods_name_not_blank check (char_length(btrim(name)) between 1 and 200),
  constraint foods_normalized_name_not_blank check (char_length(btrim(normalized_name)) between 1 and 200),
  constraint foods_source_not_blank check (char_length(btrim(source)) between 1 and 100),
  constraint foods_source_food_id_not_blank check (
    source_food_id is null or char_length(btrim(source_food_id)) between 1 and 200
  ),
  constraint foods_basis_unit_allowed check (basis_unit in ('g', 'ml')),
  constraint foods_source_metadata_object check (jsonb_typeof(source_metadata) = 'object'),
  constraint foods_nutrients_nonnegative check (
    energy_kcal_per_100 >= 0 and protein_g_per_100 >= 0
    and carbohydrate_g_per_100 >= 0 and fat_g_per_100 >= 0
  ),
  constraint foods_ownership_consistent check (
    (owner_user_id is null and source <> 'user' and source_food_id is not null and is_verified)
    or
    (owner_user_id is not null and source = 'user' and source_food_id is null and not is_verified)
  )
);

create unique index foods_global_source_identity_uidx
  on public.foods (source, source_food_id, coalesce(source_version, ''))
  where owner_user_id is null;

create unique index foods_owner_name_brand_uidx
  on public.foods (owner_user_id, normalized_name, coalesce(lower(brand), ''))
  where owner_user_id is not null and is_active;

create index foods_global_normalized_name_idx
  on public.foods (normalized_name)
  where owner_user_id is null and is_active;

create index foods_owner_normalized_name_idx
  on public.foods (owner_user_id, normalized_name)
  where owner_user_id is not null;

create trigger foods_set_updated_at
before update on public.foods
for each row execute function public.set_updated_at();

create table public.food_portions (
  id uuid primary key default gen_random_uuid(),
  food_id uuid not null references public.foods(id) on delete cascade,
  label text not null,
  quantity numeric(10,3) not null default 1,
  unit text not null,
  canonical_quantity numeric(12,3) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_portions_label_not_blank check (char_length(btrim(label)) between 1 and 120),
  constraint food_portions_unit_not_blank check (char_length(btrim(unit)) between 1 and 40),
  constraint food_portions_positive_values check (quantity > 0 and canonical_quantity > 0),
  constraint food_portions_food_label_unique unique (food_id, label)
);

comment on column public.food_portions.canonical_quantity is
  'Amount in the parent food basis_unit (g or ml) represented by quantity + unit.';

create index food_portions_food_id_idx on public.food_portions (food_id);

create trigger food_portions_set_updated_at
before update on public.food_portions
for each row execute function public.set_updated_at();
