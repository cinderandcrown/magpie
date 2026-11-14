# MAGPIE

An original iPhone game by Nicholas Will / **Cinder and Crown LLC**: a small bird loose in a big toy city.

- **Platform:** iPhone only (portrait, one-thumb)
- **Stack:** Swift + SpriteKit
- **Bundle ID:** `com.cinderandcrown.magpie`
- **Team:** `GDNRT9DJ58`
- **License:** Apache-2.0 (see `LICENSE` and `NOTICE`)

Genre ideas are welcome. **Never** copy Nintendo or Rockstar IP (names, characters, art, music, maps, or look-alike screens).

## Mission 0

Prove the full loop: push → cloud build/test → TestFlight → phone.

This tree ships a **placeholder** scene only: title, build-number label, and a bird sprite you tap to hop. No full gameplay yet.

## Generate the Xcode project

**XcodeGen** (not Tuist) — same approach as `cinderandcrown/phoenix-fox`, one YAML source of truth, no Tuist project state.

```bash
brew install xcodegen
make generate   # or: xcodegen generate
make open
```

## Packages

`Packages/GameRules` is a pure Swift package (run rules, hop math, build label). Tests run on Linux and macOS:

```bash
make test-rules
```

## CI

- **CI** (every push/PR): Ubuntu script tests + Linux `swift test`, macOS `macos-26` / Xcode 26.6 simulator build, unit tests, **simulator screenshot** artifact.
- **TestFlight** (only `testflight/*` tags): App Store Connect API key automatic signing, validate, upload. Fork-safe. Never publishes a `.ipa` artifact.
- Do **not** use xlarge runners.

Owner tags TestFlight uploads (agents do not push tags):

```bash
git tag testflight/2026-11-14
git push origin testflight/2026-11-14
```

## Agent standard

See [`AGENTS.md`](AGENTS.md).
