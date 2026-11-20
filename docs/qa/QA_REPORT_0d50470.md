# QA Report — The Neon City Bandit — build 0d50470 (primary), with 3608d51 for comparison

QA lead review, 2026-11-15 (CT). Bar: Vibe Game Dev / EA-Rockstar polish, CoC/STFC retention, CoD-style punch.

**Primary build: 0d50470**, CI run 43801746438, green (finished 10:27 PM CT). Artifacts in `/workspace/vidcheck/b/`: smoke-gameplay.mp4 (84.2 s), 8 moment shots, palette-side-by-side.png, audio + timer logs.
**Previous build: 3608d51**, artifacts in `/workspace/vidcheck/a/` (219.5 s video). Used for the regression comparison and most of the frame-level detail; structure, tiles, sprites, HUD and screens are unchanged between the two.
Code read at 0d50470 in `/workspace/qa-magpie`.

Evidence files (all in `/workspace/qa/`):
- `evidence_b/KEY_build_0d50470.png`: 5 states of the primary build (run / Mask / mid-level / results / Daily Heist)
- `evidence_b/b_palette-side-by-side.png`: **CI's own palette check. The in-game frame is flat purple and crates; the art target is a rich neon storefront street.** This single image is the gap.
- `evidence_b/b_04-mask-mode.png`, `b_mask_ghost_19s.png`, `b_feet_12s.png`, `b_06-results.png`, `b_08-daily-heist.png`
- `sheets_b/sheet_tNNN.png` (1 fps, 24 s per sheet), `sheets_b/{stomp_19s,hurt_22s,ko_43s}.png` (10 fps player-row strips)
- 3608d51: `sheets_a/*`, `evidence_a/KEY_background_states.png` (the white blowout), `evidence_a/a_feet_float_26s.png`, `crops/*.png`

## What changed 3608d51 → 0d50470

- **Fixed: white / grey background blowout.** 3608d51 had white behind the level in **94 of 220 s (43%)** and grey-lavender in 51 s (23%). 0d50470 has **0 white and 0 washed seconds out of 84** (median-luma check of the sky band on every 1 fps frame). Real progress.
- **Better:** results stars now stagger in (2★ at 0:59 → 3★ at 1:00).
- **Unchanged:** everything else below: the tiles, the poles, the hidden city, floating MOPs, the Mask ghost head, the missing pause, the smoke-only code paths and the sparse screens.
- The fix was done by **removing the parallax recolor and adding more smoke-only branches** (smaller smoke textures, mask music skipped under smoke). Because of P0-2, it is not yet proven on the real ship path.

## Verdict

**Overall: 4 / 10 (0d50470). Was 3.5 / 10 on 3608d51. Not TestFlight-ready.** Nicholas is right: it's getting better, but it isn't close.
The raccoon and MOP sprites are good, the juice code exists, and the screen no longer goes white. But the level reads as a shelf of random crates behind prison bars, on a flat purple fill that hides the actual neon city art the team already has (see the palette image). The smoke harness also runs a *different game* from the one that ships (a different level, Mask at 1 stomp, most SFX muted, smaller textures). So a green CI run still says little about the TestFlight build.

## Scores (1–10 against the bar)

