# iPhone Game Plan — The Neon City Bandit (full plan)

Nov 14, 2026 · Nicholas Will

## How to use this file

1. Part 1 is for Nicholas. It covers setup, odds, money and legal.
2. Part 2 is the Master Brief. Paste it into Grok once. Grok saves it as AGENTS.md.
3. Part 3 is the missions. Paste one at a time. Wait for the checkpoint report. Reply APPROVED before the next.

If Grok is handed this whole file: read all of it, then do Mission 0 only and stop at its checkpoint.


## Theme amendment (2026-11-14, binding)

Nicholas approved **Trash Panda Heist: Game Plan v1** ([canvas](https://cursor.com/canvas/store-f0dfaef1-646f-4cb3-b3a2-4edd43f95165/7412b08b-bc3e-4248-b762-a4a8b08a389d)). Full design: `docs/DESIGN.md`.

- Hero: cocky masked raccoon (“the Bandit” until named). Villain: **MOP**. Goal: free the captured raccoon crew.
- Moves: **Pounce**, **Belly Flop**, **Tail Swing** (replaces glide; A/B in Mission 1), **Mask Mode** at combo **x5** (shareable moment). Hijack Hop for vehicles.
- Glossary: Shinies · Stash Chute · The Den · Bagged · Sweepbot/Scrubber/Spotlight Drone/Barrier Bot · Junk Gadgets · Neon Docks / Glow Market / Arcade Row / Spotless Tower · MOP Safe Rooms.
- Visual: distinct from Sony’s Sly Cooper (no cane, no top-hat thief look, no blue/gold). Mascot needs attorney review.
- User-facing title: **The Neon City Bandit** via `ProductIdentity.displayTitle`. Engineering identifiers (bundle ID, Xcode target `Magpie`) stay unchanged.
- Open questions for Nicholas: confirm “Trash Panda” availability; sell masks directly; no Shinies packs at soft launch; rename Golden Ticket → **Crew Pass**.

**Missions 1–10 target this raccoon heist theme.** Mission 0 stays the follow-square loop. Gates, budgets, and process numbers are unchanged. Where older Part 1–2 sentences still say “bird / toy city / hop / glide / Shine / Nest,” treat them as superseded by this amendment and `docs/DESIGN.md`.

---

# Part 1: Start here (for Nicholas)

Paste the Master Brief (Part 2) into Grok once, then feed it one mission at a time (Part 3). Builds run on GitHub's free hosted Macs from a public repo, so you can start without buying a Mac.

## Do this first

Builds run on GitHub's hosted Macs for $0, as long as the repo is public and the workflow uses the standard `xcode-27` runner ([GitHub billing docs](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions), [Xcode 27 image](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available)). No Mac purchase is needed to start.

1. You already have the Apple Developer Program. In App Store Connect, create an API key so the cloud build can sign and upload.
2. Create a public GitHub repo for the game code and a private one for art, audio and levels.
3. Install the TestFlight app on your iPhone.
4. Paste the Master Brief (Part 2) into Grok. Have Grok save it as AGENTS.md.
5. Paste Mission 0. It proves the full loop: push, cloud build, TestFlight, your phone.

How the loop works without a Mac:

- Grok writes Swift on this PC and runs the game-rules tests locally in seconds.
- Every push builds and tests on a GitHub Mac. Grok reads the logs and fixes its own errors.
- Each run saves screenshots and a 30-second video, so you can look without installing.
- A tagged build goes to TestFlight and onto your phone.
- Feel tuning needs no rebuild: a debug menu changes every number live on the phone.

What a public repo costs you:

- Anyone can read and copy the code. Keep art, audio, levels and prices in the private repo; the build pulls them in.
- Paid or licensed assets must never sit in the public repo.
- Secrets live only in GitHub Secrets. Never publish the app file as a build artifact.
- Use the standard runner only. The larger `xlarge` runners are billed even on public repos.

What you give up without a Mac: each code change takes roughly 10 to 25 minutes to reach your phone (my estimate), and there is no step debugger or profiler. If Gate 1 passes and you want the code private, a private repo gets about 200 Mac minutes a month free, then $0.062 a minute. At that point a Mac mini ($899 list) as your own runner pays for itself.

## The game

**The Neon City Bandit** — a cocky masked raccoon loose in a neon night city: pounce, belly-flop bots, hijack rides, bank Shinies before a 3-minute timer runs out. Villain: **MOP**. Free the captured raccoon crew.

| Parent | The idea we take (never the IP) | In The Neon City Bandit |
| --- | --- | --- |
| Mario | Jumping that feels great | Pounce, Tail Swing, Belly Flop, bounce combos up to x10; Mask Mode at x5 |
| Zelda | Tools open the world; puzzle rooms; bosses | 4 Junk Gadgets, each opens a district; 12 MOP Safe Rooms; 4 bosses |
| GTA | Open city; take any vehicle; heat escalates | Belly Flop a roof to hijack; Heat 0 to 5; Sweepbots give chase |

- 2D top-down. Portrait. One thumb. 180-second runs.
- Free to play: in-app purchases plus opt-in rewarded ads.
- Rating target 9+: cartoon mischief, robot enemies, nobody gets hurt. Rob robots and corp vaults only — never people.
- Every run ends in a 10-second Final Dash, and the game saves that clip to share. Mask Mode at x5 is the shareable in-run moment.
- One Daily Run: the same city for everyone, one ranked try a day.
- Soft launch ships half of it: 2 districts (Neon Docks, Glow Market), 2 gadgets, 6 safe rooms, 1 boss.

Why 2D: a 3D open world takes a studio. One founder plus AI agents can finish 2D. That is my judgment, not a measured fact.

Why Swift and SpriteKit: the whole game is code, with no editor clicking, so an agent can build and test it end to end. Trade-offs: iPhone only at first, and Apple has not given SpriteKit a major update in years.

Names and skin are product decisions (`docs/DESIGN.md`). Systems keep historical engineering identifiers; user-facing title is one constant. Keep the hero visually distinct from Sony’s Sly Cooper.

## Roadmap

Three gates decide whether The Neon City Bandit earns the next spend. Durations are estimates.

| Phase | Missions | What | Time | Gate at the end |
| --- | --- | --- | --- | --- |
| Prove it | 0 to 2 | Loop, toy, sandbox | 2 to 3 weeks | Gate 1, Fun: 3 of 5 play 5+ minutes |
| Build it | 3 to 7 | Full game and beta | 6 to 10 weeks | Gate 2, Beta: day-1 35% or more |
| Sell it | 8 and 9 | Money, soft launch | 7 to 16 weeks | Gate 3, Soft launch: day-1 40%, day-7 15% |
| Scale or stop | 10 | Launch or wrap up | By the numbers | None |

Each gate is a stop sign. The next phase, and its spending, starts only after the number clears.

## Gates and honest odds

Nobody can promise a viral hit, so the plan is built to find out cheaply: three gates, each with a number, and no launch spend until the numbers clear.

What the market data says:

- The top 1% of mobile games took about 92.5% of game revenue in 2025. Everyone else shared 7.5% ([Sensor Tower, via GameDev Reports](https://gamedevreports.substack.com/p/sensor-tower-the-state-of-the-mobile)).
- The median game keeps about 22% of players on day 1 and 4% on day 7. The top 10% keep about 40% and 12% ([GameAnalytics 2026 highlights](https://investgame.net/wp-content/uploads/2026/01/2026-01-20-Mobile_retention_benchmarks_2026.pdf)). That sample leans toward small studios.
- Hybrid-casual was the only segment whose purchase revenue grew in 2025 (same Sensor Tower report). Hybrid-casual means a simple core loop, deeper upgrades, and ads plus purchases. The Neon City Bandit is built in that shape.

| Gate | After | Test | Go | Rework or stop |
| --- | --- | --- | --- | --- |
| 1. Fun | Mission 2 | 5 new players, phone handed over, no instructions | 3 of 5 play 5+ minutes and ask to play again | Rework the feel. Two tries, then rethink the concept |
| 2. Beta | Mission 7 | 30 to 50 TestFlight testers over 14 days | Day-1 retention 35%+, median session 6+ minutes, 1 in 5 testers shares a clip | Fix the weakest step and retest |
| 3. Soft launch | Mission 9 | 1,000+ installs in 4 small markets | Day-1 40%+ and day-7 15%+ | Day-1 under 30% or day-7 under 8% after 2 fix cycles: stop |

The thresholds are my judgment. The stop line sits near the top quarter of iPhone games (day-1 31 to 33%, day-7 7 to 8%). The go line sits above the top 10%. One advisory source says paid ads for this genre start to pay near 18% day-7, and it cites no data for that ([Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-03-17-mobile-game-kpis-benchmarks-2026/)). Gate 2's sample is small, so read it as a direction, not a verdict.

## Money, time and your calls

Plan on roughly $1,700 to $6,500 over about six months to reach a soft-launch verdict. The artist and the ad test are only spent after a gate passes.

| Item | Cost | When | Status |
| --- | --- | --- | --- |
| Apple Developer Program | $0 new; you already pay the $99 a year | Mission 0 | Confirmed |
| GitHub Mac runners, public repo | $0 | Mission 0 | Confirmed |
| SuperGrok for Grok Build | about $30 a month | Now | Mid-2026 reports; check your plan |
| Human artist: mascot, logo, key art | $500 to $3,000 | After Gate 1 | My estimate |
| Sound and music licenses | $0 to $300 | Mission 5 | My estimate |
| Soft-launch ad test | $1,000 to $3,000 | After Gate 2 | My estimate |
| Mac mini M6, optional | $899 list | Only if you take the code private | Confirmed Nov 4 |

Apple's cut of sales is 15% inside the Small Business Program (under $1M a year in proceeds, and you must enroll) and 30% outside it ([program explainer](https://appsops.store/blog/app-store-small-business-program-commission)).

Time, my estimate: 4 to 6 months to a real go/no-go on a worldwide launch. It depends on how many hours a week you give playtests and approvals.

Only you decide:

1. Public or private code, and whether to add a Mac after Gate 1.
2. The mascot and the final name. Search the App Store and the USPTO trademark database before you commit.
3. The seller name. Your existing developer account sets it: an organization account shows the company, an individual account shows your personal name ([enrollment guide](https://studio.adalo.com/blog/apple-developer-program-guide)).
4. The spend at each gate.
5. The ad network and the analytics vendor. Grok brings a one-page comparison in Missions 7 and 8.

## Legal guardrails

Borrowing a genre is fine; borrowing anything recognizable is not. I am not a lawyer, so treat this as a checklist to take to one.

- Take ideas, never IP. No Nintendo or Rockstar names, characters, art, music, sounds, maps or look-alike screens. The Master Brief makes this a hard rule for Grok.
- Nintendo has also sued over game-mechanic patents. Its Palworld suit was filed in September 2024, and patent offices in the US and Japan later rejected related Nintendo claims ([Sports Litigation Alert](https://sportslitigationalert.com/patent-offices-in-u-s-japan-raise-questions-about-nintendos-palworld-lawsuit/)). A court view was due November 9, 2026; I found no report of the result. The Neon City Bandit's mechanics are decades-old genre staples. That is my read, not a legal opinion.
- AI-only art gets no US copyright, so anyone could copy it ([PC Gamer](https://pcgamer.com/software/ai/ai-generated-images-still-cant-be-copyrighted-as-us-supreme-court-declines-to-hear-case)). Have a human draw or heavily rework the mascot, logo and key art, under a written IP assignment.
- A public repo with no license file is still all rights reserved, but others can read and fork it on GitHub. That is one more reason to keep art, audio and levels private.
- This is not a kids app. Keep it out of the Kids category. If you ever market to under-13s, COPPA applies; see a lawyer first.
- Before soft launch, spend an hour with a games or IP attorney on the name, the mascot and the terms.

## Not verified yet, and sources

Six things in this plan are unconfirmed, and Mission 0 exists to test the first one.

- The no-Mac loop for this exact stack: generated Xcode project, cloud signing, TestFlight upload from a GitHub runner. Others have shipped from Windows this way; I have not run it for this project.
- Grok Build's features. They come from press coverage, not hands-on testing.
- Who can download build artifacts from a public repo. Grok must confirm GitHub's current rule before uploading any.
- Benchmarks differ by source. Treat them as ranges.
- The soft-launch market list (Canada, Australia, New Zealand, Philippines) comes from one advisory blog.
- Apple API names in the brief (ReplayKit, GameKit, StoreKit). Grok must check each against current Apple docs before use.

Sources:

- GitHub: [Actions billing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions), [usage limits](https://docs.github.com/en/actions/reference/usage-limits-billing-and-administration), [Xcode 27 runner image](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available)
- Shipping iPhone apps from Windows with no Mac: [one developer's write-up](https://dev.to/snake_sun/how-i-shipped-5-ios-apps-in-30-days-as-a-solo-dev-claude-code-fastlane-asc-api-31kd)
- Apple: [SDK minimums](https://www.developer.apple.com/news/upcoming-requirements/), [membership fee](https://developer.apple.com/support/compare-memberships), [ReplayKit clips](https://developer.apple.com/wwdc21/10101), [Game Center challenges](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-challenges), [age ratings](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/), [SpriteKit status thread](https://developer.apple.com/forums/thread/826562)
- Grok Build: [launch coverage](https://www.iclarified.com/100870/xai-launches-grok-build-coding-agent-with-parallel-subagents-and-mcp-support), [1.0 coverage](https://pasqualepillitteri.it/en/news/10006/grok-build-1-0-xai-leaves-beta)
- Market: [Sensor Tower via GameDev Reports](https://gamedevreports.substack.com/p/sensor-tower-the-state-of-the-mobile), [GameAnalytics 2026 highlights](https://investgame.net/wp-content/uploads/2026/01/2026-01-20-Mobile_retention_benchmarks_2026.pdf), [Game Growth Advisor benchmarks](https://gamegrowthadvisor.com/blog/2026-03-17-mobile-game-kpis-benchmarks-2026/), [soft-launch playbook](https://gamegrowthadvisor.com/blog/2026-05-19-mobile-game-growth-strategy-complete-playbook-2026/)
- Mac mini price: [StarryHope tracker](https://www.starryhope.com/minipcs/mac-mini-black-friday-deals-2026/)
- AI art and copyright: [Promise Legal guide](https://blog.promise.legal/ai-generated-game-assets-legal-guide/)

---

# Part 2: Master Brief (paste into Grok once)

This part is written to Grok. Paste all of it at the start, and save it as AGENTS.md in the repo. It applies to every mission.

## 1. Your role

You are lead engineer on a native iPhone game. Nicholas owns the product and approves every checkpoint. You build, test and report. You work one mission at a time.

## 2. The product

- The game is **The Neon City Bandit** (`ProductIdentity.displayTitle`).
- One line: a cocky masked raccoon in a neon night city. Pounce, belly-flop, hijack rides, bank Shinies before time runs out. Free the crew from MOP.
- Genre: 2D top-down action sandbox, played in 180-second runs.
- Device: iPhone only. Portrait only. One thumb. iOS 17.0 minimum.
- Audience: ages 13 to 35, casual to mid-core. Not a kids app.
- Age rating target: 9+. Cartoon mischief, robot enemies, no blood, no guns, no harm to people.
- Business: free. In-app purchases plus opt-in rewarded ads. No pay-to-win. No loot boxes in v1.

## 3. Pillars

When two pillars conflict, the lower number wins.

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
- Touch and hold in the air for **Tail Swing**: latch a lamp/sign/wire and fling (or a short coat-flap if nothing to grab). Drag while holding to steer. Mission 1 A/B-tests Tail Swing vs classic glide behind a debug toggle.
- Quick tap in the air to **Belly Flop** the nearest target within 1.5 tiles. With no target, flop straight down.
- One Junk Gadget button on the thumb side. It shows only when a gadget can be used.
- Variant B, behind a debug toggle: a fixed Pounce button. Gate 1 picks the winner.

### The hero

- Cocky masked raccoon. Visually distinct from Sony’s Sly Cooper: no cane, no top-hat gentleman-thief look, no blue/gold palette. Scruffy junk-gadget chaos. Mascot needs attorney review.
- The world is 2.5D: x and y on the ground, plus height. Anything in the air casts a shadow.
- A Pounce clears a 1-tile gap and lands on anything up to 1 tile tall.
- A Tail Swing lasts up to 1.2 seconds and crosses up to 4 tiles (same tuning keys as the old glide until retuned).
- A Belly Flop that hits bounces the Bandit up, adds 1 to the combo and refreshes Tail Swing.
- The combo breaks after 0.4 seconds on the ground. It caps at x10.
- At combo **x5**, **Mask Mode** turns on: mask lights neon, double loot while active, flourishes, bots stagger — the shareable moment.
- 3 hearts. A hit costs 1 heart and 10% of carried Shinies, then gives 1 second of safety.

### Vehicles

- Belly Flop a roof to **Hijack Hop**. It drives itself forward. Drag steers. Tap ejects with a high Pounce.
- Three at first: Scooter (fast, fragile), Taxi (balanced), Box Truck (slow, rams bots).
- Vehicles take damage, smoke, then break down. Hijacked vehicles respawn off-screen.
- Townies walk the sidewalks. They dodge, cheer or gasp. Nothing can hurt them. Rob robots and Spotless Inc. only.

### Heat

- Heat runs 0 to 5. Chaos raises it: flopping bots, smashing props, hijacking vehicles, speeding.
- Heat drops one level after 6 seconds out of every bot's sight. Alleys and dumpsters are cool-off spots.
- Higher Heat sends more Sweepbots and pays more Shinies.
- Bots: Sweepbot from Heat 1 (one flop). Scrubber from Heat 2 (two flops or a ram). Spotlight Drone from Heat 3 (it flies; its shadow warns you). Barrier Bot from Heat 4.
- Zero hearts means **Bagged**. The run ends. Carried Shinies are lost. Banked Shinies are safe.

### Shinies and banking

- Shinies are the loot and the only currency. Sources: street pickups 1, props 1 to 3, bots 5, strongboxes 25.
- Shinies from a Belly Flop are multiplied by the combo (and by Mask Mode when active).
- Carried Shinies are at risk. Dive through a **Stash Chute** to bank them. Each district has 4 chutes. A used chute rests for 20 seconds.
- Banking multiplies by Heat: x1.0, x1.2, x1.5, x2.0, x2.5, x3.0 for Heat 0 to 5.

### The run

- Ready, then 180 seconds of play, then a 10-second Final Dash, then Results.
- In the Final Dash every stash chute is open. Reach one or lose what you carry.
- Results show banked Shinies, best combo, top Heat, new records, the saved clip and Play Again.
- Play Again puts the player back in control within 1.5 seconds.

## 6. Meta game

- **The Den** is the home screen. Den levels 1 to 10 cost Shinies. Each level unlocks one thing: a mask/skin, a vehicle type, a perk or a Junk Gadget.
- Junk Gadgets: 4 at v1.0. Each has three uses, one for travel, one for bots, one for puzzles. Gadgets run on an 8-second cooldown, never ammo.

| Junk Gadget | Travel | Bots | Puzzles | Arrives |
| --- | --- | --- | --- | --- |
| Bungee Cord | Zip to hook points, cross canals | Yank a Scrubber's shield | Pull levers from range | Den level 2 |
| Fizz Can | Launch yourself or a vehicle | Clear a cluster | Break cracked walls | Boss 1 |
| Magnet Glove | Ride metal rails | Pull a Spotlight Drone down | Drag metal crates | Boss 2 |
| Leaf Blower | Dash across wide gaps | Blow bots off ledges | Spin fans and switches | Boss 3 |

- **MOP Safe Rooms** are single-screen puzzle rooms. Untimed. 60 to 120 seconds each. Spotting a Safe Room Door during a run unlocks that room on the map. Each pays 1 Relic.
- Every safe room ships with a recorded solution replay. A test plays it back to prove it can be solved.
- Bosses: one per district (MOP lieutenants / Spotless hardware). 3 Relics open the gate. The fight uses that district's gadget and lasts 90 to 150 seconds. Winning opens the next district, grants the next gadget, and advances crew-rescue beats.
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
- Starting catalog (proposed; open questions for Nicholas): **Crew Pass** $4.99 (rename from Golden Ticket; no forced ads, rewarded bonuses without watching). Starter Pack $2.99, offered once after run 5. Shinies packs $1.99, $4.99, $9.99 and $19.99 — **proposed: none at soft launch**. Masks/skins $0.99 to $3.99 — **proposed: sell masks directly** (cosmetic, what-you-see).
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
| Pounce airtime (was Hop) | 0.45 s |
| Tail Swing max time (was Glide) | 1.2 s |
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

## 11. Tech spec

### Where things run

- You run on Nicholas's Windows PC. You cannot compile an iPhone app there. Never claim a build you did not run.
- All Apple builds run in GitHub Actions on the standard `xcode-27` hosted runner. Never use `xlarge` or any larger runner; those cost money.
- The code repo is public. A second, private repo holds art, audio, level data, economy tables and anything licensed. The build pulls it in with a deploy key.
- Nicholas already has an Apple Developer Program membership. Signing and upload use an App Store Connect API key stored in GitHub Secrets.

### Stack

- Swift 6 language mode with strict concurrency. Xcode 27. iOS 17.0 minimum. iPhone, portrait.
- SpriteKit draws the game. SwiftUI draws menus and the HUD. No SpriteKit physics. No third-party engine.
- The Xcode project is generated on the runner from a text file (XcodeGen `project.yml`). Never commit a hand-made `.xcodeproj`.
- Swift Package Manager only. No dependency without Nicholas's approval. Pin versions. Log licenses.

### Modules

| Module | Job | Rules |
| --- | --- | --- |
| GameCore | All game rules and the simulation | Pure Swift, Foundation only. No UIKit, SpriteKit or SwiftUI. Must pass `swift test` on this PC, on Linux and on macOS |
| GameRender | Draws the state with SpriteKit | Reads state, never changes rules. Smooths between sim steps |
| GameApp | SwiftUI shell, menus, HUD, settings | No game rules |
| Services | Store, Game Center, clips, analytics, remote config, haptics, audio, save | Each behind a protocol, with a mock for tests |

### Determinism

- Fixed 60 Hz step. Your own seeded random generator. No wall-clock time and no system randomness inside GameCore.
- The same seed plus the same inputs gives the same state hash, every time, on every device.
- Every run records its seed, inputs and sim version as a replay. Replays power tests, the Daily Run, vault proofs and bug reports.

### Data, not code

- Tuning.json holds every number. Maps are text grids, one character per tile, plus a JSON entity list. Art is looked up by string ID through an ArtCatalog. Text lives in a String Catalog.
- Placeholder art is drawn in code. Swapping in real art must need zero gameplay changes.

### The build loop

1. Write code. Run GameCore tests locally. They must pass before any push.
2. Push to a mission branch. CI runs three jobs: GameCore tests on Linux, the iPhone build plus tests on `xcode-27`, and a simulator smoke run that saves 3 screenshots and a 30-second video.
3. Read the results with the `gh` CLI. Fix failures yourself. Report only when green.
4. On a checkpoint tag, CI archives, signs and uploads to TestFlight.

### Tuning on the phone

- A debug menu edits every Tuning.json value live, shows FPS and frame time, and has an Export button that copies the JSON.
- Nicholas pastes exported tuning back to you and you commit it. Feel changes should rarely need a new build.

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
- Workflows run on pushes to protected branches and on manual dispatch. Never run fork code with secrets. Never use `pull_request_target` to build pull-request code.
- Never upload the app file, signing files or private content as artifacts. Screenshots and videos of placeholder builds are fine.
- Add no license that grants reuse. Add a notice: all rights reserved.

### Privacy and access

- No login. No personal data. No tracking without consent. Ship a privacy manifest.
- Left-hand mode, a haptics toggle, reduce-motion support, and never color as the only signal.

## 12. Hard rules

1. One mission at a time. Stop at the checkpoint. Wait for APPROVED.
2. Never fake it. No stubbed feature reported as done. No invented test results, screenshots, metrics or data. If you cannot do something, say so.
3. Green before you report: zero build errors, zero warnings, all tests passing in CI. Link the run.
4. Check every Apple API against current Apple documentation before using it. Put the doc link in the pull request.
5. The originality rules in section 4 always apply.
6. No new dependency, SDK or paid service without approval. Spend no money.
7. Do not touch signing, the bundle ID, App Store Connect settings, prices or store listings without approval.
8. One branch per mission, named `mission/NN-name`. Small commits. Never force-push main. Tag `mNN-approved` only after approval.
9. No magic numbers. Tuning goes in Tuning.json.
10. Stuck after 2 real attempts: stop and report what you tried. Never cut scope silently to get past it.
11. Stay in scope. Ideas for later go in BACKLOG.md, not into the build.
12. Keep DECISIONS.md current: every choice that changes the plan, with the reason.

## 13. Checkpoint report

Send this at every checkpoint, in this order:

1. Status: PASS or FAIL for each checkpoint line, with evidence.
2. The CI run link and the test count: passed, failed, skipped.
3. What you built, in 5 lines or fewer.
4. Screenshots and video: the artifact links.
5. The TestFlight build number, if one was uploaded.
6. What to try on the phone, as numbered steps.
7. Known issues and risks.
8. Decisions you made, and anything you could not verify.
9. Questions for Nicholas, batched, 3 at most.

Then stop.

---

# Part 3: Missions (paste one at a time)

Each mission is written to Grok. Paste one, wait for its checkpoint report, check it, then reply APPROVED before pasting the next.

## Mission 0: Prove the loop

Goal: a blank Neon City Bandit app travels from a push on this PC to Nicholas's iPhone through GitHub's hosted Macs, with no Mac on the desk.

Build:

1. Report your environment: OS, Swift toolchain version, `gh` version, Grok Build version. Confirm you can run `swift test` locally. If you cannot, set up the Swift toolchain for Windows or WSL2 first.
2. Write OWNER_SETUP.md: the exact clicks Nicholas must do himself, each checked against current Apple and GitHub docs. It covers: create the public code repo and the private content repo; register the bundle ID; create the app record in App Store Connect; create an App Store Connect API key; add the key and IDs to GitHub Secrets; add a deploy key for the private repo; install TestFlight and join the internal test group. Then wait for him to confirm.
3. Create the repo layout: AGENTS.md (the Master Brief), README, .gitignore, ASSETS_LICENSES.md, DECISIONS.md, BACKLOG.md, `project.yml`, and the packages GameCore, GameRender and Services with one passing test each.
4. Build the app: a SpriteKit scene inside a SwiftUI view, one square that follows the finger, and an FPS counter in debug builds.
5. Write the CI workflows: GameCore tests on Linux; build and test on `xcode-27`; a simulator smoke run that saves 3 screenshots and a 30-second video; a tag-triggered TestFlight upload.
6. Signing: try Xcode's cloud-managed signing through the API key first. If it fails on the runner, use fastlane match with a private certificates repo. Report which one works.
7. Set the export-compliance flag in Info.plist so TestFlight builds do not stall on that question. Confirm the value with Nicholas first.

Not in this mission: any game code.

Checkpoint, all must be true:

- `swift test` passes on this PC and in the Linux job.
- The `xcode-27` build has 0 errors and 0 warnings.
- The smoke run produced real screenshots and a real video. If the hosted simulator cannot draw SpriteKit, say so plainly and propose a fallback. Do not fake them.
- A TestFlight build is on Nicholas's iPhone and the square follows his finger. He confirms.
- You measured and reported two times: push to green CI, and tag to installable build.
- No secret appears in any log or artifact. Every job used a standard runner.

Send the checkpoint report. Then stop and wait for APPROVED M0.

## Mission 1: The toy

Goal: moving the Bandit (placeholder raccoon silhouette) around an empty neon alley block is fun for 60 seconds with no goals at all.

Build:

1. The GameCore loop: fixed 60 Hz step, seeded random generator, input commands, state hash, replay record and playback.
2. A map loader for text grids. One test block, 40 by 60 tiles: ground, 1-tile walls, canal gaps, ramps, crates, latch points for Tail Swing.
3. The Bandit: run, coast, Pounce, Tail Swing (A/B vs glide behind debug toggle), Belly Flop, bounce, coyote time, input buffer, height and shadow. Mask Mode trigger stub at combo x5 (juice can be minimal).
4. Collision: tiles plus boxes, height-aware, so the Bandit can land on anything up to 1 tile tall.
5. Ten flop dummies that respawn, and a combo counter.
6. The camera: follows with look-ahead, 12 tiles wide, with a shake hook.
7. Both control variants, A and B, behind a debug toggle.
8. The debug menu: live edit of every Tuning.json value, time scale, hitbox view, seed entry, replay record and play, Export tuning, and Copy perf report (average fps, worst 1% fps, frame time).
9. Placeholder visuals drawn in code through the ArtCatalog (raccoon-shaped silhouette, not a bird). No image files yet. No cane / top-hat / blue-gold Sly-like look.
10. First juice: squash and stretch on Pounce and landing, a dust puff, a 50 ms hit-pause on Belly Flop, a light haptic on flop, a brief Mask Mode flash at x5.

Not in this mission: vehicles, Heat, Shinies, menus, sound.

Checkpoint, all must be true:

- At least 25 GameCore tests pass, including: a Pounce clears a 1-tile gap; a Tail Swing (or glide variant) crosses 4 tiles; Belly Flop bounces chain; coyote time works; a buffered Pounce fires; Mask Mode arms at x5.
- One golden replay of 30 seconds reproduces the same final state hash 100 times in a row.
- The Bandit responds within 2 frames of input.
- Nicholas's perf report from his iPhone shows 60 fps average and no worse than 55 fps in the worst 1%.
- Nicholas answers five feel checks on the phone: the Pounce feels snappy; Tail Swing (or glide) feels controllable; Belly Flops feel punchy; I never fought the controls; I wanted to keep moving. At least four are yes.

Send the checkpoint report, plus a 30-second video of each control variant. Then stop and wait for APPROVED M1.

## Mission 2: The sandbox, then Gate 1

Goal: the neon city fights back (Sweepbots), and strangers keep playing without being told what to do.

Build:

1. Vehicles: Scooter, Taxi, Box Truck. Lane-following traffic. Belly Flop a roof to Hijack Hop. Auto-drive, drag to steer, tap to eject. Damage, smoke, breakdown.
2. Townies: they wander, dodge and react. Nothing can hurt them. Vehicles and the Bandit nudge them aside.
3. Sweepbots and Scrubbers. They spawn by Heat, chase with simple steering and line of sight, and cost hearts on a hit.
4. Heat 0 to 3: sources, decay, cool-off spots (alleys, dumpsters) and a HUD meter.
5. Eight breakable props, including a hydrant whose water launches the Bandit, and ramps that launch vehicles.
6. The combo system with number pop-ups, plus Mask Mode at x5 (double loot stub, neon flash, bots stagger briefly).
7. A test district, 64 by 96 tiles: neon roads, sidewalks, alleys, a canal and 2 ramps.
8. Hearts, the Bagged state and an instant restart.
9. Twelve placeholder sound effects, CC0 only, each logged in ASSETS_LICENSES.md.

Not in this mission: Shinies, the timer, menus, Junk Gadgets, MOP Safe Rooms.

Checkpoint, all must be true:

- At least 60 GameCore tests pass, and 3 golden replays reproduce their hashes.
- The 10-minute random-input soak test ends with no crash and the Bandit never stuck for more than 5 seconds.
- Nicholas's perf report shows 60 fps average with 20 vehicles, 40 townies and 15 bots active.
- A TestFlight build is ready for Gate 1.

Gate 1, run by Nicholas: hand the phone to 5 people who have never seen the game and say nothing. Record minutes played before they put it down, whether they hijacked a vehicle unprompted, whether they noticed Mask Mode, and whether they asked to play again.

- Go: 3 of 5 play 5 minutes or more, and 3 of 5 ask to play again.
- Otherwise: Nicholas sends you the notes. Rework the feel. Two rework rounds at most, then stop and rethink the concept together.

Send the checkpoint report. Then stop and wait for APPROVED M2 and the Gate 1 result.

## Mission 3: The run

Goal: one complete 3-minute heist, from first touch to Results, that a new player understands without reading.

Build:

1. The run state machine: Ready, Run for 180 seconds, Final Dash for 10 seconds, Results, plus the Bagged path.
2. Shinies: every source, carrying, the HUD count, 4 Stash Chutes with a 20-second rest, the Heat multiplier at banking, the combo bonus, and Mask Mode double-loot while active.
3. Heat 4 and 5, the Spotlight Drone and the Barrier Bot.
4. District 1, Neon Docks: 96 by 160 tiles as a hand-written text grid in the private content repo. A pier, a night market stub, a canal, a ferry ramp and rooftops. 4 stash chutes, 3 locked Safe Room Doors, 12 cool-off spots, 6 secrets. Story beat: first clue to the caged crew.
5. The HUD as a SwiftUI overlay: timer, carried Shinies, banked Shinies, Heat, hearts, combo / Mask Mode. Nothing sits under the thumb.
6. The Results screen: stats, records and Play Again.
7. First launch: the player controls the Bandit within 5 seconds. No menu first. Three prompts in context, for move, Pounce and Belly Flop, each 5 words or fewer.
8. Save version 1: local, versioned, written to a temp file and swapped in, so a crash cannot corrupt it.
9. Personal bests.

Not in this mission: The Den, Junk Gadgets, MOP Safe Rooms, bosses, sharing, purchases.

Checkpoint, all must be true:

- At least 100 GameCore tests pass. Every score multiplier path has a test (including Mask Mode).
- A scripted replay bot finishes 20 full runs in a row in CI with no crash.
- The same seed and inputs give the same final score in CI and in a replay exported from Nicholas's phone.
- Play Again reaches gameplay within 1.5 seconds on Nicholas's phone.
- Three fresh testers, run by Nicholas: first Belly Flop inside 20 seconds, first hijacked vehicle inside 90 seconds, and all three finish a run without help.

Send the checkpoint report. Then stop and wait for APPROVED M3.

## Mission 4: The meta

Goal: a reason to come back tomorrow. Shinies buy progress, Junk Gadgets open the world, MOP Safe Rooms and a boss give it shape — and the crew-rescue track advances.

Build:

1. The Den as the home screen: levels 1 to 10, the unlock track (masks, vehicles, perks, gadgets), and a Play button that is always one tap from a run. Show which crew members are still caged.
2. Two Junk Gadgets, Bungee Cord and Fizz Can: three uses each, the 8-second cooldown, 3 upgrade levels.
3. The MOP Safe Room system: a room loader, the puzzle pieces (switch, door, crate, pressure plate, laser gate, moving platform, hook point, cracked wall), a win check and the Relic reward.
4. Six safe rooms, 3 per gadget, rising in difficulty. Each has a solution replay that CI plays back.
5. The Neon Docks boss (MOP lieutenant / Spotless hardware): 3 phases, beaten with the Bungee Cord. Winning grants Fizz Can, opens Glow Market, and frees one crew member.
6. District 2, Glow Market: 96 by 160 tiles, same rules as Neon Docks.
7. The map screen: districts, safe rooms found and cleared, the boss gate, crew status.
8. Economy version 1 in Economy.json, in the private content repo. Simulate a scripted average player and export the progression curve as a CSV.
9. Save version 2, with a tested migration from version 1.

Not in this mission: final art, sharing, purchases, ads.

Checkpoint, all must be true:

- All 6 safe-room solution replays pass in CI.
- The economy CSV shows: Den level 3 by the end of session 1, the second gadget by day 3, and no unlock before Den level 6 that takes more than 8 runs of saving.
- The save migration test passes.
- Three fresh testers, run by Nicholas, each clear Safe Room 1 in under 3 minutes without help.
- Nicholas beats the Neon Docks boss and reports the number of tries. Target: 2 to 5.

Send the checkpoint report. Then stop and wait for APPROVED M4.

## Mission 5: Juice and identity

Goal: the game looks and sounds like The Neon City Bandit — neon night, masked raccoon, MOP menace — and still runs at 60 fps.

Build:

1. The art pass through the ArtCatalog. Nicholas supplies or approves every source: a human artist for the Bandit, MOP, logo and key art (attorney review before locking the mascot); CC0 or licensed packs for the rest. Integrate texture atlases from the private content repo. Never generate look-alikes of existing games (especially no Sly Cooper cane/top-hat/blue-gold).
2. Bandit animation in 4 directions: run, Pounce, Tail Swing, Belly Flop, hurt, celebrate, Mask Mode idle.
3. Particles, screen shake that respects reduce-motion, hit-pause, Mask Mode neon bloom at x5, a short slow-motion at combo x10, number pops.
4. Core Haptics patterns for Pounce, Belly Flop, bank, Bagged, Mask Mode and each combo tier.
5. Audio: about 40 sound effects and 3 music loops for The Den, the heist run and the Final Dash. The player's own music keeps playing if it is on.
6. The app icon and launch screen, for Nicholas's approval (uses `ProductIdentity.displayTitle` only — no scattered title strings).
7. The accessibility pass from the tech spec.

Not in this mission: new mechanics or content.

Checkpoint, all must be true:

- Nicholas's perf report still shows 60 fps average. Memory stays under 200 MB. Download size stays under 150 MB.
- Every asset is listed in ASSETS_LICENSES.md with its source and license. Nothing licensed sits in the public repo.
- A before-and-after video of the same replay, including a Mask Mode moment.
- Nicholas approves the look, the icon and the sound. Attorney note on mascot filed or explicitly deferred.

Send the checkpoint report. Then stop and wait for APPROVED M5.

## Mission 6: Share and social

Goal: every heist ends with something worth sending to a friend (especially Mask Mode + Final Dash), and one tap sends it.

Build:

1. The ReplayKit rolling clip: the pre-prompt before run 2, export of the last 15 seconds at Results, a preview and a Share button. Prefer clips that include Mask Mode when it fired.
2. The branded Final Dash HUD using `ProductIdentity.displayTitle` only.
3. The result card image, 1080 by 1920, with score, best combo, top Heat, Mask Mode peak and the day number.
4. The Daily Run: UTC seed, fixed loadout, first attempt ranked, practice after, the streak counter.
5. Game Center: sign-in that never blocks play, 3 leaderboards (daily, best run, best combo), 20 achievements (include Mask Mode / crew-rescue beats), and Challenges plus Activities on the iOS versions that support them.
6. The Beat My Run link, which opens the same seeded run.
7. A rating prompt after a personal best, within Apple's rules for how often it may appear.

Not in this mission: purchases, ads, analytics.

Checkpoint, all must be true:

- The clip exports in under 3 seconds on Nicholas's phone and plays after he shares it to Messages and saves it to Photos.
- Declining recording, declining Game Center and airplane mode each leave the game fully playable.
- Two phones on the same day show the same Daily Run city. Nicholas confirms with a second device or tester.
- Game Center features pass in the sandbox, with screenshots.

Send the checkpoint report. Then stop and wait for APPROVED M6.

## Mission 7: Telemetry and beta, then Gate 2

Goal: real numbers from real testers, so the next decision rests on data.

Build:

1. Bring Nicholas a one-page comparison of analytics options: cost, SDK size, privacy manifest status, what each measures. Candidates include Firebase, PostHog and TelemetryDeck. He picks. Check current terms; do not rely on memory.
2. Analytics behind an AnalyticsSink protocol, so the vendor can be swapped. No personal data in any event.
3. Events: app open, first control, first Pounce, first Belly Flop, first hijack, Mask Mode start/end, run start, run end (banked, best combo, top Heat, cause, length), bank, Bagged, Final Dash result, safe room found, safe room cleared, boss result, crew freed, Den level up, gadget unlock, clip prompt result, clip shared, Daily start and end, session end.
4. Remote config for Tuning.json overrides, with safe offline defaults.
5. Crash reporting.
6. A funnel view: install, first control, first Belly Flop, first Mask Mode, first run finished, third run, day-1 return, day-7 return.
7. The external TestFlight build: the What to Test text and the beta review answers, drafted for Nicholas to submit (raccoon heist framing; engineering IDs internal only).

Not in this mission: purchases, ads.

Checkpoint, all must be true:

- Every event fires once and only once in a scripted run, proven by a test against the mock sink.
- The app works fully offline and with analytics blocked.
- The funnel view shows data from Nicholas's own device.

Gate 2, run by Nicholas: 30 to 50 outside testers for 14 days.

- Go: day-1 retention 35% or more, median session 6 minutes or more, 1 in 5 testers shares a clip, crash-free sessions 99.5% or more.
- Otherwise: find the weakest funnel step, fix it, retest. The sample is small, so treat one bad number as a signal, not a verdict.

Send the checkpoint report. Then stop and wait for APPROVED M7 and the Gate 2 result.

## Mission 8: Money

Goal: the game can earn, without ever getting in the way of a heist.

Build:

1. Bring Nicholas a one-page comparison of ad mediation options: current terms, SDK size, privacy manifest status. Candidates include AppLovin MAX and Google AdMob. He picks.
2. StoreKit 2: the starting catalog per open questions — **Crew Pass** (proposed rename of Golden Ticket), Starter Pack, masks for sale (proposed), **no Shinies packs at soft launch** (proposed). StoreKit configuration for local tests; purchase, restore, refunds, Ask to Buy and interrupted purchases. Prices always come from StoreKit, never hard-coded. Do not ship contested SKUs until Nicholas answers the open questions in `docs/DESIGN.md`.
3. Rewarded ads in the 3 placements, with frequency caps. No ad during a run, ever. Test ads only until Nicholas approves live ads.
4. The tracking-permission prompt only if the chosen SDK needs it, after run 3, with a pre-prompt. The game works fully if the player declines.
5. The Starter Pack offer after run 5, and the store screen (masks / Crew Pass framing).
6. The privacy manifest, plus draft answers for the App Privacy labels and the age-rating questionnaire, for Nicholas to review.
7. A test proving purchases change nothing in Daily Run scoring.

Not in this mission: store listing, launch.

Checkpoint, all must be true:

- StoreKit tests pass for every product: buy, cancel, restore, refund.
- Nicholas completes a sandbox purchase and a restore on his phone.
- No ad offer and no purchase offer appears before run 3.
- The app works in airplane mode. Download size is still under 150 MB.
- No ad or store key sits in the public repo.
- Open questions on Crew Pass / masks / Shinies packs are either answered or explicitly deferred with Nicholas.

Send the checkpoint report. Then stop and wait for APPROVED M8.

## Mission 9: Store and soft launch, then Gate 3

Goal: the raccoon heist is live in four small markets, and the numbers say go, fix or stop.

Build:

1. Keep **The Neon City Bandit** as `ProductIdentity.displayTitle`. Drop anything close to Sony’s Sly Cooper. Sync ASC listing name when ready (bundle ID stays).
2. The store listing draft: name, subtitle, keywords, description, promotional text (neon heist / Mask Mode / free the crew). Confirm Apple's current length limits and screenshot sizes before writing.
3. Six screenshots and 2 preview videos, cut from real gameplay only — include at least one Mask Mode moment.
4. Review prep: App Review notes, the content rights statement, the age rating, the privacy labels, export compliance, attorney note on mascot. All drafted for Nicholas to submit.
5. The soft-launch setup: the Canada, Australia, New Zealand and Philippines storefronts only. Nicholas confirms the list. Catalog respects soft-launch IAP decisions (Crew Pass / masks / no Shinies packs if still proposed).
6. Ten short ad videos, 5 to 15 seconds each, cut from real gameplay clips (Mask Mode and Belly Flop moments), with a naming scheme so each can be tracked. Never show gameplay that is not in the game.
7. Live-ops basics: a weekly modifier, such as low-gravity week or double Mask Mode window, switched by remote config.

Not in this mission: new districts, gadgets or modes.

Checkpoint, all must be true:

- The release build passes App Review and is live in the 4 storefronts.
- The dashboard shows installs, day-1 and day-7 retention, session length, crash-free rate, ad views per player, payer share and revenue per daily player.
- Nicholas has the 10 ad videos and the tracking scheme.

Gate 3, run by Nicholas, after 1,000 installs or more:

- Go: day-1 40% or more and day-7 15% or more, with crash-free sessions 99.5% or more.
- Fix: day-1 between 30% and 40%, or day-7 between 8% and 15%. Run up to 2 two-week cycles on the weakest funnel step.
- Stop: below those lines after 2 cycles.
- Before any large ad spend, compare the cost of an install with what a player earns over time. Spend only when earnings clearly exceed cost.

Send the checkpoint report. Then stop and wait for APPROVED M9 and the Gate 3 result.

## Mission 10: Scale or stop

Goal: act on the Gate 3 result with no drift.

If Go:

1. Worldwide release as **The Neon City Bandit** (`ProductIdentity.displayTitle` + ASC listing rename as needed; bundle ID stays).
2. Arcade Row and Spotless Tower, Magnet Glove and Leaf Blower, 6 more MOP Safe Rooms, 3 more bosses; finish freeing the raccoon crew.
3. A season pass and a 28-day season calendar (masks / neon seasons).
4. Localization, starting with Spanish.
5. A written recommendation on Android: GameCore carries over, the drawing layer does not.
6. A written recommendation on taking the code private and adding a Mac runner.

If Stop:

1. A one-page post-mortem: what the numbers said, what was tried, what was learned.
2. A list of what carries into the next game: GameCore, the services, the CI pipeline and the tuning tools.

Send the checkpoint report. Then stop.
