// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

public enum ArtCatalog {
    public static let nightSky = SKColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 1)
    public static let neonPink = SKColor(red: 1.0, green: 0.28, blue: 0.62, alpha: 1)
    public static let neonCyan = SKColor(red: 0.15, green: 0.92, blue: 0.95, alpha: 1)
    public static let neonLime = SKColor(red: 0.55, green: 0.98, blue: 0.35, alpha: 1)
    public static let neonOrange = SKColor(red: 1.0, green: 0.55, blue: 0.18, alpha: 1)
    public static let asphalt = SKColor(red: 0.14, green: 0.12, blue: 0.22, alpha: 1)

    /// Soft alpha erode / green despill for chroma fringe on keyed sprites.
    public static func makeDespillShader() -> SKShader {
        SKShader(source: """
        void main() {
          vec4 c = texture2D(u_texture, v_tex_coord);
          float mx = max(c.r, c.b);
          float greenSpill = c.g - mx;
          if (greenSpill > 0.02) {
            c.g = mx + greenSpill * 0.15;
            c.a *= smoothstep(0.02, 0.18, mx + c.a * 0.5);
          }
          if (c.a > 0.05 && c.a < 0.85) {
            c.a *= 0.92;
          }
          gl_FragColor = c;
        }
        """)
    }

    public static func texture(_ key: AssetKey) -> SKTexture? {
        guard let img = AssetManifest.image(for: key) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    public static func textures(_ keys: [AssetKey]) -> [SKTexture] {
        keys.compactMap { texture($0) }
    }

    public static func applyDespill(_ node: SKSpriteNode) {
        node.shader = makeDespillShader()
    }

    /// 64pt raccoon sprite; animates via `BanditVisual`.
    public static func makeBanditVisual() -> BanditVisual {
        BanditVisual()
    }

    public static func makeMopNode() -> SKSpriteNode {
        let tex = texture(.mopPatrol) ?? texture(.mopIdle)
        let n = SKSpriteNode(texture: tex, size: CGSize(width: 72, height: 48))
        n.name = "mop"
        if tex != nil { applyDespill(n) }
        return n
    }

    public static func makeShinyNode() -> SKNode {
        let frames = textures(AssetManifest.shinyFrames)
        let n = SKSpriteNode(texture: frames.first, size: CGSize(width: 28, height: 28))
        n.name = "shiny"
        if let f = frames.first { _ = f; applyDespill(n) }
        if frames.count > 1 {
            n.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.12)))
        } else {
            n.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.3),
                SKAction.scale(to: 0.95, duration: 0.3),
            ])))
        }
        return n
    }

    public static func makeLogoNode() -> SKNode {
        if let tex = texture(.logo) {
            let s = SKSpriteNode(texture: tex)
            let maxW: CGFloat = 320
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

    public static func background(_ key: AssetKey, height: CGFloat) -> SKSpriteNode? {
        guard let tex = texture(key) else { return nil }
        let aspect = tex.size().width / max(tex.size().height, 1)
        let n = SKSpriteNode(texture: tex, size: CGSize(width: height * aspect, height: height))
        n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return n
    }

    public static func tileTexture(index: Int) -> SKTexture? {
        let name = String(format: "tile_%02d", index)
        // Load via relative path
        for root in ["Generated/sprites/tiles", "Assets/Generated/sprites/tiles"] {
            if let u = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: root),
               let data = try? Data(contentsOf: u),
               let img = UIImage(data: data) {
                return SKTexture(image: img)
            }
        }
        return nil
    }
}

/// Animated raccoon using Fire Fox frames + procedural bob for a readable run.
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

    public override init() {
        idleTex = ArtCatalog.texture(.raccoonIdle)
        runTextures = ArtCatalog.textures(AssetManifest.runCycle)
        jumpTex = ArtCatalog.texture(.raccoonJump)
        fallTex = ArtCatalog.texture(.raccoonFall)
        pounceTex = ArtCatalog.texture(.raccoonPounce)
        flopTex = ArtCatalog.texture(.raccoonBellyFlop)
        maskTex = ArtCatalog.texture(.raccoonMaskMode)

        sprite = SKSpriteNode(texture: idleTex, size: CGSize(width: 64, height: 64))
        sprite.name = "sprite"
        ArtCatalog.applyDespill(sprite)

        shadow = SKShapeNode(ellipseOf: CGSize(width: 36, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
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
            if runTextures.count >= 2 {
                // Slightly slower cycle so similar frames still read as motion
                let animate = SKAction.animate(with: runTextures, timePerFrame: 0.09)
                sprite.run(SKAction.repeatForever(animate), withKey: "run")
            } else if let idleTex {
                sprite.texture = idleTex
            }
            bobPhase += dt * 14
            sprite.position.y = sin(bobPhase) * 3
            // Procedural squash as weight shifts
            let squash = 1.0 + sin(bobPhase * 2) * 0.04
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
        if maskMode, anim != .idle, let maskTex, anim == .idle {
            sprite.texture = maskTex
        }
        // Mask Mode: cyan glow via blend
        sprite.color = maskMode ? ArtCatalog.neonCyan : .white
        sprite.colorBlendFactor = maskMode ? 0.25 : 0
    }
}
#endif
