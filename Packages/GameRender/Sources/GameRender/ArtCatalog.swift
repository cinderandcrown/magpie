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
    private static var sideMaskCache: [Int: SKTexture] = [:]
    private static var sidePropCache: [Int: SKTexture] = [:]
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
            .raccoonRigHead, .raccoonRigTorso, .raccoonRigArm, .raccoonRigLeg, .raccoonRigTail,
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
                // Legacy prop sheets only — ground uses tiles_side autotiles (no outline bake).
                let baked = bakeNeonGrid(onto: img, style: .prop)
                tileDict[String(format: "tile_%02d", i)] = baked
            }
        }
        if !tileDict.isEmpty {
            tileAtlas = SKTextureAtlas(dictionary: tileDict)
        }
        warmSideAutotiles()
        warmSideProps()
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

    /// Front-facing idle for title / menu / Hideout (`idle_front` sheet).
    public static func makeBanditFrontMascot(size: CGSize = CGSize(width: 96, height: 96)) -> SKSpriteNode {
        let cycle = SpriteCycles.bandit("idle_front")
        let tex = cycle?.textures.first ?? texture(.raccoonIdle) ?? SKTexture()
        let n = SKSpriteNode(texture: tex, size: size)
        n.name = "banditFront"
        n.anchorPoint = CGPoint(x: 0.5, y: cycle?.footAnchorY ?? 0.14)
        applyDespill(n)
        if let cycle, cycle.textures.count > 1 {
            n.run(SKAction.repeatForever(
                SKAction.animate(with: cycle.textures, timePerFrame: cycle.timePerFrame)
            ), withKey: "frames")
        }
        return n
    }

    /// Rig parts cropped from the project idle sheet (see `Assets/LICENSES.md`). No third-party art.
    public static func raccoonRigParts() -> (
        head: SKTexture, torso: SKTexture, arm: SKTexture, leg: SKTexture, tail: SKTexture
    ) {
        let fallback = texture(.raccoonIdle) ?? SKTexture()
        func load(_ key: AssetKey) -> SKTexture {
            texture(key) ?? fallback
        }
        return (
            head: load(.raccoonRigHead),
            torso: load(.raccoonRigTorso),
            arm: load(.raccoonRigArm),
            leg: load(.raccoonRigLeg),
            tail: load(.raccoonRigTail)
        )
    }

    /// Prefer Spriterrific ready frames, then legacy CC-BY folders.
    public static func licensedCycleTextures(_ name: String, maxFrames: Int = 24) -> [SKTexture] {
        if let cycle = SpriteCycles.bandit(name), !cycle.textures.isEmpty {
            return Array(cycle.textures.prefix(maxFrames))
        }
        let roots = [
            "sprites/spriterrific_ready/bandit/\(name)",
            "sprites/raccoon/spriterrific/\(name)",
            "sprites/raccoon/licensed_ccby/\(name)",
        ]
        for root in roots {
            var out: [SKTexture] = []
            for i in 1...maxFrames {
                let rel = String(format: "%@/%02d", root, i)
                guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                      let data = try? Data(contentsOf: url),
                      let img = UIImage(data: data) else { break }
                let tex = SKTexture(image: img)
                tex.filteringMode = .linear
                out.append(tex)
            }
            if out.count >= 2 { return out }
        }
        return []
    }

    public static func makeMopNode() -> MopVisual {
        MopVisual()
    }

    public static func makeBossNode() -> BossVisual {
        BossVisual()
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

    /// 16-mask side-view ground autotile set (`sprites/tiles_side/mask_XX.png`).
    /// Bits: N=1 E=2 S=4 W=8 (solid neighbour present). No per-tile outline strokes.
    public static func makePlatformTileSet(tileSize: CGSize) -> SKTileSet {
        warmSideAutotiles()
        var groups: [SKTileGroup] = []
        groups.reserveCapacity(16)
        for mask in 0..<16 {
            let tex = sideAutotileTexture(mask: mask) ?? solidFallbackTexture(tileSize: tileSize)
            let def = SKTileDefinition(texture: tex, size: tileSize)
            def.name = String(format: "side_mask_%02d", mask)
            let group = SKTileGroup(tileDefinition: def)
            group.name = def.name
            groups.append(group)
        }
        return SKTileSet(tileGroups: groups)
    }

    public static func sideAutotileTexture(mask: Int) -> SKTexture? {
        let m = max(0, min(15, mask))
        if let cached = sideMaskCache[m] { return cached }
        warmSideAutotiles()
        return sideMaskCache[m]
    }

    /// Kenney Industrial CC0 props for decoration only (crates / pipes).
    public static func sidePropTexture(index: Int) -> SKTexture? {
        if let cached = sidePropCache[index] { return cached }
        warmSideProps()
        return sidePropCache[index]
    }

    public static func sidePropTextures() -> [SKTexture] {
        warmSideProps()
        return sidePropCache.keys.sorted().compactMap { sidePropCache[$0] }
    }

    private static func warmSideAutotiles() {
        if sideMaskCache.count >= 16 { return }
        for mask in 0..<16 {
            let name = String(format: "mask_%02d", mask)
            let rel = "sprites/tiles_side/\(name)"
            guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                  let img = downsampledUIImage(url: url, maxPixel: 128) else { continue }
            let tex = SKTexture(image: img)
            tex.filteringMode = .nearest
            sideMaskCache[mask] = tex
        }
    }

    private static func warmSideProps() {
        if !sidePropCache.isEmpty { return }
        for i in 20...59 {
            let name = String(format: "prop_%03d", i)
            let rel = "sprites/props_side/\(name)"
            guard let url = AssetManifest.fileURLPublic(relative: rel, extensions: ["png"]),
                  let img = downsampledUIImage(url: url, maxPixel: 128) else { continue }
            let tex = SKTexture(image: img)
            tex.filteringMode = .nearest
            sidePropCache[i] = tex
        }
    }

    private static func solidFallbackTexture(tileSize: CGSize) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: tileSize, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.12, green: 0.1, blue: 0.2, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: tileSize))
            cg.setFillColor(UIColor(red: 0.25, green: 0.98, blue: 1.0, alpha: 0.85).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: tileSize.width, height: 3))
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
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
    /// In-game credits. Spriterrific steampunk-neon bandit / MOP sheets owned by Cinder & Crown.
    public static let assetCredits = "Art: Spriterrific (Cinder & Crown)"
}

