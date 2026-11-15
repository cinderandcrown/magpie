# Trash Panda — Mission 1 generated assets

**Branch:** `assets/mission-1`  
**Date added:** 14 November 2026 (America/Chicago)  
**Purpose:** playable-quality placeholder art and audio for the Mission 1 neon heist level. These are original generated assets, not final production illustration.

## Important: public repo

`cinderandcrown/magpie` is a **public** repository. `AGENTS.md` / `docs/PLAN.md` say paid or licensed assets should live in a private content repo and must be logged in `ASSETS_LICENSES.md`. This pack was committed here because the Mission 1 asset task asked for `Assets/Generated/` on this branch. Consider moving the pack to the private content repo before a public release if counsel wants generated-media kept off the public tree.

These files are **not CC0**. They are all-rights-reserved material for Cinder & Crown LLC, and they are also subject to the terms of the tools that produced them (see Licence, below).

## How to use in SpriteKit

- **Sprites:** canonical frames are the unsuffixed PNGs (raccoon 256×256, MOP 384×256, shinies 128×128), bottom-anchored, premultiplied-friendly RGBA. `@2x` (128 / 192×128 / 64) and `@3x` (192 / 288×192 / 96) are downscales for a 64 pt sprite. The unsuffixed file is a higher-resolution master, not a 1× asset.
- **Backgrounds:** 2560×1440 PNG layers. Scroll them for parallax. They are **wide paintings, not seamless tiles** (unique storefronts, a centered moon on the far skyline, a walkable roof surface on the near layer that will fight the platform tiles if used as the ground). Composite `rain_overlay.png` (straight alpha) additively or with a small alpha over the mid/near layers.
- **Audio:** music is AAC `.m4a`, stereo, 44.1 kHz, loudness-normalized to about −14 LUFS. SFX ship as 44.1 kHz mono 16-bit PCM in both `.wav` and `.caf`. A 20 ms equal-power crossfade was applied to the two loopable music files; **verify the loop by ear** before shipping.
- Source sheets (green-screen keyed) live in `Assets/Generated/sprites/sheets/` if a frame needs to be recropped.

## Colour and legal (from `docs/DESIGN.md`)

Hero: warm rust-brown fur, dirty cream muzzle/belly, scavenged charcoal mask with a magenta LED rim and a teal status light, faded olive mechanic vest, mesh produce-bag backpack. **No cane, no top hat, no blue/gold gentleman-thief palette.** Mascot still needs attorney review (Sly Cooper / other raccoon-thief lookalikes).

---

## File list

### Audio — ElevenLabs

Generated with the official ElevenLabs API (`music_v2` for music, `eleven_text_to_sound_v2` for SFX) using the account already configured on this machine. The ElevenLabs MCP connector did not expose music or sound-effect tools (and `account_get_usage` required a `user_read` re-grant), so the CLI/SDK path from the ElevenLabs music and sound-effects skills was used instead.

| File | Duration | Purpose | Tool |
| --- | --- | --- | --- |
| `audio/level_loop.m4a` | 76.80 s | Loopable level music. Prompted as a 32-bar sneaky synthwave / lo-fi heist groove in D minor at 100 BPM. | ElevenLabs Music `music_v2` |
| `audio/mask_mode_layer.m4a` | 38.40 s | Loopable Mask Mode hype layer, same key and tempo, meant to sit on top of the level loop. | ElevenLabs Music `music_v2` |
| `audio/title_sting.m4a` | 8.23 s | Title-screen ident sting (requested ~6 s; model returned a longer clip, silence trimmed). | ElevenLabs Music `music_v2` |
| `audio/jump.wav` + `.caf` | 0.52 s | Jump whoosh | ElevenLabs text-to-sound-effects |
| `audio/land.wav` + `.caf` | 0.23 s | Paw landing on wet concrete | ElevenLabs text-to-sound-effects |
| `audio/collect_shiny.wav` + `.caf` | 0.68 s | Shiny pickup chime | ElevenLabs text-to-sound-effects |
| `audio/pounce.wav` + `.caf` | 0.43 s | Pounce lunge / claw swipe | ElevenLabs text-to-sound-effects |
| `audio/belly_flop.wav` + `.caf` | 0.42 s | Belly-flop impact | ElevenLabs text-to-sound-effects |
| `audio/tail_swing.wav` + `.caf` | 0.68 s | Tail whip and sign-fling | ElevenLabs text-to-sound-effects |
| `audio/mop_alert.wav` + `.caf` | 1.20 s | MOP spots the player | ElevenLabs text-to-sound-effects |
| `audio/mop_hit.wav` + `.caf` | 0.60 s | MOP takes a hit | ElevenLabs text-to-sound-effects |
| `audio/player_hit.wav` + `.caf` | 0.60 s | Player is tagged | ElevenLabs text-to-sound-effects |
| `audio/mask_mode_on.wav` + `.caf` | 1.60 s | Mask Mode activation | ElevenLabs text-to-sound-effects |
| `audio/checkpoint.wav` + `.caf` | 0.88 s | Checkpoint chime | ElevenLabs text-to-sound-effects |
| `audio/win.wav` + `.caf` | 1.86 s | Heist-success sting | ElevenLabs text-to-sound-effects |
| `audio/fail.wav` + `.caf` | 2.20 s | Bagged / fail sting | ElevenLabs text-to-sound-effects |
| `audio/ui_tap.wav` + `.caf` | 0.31 s | Menu tap | ElevenLabs text-to-sound-effects |

