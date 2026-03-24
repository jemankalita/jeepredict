begin;

delete from public.bets
where user_id in (
  select id from public.profiles where lower(username) = 'ayoitswhite'
);

delete from public.profiles
where lower(username) = 'ayoitswhite';

delete from auth.users
where lower(email) = 'ayoitswhite@jeepredict.app';

commit;
