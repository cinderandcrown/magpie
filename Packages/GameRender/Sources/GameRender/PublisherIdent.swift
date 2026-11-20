// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Cinder & Crown Creative publisher splash — matched to Trash Stack (`PublisherIdentView`).
/// Mute logo only (phoenix + crown, no wordmark). Fixed 168 pt mark, centered; never stretched.
@MainActor
public enum PublisherIdent {
    public static let presentsLine = "Cinder & Crown Creative Presents"
    public static let logoCredit = "Cinder & Crown logo, © Cinder and Crown LLC, used by permission."
    /// Shared with Trash Stack splash.
    public static let crimson = SKColor(red: 0x6E / 255, green: 0x0F / 255, blue: 0x16 / 255, alpha: 1)
    public static let gold = SKColor(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255, alpha: 1)
    public static let cream = SKColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
    public static let charcoal = SKColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
    /// Identical to Trash Stack `.frame(width: 168, height: 168)`.
    public static let logoPointSize: CGFloat = 168
    public static let titleFontSize: CGFloat = 17
    public static let titleTracking: CGFloat = 3.2
    public static let seenKey = "ncb.identSeen"

    public static var reduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    public static var hasSeenIdent: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    public static func markIdentSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }

    public static func makeLogoSprite() -> SKSpriteNode {
        if let img = UIImage(named: "CinderCrownMute") {
            let tex = SKTexture(image: img)
            tex.filteringMode = .linear
            let node = SKSpriteNode(texture: tex)
            node.name = "publisherLogo"
            node.colorBlendFactor = 0
            return node
        }
        let node = SKSpriteNode(color: gold, size: CGSize(width: logoPointSize, height: logoPointSize))
        node.name = "publisherLogo"
        return node
    }

    /// Charcoal-only first paint (does not decode logo) — first frame must not wait on art.
    public static func buildCharcoalRoot(sceneSize: CGSize) -> SKNode {
        let root = SKNode()
        root.name = "publisherIdentRoot"
        root.zPosition = 500
        let bg = SKSpriteNode(color: charcoal, size: CGSize(width: sceneSize.width * 4, height: sceneSize.height * 4))
        bg.name = "publisherBg"
        bg.zPosition = 0
        root.addChild(bg)
        return root
    }

    /// Logo + presents line + optional ember glow (added after first charcoal frame).
    public static func attachLogoArt(to root: SKNode, sceneSize: CGSize) {
        root.childNode(withName: "publisherArt")?.removeFromParent()
        let art = SKNode()
        art.name = "publisherArt"
        art.zPosition = 5
        art.alpha = 0

        let emberGlow = SKShapeNode(circleOfRadius: 340)
        emberGlow.name = "publisherEmberGlow"
        emberGlow.fillColor = crimson.withAlphaComponent(0.55)
        emberGlow.strokeColor = .clear
        emberGlow.glowWidth = 0
        emberGlow.zPosition = 1
        emberGlow.alpha = 0.35
        emberGlow.blendMode = .alpha
        art.addChild(emberGlow)

        let logo = makeLogoSprite()
        // Fixed point size — same in portrait Trash Stack and landscape NCB; never stretch to scene.
        logo.size = CGSize(width: logoPointSize, height: logoPointSize)
        logo.position = .zero
        logo.zPosition = 10
        logo.alpha = 0
        logo.setScale(0.92)
        art.addChild(logo)

        let sweep = SKSpriteNode(color: gold.withAlphaComponent(0.55), size: CGSize(width: 56, height: 180))
        sweep.name = "publisherSweep"
        sweep.zRotation = 18 * .pi / 180
        sweep.zPosition = 11
        sweep.alpha = 0
        sweep.blendMode = .add
        sweep.position = CGPoint(x: -0.6 * 140, y: 0)
        logo.addChild(sweep)

        let title = SKLabelNode()
        title.name = "publisherTitle"
        title.attributedText = presentsAttributed()
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        // Trash Stack VStack spacing 22 under a 168 mark ≈ title sits below the logo.
        title.position = CGPoint(x: 0, y: -(logoPointSize * 0.5 + 28))
        title.zPosition = 12
        title.alpha = 0
        art.addChild(title)

        if !reduceMotionEnabled, let embers = emberEmitter(sceneSize: sceneSize) {
            embers.name = "publisherEmbers"
            embers.zPosition = 8
            embers.position = .zero
            embers.particleBirthRate = 0
            art.addChild(embers)
        }

        root.addChild(art)
    }

    private static func presentsAttributed() -> NSAttributedString {
        let font = UIFont(name: "Georgia", size: titleFontSize)
            ?? UIFont.systemFont(ofSize: titleFontSize, weight: .light)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        return NSAttributedString(string: presentsLine, attributes: [
            .font: font,
            .foregroundColor: cream.withAlphaComponent(0.95),
            .kern: titleTracking,
            .paragraphStyle: para,
        ])
    }

    public static func emberEmitter(sceneSize: CGSize) -> SKEmitterNode? {
        let e = SKEmitterNode()
        e.particleBirthRate = 18
        e.numParticlesToEmit = 0
        e.particleLifetime = 1.4
        e.particleLifetimeRange = 0.5
        e.particleSize = CGSize(width: 2.4, height: 3.2)
        e.particleScale = 0.7
        e.particleScaleRange = 0.35
        e.particleScaleSpeed = -0.25
        e.particleAlpha = 0.55
        e.particleAlphaSpeed = -0.35
        e.particleColor = gold
        e.particleColorBlendFactor = 1
        e.particleSpeed = 18
        e.particleSpeedRange = 10
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi / 3
        e.particlePositionRange = CGVector(dx: min(sceneSize.width, 420) * 0.45, dy: 8)
        e.yAcceleration = 12
        e.particleBlendMode = .add
        return e
    }

    /// Trash Stack timing: ignite → sweep → title → short hold → fade (or blink if seen / Reduce Motion).
    public static func runPresentation(
        on root: SKNode,
        reduceMotion: Bool,
        smokeHold: Bool = false,
        playWhoosh: (() -> Void)? = nil,
        onFinished: @escaping () -> Void
    ) {
        guard let art = root.childNode(withName: "publisherArt"),
              let logo = art.childNode(withName: "publisherLogo"),
              let title = art.childNode(withName: "publisherTitle"),
              let glow = art.childNode(withName: "publisherEmberGlow")
        else {
            onFinished()
            return
        }
        let sweep = logo.childNode(withName: "publisherSweep")
        let embers = art.childNode(withName: "publisherEmbers") as? SKEmitterNode
        art.alpha = 1

        // Smoke / CI: hold final pose so slow screenshots still catch charcoal + logo.
        if smokeHold {
            logo.alpha = 1
            logo.setScale(1)
            title.alpha = 1
            glow.alpha = 0.55
            sweep?.alpha = 0
            root.alpha = 1
            root.run(SKAction.sequence([
                SKAction.wait(forDuration: 16.5),
                SKAction.fadeOut(withDuration: 0.45),
                SKAction.run {
                    markIdentSeen()
                    onFinished()
                },
            ]), withKey: "publisherIdent")
            return
        }

        let seenBefore = hasSeenIdent
        if reduceMotion || seenBefore {
            logo.alpha = 1
            logo.setScale(1)
            title.alpha = 1
            glow.alpha = 0.55
            let hold: TimeInterval = seenBefore ? 0.28 : 0.45
            root.run(SKAction.sequence([
                SKAction.wait(forDuration: hold),
                SKAction.run {
                    markIdentSeen()
                    onFinished()
                },
            ]), withKey: "publisherIdent")
            return
        }

        // Match Trash Stack: logo 0.28s easeOut, sweep 0.55s, title after 220ms (0.22s),
        // hold 420ms, fade 0.2s + 180ms settle.
        logo.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.28),
            SKAction.scale(to: 1.0, duration: 0.28),
        ]))
        glow.run(SKAction.fadeAlpha(to: 0.85, duration: 0.28))
        if let sweep {
            sweep.position = CGPoint(x: -0.6 * 140, y: 0)
            sweep.alpha = 0
            sweep.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.7, duration: 0.12),
                    SKAction.moveTo(x: 0.7 * 140, duration: 0.55),
                ]),
                SKAction.fadeOut(withDuration: 0.12),
            ]))
        }
        playWhoosh?()
        embers?.particleBirthRate = 18

        title.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.22),
            SKAction.fadeIn(withDuration: 0.22),
        ]))
        glow.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.28),
            SKAction.fadeAlpha(to: 0.55, duration: 0.4),
        ]))

        root.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.22 + 0.22 + 0.42),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.run {
                    embers?.particleBirthRate = 0
                },
            ]),
            SKAction.wait(forDuration: 0.18),
            SKAction.run {
                markIdentSeen()
                onFinished()
            },
        ]), withKey: "publisherIdent")
    }
}
#endif
