-- ============================================================
-- JEEPredict — Supabase Schema
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================


-- ── 1. PROFILES ─────────────────────────────────────────────
-- Extends Supabase auth.users with game data
create table if not exists profiles (
  id               uuid references auth.users(id) on delete cascade primary key,
  username         text unique,
  email            text,
  reddium_balance  integer not null default 1000,
  created_at       timestamptz default now()
);

-- Auto-create a profile when a user signs up
create or replace function handle_new_user()
returns trigger as $$
declare
  uname text;
begin
  -- Reddit OAuth sends full_name or preferred_username in raw_user_meta_data
  -- Email signup sends username in raw_user_meta_data.username
  uname := coalesce(
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'preferred_username',
    new.raw_user_meta_data->>'full_name',
    split_part(new.email, '@', 1)
  );

  insert into profiles (id, email, username)
  values (new.id, new.email, uname)
  on conflict (id) do update set
    username = coalesce(profiles.username, excluded.username),
    email    = excluded.email;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();


-- ── 2. MARKETS ──────────────────────────────────────────────
create table if not exists markets (
  id          text primary key,
  name        text not null,
  description text,
  is_open     boolean default true,
  winner      text default null,
  created_at  timestamptz default now()
);

-- Seed the 5 markets
insert into markets (id, name, description) values
  ('highest', 'Highest Cutoff Shift',       'Which shift will have the highest overall cutoff?'),
  ('lowest',  'Lowest Cutoff Shift',         'Which shift will have the lowest cutoff?'),
  ('hardest', 'Hardest Shift',               'Which shift had the most difficult paper?'),
  ('easiest', 'Easiest Shift',               'Which shift felt most accessible?'),
  ('c99',     'Average Score Across Shifts', 'What will the average score across all shifts be? (150–200)')
on conflict (id) do nothing;


-- ── 3. POOL ─────────────────────────────────────────────────
-- Tracks total Reddium staked per option per market
create table if not exists pool (
  id            uuid default gen_random_uuid() primary key,
  market_id     text references markets(id) on delete cascade,
  option        text not null,
  total_staked  integer not null default 0,
  unique(market_id, option)
);


-- ── 4. BETS ─────────────────────────────────────────────────
create table if not exists bets (
  id              uuid default gen_random_uuid() primary key,
  user_id         uuid references profiles(id) on delete cascade,
  market_id       text references markets(id),
  pick            text not null,
  stake           integer not null,
  locked_odds     numeric(10,4) not null,
  locked_payout   numeric(10,4) not null,
  status          text not null default 'pending', -- pending | won | lost
  created_at      timestamptz default now()
);


-- ── 5. ATOMIC BET FUNCTION ──────────────────────────────────
-- Called as a single transaction to prevent race conditions
-- on the parimutuel pool
create or replace function place_bet(
  p_user_id       uuid,
  p_market_id     text,
  p_pick          text,
  p_stake         integer,
  p_locked_odds   numeric,
  p_locked_payout numeric
)
returns json as $$
declare
  current_balance integer;
  current_pool    integer;
  current_side    integer;
  new_pool        integer;
  new_side        integer;
  real_payout     numeric;
  real_odds       numeric;
begin
  -- Lock the user row to prevent concurrent balance issues
  select reddium_balance into current_balance
  from profiles
  where id = p_user_id
  for update;

  if current_balance is null then
    raise exception 'User not found';
  end if;

  if current_balance < p_stake then
    raise exception 'Insufficient Reddium balance';
  end if;

  -- Check market is open
  if not exists (select 1 from markets where id = p_market_id and is_open = true) then
    raise exception 'Market is closed';
  end if;

  -- Get current pool totals
  select coalesce(sum(total_staked), 0) into current_pool
  from pool where market_id = p_market_id;

  select coalesce(total_staked, 0) into current_side
  from pool where market_id = p_market_id and option = p_pick;

  -- Calculate real locked payout after this stake enters pool
  new_pool := current_pool + p_stake;
  new_side := current_side + p_stake;
  real_payout := (p_stake::numeric / new_side::numeric) * new_pool::numeric;
  real_odds   := real_payout / p_stake::numeric;

  -- Deduct balance
  update profiles
  set reddium_balance = reddium_balance - p_stake
  where id = p_user_id;

  -- Upsert pool row
  insert into pool (market_id, option, total_staked)
  values (p_market_id, p_pick, p_stake)
  on conflict (market_id, option)
  do update set total_staked = pool.total_staked + p_stake;

  -- Insert bet record
  insert into bets (user_id, market_id, pick, stake, locked_odds, locked_payout)
  values (p_user_id, p_market_id, p_pick, p_stake, real_odds, real_payout);

  return json_build_object(
    'success',        true,
    'locked_odds',    real_odds,
    'locked_payout',  real_payout,
    'new_balance',    current_balance - p_stake
  );

exception when others then
  return json_build_object('success', false, 'error', sqlerrm);
end;
$$ language plpgsql security definer;


-- ── 6. LEADERBOARD VIEW ─────────────────────────────────────
create or replace view leaderboard as
select
  p.id,
  p.username,
  p.reddium_balance,
  count(b.id)                                    as total_bets,
  coalesce(sum(case when b.status = 'won' then 1 else 0 end), 0) as wins,
  coalesce(sum(case when b.status = 'lost' then 1 else 0 end), 0) as losses,
  row_number() over (order by p.reddium_balance desc) as rank
from profiles p
left join bets b on b.user_id = p.id
group by p.id, p.username, p.reddium_balance
order by p.reddium_balance desc;


-- ── 7. ROW LEVEL SECURITY ───────────────────────────────────
alter table profiles enable row level security;
alter table bets     enable row level security;
alter table pool     enable row level security;
alter table markets  enable row level security;

-- Profiles: users can read all, update only their own
create policy "profiles_read_all"   on profiles for select using (true);
create policy "profiles_update_own" on profiles for update using (auth.uid() = id);

-- Bets: users can read all bets, insert only their own
create policy "bets_read_all"   on bets for select using (true);
create policy "bets_insert_own" on bets for insert with check (auth.uid() = user_id);

-- Pool: anyone can read, only service role can write (via RPC)
create policy "pool_read_all" on pool for select using (true);

-- Markets: anyone can read
create policy "markets_read_all" on markets for select using (true);


-- ── 8. REALTIME ─────────────────────────────────────────────
-- Enable realtime on pool so all users see live odds
alter publication supabase_realtime add table pool;
alter publication supabase_realtime add table profiles;