/// Bandit raccoon — Spriterrific sheets (west-facing); feet sit IN the ground art.
@MainActor
public final class BanditVisual: SKNode {
    public let sprite: SKSpriteNode
    private let body: SKNode
    private let rig: SKNode
    private let head: SKSpriteNode
    private let torso: SKSpriteNode
    private let armF: SKSpriteNode
    private let armB: SKSpriteNode
    private let legF: SKSpriteNode
    private let legB: SKSpriteNode
    private let tail: SKSpriteNode
    private let shadow: SKShapeNode
    private let maskGlow: SKSpriteNode
    private var cycles: [String: SpriteCycle] = [:]
    private var runTextures: [SKTexture] = []
    private var walkTextures: [SKTexture] = []
    private var idleTextures: [SKTexture] = []
    private var jumpTextures: [SKTexture] = []
    private var attackTextures: [SKTexture] = []
    private var hurtTextures: [SKTexture] = []
    private var deathTextures: [SKTexture] = []
    private var pickUpTextures: [SKTexture] = []
    private var idleTex: SKTexture?
    private var jumpTex: SKTexture?
    private var fallTex: SKTexture?
    private var pounceTex: SKTexture?
    private var flopTex: SKTexture?
    private var maskTex: SKTexture?
    private var bobPhase: CGFloat = 0
    /// World facing: +1 = right/east. Sheets face west, so body.xScale = −facingSign.
    private var facingSign: CGFloat = 1
    private var usesWestSheets = true
    private var footAnchorY: CGFloat = 0.14
    private var currentAnim: BanditAnim = .idle
    private var trailPool: [SKSpriteNode] = []
    private var trailCursor: Int = 0
    private var trailAcc: CGFloat = 0
    private let trailPoolSize = 18
    private var sheetDriven = false

