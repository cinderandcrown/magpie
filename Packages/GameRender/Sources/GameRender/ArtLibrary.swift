// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import Foundation
import SpriteKit
import UIKit
import GameCore

/// Drop-in art library for the shared cyberpunk raccoon (Trash Stack + Neon City Bandit)
/// and NCB-specific packs (MOPs, districts, loot, hideout, map, story).
///
/// Search order (first hit wins):
/// 1. `sprites/library/<pack>/<action>/` — Higgsfield shared / NCB packs (preferred)
/// 2. `sprites/spriterrific_ready/<character>/<action>/` — current shipping sheets
/// 3. Procedural / AssetKey placeholders when nothing is on disk
///
/// Drop approved Higgsfield frames into `Assets/Generated/sprites/library/` using the
/// folder names in `BanditAction` / `MopPack` / `DistrictParallax`. No code change needed.
@MainActor
public enum ArtLibrary {
    /// Shared raccoon bandit (goggles, cyan cables, magenta-trim hoodie).
    public enum BanditAction: String, CaseIterable, Sendable {
        case idle
        case idleFront = "idle_front"
        case walk
        case run
        case jump
        case pounce
        case hurt
        case death
        case victory
        case pickUp = "pick_up"
        case expressionHappy = "expr_happy"
        case expressionWorried = "expr_worried"
        case expressionSmug = "expr_smug"

        /// Spriterrific / legacy folder names tried when the library slot is empty.
        public var fallbackActions: [String] {
            switch self {
            case .pounce: return ["pounce", "attack"]
            case .victory: return ["victory", "idle_front", "idle"]
            case .expressionHappy: return ["expr_happy", "idle_front", "idle"]
            case .expressionWorried: return ["expr_worried", "hurt", "idle"]
            case .expressionSmug: return ["expr_smug", "idle_front", "idle"]
            case .idleFront: return ["idle_front", "idle"]
            case .pickUp: return ["pick_up"]
            default: return [rawValue]
            }
        }
    }

    public enum CharacterPack: String, Sendable {
        case bandit
        case mopBot = "mop_bot"
        case mopBrute = "mop_brute"
        case mopFlyer = "mop_flyer"
        case mopMiniBoss = "mop_mini_boss"
        case mop9000 = "mop_9000_boss"
    }

    /// Relative roots under `Generated/`, preferred → fallback.
    public static func spriteRoots(pack: CharacterPack) -> [String] {
        switch pack {
        case .bandit:
            return [
                "sprites/library/bandit",
                "sprites/spriterrific_ready/bandit",
            ]
        case .mopBot:
            return [
                "sprites/library/mop_bot",
                "sprites/spriterrific_ready/mop_bot",
            ]
        case .mopBrute, .mopFlyer, .mopMiniBoss:
            return [
                "sprites/library/\(pack.rawValue)",
                "sprites/library/mop_bot",
                "sprites/spriterrific_ready/mop_bot",
            ]
        case .mop9000:
            return [
                "sprites/library/mop_9000_boss",
                "sprites/spriterrific_ready/mop_9000_boss",
            ]
        }
    }

    /// Resolve a bandit action cycle through the library → spriterrific chain.
    public static func banditCycle(_ action: BanditAction) -> SpriteCycle? {
        for name in action.fallbackActions {
            if let c = SpriteCycles.cycle(character: "bandit", action: name, preferLibrary: true) {
                return c
            }
        }
        return nil
    }

    /// District parallax plates. Missing files fall back to the classic skyline pack.
    public static func districtLayer(
        _ district: DistrictID,
        layer: DistrictParallaxLayer,
        height: CGFloat,
        maxPixel: CGFloat = 960
    ) -> SKSpriteNode? {
        let slug = district.rawValue
        let rel = "backgrounds/districts/\(slug)/\(layer.rawValue)"
        if let tex = ArtCatalog.downsampledTexture(relative: rel, maxPixel: maxPixel) {
            let node = SKSpriteNode(texture: tex)
            fitHeight(node, height: height)
            node.name = "parallax_\(layer.rawValue)"
            return node
        }
        // Placeholder / shipping fallback.
        let key: AssetKey
        switch layer {
        case .far: key = .farSkyline
        case .mid: key = .midBuildings
        case .near: key = .nearRooftops
        }
        return ArtCatalog.background(key, height: height, maxPixel: maxPixel)
    }

    private static func fitHeight(_ node: SKSpriteNode, height: CGFloat) {
        guard let tex = node.texture else { return }
        let sz = tex.size()
        guard sz.height > 1 else { return }
        let scale = height / sz.height
        node.size = CGSize(width: sz.width * scale, height: height)
    }
}

public enum DistrictParallaxLayer: String, Sendable {
    case far
    case mid
    case near
}
#endif
