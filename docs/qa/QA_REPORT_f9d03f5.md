# QA Report, round 3: The Neon City Bandit, build f9d03f5

QA lead review, 2026-11-16 ~4:50 AM CT. Same method and bar as rounds 1–2: Vibe Game Dev / EA-Rockstar polish, CoC/STFC retention, CoD-style punch.

**Primary:** f9d03f5, CI run 43843577456 (green). Artifacts in `/workspace/qa/r3_f9d03f5/`: 14 screenshots, a 165.9 s smoke video at 442×960 with an audio track, `smoke_audio_events.txt` (18,083 lines) and the timer log.
**Diffed against:**
- **33257aa**, the build on Nicholas's TestFlight. CI 43827720154; artifacts in `/workspace/qa/r3_33257aa/` (112 s video).
- **56504ee**, round 2 (`/workspace/vidcheck/c/`).

Code read at f9d03f5. Between 33257aa and f9d03f5 there are only 4 commits: two CI harness changes, the round-2 QA report, and **one** art change (f9d03f5: brighter rim and fur lift, denser additive neon sign rectangles, slightly lower plate tint). The round-2 fix batch itself (ee591d6, 4928396a, 92b1f90, 39aef47) is already in 33257aa.

**Contact sheet:** `/workspace/qa/contact_r3_f9d03f5.png`. Rows are 56504ee / 33257aa / f9d03f5 at mid-run, Mask, stomp, results and Daily Heist, plus f9d03f5 close-ups.
Other evidence:
- `r3_f9d03f5/sheets/sheet_tNNN.png` (1 fps, 24 s per sheet)
- `r3_f9d03f5/sheets/{hurtstomp_4s,maskon_24s,ko_17s,ko_118s,run_136s}.png` (8–10 fps player-row strips)
- `r3_f9d03f5/ev/*.png` (crops), `r3_*/shots_grid.png` (all 10 moment shots per build)

## Verdict

**Score: 6 / 10** (56504ee was 5.5; 33257aa ≈ 6).
Real progress since round 2:
- the raccoon is about twice the size
- Mask LEDs sit on the head and the afterimages are silhouettes
- the pause menu and background-pause are now captured by smoke
- results show a NEW BEST stamp, a tally tick, and a time that matches the HUD
- SFX use voice pools
- the CI gates measure sensible things

But this round found **a new P0 regression that is in Nicholas's TestFlight build (33257aa) too.** The land event fires every frame while the raccoon is on the ground. That plays the `land` SFX ~25×/s (4,660 `sfx land` lines in this run), spawns 8 orange `SKShapeNode` dust puffs per frame (the permanent orange "jet" trail behind his feet), and restarts the squash action every frame. It's a feel bug, an audio bug and a likely cause of the FPS drop.

**Is f9d03f5 worth a new TestFlight tag before Nicholas's feedback? No.** Visually it's nearly identical to 33257aa (contact sheet rows 2 vs 3): a slightly stronger rim and a bit more teal. It carries the same land-spam bug. Tag the build that fixes P0-1 below. That one *is* worth replacing his build for, because it changes how every step sounds and looks.

## Round-2 items: status

