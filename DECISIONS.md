# Decisions

Every choice that changes the plan, with the reason. Newest first.

## 2026-11-14 — Mission 0 bootstrap

| Decision | Reason |
| --- | --- |
| Use **XcodeGen** `project.yml` (not Tuist, not a hand-made `.xcodeproj`) | Plan §11: generate on the runner from text; never commit a hand-made project. |
| CI Mac runner label: **`xcode-27`** (standard, not `xcode-27-xlarge`) | Plan requires `xcode-27`. Verified GA on 2026-10-15 ([GitHub changelog](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/)). Sibling phoenix-fox uses `macos-26` / Xcode 26.6; Magpie follows the plan’s newer label. |
| Modules: **GameCore**, **GameRender**, **Services**, plus app target **Magpie** (GameApp) | Plan §11 module table. |
| Mission 0 UI: SwiftUI `SpriteView` hosting a SpriteKit scene; one finger-following square; FPS label in `DEBUG` only | Plan Mission 0 build item 4. No bird, no game rules. |
| No Apache-2.0 / no reuse license; **NOTICE** is all rights reserved only | Plan §11 Security / Part 1 legal: “Add no license that grants reuse.” Plan wins over the earlier brief. |
| TestFlight workflow trigger: pushed tags matching `testflight/*` | Proves the upload loop without implying Mission 0 is approved (`m00-approved` waits for APPROVED). Agents do not push tags. |
| Signing: App Store Connect API key + Xcode cloud-managed / automatic signing first | Plan Mission 0 item 6; same proven approach as phoenix-fox. Fastlane match only if that fails. |
| `ITSAppUsesNonExemptEncryption` **not** written into Info.plist yet | Proposed `false` for Nicholas’s confirmation (export-compliance question). Not treated as approved. |
| Private content repo / deploy key deferred | Not needed until paid assets or Harbor maps land; documented in OWNER_SETUP.md. |
