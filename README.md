# JEEPredict

JEEPredict is a lightweight prediction market for JEE Main April 2026. Users place bets with virtual currency called `Reddium` on outcomes like:

- highest cutoff shift
- lowest cutoff shift
- hardest shift
- easiest shift
- average score across shifts for 99 percentile

No real money is involved.

## Live Site

[https://jeepredict.vercel.app/](https://jeepredict.vercel.app/)

## How the website works

The site has two main pages:

- [index.html](C:\Users\User\Downloads\predictJEE\index.html): landing page
- [jee-prediction-market.html](C:\Users\User\Downloads\predictJEE\jee-prediction-market.html): the actual market app

The frontend is plain HTML, CSS, and JavaScript. Data is stored in Supabase/Postgres.

Main backend pieces:

- `profiles`: user balances and usernames
- `bets`: every bet placed by users
- `pool`: total stake on each option in each market
- `place_bet(...)`: SQL function that validates a bet, deducts balance, updates pool totals, and stores locked odds/payout

## How betting works

This is a parimutuel market.

That means users are betting against each other, not against the website.

- Every option in a market has a running pool.
- When more people bet on one side, that side becomes less profitable.
- Less popular sides have higher odds because less Reddium is staked there.
- Losing Reddium goes to the winning side when results are resolved.

## Odds and payout

The app uses these formulas:

```text
Display Odds = Total Pool / Stake on your side

Locked Payout = (Your Stake / New Side Total) * New Total Pool

Implied Probability = Side Stake / Total Pool
```

What this means in practice:

- `Display Odds` shows the current multiplier for that option right now.
- `Locked Payout` is calculated at the moment you confirm the bet.
- After your bet is placed, later bets can change public odds for new users, but your own locked payout stays fixed.

## Reddium

`Reddium` is the site currency.

- new users start with a free balance
- users spend it to place bets
- if their prediction wins, they receive payout from the final pool

## Live updates

The market page updates pool values and pricing as bets come in. The visible total pool, odds, and positions are derived from the current stored pool/bet data.

## Files

- [index.html](C:\Users\User\Downloads\predictJEE\index.html): landing page
- [jee-prediction-market.html](C:\Users\User\Downloads\predictJEE\jee-prediction-market.html): main app UI
- [schema.sql](C:\Users\User\Downloads\predictJEE\schema.sql): base database schema
- [backend_reset.sql](C:\Users\User\Downloads\predictJEE\backend_reset.sql): backend setup/reset script
- [bot_market_seed.sql](C:\Users\User\Downloads\predictJEE\bot_market_seed.sql): bot users and seeded pool data

## Running it

This is a static site, so you can serve it locally with:

```powershell
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/index.html
```
