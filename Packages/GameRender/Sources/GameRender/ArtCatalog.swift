// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

@MainActor
public enum ArtCatalog {
    public static let nightSky = SKColor(red: 0.08, green: 0.06, blue: 0.18, alpha: 1)
    public static let neonPink = SKColor(red: 1.0, green: 0.35, blue: 0.75, alpha: 1)
    public static let neonCyan = SKColor(red: 0.3, green: 0.98, blue: 1.0, alpha: 1)
    public static let neonLime = SKColor(red: 0.62, green: 1.0, blue: 0.42, alpha: 1)
    public static let neonOrange = SKColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)
    public static let asphalt = SKColor(red: 0.28, green: 0.22, blue: 0.38, alpha: 1)
    public static let dockFill = SKColor(red: 0.10, green: 0.08, blue: 0.20, alpha: 1)

    private static var textureCache: [AssetKey: SKTexture] = [:]

    public static func texture(_ key: AssetKey) -> SKTexture? {
        if let cached = textureCache[key] { return cached }
        guard let img = AssetManifest.image(for: key) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        textureCache[key] = tex
        return tex
    }

    public static func textures(_ keys: [AssetKey]) -> [SKTexture] {
        keys.compactMap { texture($0) }
    }

    /// Despill disabled at runtime — per-sprite SKShader was killing FPS (~10) and contributing to jetsam.
    public static func applyDespill(_ node: SKSpriteNode) {
        node.shader = nil
    }

    public static func makeBanditVisual() -> BanditVisual {
        BanditVisual()
    }

    public static func makeMopNode() -> SKSpriteNode {
        let tex = texture(.mopPatrol) ?? texture(.mopIdle)
        let n = SKSpriteNode(texture: tex, size: CGSize(width: 72, height: 48))
        n.name = "mop"
        return n
    }

    public static func makeShinyNode() -> SKNode {
        let frames = textures(AssetManifest.shinyFrames)
        let n = SKSpriteNode(texture: frames.first, size: CGSize(width: 28, height: 28))
        n.name = "shiny"
        if frames.count > 1 {
            // Slower animation = less GPU churn
            n.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.18)))
        }
        return n
    }

    public static func makeLogoNode() -> SKNode {
        if let tex = texture(.logo) {
            let s = SKSpriteNode(texture: tex)
            let maxW: CGFloat = 300
            let scale = min(1, maxW / max(s.size.width, 1))
            s.setScale(scale)
            s.name = "logo"
            return s
        }
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = "TRASH PANDA"
        t.fontSize = 42
        t.fontColor = neonCyan
        return t
    }

    /// Backgrounds are 2560×1440 masters — downsample before upload to GPU.
    public static func background(_ key: AssetKey, height: CGFloat) -> SKSpriteNode? {
        guard let img = AssetManifest.image(for: key) else { return nil }
        let maxPixel: CGFloat = 1400
        let scale = min(1, maxPixel / max(img.size.width, img.size.height))
        let sized: UIImage
        if scale < 0.99 {
            let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            sized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            sized = img
        }
        let tex = SKTexture(image: sized)
        tex.filteringMode = .linear
        let aspect = tex.size().width / max(tex.size().height, 1)
        let n = SKSpriteNode(texture: tex, size: CGSize(width: height * aspect, height: height))
        n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return n
    }

    private static var tileCache: [Int: SKTexture] = [:]

    public static func tileTexture(index: Int) -> SKTexture? {
        if let cached = tileCache[index] { return cached }
        let name = String(format: "tile_%02d", index)
        let rel = "sprites/tiles/\(name)"
        var url: URL?
        if let res = Bundle.main.resourceURL {
            for root in ["Generated", "Assets/Generated"] {
                let candidate = res.appendingPathComponent(root).appendingPathComponent(rel).appendingPathExtension("png")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    url = candidate
                    break
                }
            }
        }
        if url == nil {
            url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Generated/sprites/tiles")
                ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets/Generated/sprites/tiles")
        }
        guard let url,
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        tileCache[index] = tex
        return tex
    }

    /// Budget helper for regression tests: solids should not explode into dual edge nodes.
    public static var expectedNodesPerSolidTile: Int { 1 }
}