Post-process: ffmpeg, silence trim, loudness normalization (music ~−14 LUFS, SFX ~−16 LUFS / −1.5 dB true peak).

### Art — image generation (`GenerateImage`)

All paintings and sprite sheets were generated with the Cursor `GenerateImage` tool, then chroma-keyed (flat `#00FF00` screens), split, despilled, and resized with Python / Pillow. Higgsfield was not used.

#### Raccoon (`sprites/raccoon/`)

Each pose has `name.png` (256×256), `name@2x.png` (128×128), `name@3x.png` (192×192).

| File stem | Purpose |
| --- | --- |
| `idle` | Standing cocky idle, unlit mask |
| `run_01` … `run_06` | Six-frame run cycle (see quality notes) |
| `jump` | Jump, arms up |
| `fall` | Fall, limbs out |
| `pounce` | Mid-air pounce |
| `belly_flop` | Belly-down smash |
| `tail_swing` | Tail-whip fling (from a dedicated frame, not the action sheet) |
| `mask_mode` | Idle with mask LEDs blazing |

Sheets (keyed source): `sprites/sheets/raccoon-character-sheet.png`, `raccoon-run-cycle.png`, `raccoon-action-poses.png`, `raccoon-tail-swing-v2.png`.

#### MOP (`sprites/mop/`)

Canonical size 384×256, plus `@2x` / `@3x`.

| File stem | Purpose |
| --- | --- |
| `idle` | Parked, visor dim |
| `patrol` | Rolling, visor lit, brushes spinning |
| `alert` | Visor red, spotlight on |

Sheet: `sprites/sheets/mop-robot-sheet.png`.

#### Shinies (`sprites/shiny/`)

Canonical size 128×128, plus `@2x` / `@3x`. Four sparkle frames of the same foil bottle-cap with a teal gem: `shiny_01` … `shiny_04`. Sheet: `sprites/sheets/shiny-sparkle-frames.png`.

#### Platform tiles (`sprites/tiles/`)

`tile_01.png` … `tile_27.png`, natural sizes padded to multiples of 4. Wet concrete slabs, metal grates, brick ledges, magenta/teal neon strips, hazard curb, pipes, pallet, crate, vent, left/right roof caps. Sheet: `sprites/sheets/tiles-platforms.png`.

#### Backgrounds (`backgrounds/`)

| File | Size | Purpose |
| --- | --- | --- |
| `far_skyline.png` | 2560×1440 | Far rainy purple/teal city skyline and canal |
| `mid_buildings.png` | 2560×1440 | Mid neon shop row (SPOTLESS, GLOW MART, FIZZ, ARCADE ROW, DEN) |
| `near_rooftops.png` | 2560×1440 | Near rooftops, fire escapes, water towers |
| `rain_overlay.png` | 2560×1440 RGBA | Rain-streak overlay (transparent background) |

#### UI and icon

