// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Logical keys → Fire Fox paths under `Generated/` (see `docs/ASSETS.md`).
public enum AssetKey: String, CaseIterable, Sendable {
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

    case mopIdle = "mop/idle"
    case mopPatrol = "mop/patrol"
    case mopAlert = "mop/alert"

    case shiny1 = "shiny/shiny_01"
    case shiny2 = "shiny/shiny_02"
    case shiny3 = "shiny/shiny_03"
    case shiny4 = "shiny/shiny_04"

    case farSkyline = "far_skyline"
    case midBuildings = "mid_buildings"
    case nearRooftops = "near_rooftops"
    case rainOverlay = "rain_overlay"
    case logo = "logo_trash_panda"

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

    case musicLevelLoop = "level_loop"
    case musicMaskLayer = "mask_mode_layer"
    case musicTitleSting = "title_sting"
}

public enum AssetManifest {
    public static let runCycle: [AssetKey] = [
        .raccoonRun1, .raccoonRun2, .raccoonRun3, .raccoonRun4, .raccoonRun5, .raccoonRun6,
    ]
    public static let shinyFrames: [AssetKey] = [.shiny1, .shiny2, .shiny3, .shiny4]

    public static func relativePath(for key: AssetKey) -> String {
        switch key {
        case .raccoonIdle, .raccoonRun1, .raccoonRun2, .raccoonRun3, .raccoonRun4, .raccoonRun5, .raccoonRun6,
             .raccoonJump, .raccoonFall, .raccoonPounce, .raccoonBellyFlop, .raccoonTailSwing, .raccoonMaskMode,
             .mopIdle, .mopPatrol, .mopAlert, .shiny1, .shiny2, .shiny3, .shiny4:
            return "sprites/\(key.rawValue)"
        case .farSkyline, .midBuildings, .nearRooftops, .rainOverlay:
            return "backgrounds/\(key.rawValue)"
        case .logo:
            return "ui/\(key.rawValue)"
        case .sfxJump, .sfxLand, .sfxCollectShiny, .sfxPounce, .sfxBellyFlop, .sfxTailSwing,
             .sfxMopAlert, .sfxMopHit, .sfxPlayerHit, .sfxMaskModeOn, .sfxCheckpoint, .sfxWin, .sfxFail, .sfxUITap,
             .musicLevelLoop, .musicMaskLayer, .musicTitleSting:
            return "audio/\(key.rawValue)"
        }
    }

    /// Roots of the Generated tree inside the app bundle (folder reference last path component).
    private static func generatedRoots(bundle: Bundle) -> [URL] {
        var roots: [URL] = []
        if let res = bundle.resourceURL {
            roots.append(res.appendingPathComponent("Generated", isDirectory: true))
            roots.append(res.appendingPathComponent("Assets/Generated", isDirectory: true))
        }
        if let direct = bundle.url(forResource: "Generated", withExtension: nil) {
            roots.append(direct)
        }
        return roots
    }

    private static func fileURL(relative: String, extensions: [String], bundle: Bundle) -> URL? {
        for root in generatedRoots(bundle: bundle) {
            for ext in extensions {
                let url = root.appendingPathComponent(relative).appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        // Fallback: Bundle API with subdirectory
        let name = (relative as NSString).lastPathComponent
        let dir = (relative as NSString).deletingLastPathComponent
        for rootName in ["Generated", "Assets/Generated"] {
            let sub = dir.isEmpty ? rootName : "\(rootName)/\(dir)"
            for ext in extensions {
                if let u = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
                    return u
                }
            }
        }
        return nil
    }

    /// Public wrapper for ArtCatalog / ImageIO loaders.
    public static func fileURLPublic(relative: String, extensions: [String], bundle: Bundle = .main) -> URL? {
        fileURL(relative: relative, extensions: extensions, bundle: bundle)
    }

    public static func audioURL(_ key: AssetKey, bundle: Bundle = .main) -> URL? {
        let rel = relativePath(for: key)
        let exts: [String]
        switch key {
        case .musicLevelLoop, .musicMaskLayer, .musicTitleSting:
            exts = ["m4a", "wav", "caf"]
        default:
            exts = ["wav", "caf", "m4a"]
        }
        return fileURL(relative: rel, extensions: exts, bundle: bundle)
    }

    #if canImport(UIKit)
    /// Prefer @2x (or preferScale) then other scales then master.
    public static func image(for key: AssetKey, bundle: Bundle = .main, preferScale: CGFloat = 2) -> UIImage? {
        let rel = relativePath(for: key)
        var candidates: [(suffix: String, scale: CGFloat)] = [("@2x", 2), ("@3x", 3), ("", 1)]
        if preferScale >= 2.5 {
            candidates = [("@3x", 3), ("@2x", 2), ("", 1)]
        } else if preferScale < 1.5 {
            candidates = [("", 1), ("@2x", 2), ("@3x", 3)]
        }
        for c in candidates {
            let path = rel + c.suffix
            if let url = fileURL(relative: path, extensions: ["png"], bundle: bundle),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data, scale: c.scale) {
                return img
            }
        }
        return nil
    }
    #endif
}
