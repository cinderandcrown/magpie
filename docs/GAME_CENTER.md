# Game Center + Daily Heist

Nicholas-approved competition loop for **The Neon City Bandit**.

## What ships

1. **Game Center basics** — `GKLocalPlayer` auth on launch (never blocks play), access point on menu/results, `Magpie.entitlements` Game Center + CloudKit.
2. **Daily Heist** — one UTC-day layout for everyone (`ProgressStore.dailySeed`). Score = time + loot + no-damage (`DailyScore`). Recurring boards: `daily_heist` (1-day) and `most_wanted_weekly` (7-day). Ghost races vs #1 / own best / friend (translucent cyan bandit). CloudKit public DB stores compact samples. Unlimited retries; best score wins. No paid entries.
3. **~15 achievements** — see `Assets/GameCenter/catalog.json`.
4. **Friend challenges** — “beat my score” via Game Center leaderboard UI.

## ASC config (no submission)

With `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` set:

```bash
python3 scripts/appstore_connect.py ensure-game-center \
  --bundle-id com.cinderandcrown.magpie \
  --catalog Assets/GameCenter/catalog.json
```

Creates / updates Game Center detail, leaderboards, and achievements from the catalog. **Config only** — does not submit or release.

## Cross-game badge (Trash Stack)

Shared achievement vendor id: `bandit_of_both_worlds`.

**Preferred:** put Neon City Bandit + Trash Stack in one **Game Center game group** (same Apple team). Group achievements unlock in both apps; each app grants the shared bandit outfit when the achievement is earned.

**Fallback (if groups aren’t available):** CloudKit public record `CrossGameBadge` keyed by Game Player ID + `bandit_of_both_worlds`, plus a custom URL scheme claim (`magpie://badge/both-worlds` / Trash Stack equivalent). Either app writes the record when the badge is earned; the other reads on launch and unlocks the outfit. Still no IAP, no server cost beyond free CloudKit.

## Art

Uses the **Nicholas-approved** bandit when the 256² archive lands (`ArtLibrary.activateSet` / `active_set.json`). Ghost tint stays cyan regardless of skin.
