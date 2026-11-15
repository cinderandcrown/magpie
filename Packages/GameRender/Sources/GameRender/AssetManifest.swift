// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Named keys for art/audio. Fire Fox drops files under `Assets/Generated/`
/// (see `docs/ASSETS.md` on `assets/mission-1`). Placeholders fill gaps until merge.
public enum AssetKey: String, CaseIterable, Sendable {
    // Bandit frames
    case raccoonIdle0 = "raccoon_idle_0"
    case raccoonRun0 = "raccoon_run_0"
    case raccoonRun1 = "raccoon_run_1"
    case raccoonJump0 = "raccoon_jump_0"
    case raccoonFall0 = "raccoon_fall_0"
    case raccoonPounce0 = "raccoon_pounce_0"

    // Enemies / pickups
    case mopIdle0 = "mop_idle_0"
    case mopPatrol0 = "mop_patrol_0"
    case shiny0 = "shiny_0"

    // World
    case parallaxSky = "parallax_sky"
    case parallaxSkyline = "parallax_skyline"
    case parallaxSigns = "parallax_signs"
    case tileGround = "tile_ground"
    case tileWall = "tile_wall"
    case rain = "rain"
    case logo = "logo"

    // SFX
    case sfxJump = "jump"
    case sfxLand = "land"
    case sfxCollectShiny = "collect_shiny"
    case sfxPounce = "pounce"
    case sfxHit = "hit"
    case sfxWin = "win"
    case sfxFail = "fail"
    case sfxMaskMode = "mask_mode"

    // Music
    case musicHeistLoop = "heist_loop"
}

public struct AssetManifest: Sendable {
    public static let shared = AssetManifest()

    /// Bundle that may contain Fire Fox assets after merge (`Assets/Generated`).
    public var generatedSubdirectory = "Generated"

    public func imageName(for key: AssetKey) -> String { key.rawValue }

    public func soundFileName(for key: AssetKey) -> String {
        "\(key.rawValue).wav"
    }

    public func musicFileName(for key: AssetKey) -> String {
        "\(key.rawValue).m4a"
    }

    /// Resolves a URL from the app bundle if Fire Fox (or placeholder) files are present.
    public func url(for key: AssetKey, ext: String, in bundle: Bundle = .main) -> URL? {
        if let u = bundle.url(forResource: key.rawValue, withExtension: ext, subdirectory: generatedSubdirectory) {
            return u
        }
        if let u = bundle.url(forResource: key.rawValue, withExtension: ext, subdirectory: "Assets/Generated") {
            return u
        }
        return bundle.url(forResource: key.rawValue, withExtension: ext)
    }
}