| Area | Score | One-line why |
|---|---|---|
| Art cohesion & readability | **3** (was 2) | Blowout fixed in 0d50470, but the city parallax is still hidden behind a flat wash (hard cut under the skyline). Top-down/3/4-view crate and pipe props are used as side-view ground in a random round-robin. Cyan "prison bar" poles everywhere. |
| Character / enemy sprites (in isolation) | 6.5 | Raccoon and MOP art are good and on-brand. They're undermined by scale, floating feet and the backgrounds. |
| Animation | **4** | Frame rate is fixed by time, not speed (foot-slide risk). Jump/fall are single frames. MOPs hover about half a tile above the floor. The Mask ghost aura is a huge blurry translucent raccoon head. |
| Game feel / juice | **4** | The code has 70 ms hit-stop, shake and squash. In frames the stomp barely reads, the shake is a fixed hand-authored wiggle, and the camera is static for the first 27 s. Smoke cuts particles and SFX, so the real feel is unverified. |
| Level design | **2.5** | No autotiling. Walls are stacked boxes. There's no silhouette and no foreground/background separation. The bot dies 7 times on the same ~20 s segment, so the difficulty is unreadable or unfair. The camera shows ~9 tiles wide in portrait. |
| UI / UX | **4** | Clean neon buttons and cards. But there's no pause button or menu, the results card is sparse with no reward beat, the map is a wireframe, the title buttons overlap live gameplay sprites, and the HUD timer disagrees with the card time. |
| Audio (events) | **3** (unverifiable) | The log shows only ~10 event types. Jump/land/collect/combo are muted under smoke. Mask sting and stomp crunch fire 33 ms apart (mud). The architecture decodes from disk per play. |
| Retention hooks | **3** | Map and Daily Heist exist as screens. Stars only, no streak, no reward count-up, no rank/XP beat, no daily reason to return yet. |
| Performance hints | **4** | 98 frame gaps of 66–232 ms (sim recording) cluster on Mask on/off and deaths. Per-column SKShapeNode poles, color-only sprite washes and AVAudioPlayer-per-SFX are all known perf traps. |

---

## P0 — blocks TestFlight

### P0-1. Background layer stack: blowout fixed in 0d50470, but the root cause and the gate remain
- **Status in 0d50470:** no white or washed frames in the 84 s smoke. Keep this item open until the ship-path smoke (P0-2) shows the same result and the wash layer is gone. The flat purple you now see *is* the same wash quad, just no longer turning white.
- **What (3608d51):** After the first Mask Mode, the area behind the level renders **solid white** whenever Mask is off, and **grey-lavender** while Mask is on. The pre-Mask state (0–27 s) is the only correct dark look. This persists across retries and also appears on Daily Heist and behind the Results card.
- **Evidence:** `evidence_a/KEY_background_states.png`. White at 32, 37–49, 56, 62–72, 78–92, 97–98, 103–113, 124–133, 143–155, 179 and 207–219 s (`sheets_a/sheet_t024.png`, `sheet_t048.png`, `sheet_t144.png`, `sheet_t192.png`). Washed at 28–35, 50–61, 180–190 s (results card on grey: `sheet_t168.png` @3:05–3:10). **CI screenshot `04-mask-mode.png` is itself a white frame with no Mask HUD (timer 145 s), and the run still passed**, so the screenshot gate is checking the wrong moment or the wrong metric (`crops/mask_play.png`).
- **Root cause (code):** `HeistScene.buildAtmosphere()` adds `worldNightWash`, a color-only `SKSpriteNode` sized mapW+400 × mapH+320 at world z −8. `view.ignoresSiblingOrder = true`, so it draws **above** every parallax plate (z −10…−30). It is the visible "background" over the whole map. The white region in every white frame is exactly this rectangle, with a hard edge at the top where the skyline gets cut off. Three successive commits (cyan wash → white blowout → "memory pressure") have patched symptoms with smoke-only branches instead of removing the layer.
- **Fix:**
  1. Delete `worldNightWash`, `stageBackdrop` and the per-frame `color/colorBlendFactor` rewrites in `sync()`. Keep only `scene.backgroundColor = nightSky` plus the textured parallax plates, which must fully cover the viewport with tiled plates extended vertically.
  2. Put the parallax at z below the tile map *and* make sure nothing between −30 and 0 is an opaque full-map quad.
  3. Mask Mode must be **character-only** (glow, trail, rim light) plus at most a real radial-gradient **texture** vignette (transparent centre, PNG). No full-screen `SKSpriteNode(color:)` at all. Per VIBEGAMEDEV_METHODS: "NEVER a full-screen wash".
  4. Replace the CI color gate with a **per-frame** luminance/saturation check over the *whole video* (sample at 2 fps): fail if the median luma of the sky band (y 25–40%) is above 60 or saturation is below X for >0.5 s in gameplay. The 8-screenshot check missed a 43%-of-runtime defect.

### P0-2. The smoke harness tests a different game from the one that ships
- **What:** Under `-SmokeAutoplay`:
  - `maskModeAtCombo = 1` (ship: 5) and `comboGroundGrace = 4`
  - a separate `SmokeDemoLevel` instead of Neon Docks
  - 768 px plates instead of 1280 px
  - all jump/land/pounce/collect/checkpoint SFX skipped
  - Mask music layer skipped, jingle skipped
  - fewer particles and a different shake amplitude

  There are 58 `smokeEnabled` branches in HeistScene.swift. The bot also deliberately idles against the left wall for the first 27 s (`smoke_midrun_ok` hold), so the video shows almost no walking or running.
