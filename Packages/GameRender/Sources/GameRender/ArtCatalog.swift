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
    private static var perspectiveGridTex: SKTexture?
    private static var trailSpeckTex: SKTexture?

    /// Warm atlases once — batches GPU uploads for raccoon / MOP / shiny / tiles.
    /// Platform tiles get a baked neon-grid + edge pass (no runtime shaders / SKEffectNode).
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
                // Prop tiles (18+) get edge accents only; floor/wall slabs get full grid.
                let baked = i <= 17 ? bakeNeonGrid(onto: img, style: .platform) : bakeNeonGrid(onto: img, style: .prop)
                tileDict[String(format: "tile_%02d", i)] = baked
            }
        }
        if !tileDict.isEmpty {
            tileAtlas = SKTextureAtlas(dictionary: tileDict)
        }
        _ = motionTrailTexture()
        _ = perspectiveGridTexture()
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
        // Title art is path-swappable — drop a PNG at any TitleArt.logoCandidates path.
        // Callers MUST `fitTitleLogo` before pulse actions (scale(to:) is absolute).
        let maxPx: CGFloat = lite ? 768 : 1024
        let tex: SKTexture? = {
            for rel in TitleArt.logoCandidates {
                if let t = downsampledTexture(relative: rel, maxPixel: maxPx) { return t }
            }
            return texture(.logo)
        }()
        if let tex {
            let s = SKSpriteNode(texture: tex)
            s.name = "logo"
            s.setScale(1)
            return s
        }
        // Fallback label uses the working title string (still not ASC / bundle rename).
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = TitleArt.fallbackWordmark
        t.fontSize = 36
        t.fontColor = neonCyan
        t.name = "logo"
        t.numberOfLines = 2
        t.preferredMaxLayoutWidth = 360
        return t
    }

    /// Far-parallax perspective grid horizon (baked texture, additive, one node).
    public static func makePerspectiveGridHorizon(width: CGFloat, height: CGFloat) -> SKSpriteNode {
        let tex = perspectiveGridTexture()
        let n = SKSpriteNode(texture: tex, size: CGSize(width: width, height: height))
        n.name = "gridHorizon"
        n.blendMode = .add
        n.alpha = 0.42
        n.zPosition = -28
        return n
    }

    public static func motionTrailTexture() -> SKTexture {
        if let trailSpeckTex { return trailSpeckTex }
        let size = CGSize(width: 16, height: 28)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.0).cgColor,
                UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.85).cgColor,
                UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.55).cgColor,
                UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.0).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 0.7, 1]) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width * 0.5, y: 0),
                    end: CGPoint(x: size.width * 0.5, y: size.height),
                    options: []
                )
            }
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        trailSpeckTex = tex
        return tex
    }

    /// Scale the title wordmark to `fraction` of scene width (default 85%). Stores `baseScale` for pulse actions.
    @discardableResult
    public static func fitTitleLogo(_ node: SKNode, sceneWidth: CGFloat, fraction: CGFloat = 0.85) -> CGFloat {
        let target = max(120, sceneWidth * fraction)
        if let sprite = node as? SKSpriteNode {
            sprite.setScale(1)
            let scale = target / max(sprite.size.width, 1)
            sprite.setScale(scale)
            if sprite.userData == nil { sprite.userData = NSMutableDictionary() }
            sprite.userData?["baseScale"] = scale
            return scale
        }
        if let label = node as? SKLabelNode {
            label.setScale(1)
            let width = max(label.frame.width, 1)
            let scale = target / width
            label.setScale(scale)
            if label.userData == nil { label.userData = NSMutableDictionary() }
            label.userData?["baseScale"] = scale
            return scale
        }
        return 1
    }

    /// True when `frame` (scene space, anchor center) sits fully inside the safe playfield.
    public static func logoFrameInsideSafeArea(
        logoFrame: CGRect,
        sceneSize: CGSize,
        topSafe: CGFloat,
        bottomSafe: CGFloat
    ) -> Bool {
        let hw = sceneSize.width * 0.5
        let hh = sceneSize.height * 0.5
        let safe = CGRect(
            x: -hw + 4,
            y: -hh + bottomSafe + 4,
            width: sceneSize.width - 8,
            height: sceneSize.height - topSafe - bottomSafe - 8
        )
        return safe.contains(logoFrame)
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

    // MARK: - Neon grid bake (Grid-inspired, original magenta/teal)

    private enum NeonBakeStyle {
        case platform
        case prop
    }

    /// Composite thin glowing grid + crisp neon edges onto a tile PNG (CPU once at warm).
    private static func bakeNeonGrid(onto image: UIImage, style: NeonBakeStyle) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height
            let line = max(1.0 / image.scale, 0.75)

            if style == .platform {
                // Thin grid over dark floor/wall slabs.
                cg.setStrokeColor(UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.32).cgColor)
                cg.setLineWidth(line)
                let step = max(5, w / 4)
                var x: CGFloat = step
                while x < w - 1 {
                    cg.move(to: CGPoint(x: x, y: 2))
                    cg.addLine(to: CGPoint(x: x, y: h - 2))
                    x += step
                }
                var y: CGFloat = step
                while y < h - 1 {
                    cg.move(to: CGPoint(x: 2, y: y))
                    cg.addLine(to: CGPoint(x: w - 2, y: y))
                    y += step
                }
                cg.strokePath()

                // Crisp cyan top edge + magenta bottom lip.
                cg.setStrokeColor(UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.9).cgColor)
                cg.setLineWidth(line * 2.2)
                cg.move(to: CGPoint(x: 0, y: 1.5))
                cg.addLine(to: CGPoint(x: w, y: 1.5))
                cg.strokePath()
                cg.setStrokeColor(UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.65).cgColor)
                cg.setLineWidth(line * 1.6)
                cg.move(to: CGPoint(x: 0, y: h - 1.5))
                cg.addLine(to: CGPoint(x: w, y: h - 1.5))
                cg.strokePath()
            } else {
                // Props: neon rim only (no dense grid).
                cg.setStrokeColor(UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.55).cgColor)
                cg.setLineWidth(line * 1.8)
                cg.stroke(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
                cg.setStrokeColor(UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.35).cgColor)
                cg.setLineWidth(line)
                cg.stroke(CGRect(x: 3, y: 3, width: w - 6, height: h - 6))
            }
        }
    }

    private static func perspectiveGridTexture() -> SKTexture {
        if let perspectiveGridTex { return perspectiveGridTex }
        let size = CGSize(width: 512, height: 280)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height
            let vanishing = CGPoint(x: w * 0.5, y: h * 0.18)
            // Horizon bar
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.35).cgColor)
            cg.setLineWidth(1.2)
            cg.move(to: CGPoint(x: 0, y: vanishing.y))
            cg.addLine(to: CGPoint(x: w, y: vanishing.y))
            cg.strokePath()
            // Perspective spokes (floor grid vanishing into the skyline — not a Tron copy).
            cg.setStrokeColor(UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.28).cgColor)
            cg.setLineWidth(1)
            let spokes = 11
            for i in 0..<spokes {
                let t = CGFloat(i) / CGFloat(spokes - 1)
                let x = t * w
                cg.move(to: vanishing)
                cg.addLine(to: CGPoint(x: x, y: h))
            }
            cg.strokePath()
            // Horizontal depth rings
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.28, blue: 0.72, alpha: 0.22).cgColor)
            for i in 1...7 {
                let t = CGFloat(i) / 8.0
                let y = vanishing.y + (h - vanishing.y) * (t * t)
                let inset = (1 - t) * w * 0.42
                cg.move(to: CGPoint(x: inset, y: y))
                cg.addLine(to: CGPoint(x: w - inset, y: y))
            }
            cg.strokePath()
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        perspectiveGridTex = tex
        return tex
    }

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

