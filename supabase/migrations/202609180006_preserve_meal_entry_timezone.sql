-- Preserve the exact timezone used to derive each meal's historical local date.
alter table public.meals
  add column timezone_at_entry text;

update public.meals m
set timezone_at_entry = p.timezone
from public.profiles p
where p.id = m.user_id;

alter table public.meals
  alter column timezone_at_entry set not null;

create or replace function public.set_meal_local_date()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  profile_timezone text;
begin
  if tg_op = 'INSERT' then
    if new.timezone_at_entry is null then
      select p.timezone into profile_timezone
      from public.profiles p
      where p.id = new.user_id;

      if profile_timezone is null then
        raise exception 'Profile with timezone is required for meal owner' using errcode = '23503';
      end if;

      new.timezone_at_entry = profile_timezone;
    end if;

    if not exists (
      select 1 from pg_catalog.pg_timezone_names where name = new.timezone_at_entry
    ) then
      raise exception 'Invalid IANA timezone: %', new.timezone_at_entry using errcode = '22023';
    end if;

    new.local_date = (new.eaten_at at time zone new.timezone_at_entry)::date;
    return new;
  end if;

  if new.timezone_at_entry is distinct from old.timezone_at_entry then
    raise exception 'timezone_at_entry is immutable after meal creation' using errcode = '22023';
  end if;

  if new.user_id is distinct from old.user_id then
    raise exception 'Meal ownership is immutable' using errcode = '22023';
  end if;

  if new.eaten_at is distinct from old.eaten_at then
    new.local_date = (new.eaten_at at time zone old.timezone_at_entry)::date;
  elsif new.local_date is distinct from old.local_date then
    raise exception 'local_date is derived from eaten_at and timezone_at_entry' using errcode = '22023';
  end if;

  return new;
end;
$$;

drop trigger meals_set_local_date on public.meals;

create trigger meals_set_local_date
before insert or update of user_id, eaten_at, local_date, timezone_at_entry on public.meals
for each row execute function public.set_meal_local_date();

comment on column public.meals.timezone_at_entry is
  'Immutable IANA timezone used to derive local_date from eaten_at.';