- **Evidence:** `HeistScene.swift:104-108, 195, 242, 256, 1290-1298, 1604-1608, 2025-2040`. `JuiceSound.swift:110-116, 219-223`. Raccoon pinned at the same x for 0–27 s in `sheets_a/sheet_t000.png` and `walk_3s.png`.
- **Fix:** Keep the smoke brain (input driver plus flags) but make **render, audio, tuning and level identical** to the ship build. Add a second CI pass `-SmokeShip` that plays real Neon Docks level 1 with ship tuning and full audio for 60 s and records it. Allowed smoke-only differences: deterministic seed, input source, the status file. Nothing visual or audible. Kill the wall-idle hold: take the midrun screenshot while running.

### P0-3. No pause and no app-lifecycle handling
- **What:** No pause button or pause menu in the HUD. There's no handling of `willResignActive`, `didEnterBackground` or `scenePhase`, and no AVAudioSession interruption handling (grep finds none). A phone call or swipe-home mid-run keeps the sim/timer running or desyncs audio. This is a basic App Store review and player-trust issue.
- **Evidence:** HUD in every gameplay frame (e.g. `evidence_a/a_t026s.png`): only score, hearts and timer at top-left, nothing at top-right. `rg -n "willResignActive|scenePhase|isPaused|interruption"` returns nothing.
- **Fix:** Add a top-right pause button in the safe area. The pause sheet offers Resume / Restart / Settings (music & SFX sliders, haptics, left-handed swap) / Home. Auto-pause on `UIApplication.willResignActiveNotification` and on `AVAudioSession.interruptionNotification`. Resume shows a 3-2-1 count.

### P0-4. Tile art is wrong for a side-scroller and placed at random
- **What:** `buildTiles()` assigns `groups[tileIdx % groups.count]`, cycling through **all 27 textures** (crates, pipe racks, pallets, puddled concrete, grates, AC units, hazard blocks) in sequence across ground and walls. The textures are 3/4 top-down props, so floors look like rows of boxes on a shelf, and walls look like stacked mismatched crates with visible outlines around every tile. There are no top edges, no caps and no fill tiles.
- **Evidence:** `crops/midrun_play.png`, `crops/stomp_play.png`, the left wall in `crops/feet_3s.png`, and the right column in `crops/heist_play.png`.
- **Fix:**
  1. Generate or source a proper **side-view neon-city tileset** with a 47-blob or 16-tile autotile set: top-surface tile with a neon edge-light strip, fill tile, left/right caps, inner corners, a one-way catwalk platform, and wall face. Use Spriterrific or CC0 (Kenney / OpenGameArt "industrial/cyberpunk" side-view sets).
  2. Implement bitmask autotiling with SKTileSet adjacency rules or a manual 4-neighbour mask.
  3. Demote crates, AC units, pipes and pallets to **decoration props** placed by the level file, not the collision tiles.
  4. Remove per-tile outline strokes. Brighten the top surface (walkable reads instantly) and darken the fill.

## P1 — needed to feel good

### P1-1. Scaffold poles read as prison bars
- **What:** Every floating ledge column drops a cyan-stroked `SKShapeNode` pole to the next floor, plus pink braces. The result is a full-screen grid of vertical cyan lines that competes with the player and MOPs, against the doc rule "Parallax and HUD colors must not compete with the playfield". It's also dozens to hundreds of SKShapeNodes, which are expensive.
- **Evidence:** All gameplay frames, e.g. `evidence_a/a_t040s.png` and `sheets_a/stomp_28s.png`.
- **Fix:** Replace them with baked sprite supports (dark, low-contrast girders), only every 3–4 tiles or where the level file marks them. No cyan stroke. Neon belongs on walkable edges and interactables only.

