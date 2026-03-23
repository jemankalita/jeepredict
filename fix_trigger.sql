-- ============================================================
-- Fix: handle_new_user trigger for username-only auth
-- Run in Supabase SQL Editor
-- ============================================================

create or replace function handle_new_user()
returns trigger as $$
declare
  uname text;
begin
  -- Get username from metadata
  uname := coalesce(
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'preferred_username',
    split_part(new.email, '@', 1)
  );

  -- Insert profile, ignore if already exists
  insert into profiles (id, email, username, reddium_balance)
  values (new.id, new.email, uname, 1000)
  on conflict (id) do nothing;

  return new;

-- If anything fails, don't block the auth user creation
exception when others then
  return new;
end;
$$ language plpgsql security definer;
