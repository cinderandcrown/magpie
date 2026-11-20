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
/// 1. Active library set (`ArtLibrary.libraryRoot` / `sprites/active_set.json`) —
///    `<root>/<pack>/<action>/NN.png` (256×256 approved sheets)
/// 2. `sprites/spriterrific_ready/<character>/<action>/` — current shipping sheets
/// 3. Procedural / AssetKey placeholders when nothing is on disk
///
/// **Whole-set swap:** drop an archive into `sprites/library_sets/<name>/` mirroring
/// `bandit|mop_bot|mop_9000_boss/<anim>/01.png…`, then either:
/// - write `sprites/active_set.json` → `{ "root": "sprites/library_sets/<name>" }`, or
/// - call `ArtLibrary.activateSet("sprites/library_sets/<name>")`.
/// Replacing files in-place under `sprites/library/` also works — call `reload()`.
@MainActor
public enum ArtLibrary {
    /// Pointer file under Generated — swap sets without a code change.
    public static let activeSetPointerRelative = "sprites/active_set"

    /// Shared raccoon bandit (goggles, cyan cables, magenta-trim hoodie).
    /// Nicholas approved the official character sheet (hero/side/pounce/victory + exprs).
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
        /// Character-sheet expressions (incoming 256² archive).
        case expressionCheer = "expr_cheer"
        case expressionDetermined = "expr_determined"
        case expressionPanic = "expr_panic"
        case expressionGameOver = "expr_game_over"

