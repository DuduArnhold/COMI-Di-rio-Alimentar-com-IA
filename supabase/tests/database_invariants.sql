\set ON_ERROR_STOP on
\set user_a '10000000-0000-4000-8000-000000000001'
\set user_b '20000000-0000-4000-8000-000000000002'
\set global_food '30000000-0000-4000-8000-000000000001'
\set inactive_food '30000000-0000-4000-8000-000000000002'
\set food_a '30000000-0000-4000-8000-000000000003'
\set food_b '30000000-0000-4000-8000-000000000004'
\set meal_a '40000000-0000-4000-8000-000000000001'
\set meal_b '40000000-0000-4000-8000-000000000002'
\set meal_item_a '50000000-0000-4000-8000-000000000001'
\set saved_a '60000000-0000-4000-8000-000000000001'
\set saved_b '60000000-0000-4000-8000-000000000002'
\set parse_a '70000000-0000-4000-8000-000000000001'
\set parse_b '70000000-0000-4000-8000-000000000002'

begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is not true then
    raise exception 'ASSERTION FAILED: %', message;
  end if;
end;
$$;

create or replace function pg_temp.statement_fails(statement text)
returns boolean language plpgsql as $$
begin
  execute statement;
  return false;
exception when others then
  return true;
end;
$$;

-- Administrative fixture setup. Assertions below always switch to authenticated.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  (:'user_a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-a@example.invalid', '', now(), now(), now()),
  (:'user_b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-b@example.invalid', '', now(), now(), now());

insert into public.profiles (id, display_name, timezone) values
  (:'user_a', 'User A', 'America/Sao_Paulo'),
  (:'user_b', 'User B', 'UTC');

insert into public.foods (
  id, name, normalized_name, source, source_food_id, source_version,
  basis_unit, energy_kcal_per_100, protein_g_per_100,
  carbohydrate_g_per_100, fat_g_per_100, is_verified, is_active
) values
  (:'global_food', 'Global active', 'global active', 'test', 'active', '1', 'g', 100, 10, 20, 2, true, true),
  (:'inactive_food', 'Global inactive', 'global inactive', 'test', 'inactive', '1', 'g', 200, 20, 30, 3, true, false);

-- User A context.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'user_a', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Profiles: A sees/updates only A.
select pg_temp.assert_true((select count(*) from public.profiles) = 1, 'A must only read profile A');
update public.profiles set display_name = 'compromised' where id = :'user_b';
select pg_temp.assert_true(not exists (
  select 1 from public.profiles where id = :'user_b'
), 'profile B must remain invisible to A');

-- Historical goals: adjacent periods work; overlap fails; B cannot be targeted.
insert into public.nutrition_goals (
  user_id, effective_from, effective_until, energy_kcal, protein_g, carbohydrate_g, fat_g
) values
  (:'user_a', '2026-01-01', '2026-02-01', 2000, 120, 250, 60),
  (:'user_a', '2026-02-01', null, 2100, 125, 260, 65);
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.nutrition_goals (user_id,effective_from,effective_until,energy_kcal,protein_g,carbohydrate_g,fat_g) values (%L,%L,%L,2000,100,200,50)',
  :'user_a', '2026-01-15', '2026-02-15'
)), 'overlapping goals must fail');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.nutrition_goals (user_id,effective_from,energy_kcal,protein_g,carbohydrate_g,fat_g) values (%L,%L,2000,100,200,50)',
  :'user_b', '2027-01-01'
)), 'A must not insert a goal for B');

-- Foods: active global is visible, inactive global is hidden and global edits are blocked.
select pg_temp.assert_true((select count(*) from public.foods where id = :'global_food') = 1, 'active global food must be visible');
select pg_temp.assert_true((select count(*) from public.foods where id = :'inactive_food') = 0, 'inactive global food must be hidden');
update public.foods set name = 'hacked global' where id = :'global_food';
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.foods (owner_user_id,name,normalized_name,source,basis_unit,energy_kcal_per_100,protein_g_per_100,carbohydrate_g_per_100,fat_g_per_100) values (%L,''wrong owner'',''wrong owner'',''user'',''g'',1,1,1,1)',
  :'user_b'
)), 'A must not create a custom food for B');
insert into public.foods (
  id, owner_user_id, name, normalized_name, source, basis_unit,
  energy_kcal_per_100, protein_g_per_100, carbohydrate_g_per_100, fat_g_per_100
) values (:'food_a', :'user_a', 'Food A', 'food a', 'user', 'g', 100, 10, 20, 3);
insert into public.food_portions (food_id, label, quantity, unit, canonical_quantity)
values (:'food_a', '1 unidade', 1, 'unidade', 50);