| Round-2 item | Status | Evidence |
|---|---|---|
| **Darkness / neon** | **Partial** | Play-area mean luma 27 → 28 → **33**/255 (56504ee → 33257aa → f9d03f5, median over all 1 fps video frames). Bright-pixel share 3.7% → 4.2% → **6.6%**. Neon (gate formula): teal 0.95% → 1.08% → **1.52%**, but **magenta ≈ 0.0–0.03%**, and the mid-run shot has 0.00% magenta. The agent-reported "1.35% mostly teal" matches. The magenta signs only show on one building around 36–70 s (`sheet_t024`/`t048`). Still a dark teal alley, not a magenta/teal neon city. |
| **Mask LED placement** | **Partial** | Now on the head (`ee591d6`, head-anchored), not the belly. But the two orbs sit **below the goggles on the muzzle/cheek**, as a front-facing pair on a profile face (`r3_f9d03f5/ev/mask_zoom_30s.png`, `ev/mask_band.png`). |
| **Rectangular trail** | **Fixed (new issue)** | Trail is silhouette afterimages now. There are too many copies, packed too tightly, so they read as a noisy cyan smear behind him (`mask_zoom_30s.png`, `sheet_t024` 24–48 s). |
| **Raccoon size (~8%)** | **Fixed** | ≈16–18% of screen height (`ev/midrun_band.png`: ~460 px of 2622). He still hugs the **left screen edge** during Mask and stomp beats and is partly cut off (`04-mask-mode`, `03-mop-stomp`, contact sheet cols 2–3). |
| **KO pose** | **Partial / not visible** | A death sheet exists (4928396a), but both KOs happen with the raccoon translucent (invulnerability blink) and overlapping a MOP. At 1:58.2–1:59.3 he is a faint ghost inside the right MOP until the card drops (`sheets/ko_118s.png`). No readable pose on video. |
| **Hitbox feel** | **Partial** | "Tighter hitboxes" landed, but MOPs still walk *through* the raccoon. He's translucent inside a MOP for ~0.6 s around hurts (`sheets/hurtstomp_4s.png` @4.0–4.6, `ev/midrun_band.png`: a MOP hidden behind him with its mop-head under his feet). No knockback separation. |
| **Title unchanged** | **Still open** | Pixel-identical layout. MAP/DAILY/MUTE sit over a coin, the raccoon and a MOP (`shots_grid.png` 01). |
| **Results unchanged** | **Partial** | Added: NEW BEST stamp, `tally_tick` ×4, `new_best`. But the **NEW BEST stamp is drawn on top of the star row**, so stars are hidden and the text clips into the first star (`ev/results_card.png`). No labels on stars, no count-up visible, no rank bar. |
| **District map unchanged** | **Still open** | Identical (`sheet_t144` 2:26–2:33). |
| **Daily Heist screen** | **Implemented in code, broken in smoke, unverified** | 92b1f90 adds a board (seed, streak, best). The `08-daily-heist.png` shot shows **only the level**, no board, in both 33257aa and f9d03f5. Root cause is in the smoke harness: `smoke_show_map.txt` is never cleared, so once `smoke_show_daily.txt` appears, `HeistScene` (~L1527–1533) flips map ↔ daily **every frame**. Each rebuild calls `RetentionChrome.present()`, which starts at alpha 0. This also produces the **13,307 `music_mask_off` log lines** (≈30/s from 150 s on, via `hideOutcome()`). |
| **SFX pooling** | **Fixed** | Per-clip pool of 3 `AVAudioPlayer`s, reused, with a 40 ms retrigger guard (`SFXManager.swift:22-29, 126-156`). That guard is the only thing keeping the land spam at ~25/s instead of 60/s. |
| **Unused tally / new_best / level_up** | **Partial** | `tally_tick` (×4) and `new_best` fire at 143.7–144.4 s. `level_up` is wired (`JuiceSound.swift:162`, `levelUpStamp`) but never fires: there's no rank/XP system to trigger it. |
| **Results time vs HUD** | **Fixed** | Results 144 s vs HUD 143 s at clear. Death card 120 s vs HUD 119 s. |

## Scores (1–10)

| Area | 56504ee | 33257aa | **f9d03f5** | Note |
|---|---|---|---|---|
| Art cohesion & readability | 6 | 6 | **6** | Slightly brighter, still dark and teal-only. Bare wall columns and floating slab ledges remain. |
| Character / enemy sprites | 7 | 7.5 | **7.5** | Bigger hero with rim light reads well. |
| Animation | 5 | 5.5 | **5.5** | Head LEDs and silhouette trail are better. KO is invisible, and the squash restarts every frame (P0-1). |
| Game feel / juice | 5.5 | 5 | **5** | Stomp pops are good. The orange dust jet, land-thud spam and walk-through MOPs pull it down. |
| Level design | 4.5 | 4.5 | **4.5** | Unchanged. Spawn and Mask framing pin the hero left. |
| UI / UX | 5 | 6 | **6** | Pause menu and background-pause work on video (`02b`, `02c`). Title and map are unchanged, the results stamp overlaps the stars, and the Daily board never appears. |
| Audio | 3.5 (unverified) | 3.5 | **4** | Mux and log exist now. Soundtrack (`main_theme`) and pools are good. The land spam is a P0, and the `mask_mode_on` sting fires only once in 166 s. |
| Retention hooks | 3 | 3.5 | **3.5** | NEW BEST and the Daily board in code. No streak/claim/rank in play yet. |
| Performance | 4.5 | ? | **4** | FPS 51.1 → 43.9 (sim), maxFrameMs 216. See the FPS section. |
| **Overall** | **5.5** | **≈6** | **6** | |