        /// Spriterrific / legacy folder names tried when the library slot is empty.
        public var fallbackActions: [String] {
            switch self {
            case .pounce: return ["pounce", "attack"]
            case .victory: return ["victory", "idle_front", "idle"]
            case .expressionHappy: return ["expr_happy", "expr_cheer", "idle_front", "idle"]
            case .expressionCheer: return ["expr_cheer", "expr_happy", "expr_smug", "idle_front"]
            case .expressionWorried: return ["expr_worried", "expr_panic", "hurt", "idle"]
            case .expressionPanic: return ["expr_panic", "expr_worried", "hurt", "idle"]
            case .expressionSmug: return ["expr_smug", "expr_cheer", "idle_front", "idle"]
            case .expressionDetermined: return ["expr_determined", "idle_front", "idle"]
            case .expressionGameOver: return ["expr_game_over", "death", "hurt", "idle"]
            case .idleFront: return ["idle_front", "idle"]
            case .pickUp: return ["pick_up"]
            default: return [rawValue]
            }
        }
    }

    public enum CharacterPack: String, CaseIterable, Sendable {
        case bandit
        case mopBot = "mop_bot"
        case mopBrute = "mop_brute"
        case mopFlyer = "mop_flyer"
        case mopMiniBoss = "mop_mini_boss"
        case mop9000 = "mop_9000_boss"
    }

    /// Current library root (same as `SpriteCycles.libraryRoot`).
    public static var libraryRoot: String { SpriteCycles.libraryRoot }

    /// Activate a whole sprite set by folder under `Generated/`.
    /// Example: `activateSet("sprites/library_sets/approved_256")`.
    @discardableResult
    public static func activateSet(_ relativeRoot: String) -> Bool {
        let trimmed = relativeRoot.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return false }
        SpriteCycles.setLibraryRoot(trimmed)
        return true
    }

    /// Re-read `sprites/active_set.json` (if any) and flush caches.
    public static func reload() {
        applyActiveSetFromDisk()
        SpriteCycles.clearCache()
        applyActiveSetFromDisk()
    }

    /// Apply `sprites/active_set.json` → `{ "root": "sprites/library_sets/…" }`.
    /// Safe to call repeatedly; no-ops when the pointer is missing.
    /// Does not flush caches (callers that need a hot-swap use `activateSet` / `reload`).
    public static func applyActiveSetFromDisk() {
        guard let url = AssetManifest.fileURLPublic(
            relative: activeSetPointerRelative,
            extensions: ["json"]
        ),
        let data = try? Data(contentsOf: url),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        let root = (obj["root"] as? String)
            ?? (obj["libraryRoot"] as? String)
            ?? (obj["set"] as? String).map { "sprites/library_sets/\($0)" }
        guard let root, !root.isEmpty else { return }
        SpriteCycles.applyLibraryRoot(root)
    }

    /// Relative roots under `Generated/`, preferred → fallback.
    public static func spriteRoots(pack: CharacterPack) -> [String] {
        let lib = SpriteCycles.libraryRoot
        switch pack {
        case .bandit:
            return [
                "\(lib)/bandit",
                "sprites/library/bandit",
                "sprites/spriterrific_ready/bandit",
            ]
        case .mopBot:
            return [
                "\(lib)/mop_bot",
                "sprites/library/mop_bot",
                "sprites/spriterrific_ready/mop_bot",
            ]
        case .mopBrute, .mopFlyer, .mopMiniBoss:
            return [
                "\(lib)/\(pack.rawValue)",
                "sprites/library/\(pack.rawValue)",
                "\(lib)/mop_bot",
                "sprites/library/mop_bot",
                "sprites/spriterrific_ready/mop_bot",
            ]
        case .mop9000:
            return [
                "\(lib)/mop_9000_boss",
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

    /// Resolve a MOP pack action through the active library set.
    public static func mopCycle(pack: CharacterPack, action: String) -> SpriteCycle? {
        let character: String
        switch pack {
        case .bandit: character = "bandit"
        case .mopBot, .mopBrute, .mopFlyer, .mopMiniBoss: character = pack.rawValue
        case .mop9000: character = "mop_9000_boss"
        }
        if let c = SpriteCycles.cycle(character: character, action: action, preferLibrary: true) {
            return c
        }
        // Brute / flyer / mini-boss fall back to mop_bot frames.
        if pack != .mopBot && pack != .mop9000 && pack != .bandit {
            return SpriteCycles.cycle(character: "mop_bot", action: action, preferLibrary: true)
        }
        return nil
    }

    /// Higgsfield art folder under `backgrounds/districts/` / `sprites/tiles_district/`.
    /// Heist 1 (Neon Docks) → downtown; heists 2–3 → docks; MOP-9000 finale → factory.
    public static func artFolder(for district: DistrictID) -> String {
        switch district {
        case .neonDocks: return "downtown"
        case .arcadeRow, .rooftops: return "docks"
        case .sewerGrid: return "factory"
        }
    }

    /// District parallax plates. Missing files fall back to the classic skyline pack.
    public static func districtLayer(
        _ district: DistrictID,
        layer: DistrictParallaxLayer,
        height: CGFloat,
        maxPixel: CGFloat = 960
    ) -> SKSpriteNode? {
        let folder = artFolder(for: district)
        // Prefer art-folder slug (downtown/docks/factory), then DistrictID rawValue.
        for slug in [folder, district.rawValue] {
            let rel = "backgrounds/districts/\(slug)/\(layer.rawValue)"
            if let tex = ArtCatalog.downsampledTexture(relative: rel, maxPixel: maxPixel) {
                let node = SKSpriteNode(texture: tex)
                fitHeight(node, height: height)
                node.name = "parallax_\(layer.rawValue)"
                return node
            }
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

    /// Platform / crate / ledge / vent / ladder from the district tile pack.
    public static func districtTileTexture(
        _ district: DistrictID,
        name: String,
        maxPixel: CGFloat = 256
    ) -> SKTexture? {
        let folder = artFolder(for: district)
        for slug in [folder, district.rawValue] {
            let rel = "sprites/tiles_district/\(slug)/\(name)"
            if let tex = ArtCatalog.downsampledTexture(relative: rel, maxPixel: maxPixel) {
                tex.filteringMode = .nearest
                return tex
            }
        }
        return nil
    }

    public static func districtDecorTextures(_ district: DistrictID) -> [SKTexture] {
        ["crate", "vent", "ladder", "ledge", "rooftop", "fire-escape"].compactMap {
            districtTileTexture(district, name: $0, maxPixel: 192)
        }
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
