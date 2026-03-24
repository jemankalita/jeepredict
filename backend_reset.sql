-- ============================================================
-- JEEPredict backend reset
-- Run this in Supabase SQL Editor to rebuild the app backend.
-- ============================================================

set check_function_bodies = off;

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique,
  email text,
  reddium_balance integer not null default 1000,
  created_at timestamptz not null default now()
);

create table if not exists public.markets (
  id text primary key,
  name text not null,
  description text,
  is_open boolean not null default true,
  winner text default null,
  created_at timestamptz not null default now()
);

create table if not exists public.pool (
  id uuid primary key default gen_random_uuid(),
  market_id text not null references public.markets(id) on delete cascade,
  option text not null,
  total_staked integer not null default 0,
  unique (market_id, option)
);

create table if not exists public.bets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  market_id text not null references public.markets(id) on delete cascade,
  pick text not null,
  stake integer not null check (stake > 0),
  locked_odds numeric(10,4) not null,
  locked_payout numeric(10,4) not null,
  status text not null default 'pending' check (status in ('pending','won','lost')),
  created_at timestamptz not null default now()
);

insert into public.markets (id, name, description) values
  ('highest', 'Highest Cutoff Shift', 'Which shift will have the highest overall cutoff?'),
  ('lowest', 'Lowest Cutoff Shift', 'Which shift will have the lowest cutoff?'),
  ('hardest', 'Hardest Shift', 'Which shift had the most difficult paper?'),
  ('easiest', 'Easiest Shift', 'Which shift felt most accessible?'),
  ('c99', 'Average Score Across Shifts', 'What will the average score across all shifts be? (150-200)')
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text;
begin
  uname := coalesce(
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'preferred_username',
    new.raw_user_meta_data->>'full_name',
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, email, username, reddium_balance)
  values (new.id, new.email, uname, 1000)
  on conflict (id) do update set
    email = excluded.email,
    username = coalesce(public.profiles.username, excluded.username);

  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, email, username, reddium_balance)
select
  au.id,
  au.email,
  coalesce(
    au.raw_user_meta_data->>'username',
    au.raw_user_meta_data->>'preferred_username',
    split_part(au.email, '@', 1)
  ),
  1000
from auth.users au
left join public.profiles p on p.id = au.id
where p.id is null
on conflict (id) do nothing;

create or replace function public.place_bet(
  p_user_id uuid,
  p_market_id text,
  p_pick text,
  p_stake integer,
  p_locked_odds numeric,
  p_locked_payout numeric
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  current_balance integer;
  current_pool integer;
  current_side integer;
  new_pool integer;
  new_side integer;
  real_payout numeric;
  real_odds numeric;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if auth.uid() <> p_user_id then
    raise exception 'User mismatch';
  end if;

  if p_stake is null or p_stake <= 0 then
    raise exception 'Stake must be positive';
  end if;

  select reddium_balance into current_balance
  from public.profiles
  where id = p_user_id
  for update;

  if current_balance is null then
    raise exception 'User not found';
  end if;

  if current_balance < p_stake then
    raise exception 'Insufficient Reddium balance';
  end if;

  if not exists (
    select 1
    from public.markets
    where id = p_market_id
      and is_open = true
  ) then
    raise exception 'Market is closed';
  end if;

  select coalesce(sum(total_staked), 0)
  into current_pool
  from public.pool
  where market_id = p_market_id;

  select coalesce(total_staked, 0)
  into current_side
  from public.pool
  where market_id = p_market_id
    and option = p_pick;

  new_pool := current_pool + p_stake;
  new_side := current_side + p_stake;
  real_payout := (p_stake::numeric / new_side::numeric) * new_pool::numeric;
  real_odds := real_payout / p_stake::numeric;

  update public.profiles
  set reddium_balance = reddium_balance - p_stake
  where id = p_user_id;

  insert into public.pool (market_id, option, total_staked)
  values (p_market_id, p_pick, p_stake)
  on conflict (market_id, option)
  do update set total_staked = public.pool.total_staked + excluded.total_staked;

  insert into public.bets (user_id, market_id, pick, stake, locked_odds, locked_payout)
  values (p_user_id, p_market_id, p_pick, p_stake, real_odds, real_payout);

  return json_build_object(
    'success', true,
    'locked_odds', real_odds,
    'locked_payout', real_payout,
    'new_balance', current_balance - p_stake
  );
exception when others then
  return json_build_object('success', false, 'error', sqlerrm);
end;
$$;

create or replace view public.leaderboard as
select
  p.id,
  p.username,
  p.reddium_balance,
  count(b.id) as total_bets,
  coalesce(sum(case when b.status = 'won' then 1 else 0 end), 0) as wins,
  coalesce(sum(case when b.status = 'lost' then 1 else 0 end), 0) as losses,
  row_number() over (order by p.reddium_balance desc, p.created_at asc) as rank
from public.profiles p
left join public.bets b on b.user_id = p.id
group by p.id, p.username, p.reddium_balance, p.created_at
order by p.reddium_balance desc, p.created_at asc;

alter table public.profiles enable row level security;
alter table public.markets enable row level security;
alter table public.pool enable row level security;
alter table public.bets enable row level security;

do $$
declare
  r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles', 'markets', 'pool', 'bets')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

create policy profiles_read_all on public.profiles for select using (true);
create policy profiles_insert_own on public.profiles for insert with check (auth.uid() = id);
create policy profiles_update_own on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy markets_read_all on public.markets for select using (true);
create policy pool_read_all on public.pool for select using (true);
create policy bets_read_all on public.bets for select using (true);
create policy bets_insert_own on public.bets for insert with check (auth.uid() = user_id);

grant usage on schema public to anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant select on public.markets to anon, authenticated;
grant select on public.pool to anon, authenticated;
grant select on public.bets to anon, authenticated;
grant insert on public.bets to authenticated;
grant select on public.leaderboard to anon, authenticated;
grant execute on function public.place_bet(uuid, text, text, integer, numeric, numeric) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.pool;
exception when duplicate_object then
  null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then
  null;
end $$;

select 'profiles' as table_name, count(*) as row_count from public.profiles
union all
select 'markets', count(*) from public.markets
union all
select 'pool', count(*) from public.pool
union all
select 'bets', count(*) from public.bets;
