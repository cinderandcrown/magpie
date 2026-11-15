# Decisions

Every choice that changes the plan, with the reason. Newest first.

## 2026-11-15 — APPROVED M0; Mission 1 toy + home-screen name

| Decision | Reason |
| --- | --- |
| Start Mission 1 on `cursor/mission-1-raccoon-toy-0c7d` | Fire Fox / Nicholas: APPROVED M0; build 12.1 on device. |
| `CFBundleDisplayName` = **Trash Panda**; `ProductIdentity.displayTitle` = Trash Panda | Nicholas: home screen still said Magpie. |
| `ITSAppUsesNonExemptEncryption` = false | Nicholas verified: no encryption/networking in the app. |
| Mission 1 includes Shinies, stash win, water fail, and procedural sound (beyond strict PLAN “no goals/sound”) | Nicholas: “this isn’t a game” — next build must feel like a real fun game. PLAN M1 mechanics (Pounce, Tail Swing A/B, Belly Flop, coyote, buffer, Mask Mode) still required. |
| Placeholder raccoon via SpriteKit shapes; no Sly Cooper cane/top-hat/blue-gold | DESIGN.md visual distinctness. |

## 2026-11-14 — Name: Trash Panda

| Decision | Reason |
| --- | --- |
| The game is **Trash Panda**; working title **Trash Panda Heist** until App Store / USPTO availability is confirmed | Nicholas named it. Replaces the prior shortlist. |
| `ProductIdentity.displayTitle` holds the working title until availability flips it to Trash Panda | Single user-facing title constant; MAGPIE stays in code identifiers. |
| Open questions remaining: Trash Panda availability; sell masks directly; no Shinies packs at soft launch; Crew Pass rename | Same as design open questions minus “pick from shortlist.” |

## 2026-11-14 — Trash Panda Heist design approved (missions 1–10)

| Decision | Reason |
| --- | --- |
| Product theme is raccoon neon-city heist per approved *Trash Panda Heist: Game Plan v1* | Nicholas approved the canvas design. Captured in `docs/DESIGN.md`; Part 3 missions 1–10 in `docs/PLAN.md` retargeted. |
| Hero moves: Pounce, Belly Flop, Tail Swing (replaces glide; A/B in M1), Mask Mode at combo x5 | Design v1. Mask Mode is the shareable in-run moment. |
| Villain **MOP**; free the captured raccoon crew; rob robots/corp only | Design v1 story spine. |
| Glossary: Shinies, Stash Chute, The Den, Bagged, Sweepbots…, Junk Gadgets, Neon Docks / Glow Market / Arcade Row / Spotless Tower, MOP Safe Rooms | Replaces bird/toy-city placeholder terms without renaming code modules. |
| Keep hero visually distinct from Sony’s Sly Cooper; mascot needs attorney review | Legal / originality. No cane, no top-hat thief look, no blue/gold palette. |
| Codename **MAGPIE** stays in code identifiers; user-facing title only in `ProductIdentity.displayTitle` | Avoid scattered title strings. Superseded on the name itself by “Name: Trash Panda” above. |
| Open questions for Nicholas (not decided): Trash Panda availability; sell masks directly; no Shinies packs at soft launch; rename Golden Ticket → Crew Pass | Tracked in DESIGN.md / BACKLOG; Mission 8+ must not ship contested SKUs until answered. |
| Mission 0 unchanged (follow-square); do not start Mission 1 until Fire Fox posts **APPROVED M0** | Plan rule 12 / mission discipline. |

## 2026-11-14 — Theme pivot noted (pre-approval)

| Decision | Reason |
| --- | --- |
| Theme → raccoon (“trash panda”), night neon city heist; final name TBD — backlog until design approved | Early Nicholas direction. Superseded by design-approval decision above once canvas landed. |

## 2026-11-14 — ASC app record created