/// Animated raccoon using Fire Fox frames + procedural bob for a readable run.
@MainActor
public final class BanditVisual: SKNode {
    public let sprite: SKSpriteNode
    private let shadow: SKShapeNode
    private var runTextures: [SKTexture] = []
    private var idleTex: SKTexture?
    private var jumpTex: SKTexture?
    private var fallTex: SKTexture?
    private var pounceTex: SKTexture?
    private var flopTex: SKTexture?
    private var maskTex: SKTexture?
    private var bobPhase: CGFloat = 0
    private var runIndex: Int = 0
    private var runAcc: CGFloat = 0

    public override init() {
        idleTex = ArtCatalog.texture(.raccoonIdle)
        runTextures = ArtCatalog.textures(AssetManifest.runCycle)
        jumpTex = ArtCatalog.texture(.raccoonJump)
        fallTex = ArtCatalog.texture(.raccoonFall)
        pounceTex = ArtCatalog.texture(.raccoonPounce)
        flopTex = ArtCatalog.texture(.raccoonBellyFlop)
        maskTex = ArtCatalog.texture(.raccoonMaskMode)

        // Readable on phone (~1/7 screen with mild world zoom).
        sprite = SKSpriteNode(texture: idleTex, size: CGSize(width: 72, height: 72))
        sprite.name = "sprite"

        shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.4)
        shadow.strokeColor = .clear
        shadow.zPosition = -1

        super.init()
        addChild(shadow)
        addChild(sprite)
        name = "bandit"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    public func setFacing(_ facing: Double) {
        sprite.xScale = facing >= 0 ? 1 : -1
    }

    public func show(anim: BanditAnim, maskMode: Bool, dt: CGFloat) {
        sprite.removeAction(forKey: "run")
        switch anim {
        case .run:
            // Manual frame advance — avoids SKAction allocate/churn every state flip.
            if runTextures.count >= 2 {
                runAcc += dt
                if runAcc >= 0.09 {
                    runAcc = 0
                    runIndex = (runIndex + 1) % runTextures.count
                    sprite.texture = runTextures[runIndex]
                }
            } else if let idleTex {
                sprite.texture = idleTex
            }
            bobPhase += dt * 14
            sprite.position.y = sin(bobPhase) * 2.5
            let squash = 1.0 + sin(bobPhase * 2) * 0.035
            sprite.yScale = squash
            sprite.xScale = (sprite.xScale >= 0 ? 1 : -1) * (2 - squash)
        case .jump:
            sprite.texture = jumpTex ?? idleTex
            sprite.position.y = 2
            sprite.yScale = 1.05
        case .fall:
            sprite.texture = fallTex ?? idleTex
            sprite.position.y = 0
            sprite.yScale = 1
        case .pounce:
            sprite.texture = (flopTex ?? pounceTex) ?? idleTex
            sprite.position.y = 0
            sprite.yScale = 0.9
            sprite.xScale = (sprite.xScale >= 0 ? 1 : -1) * 1.1
        case .wallSlide:
            sprite.texture = fallTex ?? idleTex
            sprite.position.y = 0
        case .idle:
            sprite.texture = (maskMode ? maskTex : nil) ?? idleTex
            sprite.position.y = 0
            sprite.yScale = 1
            let face = sprite.xScale >= 0 ? 1.0 : -1.0
            sprite.xScale = face
        }
        // Rim via light color blend (no second sprite / no shader).
        if maskMode {
            sprite.color = ArtCatalog.neonCyan
            sprite.colorBlendFactor = 0.3
        } else {
            sprite.color = ArtCatalog.neonPink
            sprite.colorBlendFactor = 0.12
        }
    }
}
#endif
