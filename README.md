# The Neon City Bandit

Original iPhone game by Nicholas Will / Cinder and Crown LLC: a cocky masked raccoon on neon-city heists.

**All rights reserved** — see `NOTICE`. No reuse license is granted.

- **Plan:** [`docs/PLAN.md`](docs/PLAN.md)
- **Agent brief:** [`AGENTS.md`](AGENTS.md)
- **Owner setup (remaining):** [`OWNER_SETUP.md`](OWNER_SETUP.md)
- **Bundle ID:** `com.cinderandcrown.magpie` · **Team:** `GDNRT9DJ58` (unchanged engineering identifiers)
- **Stack:** Swift 6 · SpriteKit + SwiftUI · iPhone portrait · iOS 17+
- **Repo:** `cinderandcrown/neon-city-bandit`

## Mission 0

Prove the loop: push → GitHub `xcode-27` build → smoke screenshots/video → (owner-tagged) TestFlight → phone.

Placeholder UI only: a yellow square that follows the finger, plus an FPS counter in debug builds. No game code.

## Layout

| Path | Role |
| --- | --- |
| `Packages/GameCore` | Pure Swift rules/sim (Foundation only) |
| `Packages/GameRender` | SpriteKit drawing |
| `Packages/Services` | Store, Game Center, clips, etc. (protocols) |
| `Magpie/` | SwiftUI app shell (Xcode target name unchanged) |
| `project.yml` | XcodeGen source of truth |

```bash
make test-core          # Linux or Mac
make generate           # Mac: xcodegen generate && open Magpie.xcodeproj
```

## CI

- Linux: GameCore (+ Services / GameRender Linux-safe) tests
- `xcode-27`: generate, build, test, 3 screenshots + 30s smoke video
- TestFlight: tags `testflight/*` only; fork-safe; no `.ipa` artifacts; no `pull_request_target`