### P1-2. The Neon City is hidden; the background is flat (now the most visible art problem in 0d50470)
- **Evidence (0d50470):** `evidence_b/b_palette-side-by-side.png` and `evidence_b/b_04-mask-mode.png` (skyline hard-cut at ~20% height, then flat purple to the floor).
- **What:** The parallax skyline only shows in the top ~15% strip above the map (because of the wash in P0-1). There is no visible mid or near layer and no Tron-like grid horizon behind the action. About 55% of the screen is flat purple or white.
- **Evidence:** `crops/title.png` (hard horizontal cut under the skyline at ~15% height), `evidence_a/a_t026s.png`.
- **Fix:** After P0-1, scale and tile the far/mid/near plates to cover the full viewport height. Add the perspective grid horizon as a visible lower layer at low alpha. Add a dim foreground silhouette layer (railings, cables, signs) moving at 1.2× for depth. Darken and desaturate the parallax about 30% so sprites pop.

### P1-3. Characters float and look small in a tall portrait frame
- **What:** MOPs hover about 0.5–0.7 tile above the floor (skirt bottom well above the top of the grate). The raccoon also sits clearly above the surface in several frames. At worldZoom 1.42 with 32 pt tiles, the player is about 1.4 tiles tall in a ~19-tile-high frame, so the gameplay band is ~40% of the screen and the hero is tiny.
- **Evidence:** `evidence_b/b_feet_12s.png` (0d50470: the raccoon and MOP both hover clearly above the concrete), `evidence_a/a_feet_float_26s.png` (three MOPs floating over grates), `crops/feet_3s.png`.
- **Fix:** Run the "Normalize" step from the methods doc: measure each sheet's real foot baseline per frame and set `footAnchorY` from data, not the 0.11 fallback. Snap MOP `home.y` to tile top + 0. Raise worldZoom to about 1.9–2.1, or make the camera frame about 12 tiles high with the HUD and controls over a darker letterbox. Consider tilting the level band so more is visible ahead.

### P1-4. Mask Mode is not an earned moment and reads as mush
- **What:** Mask fires on the first stomp (smoke) with no build-up. The visual is a giant translucent blue raccoon-head ghost behind the hero plus a full-screen tint. The `mask_mode_on` sting and `stomp_crunch` fire 33 ms apart every time, so the two big sounds smear together.
- **Evidence:** `evidence_b/b_mask_ghost_19s.png`, `sheets_b/stomp_19s.png`, `sheets_a/stomp_28s.png`, `hurt_34s.png`. Audio log (0d50470) 18.898/18.914, 28.082/28.098, 46.752/46.775. Audio log (3608d51) 28.734/28.800, 34.501/34.550, 51.334/51.393 s and every later life.
- **Fix:**
  - Visual: replace the ghost head with a crisp mask-LED eye glint, a cyan rim light on the sprite, and a short afterimage trail of 3 copies at decreasing alpha.
  - Timing: 120 ms hit-stop on Mask entry, a big "MASK MODE" stamp that slams in and out within 0.6 s, a camera punch-in of 1.06× for 0.25 s, and music filter sweep.
  - Audio: sequence stomp → 90 ms → mask sting, with the stomp ducked under the sting.
  - Cue: show the combo meter filling toward 5 in the HUD so the player feels it coming.

### P1-5. Stomp and hit feel do not read on screen
- **What:** In the 10 fps stomp/hurt strips, the stomp and the hurt look the same as walking past a MOP. There's no visible MOP squash, no score pop large enough to read, no flash on the MOP, and the shake isn't visible. On hurt, two MOPs overlap the raccoon (34.9–35.2 s) with no knockback readable. The death beat is about 0.75 s from `raccoon_ko` to `ui_tap` retry, and in-world frames show no death pose.
- **Evidence:** `sheets_b/stomp_19s.png` (0d50470: the stomped MOP tips over sideways and slides along beside the raccoon for ~1 s instead of popping flat), `sheets_b/ko_43s.png` (KO at 42.917: the raccoon is simply off-frame, then reappears at 43.1 with no death pose; the card is suppressed by the smoke `smoke_mask_ok` gate, another smoke-only difference), `sheets_a/stomp_28s.png`, `hurt_34s.png`, `ko_49s.png`. Audio log (3608d51) KO at 49.567 → tap 50.317.
- **Fix:**
  - Stomp: MOP white-flash frame (1 frame at 100% white via shader or colorize), squash to 1.4×0.3 then pop into 6–10 parts or debris, bigger "+N" popup (24 pt, outlined, rising 30 pt), and Perlin-noise trauma shake (trauma 0.35, decays) instead of the fixed 4-step wiggle. Hit-stop 90 ms on normal stomps, 150 ms on combo ≥3.
  - Hurt: 1-frame red flash, 6–8 pt knockback with an arc, 1 s blink invulnerability, MOP separation.
  - Death: 0.6 s slow-mo plus a death pose, then the SPLASHED card.
  - Verify all of this in the ship-path smoke from P0-2.

