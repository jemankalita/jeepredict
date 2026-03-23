-- ============================================================
-- FINAL FIX — Run in Supabase SQL Editor
-- ============================================================

-- Drop all existing policies
drop policy if exists "profiles_read_all"   on profiles;
drop policy if exists "profiles_update_own" on profiles;
drop policy if exists "bets_read_all"       on bets;
drop policy if exists "bets_insert_own"     on bets;
drop policy if exists "pool_read_all"       on pool;
drop policy if exists "markets_read_all"    on markets;

-- Recreate clean policies
create policy "profiles_read_all"   on profiles for select using (true);
create policy "profiles_insert_own" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on profiles for update using (auth.uid() = id);
create policy "bets_read_all"       on bets for select using (true);
create policy "bets_insert_own"     on bets for insert with check (auth.uid() = user_id);
create policy "pool_read_all"       on pool for select using (true);
create policy "markets_read_all"    on markets for select using (true);

-- Make sure realtime is enabled
alter publication supabase_realtime add table pool;
alter publication supabase_realtime add table profiles;
