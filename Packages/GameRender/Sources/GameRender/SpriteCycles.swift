// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import Foundation
import SpriteKit
import UIKit

/// Normalized head/eye anchor relative to a foot-anchored display sprite.
/// `x` is fraction of display width from center (−0.5…0.5); `y` is fraction of
/// display height above the foot anchor (so LED eyes track the head per frame).
public struct HeadAnchor: Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// One Spriterrific action cycle (normalized frames under `sprites/spriterrific_ready/`).
/// Not Sendable: holds `SKTexture` (SpriteKit). Load/use on the main actor via `SpriteCycles`.
public struct SpriteCycle {
    public var textures: [SKTexture]
    public var fps: Double
    public var footY: Double
    /// Sheets face WEST; flip xScale when facing east/right.
    public var facesWest: Bool
    /// Per-frame head/eye anchors matching `textures` (same count).
    public var headAnchors: [HeadAnchor]

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
        var images: [UIImage] = []
        for i in 1...maxFrames {
            let rel = String(format: "%@/%02d", root, i)
            guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                  let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { break }
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            textures.append(tex)
            images.append(img)
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
        let anchors = headAnchors(for: images, footY: footY)
        let cycle = SpriteCycle(
            textures: textures,
            fps: fps,
            footY: footY,
            facesWest: true,
            headAnchors: anchors
        )
        cache[key] = cycle
        return cycle
    }

    /// Eye / head center per frame, expressed relative to the foot anchor.
    private static func headAnchors(for images: [UIImage], footY: Double) -> [HeadAnchor] {
        images.map { img in
            guard let cg = img.cgImage else {
                return HeadAnchor(x: 0, y: 0.48)
            }
            let w = cg.width
            let h = cg.height
            guard w > 0, h > 0, let data = cg.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                return HeadAnchor(x: 0, y: 0.48)
            }
            let bpp = max(cg.bitsPerPixel / 8, 1)
            let stride = cg.bytesPerRow
            var top = h
            var bot = 0
            for y in 0..<h {
                var opaque = false
                let row = ptr + y * stride
                for x in 0..<w {
                    let a = row[x * bpp + min(3, bpp - 1)]
                    if a > 40 { opaque = true; break }
                }
                if opaque {
                    top = min(top, y)
                    bot = max(bot, y)
                }
            }
            if top > bot {
                let footAnchor = (Double(h) - 1 - footY) / Double(h)
                return HeadAnchor(x: 0, y: CGFloat(0.55 - footAnchor))
            }
            let band = max(1, Int(Double(bot - top) * 0.42))
            var sumX = 0.0, sumY = 0.0, n = 0.0
            for y in top..<(top + band) {
                let row = ptr + y * stride
                for x in 0..<w {
                    let o = x * bpp
                    let r = Double(row[o])
                    let g = Double(row[min(o + 1, stride - 1)])
                    let b = Double(row[min(o + 2, stride - 1)])
                    let a = Double(row[min(o + 3, stride - 1)])
                    // Prefer bright eye glints; fall back to any opaque head pixel.
                    if a > 80, r > 160, g > 160, b > 160 {
                        sumX += Double(x); sumY += Double(y); n += 1
                    }
                }
            }
            if n < 4 {
                sumX = 0; sumY = 0; n = 0
                for y in top..<(top + max(1, band / 2)) {
                    let row = ptr + y * stride
                    for x in 0..<w {
                        let a = row[x * bpp + min(3, bpp - 1)]
                        if a > 80 {
                            sumX += Double(x); sumY += Double(y); n += 1
                        }
                    }
                }
            }
            guard n > 0 else {
                let footAnchor = (Double(h) - 1 - footY) / Double(h)
                return HeadAnchor(x: 0, y: CGFloat(0.55 - footAnchor))
            }
            let eyeX = sumX / n
            let eyeY = sumY / n
            let footAnchor = (Double(h) - 1 - footY) / Double(h)
            let eyeFracFromBottom = (Double(h) - 1 - eyeY) / Double(h)
            return HeadAnchor(
                x: CGFloat(eyeX / Double(w) - 0.5),
                y: CGFloat(eyeFracFromBottom - footAnchor)
            )
        }
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

    /// ~11–13% of portrait height at worldZoom ~1.85 after sheet padding.
    public static let banditDisplaySize = CGSize(width: 104, height: 104)
    public static let mopDisplaySize = CGSize(width: 96, height: 96)
    public static let bossDisplaySize = CGSize(width: 160, height: 160)

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
