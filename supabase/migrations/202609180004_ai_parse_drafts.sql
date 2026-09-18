-- Temporary AI parsing drafts. Nutrition values deliberately do not belong here.
create table public.ai_parse_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'processing',
  raw_input text,
  raw_input_expires_at timestamptz,
  confirmed_meal_id uuid references public.meals(id) on delete cascade,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_parse_sessions_status_allowed check (
    status in ('processing', 'needs_review', 'confirmed', 'rejected', 'failed')
  ),
  constraint ai_parse_sessions_raw_input_length check (
    raw_input is null or char_length(raw_input) <= 10000
  ),
  constraint ai_parse_sessions_raw_retention check (
    (raw_input is null and raw_input_expires_at is null)
    or
    (raw_input is not null and raw_input_expires_at is not null
      and raw_input_expires_at > created_at
      and raw_input_expires_at <= created_at + interval '30 days')
  ),
  constraint ai_parse_sessions_confirmation_consistent check (
    (status = 'confirmed' and confirmed_meal_id is not null)
    or
    (status <> 'confirmed' and confirmed_meal_id is null)
  ),
  constraint ai_parse_sessions_error_consistent check (
    (status = 'failed' and error_code is not null)
    or status <> 'failed'
  )
);

create or replace function public.set_raw_input_expiration()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at = now();
  elsif new.created_at is distinct from old.created_at then
    raise exception 'created_at is immutable' using errcode = '22023';
  end if;
  if new.raw_input is null then
    new.raw_input_expires_at = null;
  elsif new.raw_input_expires_at is null then
    new.raw_input_expires_at = new.created_at + interval '30 days';
  end if;
  return new;
end;
$$;

create index ai_parse_sessions_user_created_at_idx
  on public.ai_parse_sessions (user_id, created_at desc);
create index ai_parse_sessions_raw_expiry_idx
  on public.ai_parse_sessions (raw_input_expires_at)
  where raw_input is not null;

create trigger ai_parse_sessions_set_updated_at
before update on public.ai_parse_sessions
for each row execute function public.set_updated_at();

create trigger ai_parse_sessions_set_raw_expiration
before insert or update of raw_input, raw_input_expires_at, created_at on public.ai_parse_sessions
for each row execute function public.set_raw_input_expiration();

create table public.ai_parse_items (
  id uuid primary key default gen_random_uuid(),
  parse_session_id uuid not null references public.ai_parse_sessions(id) on delete cascade,
  raw_label text not null,
  interpreted_name text not null,
  quantity numeric(12,3),
  unit text,
  matched_food_id uuid references public.foods(id) on delete set null,
  confidence numeric(4,3) not null,
  needs_clarification boolean not null default false,
  uncertainty_reason text,
  alternatives jsonb not null default '[]'::jsonb,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_parse_items_raw_label_not_blank check (char_length(btrim(raw_label)) between 1 and 300),
  constraint ai_parse_items_interpreted_name_not_blank check (char_length(btrim(interpreted_name)) between 1 and 200),
  constraint ai_parse_items_quantity_positive check (quantity is null or quantity > 0),
  constraint ai_parse_items_unit_consistent check (
    (quantity is null and unit is null)
    or
    (quantity is not null and unit is not null and char_length(btrim(unit)) between 1 and 40)
  ),
  constraint ai_parse_items_confidence_range check (confidence >= 0 and confidence <= 1),
  constraint ai_parse_items_uncertainty_consistent check (
    (needs_clarification and uncertainty_reason is not null and char_length(btrim(uncertainty_reason)) > 0)
    or
    (not needs_clarification)
  ),
  constraint ai_parse_items_alternatives_array check (jsonb_typeof(alternatives) = 'array'),
  constraint ai_parse_items_sort_order_nonnegative check (sort_order >= 0),
  constraint ai_parse_items_order_unique unique (parse_session_id, sort_order)
);

create index ai_parse_items_session_idx on public.ai_parse_items (parse_session_id);
create index ai_parse_items_matched_food_idx on public.ai_parse_items (matched_food_id)
  where matched_food_id is not null;

create trigger ai_parse_items_set_updated_at
before update on public.ai_parse_items
for each row execute function public.set_updated_at();

-- A foreign key proves existence, but not that a referenced custom food belongs
-- to the same user. These trigger checks close that cross-tenant reference gap.
create or replace function public.assert_owned_food_reference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  record_owner uuid;
  referenced_food_id uuid;
begin
  if tg_table_name = 'meal_items' then
    select m.user_id into record_owner from public.meals m where m.id = new.meal_id;
    referenced_food_id := new.food_id;
  elsif tg_table_name = 'saved_meal_items' then
    select sm.user_id into record_owner from public.saved_meals sm where sm.id = new.saved_meal_id;
    referenced_food_id := new.food_id;
  elsif tg_table_name = 'ai_parse_items' then
    select aps.user_id into record_owner from public.ai_parse_sessions aps where aps.id = new.parse_session_id;
    referenced_food_id := new.matched_food_id;
  else
    raise exception 'Unsupported ownership validation table';
  end if;

  if record_owner is null then
    raise exception 'Owning parent does not exist' using errcode = '23503';
  end if;

  if referenced_food_id is not null and not exists (
    select 1 from public.foods f
    where f.id = referenced_food_id
      and ((f.owner_user_id is null and f.is_active) or f.owner_user_id = record_owner)
  ) then
    raise exception 'Food is not visible to the owning user' using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function public.assert_confirmed_meal_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.confirmed_meal_id is not null and not exists (
    select 1 from public.meals m
    where m.id = new.confirmed_meal_id and m.user_id = new.user_id and m.deleted_at is null
  ) then
    raise exception 'Confirmed meal must belong to the parse-session owner' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger meal_items_validate_food_owner
before insert or update of meal_id, food_id on public.meal_items
for each row execute function public.assert_owned_food_reference();

create trigger saved_meal_items_validate_food_owner
before insert or update of saved_meal_id, food_id on public.saved_meal_items
for each row execute function public.assert_owned_food_reference();

create trigger ai_parse_items_validate_food_owner
before insert or update of parse_session_id, matched_food_id on public.ai_parse_items
for each row execute function public.assert_owned_food_reference();

create trigger ai_parse_sessions_validate_confirmed_meal
before insert or update of user_id, confirmed_meal_id on public.ai_parse_sessions
for each row execute function public.assert_confirmed_meal_owner();

revoke all on function public.assert_owned_food_reference() from public;
revoke all on function public.assert_confirmed_meal_owner() from public;