### P1-6. Unreadable or unfair difficulty: 7 deaths on the same ~20 s
- **0d50470:** 2 KOs and 4 hurts before the win at 59.9 s. Shinies sit inside MOP patrol paths, with the gear drawn over the MOP's feet (`sheets_b/ko_43s.png`), so collecting means taking a hit.
- **What (3608d51):** The bot dies at 49, 71, 90, 111, 131, 154 and 162 s, each after roughly the same Mask → hurt → hurt → KO sequence, and wins once at 186 s. MOPs bunch two to three deep on the same lane (`hurt_34s.png`, `sheet_t096.png` @1:51–1:53).
- **Fix:**
  - MOP spacing rule: at least 4 tiles between patrols on the same platform, staggered phases, and a 0.3 s "alert" tell (`mop_bot_alert` is wired in code but muted under smoke, so it's unverified) before a MOP turns to attack.
  - Give Mask Mode contact-damage immunity against MOPs, a common power-fantasy expectation.
  - Add 2 checkpoints per level.
  - Log real-human deaths per segment in TestFlight analytics (local only).

### P1-7. Animation driving
- **What:** Walk and run play at a fixed 12/14 fps by time (`ArtCatalog.show`, plus `playLoop` with a fixed timePerFrame), not scaled by horizontal speed, which causes foot sliding at partial stick. Jump, apex and fall are one static texture each. The death fallback indexes the global `bobPhase` (never reset), so it can start on its last frame.
- **Fix:** Set `animate` speed = |vx| / runSpeed (clamped 0.6–1.4). Add a 3-frame jump (crouch/launch/rise), an apex hang frame, a 2-frame fall loop and a land squash frame. Reset the phase on every state change.

### P1-8. Results / death / map screens lack the reward beat
- **What:**
  - Results is a small card with three stars, a gear count, a time and the combo. There are no labels for what each star means, no count-up, no "NEW BEST", no XP or rank bar, and nothing unlocked.
  - The card time (6.1 s / 7 s) disagrees with the HUD timer (145 s+).
  - The district map is a thin wireframe: two circles, two lock dots, odd ruler ticks at the top, and a tiny raccoon floating under the panel.
  - The SPLASHED death card sits on a dimmed level and is fine but plain.
- **Evidence:** `sheets_a/sheet_t168.png` @3:05–3:10, `sheet_t192.png`, CI `06-results.png`, `07-district-map.png`.
- **Fix:**
  - Results sequence (CoD rank-up feel):
    1. Stars slam in one at a time, labelled Finish / All Shinies / Par time, using the existing `star_1-3.wav`. Note that `tally_tick`, `new_best` and `level_up` ship in Assets/Audio/sfx but aren't referenced anywhere in code.
    2. Loot count-up with `tally_tick.wav`.
    3. A "NEW BEST" stamp with `new_best.wav`.
    4. A rank/XP bar fill with a level-up pop (`level_up.wav`).
    5. "Next unlock" preview.
  - Fix the time source so the HUD and card agree.
  - Map: real art per district (Spriterrific), a glowing path, node thumbnails, star counts and a locked-district preview, with the raccoon standing on the current node.

### P1-9. SFX architecture: decode per play
- **What:** `SFXManager` keeps "URLs only — no PCM buffers" and the legacy path builds AVAudioPlayers per event. The scene comment admits "AVAudioPlayer decode on every event tanks sim FPS below 55". That's why smoke mutes most SFX. On device, a rapid combo would stutter or drop sounds.
- **Fix:** Use AVAudioEngine with a pool of 12–16 AVAudioPlayerNodes and pre-decoded short SFX (<1 s, 44.1 k mono, a few MB total) into `AVAudioPCMBuffer` at launch. Stream music via AVAudioPlayer. Cap each SFX to 3 voices with a 40 ms re-trigger guard. Then re-enable every SFX in smoke.

### P1-10. Title screen layering
- **What:** The title overlays the live level. MAP/DAILY/MUTE buttons sit on top of gear shinies and a MOP. The title disc is a flat magenta circle, the raccoon is tiny, the instruction plate is plain, and the skyline gets a hard cut (P0-1).
- **Evidence:** `crops/title.png`, CI `01-title.png`.
- **Fix:**
  - Dedicated title scene: hero key art (Spriterrific splash of the raccoon on a neon rooftop), logo with animated neon flicker, the startup jingle synced to a logo slam.
  - One big PLAY button. Map, Daily and Settings as icon buttons along the bottom, with a 25% dark blur behind them.
  - Move the control hint into the FTUE.

## P2 — polish

1. **HUD:** the score icon "✦ 1" is cryptic. Use the actual shiny icon with a count, and add a combo meter and a Mask meter. Move the timer to top centre in small type. The HUD outline/glow label stacks triple-draw text, so bake it into one styled label.
2. **Controls:** the stick base at full alpha in smoke hides the real 0.22 dock look. Verify the real one. The JUMP/POUNCE buttons are small (the doc asks for a big thumb target): 72 pt minimum, with a pressed-state scale and haptic.
3. **EXIT / checkpoint** are `SKShapeNode` placeholders (green rounded rect, 9 pt "EXIT" label, lime flag rect). Replace them with an art door and an animated beacon checkpoint (`crops/heist_play.png`).
4. **Rain** is cyan dashes at 55/s. Make it thinner and more varied, add splash particles on the top surfaces, and add a wet-floor reflection strip under the neon edges.
5. **Shinies:** the gold cog art is good, but there's no idle bob or sparkle loop and no magnet pull on collect. Add a 4-frame shimmer.
6. **Daily Heist** (still true in 0d50470, `evidence_b/b_08-daily-heist.png`) shows no screen identity: no date, no seed name, no leaderboard stub, no streak. Add a header card with today's date, a "Same heist for everyone" note and your best time.
7. **Debug look:** remove the per-tile 1 px outlines and the magenta under-ledge strips. They read as editor gizmos.
8. **Credits:** "Art: Spriterrific (Cinder & Crown)" on the title belongs in Settings › Credits.

## Retention check vs DESIGN.md (binding plan)

Present: stars on clear only (good), district map screen, Daily Heist run, no nag popups (good), no firearm wording (good).
Missing for a "come back daily" build: streak counter and calendar, a daily reward claim (free, no timers), ghost of best run, Weekly Bounties, a rank/XP track, crew unlock tease, and Game Center leaderboards. Recommend shipping the first TestFlight with **streak + daily claim + rank bar on results** at minimum. All are free and fully earnable.

## Performance hints (from the sim recording; verify on device)

- 0d50470: 75 frame gaps over 50 ms in 84 s (520 ms at boot; 201 ms at 17.28 s just before Mask; 235 ms at 42.82 s at KO; 184 ms at 44.12 s on retry). Same pattern as before: hitches on state changes.

- 98 frame gaps of 66–232 ms. The largest (232 ms at 27.47 s, 116 ms at 28.43 s) sit right before and at Mask entry, and clusters sit at every death/retry (49–50, 70–73, 89–91, 110–113, 130–134 s). That fits audio decode plus texture work on state changes.
- Dozens to hundreds of `SKShapeNode`s (one per floating-ledge column plus braces) (poles, braces, water, spikes, doors, rings): bake them into textures. `SKShapeNode` with `glowWidth` is especially costly.
- Add Instruments (Time Profiler + Metal System Trace) on a real iPhone for 60 s of real Neon Docks. Target a 16.6 ms frame with no hitch over 25 ms.

## Ask of the game agent, in order

P0-1 → P0-4 → P0-2 → P0-3, then P1-1/2/3 together (they're the same "make it look like a neon city" pass), then P1-4/5/6, then P1-8/9.
After each pass, post a side-by-side of the same 5 timestamps against this report's `KEY_background_states.png`.