## FPS 43.9: simulator artifact or real risk?

**Both, and the real part is fixable today.**
- **Artifact share:** the GitHub macOS runner simulator is GPU-virtualised and records video at the same time. Absolute numbers there don't predict an iPhone. The video's own capture rate (~25–29 fps in play, ~40 on menus) is a recorder limit, not the game.
- **Real share:** the drop from 51.1 (56504ee) to 43.9 lines up with 4928396a, which introduced the land-every-frame bug. Per frame while grounded, that bug creates 8 `SKShapeNode` dust circles (~130 live at any time, each its own draw), runs 8 action sequences, restarts a squash action, and triggers an `AVAudioPlayer.play()` (~25/s). Shape nodes are among the most expensive things in SpriteKit. That's measurable on a device too.
- **What to do:** fix P0-1, re-measure on the same runner, and expect most of the 7 fps back. Then confirm real 60 fps with one Instruments pass on Nicholas's phone class. maxFrameMs 216 during live play is worth chasing: frame gaps of 139–254 ms in the video sit at 4.0 s (first hurt), 14.95 s, 17.1 s (KO) and 22–23.6 s (Mask entry).

## 1.35% neon coverage

The gate (≥ 0.2%) passes easily, but **the number is almost all teal**: magenta is 0.00% in `02-midrun` and a median of 0.03% across the video. The f9d03f5 magenta signs are additive `SKSpriteNode(color:)` **rectangles** at z −19 in the mid parallax. They only light up one building band and read as coloured blocks, not signs. The art direction says magenta and teal are both canonical. Target ≥ 0.5% magenta *and* ≥ 1% teal in every gameplay quarter, with signage that reads as signs.

---

## Ranked fix list

### P0

**P0-1. Land event fires every frame on the ground (in the TestFlight build).**
- **Cause:** `Sim.swift` ~L272 sets `bandit.onGround = false` every step. Then at ~L307 `wasAir = !bandit.onGround && bandit.anim != .idle` is true on every grounded step while walking or running. So `.land` and `.dust` are emitted every sim step. In `HeistScene` `.land` → `playLand()` + `squash(1.35, 0.65)` + `dust()` (8 `SKShapeNode`s).
- **Evidence:**
  - `smoke_audio_events.txt`: 4,660 `sfx land` lines, median gap 18 ms, 36–56/s during play. 33257aa has 3,324 in 112 s.
  - The orange dust jet behind his feet in every running frame (`ev/dust_trail_136s.png`, `sheets/run_136s.png`, `hurtstomp_4s.png`).
- **Fix:**
  1. Capture `let wasGrounded = bandit.onGround` *before* the reset at L272, then emit `.land` only on the `!wasGrounded → grounded` transition, plus the existing hard-landing branch when `velocity.y < -40`.
  2. Add a unit test: walk 120 steps on flat ground and assert exactly 0 land events; jump once and assert exactly 1.
  3. Make dust a single pooled `SKEmitterNode` (`particleBirthRate` burst) instead of 8 `SKShapeNode`s per call.
  4. Add a CI assertion: fail if `sfx land` exceeds 3/s averaged over live play.

**P0-2. Daily Heist board never appears in smoke (map ↔ daily flip every frame).**
- **Evidence:** `08-daily-heist.png` shows only the level, in both builds. 13,307 `music_mask_off` lines from 150 s on.
- **Fix:**
  1. In the harness-driven retention block, delete `smoke_show_map.txt` (or check `smoke_show_daily` first and `else if` the map) when moving to daily.
  2. Make `showDailyHeist`/`showDistrictMap` early-return if already in that mode.
  3. Only call `setMaskModeMusic(false)` from `hideOutcome()` when mask music is actually on.
  4. Add a smoke assertion that `08-daily-heist.png` contains the board, e.g. that the card frame's neon border pixels exist in the centre.

  Until this is fixed, the Daily Heist board has never been seen on video.

