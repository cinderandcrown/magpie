# QA Report, round 2: The Neon City Bandit, build 56504ee

QA lead review, 2026-11-16 ~1:45 AM CT. Same bar as round 1: Vibe Game Dev / EA-Rockstar polish, CoC/STFC retention, CoD-style punch.

**Primary build: 56504ee.** Artifacts in `/workspace/vidcheck/c/`: 8 screenshots plus smoke-gameplay.mp4, 170.2 s, recorded at full 1206×2622. The video has no audio track, and **this artifact set has no `smoke_audio_events.txt`**. Gameplay smoke passed. The run failed the midrun brightness gate (~6% vs 8%) and the FPS gate (51.1 < 55).
**Baseline: 0d50470** (`/workspace/vidcheck/b/`, round-1 report `QA_REPORT_0d50470.md`).
**Newer: 92557a3** (CI 43821795439). See the addendum at the bottom.
Code read at 56504ee in `/workspace/qa-magpie`.

Evidence files (all in `/workspace/qa/`):
- `compare_0d50470_vs_56504ee.png`: before/after at title, mid-run, Mask, results, Daily Heist
- `sheets_c/sheet_tNNN.png`: 1 fps contact sheets, 24 s each, absolute timestamps burned in
- `sheets_c/{walk_2s,stomp_7s,maskon_41s,death_76s}.png`: player-row strips at 10/6.7/5 fps
- `evidence_c/c_midrun_full.png`, `c_mask_band.png`, `c_heist_full.png`, `c_title_full.png`, `shots_grid.png`

## Verdict

**Overall: 5.5 / 10 (up from 4 on 0d50470).** This is the biggest single jump so far, and the agent did the work honestly. The level now reads as a place: a rainy Neon Docks alley with fire escapes and laundry lines. Characters stand on a real floor. The prison-bar poles and the random crate shelf are gone. Stomps pop. Pause and lifecycle handling exist. Smoke now plays the real level with real tuning.

It is still **not at the bar**:
- The scene is **murky dark**: mean luma is 22–33 out of 255 in the play area, and only 3–6% of pixels are "bright". It reads as a grimy alley, not a *neon* city.
- The hero is small.
- Mask Mode's new "LED eyes" are drawn on the raccoon's **belly**.
- Title, results, map and Daily Heist screens are unchanged.
- Animation timing is still not speed-driven.

**TestFlight call: yes, as a limited real-device feel test.** Conditions:
- tag the next build whose smoke passes the gameplay and no-white gates (92557a3 if its run is clean)
- don't block it on the simulator FPS number
- frame it to Nicholas as "how does it feel in your hands", not "is it polished"

Details are in the TestFlight section near the end.

## Round-1 items: status

