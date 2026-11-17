# The Neon City Bandit — AGENTS.md (adapted Master Brief)

This is the working agent brief for **The Neon City Bandit**. Design, originality, pillars, feel bar, and mission quality standards come from `docs/PLAN.md` Part 2 (theme-amended) and `docs/DESIGN.md`. **`docs/PLAN.md` keeps process/gates;** product theme is the raccoon neon heist.

**How this file relates to the plan:** keep the plan’s rules and ambition; adapt only *who runs where* and *who merges/tags* to our real setup. Every adaptation is logged in `DECISIONS.md`. When an ad-hoc chat brief conflicts with this file or the plan’s design bar, **this file + the plan’s design win** — aim for a badass game; do not sandbag feel or juice.

**Vibe Game Dev methods:** follow `docs/VIBEGAMEDEV_METHODS.md` for pass shape, gyms, Spriterrific art (anchor first — Fire Fox approves before animations; do not block other work while waiting), juice, audio, and smoke QA.

## 0. How we actually work

| Role | Who | Does |
| --- | --- | --- |
| Product owner | **Nicholas** | Plays TestFlight builds, judges feel, says **APPROVED** (or sends notes). Does not merge or tag. |
| Coordinator | **Fire Fox** (assistant) | Coordinates missions, merges PRs to `main`, pushes TestFlight tags (`testflight/*` / `mNN-approved` after approval). |
| Lead engineer | **Cursor cloud agents** | Write Swift, run GameCore tests on **Linux VMs**, push mission branches, fix CI, open PRs, send checkpoint reports. |

There is **no** assumption of a Windows PC toolchain, a local Mac, or Grok Build on Nicholas’s desk. Agents never claim an iPhone compile they did not run in GitHub Actions.

## 1. Your role (Cursor cloud agent)

You are lead engineer on a native iPhone game. You build, test, and report **one mission at a time**. You stop at the checkpoint and wait for Nicholas’s **APPROVED** (routed through Fire Fox).

You work on a **Linux cloud VM**: run `swift test` for GameCore (and other pure packages) here before every push. You **cannot** compile or run the iPhone app on this VM. Apple builds, simulator smoke, signing, and TestFlight upload happen only in GitHub Actions.

Fire Fox merges and tags. You do **not** push `testflight/*` or `mNN-approved` tags unless Fire Fox explicitly asks you to in that turn.

## 2. The product

- The game is **The Neon City Bandit**. Title via `ProductIdentity.displayTitle` only. Engineering identifiers (bundle ID `com.cinderandcrown.magpie`, Xcode target `Magpie`) stay unchanged.
- One line: a cocky masked raccoon in a neon night city. Pounce, belly-flop, hijack rides, bank Shinies before time runs out. Free the crew from MOP.
- Genre: 2D top-down action sandbox, played in 180-second runs.
- Device: iPhone only. Portrait only. One thumb. iOS 17.0 minimum.
- Audience: ages 13 to 35, casual to mid-core. Not a kids app.
- Age rating target: 9+. Cartoon mischief, robot enemies, no blood, no guns, no harm to people.
- Business: free. In-app purchases plus opt-in rewarded ads. No pay-to-win. No loot boxes in v1.

## 3. Pillars

When two pillars conflict, the lower number wins. Protect these fiercely — especially **#1 feel**.

1. Feels great in 10 seconds.
2. Every run makes a moment worth sharing.
3. There is always something new to unlock.
4. The city reacts to you.
5. Fair: skill beats spending.

## 4. Originality rules

These are legal rules. No exceptions.

1. Every character, name, sprite, sound, track, map and screen is original, CC0, or licensed with the license on file.
2. Nothing from Nintendo, Rockstar or any other publisher: no names, characters, art, music, sound-alikes, level layouts or look-alike screens. Keep their names out of code, comments, commits and file names.
3. Take genre ideas only: jumping, tool-gated doors, open-city driving.
4. Log every third-party asset in ASSETS_LICENSES.md: file, source URL, license, date.
5. If a request would break these rules, stop and say so.

## 5. Core design

### Controls

- Drag anywhere to move. The Bandit coasts for 0.25 seconds after the finger lifts.
- Quick tap to **Pounce**. A tap is a touch shorter than 180 ms that moves less than 10 points. A second finger counts.
- Touch and hold in the air for **Tail Swing** (latch and fling; A/B vs glide in Mission 1). Drag while holding to steer.
- Quick tap in the air to **Belly Flop** the nearest target within 1.5 tiles. With no target, flop straight down.
- One Junk Gadget button on the thumb side. It shows only when a gadget can be used.
- Variant B, behind a debug toggle: a fixed Pounce button. Gate 1 picks the winner.

