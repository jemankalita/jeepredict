-- ============================================================
-- JEEPredict — UPDATE ONLY
-- Run this in Supabase SQL Editor
-- Safe to run multiple times — only updates existing functions
-- ============================================================

-- Update handle_new_user to support Reddit OAuth username
create or replace function handle_new_user()
returns trigger as $$
declare
  uname text;
begin
  -- Reddit OAuth sends preferred_username in raw_user_meta_data
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


-- Update place_bet function (safe to re-run)
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
  select reddium_balance into current_balance
  from profiles where id = p_user_id for update;

  if current_balance is null then
    raise exception 'User not found';
  end if;

  if current_balance < p_stake then
    raise exception 'Insufficient Reddium balance';
  end if;

  if not exists (select 1 from markets where id = p_market_id and is_open = true) then
    raise exception 'Market is closed';
  end if;

  select coalesce(sum(total_staked), 0) into current_pool
  from pool where market_id = p_market_id;

  select coalesce(total_staked, 0) into current_side
  from pool where market_id = p_market_id and option = p_pick;

  new_pool    := current_pool + p_stake;
  new_side    := current_side + p_stake;
  real_payout := (p_stake::numeric / new_side::numeric) * new_pool::numeric;
  real_odds   := real_payout / p_stake::numeric;

  update profiles set reddium_balance = reddium_balance - p_stake where id = p_user_id;

  insert into pool (market_id, option, total_staked)
  values (p_market_id, p_pick, p_stake)
  on conflict (market_id, option)
  do update set total_staked = pool.total_staked + p_stake;

  insert into bets (user_id, market_id, pick, stake, locked_odds, locked_payout)
  values (p_user_id, p_market_id, p_pick, p_stake, real_odds, real_payout);

  return json_build_object(
    'success',       true,
    'locked_odds',   real_odds,
    'locked_payout', real_payout,
    'new_balance',   current_balance - p_stake
  );

exception when others then
  return json_build_object('success', false, 'error', sqlerrm);
end;
$$ language plpgsql security definer;


-- Update leaderboard view
create or replace view leaderboard as
select
  p.id,
  p.username,
  p.reddium_balance,
  count(b.id) as total_bets,
  coalesce(sum(case when b.status = 'won' then 1 else 0 end), 0) as wins,
  coalesce(sum(case when b.status = 'lost' then 1 else 0 end), 0) as losses,
  row_number() over (order by p.reddium_balance desc) as rank
from profiles p
left join bets b on b.user_id = p.id
group by p.id, p.username, p.reddium_balance
order by p.reddium_balance desc;
