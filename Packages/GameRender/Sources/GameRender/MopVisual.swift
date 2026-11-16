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

/// MOP-9000 boss — Spriterrific sheets. Movement uses `tread_roll` (not walk);
/// a light code tread offset remains as polish on top of the sheet.
@MainActor
public final class BossVisual: SKNode {
    public let sprite: SKSpriteNode
    /// Polish tread stripe under the body; subtle x-offset while moving.
    public let tread: SKSpriteNode
    private var idle: [SKTexture] = []
    private var treadRoll: [SKTexture] = []
    private var walkFallback: [SKTexture] = []
    private var attack: [SKTexture] = []
    private var hurt: [SKTexture] = []
    private var death: [SKTexture] = []
    private var tpf: [String: TimeInterval] = [:]
    private var current = "idle"
    private var treadPhase: CGFloat = 0
    private var usesWestSheets = true
    private var facingSign: CGFloat = 1

    public override init() {
        let idleC = SpriteCycles.mop9000("idle")
        let tex = idleC?.textures.first ?? SKTexture()
        sprite = SKSpriteNode(texture: tex, size: SpriteCycles.bossDisplaySize)
        sprite.name = "bossSprite"
        sprite.anchorPoint = CGPoint(x: 0.5, y: idleC?.footAnchorY ?? 0.11)
        ArtCatalog.applyDespill(sprite)

        tread = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.28), size: CGSize(width: 88, height: 14))
        tread.name = "tread"
        tread.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tread.position = CGPoint(x: 0, y: -SpriteCycles.bossDisplaySize.height * 0.30)
        tread.zPosition = -0.2
        tread.alpha = 0.2

        super.init()
        addChild(sprite)
        addChild(tread)
        name = "mop9000"

        if let idleC {
            idle = idleC.textures
            tpf["idle"] = idleC.timePerFrame
            usesWestSheets = true
        }
        if let c = SpriteCycles.mop9000("tread_roll"), !c.textures.isEmpty {
            treadRoll = c.textures
            tpf["tread_roll"] = c.timePerFrame
        }
        if let c = SpriteCycles.mop9000("walk") {
            walkFallback = c.textures
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
        show(action: "idle", facing: 1, moving: false, dt: 0)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    public func show(action: String, facing: Double, moving: Bool, dt: CGFloat) {
        facingSign = facing >= 0 ? 1 : -1
        let face = usesWestSheets ? -facingSign : facingSign
        sprite.xScale = face

        // Movement sheet = tread_roll (replaces walk). Idle/attack/hurt/death unchanged.
        let resolved: String = {
            if moving || action == "walk" || action == "tread_roll" {
                return treadRoll.isEmpty ? "walk" : "tread_roll"
            }
            return action
        }()

        if resolved != current || sprite.action(forKey: "frames") == nil {
            current = resolved
            sprite.removeAction(forKey: "frames")
            let textures: [SKTexture]
            switch resolved {
            case "tread_roll":
                textures = treadRoll.isEmpty ? (walkFallback.isEmpty ? idle : walkFallback) : treadRoll
            case "walk":
                textures = walkFallback.isEmpty ? idle : walkFallback
            case "attack":
                textures = attack.isEmpty ? idle : attack
            case "hurt":
                textures = hurt.isEmpty ? idle : hurt
            case "death":
                textures = death.isEmpty ? idle : death
            default:
                textures = idle
            }
            let rate = tpf[resolved] ?? (1.0 / 12)
            if textures.count > 1 {
                let anim = SKAction.animate(with: textures, timePerFrame: rate)
                if resolved == "idle" || resolved == "walk" || resolved == "tread_roll" {
                    sprite.run(SKAction.repeatForever(anim), withKey: "frames")
                } else {
                    sprite.run(anim, withKey: "frames")
                }
            } else if let t = textures.first {
                sprite.texture = t
            }
        }

        // Boss tread rumble loop while moving (juice SFX pack).
        #if canImport(AVFoundation)
        JuiceSound.shared.setBossTreadMoving(moving)
        #endif

        // Light code tread scroll as polish under the tread_roll body sheet.
        if moving {
            treadPhase += dt * 10
            tread.alpha = 0.45
            tread.position.x = CGFloat(sin(treadPhase)) * 5 * face
        } else {
            tread.alpha = 0.18
            tread.position.x = 0
        }
    }
}
#endif