### P1

1. **Neon city, for real.** Replace the coloured-rectangle "signs" with 4–6 actual sign sprites per screen: Spriterrific, or the existing storefront art from `mid_buildings.png`, which already has SPOTLESS / GLOW MART / FIZZ / ARCADE ROW / DEN. Put them in the mid layer with an additive glow sprite behind each and a 2–3 s flicker on one of them. Add a magenta strip light on every other ledge underside and magenta reflections on the wet floor band. Target ≥ 0.5% magenta and ≥ 1% teal in each gameplay quarter, and lift mean play-area luma to ~40.
2. **Mask LEDs on the goggles.** In profile, put one LED glint on the goggle lens. Use two only on `idle_front`. Read the per-frame head anchor plus a goggle offset from the cycle manifest, not a shared offset. Cut the afterimages to 3 copies at 0.45/0.25/0.12 alpha, spaced by velocity × 0.05 s, so the trail reads as motion instead of a smear (`ev/mask_zoom_30s.png`).
3. **Camera framing.** In Mask and stomp beats the hero sits at x ≈ 0–10% of screen width and is partly cut off (`04-mask-mode`, `03-mop-stomp`). Clamp the bandit's screen position to 25–40% of width, extend the map's left padding by 3 tiles or let the camera leave the clamp near the start, and keep ~35% look-ahead in the facing direction.
4. **Walk-through MOPs and an invisible KO.**
   - On hurt, knock the raccoon ≥ 1.2 tiles away and push the MOP 0.5 tiles the other way. Stop the MOP's patrol for 0.5 s.
   - Don't let the invulnerability blink drop below alpha 0.5.
   - On KO, cancel the invulnerability blink, set alpha 1, play the death sheet at full opacity in front of the MOP (z above), and give ~0.3 s of slow-mo before the card (`sheets/ko_118s.png`).
5. **Results card layout.** Move the NEW BEST stamp *below* the stars, or slam it in after the stars at a −8° angle, offset right, and keep the stars visible. Label the stars (Finish / All Shinies / Par). Run the gear count up with `tally_tick` as it ticks. Add the rank/XP bar so `level_up` has a trigger (`ev/results_card.png`).
6. **Title and district map (open since round 1).**
   - Title: a dedicated scene with key art, one big PLAY, and icon buttons. No live level behind it.
   - Map: district art, a glowing route, the raccoon on his node, and star counts.
7. **Hitch spots.** After P0-1, re-check the 139–254 ms gaps at first hurt (4.0 s), KO (17.1 s) and Mask entry (22–23.6 s). Pre-warm the death sheet and Mask textures at level load, and avoid creating shape nodes on the event frame.

### P2

1. Bare wall columns and floating slab ledges: add a wall-face texture with neon trim, and brackets under the ledges (`ev/heist_full.png`).
2. A thin green vertical line still appears near the top of several frames (`ev/heist_full.png` x≈185; also near the stick in `ev/mask_band.png`). Find and remove it: likely a stray checkpoint/flag pole node or a lime stroke.
3. Pause card: add Music/SFX sliders, haptics and a left-handed swap.
4. Only one Mask entry happened in 166 s (24.6 s, held for the screenshot), so re-entry was never exercised. Add a second Mask entry to the smoke route and check the sting and visuals fire again.
5. Raise the neon gate to require both colours (magenta ≥ 0.3% AND teal ≥ 0.5%) so it can't pass on teal alone.

## Is f9d03f5 meaningfully better than 33257aa?

**No, not enough to re-tag.** The only game change is f9d03f5's rim and signage tweak. Measured, that's +5 luma, +0.4% teal and ~0 magenta. On the contact sheet, rows 2 and 3 are near-identical. Both carry P0-1. **Recommendation:** fix P0-1 (small and contained: Sim.swift transition plus emitter dust), verify smoke shows ≤ 3 land SFX/s and no orange jet, and tag *that* build. It's worth replacing his build because it changes the feel and sound of every step he takes. Fold in P0-2 and P1-1/2 if they land the same day. No commit, push or tag was made by QA.
