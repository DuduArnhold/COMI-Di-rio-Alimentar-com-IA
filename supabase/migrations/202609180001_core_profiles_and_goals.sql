-- Core user data and historically effective nutrition goals.
create extension if not exists btree_gist with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.validate_iana_timezone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from pg_catalog.pg_timezone_names where name = new.timezone
  ) then
    raise exception 'Invalid IANA timezone: %', new.timezone using errcode = '22023';
  end if;
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  timezone text not null default 'America/Sao_Paulo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (
    display_name is null or char_length(btrim(display_name)) between 1 and 100
  )
);

create trigger profiles_validate_timezone
before insert or update of timezone on public.profiles
for each row execute function public.validate_iana_timezone();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table public.nutrition_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  effective_from date not null,
  effective_until date,
  energy_kcal numeric(8,2) not null,
  protein_g numeric(7,2) not null,
  carbohydrate_g numeric(7,2) not null,
  fat_g numeric(7,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nutrition_goals_valid_period check (
    effective_until is null or effective_until > effective_from
  ),
  constraint nutrition_goals_energy_range check (energy_kcal > 0 and energy_kcal <= 20000),
  constraint nutrition_goals_protein_range check (protein_g >= 0 and protein_g <= 2000),
  constraint nutrition_goals_carbohydrate_range check (carbohydrate_g >= 0 and carbohydrate_g <= 3000),
  constraint nutrition_goals_fat_range check (fat_g >= 0 and fat_g <= 2000),
  constraint nutrition_goals_no_overlap exclude using gist (
    user_id with =,
    daterange(effective_from, effective_until, '[)') with &&
  )
);

create index nutrition_goals_user_effective_from_idx
  on public.nutrition_goals (user_id, effective_from desc);

create trigger nutrition_goals_set_updated_at
before update on public.nutrition_goals
for each row execute function public.set_updated_at();
