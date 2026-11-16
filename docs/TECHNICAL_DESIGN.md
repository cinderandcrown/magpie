# Neon City Bandit — Technical design (mobile)

**Stack:** Native Swift · SpriteKit · StoreKit 2 · iOS 17+ · portrait iPhone only.  
**Sim:** `Packages/GameCore` (deterministic, Linux-testable). **Render/UI:** `Packages/GameRender`.  
**Feel numbers:** `Tuning` (walk/run, gravity, coyote, stomp, hit-stop). No magic numbers in call sites.

## One-minute loop

Camera follows Bandit; verbs = move (left-half floating stick), jump, pounce/stomp; win = bank Shinies / clear; lose = Bagged / hazard.

## Controls (placement-insensitive)

| Zone | Behavior |
| --- | --- |
| Left half | Stick **appears at finger**; slight deflection = walk, full = run |
| Right | JUMP + POUNCE face buttons inside safe area |

All HUD/controls respect `safeAreaInsets` (island + home indicator). Smoke uses scripted input (no touch).

## Systems / gyms

| Gym | Owns |
| --- | --- |
| Character | BanditVisual sheets, foot baseline in ground, Mask grade ≤ subtle |
| Tiles/collision | Tile map, coyote/buffer, wall cling |
| Enemies | MOP patrol; stomp hitbox only while committed downward / flop contact |
| Background | Parallax plates dimmer than playfield; no HUD color fight |

## Art handoff

Fire Fox runs Spriterrific locally (CI spend disabled). Sheets: `Assets/Generated/sprites/spriterrific/` → normalize with `scripts/normalize_spriterrific_sheets.py` → `spriterrific_ready/`. Runtime: `SpriteCycles` → `BanditVisual` / `MopVisual` / `BossVisual` (west-facing flip; shared foot baseline). Boss tread scrolls in code until `tread_roll` is swapped in. See `Assets/SPRITERRIFIC_ANCHOR.md`.

## QA gate

Deterministic smoke video ≥60s, ready-signal milestones, palette gates (no white plate, no Mask cyan wash), screenshot moments for agent-eyes compare.