    public override init() {
        ArtCatalog.warmAtlases()
        func load(_ action: String) -> SpriteCycle? {
            SpriteCycles.bandit(action)
        }
        let idleC = load("idle")
        let walkC = load("walk")
        let runC = load("run")
        let jumpC = load("jump")
        let attackC = load("attack")
        let hurtC = load("hurt")
        let deathC = load("death")
        let pickC = load("pick_up")
        sheetDriven = (runC?.textures.count ?? 0) >= 6 && (idleC?.textures.count ?? 0) >= 2
        if let idleC { cycles["idle"] = idleC; idleTextures = idleC.textures; footAnchorY = idleC.footAnchorY }
        if let walkC { cycles["walk"] = walkC; walkTextures = walkC.textures }
        if let runC { cycles["run"] = runC; runTextures = runC.textures }
        if let jumpC { cycles["jump"] = jumpC; jumpTextures = jumpC.textures }
        if let attackC { cycles["attack"] = attackC; attackTextures = attackC.textures }
        if let hurtC { cycles["hurt"] = hurtC; hurtTextures = hurtC.textures }
        if let deathC { cycles["death"] = deathC; deathTextures = deathC.textures }
        if let pickC { cycles["pick_up"] = pickC; pickUpTextures = pickC.textures }
        usesWestSheets = sheetDriven

        if !sheetDriven {
            let licensedRun = ArtCatalog.licensedCycleTextures("run", maxFrames: 12)
            runTextures = licensedRun.count >= 6 ? licensedRun : ArtCatalog.textures(AssetManifest.runCycle)
            idleTextures = ArtCatalog.licensedCycleTextures("idle", maxFrames: 8)
            jumpTextures = ArtCatalog.licensedCycleTextures("jump", maxFrames: 8)
            usesWestSheets = false
        }

        idleTex = idleTextures.first ?? ArtCatalog.texture(.raccoonIdle)
        jumpTex = jumpTextures.first ?? ArtCatalog.texture(.raccoonJump)
        fallTex = jumpTextures.dropFirst(jumpTextures.count * 2 / 3).first ?? ArtCatalog.texture(.raccoonFall)
        pounceTex = attackTextures.first ?? ArtCatalog.texture(.raccoonPounce)
        flopTex = attackTextures.last ?? ArtCatalog.texture(.raccoonBellyFlop)
        maskTex = ArtCatalog.texture(.raccoonMaskMode)

        let parts = ArtCatalog.raccoonRigParts()

        body = SKNode()
        body.name = "body"
        rig = SKNode()
        rig.name = "rig"

        // Anchor at normalized foot baseline so soles sit IN the ground art.
        sprite = SKSpriteNode(texture: idleTex, size: SpriteCycles.banditDisplaySize)
        sprite.name = "sprite"
        sprite.anchorPoint = CGPoint(x: 0.5, y: footAnchorY)
        sprite.zPosition = 1
        ArtCatalog.applyDespill(sprite)

        torso = SKSpriteNode(texture: parts.torso, size: CGSize(width: 36, height: 34))
        torso.name = "torso"
        torso.position = CGPoint(x: 0, y: -2)
        torso.alpha = 0
        ArtCatalog.applyDespill(torso)

        head = SKSpriteNode(texture: parts.head, size: CGSize(width: 40, height: 36))
        head.name = "head"
        head.position = CGPoint(x: 2, y: 20)
        head.alpha = 0
        ArtCatalog.applyDespill(head)

        armB = SKSpriteNode(texture: parts.arm, size: CGSize(width: 18, height: 26))
        armB.name = "armB"
        armB.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        armB.position = CGPoint(x: -14, y: 10)
        armB.alpha = 0
        ArtCatalog.applyDespill(armB)

        armF = SKSpriteNode(texture: parts.arm, size: CGSize(width: 18, height: 26))
        armF.name = "armF"
        armF.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        armF.position = CGPoint(x: 14, y: 10)
        armF.xScale = -1
        armF.alpha = 0
        ArtCatalog.applyDespill(armF)

        legB = SKSpriteNode(texture: parts.leg, size: CGSize(width: 20, height: 28))
        legB.name = "legB"
        legB.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        legB.position = CGPoint(x: -8, y: -14)
        legB.alpha = 0
        ArtCatalog.applyDespill(legB)

        legF = SKSpriteNode(texture: parts.leg, size: CGSize(width: 20, height: 28))
        legF.name = "legF"
        legF.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        legF.position = CGPoint(x: 8, y: -14)
        legF.alpha = 0
        ArtCatalog.applyDespill(legF)

        tail = SKSpriteNode(texture: parts.tail, size: CGSize(width: 36, height: 24))
        tail.name = "tail"
        tail.anchorPoint = CGPoint(x: 0.9, y: 0.5)
        tail.position = CGPoint(x: -16, y: -2)
        tail.zPosition = -0.3
        tail.alpha = sheetDriven ? 0 : 1
        ArtCatalog.applyDespill(tail)

        shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.4)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        shadow.position = CGPoint(x: 0, y: -2)