| # | Round-1 item | Status | Evidence |
|---|---|---|---|
| P0-1 | White/grey blowout; `worldNightWash` above the parallax | **Fixed** | No white or washed frames in 170 s. `worldNightWash`/`stageBackdrop` are gone from the code. Full-height city visible in every gameplay frame (`sheets_c/sheet_t000.png`…`t096`). |
| P0-2 | Smoke ≠ shipping build | **Mostly fixed** | Real `NeonDocksLevel`. The `maskModeAtCombo = 1` override is gone. Full audio path. Remaining differences: sim `maxSteps` 2 vs 4 (`HeistScene.swift` ~1494), so smoke slows down instead of catching up when FPS dips; `setPaused` is a no-op under smoke (`HeistScene.swift:881`), so **the new pause menu is never exercised by CI**; the death card is deferred under smoke. Also `maskDuration = 14 s` was added partly "for smoke capture" (78e5b9d). It applies to ship too, so it isn't a parity break, but it's a design number chosen for a screenshot. |
| P0-3 | No pause / lifecycle | **Fixed in code, unverified** | PAUSE button top-right in all gameplay frames (`evidence_c/c_midrun_full.png`). Pause card: Resume / Restart / Mute / Home, with a 3-2-1 countdown. `ContentView.swift` handles `scenePhase`, willResignActive, didEnterBackground and audio interruptions. No smoke screenshot of the pause card, and no music/SFX sliders yet. |
| P0-4 | Random round-robin crate tiles | **Fixed** | 4-neighbour autotile (`HeistScene.swift:334-340`). The floor is a clean slab with a cyan walk edge (`evidence_c/c_mask_band.png`). New problems listed under P1-4 below. |
| P1-1 | Cyan "prison bar" poles | **Fixed** | No poles in any frame. |
| P1-2 | City hidden behind a flat fill | **Fixed, overcorrected to too dark** | City plates fill the frame. Brightness numbers above. |
| P1-3 | Floating feet; hero tiny | **Feet fixed; scale not fixed** | Feet on the slab: `sheets_c/walk_2s.png`. Raccoon ≈ 8% of screen height, pinned to the left screen edge at spawn (`sheets_c/sheet_t000.png` 0–40 s). |
| P1-4 | Mask ghost head; sting on top of stomp | **Partly fixed** | Ghost head gone; rings plus afterimage on entry (`sheets_c/maskon_41s.png` @42.55). But the LED "eyes" are hard-coded at `(±5, 22)` in `ArtCatalog.swift:727-745` and land on the belly or backpack in side view (`evidence_c/c_mask_band.png`, `sheets_c/death_76s.png` @76.0–76.8). The trail is a rectangular cyan/purple slab, not a silhouette. Audio de-stacking can't be verified: no audio log, no audio track. |
| P1-5 | Stomp / hit / death don't read | **Mostly fixed (stomp); partly (death)** | Stomp: big "+1…+5" pops, pixel burst, MOP pops instead of sliding (`sheets_c/stomp_7s.png` @7.2–7.7). Death: the raccoon fades to a translucent ghost overlapping a MOP for ~0.8 s, then the BAGGED card (`sheets_c/death_76s.png` @77.2–78.0). No readable pose. |
| P1-6 | Unfair deaths; coins on patrols | **Partly fixed** | 1 death (BAGGED @1:18), clear @1:51 with 2★. Coins now float above the lanes. But the bot spends **0–40 s farming MOPs at the spawn wall** before moving (`sheet_t000`/`t024`), so most of the level is untested in the video. Raccoon and MOP sprites overlap side-by-side for ~0.5 s before a hurt or stomp resolves (`stomp_7s.png` @6.6–7.1). |
| P1-7 | Animation timing not speed-driven; global phase | **Not fixed** | No speed scaling or phase reset in `ArtCatalog.show` (no `.speed =`, no `bobPhase = 0`). |
| P1-8 | Results / death / map lack the reward beat; time mismatch | **Not fixed** | Results card identical, apart from stars (`compare_*.png` col 4). Card time 11.7 s vs HUD 111 s+ at clear (`sheet_t096.png` @1:49 vs @1:52). Map identical (`sheet_t120.png`). `tally_tick`, `new_best`, `level_up` still unreferenced in code. |
| P1-9 | SFX decode per play | **Partly fixed** | SFX are now cached as `Data` in memory (no disk read), but each play still constructs `AVAudioPlayer(data:)` (`SFXManager.swift:113`). |
| P1-10 | Title overlays the live level | **Not fixed** | Same layout. MAP/DAILY/MUTE sit on top of a coin, the raccoon and a MOP (`evidence_c/c_title_full.png`, `compare_*.png` col 1). |

## Scores (1–10 against the bar)

