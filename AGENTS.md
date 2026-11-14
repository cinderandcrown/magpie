# MAGPIE — agent engineering standard

This repository is the public code and CI for **MAGPIE**, an original iPhone game by Nicholas Will / Cinder and Crown LLC. Concept: a small bird loose in a big toy city. Genre inspiration is welcome; **never copy IP** (no Nintendo or Rockstar names, characters, art, music, maps, or look-alike screens).

## Keep existing code

- Prefer small, additive changes. Do not rewrite working modules “for cleanliness.”
- Match the style and structure already in the tree. If a pattern exists (XcodeGen, scripts, report format), extend it.
- Do not delete or replace generated workflow approaches that already ship builds to TestFlight unless the change is required and tested.

## Tests for every feature

- Every behavior change needs an automated test in the same change.
- Pure rules and math live in `Packages/GameRules` and must pass `swift test` on **Linux and macOS**.
- Apple-only UI wiring is covered by the iOS unit-test target and by CI’s simulator screenshot artifact.
- Script helpers under `scripts/` have Python unit tests that CI runs on Ubuntu.

## Report format

After meaningful work, report in this exact shape:

```
Outcome:
Changed:
Compatibility:
Verified:
Risks:
Next:
Git:
```

- **Verified** must say whether checks ran on a **physical iPhone**, on the **simulator**, or only as **unit/script tests**. Simulator results never count as on-phone results.
- **Git** must name the branch, commit, and PR (if any).

## Apple APIs — verify before use

Before introducing or changing calls into **SpriteKit**, **GameKit**, **ReplayKit**, or **StoreKit**, read the **current** Apple documentation for that API and confirm the symbols, availability, and recommended usage still match. Do not copy stale samples from memory. Note the docs you checked in the change or report when the API surface is non-trivial.

Mission 0 uses SpriteKit only: `SKView`, `SKScene`, `SKSpriteNode`, `SKLabelNode`, `SKAction`, and `UIResponder` touch delivery via `touchesBegan(_:with:)`. Confirm against Apple’s SpriteKit docs if you extend that set.

## Secrets and paid assets

- Never commit secrets (`.p8` keys, tokens, `Config.xcconfig` with real team overrides that hold secrets).
- Never commit paid or final art, audio, or levels. Placeholder geometrics and generated icons in this repo are temporary. Final art, audio, and levels will live in a **private** repo later.
- Repo secrets for signing live in GitHub Actions only: `APPLE_TEAM_ID`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8`.

## Artifacts and distribution

- CI may upload a **simulator screenshot** artifact.
- **Never** publish a `.ipa` (or `.xcarchive`) as a GitHub Actions artifact. Signed apps stay on the runner, upload to TestFlight, then are deleted.
- Do not push `testflight/*` tags from agents; the owner tags TestFlight uploads.

## Project generation

- The Xcode project is generated with **XcodeGen** from `project.yml` (not hand-edited `pbxproj`, not Tuist).
- **Why XcodeGen:** the sibling `cinderandcrown/phoenix-fox` already uses it successfully for App Store Connect API signing and TestFlight; Magpie stays in the same YAML-driven model; Tuist adds a heavier binary and project-state model Magpie does not need for a single iOS app + local Swift package.
- Run `make generate` (or `xcodegen generate`) after changing `project.yml` or source layout. CI regenerates before every build.

## CI runners

- Use the standard free GitHub-hosted **`macos-26`** image with **Xcode 26.6** (`DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`), matching phoenix-fox.
- **Never** use `macos-*-xlarge` or other larger/paid runner labels.

## Platforms

- Product target: **iPhone only** (no iPad idiom, no Mac Catalyst).
- Bundle ID: `com.cinderandcrown.magpie`
- Team: `GDNRT9DJ58`
