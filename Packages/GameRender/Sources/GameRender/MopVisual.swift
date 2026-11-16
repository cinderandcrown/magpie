// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// MOP bot enemy — Spriterrific `mop_bot` sheets (west-facing).
@MainActor
public final class MopVisual: SKSpriteNode {
    private var walk: [SKTexture] = []
    private var attack: [SKTexture] = []
    private var hurt: [SKTexture] = []
    private var death: [SKTexture] = []
    private var tpfWalk: TimeInterval = 1.0 / 24
    private var tpfAttack: TimeInterval = 1.0 / 24
    private var current: MopAnim = .walk
    private var usesWestSheets = true
    private var facingSign: CGFloat = 1

    public convenience init() {
        let walkC = SpriteCycles.mopBot("walk")
        let tex = walkC?.textures.first
            ?? ArtCatalog.texture(.mopPatrol)
            ?? ArtCatalog.texture(.mopIdle)
            ?? SKTexture()
        self.init(texture: tex, color: .clear, size: SpriteCycles.mopDisplaySize)
        name = "mop"
        anchorPoint = CGPoint(x: 0.5, y: walkC?.footAnchorY ?? 0.11)
        ArtCatalog.applyDespill(self)
        if let walkC, !walkC.textures.isEmpty {
            walk = walkC.textures
            tpfWalk = walkC.timePerFrame
            usesWestSheets = true
        }
        if let c = SpriteCycles.mopBot("attack") {
            attack = c.textures
            tpfAttack = c.timePerFrame
        }
        if let c = SpriteCycles.mopBot("hurt") { hurt = c.textures }
        if let c = SpriteCycles.mopBot("death") { death = c.textures }
        show(anim: .walk, facing: 1)
    }

    public func show(anim: MopAnim, facing: Double) {
        facingSign = facing >= 0 ? 1 : -1
        // West sheets → flip when facing right.
        xScale = usesWestSheets ? -facingSign : facingSign
        yScale = abs(yScale) == 0 ? 1 : abs(yScale)
        guard anim != current || action(forKey: "frames") == nil else { return }
        current = anim
        removeAction(forKey: "frames")
        switch anim {
        case .walk:
            playLoop(walk.isEmpty ? [texture].compactMap { $0 } : walk, tpf: tpfWalk)
        case .attack:
            playOnce(attack.isEmpty ? walk : attack, tpf: tpfAttack)
        case .hurt:
            playOnce(hurt.isEmpty ? walk : hurt, tpf: 1.0 / 24)
        case .death:
            playOnce(death.isEmpty ? walk : death, tpf: 1.0 / 18)
        }
    }

    private func playLoop(_ textures: [SKTexture], tpf: TimeInterval) {
        guard textures.count > 1 else {
            texture = textures.first
            return
        }
        run(SKAction.repeatForever(SKAction.animate(with: textures, timePerFrame: tpf)), withKey: "frames")
    }

    private func playOnce(_ textures: [SKTexture], tpf: TimeInterval) {
        guard textures.count > 1 else {
            texture = textures.first
            return
        }
        run(SKAction.animate(with: textures, timePerFrame: tpf), withKey: "frames")
    }
}

/// MOP-9000 boss — Spriterrific sheets; tread scroll while moving until tread_roll arrives.
@MainActor
public final class BossVisual: SKNode {
    public let sprite: SKSpriteNode
    /// Swappable tread layer: offset while moving; replace textures when tread_roll sheet lands.
    public let tread: SKSpriteNode
    private var idle: [SKTexture] = []
    private var walk: [SKTexture] = []
    private var attack: [SKTexture] = []
    private var hurt: [SKTexture] = []
    private var death: [SKTexture] = []
    private var tpf: [String: TimeInterval] = [:]
    private var current = "idle"
    private var treadPhase: CGFloat = 0
    private var usesWestSheets = true
    private var facingSign: CGFloat = 1
    /// When true, prefer a future `tread_roll` cycle instead of UV offset.
    public var useTreadRollSheet = false
    private var treadRoll: [SKTexture] = []

