// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Cinder & Crown Creative publisher splash (studio ident) before the game title.
@MainActor
public enum PublisherIdent {
    public static let presentsLine = "Cinder & Crown Creative Presents"
    public static let logoCredit = "Cinder & Crown logo, © Cinder and Crown LLC, used by permission."
    public static let crimson = SKColor(red: 0x6E / 255, green: 0x0F / 255, blue: 0x16 / 255, alpha: 1)
    public static let gold = SKColor(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255, alpha: 1)
    public static let cream = SKColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1)
    public static let charcoal = SKColor(red: 0.07, green: 0.06, blue: 0.055, alpha: 1)

    /// Total length target 1.8…2.2 s (Reduce Motion uses the short end).
    public static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 1.85 : 2.05
    }

    public static var reduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    public static func makeLogoSprite() -> SKSpriteNode {
        if let img = UIImage(named: "CinderCrownMute") {
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            let node = SKSpriteNode(texture: tex)
            node.name = "publisherLogo"
            // Keep authored crimson/gold — no neon recolor.
            node.colorBlendFactor = 0
            return node
        }
        // Fallback glyph if catalog missing (tests / Linux stubs).
        let node = SKSpriteNode(color: gold, size: CGSize(width: 120, height: 120))
        node.name = "publisherLogo"
        return node
    }

    /// Builds the full-screen ident tree (caller owns add/remove).
    public static func buildRoot(sceneSize: CGSize) -> SKNode {
        let root = SKNode()
        root.name = "publisherIdentRoot"
        root.zPosition = 500

        let bg = SKSpriteNode(color: charcoal, size: CGSize(width: sceneSize.width * 4, height: sceneSize.height * 4))
        bg.name = "publisherBg"
        bg.zPosition = 0
        root.addChild(bg)

        let emberGlow = SKShapeNode(circleOfRadius: min(sceneSize.width, sceneSize.height) * 0.42)
        emberGlow.name = "publisherEmberGlow"
        emberGlow.fillColor = crimson.withAlphaComponent(0.22)
        emberGlow.strokeColor = gold.withAlphaComponent(0.18)
        emberGlow.lineWidth = 1
        emberGlow.glowWidth = 28
        emberGlow.zPosition = 1
        emberGlow.alpha = 0
        root.addChild(emberGlow)

        let logo = makeLogoSprite()
        let side = min(sceneSize.width, sceneSize.height) * 0.34
        logo.size = CGSize(width: side, height: side)
        logo.position = CGPoint(x: 0, y: side * 0.18)
        logo.zPosition = 10
        logo.alpha = 0
        logo.setScale(0.92)
        root.addChild(logo)

        // Soft gold light sweep across the crown (clipped to logo bounds via crop).
        let sweep = SKSpriteNode(color: gold.withAlphaComponent(0.55), size: CGSize(width: side * 0.22, height: side * 1.15))
        sweep.name = "publisherSweep"
        sweep.zPosition = 11
        sweep.alpha = 0
        sweep.blendMode = .add
        logo.addChild(sweep)

        let title = SKLabelNode(fontNamed: "Georgia-Italic")
        title.name = "publisherTitle"
        title.text = presentsLine
        title.fontSize = 15
        title.fontColor = cream
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: -side * 0.55)
        title.zPosition = 12
        title.alpha = 0
        // Wide tracking via letter spacing isn't available on SKLabelNode — use thin sans fallback spacing feel.
        root.addChild(title)

        let credit = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
        credit.name = "publisherCredit"
        credit.text = logoCredit
        credit.fontSize = 8
        credit.fontColor = cream.withAlphaComponent(0.4)
        credit.horizontalAlignmentMode = .center
        credit.verticalAlignmentMode = .center
        credit.position = CGPoint(x: 0, y: -sceneSize.height * 0.42)
        credit.zPosition = 12
        credit.alpha = 0
        root.addChild(credit)

        if let embers = emberEmitter(sceneSize: sceneSize) {
            embers.name = "publisherEmbers"
            embers.zPosition = 8
            embers.position = CGPoint(x: 0, y: -side * 0.1)
            root.addChild(embers)
        }

        return root
    }

    public static func emberEmitter(sceneSize: CGSize) -> SKEmitterNode? {
        let e = SKEmitterNode()
        e.particleBirthRate = 28
        e.numParticlesToEmit = 0
        e.particleLifetime = 1.4
        e.particleLifetimeRange = 0.5
        e.particleSize = CGSize(width: 3, height: 3)
        e.particleScale = 0.6
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = -0.25
        e.particleAlpha = 0.85
        e.particleAlphaSpeed = -0.55
        e.particleColor = gold
        e.particleColorBlendFactor = 1
        e.particleSpeed = 28
        e.particleSpeedRange = 18
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi / 3
        e.particlePositionRange = CGVector(dx: sceneSize.width * 0.35, dy: 8)
        e.yAcceleration = 12
        e.particleBlendMode = .add
        return e
    }

    /// Ignite → title → hold → fade. Calls `onFinished` on the scene action.
    public static func runPresentation(
        on root: SKNode,
        reduceMotion: Bool,
        onFinished: @escaping () -> Void
    ) {
        let total = duration(reduceMotion: reduceMotion)
        guard let logo = root.childNode(withName: "publisherLogo"),
              let title = root.childNode(withName: "publisherTitle"),
              let credit = root.childNode(withName: "publisherCredit"),
              let glow = root.childNode(withName: "publisherEmberGlow")
        else {
            onFinished()
            return
        }
        let sweep = logo.childNode(withName: "publisherSweep")
        let side = max(logo.frame.width, 1)

        if reduceMotion {
            logo.run(SKAction.fadeIn(withDuration: 0.35))
            title.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.2),
                SKAction.fadeIn(withDuration: 0.35),
            ]))
            credit.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.25),
                SKAction.fadeAlpha(to: 0.45, duration: 0.3),
            ]))
            glow.run(SKAction.fadeAlpha(to: 0.5, duration: 0.35))
            root.run(SKAction.sequence([
                SKAction.wait(forDuration: total - 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.run(onFinished),
            ]), withKey: "publisherIdent")
            return
        }

        // Ignite logo + ember glow.
        logo.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.55),
        ]))
        glow.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.85, duration: 0.5),
            SKAction.fadeAlpha(to: 0.45, duration: 0.7),
        ]))

        // Gold light sweep across the crown.
        if let sweep {
            sweep.position = CGPoint(x: -side * 0.55, y: side * 0.18)
            sweep.alpha = 0
            sweep.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.35),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.7, duration: 0.12),
                    SKAction.moveTo(x: side * 0.55, duration: 0.55),
                ]),
                SKAction.fadeOut(withDuration: 0.18),
            ]))
        }

        title.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.55),
            SKAction.fadeIn(withDuration: 0.35),
        ]))
        credit.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.65),
            SKAction.fadeAlpha(to: 0.45, duration: 0.3),
        ]))

        let hold = max(0.25, total - 1.35)
        root.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.55 + 0.35 + hold),
            SKAction.fadeOut(withDuration: 0.45),
            SKAction.run(onFinished),
        ]), withKey: "publisherIdent")
    }
}
#endif