| Decision | Reason |
| --- | --- |
| Smoke sims: prefer single-screen iPhone; pass `--display` to simctl | `iPhone Duo` on xcode-27 exposed two LCDs; screenshot failed with “Cannot choose between 2 displays”. |
| Store name **Magpie Toy City** (Apple ID `6834947645`, SKU `magpie-001`) | “MAGPIE” was taken in App Store Connect; bundle id stays `com.cinderandcrown.magpie`. Codename MAGPIE unchanged. Display title constant may diverge until rename mission. |

## 2026-11-14 — AGENTS.md adapted to real setup

`docs/PLAN.md` remains the process source of truth (now theme-amended). `AGENTS.md` keeps the Master Brief’s pillars, originality rules, budgets, and feel/juice bar; process/hosting roles match Cursor + Fire Fox.

| Adaptation | Reason |
| --- | --- |
| Cursor **cloud agents on Linux VMs** are the engineers (not Grok on Nicholas’s Windows PC) | That is how Magpie is actually built; drop local-PC toolchain assumptions. |
| **Fire Fox** coordinates, merges PRs, and pushes TestFlight / approval tags | Nicholas plays builds and says APPROVED only; agents do not self-merge or self-tag. |
| GameCore `swift test` on the **agent Linux VM** + CI Linux job (not “this PC”) | Agents have Swift on the VM; they cannot compile the iPhone app there. |
| Signing: **ASC API key** path proven on `phoenix-fox`; **no fastlane match** unless cloud signing fails | Secrets already work; avoid a second cert pipeline until needed. |
| Checkpoint tagging is **Fire Fox’s** job; agents report build numbers after upload | Matches ownership split; Mission 0 still uploads only on `testflight/*`. |
| TestFlight PR check: **skip altool validate** when ASC app record is missing | Archive + cloud sign already proved; validate/upload need the app record. (App record now exists; validate is green.) |
| Explicit **do not sandbag feel/juice** | Nicholas wants a badass game; process adaptations must not lower the quality bar. |
| Simulator ≠ on-phone for feel sign-off | Plan already implied this; AGENTS.md states it as a hard rule. |

## 2026-11-14 — Mission 0 bootstrap

| Decision | Reason |
| --- | --- |
| Use **XcodeGen** `project.yml` (not Tuist, not a hand-made `.xcodeproj`) | Plan §11: generate on the runner from text; never commit a hand-made project. |
| CI Mac runner label: **`xcode-27`** (standard, not `xcode-27-xlarge`) | Plan requires `xcode-27`. Verified GA on 2026-10-15 ([GitHub changelog](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/)). |
| Modules: **GameCore**, **GameRender**, **Services**, plus app target **Magpie** (GameApp) | Plan §11 module table. |
| Mission 0 UI: SwiftUI `SpriteView` hosting a SpriteKit scene; one finger-following square; FPS label in `DEBUG` only | Plan Mission 0 build item 4. No hero art, no game rules. |
| No Apache-2.0 / no reuse license; **NOTICE** is all rights reserved only | Plan §11 Security / Part 1 legal: “Add no license that grants reuse.” |
| TestFlight workflow trigger: pushed tags matching `testflight/*` | Proves the upload loop without implying Mission 0 is approved. Agents do not push tags. |
| Signing: App Store Connect API key + Xcode cloud-managed / automatic signing first | Plan Mission 0 item 6; same proven approach as phoenix-fox. |
| `ITSAppUsesNonExemptEncryption` **not** written into Info.plist yet | Proposed `false` for Nicholas’s confirmation (export-compliance question). Not treated as approved. |
| Linux GameCore job on **ubuntu-24.04** (not `ubuntu-latest`) | Swift 6.2 RELEASE tarball is built for Ubuntu 24.04; `ubuntu-latest` is 26.04 and failed with missing `libxml2.so.2`. |
| Private content repo / deploy key deferred | Not needed until paid assets or district maps land; documented in OWNER_SETUP.md. |
