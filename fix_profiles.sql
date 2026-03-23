-- ============================================================
-- Fix 1: Manually create profiles for any users missing one
-- ============================================================
insert into profiles (id, email, username, reddium_balance)
select 
  au.id,
  au.email,
  coalesce(
    au.raw_user_meta_data->>'username',
    split_part(au.email, '@', 1)
  ),
  1000
from auth.users au
left join profiles p on p.id = au.id
where p.id is null
on conflict (id) do nothing;


-- ============================================================
-- Fix 2: Update trigger to be more robust
-- ============================================================
create or replace function handle_new_user()
returns trigger as $$
declare
  uname text;
begin
  uname := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1)
  );

  insert into profiles (id, email, username, reddium_balance)
  values (new.id, new.email, uname, 1000)
  on conflict (id) do update set
    username = coalesce(profiles.username, excluded.username),
    email    = excluded.email;

  return new;
exception when others then
  return new;
end;
$$ language plpgsql security definer;


-- ============================================================
-- Fix 3: Check what's in profiles right now
-- ============================================================
select id, username, email, reddium_balance from profiles;
