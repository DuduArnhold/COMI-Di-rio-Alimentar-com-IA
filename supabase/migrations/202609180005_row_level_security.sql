-- Explicit tenant isolation. No service-role policies are needed because that
-- role bypasses RLS and must never be used by ordinary application flows.

alter table public.profiles enable row level security;
alter table public.nutrition_goals enable row level security;
alter table public.foods enable row level security;
alter table public.food_portions enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.saved_meals enable row level security;
alter table public.saved_meal_items enable row level security;
alter table public.weight_logs enable row level security;
alter table public.ai_parse_sessions enable row level security;
alter table public.ai_parse_items enable row level security;

-- Profiles
create policy profiles_select_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy profiles_delete_own on public.profiles for delete to authenticated
  using ((select auth.uid()) = id);

-- Historical goals
create policy nutrition_goals_select_own on public.nutrition_goals for select to authenticated
  using ((select auth.uid()) = user_id);
create policy nutrition_goals_insert_own on public.nutrition_goals for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy nutrition_goals_update_own on public.nutrition_goals for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy nutrition_goals_delete_own on public.nutrition_goals for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Global foods are active read-only rows. Custom foods are private and mutable by their owner.
create policy foods_select_visible on public.foods for select to authenticated
  using ((owner_user_id is null and is_active) or owner_user_id = (select auth.uid()));
create policy foods_insert_custom_own on public.foods for insert to authenticated
  with check (owner_user_id = (select auth.uid()) and source = 'user' and not is_verified);
create policy foods_update_custom_own on public.foods for update to authenticated
  using (owner_user_id = (select auth.uid()))
  with check (owner_user_id = (select auth.uid()) and source = 'user' and not is_verified);
create policy foods_delete_custom_own on public.foods for delete to authenticated
  using (owner_user_id = (select auth.uid()));

-- Portions inherit visibility and mutability from their food.
create policy food_portions_select_visible on public.food_portions for select to authenticated
  using (exists (
    select 1 from public.foods f where f.id = food_id
      and ((f.owner_user_id is null and f.is_active) or f.owner_user_id = (select auth.uid()))
  ));
create policy food_portions_insert_custom_own on public.food_portions for insert to authenticated
  with check (exists (
    select 1 from public.foods f where f.id = food_id and f.owner_user_id = (select auth.uid())
  ));
create policy food_portions_update_custom_own on public.food_portions for update to authenticated
  using (exists (
    select 1 from public.foods f where f.id = food_id and f.owner_user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.foods f where f.id = food_id and f.owner_user_id = (select auth.uid())
  ));
create policy food_portions_delete_custom_own on public.food_portions for delete to authenticated
  using (exists (
    select 1 from public.foods f where f.id = food_id and f.owner_user_id = (select auth.uid())
  ));

-- Confirmed meals
create policy meals_select_own on public.meals for select to authenticated
  using (user_id = (select auth.uid()));
create policy meals_insert_own on public.meals for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy meals_update_own on public.meals for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy meals_delete_own on public.meals for delete to authenticated
  using (user_id = (select auth.uid()));

create policy meal_items_select_own on public.meal_items for select to authenticated
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid())));
create policy meal_items_insert_own on public.meal_items for insert to authenticated
  with check (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid()) and m.deleted_at is null));
create policy meal_items_update_own on public.meal_items for update to authenticated
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid()) and m.deleted_at is null))
  with check (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid()) and m.deleted_at is null));
create policy meal_items_delete_own on public.meal_items for delete to authenticated
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid()) and m.deleted_at is null));

-- Saved meal templates
create policy saved_meals_select_own on public.saved_meals for select to authenticated using (user_id = (select auth.uid()));
create policy saved_meals_insert_own on public.saved_meals for insert to authenticated with check (user_id = (select auth.uid()));
create policy saved_meals_update_own on public.saved_meals for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy saved_meals_delete_own on public.saved_meals for delete to authenticated using (user_id = (select auth.uid()));

create policy saved_meal_items_select_own on public.saved_meal_items for select to authenticated
  using (exists (select 1 from public.saved_meals sm where sm.id = saved_meal_id and sm.user_id = (select auth.uid())));
create policy saved_meal_items_insert_own on public.saved_meal_items for insert to authenticated
  with check (exists (select 1 from public.saved_meals sm where sm.id = saved_meal_id and sm.user_id = (select auth.uid())));
create policy saved_meal_items_update_own on public.saved_meal_items for update to authenticated
  using (exists (select 1 from public.saved_meals sm where sm.id = saved_meal_id and sm.user_id = (select auth.uid())))
  with check (exists (select 1 from public.saved_meals sm where sm.id = saved_meal_id and sm.user_id = (select auth.uid())));
create policy saved_meal_items_delete_own on public.saved_meal_items for delete to authenticated
  using (exists (select 1 from public.saved_meals sm where sm.id = saved_meal_id and sm.user_id = (select auth.uid())));

-- Weight
create policy weight_logs_select_own on public.weight_logs for select to authenticated using (user_id = (select auth.uid()));
create policy weight_logs_insert_own on public.weight_logs for insert to authenticated with check (user_id = (select auth.uid()));
create policy weight_logs_update_own on public.weight_logs for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy weight_logs_delete_own on public.weight_logs for delete to authenticated using (user_id = (select auth.uid()));

-- Parsing drafts
create policy ai_parse_sessions_select_own on public.ai_parse_sessions for select to authenticated using (user_id = (select auth.uid()));
create policy ai_parse_sessions_insert_own on public.ai_parse_sessions for insert to authenticated with check (user_id = (select auth.uid()));
create policy ai_parse_sessions_update_own on public.ai_parse_sessions for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy ai_parse_sessions_delete_own on public.ai_parse_sessions for delete to authenticated using (user_id = (select auth.uid()));

create policy ai_parse_items_select_own on public.ai_parse_items for select to authenticated
  using (exists (select 1 from public.ai_parse_sessions aps where aps.id = parse_session_id and aps.user_id = (select auth.uid())));
create policy ai_parse_items_insert_own on public.ai_parse_items for insert to authenticated
  with check (exists (select 1 from public.ai_parse_sessions aps where aps.id = parse_session_id and aps.user_id = (select auth.uid())));
create policy ai_parse_items_update_own on public.ai_parse_items for update to authenticated
  using (exists (select 1 from public.ai_parse_sessions aps where aps.id = parse_session_id and aps.user_id = (select auth.uid())))
  with check (exists (select 1 from public.ai_parse_sessions aps where aps.id = parse_session_id and aps.user_id = (select auth.uid())));
create policy ai_parse_items_delete_own on public.ai_parse_items for delete to authenticated
  using (exists (select 1 from public.ai_parse_sessions aps where aps.id = parse_session_id and aps.user_id = (select auth.uid())));
