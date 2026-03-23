-- ============================================================
-- FINAL FIX — Run in Supabase SQL Editor
-- ============================================================

-- Step 1: Disable RLS temporarily to test
alter table profiles disable row level security;
alter table pool     disable row level security;
alter table markets  disable row level security;
alter table bets     disable row level security;

-- Step 2: Re-enable with correct policies
alter table profiles enable row level security;
alter table pool     enable row level security;
alter table markets  enable row level security;
alter table bets     enable row level security;

-- Step 3: Drop ALL existing policies cleanly
do $$ 
declare r record;
begin
  for r in select policyname, tablename from pg_policies 
           where schemaname = 'public' 
           and tablename in ('profiles','pool','markets','bets')
  loop
    execute format('drop policy if exists %I on %I', r.policyname, r.tablename);
  end loop;
end $$;

-- Step 4: Create simple open policies (anyone can read everything)
create policy "allow_all_profiles" on profiles for all using (true) with check (true);
create policy "allow_all_pool"     on pool     for all using (true) with check (true);
create policy "allow_all_markets"  on markets  for all using (true) with check (true);
create policy "allow_all_bets"     on bets     for all using (true) with check (true);

-- Step 5: Make sure markets data exists
insert into markets (id, name, description) values
  ('highest', 'Highest Cutoff Shift',       'Which shift will have the highest overall cutoff?'),
  ('lowest',  'Lowest Cutoff Shift',         'Which shift will have the lowest cutoff?'),
  ('hardest', 'Hardest Shift',               'Which shift had the most difficult paper?'),
  ('easiest', 'Easiest Shift',               'Which shift felt most accessible?'),
  ('c99',     'Average Score Across Shifts', 'What will the average score across all shifts be?')
on conflict (id) do nothing;

-- Step 6: Verify
select 'profiles' as tbl, count(*) from profiles
union all
select 'markets', count(*) from markets
union all  
select 'pool', count(*) from pool;
