# The Neon City Bandit — Design

**Status:** Live product direction (Mission 1+)  
**Codename in code:** `MAGPIE` (repo, bundle id `com.cinderandcrown/magpie`, modules).  
**User-facing title:** **The Neon City Bandit** via `ProductIdentity.displayTitle`. Home screen: `CFBundleDisplayName` = **Neon City Bandit**. Do not scatter title strings. Bundle ID does not change.

## Pitch

A cocky masked raccoon runs short neon-city heists: pounce, belly-flop MOPs, bank Shinies, free the crew. Villain: **MOP** (Municipal Order Protocol). Rating target 9+.

**North-star (Nicholas):** the game must be **fun enough that people come back daily**. Retention is designed around a great 30-second loop first, then light optional hooks — never nagging.

## Reference games (Nicholas)

What he returns to / loves — **steal the feeling, never the IP**. No copied names, UI chrome, layouts, art, audio, or mode names from these titles. Original neon-heist framing only.

| Reference | What to take | What never to take |
| --- | --- | --- |
| **Clash of Clans** | Return loop: a home you upgrade with stolen loot; timers that finish while you’re away; a reason to check in daily; something to collect every visit. Free-friendly — no nag popups; mild spend-to-speed OK (see Monetization). | Village layout, building names, UI cards, troop fantasy, or Supercell branding. |
| **Star Trek Fleet Command** | Same return-loop pattern: base / roster progress that advances offline; daily goals; collectible progress each session. | Star Trek IP, ship/officer names, starbase UI, or STFC mode labels. |
| **Call of Duty** | Badass *feel*: heavy punchy hits (hit-stop, screen shake, crisp SFX); a satisfying level-up / rank-up beat; cosmetics and finishers that feel earned in the pass. | Gun names, operator kits, HUD layout, killstreak labels, or CoD branding. |

Derived backlog (below) is gated until the **core slice passes review**. Do not implement in the current mission pass.

## Retention plan (binding)

### Core fun first (30-second loop)

- **Tight controls:** coyote time, jump buffer, variable jump height, pounce dash with a satisfying arc. **Floating left stick** (appears where you touch); slight push = walk, full = run; JUMP/POUNCE on the right inside the safe area (`docs/VIBEGAMEDEV_METHODS.md` v2).
- **Chain-stomps:** stomping MOPs without touching the ground builds combos with escalating pitch SFX and multipliers; Mask Mode at combo threshold. Stomp hitbox live on the contact / committed-fall frame only.
- **Medals (3 per level, shown up front):** (1) finish, (2) collect all Shinies, (3) beat par time. Stars/medals appear on **level clear only** — never on the death card.
- **Crew:** 1 hidden crew member per level (“Free the crew”) in a secret spot.
- **FTUE (pre-release):** teach move, jump, stomp, Mask in &lt;30s. Juicy vertical slice — no feature sprawl.

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
- **Season pass** free + premium tracks; gems earnable in play. Offers follow Monetization (no nag popups at launch, mid-run, or after a loss).

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

## Monetization (Nicholas)

**Tone:** mild pay-to-win is OK — “just not crazy.” Paying may **speed progress** and give a **modest edge**, never lock the game behind a wallet.

**Allowed (examples):**

- Hideout / upgrade **timer skips**
- Temporary **loot boosters** and similar convenience
- Cosmetic / finisher purchases in the pass
- Modest progress edge vs a free peer on the same skill

**Hard limits:**

- Everything paid must also be **earnable for free by playing** (no paid-only power).
- **No paywall levels** or gated districts behind IAP.
- **No crazy stat gap** — a skilled free player must still be able to win / clear content.
- **No nagging:** no purchase popups at launch, mid-run, or after a loss; rewarded ads stay opt-in; Daily score ceiling stays purchase-neutral.

Prices and catalog still need Nicholas approval before shipping (see open questions).

## Open questions

1. Season pass pricing / gem economy numbers (and how mild the paid edge is).  
2. Which crew variants ship in district 1.  
3. ASC listing name sync with **The Neon City Bandit** (bundle ID stays).

## Backlog (do not start until core slice passes review)

### DISCO NEON LASER SHOW (easter egg) — Nicholas

**Gate:** build only after the next review of the core vertical slice. Not in the current mission pass.

**Secret trigger (pick one / A-B later):** stomp the same hidden neon tile 3 times, **or** find a hidden disco ball in a level.

**On trigger (5–8 seconds, then return to play):**

- Raccoon plays a `disco_dance` loop (sprite sheet delivered by Fire Fox from Spriterrific).
- Mirror ball drops in; sweeping colored laser beams (additive blend).
- Pulsing grid floor; brief **original** bass-drop music sting (no licensed music).
- Haptics on the beat; confetti sparks.
- Unlocks a cosmetic flag / achievement.

**Constraints:** original art and code only. No licensed music. Keep it a juicy secret — no feature sprawl into the core loop.

### Hideout return loop (from CoC / STFC feel) — Nicholas

**Gate:** after core-slice review. Original naming/UI/art only.

- **Hideout** home base the raccoon upgrades with stolen Shinies / loot.
- Upgrades that **finish while you’re away** (offline progress timers).
- **Daily heist goals** tied to the Hideout / Den visit.
- **Something to collect every visit** (small, free, non-nagging).
- **Monetization:** timer skips / loot boosters OK under Monetization (mild edge, all earnable free, no nag).

### Badass feel pass (from CoD feel) — Nicholas

**Gate:** after core-slice review. Original cosmetics/finishers only.

- Heavier, punchier hits: tunable hit-stop, screen shake, crisp original SFX.
- A satisfying **level-up / rank-up** moment (celebration juice, not a paywall).
- **Badass cosmetics and finishers** in the (free + premium) pass — earnable in play; paid track may speed cosmetics only within Monetization limits (no crazy power gap).

## Unchanged engineering pillars

Gates · Swift/SpriteKit · GameCore determinism · portrait one-thumb · baked glow (no SKEffectNode/shaders) · one mission quality bar at a time.