/// Title art hooks — logo PNGs + strings. Bundle ID / Magpie target names stay unchanged.
public enum TitleArt {
    /// Prefer the first existing file. Ship `logo_neon_city_bandit` as the canonical wordmark.
    public static let logoCandidates: [String] = [
        "ui/logo_neon_city_bandit@1024",
        "ui/logo_neon_city_bandit",
        "ui/logo_title@1024",
        "ui/logo_title",
    ]
    public static let displayTitle = "The Neon City Bandit"
    public static let fallbackWordmark = "THE NEON CITY\nBANDIT"
    public static let workingSubtitle = "Free the crew · Stomp MOPs"
}

/// Animated raccoon using Fire Fox frames + procedural bob for a readable run.
@MainActor
public final class BanditVisual: SKNode {
    public let sprite: SKSpriteNode
    /// Squash/stretch lives on this wrapper so pose updates never clobber takeoff/land juice.
    private let body: SKNode
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
    private var facingSign: CGFloat = 1
    /// Fixed pool — recycle trail sprites (jetsam lesson: no per-frame alloc storms).
    private var trailPool: [SKSpriteNode] = []
    private var trailCursor: Int = 0
    private var trailAcc: CGFloat = 0
    private let trailPoolSize = 18

    public override init() {
        ArtCatalog.warmAtlases()
        idleTex = ArtCatalog.texture(.raccoonIdle)
        runTextures = ArtCatalog.textures(AssetManifest.runCycle)
        jumpTex = ArtCatalog.texture(.raccoonJump)
        fallTex = ArtCatalog.texture(.raccoonFall)
        pounceTex = ArtCatalog.texture(.raccoonPounce)
        flopTex = ArtCatalog.texture(.raccoonBellyFlop)
        maskTex = ArtCatalog.texture(.raccoonMaskMode)

        body = SKNode()
        body.name = "body"

        sprite = SKSpriteNode(texture: idleTex, size: CGSize(width: 72, height: 72))
        sprite.name = "sprite"
        ArtCatalog.applyDespill(sprite)

        shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.4)
        shadow.strokeColor = .clear
        shadow.zPosition = -1