| File | Size | Purpose |
| --- | --- | --- |
| `ui/logo_trash_panda.png` | ~2048 px wide, transparent | “Trash Panda” wordmark, magenta neon edge, small raccoon-mask accent in the A |
| `ui/logo_trash_panda@1024.png` | ~1024 px wide | Smaller wordmark |
| `icon/AppIcon-1024.png` | 1024×1024 RGB, no alpha | App icon: raccoon mask on neon rain, no typography |

---

## Licence

| Source | What it covers | Licence / terms |
| --- | --- | --- |
| ElevenLabs Music and text-to-sound-effects | All files under `Assets/Generated/audio/` | Generated by the Cinder & Crown ElevenLabs account. Use is subject to the [ElevenLabs Terms of Service](https://elevenlabs.io/terms). **Not CC0.** Cinder & Crown LLC claims all rights it has in the outputs, all rights reserved, consistent with `NOTICE`. |
| Cursor `GenerateImage` | All files under `Assets/Generated/{sprites,backgrounds,ui,icon}/` | AI-generated illustrations produced for Cinder & Crown LLC. Subject to the image-generation provider’s terms. **Not CC0.** All rights reserved, consistent with `NOTICE`. |

No third-party stock art, fonts, or licensed libraries are included. Invented signage on the mid layer (SPOTLESS, GLOW MART, FIZZ, ARCADE ROW, DEN) is original.

---

## Quality and consistency notes (honest)

These are good first-pass game assets, not final animation or environment art.

1. **Run cycle is weak.** Frames 1–5 are similar mid-stride poses, not a full contact / down / passing / up cycle. `run_06` is closer to a walk and has a more strongly lit / pinker mask than the other run frames.
2. **Mask lighting is inconsistent.** Idle and several action poses use a darker unlit mask; the run cycle and Mask Mode read as already-glowing magenta LEDs.
3. **Tail swing is slightly off-model.** It was generated as a dedicated frame so the pose would read. The raccoon is still chubby with the olive vest, mesh backpack, and LED mask, but the proportions and face are a bit more dynamic / less “sheet-consistent” than idle and jump, and the paws read slightly more like gloves.
4. **Faint green-screen fringe** remains on some sprite edges (especially tails and feet) after chroma key and despill. Recrop from the sheets or a second despill pass will clean this up.
5. **Backgrounds do not tile seamlessly.** A first attempt at an offset-blend seam made a visible blur band, so the original wide paintings were shipped instead. The far layer has a centered moon that will double if the layer wraps. The mid layer is a unique shop row. The near layer includes a walkable wet roof in the lower third — treat that as scenery, not as the collision floor (use the tile set for platforms). The mid layer also already contains a distant skyline, which will double up if stacked under `far_skyline.png` without cropping or dimming.
6. **Icon** is a more painterly, close-up portrait than the side-view sprites (normal for an app icon). An earlier circular-cropped draft was discarded. A garbled neon sign on the left of the chosen square rendering was colour-patched; a slight smudge may still be visible in that corner. No typography remains.
7. **Logo** wordmark is correctly spelled “Trash Panda.” The tiny raccoon face in the letter A is a generic accent, not the in-game sprite.
8. **Style mix.** Sprites and tiles are cel-shaded with a thick outline. Backgrounds and the icon are more painterly / cinematic. They share a magenta/teal night-city palette but will not look like one illustrator’s hand.
9. **Incidental likeness risk.** The icon and the cocky vest-wearing raccoon can vaguely recall other popular raccoon characters (not Sly Cooper — there is no cane, top hat, or blue/gold formal look — but a reviewer should still look at it). The design doc already flags attorney review of the mascot.
10. **Audio** was not auditioned on a device in this pass. Prompts requested instrumental-only music and dry, punchy SFX; confirm there are no unexpected vocals, and confirm the two loops actually feel seamless at 100 BPM. The title sting is 8.2 s rather than a tight 6 s ident. `land` and `ui_tap` were generated at the 0.5 s API minimum and then trimmed.
11. **No Higgsfield outputs** are in this pack. Official character sheets were used as `reference_image_paths` for later raccoon frames to keep the design consistent.

A contact sheet of the sprites, tiles, backgrounds, logo, and icon is saved at `/workspace/trash-panda-assets/contact-sheet.png` on the agent box (not committed to the repo).