    public override init() {
        let idleC = SpriteCycles.mop9000("idle")
        let tex = idleC?.textures.first ?? SKTexture()
        sprite = SKSpriteNode(texture: tex, size: SpriteCycles.bossDisplaySize)
        sprite.name = "bossSprite"
        sprite.anchorPoint = CGPoint(x: 0.5, y: idleC?.footAnchorY ?? 0.11)
        ArtCatalog.applyDespill(sprite)

        tread = SKSpriteNode(color: SKColor(white: 0.15, alpha: 0.0), size: CGSize(width: 90, height: 18))
        tread.name = "tread"
        tread.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tread.position = CGPoint(x: 0, y: -SpriteCycles.bossDisplaySize.height * 0.28)
        tread.zPosition = 0.5
        // Placeholder tread stripe — scrolled in code; swap for tread_roll sheet when delivered.
        tread.color = ArtCatalog.neonCyan.withAlphaComponent(0.35)
        tread.colorBlendFactor = 1

        super.init()
        addChild(sprite)
        addChild(tread)
        name = "mop9000"

        if let idleC {
            idle = idleC.textures
            tpf["idle"] = idleC.timePerFrame
            usesWestSheets = true
        }
        if let c = SpriteCycles.mop9000("walk") {
            walk = c.textures
            tpf["walk"] = c.timePerFrame
        }
        if let c = SpriteCycles.mop9000("attack") {
            attack = c.textures
            tpf["attack"] = c.timePerFrame
        }
        if let c = SpriteCycles.mop9000("hurt") {
            hurt = c.textures
            tpf["hurt"] = c.timePerFrame
        }
        if let c = SpriteCycles.mop9000("death") {
            death = c.textures
            tpf["death"] = c.timePerFrame
        }
        // Optional future sheet path — keep swappable.
        if let c = SpriteCycles.mop9000("tread_roll"), !c.textures.isEmpty {
            treadRoll = c.textures
            useTreadRollSheet = true
            tpf["tread_roll"] = c.timePerFrame
        }
        show(action: "idle", facing: 1, moving: false, dt: 0)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    public func show(action: String, facing: Double, moving: Bool, dt: CGFloat) {
        facingSign = facing >= 0 ? 1 : -1
        let face = usesWestSheets ? -facingSign : facingSign
        sprite.xScale = face
        if action != current || sprite.action(forKey: "frames") == nil {
            current = action
            sprite.removeAction(forKey: "frames")
            let textures: [SKTexture]
            switch action {
            case "walk": textures = walk.isEmpty ? idle : walk
            case "attack": textures = attack.isEmpty ? idle : attack
            case "hurt": textures = hurt.isEmpty ? idle : hurt
            case "death": textures = death.isEmpty ? idle : death
            default: textures = idle
            }
            let rate = tpf[action] ?? (1.0 / 12)
            if textures.count > 1 {
                let anim = SKAction.animate(with: textures, timePerFrame: rate)
                if action == "idle" || action == "walk" {
                    sprite.run(SKAction.repeatForever(anim), withKey: "frames")
                } else {
                    sprite.run(anim, withKey: "frames")
                }
            } else if let t = textures.first {
                sprite.texture = t
            }
        }
        // Tread: scroll offset in code, or play tread_roll when present.
        if moving {
            treadPhase += dt * 8
            if useTreadRollSheet, treadRoll.count > 1 {
                if tread.action(forKey: "tread") == nil {
                    tread.texture = treadRoll[0]
                    tread.size = CGSize(width: 100, height: 24)
                    tread.alpha = 1
                    tread.run(SKAction.repeatForever(
                        SKAction.animate(with: treadRoll, timePerFrame: tpf["tread_roll"] ?? 0.05)
                    ), withKey: "tread")
                }
            } else {
                tread.removeAction(forKey: "tread")
                tread.alpha = 0.55
                tread.position.x = CGFloat(sin(treadPhase)) * 6 * face
            }
        } else {
            tread.removeAction(forKey: "tread")
            tread.alpha = 0.25
            tread.position.x = 0
        }
    }
}
#endif
