-- ============================================================
-- JEEPredict bot market seed
-- Run after backend_reset.sql
-- Seeds ~100k total pool and visible bot-style bet history.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.bot_profiles (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  reddium_balance integer not null default 25000,
  created_at timestamptz not null default now()
);

create table if not exists public.bot_bets (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.bot_profiles(id) on delete cascade,
  market_id text not null references public.markets(id) on delete cascade,
  pick text not null,
  stake integer not null check (stake > 0),
  created_at timestamptz not null default now()
);

insert into public.bot_profiles (username, reddium_balance) values
  ('rank_pundit', 32000),
  ('shift_whisperer', 28000),
  ('cutoff_oracle', 31000),
  ('paperhawk', 26000),
  ('nta_watch', 29000),
  ('jeequant', 34000),
  ('session_sniper', 27000),
  ('markschemist', 30000)
on conflict (username) do nothing;

insert into public.pool (market_id, option, total_staked)
select seed.market_id, seed.option, seed.total_staked
from (
  values
    ('highest','2S1',2100),('highest','2S2',2400),('highest','4S1',3000),('highest','4S2',3400),('highest','5S1',5200),('highest','5S2',4700),('highest','6S1',2600),('highest','6S2',2100),('highest','7S1',3300),('highest','7S2',2800),('highest','8S2',1800),
    ('lowest','2S1',1800),('lowest','2S2',2200),('lowest','4S1',1600),('lowest','4S2',2100),('lowest','5S1',1700),('lowest','5S2',2300),('lowest','6S1',4200),('lowest','6S2',5100),('lowest','7S1',3600),('lowest','7S2',3200),('lowest','8S2',5700),
    ('hardest','2S1',2400),('hardest','2S2',2200),('hardest','4S1',3100),('hardest','4S2',3600),('hardest','5S1',4300),('hardest','5S2',4600),('hardest','6S1',3900),('hardest','6S2',2600),('hardest','7S1',1900),('hardest','7S2',1600),('hardest','8S2',1200),
    ('easiest','2S1',1500),('easiest','2S2',1700),('easiest','4S1',1400),('easiest','4S2',1800),('easiest','5S1',1200),('easiest','5S2',1300),('easiest','6S1',2300),('easiest','6S2',3500),('easiest','7S1',4600),('easiest','7S2',5200),('easiest','8S2',6100),
    ('c99','150-155',900),('c99','155-160',1300),('c99','160-165',2100),('c99','165-170',3400),('c99','170-175',5200),('c99','175-180',6900),('c99','180-185',6100),('c99','185-190',4300),('c99','190-195',2500),('c99','195-200',1200)
) as seed(market_id, option, total_staked)
on conflict (market_id, option)
do update set total_staked = greatest(public.pool.total_staked, excluded.total_staked);

with bots as (
  select id, username, row_number() over (order by username) as n
  from public.bot_profiles
),
seed_bets as (
  select * from (values
    ('highest','5S1',2400),('highest','5S2',2100),('highest','4S2',1700),('highest','7S1',1600),('highest','4S1',1500),('highest','7S2',1300),('highest','2S2',1100),('highest','6S1',900),
    ('lowest','8S2',2600),('lowest','6S2',2300),('lowest','6S1',1900),('lowest','7S1',1700),('lowest','7S2',1400),('lowest','5S2',1200),('lowest','4S2',1000),('lowest','2S2',900),
    ('hardest','5S2',2500),('hardest','5S1',2200),('hardest','6S1',1900),('hardest','4S2',1700),('hardest','4S1',1400),('hardest','6S2',1200),('hardest','2S1',1100),('hardest','7S1',900),
    ('easiest','8S2',2800),('easiest','7S2',2400),('easiest','7S1',2100),('easiest','6S2',1700),('easiest','6S1',1100),('easiest','4S2',900),('easiest','2S2',800),('easiest','5S2',700),
    ('c99','175-180',3300),('c99','180-185',3000),('c99','170-175',2600),('c99','185-190',2200),('c99','165-170',1700),('c99','190-195',1300),('c99','160-165',1000),('c99','155-160',800)
  ) as t(market_id, pick, stake)
),
numbered as (
  select market_id, pick, stake, row_number() over (order by market_id, pick) as rn
  from seed_bets
)
insert into public.bot_bets (bot_id, market_id, pick, stake)
select b.id, n.market_id, n.pick, n.stake
from numbered n
join bots b on (((n.rn - 1) % 8) + 1) = b.n
where not exists (
  select 1
  from public.bot_bets bb
  where bb.market_id = n.market_id
    and bb.pick = n.pick
    and bb.stake = n.stake
);

create or replace view public.app_leaderboard as
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

union all

select
  bp.id,
  bp.username,
  bp.reddium_balance,
  count(bb.id) as total_bets,
  0 as wins,
  0 as losses,
  null::bigint as rank
from public.bot_profiles bp
left join public.bot_bets bb on bb.bot_id = bp.id
group by bp.id, bp.username, bp.reddium_balance, bp.created_at;

grant select on public.bot_profiles to anon, authenticated;
grant select on public.bot_bets to anon, authenticated;
grant select on public.app_leaderboard to anon, authenticated;

select
  coalesce(sum(total_staked), 0) as total_pool,
  (select count(*) from public.bot_profiles) as bot_count,
  (select count(*) from public.bot_bets) as bot_bet_count
from public.pool;
