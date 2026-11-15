// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Logical keys → Fire Fox paths under `Assets/Generated/` (see `docs/ASSETS.md`).
public enum AssetKey: String, CaseIterable, Sendable {
    // Raccoon
    case raccoonIdle = "raccoon/idle"
    case raccoonRun1 = "raccoon/run_01"
    case raccoonRun2 = "raccoon/run_02"
    case raccoonRun3 = "raccoon/run_03"
    case raccoonRun4 = "raccoon/run_04"
    case raccoonRun5 = "raccoon/run_05"
    case raccoonRun6 = "raccoon/run_06"
    case raccoonJump = "raccoon/jump"
    case raccoonFall = "raccoon/fall"
    case raccoonPounce = "raccoon/pounce"
    case raccoonBellyFlop = "raccoon/belly_flop"
    case raccoonTailSwing = "raccoon/tail_swing"
    case raccoonMaskMode = "raccoon/mask_mode"

    // MOP
    case mopIdle = "mop/idle"
    case mopPatrol = "mop/patrol"
    case mopAlert = "mop/alert"

    // Shinies
    case shiny1 = "shiny/shiny_01"
    case shiny2 = "shiny/shiny_02"
    case shiny3 = "shiny/shiny_03"
    case shiny4 = "shiny/shiny_04"

    // World
    case farSkyline = "far_skyline"
    case midBuildings = "mid_buildings"
    case nearRooftops = "near_rooftops"
    case rainOverlay = "rain_overlay"
    case logo = "logo_trash_panda"

    // Audio SFX
    case sfxJump = "jump"
    case sfxLand = "land"
    case sfxCollectShiny = "collect_shiny"
    case sfxPounce = "pounce"
    case sfxBellyFlop = "belly_flop"
    case sfxTailSwing = "tail_swing"
    case sfxMopAlert = "mop_alert"
    case sfxMopHit = "mop_hit"
    case sfxPlayerHit = "player_hit"
    case sfxMaskModeOn = "mask_mode_on"
    case sfxCheckpoint = "checkpoint"
    case sfxWin = "win"
    case sfxFail = "fail"
    case sfxUITap = "ui_tap"

    // Music
    case musicLevelLoop = "level_loop"
    case musicMaskLayer = "mask_mode_layer"
    case musicTitleSting = "title_sting"
}

public enum AssetManifest {
    public static let runCycle: [AssetKey] = [
        .raccoonRun1, .raccoonRun2, .raccoonRun3, .raccoonRun4, .raccoonRun5, .raccoonRun6,
    ]
    public static let shinyFrames: [AssetKey] = [.shiny1, .shiny2, .shiny3, .shiny4]

    /// Relative path under the Generated folder (no scale suffix, no extension).
    public static func relativePath(for key: AssetKey) -> String {
        switch key {
        case .raccoonIdle, .raccoonRun1, .raccoonRun2, .raccoonRun3, .raccoonRun4, .raccoonRun5, .raccoonRun6,
             .raccoonJump, .raccoonFall, .raccoonPounce, .raccoonBellyFlop, .raccoonTailSwing, .raccoonMaskMode:
            return "sprites/\(key.rawValue)"
        case .mopIdle, .mopPatrol, .mopAlert:
            return "sprites/\(key.rawValue)"
        case .shiny1, .shiny2, .shiny3, .shiny4:
            return "sprites/\(key.rawValue)"
        case .farSkyline, .midBuildings, .nearRooftops, .rainOverlay:
            return "backgrounds/\(key.rawValue)"
        case .logo:
            return "ui/\(key.rawValue)"
        case .sfxJump, .sfxLand, .sfxCollectShiny, .sfxPounce, .sfxBellyFlop, .sfxTailSwing,
             .sfxMopAlert, .sfxMopHit, .sfxPlayerHit, .sfxMaskModeOn, .sfxCheckpoint, .sfxWin, .sfxFail, .sfxUITap:
            return "audio/\(key.rawValue)"
        case .musicLevelLoop, .musicMaskLayer, .musicTitleSting:
            return "audio/\(key.rawValue)"
        }
    }

    public static func audioURL(_ key: AssetKey, bundle: Bundle = .main) -> URL? {
        let rel = relativePath(for: key)
        let name = (rel as NSString).lastPathComponent
        let dir = (rel as NSString).deletingLastPathComponent
        let exts: [String]
        switch key {
        case .musicLevelLoop, .musicMaskLayer, .musicTitleSting:
            exts = ["m4a", "wav", "caf"]
        default:
            exts = ["wav", "caf", "m4a"]
        }
        for root in ["Generated", "Assets/Generated", ""] {
            let sub = root.isEmpty ? dir : (dir.isEmpty ? root : "\(root)/\(dir)")
            for ext in exts {
                if let u = bundle.url(forResource: name, withExtension: ext, subdirectory: sub.isEmpty ? nil : sub) {
                    return u
                }
            }
        }
        return nil
    }

    #if canImport(UIKit)
    /// Loads @2x/@3x preferred for a 64pt sprite (masters are 256; @2x=128, @3x=192).
    /// Prefer @2x then @3x without touching UIScreen (keeps this nonisolated / Sendable-safe).
    public static func image(for key: AssetKey, bundle: Bundle = .main) -> UIImage? {
        let rel = relativePath(for: key)
        let base = (rel as NSString).lastPathComponent
        let dir = (rel as NSString).deletingLastPathComponent
        let candidates: [(suffix: String, scale: CGFloat)] = [("@2x", 2), ("@3x", 3), ("", 1)]
        for root in ["Generated", "Assets/Generated"] {
            let sub = dir.isEmpty ? root : "\(root)/\(dir)"
            for c in candidates {
                let name = base + c.suffix
                if let u = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
                   let data = try? Data(contentsOf: u),
                   let img = UIImage(data: data, scale: c.scale) {
                    return img
                }
            }
        }
        return nil
    }
    #endif
}
