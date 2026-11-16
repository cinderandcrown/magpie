# Asset licenses — The Neon City Bandit (MAGPIE)

All gameplay art and audio in this repository are either:

1. **Original** work created for this project (Cinder and Crown LLC),
2. **Procedural derivatives** of those originals, or
3. **Third-party** assets with an explicit commercial-use license (CC0 or CC-BY), logged below.

Also see root `ASSETS_LICENSES.md` and `docs/ASSETS.md`.

## Raccoon / bandit / MOP (primary — Spriterrific)

| Asset | Source | License | In-game credits |
| --- | --- | --- | --- |
| `sprites/spriterrific/**` + `sprites/spriterrific_ready/**` (bandit, mop_bot, mop_9000_boss) | Spriterrific AI ([spriterrific.com](https://spriterrific.com)); original text prompts on Cinder & Crown account — see `Assets/Generated/sprites/spriterrific/README.md` and `Assets/SPRITERRIFIC_ANCHOR.md` | Owned by **Cinder and Crown LLC** | Yes — `Art: Spriterrific (Cinder & Crown)` |

Side views face WEST; ready frames are foot-baseline-normalized 256². `disco_dance` reserved for backlog easter egg. `bandit/anchor-s.png` for menu/Hideout.

## Raccoon / bandit (legacy fallback — OGA CC-BY)

| Asset | Source URL | Author | License | In-game credits |
| --- | --- | --- | --- | --- |
| `sprites/raccoon/*.png` + `sprites/raccoon/licensed_ccby/**` | [Cute raccoon 2d game sprite and animations](https://opengameart.org/content/cute-raccoon-2d-game-sprite-and-animations) | null-painter-error | **CC-BY 4.0** | Keep attribution while files remain in tree |

## Juice SFX

| Asset | Source | License |
| --- | --- | --- |
| `Assets/Audio/sfx/**` (41 WAVs + `sfx_manifest.json`) | Fire Fox / ElevenLabs 2026-11-15 | Cinder & Crown; ElevenLabs ToS |

## Raccoon procedural rig (fallback / squash helpers)

| Asset | Source | License |
| --- | --- | --- |
| `sprites/raccoon/rig/*.png` | Crops + palette-matched capsules derived for procedural SKAction poses | Same as parent raccoon sheet above when used with CC-BY pack; otherwise original project derivative |

## Backgrounds / tiles / UI / audio

| Asset | Source | License |
| --- | --- | --- |
| `backgrounds/*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/tiles/*.png` (+ neon-grid bake at runtime) | Original project art | Proprietary — Cinder and Crown LLC |
| `sprites/mop/*`, `sprites/shiny/*` | Original project art | Proprietary — Cinder and Crown LLC |
| `ui/logo_neon_city_bandit*.png` | Original project art | Proprietary — Cinder and Crown LLC |
| `audio/*` | Original project audio | Proprietary — Cinder and Crown LLC |

## Policy (binding)

- Prefer **CC0** (e.g. [Kenney.nl](https://kenney.nl), [Quaternius](https://quaternius.com), [Poly Pizza CC0](https://poly.pizza)) when adding third-party packs.
- Otherwise **OpenGameArt / itch.io / Sketchfab** with explicit **commercial use** (CC0 or CC-BY with attribution here + in-game credits).
- Pre-rendered 3D → 2D sheets are allowed when the source model is CC0/CC-BY (log source URL, author, license, date).
- **Forbidden:** ripped/unlicensed art, GPL-only, NC/ND/personal-use-only, anything that resembles third-party IP (e.g. Sly Cooper lookalikes).

When a CC-BY asset is added, list: asset path, source URL, author, license, date, and whether in-game credits are required.