        // LED eye glints for Mask Mode (crisp points — not a translucent head plate).
        maskGlow = SKSpriteNode(color: .clear, size: CGSize(width: 28, height: 12))
        maskGlow.alpha = 0
        maskGlow.isHidden = true
        maskGlow.zPosition = 3
        maskGlow.position = CGPoint(x: 2, y: 22)
        let eyeL = SKShapeNode(circleOfRadius: 2.4)
        eyeL.fillColor = ArtCatalog.neonCyan
        eyeL.strokeColor = .white
        eyeL.lineWidth = 0.6
        eyeL.glowWidth = 1.2
        eyeL.position = CGPoint(x: -5, y: 0)
        let eyeR = SKShapeNode(circleOfRadius: 2.4)
        eyeR.fillColor = ArtCatalog.neonCyan
        eyeR.strokeColor = .white
        eyeR.lineWidth = 0.6
        eyeR.glowWidth = 1.2
        eyeR.position = CGPoint(x: 5, y: 0)
        maskGlow.addChild(eyeL)
        maskGlow.addChild(eyeR)

        super.init()
        addChild(shadow)
        addChild(maskGlow)
        addChild(body)
        body.addChild(sprite)
        body.addChild(rig)
        for n in [tail, armB, legB, torso, legF, armF, head] as [SKNode] {
            rig.addChild(n)
        }
        name = "bandit"
        applyFacingScale()

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
        startIdleMotion()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    public func setFacing(_ facing: Double) {
        facingSign = facing >= 0 ? 1 : -1
        applyFacingScale()
        sprite.xScale = abs(sprite.xScale)
    }

    private func bodyFaceScale() -> CGFloat {
        // West-facing sheets: flip when facing right (+1).
        usesWestSheets ? -facingSign : facingSign
    }

    private func applyFacingScale() {
        body.xScale = bodyFaceScale()
    }