| Area | 0d50470 | **56504ee** | Why |
|---|---|---|---|
| Art cohesion & readability | 3 | **6** | Coherent painted alley with a clean walkable edge and no debug look. Too dark and under-neon. Floating slab ledges have no supports. Untextured wall columns. A grey placeholder tile on the Daily Heist wall. |
| Character / enemy sprites | 6.5 | **7** | Good sprites, now grounded with shadows. Hero too small. |
| Animation | 4 | **5** | Stomp pop is good. Walk reads. Death is a fade, not a pose. Mask LEDs misplaced. Timing still fixed-rate. |
| Game feel / juice | 4 | **5.5** | "+N" pops, pixel bursts, rings and hit-stop are all visible. Shake isn't visible at this capture rate. No camera punch on Mask. Contacts are mushy (sprites overlap). |
| Level design | 2.5 | **4.5** | It's a real level with ledges and a clear exit. The visible route is long flat stretches. Spawn framing is poor. Verticality and secrets aren't shown. |
| UI / UX | 4 | **5** | Pause added, and the HUD is clean with a big PAUSE button. Title, results, map and Daily Heist are unchanged. |
| Audio (events) | 3 | **3.5 (unverifiable)** | Soundtrack and SFX cache are wired in code, but this artifact has no audio log and no audio track. I can't judge the mix. |
| Retention hooks | 3 | **3** | Unchanged: no streak, no daily claim, no rank/XP, no reward sequence. |
| Performance hints | 4 | **4.5** | The app self-reports 51.1 fps average in the simulator. The recording captured only ~12–20 fps during gameplay at full res, against ~60 on static menus, which makes the video choppy. 152 gaps over 100 ms; 15 over 150 ms, clustered at mask entry (42.3), deaths (63–71) and the clear (111.8). |
| **Overall** | **4** | **5.5** | |

## Fresh ranked list

### P0: blocks putting it in Nicholas's hands

**P0-1. CI gates that measure the wrong thing are blocking good builds**
- **What:** Two of tonight's gates are noise or style checks dressed as correctness checks.
  - **FPS gate (avg ≥ 55 in the simulator):** it averages instantaneous 1/dt (mean of rates, biased high by fast frames and low by hitches). It runs on a virtualised GitHub macOS runner with a paravirtual GPU while `simctl recordVideo` encodes 1206×2622 in parallel. 51 vs 55 there tells you nothing about an iPhone. It's a coin flip that has eaten several runs.
  - **Brightness gate (≥ 8% of pixels with mean > 70 in the 10–90% × 18–62% crop):** this is an art-direction opinion. It also flips with where the camera happens to be when `02-midrun` is captured (the same build reads 3–17% across this video, `frames_c`).
