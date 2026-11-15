// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import ImageIO
import SpriteKit
import UIKit

@MainActor
public enum ArtCatalog {
    /// Bright magenta / teal neon night — Game Plan v1 “bright neon on dark”.
    public static let nightSky = SKColor(red: 0.06, green: 0.04, blue: 0.16, alpha: 1)
    public static let neonPink = SKColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 1)
    public static let neonCyan = SKColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 1)
    public static let neonLime = SKColor(red: 0.62, green: 1.0, blue: 0.42, alpha: 1)
    public static let neonOrange = SKColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)
    public static let asphalt = SKColor(red: 0.28, green: 0.22, blue: 0.38, alpha: 1)
    public static let dockFill = SKColor(red: 0.09, green: 0.07, blue: 0.18, alpha: 1)

    private static var textureCache: [AssetKey: SKTexture] = [:]
    private static var tileCache: [Int: SKTexture] = [:]
    private static var spriteAtlas: SKTextureAtlas?
    private static var tileAtlas: SKTextureAtlas?
    private static var didWarm = false

    /// Warm atlases once — batches GPU uploads for raccoon / MOP / shiny / tiles.
    public static func warmAtlases() {
        guard !didWarm else { return }
        didWarm = true
        var spriteDict: [String: UIImage] = [:]
        for key in AssetManifest.runCycle + AssetManifest.shinyFrames + [
            .raccoonIdle, .raccoonJump, .raccoonFall, .raccoonPounce, .raccoonBellyFlop, .raccoonMaskMode,
            .mopIdle, .mopPatrol, .mopAlert, .logo,
        ] {
            if let img = AssetManifest.image(for: key, preferScale: 2) {
                spriteDict[key.rawValue.replacingOccurrences(of: "/", with: "_")] = img
            }
        }
        if !spriteDict.isEmpty {
            spriteAtlas = SKTextureAtlas(dictionary: spriteDict)
        }
        var tileDict: [String: UIImage] = [:]
        for i in 1...27 {
            if let img = loadTileImage(index: i) {
                tileDict[String(format: "tile_%02d", i)] = img
            }
        }
        if !tileDict.isEmpty {
            tileAtlas = SKTextureAtlas(dictionary: tileDict)
        }
    }

    public static func texture(_ key: AssetKey) -> SKTexture? {
        if let cached = textureCache[key] { return cached }
        let atlasName = key.rawValue.replacingOccurrences(of: "/", with: "_")
        if let atlas = spriteAtlas {
            let names = atlas.textureNames
            if names.contains(atlasName) {
                let tex = atlas.textureNamed(atlasName)
                tex.filteringMode = .linear
                textureCache[key] = tex
                return tex
            }
        }
        guard let img = AssetManifest.image(for: key, preferScale: 2) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        textureCache[key] = tex
        return tex
    }

    public static func textures(_ keys: [AssetKey]) -> [SKTexture] {
        keys.compactMap { texture($0) }
    }

    /// Despill disabled at runtime — glow is baked into the PNGs (Game Plan v1).
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
        applyDespill(n)
        return n
    }

    public static func makeShinyNode() -> SKNode {
        let frames = textures(AssetManifest.shinyFrames)
        let n = SKSpriteNode(texture: frames.first, size: CGSize(width: 28, height: 28))
        n.name = "shiny"
        applyDespill(n)
        if frames.count > 1 {
            n.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.16)))
        }
        return n
    }

    public static func makeLogoNode(lite: Bool = false) -> SKNode {
        // Prefer @1024 wordmark when present; skip 2048 master during smoke lite boot.
        if !lite, let tex = texture(.logo) {
            let s = SKSpriteNode(texture: tex)
            let maxW: CGFloat = 300
            let scale = min(1, maxW / max(s.size.width, 1))
            s.setScale(scale)
            s.name = "logo"
            return s
        }
        if let tex = downsampledTexture(relative: "ui/logo_trash_panda@1024", maxPixel: 1024)
            ?? downsampledTexture(relative: "ui/logo_trash_panda", maxPixel: 1024) {
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
        t.name = "logo"
        return t
    }

    /// Backgrounds: ImageIO thumbnail decode to ≤ maxPixel (never upload 2560 masters).
    public static func background(_ key: AssetKey, height: CGFloat, maxPixel: CGFloat = 1280) -> SKSpriteNode? {
        let rel = AssetManifest.relativePath(for: key)
        guard let tex = downsampledTexture(relative: rel, maxPixel: maxPixel) else { return nil }
        let aspect = tex.size().width / max(tex.size().height, 1)
        let h = min(height, 780)
        let n = SKSpriteNode(texture: tex, size: CGSize(width: h * aspect, height: h))
        n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // Brighten toward Game Plan magenta/teal neon read.
        n.color = SKColor(white: 1.12, alpha: 1)
        n.colorBlendFactor = 0.12
        return n
    }

    public static func tileTexture(index: Int) -> SKTexture? {
        if let cached = tileCache[index] { return cached }
        let name = String(format: "tile_%02d", index)
        if let atlas = tileAtlas, atlas.textureNames.contains(name) {
            let tex = atlas.textureNamed(name)
            tex.filteringMode = .nearest
            tileCache[index] = tex
            return tex
        }
        guard let img = loadTileImage(index: index) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        tileCache[index] = tex
        return tex
    }

    public static func allTileTextures() -> [SKTexture] {
        (1...27).compactMap { tileTexture(index: $0) }
    }

    /// One visual tile definition set for SKTileMapNode (baked neon strips already in PNGs).
    public static func makePlatformTileSet(tileSize: CGSize) -> SKTileSet {
        var groups: [SKTileGroup] = []
        for i in 1...27 {
            guard let tex = tileTexture(index: i) else { continue }
            let def = SKTileDefinition(texture: tex, size: tileSize)
            def.name = String(format: "tile_%02d", i)
            let group = SKTileGroup(tileDefinition: def)
            group.name = def.name
            groups.append(group)
        }
        // Fallback solid if no textures.
        if groups.isEmpty {
            let fallback = SKTileDefinition(texture: SKTexture(), size: tileSize)
            groups.append(SKTileGroup(tileDefinition: fallback))
        }
        return SKTileSet(tileGroups: groups)
    }

    public static func rainEmitter(sceneSize: CGSize) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleBirthRate = 55
        e.numParticlesToEmit = 0
        e.particleLifetime = 1.1
        e.particleSize = CGSize(width: 1.5, height: 10)
        e.particleColor = neonCyan.withAlphaComponent(0.55)
        e.particleColorBlendFactor = 1
        e.particleAlpha = 0.55
        e.particleAlphaRange = 0.25
        e.particleSpeed = 280
        e.particleSpeedRange = 80
        e.emissionAngle = -.pi / 2 - 0.25
        e.emissionAngleRange = 0.08
        e.particleRotation = -.pi / 2 - 0.25
        e.position = CGPoint(x: 0, y: sceneSize.height * 0.55)
        e.particlePositionRange = CGVector(dx: sceneSize.width * 1.2, dy: 20)
        e.zPosition = 70
        return e
    }

    /// Palette anchors for smoke side-by-side check (Game Plan bright magenta + teal).
    public static let paletteMagenta = (r: 1.0, g: 0.28, b: 0.72)
    public static let paletteTeal = (r: 0.25, g: 0.98, b: 1.0)

    public static var expectedNodesPerSolidTile: Int { 1 }

    // MARK: - Loaders

    private static func loadTileImage(index: Int) -> UIImage? {
        let name = String(format: "tile_%02d", index)
        let rel = "sprites/tiles/\(name)"
        guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]) else { return nil }
        return downsampledUIImage(url: url, maxPixel: 256)
    }

    private static func downsampledTexture(relative: String, maxPixel: CGFloat) -> SKTexture? {
        guard let url = AssetManifest.fileURLPublic(relative: relative, extensions: ["png"]),
              let img = downsampledUIImage(url: url, maxPixel: maxPixel) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    /// Memory-safe downsample via ImageIO thumbnails (no full-res bitmap spike).
    public static func downsampledUIImage(url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Animated raccoon using Fire Fox frames + procedural bob for a readable run.
@MainActor
public final class BanditVisual: SKNode {
    public let sprite: SKSpriteNode
    private let shadow: SKShapeNode
    private let maskGlow: SKSpriteNode
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
        ArtCatalog.warmAtlases()
        idleTex = ArtCatalog.texture(.raccoonIdle)
        runTextures = ArtCatalog.textures(AssetManifest.runCycle)
        jumpTex = ArtCatalog.texture(.raccoonJump)
        fallTex = ArtCatalog.texture(.raccoonFall)
        pounceTex = ArtCatalog.texture(.raccoonPounce)
        flopTex = ArtCatalog.texture(.raccoonBellyFlop)
        maskTex = ArtCatalog.texture(.raccoonMaskMode)

        sprite = SKSpriteNode(texture: idleTex, size: CGSize(width: 72, height: 72))
        sprite.name = "sprite"
        ArtCatalog.applyDespill(sprite)

        shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.4)
        shadow.strokeColor = .clear
        shadow.zPosition = -1

        // Soft cyan plate behind the sprite during Mask Mode (baked look, no SKEffectNode).
        maskGlow = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.35), size: CGSize(width: 90, height: 90))
        maskGlow.zPosition = -0.5
        maskGlow.isHidden = true
        maskGlow.alpha = 0

        super.init()
        addChild(shadow)
        addChild(maskGlow)
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
        if maskMode {
            sprite.color = ArtCatalog.neonCyan
            sprite.colorBlendFactor = 0.35
            maskGlow.isHidden = false
            maskGlow.alpha = 0.55 + 0.25 * sin(bobPhase * 3)
        } else {
            sprite.color = ArtCatalog.neonPink
            sprite.colorBlendFactor = 0.14
            maskGlow.isHidden = true
            maskGlow.alpha = 0
        }
    }
}
#endif