### The hero

- Cocky masked raccoon; distinct from Sony’s Sly Cooper (no cane, no top-hat, no blue/gold). Mascot needs attorney review.
- The world is 2.5D: x and y on the ground, plus height. Anything in the air casts a shadow.
- A Pounce clears a 1-tile gap and lands on anything up to 1 tile tall.
- A Tail Swing lasts up to 1.2 seconds and crosses up to 4 tiles.
- A Belly Flop that hits bounces the Bandit up, adds 1 to the combo and refreshes Tail Swing.
- The combo window is **12 s** on the ground (`comboGroundGrace`). It caps at x10. **Mask Mode** at combo **x3** (double loot, neon mask, bots stagger) — Nicholas APPROVED 2026-11-17 (was x5 / 4.5 s).
- 3 hearts. A hit costs 1 heart and 10% of carried Shinies, then gives 1 second of safety.

### Vehicles

- Belly Flop a roof to Hijack Hop. It drives itself forward. Drag steers. Tap ejects with a high Pounce.
- Three at first: Scooter (fast, fragile), Taxi (balanced), Box Truck (slow, rams bots).
- Vehicles take damage, smoke, then break down. Borrowed vehicles respawn off-screen.
- Townies walk the sidewalks. They dodge, cheer or gasp. Nothing can hurt them.

### Heat

- Heat runs 0 to 5. Chaos raises it: stomping bots, smashing props, borrowing vehicles, speeding.
- Heat drops one level after 6 seconds out of every bot's sight. Alleys and bushes are cool-off spots.
- Higher Heat sends more Sweepbots and pays more Shinies.
- Bots: Sweepbot from Heat 1 (one flop). Scrubber from Heat 2 (two flops or a ram). Spotlight Drone from Heat 3 (it flies; its shadow warns you). Barrier Bot from Heat 4.
- Zero hearts means Bagged. The run ends. Carried Shinies are lost. Banked Shinies are safe.

### Shinies and banking

- Shinies are the loot and the only currency. Sources: street pickups 1, props 1 to 3, bots 5, strongboxes 25.
- Shinies from a Belly Flop are multiplied by the combo (and Mask Mode when active).
- Carried Shinies are at risk. Dive through a Stash Chute to bank them. Each district has 4 chutes. A used chute rests for 20 seconds.
- Banking multiplies by Heat: x1.0, x1.2, x1.5, x2.0, x2.5, x3.0 for Heat 0 to 5.

### The run

- Ready, then 180 seconds of play, then a 10-second Final Dash, then Results.
- In the Final Dash every ring is open. Reach one or lose what you carry.
- Results show banked Shinies, best combo, top Heat, new records, the saved clip and Play Again.
- Play Again puts the player back in control within 1.5 seconds.

## 6. Meta game

- The Den is the home screen. Den levels 1 to 10 cost Shinies. Each level unlocks one thing: a mask/skin, a vehicle type, a perk or a Junk Gadget.
- Junk Gadgets: 4 at v1.0. Each has three uses, one for travel, one for bots, one for puzzles. Gadgets run on an 8-second cooldown, never ammo.

| Junk Gadget | Travel | Bots | Puzzles | Arrives |
| --- | --- | --- | --- | --- |
| Bungee Cord | Zip to hook points, cross canals | Yank a Scrubber's shield | Pull levers from range | Den level 2 |
| Fizz Can | Launch yourself or a vehicle | Clear a cluster | Break cracked walls | Boss 1 |
| Magnet Glove | Ride metal rails | Pull a Spotlight Drone down | Drag metal crates | Boss 2 |
| Leaf Blower | Dash across wide gaps | Blow bots off ledges | Spin fans and switches | Boss 3 |

- MOP Safe Rooms are single-screen puzzle rooms. Untimed. 60 to 120 seconds each. Spotting a Safe Room Door during a run unlocks that room on the map. Each pays 1 Relic.
- Every safe room ships with a recorded solution replay. A test plays it back to prove it can be solved.
- Bosses: one per district. 3 Relics open the gate. The fight uses that district's gadget and lasts 90 to 150 seconds. Winning opens the next district, grants the next gadget, and advances crew rescue.
- Districts at v1.0: Neon Docks, Glow Market, Arcade Row, Spotless Tower. Each is 96 by 160 tiles with 4 stash chutes, 3 safe rooms and 1 boss.
- Soft launch ships Neon Docks and Glow Market, Bungee Cord and Fizz Can, 6 safe rooms and the Neon Docks boss.

## 7. Daily Run

- One seed per UTC day. Same city and same spawns for everyone.
- A fixed loadout for all players, so purchases never change a Daily score.
- The first finished attempt is the ranked score. Practice is unlimited after that.
- A streak counter pays cosmetic rewards at 3, 7, 14 and 30 days.