- **Fix:**
  - **FPS (sim): make it a warning, not a gate.** Keep only a catastrophic floor that fails on: median frame time > 33 ms (under 30 fps) over gameplay; or more than 3 hitches over 250 ms outside load/transition windows; or any single frame over 1 s.
  - Compute from frame times (p50 / p95 / hitch count), not mean of 1/dt. Write them to `smoke_status`.
  - Record video at reduced size, or run the FPS-measuring pass without recording.
  - Auto-retry the smoke job once on simulator boot/infra failure.
  - **Real perf gate:** on device. Use a manual Instruments pass per milestone (Time Profiler + Metal System Trace, 60 s of Neon Docks on Nicholas's iPhone class). Target: 60 fps p95 ≤ 18 ms, with no hitch over 50 ms in normal play. Later, add an `XCTOSSignpostMetric`/MetricKit hitch-rate check from TestFlight builds.
  - **Brightness:** replace it with a **readability** gate:
    - hero/enemy vs local-background luminance contrast ≥ 3:1, measured in a box around the bandit and MOP positions from `smoke_status`
    - neon presence: ≥ 0.5% saturated magenta/teal pixels
    - a no-blowout check: ≤ 2% near-white outside UI
    - all over 5+ sampled gameplay frames, not one screenshot.
- **Evidence:** run notes (51.1 < 55; ~6% < 8%). `scripts/simulator_smoke.sh:12, 304-314, 527-566`. Bright-pixel % per gameplay second ranges 2.7–16.8% in this single video.

**P0-2. The pause menu is never exercised by smoke**
- **What:** `setPaused` returns early under smoke (`HeistScene.swift:881`). A pause or lifecycle bug (soft-lock, timer keeps running, music doesn't resume) would ship to a human untested.
- **Fix:** allow pause under smoke. Add a smoke step at ~15 s of play: pause → screenshot `09-pause.png` → resume (3-2-1) → assert the sim time didn't advance while paused and that the music resumed (audio log line). Also simulate `willResignActive` via a flag file and check the same.

### P1: needed to feel good

1. **Too dark and not neon enough.**
   - Evidence: play-area mean luma 22–33/255 (`frames_c`, `evidence_c/c_midrun_full.png`, `c_heist_full.png`). The neon is a few teal window lights; there's almost no magenta.
   - Fix: lift background midtones ~20–25% (curve on the plates, not a full-screen tint). Add 3–5 emissive neon signs and strips per screen in magenta and teal, with soft additive glow sprites (92557a3 starts this). Add wet-floor reflections of those signs on the slab top. Add rim light on the hero (a thin cyan edge sprite). Keep the walkable edge the brightest line on screen.
2. **Mask LEDs on the belly; rectangular trail.**
   - Fix: drive the LED position from per-animation head anchors, measured in the sheet normalization step and stored in the cycle manifest. Flip with facing. In side view show one eye glint, two only on `idle_front`. Or bake the glint into a tiny per-frame overlay sheet. Make the trail 3 afterimage copies of the *current texture* (alpha 0.5/0.3/0.15, cyan colorize), not a rect.
   - Evidence: `evidence_c/c_mask_band.png`, `sheets_c/death_76s.png`.
3. **Hero too small; poor spawn framing.**
   - What: the raccoon is ~8% of screen height and starts against the left screen edge with the camera clamped (`sheet_t000`).
   - Fix: raise the zoom so the raccoon is ~12–14% of screen height. Start the camera with the hero at ~35% from the left, add ~2 tiles of padding before the map's left edge, and give some look-ahead in the facing direction. Re-check the HUD and controls don't cover the play band.
4. **Unfinished level geometry.**
   - What: floating slab ledges have no supports or brackets (`c_midrun_full.png` top). Tall wall columns are flat untextured slate (`c_heist_full.png` right). A **grey placeholder-looking tile** sits on the Daily Heist wall (`c_heist_full.png` @ right side, ~60% height).
   - Fix: add brackets or chains under ledges (Kenney CC0 props), a wall-face texture with neon trim, and replace or remove the grey tile (check which prop index it is).
5. **Death has no pose.**
   - What: the raccoon fades into a ghost over the MOP, then the card comes (`sheets_c/death_76s.png` @77.2–78.0).
   - Fix: knock back away from the MOP, play a 4–6 frame KO (Spriterrific, or reuse the hurt frames plus spin), ~0.3 s slow-mo, and a "BAGGED" stamp in-world. Bring the card in at ~0.9 s.
6. **Contacts are mushy.**
   - What: raccoon and MOP sprites overlap for ~0.5 s before a hurt or stomp resolves (`sheets_c/stomp_7s.png` @6.6–7.1). Side-on stomps look like touch-kills.
   - Fix: on hurt, separate immediately (knockback ≥ 1 tile plus MOP recoil). Only allow a stomp when the bandit's feet are above the MOP's top third. Show the flop pose for ≥ 3 frames before contact.
7. **Results / map / title (carried over, not fixed).** Implement the round-1 P1-8 and P1-10 fixes:
   - Results: labelled star slams; loot count-up with `tally_tick`; NEW BEST with `new_best`; rank bar with `level_up`. Fix the card time to match the HUD.
   - Map: district art, glowing path, raccoon on its node.
   - Title: a dedicated scene with key art, logo slam synced to the startup jingle, and one big PLAY button.
   - This is now the most visible "not done" part of the game.
8. **Animation timing (carried over).** Drive walk/run speed by |vx|/runSpeed and reset the phase on state change. Add apex and land frames.
9. **SFX engine.** Move from `AVAudioPlayer(data:)` per play to AVAudioEngine plus pre-decoded `AVAudioPCMBuffer`s on a pool of player nodes, with a voice cap and re-trigger guard. Then put `smoke_audio_events.txt` back into the artifact upload, because this run lacks it, and mux audio into the video.
10. **Smoke route coverage.**
    - What: the bot farms the spawn for 40 s, so the middle of Neon Docks never appears on video.
    - Fix: the bot should progress, with an assertion like "bandit.x passes 25/50/75% of map width by T". Capture one screenshot per quarter.
    - Also record at a lower resolution so the video runs at 60 fps and judging feel from it is possible. This run captured 12–20 fps during gameplay.

### P2: polish

1. HUD: swap the "✦ N" glyph for the gear-coin icon. Add a combo/Mask meter. Use a smaller top-centre timer.
2. Pause card: add Music/SFX sliders, a haptics toggle and a left-handed swap.
3. Daily Heist: header with date, "same heist for everyone", best time and streak (`c_heist_full.png` has no identity).
4. Rain: vary streak length and alpha, and add splash particles on the slab edge.
5. Shinies: idle shimmer and magnet pull on collect.
6. EXIT is still a green rounded rect with a label. Replace it with a door sprite plus beacon.
7. Move the "Art: Spriterrific…" credit off the title into Settings › Credits.

## Simulator FPS gate at 55: my view

It's not a reasonable *blocker*. Keep it as a *signal*.
- The CI runner's simulator is GPU-virtualised and shared, and tonight it was also encoding a full-resolution video. Frame rate there depends on runner load as much as on our code. Several runs failed on boot or infra flakes alone.
- The current metric (average of 1/dt, first 2 s skipped) can't tell a smooth 51 from a 60 with stutters, and stutters are what players feel.
- What CI *can* reliably catch is **regressions and catastrophes**. Gate on those, using a relative check against the last green run's p95 (fail if it's > 25% worse) plus the absolute floors in P0-1.
- Real 60 fps verification belongs on a device. Nicholas's TestFlight session is the first real data point. Ask him "did it ever stutter?" and run Instruments once per milestone.
- Retry the smoke job once automatically on simulator boot or install failures.

## TestFlight: ready for Nicholas?

**Yes, for a real-device feel test, with conditions.** I'd tag the next build that passes the gameplay smoke, the no-white check and a pause sanity check (P0-2), even if the sim FPS reads 50–55.

**Which build:** if you need a build tonight, 56504ee itself is acceptable for this feel test. Its gameplay smoke passed and the only failures are the two gates I argue against above. But pause is untested by CI, so pause and home-swipe it once yourself on the first install. The better path is: fix the gates, add the pause smoke step, rerun 92557a3 and tag that.

Why yes now:
- The game no longer looks broken. It runs the real level with real tuning, and it has pause and lifecycle handling.
- The remaining big unknowns are things only a device and a human can answer:
  - is it too dark on a real screen?
  - do touch controls feel tight?
  - is it 60 fps on his phone?
  - is stomping fun?
- Another night of simulator-only iteration has diminishing returns.

Why not "polished": the title, results and map screens are unfinished, the hero is small, Mask LEDs are misplaced, and death has no pose. Frame it to him as an early feel build.

Suggested 10-minute ask for him:
1. Play Neon Docks twice.
2. Answer 5 questions:
   - too dark?
   - controls tight or floaty?
   - did stomping feel good?
   - any stutter?
   - did you want to play again?
3. Try pause, then home-swipe out and back in.

Standing rules still hold: no store submission, and no nag/offer surfaces in this build (none seen).

## Addendum: 92557a3 (cheaper rain/parallax, neon signage)

- **No smoke artifacts, so no deltas to judge.** CI run 43821795439 **failed in "Unit tests" before smoke ran** (smoke step skipped; only `xcodebuild-logs` uploaded, saved in `/workspace/vidcheck/d_logs/`). Error: `FBSOpenApplicationServiceErrorDomain Code=3 … RBSRequestErrorDomain Code=5 "Launch failed"` → `Early unexpected exit, operation never finished bootstrapping … Lost pending connection to the test runner before launch`.
- The logs contain no crash report (no EXC_/SIGABRT/jetsam text), and the same symptom hit earlier tonight (56504ee is literally "Retrigger CI after simulator boot flake"). So it's **most likely a simulator launch flake**. A real launch crash from the heavier signage textures can't be ruled out until a rerun passes. Ask: rerun once. If it fails the same way twice, treat it as a real launch-time crash and check memory at boot.
- The TestFlight workflow run 43821795115 on 92557a3 (green) was the **pull_request sign/check path**, not an upload. `testflight.yml` only uploads on pushed `testflight/*` tags.
- The midrun neon-signage change goes straight at P1-1 (too dark / not neon). Once 92557a3 has artifacts, re-run the brightness numbers above and the readability-gate idea in P0-1 against it.