    public func squash(x: CGFloat, y: CGFloat) {
        body.removeAction(forKey: "sq")
        let face = bodyFaceScale()
        body.xScale = face
        body.yScale = 1
        body.run(SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: x * face, duration: 0.05),
                SKAction.scaleY(to: y, duration: 0.05),
            ]),
            SKAction.group([
                SKAction.scaleX(to: face, duration: 0.11),
                SKAction.scaleY(to: 1, duration: 0.11),
            ]),
        ]), withKey: "sq")
    }

    public func show(anim: BanditAnim, maskMode: Bool, dt: CGFloat, smokeLite: Bool = false) {
        if anim != currentAnim {
            currentAnim = anim
            applyPose(anim)
        }
        bobPhase += dt
        // Sheet cycles already animate; skip extra bob when sheet-driven.
        if !sheetDriven, anim == .idle || anim == .run || anim == .walk {
            let runLike = anim == .run
            sprite.position.y = sin(bobPhase * (runLike ? 15 : 3.2)) * (runLike ? 2.6 : 1.3)
        } else if sheetDriven {
            sprite.position.y = 0
        } else {
            sprite.position.y = 0
        }
        if maskMode {
            // Crisp cyan rim — not a blurry ghost head wash.
            sprite.color = ArtCatalog.neonCyan
            sprite.colorBlendFactor = sheetDriven ? 0.18 : 0.28
            tail.color = ArtCatalog.neonCyan
            tail.colorBlendFactor = 0.28
            maskGlow.isHidden = false
            maskGlow.alpha = 0.95
        } else {
            sprite.color = .white
            sprite.colorBlendFactor = 0
            tail.color = .white
            tail.colorBlendFactor = 0
            maskGlow.isHidden = true
            maskGlow.alpha = 0
        }
        if sprite.action(forKey: "frames") == nil {
            switch anim {
            case .jump, .apex: sprite.texture = jumpTex ?? idleTex
            case .fall, .wallSlide: sprite.texture = fallTex ?? idleTex
            case .pounce: sprite.texture = (flopTex ?? pounceTex) ?? idleTex
            case .walk where walkTextures.count > 1:
                sprite.texture = walkTextures[Int(bobPhase * 12) % walkTextures.count]
            case .run where runTextures.count > 1:
                sprite.texture = runTextures[Int(bobPhase * 14) % runTextures.count]
            case .hurt where hurtTextures.count > 0:
                sprite.texture = hurtTextures[min(hurtTextures.count - 1, Int(bobPhase * 20) % hurtTextures.count)]
            case .death where deathTextures.count > 0:
                sprite.texture = deathTextures[min(deathTextures.count - 1, Int(bobPhase * 12))]
            case .pickUp where pickUpTextures.count > 0:
                sprite.texture = pickUpTextures[min(pickUpTextures.count - 1, Int(bobPhase * 18) % pickUpTextures.count)]
            default:
                sprite.texture = idleTex
            }
        }
        tickMotionTrail(anim: anim, maskMode: maskMode, dt: dt, smokeLite: smokeLite)
    }

    private func tpf(_ action: String, fallback: TimeInterval) -> TimeInterval {
        cycles[action]?.timePerFrame ?? fallback
    }

    private func playLoop(_ textures: [SKTexture], action: String, fallbackTPF: TimeInterval) {
        guard textures.count > 1 else {
            sprite.texture = textures.first ?? idleTex
            return
        }
        sprite.run(SKAction.repeatForever(
            SKAction.animate(with: textures, timePerFrame: tpf(action, fallback: fallbackTPF))
        ), withKey: "frames")
    }

    private func playOnce(_ textures: [SKTexture], action: String, fallbackTPF: TimeInterval) {
        guard textures.count > 1 else {
            sprite.texture = textures.first ?? idleTex
            return
        }
        sprite.run(SKAction.animate(with: textures, timePerFrame: tpf(action, fallback: fallbackTPF)), withKey: "frames")
    }

    private func applyPose(_ anim: BanditAnim) {
        stopLimbActions()
        sprite.removeAction(forKey: "frames")
        if sheetDriven { rig.alpha = 0 }
        switch anim {
        case .walk:
            if !sheetDriven { startRunCycle() }
            playLoop(walkTextures.isEmpty ? runTextures : walkTextures, action: "walk", fallbackTPF: 0.06)
        case .run:
            if !sheetDriven { startRunCycle() }
            playLoop(runTextures, action: "run", fallbackTPF: 0.055)
        case .jump:
            if !sheetDriven { poseJump() }
            if jumpTextures.count > 2 {
                let ascent = Array(jumpTextures.prefix(max(2, jumpTextures.count / 2)))
                sprite.run(SKAction.animate(with: ascent, timePerFrame: tpf("jump", fallback: 0.06)), withKey: "frames")
            } else {
                sprite.texture = jumpTex ?? idleTex
            }
        case .apex:
            if !sheetDriven { poseApex() }
            sprite.texture = jumpTextures.dropFirst(jumpTextures.count / 2).first ?? jumpTex ?? idleTex
        case .fall, .wallSlide:
            if !sheetDriven { poseFall() }
            if jumpTextures.count > 2 {
                let descent = Array(jumpTextures.suffix(max(2, jumpTextures.count / 2)))
                sprite.run(SKAction.repeatForever(
                    SKAction.animate(with: descent, timePerFrame: tpf("jump", fallback: 0.08))
                ), withKey: "frames")
            } else {
                sprite.texture = fallTex ?? idleTex
            }
        case .pounce:
            if !sheetDriven { posePounce() }
            if attackTextures.count > 2 {
                playOnce(attackTextures, action: "attack", fallbackTPF: 0.04)
            } else {
                sprite.texture = (flopTex ?? pounceTex) ?? idleTex
            }
        case .hurt:
            playOnce(hurtTextures, action: "hurt", fallbackTPF: 0.04)
        case .death:
            playOnce(deathTextures, action: "death", fallbackTPF: 0.05)
        case .pickUp:
            playOnce(pickUpTextures, action: "pick_up", fallbackTPF: 0.04)
        case .idle:
            if !sheetDriven { startIdleMotion() }
            playLoop(idleTextures, action: "idle", fallbackTPF: 0.12)
        }
    }

    private func stopLimbActions() {
        for n in [armF, armB, legF, legB, tail, head, torso, rig, sprite, body] as [SKNode] {
            n.removeAction(forKey: "limb")
        }
    }

    private func startIdleMotion() {
        resetLimbBases()
        head.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 1.6, duration: 0.5),
            SKAction.moveBy(x: 0, y: -1.6, duration: 0.5),
        ])), withKey: "limb")
        tail.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.45, duration: 0.4),
            SKAction.rotate(toAngle: -0.35, duration: 0.4),
        ])), withKey: "limb")
        armF.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.2, duration: 0.6),
            SKAction.rotate(toAngle: -0.15, duration: 0.6),
        ])), withKey: "limb")
        armB.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: -0.16, duration: 0.6),
            SKAction.rotate(toAngle: 0.16, duration: 0.6),
        ])), withKey: "limb")
        torso.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: 1.05, duration: 0.5),
                SKAction.scaleY(to: 0.96, duration: 0.5),
            ]),
            SKAction.group([
                SKAction.scaleX(to: 1.0, duration: 0.5),
                SKAction.scaleY(to: 1.0, duration: 0.5),
            ]),
        ])), withKey: "limb")
    }

    private func startRunCycle() {
        resetLimbBases()
        let swing: CGFloat = 1.1
        let step: TimeInterval = 0.07
        func cycle(_ node: SKNode, a: CGFloat, b: CGFloat) {
            node.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.rotate(toAngle: a, duration: step),
                SKAction.rotate(toAngle: b, duration: step),
            ])), withKey: "limb")
        }
        cycle(legF, a: swing, b: -swing)
        cycle(legB, a: -swing, b: swing)
        cycle(armF, a: -swing * 0.9, b: swing * 0.9)
        cycle(armB, a: swing * 0.9, b: -swing * 0.9)
        tail.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.75, duration: step),
            SKAction.rotate(toAngle: -0.5, duration: step),
        ])), withKey: "limb")
        torso.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3.0, duration: step),
            SKAction.moveBy(x: 0, y: -3.0, duration: step),
        ])), withKey: "limb")
        head.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 1.4, y: 1.8, duration: step),
            SKAction.moveBy(x: -1.4, y: -1.8, duration: step),
        ])), withKey: "limb")
        // Whole-body squash pulse so the run never reads as a static cutout.
        let face = bodyFaceScale()
        body.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: 0.9 * face, duration: step),
                SKAction.scaleY(to: 1.12, duration: step),
            ]),
            SKAction.group([
                SKAction.scaleX(to: 1.08 * face, duration: step),
                SKAction.scaleY(to: 0.9, duration: step),
            ]),
        ])), withKey: "limb")
    }

    private func poseJump() {
        resetLimbBases()
        armF.zRotation = -1.05
        armB.zRotation = 0.9
        legF.zRotation = -0.65
        legB.zRotation = -0.45
        tail.zRotation = -0.6
        torso.yScale = 1.1
        torso.xScale = 0.9
        head.position = CGPoint(x: 2, y: 22)
        tail.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: -0.35, duration: 0.11),
            SKAction.rotate(toAngle: -0.75, duration: 0.11),
        ])), withKey: "limb")
    }

    private func poseApex() {
        resetLimbBases()
        armF.zRotation = -0.4
        armB.zRotation = 0.4
        legF.zRotation = -0.2
        legB.zRotation = 0.2
        tail.zRotation = 0.2
        torso.yScale = 0.94
        torso.xScale = 1.08
    }

    private func poseFall() {
        resetLimbBases()
        armF.zRotation = 0.9
        armB.zRotation = -0.7
        legF.zRotation = 0.55
        legB.zRotation = 0.35
        tail.zRotation = 0.7
        torso.yScale = 1.14
        torso.xScale = 0.86
        head.zRotation = -0.1
        tail.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.4, duration: 0.1),
            SKAction.rotate(toAngle: 0.9, duration: 0.1),
        ])), withKey: "limb")
    }

    private func posePounce() {
        resetLimbBases()
        armF.zRotation = 1.1
        armB.zRotation = 0.95
        legF.zRotation = 1.0
        legB.zRotation = 0.8
        tail.zRotation = 1.0
        torso.yScale = 0.78
        torso.xScale = 1.22
        head.position = CGPoint(x: 4, y: 14)
    }

    private func resetLimbBases() {
        armF.zRotation = 0; armB.zRotation = 0
        legF.zRotation = 0; legB.zRotation = 0
        tail.zRotation = 0; head.zRotation = 0
        torso.xScale = 1; torso.yScale = 1
        torso.position = CGPoint(x: 0, y: -2)
        head.position = CGPoint(x: 2, y: 20)
        armB.position = CGPoint(x: -14, y: 10)
        armF.position = CGPoint(x: 14, y: 10)
        legB.position = CGPoint(x: -8, y: -14)
        legF.position = CGPoint(x: 8, y: -14)
        tail.position = CGPoint(x: -14, y: 0)
        sprite.position = .zero
        applyFacingScale()
        body.yScale = 1
    }

    private func tickMotionTrail(anim: BanditAnim, maskMode: Bool, dt: CGFloat, smokeLite: Bool) {
        let moving = maskMode || anim == .run || anim == .walk || anim == .pounce || anim == .jump || anim == .apex
        guard moving else { return }
        trailAcc += dt
        let interval: CGFloat = {
            if maskMode { return smokeLite ? 0.09 : 0.04 }
            return smokeLite ? 0.12 : 0.07
        }()
        guard trailAcc >= interval else { return }
        trailAcc = 0
        emitPooledTrail(maskMode: maskMode, dash: anim == .pounce)
    }

    public func emitMaskTrail() {
        emitPooledTrail(maskMode: true, dash: false)
    }

    /// Mask Mode entry: LED pulse + 3 afterimage copies (no giant translucent head).
    public func flashMaskEntry() {
        maskGlow.isHidden = false
        maskGlow.alpha = 1
        maskGlow.removeAllActions()
        maskGlow.setScale(1)
        maskGlow.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.35, duration: 0.08),
                SKAction.fadeAlpha(to: 1, duration: 0.05),
            ]),
            SKAction.scale(to: 1.0, duration: 0.12),
        ]))
        for i in 0..<3 {
            guard let tex = sprite.texture else { continue }
            let ghost = SKSpriteNode(texture: tex, size: sprite.size)
            ghost.anchorPoint = sprite.anchorPoint
            ghost.position = CGPoint(x: -facingSign * CGFloat(10 + i * 12), y: 0)
            ghost.zPosition = -0.4
            ghost.alpha = 0.45 - CGFloat(i) * 0.12
            ghost.color = ArtCatalog.neonCyan
            ghost.colorBlendFactor = 0.55
            ghost.xScale = bodyFaceScale()
            addChild(ghost)
            ghost.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.28),
                    SKAction.moveBy(x: -facingSign * 18, y: 0, duration: 0.28),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
        for _ in 0..<3 { emitMaskTrail() }
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
