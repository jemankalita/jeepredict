# JEEPredict

> Predict JEE Mains April shifts. Bet Reddium. Win from the loser pool.

A prediction market built specifically for **JEE Mains April 2025**. Pick which shift has the highest cutoff, the hardest paper, the lowest cutoff, the easiest paper, or predict the average score range — and earn **Reddium** when you're right.

---

## What is this

JEEPredict is a parimutuel prediction market where users stake virtual currency (Reddium) on outcomes related to JEE Mains April 2025 shifts. All odds are calculated in real-time from actual stakes — no house edge, no fake numbers.

---

## Markets

| Market | Description |
|--------|-------------|
| 🏆 Highest Cutoff Shift | Which shift will have the highest overall cutoff? |
| 📉 Lowest Cutoff Shift | Which shift will have the lowest cutoff? |
| 💀 Hardest Shift | Which shift had the most difficult paper? |
| 😌 Easiest Shift | Which shift felt most accessible? |
| 📊 Average Score | What will the average score across all shifts be? (150–200) |

All 11 shifts available: `2S1 · 2S2 · 4S1 · 4S2 · 5S1 · 5S2 · 6S1 · 6S2 · 7S1 · 7S2 · 8S2`

---

## How the odds work

This uses a real **parimutuel** system — the same model used by horse racing and global betting markets.

```
Display Odds  =  Total Pool  ÷  Staked on your pick

Locked Payout =  (Your Stake ÷ New Side Total)  ×  New Total Pool

Implied Prob  =  Side Stake  ÷  Total Pool
```

- Odds update live with every bet placed
- Your payout is **locked** the moment you confirm
- Zero house edge — all losing Reddium flows directly to winners

---

## Reddium

Reddium (🔴) is the virtual currency used across all markets.

- Every new user starts with **1,000 Reddium free**
- Grow it by making correct predictions
- Lose it by being wrong
- No real money involved

---

## Tech Stack

- **Pure HTML / CSS / JS** — no frameworks, no build tools
- **Parimutuel engine** — built from scratch in vanilla JS
- **iOS Emojis** — via `emoji-datasource-apple` CDN
- **Fonts** — Cormorant Garamond · DM Sans · JetBrains Mono
- **Video background** — embedded as base64 in the landing page

---

## Project Structure

```
├── index.html                  # Landing page (with video background)
├── jee-prediction-market.html  # Prediction market app
└── README.md
```

---

## Author

Made by **Jeman Kalita** · [github.com/jemankalita](https://github.com/jemankalita)

---

*This is a fun prediction market project. No real money is involved. All currency is virtual.*
