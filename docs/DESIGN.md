# The Neon City Bandit — Design

**Status:** Live product direction (Mission 1+)  
**Codename in code:** `MAGPIE` (repo, bundle id `com.cinderandcrown/magpie`, modules).  
**User-facing title:** **The Neon City Bandit** via `ProductIdentity.displayTitle`. Home screen: `CFBundleDisplayName` = **Neon City Bandit**. Do not scatter title strings. Bundle ID does not change.

## Pitch

A cocky masked raccoon runs short neon-city heists: pounce, belly-flop MOPs, bank Shinies, free the crew. Villain: **MOP** (Municipal Order Protocol). Rating target 9+.

**North-star (Nicholas):** the game must be **fun enough that people come back daily**. Retention is designed around a great 30-second loop first, then light optional hooks — never nagging.

## Retention plan (binding)

### Core fun first (30-second loop)

- **Tight controls:** coyote time, jump buffer, variable jump height, pounce dash with a satisfying arc.
- **Chain-stomps:** stomping MOPs without touching the ground builds combos with escalating pitch SFX and multipliers; Mask Mode at combo threshold.
- **Medals (3 per level, shown up front):** (1) finish, (2) collect all Shinies, (3) beat par time. Stars/medals appear on **level clear only** — never on the death card.
- **Crew:** 1 hidden crew member per level (“Free the crew”) in a secret spot.

### Progression

- **District map — Neon City:** districts Docks, Arcade Row, Rooftops, Sewer Grid. Each ~8 short levels (60–120 s) + a boss MOP (MOP-ZILLA style, original). Stars unlock districts.
- **Freed crew** become playable raccoon variants with small perks (double jump, magnet, etc.).
- **Cosmetics:** vests, mask LED colors, trail colors.

### Come-back hooks (optional, no nagging)

- **Daily Heist:** one handcrafted/remixed level per day (same for everyone) + Game Center time leaderboard.
- **Ghost racing:** replay any level against your own best-run ghost.
- **Daily login streak** with escalating cosmetics; one free “streak saver” per week if a day is missed.
- **Weekly Bounties:** 3 challenges (e.g. stomp 50 MOPs in Mask Mode).
- **Local push** only if opted in, ≤1/day (daily heist ready / streak at risk).
- **Season pass** free + premium cosmetic tracks; gems earnable in play. No purchase popups at launch, mid-run, or after a loss.

### Game Center

- Leaderboards per level + Daily Heist.
- Achievements for loop milestones (first Mask Mode, first full-medal clear, streak, etc.).

### Ship order

1. Core loop polish + medals on results  
2. District map with **first district (Neon Docks) fully playable**  
3. Daily Heist screen + run  
4. Ghosts + streaks  
5. Season pass  

Smoke evidence for this increment: combos, medals on the results card, district map, Daily Heist screen.

## Hero moves

| Move | Notes |
| --- | --- |
| **Pounce** | Air dash with arc |
| **Belly Flop** | Dive-stomp; combo +1 |
| **Mask Mode** | At combo threshold — double loot, trails, shareable moment |

**Visual / legal:** keep the hero clearly apart from Sony’s Sly Cooper — no cane, no top-hat gentleman-thief look. Scruffy junk-gadget chaos. Mascot still needs attorney review. Neon look may evoke a Grid-like city (thin glowing grids, edge light, trails) but must stay **original** — no Tron logos, light cycles, identity discs, or its exact blue/orange palette. Magenta + teal stay canonical.

## World glossary

| Term | Meaning |
| --- | --- |
| Shinies | Collectibles / loot |
| Stash | Bank chute |
| MOP | Enemy bots |
| Neon Docks / Arcade Row / Rooftops / Sewer Grid | Districts |
| Bagged / Splashed / Spiked | Fail states |

## Open questions

1. Season pass pricing / gem economy numbers.  
2. Which crew variants ship in district 1.  
3. ASC listing name sync with **The Neon City Bandit** (bundle ID stays).

## Unchanged engineering pillars

Gates · Swift/SpriteKit · GameCore determinism · portrait one-thumb · baked glow (no SKEffectNode/shaders) · one mission quality bar at a time.
