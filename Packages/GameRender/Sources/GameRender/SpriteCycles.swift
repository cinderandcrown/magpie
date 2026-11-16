// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import Foundation
import SpriteKit
import UIKit

/// One Spriterrific action cycle (normalized frames under `sprites/spriterrific_ready/`).
public struct SpriteCycle: Sendable {
    public var textures: [SKTexture]
    public var fps: Double
    public var footY: Double
    /// Sheets face WEST; flip xScale when facing east/right.
    public var facesWest: Bool

    public var timePerFrame: TimeInterval {
        max(1.0 / max(fps, 1), 1.0 / 60.0)
    }

    public var footAnchorY: CGFloat {
        // footY is pixel row from top of 256 frame; SK anchor y is from bottom.
        let h = 256.0
        return CGFloat(max(0, min(1, (h - 1 - footY) / h)))
    }
}

@MainActor
public enum SpriteCycles {
    private static var cache: [String: SpriteCycle] = [:]
    private static var indexFoot: [String: Double] = [:]
    private static var didLoadIndex = false

    public static func cycle(character: String, action: String, maxFrames: Int = 64) -> SpriteCycle? {
        let key = "\(character)/\(action)"
        if let cached = cache[key] { return cached }
        loadIndexIfNeeded()
        let root = "sprites/spriterrific_ready/\(character)/\(action)"
        var textures: [SKTexture] = []
        for i in 1...maxFrames {
            let rel = String(format: "%@/%02d", root, i)
            guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                  let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { break }
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            textures.append(tex)
        }
        guard !textures.isEmpty else { return nil }
        var fps = 12.0
        var footY = indexFoot[character] ?? 227
        if let metaURL = AssetManifest.fileURLPublic(relative: "\(root)/meta", extensions: ["json"]),
           let data = try? Data(contentsOf: metaURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let f = obj["fps"] as? Double { fps = f }
            else if let f = obj["fps"] as? Int { fps = Double(f) }
            if let anchor = obj["anchor"] as? [String: Any], let y = anchor["y"] as? Double {
                footY = y
            } else if let anchor = obj["anchor"] as? [String: Any], let y = anchor["y"] as? Int {
                footY = Double(y)
            }
        }
        let cycle = SpriteCycle(textures: textures, fps: fps, footY: footY, facesWest: true)
        cache[key] = cycle
        return cycle
    }

    public static func bandit(_ action: String) -> SpriteCycle? {
        cycle(character: "bandit", action: action)
    }

    public static func mopBot(_ action: String) -> SpriteCycle? {
        cycle(character: "mop_bot", action: action)
    }

    public static func mop9000(_ action: String) -> SpriteCycle? {
        cycle(character: "mop_9000_boss", action: action)
    }

    /// Display size tuned so feet sit in the 32px tile ground art.
    public static let banditDisplaySize = CGSize(width: 72, height: 72)
    public static let mopDisplaySize = CGSize(width: 70, height: 70)
    public static let bossDisplaySize = CGSize(width: 140, height: 140)

    private static func loadIndexIfNeeded() {
        guard !didLoadIndex else { return }
        didLoadIndex = true
        guard let url = AssetManifest.fileURLPublic(relative: "sprites/spriterrific_ready/index", extensions: ["json"]),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chars = obj["characters"] as? [String: Any] else { return }
        for (name, raw) in chars {
            guard let info = raw as? [String: Any] else { continue }
            if let y = info["foot_y"] as? Double { indexFoot[name] = y }
            else if let y = info["foot_y"] as? Int { indexFoot[name] = Double(y) }
        }
    }
}
#endif
