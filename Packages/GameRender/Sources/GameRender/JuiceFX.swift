// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Higgsfield juice sheets under `Generated/fx/higgsfield/` + button icons under `Generated/ui/buttons/`.
/// Short one-shots only — never block input; textures are cached after first load.
@MainActor
public enum JuiceFX {
    private static var cache: [String: [SKTexture]] = [:]
    private static var iconCache: [String: SKTexture] = [:]
    private static var warmed = false

    public enum Sheet: String {
        case stompBurst = "stomp-burst"
        case mopDeath = "mop-death"
        case footDust = "foot-dust"
        case pickupGlow = "pickup-glow"
    }

    /// Call once at scene start so first stomp/jump doesn't hitch.
    public static func warm() {
        guard !warmed else { return }
        warmed = true
        _ = textures(.stompBurst)
        _ = textures(.mopDeath)
        _ = textures(.footDust)
        _ = textures(.pickupGlow, loopStart: 2)
        _ = buttonIcon("jump")
        _ = buttonIcon("pounce")
    }

    public static func buttonIcon(_ name: String) -> SKTexture? {
        if let cached = iconCache[name] { return cached }
        let rel = "ui/buttons/\(name)"
        guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        iconCache[name] = tex
        return tex
    }

    /// Frame list for a sheet. `loopStart` is 1-based (pickup glow loops 2…6).
    public static func textures(_ sheet: Sheet, loopStart: Int = 1, maxFrames: Int = 8) -> [SKTexture] {
        let key = "\(sheet.rawValue)#\(loopStart)"
        if let cached = cache[key] { return cached }
        var frames: [SKTexture] = []
        let prefix = "fx/higgsfield/\(sheet.rawValue)/\(sheet.rawValue)"
        for i in loopStart...maxFrames {
            let rel = String(format: "%@-%02d", prefix, i)
            guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                  let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { break }
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            frames.append(tex)
        }
        cache[key] = frames
        return frames
    }

    /// Play a one-shot FX at `world` position. Returns immediately; animation self-removes.
    @discardableResult
    public static func play(
        _ sheet: Sheet,
        at position: CGPoint,
        in parent: SKNode,
        size: CGFloat,
        z: CGFloat,
        timePerFrame: TimeInterval = 1.0 / 24.0,
        blendAdd: Bool = true
    ) -> SKSpriteNode? {
        let frames = textures(sheet)
        guard let first = frames.first else { return nil }
        let node = SKSpriteNode(texture: first, size: CGSize(width: size, height: size))
        node.position = position
        node.zPosition = z
        node.blendMode = blendAdd ? .add : .alpha
        node.name = "juice_\(sheet.rawValue)"
        parent.addChild(node)
        if frames.count == 1 {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.removeFromParent(),
            ]))
        } else {
            node.run(SKAction.sequence([
                SKAction.animate(with: frames, timePerFrame: timePerFrame),
                SKAction.removeFromParent(),
            ]))
        }
        return node
    }

    /// Neon glow loop behind loot (frames 2–6). Attaches as a child; non-blocking.
    public static func attachPickupGlow(to host: SKNode, size: CGFloat = 48) {
        host.childNode(withName: "pickupGlow")?.removeFromParent()
        let frames = textures(.pickupGlow, loopStart: 2)
        guard let first = frames.first else { return }
        let glow = SKSpriteNode(texture: first, size: CGSize(width: size, height: size))
        glow.name = "pickupGlow"
        glow.zPosition = -1
        glow.blendMode = .add
        glow.alpha = 0.85
        host.addChild(glow)
        if frames.count > 1 {
            glow.run(SKAction.repeatForever(
                SKAction.animate(with: frames, timePerFrame: 0.12)
            ), withKey: "pickupGlowLoop")
        }
    }
}
#endif
