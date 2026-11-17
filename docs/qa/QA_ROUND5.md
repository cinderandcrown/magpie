# QA Round 5: a4dff32 (CI run 44028100495, green)

Branch `cursor/mission-1-raccoon-toy-0c7d` @ `a4dff3247b36f86c6a8283410c8d1e0eb5a04034`. CI finished 00:24 CST, Nov 17.
I compared this build against 9db5db9 (round 4) and 33257aa (the build on Nicholas's phone, TestFlight 96.1).
For the gate audit I diffed against a678ec7 and against 9db5db9, the last build QA'd.
Evidence is in `docs/qa/r5_a4dff32/`:
- `contact_r5_a4dff32.jpg`: the rows are 33257aa, 9db5db9 and a4dff32 (midrun, stomp, mask, results, daily), plus a 20–66 s video strip showing the stall.
- `overlay_*.jpg`: reference | current | edges (blue = 9db5db9, red = a4dff32) | 50% blend.
- `scores_a4dff32.json` holds the per-still metrics, and `measure.py` is the script that produced them.

## Verdict

**Score: 5.5 / 10** (round 4: 6, 33257aa: about 6). **Don't TestFlight this build to Nicholas.**

Most of the plumbing is fixed:
- Camera framing during the run
- The double-land
- Pause sliders
- The NEW BEST stamp
- Frame time
- The Daily board

But the midrun neon "fix" painted large flat, opaque hot-pink rectangles across the playfield in the shipping game, not only in smoke. It is the first thing anyone will see, and it looks worse than 33257aa.

The P0 is a small, contained art change. With it fixed, and nothing else, I expect about 6.5.

## The five audit items

### 1. Forced fallbacks and soft-locks (worldTX)

**Counted fallbacks: zero, but the count misses some harness interventions.**
- `smoke_forced.txt`: `forced_mask=0 forced_fail=0`. The CI log has no `smoke_force_*` WARN line.
- The bot cleared the level honestly after the death beat: worldTX went 68 → 94 (EXIT) in 12.6 s, with `won=1 medals=1`. The death was a real KO at about 140.6 s (`raccoon_ko`), not a canal teleport.
- **Uncounted interventions.** These state edits run in smoke mode and never reach `smoke_forced.txt`:
  - Mask pinned open (`maskTimer ≥ 3.0` while 04 is pending). Mask stayed on 17.1 → 65.0 s, which is **47.9 s against the 22 s design**.
  - **The 4 s Mask force-off plus combo clamp after 04.** It killed three Mask entries the bot had earned legitimately, at 81.28, 82.25 and 83.13 s. Each sting was followed by `music_mask_off` within about 50 ms, so the recorded video has a Mask sting stutter.
  - Mask cancelled before the midrun still (1.98 → 2.08 s).
  - `softReviveSmokeHarness()` undoes deaths during Mask, pause and background (no log line, so I can't tell whether it fired).
  - Invulnerability is topped up through Mask, pause and background, so the hurt counts (1 hurt, 1 KO) can't be compared with round 4's 12.
- **Bot soft-lock: about 38 s with no progress.** worldTX sat at **63 from elapsed ~23.5 s to ~61 s**, with stomps frozen at 8.
  - The audio log has **zero events from 23.499 s to 63.337 s**.
  - The 1 fps video diff drops to the rain-only noise floor for the same window (see the contact strip). The hero stands on the latch-tower ledge against the pillar.
  - No gate caught it, and the harness kept Mask pinned on the whole time.
  - The level reachability validator passes, so this looks like a bot or ledge-AI stall rather than a level the player can't escape. It still shows as dead air in every smoke video.

### 2. Mask Mode earned without forcing

**Yes, with caveats.**
- First entry: three real stomps at 16.05, 16.37 and 16.95 s, then `mask_mode_on` at 17.085 s.
- Second entry (04b): a real stomp at 87.23 s.
- `SmokeWorldProgressTests` asserts `sawMask` with no force flags and at least 3 post-midrun stomps.
- Caveats:
  - Earning got much easier in `d4acfbd`: `maskModeAtCombo` went **5 → 3** and `comboGroundGrace` went **4.5 s → 12.0 s**, about 2.7× the chain window. That's a design change Nicholas should approve.
  - The Mask durations seen in smoke are fake (see the pin above).

### 3. Loosened-gate audit

`scripts/` and `.github/` are **unchanged between a678ec7 and a4dff32**, so the agent's "loosened none since a678ec7" is true. Since 9db5db9 (round 4), though:

| Gate | Change | Weaker or stronger | Evidence |
|---|---|---|---|
| Magenta midrun ≥ 0.3% | Threshold unchanged | **Gamed in the art.** ArtCatalog comment: "Bias magenta: every sign gets a solid pink plate (CI crop needs ≥0.3%)". 16 opaque plates, alpha 1.0. | CI crop magenta 29.5% (it was about 2–4%). Full still: 12.3% vs 1.2%. **Flat untextured magenta 8.6% of the screen** (0.0% in every earlier build). The largest single slab is 4.7% of the screen. |
| Stomp (03) | `stomps≥1` became `stomps≥1 OR (mask=1 AND combo≥1)` | **Weaker.** Passes on sticky values. | |
| Stomp-chain (03b), `91bc7b8` | `stomps≥3` became `stomps≥3 OR combo≥3` | **Weaker.** combo is a high-water mark. | Passed with stomps=8 and combo=8, **unchanged since the 03 beat**. 03 and 03b differ by only 2.9/255 mean: the same still, a stuck hero and no chain. |
| Hero framing 20–45%, `8ba13c6` | Samples only when facing right, camera `settled`, and `cameraFacing>0.9`, because "mid-turn lag spiked max to ~60%" | **Weaker.** It drops exactly the samples that fail. | Telemetry max is 0.375, but in stills 04 and 04b **the hero sits at about 70% of the width, facing right**. |
| Double-land < 100 ms | New gate, plus the real `Sim.landCooldown` fix and unit tests (good) | **Tautological.** JuiceSound's 100 ms wall-clock debounce means the logged SFX can never fail the gate. | 0 doubles, minimum gap 115 ms. The Sim fix is genuine (`testSinglePounceEmitsExactlyOneLand`). |
| 4 s Mask force-off | New harness state edit | **Weaker proof.** It forces the state the gate wants to see (`maskOn=0`), uncounted. | Three killed entries at 81–83 s. |
| `wait_status` | Timeout now returns instead of exiting | Mostly neutral: most beats moved to `wait_status_strict`. **Still soft:** mask-off (`|| true`), mask-2 (gives up after 55 s and saves a placeholder still), rooftop (18 s soft timeout). | |
| Land-rate denominator | Now the audio-log span | Better, but the 217 s span still includes menus and holds. | 0.51/s |
| Daily board | lime ≥ 2.5%, cyan OR removed | **Stronger** (the round-4 fix) | lime 4.82% |
| Unit-test retry | `TEST EXECUTE FAILED` removed | **Stronger**, but the new `test runner` pattern is broad and can match a real test crash | |
| Storefront band ≥ 0.4%, reachability validator | New | Stronger in intent (the storefront one is gamed by the same plates) | |

### 4. Rename check

**Pass for player-facing strings.**
- `CFBundleDisplayName` = "Neon City Bandit", and `ProductIdentity.displayTitle` = "The Neon City Bandit".
- There's a unit test asserting the title has no Magpie.
- No "Magpie" or "MAGPIE" appears in any UI string or smoke still.
- The App Store Connect app name (read-only check) is "The Neon City Bandit".
- Internal leftovers (fine, but polish):
  - `CFBundleName = $(PRODUCT_NAME)` = "Magpie". iOS rarely shows it, but set it explicitly.
  - The beta group is named "MAGPIE team" (not shown to testers).
  - Bundle ID and target names are fine as they are.

### 5. Publisher ident (`/workspace/cc-splash/SPEC.txt`)

**Missing.**
- Nothing on this branch: no "Cinder & Crown Creative Presents" and no mute-logo asset.
- **The branch `cursor/publisher-ident-0c7d` doesn't exist on origin.** The remote has only main, assets/*, mission/* and the cursor mission/spriterrific branches.
- `01-launch.png` is byte-identical to `01-title.png`, so no ident is captured.
- Nothing to measure for skip or first-frame delay yet.

## Measured scores (stills, scale 0.25)

| Still | magenta % (33257aa / 9db5db9 / a4dff32) | flat magenta % | SSIM vs r4 | palette ΔE2000 vs r4 |
|---|---|---|---|---|
| 02-midrun | 0.32 / 1.22 / **12.31** | 0 / 0 / **8.64** | 0.28 | 7.4 |
| 04-mask | 0.22 / 2.04 / **12.13** | 0 / 0 / **7.14** | 0.28 | 4.5 |
| 03-stomp | 0.31 / 2.35 / 1.09 | 0 / 0 / 0.40 | 0.34 | 4.3 |
| 06-results | 0.25 / 0.25 / 0.24 | 0 | 0.56 | 2.0 |
| 08-daily | 0.01 / 0.24 / 0.24 | 0 | 0.97 | 0.3 |

Regression flags:
- Flat magenta went from 0 to 8.6% (**FLAG**).
- Midrun palette ΔE 7.4 is above the 5 threshold (**FLAG**).
- Video SFX silence of 39.8 s, against a 10 s threshold (**FLAG**).
- Hero at ~70% in 04/04b, outside the 20–45% band (**FLAG**).

Telemetry:
- FPS 58.8 (was 59.3).
- maxFrameMs **134** (was 171, better).
- Land SFX 110 at 0.51/s, with 0 doubles under 100 ms (was 30).
- Video 253.9 s with audio mux.

## Area scores (1–10)

| Area | 33257aa | 9db5db9 | **a4dff32** | Note |
|---|---|---|---|---|
| Art cohesion & readability | 6 | 6 | **4** | Opaque pink slabs behind the hero on the midrun, Mask and 04b screens. |
| Character / enemy sprites | 7.5 | 7.5 | **7.5** | Unchanged. |
| Animation | 5.5 | 6 | **6** | |
| Game feel / juice | 5 | 6 | **6.5** | One land per jump/pounce; Mask sting stutter is smoke-only. |
| Level design / camera | 4.5 | 3.5 | **5.5** | Run framing fixed (02 ≈ 0.45, 03 ≈ 0.33). 04/04b at ~70%. 38 s ledge stall. |
| UI / UX | 6 | 6.5 | **6.5** | Pause sliders and NEW BEST placement fixed. Results flavor text runs under the NEXT button. No ident. |
| Audio | 3.5 | 5.5 | **6** | Clean landings. |
| Retention hooks | 3.5 | 4 | **4** | |
| Performance | ? | 6 | **6.5** | 134 ms max frame. |
| **Overall** | **≈6** | **6** | **5.5** | About 6.5 once P0 lands. |

## Ranked fixes

### P0: blocks TestFlight
1. **Remove the solid pink plates from the storefront signs** (`ArtCatalog.worldStorefrontSigns`). Keep the real sign crops plus a soft additive glow, about 4–6 signs (not 16), on a dark backing at most.
   - Add an art gate: flat single-colour magenta under 0.5% of the screen, no single flat slab over 0.3%, and total magenta between 0.3% and 6%.
   - Don't tune art to a CI crop.

### P1: fix before or alongside the next tag
1. **Make stomp and stomp-chain prove fresh stomps.** Count stomps since the beat started (3 or more within the window), and fail if 03b is near-identical to 03 (mean difference under 5/255).
2. **Add a stall gate and fix the latch-tower stall.** Fail if worldTX doesn't change for more than 8 s of live play outside the screenshot holds. Make the bot (or the ledge) leave tile 63.
3. **Count every harness state edit in `smoke_forced.txt`:** Mask pin seconds, force-off count and seconds, soft revives, the pre-midrun cancel, and invulnerability top-ups. Replace the 4 s force-off with having the app write status at the moment of the shot, so earned Mask entries aren't killed.
4. **Hero framing gate:** sample every live frame, or measure the hero's bounding box in the stills. Add turn hysteresis so a brief reverse doesn't park the camera with the hero at ~70% while he faces right.
5. **Build the publisher ident to the spec and push the branch** (it isn't on origin). Include a `00-ident.png` smoke still, tap-to-skip, cold launch only, Reduce Motion support, and an honest launch-to-first-frame measurement.
6. **Results card:** the OmniClean flavor text runs under the NEXT button. Clamp it to 2 lines above the buttons, or move the buttons down.
7. **Mask-2 beat:** fail, or count it as forced, if re-entry doesn't happen. No placeholder still.
8. **Get Nicholas to approve the easier Mask:** combo 3 instead of 5, chain window 12 s instead of 4.5 s.

### P2: polish
- Narrow the `test runner` retry pattern to the exact flake strings.
- Log raw Sim land events for the double-land gate, before the audio debounce.
- Use a live-play denominator for the land rate.
- Set `CFBundleName` to "Neon City Bandit". Optionally rename the beta group.
- Replace the "Logo: B1 Holo Glass" credit text (an internal name) on the title and pause screens.
- Fix the grey "X" placeholder tile on the latch pillar (03/03b).
- Still open from earlier rounds: green drips under ledges, title and district map unchanged.

QA committed only this report and its evidence, on branch `qa/a4dff32`. No tags were pushed and nothing went to the agent branch.