        // Soft radial bloom behind the raccoon during Mask Mode (baked sprite tint, no SKEffectNode).
        let glowTex = maskTex ?? idleTex
        maskGlow = SKSpriteNode(texture: glowTex, size: CGSize(width: 110, height: 110))
        maskGlow.color = ArtCatalog.neonCyan
        maskGlow.colorBlendFactor = 0.85
        maskGlow.alpha = 0
        maskGlow.zPosition = -0.5
        maskGlow.isHidden = true
        maskGlow.blendMode = .add

        super.init()
        addChild(shadow)
        addChild(maskGlow)
        addChild(body)
        body.addChild(sprite)
        name = "bandit"

        let trailTex = ArtCatalog.motionTrailTexture()
        for i in 0..<trailPoolSize {
            let speck = SKSpriteNode(texture: trailTex, size: CGSize(width: 12, height: 22))
            speck.name = "trail_\(i)"
            speck.blendMode = .add
            speck.alpha = 0
            speck.isHidden = true
            speck.zPosition = -0.2
            trailPool.append(speck)
            addChild(speck)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    public func setFacing(_ facing: Double) {
        facingSign = facing >= 0 ? 1 : -1
        sprite.xScale = abs(sprite.xScale) * facingSign
    }

    /// Takeoff / land / stomp squash on the body wrapper (survives per-frame pose updates).
    public func squash(x: CGFloat, y: CGFloat) {
        body.removeAction(forKey: "sq")
        body.setScale(1)
        body.run(SKAction.sequence([
            SKAction.scaleX(to: x, y: y, duration: 0.055),
            SKAction.scaleX(to: 1, y: 1, duration: 0.12),
        ]), withKey: "sq")
    }

    public func show(anim: BanditAnim, maskMode: Bool, dt: CGFloat, smokeLite: Bool = false) {
        sprite.removeAction(forKey: "run")
        let face = facingSign
        switch anim {
        case .run:
            sprite.zRotation = 0
            if runTextures.count >= 2 {
                runAcc += dt
                // Faster cycle so the run reads in short smoke clips.
                if runAcc >= 0.07 {
                    runAcc = 0
                    runIndex = (runIndex + 1) % runTextures.count
                    sprite.texture = runTextures[runIndex]
                }
            } else if let idleTex {
                sprite.texture = idleTex
            }
            bobPhase += dt * 16
            sprite.position.y = sin(bobPhase) * 3.2
            let squash = 1.0 + sin(bobPhase * 2) * 0.06
            sprite.yScale = squash
            sprite.xScale = face * (2 - squash)
        case .jump:
            sprite.zRotation = 0
            sprite.texture = jumpTex ?? idleTex
            sprite.position.y = 3
            sprite.yScale = 1.14
            sprite.xScale = face * 0.86
        case .apex:
            sprite.zRotation = 0
            sprite.texture = jumpTex ?? idleTex
            sprite.position.y = 1
            bobPhase += dt * 8
            sprite.yScale = 0.92 + sin(bobPhase) * 0.02
            sprite.xScale = face * 1.08
        case .fall:
            sprite.texture = fallTex ?? idleTex
            sprite.position.y = 0
            bobPhase += dt * 10
            sprite.yScale = 1.18 + sin(bobPhase) * 0.04
            sprite.xScale = face * 0.82
            sprite.zRotation = face * -0.16
        case .pounce:
            sprite.zRotation = 0
            sprite.texture = (flopTex ?? pounceTex) ?? idleTex
            sprite.position.y = 0
            sprite.yScale = 0.86
            sprite.xScale = face * 1.16
        case .wallSlide:
            sprite.texture = fallTex ?? idleTex
            sprite.position.y = 0
            sprite.yScale = 1.05
            sprite.xScale = face * 0.9
            sprite.zRotation = face * 0.1
        case .idle:
            sprite.zRotation = 0
            sprite.texture = (maskMode ? maskTex : nil) ?? idleTex
            bobPhase += dt * 3
            sprite.position.y = sin(bobPhase) * 1.2
            sprite.yScale = 1
            sprite.xScale = face
        }
        if maskMode {
            if let maskTex { sprite.texture = maskTex }
            sprite.color = ArtCatalog.neonCyan
            sprite.colorBlendFactor = 0.28
            maskGlow.isHidden = false
            bobPhase += dt * 2
            // Stronger pulsing glow — readable next to the cyan trail.
            maskGlow.alpha = 0.55 + 0.35 * sin(bobPhase * 5)
            maskGlow.setScale(1.15 + 0.18 * sin(bobPhase * 6))
            maskGlow.color = ArtCatalog.neonCyan
        } else {
            sprite.color = ArtCatalog.neonPink
            sprite.colorBlendFactor = 0.14
            maskGlow.isHidden = true
            maskGlow.alpha = 0
            maskGlow.setScale(1)
        }
        tickMotionTrail(anim: anim, maskMode: maskMode, dt: dt, smokeLite: smokeLite)
    }

    /// Short light trail on run/dash; denser + brighter in Mask Mode. Pooled sprites only.
    private func tickMotionTrail(anim: BanditAnim, maskMode: Bool, dt: CGFloat, smokeLite: Bool) {
        let moving = maskMode || anim == .run || anim == .pounce || anim == .jump || anim == .apex
        guard moving else { return }
        trailAcc += dt
        let interval: CGFloat = {
            if maskMode { return smokeLite ? 0.055 : 0.04 }
            return smokeLite ? 0.1 : 0.07
        }()
        guard trailAcc >= interval else { return }
        trailAcc = 0
        emitPooledTrail(maskMode: maskMode, dash: anim == .pounce)
    }

    /// Public hook for Mask Mode burst cadence from the scene (still uses the pool).
    public func emitMaskTrail() {
        emitPooledTrail(maskMode: true, dash: false)
    }

    private func emitPooledTrail(maskMode: Bool, dash: Bool) {
        guard !trailPool.isEmpty else { return }
        let speck = trailPool[trailCursor % trailPool.count]
        trailCursor += 1
        speck.removeAllActions()
        let face: CGFloat = facingSign
        speck.position = CGPoint(x: -face * (maskMode ? 22 : 16), y: dash ? 2 : 4)
        speck.zRotation = 0
        speck.setScale(maskMode ? 1.45 : (dash ? 1.2 : 0.9))
        speck.color = maskMode ? ArtCatalog.neonCyan : ArtCatalog.neonPink
        speck.colorBlendFactor = 0.7
        speck.alpha = maskMode ? 0.85 : 0.48
        speck.isHidden = false
        let drift = -face * (maskMode ? 40 : 24)
        let life: TimeInterval = maskMode ? 0.32 : 0.2
        speck.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: life),
                SKAction.scaleX(to: 0.25, y: maskMode ? 1.7 : 1.25, duration: life),
                SKAction.moveBy(x: drift, y: 0, duration: life),
            ]),
            SKAction.run { speck.isHidden = true; speck.alpha = 0 },
        ]))
    }
}
#endif