## 8. Money

Built in Mission 8. Design for it from day one.

- Rewarded ads only, always opt-in, never during a run. Three placements: double the banked Shinies at Results, one revive when Bagged, one free daily crate.
- No full-screen ads in a player's first 5 sessions. The policy after that waits for Gate 3 data.
- Starting catalog (open questions): Crew Pass $4.99 (proposed rename of Golden Ticket). Starter Pack $2.99 after run 5. Shinies packs proposed **off** at soft launch. Masks $0.99 to $3.99 proposed for direct sale.
- Nothing for sale raises the Daily Run score ceiling.
- Prices are starting points. Nicholas approves every price and offer.

## 9. Sharing

Built in Mission 6.

- Keep a rolling screen clip with ReplayKit and save the last 15 seconds at Results. 15 seconds is the system cap.
- Ask for recording permission with a friendly pre-prompt before run 2. If declined, never nag. Fall back to a result-card image.
- The Final Dash HUD shows the game name and the score, so every clip is branded.
- Use the system share sheet only. No social network SDKs.
- A Beat My Run link carries the seed and the score.
- Game Center: leaderboards, 20 achievements, Challenges and Activities. Guard newer APIs by iOS version.

## 10. Starting tuning

Every number lives in Tuning.json. No magic numbers in code. These are starting values, and playtests will change them.

| Key | Start value |
| --- | --- |
| Tile size | 32 points |
| Sim rate | 60 steps a second, fixed |
| Camera width | 12 tiles |
| Hero run speed | 5.5 tiles a second |
| Coast after release | 0.25 s |
| Pounce airtime | 0.45 s |
| Tail Swing max time | 1.2 s |
| Stomp bounce airtime | 0.6 s |
| Eject hop airtime | 0.7 s |
| Coyote time | 0.10 s |
| Input buffer | 0.12 s |
| Tap threshold | 180 ms and 10 points |
| Stomp target radius | 1.5 tiles |
| Combo ground grace | 0.4 s |
| Combo cap | x10 |
| Hearts | 3 |
| Safety time after a hit | 1.0 s |
| Scooter, Taxi, Truck speed | 9, 7.5 and 5.5 tiles a second |
| Heat cool-off | 6 s unseen per level |
| Ring rest | 20 s |
| Run length | 180 s |
| Final Dash | 10 s |
| Tool cooldown | 8 s |

## 11. Tech spec (adapted)

### Where things run

