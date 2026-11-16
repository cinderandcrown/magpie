# Asset licenses — The Neon City Bandit (MAGPIE)

All gameplay art and audio in this repository are either:

1. **Original** work created for this project (Cinder and Crown LLC), or
2. **Procedural derivatives** of those originals (crops / tint / neon-grid bake / limb-rig parts).

No third-party character packs were imported for the raccoon. The living run/jump/fall
motion is a **procedural limb/tail/head rig** cropped from the project’s own `raccoon/idle`
sheet and driven with SpriteKit `SKAction`s (zero art budget; commercial-safe).

## Raccoon / bandit

| Asset | Source | License |
| --- | --- | --- |
| `sprites/raccoon/*.png` (idle, run_01–06, jump, fall, pounce, belly_flop, mask_mode, tail_swing) | Original project art | Proprietary — Cinder and Crown LLC; used under Magpie repo terms |
| `sprites/raccoon/rig/*.png` (optional exports of head/torso/arm/leg/tail crops) | Derived by cropping idle sheet | Same as parent sheet |

## Backgrounds / tiles / UI / audio

| Asset | Source | License |
| --- | --- | --- |
| `backgrounds/*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/tiles/*.png` (+ neon-grid bake at runtime) | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/mop/*`, `sprites/shiny/*` | Original project art | Proprietary — Cinder and Crown LLC |
| `ui/logo_neon_city_bandit*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `audio/*` | Original project audio | Proprietary — Cinder and Crown LLC |

## Policy (binding)

- Prefer **CC0** (e.g. Kenney.nl) when adding any future third-party pack.
- Otherwise **OpenGameArt / itch.io** packs with explicit **commercial use** (CC0 or CC-BY with attribution recorded here + in-game credits).
- **Forbidden:** ripped/unlicensed art, GPL-only assets, anything that resembles third-party IP (e.g. Sly Cooper lookalikes).

When a CC-BY asset is added, list: asset path, source URL, author, license, and whether in-game credits are required.
