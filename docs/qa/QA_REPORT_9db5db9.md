# QA Round 4: 9db5db9 (run 43864031627)

Compared against f9d03f5 (round 3) and 33257aa (Nicholas's TestFlight build). Artifacts are in `/workspace/qa/r4_9db5db9/` and the contact sheet is `/workspace/qa/contact_r4_9db5db9.png`. Contact sheet rows, top to bottom: stills for 33257aa, f9d03f5 and 9db5db9; the full video at 1 frame / 2 s; the Mask section; the hurt/KO beat; then crops of the Mask LED, the results card and the Daily board.

**Score: 6 / 10** (f9d03f5 6, 33257aa ≈ 6). The landing-spam, performance and Daily-board fixes are real and large. A new camera regression cancels most of that gain on screen: for most of the run, the hero sits half off the left edge. With the camera fixed, I expect this build to score about 6.5–7.

**Tag for Nicholas now? No.** Fix the camera first. It's one function (details under P0-A), then re-run and tag that build. That build *will* be clearly better than 33257aa.

## Round-3 items

| Item | Status | Evidence |
|---|---|---|
| **P0-1 landing spam** | **Fixed, with a residual double-land** | `sfx land` dropped from 4,660 (f9d03f5) and 3,324 (33257aa) to **73**. The orange dust jet is gone (dust is now an emitter). Over the 97 s audio-log span that's 0.75/s; over live play it's about 1.2/s. The unit tests cover walk = 0 landings and jump = 1. **But one airborne beat does not always give one landing:** 30 of 73 lands are duplicates 20–67 ms after the previous one. Every pounce logs `pounce_whoosh → land (+33 ms) → land (+67 ms)` (26.9–31.1 s), and there are 20–50 ms ground-flicker doubles at 85.9–87.8 s and 93.4–93.8 s. Fix: require ≥ 2 steps airborne before `.land`, or a ~100 ms land cooldown in the Sim, not just the audio guard. |
| **P0-2 Daily Heist board** | **Fixed** | `08-daily-heist.png` shows the board (date, seed #1CCC, best, streak 0, RUN HEIST, BACK), held about 10 s in the video (1:47–1:57). `music_mask_off` dropped from 13,307 to 6, one per KO/exit. Minor: the board's raccoon sprite overlaps the "City board · live soon" text. |
| **P1-3 neon** | **Partial: mostly painted fill** | Magenta coverage went from 0.0% to 2.2–4.2%, but it comes from flat `SKSpriteNode` colour bars. About 55–60% of all magenta pixels sit in long horizontal strips under the ledges and the floor, with blocky tile seams (`02-midrun`, `04-mask-mode`). The rest is shorter ledge strips, puddle ellipses and 4 px wall tubes. The storefront crops from `mid_buildings.png` (5b8dbaa) don't show up anywhere I could find in the video or the stills. The only real sign glow is still the baked magenta building in the background plate, which was already in earlier builds. It reads as "pink tape on every ledge", not as signs lighting the alley. |
| **P1-4 Mask eyes / afterimages / framing** | **Eyes fixed, afterimages unverifiable, framing worse** | A single LED glint now sits on the goggle lens in profile (crop in the contact sheet). Framing regressed: during Mask (31–70 s) the hero is pinned at x ≈ 0–5% of the screen, with half his body cut off. I couldn't judge the afterimage spacing because he barely moves on screen. Mask also stayed on for about 38 s with zero jump/land/stomp SFX between 31.7 s and 81 s, so the autoplay hero appears stalled against the left edge. |
| **P1-5 knockback / visibility / KO** | **Partial** | Code adds ≥ 1.2-tile knockback, a 0.5 s MOP stun, invulnerability alpha ≥ 0.5 and an opaque KO. On video, MOPs still overlap him (3.7 s: hero hidden behind a MOP). Each KO (7.7, 15.2, 22.6 s) happens at the left edge, so the KO pose is mostly off-screen. Hurts went **up** from 6 to 12 and stomps went **down** from 11 to 6 compared with f9d03f5. Knockback pushes him into the left clamp, where he gets mobbed. |
| **Results / NEW BEST** | **Partial** | Stars are visible and labelled (Finish / All Shinies / Par). The NEW BEST stamp now sits below the stars, but it still covers the "All Shinies" label and crowds the gear count "4". Nudge it about 30 pt down and right, or slam it in at −8° beside the count. No rank/XP bar, so `level_up` still never fires. |
| P2-1 bare walls / slab ledges | Open | Unchanged apart from the pink strips. |
| P2-2 green line | **Partial** | The lime checkpoint pole is replaced with a cyan gem. Dark-green blocky drips/rectangles still hang under the ledges (`02-midrun` under the upper ledge; `04` crop). |
| P2-3 pause sliders | Open | Pause card still shows only RESUME / RESTART / MUTE / HOME. |
| P2-4 second Mask entry | Open | `mask_mode_on` fired once. |
| P2-5 two-colour neon gate | **Fixed** | Magenta ≥ 0.3% AND teal ≥ 0.5%. |
| Title / district map | Open | Unchanged since round 1. |
| Hitch spots | Improved | maxFrameMs dropped from 216 to 171. 171 ms is still about 10 dropped frames, so find it. Candidates are KO and the Mask entry. |

## Gate audit

1. **433a69b (p95 cut loosened)** changes the check from `char_p95 < 48 → FAIL` to `char_p95 < 40 AND spritePop < 1% → FAIL`. This build's spritePop is around 5%, so the p95 check is effectively turned off. **It does not hide a real problem right now.** spritePop and spread90 already prove the hero/MOP band has bright pixels, and on dark alleys p95 really was noisy. The risk is that it no longer guards anything. Better: keep p95 as a warning, or tie it to the hero crop rather than the whole band.
2. **Land-rate gate (new): the denominator is wrong.** It divides by the last value in `smoke_timer_log.txt` (341 s), but the audio log covers only about 97 s and live play is about 60 s. The reported "0.21/s" is roughly 3.5–6× too low. The real rate (~0.75–1.2/s) still passes the 3/s limit, so nothing is hidden today. But it would let a spam of up to ~10/s pass. Fix: use the audio-log time span minus the paused/menu windows. Also count land events < 100 ms apart as a separate failure, which catches the double-land.
3. **Daily-board gate (new): too weak.** It passes on lime ≥ 0.15% **OR** cyan ≥ 0.4% in the centre box. I ran it on the round-3 *bare level* shots, which were the exact bug this gate is meant to catch. f9d03f5 scores lime 0.69% / cyan 1.23% and 33257aa scores 0.71% / 1.25%, so **both would pass.** It wouldn't have caught P0-2. The real board scores lime 4.8%. Fix: require lime ≥ 2.5% and drop the cyan OR, or template-match the card border.
4. **ci.yml retry list** now includes `TEST EXECUTE FAILED`. xcodebuild prints that on **any** unit-test failure, so real test failures are now retried once and a flaky real failure can go green. Remove that pattern; the launch-flake patterns (`Early unexpected exit`, `did not return a process handle`, …) are enough. Capturing stderr (`2>&1`) is good.
5. No changes to the FPS or freeze thresholds. The FPS rise (43.9 → 59.3 sim) is consistent with removing about 50 land/dust/squash calls a second, so I believe it.

## Scores (1–10)

| Area | 33257aa | f9d03f5 | **9db5db9** | Note |
|---|---|---|---|---|
| Art cohesion & readability | 6 | 6 | **6** | Magenta added, but as flat bars with seam blocks. Storefront signs not visible. |
| Character / enemy sprites | 7.5 | 7.5 | **7.5** | Goggle LED correct. |
| Animation | 5.5 | 5.5 | **6** | Squash spam gone. KO still not readable (off-screen). |
| Game feel / juice | 5 | 5 | **6** | Every step feels clean now. Double land on pounce. Hero gets mobbed at the edge. |
| Level design / camera | 4.5 | 4.5 | **3.5** | Camera regression: hero at 0–5% of width for most of 0–60 s. |
| UI / UX | 6 | 6 | **6.5** | Daily board works, stars labelled. Stamp overlap; title and map unchanged. |
| Audio | 3.5 | 4 | **5.5** | Spam fixed and the mix is readable. One Mask sting. |
| Retention hooks | 3.5 | 3.5 | **4** | Daily board on video. Streak/claim not exercised. |
| Performance | ? | 4 | **6** | 59.3 fps (sim), maxFrameMs 171. Still needs one device check. |
| **Overall** | **≈6** | **6** | **6** | ≈6.5–7 once P0-A lands. |

## Ranked fixes

### P0
**P0-A. Camera double-counts look-ahead, so the hero is pushed off the left edge (new in this batch).**
`HeistScene.swift` camera block: `target.x = hero.x + lead(max(cameraLeadTiles, 2.6) tiles) + heroBias(0.18 × viewW)`. That stacks two offsets: the hero lands at about 0.5 − lead/viewW − 0.18 ≈ 0.0–0.05 of the screen. Facing left, he goes to about 0.9. Fix: `target.x = hero.x + facing × 0.18 × viewW` (one offset, which puts the hero at about 32%), eased over ~0.4 s when he turns. Add a smoke assertion: hero screen-x stays within 20–45% during play, measured from `smoke_status` or the hero bbox.

### P1
1. **Make neon real light.** Replace the full-length flat pink bars with short (1–2 tile) strip lights that have a soft additive glow gradient (`softCircleTexture`), on every other ledge, not all of them. Verify that the storefront sign crops are actually on screen (log node count and position, add a screenshot). Add wet-floor reflections under the signs. Target: magenta that is ≥ 50% from sign/glow nodes, not bars.
2. **One airborne beat = one landing.** Require ≥ 2 airborne steps or a 100 ms land cooldown in the Sim. Pounce must not emit a land 33 ms after the whoosh. Add a unit test: pounce = 1 land.
3. **Fix the gates:** land-rate denominator, Daily-board threshold (lime ≥ 2.5%, no cyan OR), and remove `TEST EXECUTE FAILED` from the retry grep.
4. **KO / mobbing:** after P0-A, re-check KO visibility and hurt counts. Knockback must not push him into the camera clamp. Don't spawn a MOP within 4 tiles of spawn or a respawn point.
5. **Results stamp** clear of the star labels and gear count. Add a count-up and a rank bar.
6. **Hunt the 171 ms hitch.** Pre-warm the KO and Mask textures and the emitter at level load.

### P2
Title and district map (open since round 1). Green drip rectangles under ledges. Pause sliders. Second Mask entry in the smoke route. Investigate the 38 s Mask duration and the stalled autoplay (no SFX from 31.7 to 81 s). Daily board sprite overlapping text.

## Meaningfully better than 33257aa?
**Underneath, yes; on screen, not yet.** Landing spam is gone (−98% land SFX), simulator FPS went from about 44 to 59, and the Daily board finally renders. Those are exactly the reasons I gave in round 3 for re-tagging. But the camera change pushes the hero half off-screen for most of the first minute and all of Mask Mode. That's the first thing Nicholas would notice, and it reads worse than his current build. **Don't tag 9db5db9.** Land P0-A (small and contained) plus the land cooldown, re-run smoke, check that the hero sits at 25–40% of the width in the stills, then tag. QA did not commit, push or tag anything.