- **Cursor cloud agents** run on **Linux VMs**. Run GameCore (and other Foundation-only package) tests with `swift test` on the VM before every push. Never claim an iPhone build you did not run in Actions.
- **All Apple builds** run in GitHub Actions on the standard **`xcode-27`** hosted runner. Never use `xlarge` or any larger runner.
- The code repo is public (`cinderandcrown/neon-city-bandit`). A second, private repo will hold art, audio, level data, economy tables and licensed assets; the build will pull it with a deploy key when that exists.
- Signing and TestFlight upload use the **App Store Connect API key** already proven on `cinderandcrown/phoenix-fox` (secrets: `APPLE_TEAM_ID`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8`). Prefer Xcode cloud-managed / automatic signing with that key. **Do not introduce fastlane match** unless cloud signing fails on the runner and Fire Fox / Nicholas approve the fallback.

### Stack

- Swift 6 language mode with strict concurrency. Xcode 27. iOS 17.0 minimum. iPhone, portrait.
- SpriteKit draws the game. SwiftUI draws menus and the HUD. No SpriteKit physics. No third-party engine.
- The Xcode project is generated on the runner from XcodeGen `project.yml`. Never commit a hand-made `.xcodeproj`.
- Swift Package Manager only. No dependency without approval. Pin versions. Log licenses in ASSETS_LICENSES.md where relevant.

### Modules

| Module | Job | Rules |
| --- | --- | --- |
| GameCore | All game rules and the simulation | Pure Swift, Foundation only. No UIKit, SpriteKit or SwiftUI. Must pass `swift test` on the Linux agent VM, in the Linux CI job, and on the Mac CI runner |
| GameRender | Draws the state with SpriteKit | Reads state, never changes rules. Smooths between sim steps |
| GameApp (`Magpie` Xcode target) | SwiftUI shell, menus, HUD, settings | No game rules |
| Services | Store, Game Center, clips, analytics, remote config, haptics, audio, save | Each behind a protocol, with a mock for tests |

### Determinism

- Fixed 60 Hz step. Your own seeded random generator. No wall-clock time and no system randomness inside GameCore.
- The same seed plus the same inputs gives the same state hash, every time, on every device.
- Every run records its seed, inputs and sim version as a replay. Replays power tests, the Daily Run, vault proofs and bug reports.

### Data, not code

- Tuning.json holds every number. Maps are text grids, one character per tile, plus a JSON entity list. Art is looked up by string ID through an ArtCatalog. Text lives in a String Catalog.
- Placeholder art is drawn in code. Swapping in real art must need zero gameplay changes.

### The build loop

1. On the Linux agent VM: write code; run GameCore package tests (`swift test`). They must pass before any push.
2. Push to a mission branch (`mission/NN-name`). Open or update a PR. CI runs: GameCore on Linux (`ubuntu-24.04`), iPhone build + tests on `xcode-27`, simulator smoke (3 screenshots + 30-second video).
3. Read results with `gh`. Fix failures yourself. Report a checkpoint only when CI is green (or clearly blocked on an owner-only step).
4. **Fire Fox** merges when ready and pushes the TestFlight tag. CI then archives, signs with the ASC API key, and uploads. Agents do not tag unless asked.

### Tuning on the phone

- A debug menu edits every Tuning.json value live, shows FPS and frame time, and has an Export button that copies the JSON.
- Nicholas pastes exported tuning back (via Fire Fox / chat); agents commit it. Feel changes should rarely need a new build.
- **Bar:** Pounce, Tail Swing, Belly Flop, Mask Mode, vehicles, and juice must feel snappy and intentional on device. Do not ship muddy controls to clear a checkpoint.

### Budgets

| Budget | Limit |
| --- | --- |
| Frame rate on an iPhone 12-class phone | 60 fps sustained |
| Sim step | 4 ms |
| Active entities | 250 |
| Memory | 200 MB |
| Icon tap to playing | 5 s on first launch, 3 s after |
| Play Again to playing | 1.5 s |
| Download size | 150 MB |

### Tests

- Unit tests cover every rule in GameCore. Target 70% line coverage there.
- Golden replay tests: a recorded replay must reproduce its final state hash.
- Every fixed bug gets a test.
- A 10-minute random-input soak test must end with no crash and no stuck hero.

### Security on a public repo

- Secrets live only in GitHub Secrets. Never in code, logs, commits or artifacts.
- Workflows run on pushes and PRs from this repository, and on manual dispatch. Never run fork code with secrets. Never use `pull_request_target` to build pull-request code.
- Never upload the app file (`.ipa`), signing files or private content as artifacts. Screenshots and videos of placeholder builds are fine.
- Add no license that grants reuse. NOTICE: all rights reserved.

### Privacy and access

- No login. No personal data. No tracking without consent. Ship a privacy manifest.
- Left-hand mode, a haptics toggle, reduce-motion support, and never color as the only signal.

## 12. Hard rules

1. One mission at a time. Stop at the checkpoint. Wait for Nicholas’s **APPROVED** (via Fire Fox).
2. Never fake it. No stubbed feature reported as done. No invented test results, screenshots, metrics or data. If you cannot do something, say so.
3. Green before you report: zero build errors, zero warnings, all tests passing in CI. Link the run.
4. Check every Apple API against current Apple documentation before using it. Put the doc link in the pull request.
5. The originality rules in section 4 always apply.
6. No new dependency, SDK or paid service without approval. Spend no money.
7. Do not change signing setup, bundle ID, App Store Connect settings, prices or store listings without approval. Signing stays on the ASC API key path unless cloud signing fails.
8. One branch per mission, named `mission/NN-name`. Small commits. Never force-push `main`. **Fire Fox** tags `testflight/*` for uploads and `mNN-approved` only after APPROVED.
9. No magic numbers. Tuning goes in Tuning.json.
10. Stuck after 2 real attempts: stop and report what you tried. Never cut scope silently to get past it.
11. Stay in scope. Ideas for later go in BACKLOG.md, not into the build.
12. Keep DECISIONS.md current: every choice that changes the plan’s *process*, with the reason. Do not silently lower the feel/juice bar.
13. Simulator results never count as on-phone results. Nicholas’s device is the feel authority.

## 13. Checkpoint report

Send this at every checkpoint, in this order:

1. Status: PASS or FAIL for each checkpoint line, with evidence.
2. The CI run link and the test count: passed, failed, skipped.
3. What you built, in 5 lines or fewer.
4. Screenshots and video: the artifact links.
5. The TestFlight build number, if one was uploaded (Fire Fox tags; you report the resulting build).
6. What to try on the phone, as numbered steps (for Nicholas).
7. Known issues and risks.
8. Decisions you made, and anything you could not verify.
9. Questions for Nicholas, batched, 3 at most.

Then stop.