-- Meal timezone: explicit zone wins; later profile change does not rewrite history.
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.meals (user_id,meal_type,eaten_at,local_date,timezone_at_entry) values (%L,''other'',now(),current_date,''Not/A_Timezone'')',
  :'user_a'
)), 'invalid IANA meal timezone must fail');
insert into public.meals (id, user_id, meal_type, eaten_at, local_date, timezone_at_entry)
values (:'meal_a', :'user_a', 'dinner', '2026-01-02 02:30:00+00', '1900-01-01', 'America/Sao_Paulo');
select pg_temp.assert_true((
  select local_date = date '2026-01-01' and timezone_at_entry = 'America/Sao_Paulo'
  from public.meals where id = :'meal_a'
), 'meal local_date must use timezone_at_entry');
update public.profiles set timezone = 'Asia/Tokyo' where id = :'user_a';
select pg_temp.assert_true((
  select local_date = date '2026-01-01' and timezone_at_entry = 'America/Sao_Paulo'
  from public.meals where id = :'meal_a'
), 'profile timezone change must not rewrite meal history');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'update public.meals set timezone_at_entry = ''UTC'' where id = %L', :'meal_a'
)), 'meal timezone_at_entry must be immutable');

-- Confirmed item uses an immutable snapshot.
insert into public.meal_items (
  id, meal_id, food_id, display_name, entered_quantity, entered_unit,
  canonical_quantity, canonical_unit, energy_kcal_snapshot,
  protein_g_snapshot, carbohydrate_g_snapshot, fat_g_snapshot
) values (:'meal_item_a', :'meal_a', :'global_food', 'Global active', 50, 'g', 50, 'g', 50, 5, 10, 1);
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'update public.meal_items set energy_kcal_snapshot = 999 where id = %L', :'meal_item_a'
)), 'confirmed snapshots must be immutable');

-- Templates, weight, and parse drafts owned by A.
insert into public.saved_meals (id, user_id, name) values (:'saved_a', :'user_a', 'Saved A');
insert into public.saved_meal_items (
  saved_meal_id, food_id, display_name, entered_quantity, entered_unit,
  canonical_quantity, canonical_unit
) values (:'saved_a', :'food_a', 'Food A', 1, 'unidade', 50, 'g');
insert into public.weight_logs (user_id, measured_at, weight_kg)
values (:'user_a', '2026-01-01 10:00:00+00', 70.250);
insert into public.ai_parse_sessions (id, user_id, raw_input)
values (:'parse_a', :'user_a', 'Food A');
insert into public.ai_parse_items (
  parse_session_id, raw_label, interpreted_name, quantity, unit,
  matched_food_id, confidence, needs_clarification
) values (:'parse_a', 'Food A', 'Food A', 1, 'unidade', :'food_a', 0.9, false);

-- Switch to B and prove every private parent/child is isolated.
reset role;
select pg_temp.assert_true((select display_name from public.profiles where id = :'user_b') = 'User B', 'A must not alter profile B');
select pg_temp.assert_true((select name from public.foods where id = :'global_food') = 'Global active', 'authenticated users must not alter global foods');
insert into public.meals (id, user_id, meal_type, eaten_at, local_date)
values (:'meal_b', :'user_b', 'lunch', '2026-01-02 12:00:00+00', '1900-01-01');
select pg_temp.assert_true((
  select timezone_at_entry = 'UTC' and local_date = date '2026-01-02'
  from public.meals where id = :'meal_b'
), 'missing entry timezone must fall back to profile timezone');
insert into public.saved_meals (id, user_id, name) values (:'saved_b', :'user_b', 'Saved B');
insert into public.ai_parse_sessions (id, user_id) values (:'parse_b', :'user_b');

set local role authenticated;
select set_config('request.jwt.claim.sub', :'user_b', true);

select pg_temp.assert_true((select count(*) from public.profiles where id = :'user_a') = 0, 'B must not read profile A');
select pg_temp.assert_true((select count(*) from public.nutrition_goals where user_id = :'user_a') = 0, 'B must not read goals A');
select pg_temp.assert_true((select count(*) from public.foods where id = :'food_a') = 0, 'B must not read custom food A');
select pg_temp.assert_true((select count(*) from public.food_portions where food_id = :'food_a') = 0, 'B must not read portions A');
select pg_temp.assert_true((select count(*) from public.meals where id = :'meal_a') = 0, 'B must not read meal A');
select pg_temp.assert_true((select count(*) from public.meal_items where meal_id = :'meal_a') = 0, 'B must not read meal items A');
select pg_temp.assert_true((select count(*) from public.saved_meals where id = :'saved_a') = 0, 'B must not read saved meal A');
select pg_temp.assert_true((select count(*) from public.saved_meal_items) = 0, 'B must not read saved items A');
select pg_temp.assert_true((select count(*) from public.weight_logs where user_id = :'user_a') = 0, 'B must not read weights A');
select pg_temp.assert_true((select count(*) from public.ai_parse_sessions where id = :'parse_a') = 0, 'B must not read parse session A');
select pg_temp.assert_true((select count(*) from public.ai_parse_items) = 0, 'B must not read parse items A');
update public.foods set name = 'B changed A food' where id = :'food_a';
update public.saved_meals set name = 'B changed A template' where id = :'saved_a';
update public.weight_logs set weight_kg = 999 where user_id = :'user_a';
update public.ai_parse_sessions set status = 'rejected' where id = :'parse_a';

