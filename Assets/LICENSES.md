# Asset licenses — The Neon City Bandit (MAGPIE)

All gameplay art and audio in this repository are either:

1. **Original** work created for this project (Cinder and Crown LLC), or
2. **Procedural derivatives** of those originals (crops / tint / neon-grid bake / limb-rig parts).

No third-party character packs were imported for the raccoon. Zero art budget for Mission 1
animation: living motion comes from the project’s own run/jump/fall sheets plus a
**procedural limb/tail/head rig** (crops + palette-matched capsule limbs / ringed tail)
driven with SpriteKit `SKAction`s (run bounce, jump/fall/land poses, squash-stretch, tail wag).
Commercial-safe; no ripped or GPL-only art.

Also see root `ASSETS_LICENSES.md` (repo-wide third-party log) and `docs/ASSETS.md`.

## Raccoon / bandit

| Asset | Source | License |
| --- | --- | --- |
| `sprites/raccoon/*.png` (idle, run_01–06, jump, fall, pounce, belly_flop, mask_mode, tail_swing) | Original project art (in-house generated; see `docs/ASSETS.md`) | Proprietary — Cinder and Crown LLC; used under Magpie repo terms |
| `sprites/raccoon/rig/head.png`, `torso.png` | Derived by cropping `raccoon/idle` | Same as parent sheet |
| `sprites/raccoon/rig/arm.png`, `leg.png`, `tail.png` | Procedural capsules / ringed tail painted from the idle sheet’s fur palette (same character; no third-party pack) | Same as parent sheet — original project derivative |

No CC-BY attribution is required for these assets (none are third-party). If a future CC-BY
pack is added, list it below **and** surface credit in-game.

## Backgrounds / tiles / UI / audio

| Asset | Source | License |
| --- | --- | --- |
| `backgrounds/*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/tiles/*.png` (+ neon-grid bake at runtime) | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/mop/*`, `sprites/shiny/*` | Original project art | Proprietary — Cinder and Crown LLC |
| `ui/logo_neon_city_bandit*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `audio/*` | Original project audio | Proprietary — Cinder and Crown LLC |

## Policy (binding)

- Prefer **CC0** (e.g. [Kenney.nl](https://kenney.nl)) when adding any future third-party pack.
- Otherwise **OpenGameArt / itch.io** packs with explicit **commercial use** (CC0 or CC-BY with attribution recorded here + in-game credits).
- **Forbidden:** ripped/unlicensed art, GPL-only assets, anything that resembles third-party IP (e.g. Sly Cooper lookalikes).

When a CC-BY asset is added, list: asset path, source URL, author, license, date, and whether in-game credits are required.