select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.food_portions (food_id,label,quantity,unit,canonical_quantity) values (%L,''attack'',1,''unit'',1)', :'food_a'
)), 'B must not add a portion to private food A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.meal_items (meal_id,food_id,display_name,entered_quantity,entered_unit,canonical_quantity,canonical_unit,energy_kcal_snapshot,protein_g_snapshot,carbohydrate_g_snapshot,fat_g_snapshot) values (%L,%L,''attack'',1,''g'',1,''g'',1,1,1,1)',
  :'meal_a', :'global_food'
)), 'B must not add an item to meal A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.meal_items (meal_id,food_id,display_name,entered_quantity,entered_unit,canonical_quantity,canonical_unit,energy_kcal_snapshot,protein_g_snapshot,carbohydrate_g_snapshot,fat_g_snapshot) values (%L,%L,''attack'',1,''g'',1,''g'',1,1,1,1)',
  :'meal_b', :'food_a'
)), 'meal B must not reference private food A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.ai_parse_items (parse_session_id,raw_label,interpreted_name,matched_food_id,confidence) values (%L,''attack'',''attack'',%L,0.5)',
  :'parse_b', :'food_a'
)), 'parse B must not reference private food A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.saved_meal_items (saved_meal_id,display_name,entered_quantity,entered_unit,canonical_quantity,canonical_unit) values (%L,''attack'',1,''g'',1,''g'')',
  :'saved_a'
)), 'B must not add an item to template A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.weight_logs (user_id,measured_at,weight_kg) values (%L,now(),80)', :'user_a'
)), 'B must not add a weight for A');
select pg_temp.assert_true(pg_temp.statement_fails(format(
  'insert into public.ai_parse_items (parse_session_id,raw_label,interpreted_name,confidence) values (%L,''attack'',''attack'',0.5)', :'parse_a'
)), 'B must not add an item to parse session A');

-- Soft deletion keeps snapshots but hides the meal from active diary queries.
reset role;
select pg_temp.assert_true((select name from public.foods where id = :'food_a') = 'Food A', 'B must not alter private food A');
select pg_temp.assert_true((select name from public.saved_meals where id = :'saved_a') = 'Saved A', 'B must not alter template A');
select pg_temp.assert_true((select weight_kg from public.weight_logs where user_id = :'user_a') = 70.250, 'B must not alter weight A');
select pg_temp.assert_true((select status from public.ai_parse_sessions where id = :'parse_a') = 'processing', 'B must not alter parse session A');
update public.meals set deleted_at = now() where id = :'meal_a';
select pg_temp.assert_true((select count(*) from public.meal_items where id = :'meal_item_a') = 1, 'soft delete must preserve snapshot');

-- Catalog changes never alter a confirmed snapshot; hard food delete nulls only the reference.
update public.foods set energy_kcal_per_100 = 999 where id = :'global_food';
select pg_temp.assert_true((select energy_kcal_snapshot from public.meal_items where id = :'meal_item_a') = 50, 'catalog update must not change snapshot');
delete from public.foods where id = :'global_food';
select pg_temp.assert_true((
  select food_id is null and energy_kcal_snapshot = 50 from public.meal_items where id = :'meal_item_a'
), 'food deletion must preserve snapshot and null its reference');

-- Account deletion cascades all B-owned private data.
delete from auth.users where id = :'user_b';
select pg_temp.assert_true(not exists (select 1 from public.profiles where id = :'user_b'), 'account delete must remove profile B');
select pg_temp.assert_true(not exists (select 1 from public.meals where user_id = :'user_b'), 'account delete must remove meals B');
select pg_temp.assert_true(not exists (select 1 from public.saved_meals where user_id = :'user_b'), 'account delete must remove templates B');
select pg_temp.assert_true(not exists (select 1 from public.ai_parse_sessions where user_id = :'user_b'), 'account delete must remove parsing B');

rollback;
\echo 'Database invariant and two-user RLS tests passed.'
