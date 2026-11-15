// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Mission 1 neon alley heist — Bandit runs, Pounces, Belly Flops, banks Shinies.
public final class HeistScene: SKScene {
    private var sim: Sim!
    private var tuning = Tuning.default
    private var worldRoot = SKNode()
    private var banditNode: SKNode!
    private var shinyNodes: [Int: SKNode] = [:]
    private var dummyNodes: [Int: SKNode] = [:]
    private var hud = SKNode()
    private var carriedLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var bankedLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var hintLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var outcomeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var fpsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var pounceButton: SKShapeNode?
    private var variantLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    private var touchInterp = TouchInterpreter()
    private var activeTouch: UITouch?
    private var dragOriginWorld = Vec2.zero
    private var lastMove = Vec2.zero
    private var holdActive = false
    private var pendingPounce = false
    private var pendingFlop = false
    private var buttonPounce = false

    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var fpsAcc: TimeInterval = 0
    private var displayedFPS = 0
    private var hitPauseRemaining: TimeInterval = 0
    private var cameraLook = CGPoint.zero

    public override func didMove(to view: SKView) {
        backgroundColor = ArtCatalog.nightSky
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        do {
            let map = try NeonAlleyMap.load()
            sim = Sim(map: map, tuning: tuning, seed: 7, variant: .a)
        } catch {
            sim = Sim(map: try! TileMap.parse("###\n#@#\n###"), tuning: tuning)
        }

        worldRoot.name = "world"
        addChild(worldRoot)
        buildTileVisuals()
        banditNode = ArtCatalog.makeBanditNode()
        banditNode.zPosition = 50
        worldRoot.addChild(banditNode)

        for shiny in sim.state.shinies {
            let n = ArtCatalog.makeShinyNode()
            n.position = cg(shiny.position)
            n.zPosition = 20
            worldRoot.addChild(n)
            shinyNodes[shiny.id] = n
        }
        for dummy in sim.state.dummies {
            let n = ArtCatalog.makeDummyNode()
            n.position = cg(dummy.position)
            n.zPosition = 25
            worldRoot.addChild(n)
            dummyNodes[dummy.id] = n
        }

        setupHUD()
        JuiceSound.shared.prepare()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).prepare()
        #endif
        syncFromSim(force: true)
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        layoutHUD()
    }

    private func buildTileVisuals() {
        let tile = CGFloat(tuning.tileSize)
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                switch kind {
                case .empty:
                    continue
                case .water:
                    let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    n.fillColor = ArtCatalog.water
                    n.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.35)
                    n.lineWidth = 1
                    n.position = pos
                    n.zPosition = 1
                    worldRoot.addChild(n)
                case .wall:
                    let n = SKShapeNode(rectOf: CGSize(width: tile - 1, height: tile - 1), cornerRadius: 3)
                    n.fillColor = ArtCatalog.wall
                    n.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.4)
                    n.lineWidth = 1
                    n.position = pos
                    n.zPosition = 5
                    // Neon window
                    let win = SKShapeNode(rectOf: CGSize(width: 8, height: 10), cornerRadius: 1)
                    win.fillColor = (x + y) % 2 == 0 ? ArtCatalog.neonPink : ArtCatalog.neonCyan
                    win.strokeColor = .clear
                    win.alpha = 0.85
                    win.position = CGPoint(x: 0, y: 4)
                    n.addChild(win)
                    worldRoot.addChild(n)
                case .crate:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.85, height: tile * 0.85), cornerRadius: 2)
                    n.fillColor = ArtCatalog.crate
                    n.strokeColor = ArtCatalog.neonOrange
                    n.lineWidth = 1
                    n.position = pos
                    n.zPosition = 8
                    worldRoot.addChild(n)
                case .latch:
                    let pole = SKShapeNode(rectOf: CGSize(width: 4, height: tile), cornerRadius: 1)
                    pole.fillColor = ArtCatalog.neonCyan
                    pole.strokeColor = .clear
                    pole.position = pos
                    pole.zPosition = 6
                    worldRoot.addChild(pole)
                    let lamp = SKShapeNode(circleOfRadius: 6)
                    lamp.fillColor = ArtCatalog.neonOrange
                    lamp.strokeColor = .clear
                    lamp.glowWidth = 4
                    lamp.position = CGPoint(x: pos.x, y: pos.y + tile * 0.35)
                    lamp.zPosition = 7
                    worldRoot.addChild(lamp)
                    let ground = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    ground.fillColor = ArtCatalog.asphalt
                    ground.strokeColor = .clear
                    ground.position = pos
                    ground.zPosition = 0
                    worldRoot.addChild(ground)
                case .stash:
                    let ground = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    ground.fillColor = ArtCatalog.sidewalk
                    ground.strokeColor = .clear
                    ground.position = pos
                    ground.zPosition = 0
                    worldRoot.addChild(ground)
                    let stash = ArtCatalog.makeStashNode()
                    stash.position = pos
                    stash.zPosition = 9
                    worldRoot.addChild(stash)
                case .ramp:
                    let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    n.fillColor = ArtCatalog.sidewalk
                    n.strokeColor = ArtCatalog.neonLime.withAlphaComponent(0.5)
                    n.position = pos
                    n.zPosition = 0
                    worldRoot.addChild(n)
                    let stripe = SKShapeNode(rectOf: CGSize(width: tile * 0.8, height: 4))
                    stripe.fillColor = ArtCatalog.neonLime
                    stripe.strokeColor = .clear
                    stripe.zRotation = -.pi / 8
                    stripe.position = pos
                    stripe.zPosition = 1
                    worldRoot.addChild(stripe)
                default:
                    let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    n.fillColor = ArtCatalog.asphalt
                    n.strokeColor = SKColor(white: 1, alpha: 0.04)
                    n.lineWidth = 0.5
                    n.position = pos
                    n.zPosition = 0
                    worldRoot.addChild(n)
                    // Neon road edge dashes
                    if (x + y) % 3 == 0 {
                        let dash = SKShapeNode(rectOf: CGSize(width: 6, height: 2))
                        dash.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.25)
                        dash.strokeColor = .clear
                        dash.position = pos
                        dash.zPosition = 0.5
                        worldRoot.addChild(dash)
                    }
                }
            }
        }
    }

    private func setupHUD() {
        hud.zPosition = 1000
        addChild(hud)

        for (label, color) in [
            (carriedLabel, ArtCatalog.shinyGold),
            (bankedLabel, ArtCatalog.neonLime),
            (comboLabel, ArtCatalog.neonPink),
            (hintLabel, SKColor.white),
            (outcomeLabel, ArtCatalog.neonCyan),
            (variantLabel, ArtCatalog.neonCyan),
        ] as [(SKLabelNode, SKColor)] {
            label.fontSize = label === outcomeLabel ? 28 : (label === hintLabel || label === variantLabel ? 12 : 16)
            label.fontColor = color
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            hud.addChild(label)
        }
        outcomeLabel.horizontalAlignmentMode = .center
        outcomeLabel.verticalAlignmentMode = .center
        outcomeLabel.isHidden = true
        hintLabel.text = "Drag move · Tap Pounce · Air-tap Belly Flop · Hold Tail Swing"
        hintLabel.alpha = 0.85
        variantLabel.text = "A: free Pounce  (tap HUD corner for B)"
        variantLabel.horizontalAlignmentMode = .right

        #if DEBUG
        fpsLabel.fontSize = 12
        fpsLabel.fontColor = .white
        fpsLabel.horizontalAlignmentMode = .left
        fpsLabel.verticalAlignmentMode = .bottom
        fpsLabel.text = "FPS --"
        hud.addChild(fpsLabel)
        #endif

        layoutHUD()
    }

    private func layoutHUD() {
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        carriedLabel.position = CGPoint(x: -halfW + 16, y: halfH - 16)
        bankedLabel.position = CGPoint(x: -halfW + 16, y: halfH - 36)
        comboLabel.position = CGPoint(x: -halfW + 16, y: halfH - 56)
        hintLabel.position = CGPoint(x: -halfW + 16, y: -halfH + 56)
        variantLabel.position = CGPoint(x: halfW - 16, y: halfH - 16)
        outcomeLabel.position = .zero
        #if DEBUG
        fpsLabel.position = CGPoint(x: -halfW + 16, y: -halfH + 16)
        #endif

        pounceButton?.removeFromParent()
        pounceButton = nil
        if sim?.state.controlVariant == .b {
            let btn = SKShapeNode(circleOfRadius: 34)
            btn.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.55)
            btn.strokeColor = ArtCatalog.neonPink
            btn.lineWidth = 2
            btn.position = CGPoint(x: halfW - 52, y: -halfH + 72)
            btn.name = "pounceButton"
            let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
            t.text = "POUNCE"
            t.fontSize = 11
            t.fontColor = .white
            t.verticalAlignmentMode = .center
            btn.addChild(t)
            hud.addChild(btn)
            pounceButton = btn
        }
    }

    private func cg(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    // MARK: - Touch

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let hudLoc = touch.location(in: hud)

        // Toggle variant via top-right label hit
        if abs(hudLoc.x - variantLabel.position.x) < 120 && abs(hudLoc.y - variantLabel.position.y) < 28 {
            let next: ControlVariant = sim.state.controlVariant == .a ? .b : .a
            sim.state.controlVariant = next
            variantLabel.text = next == .a ? "A: free Pounce  (tap for B)" : "B: Pounce button  (tap for A)"
            layoutHUD()
            return
        }

        if sim.state.controlVariant == .b, let btn = pounceButton, btn.contains(hudLoc) {
            buttonPounce = true
            pendingPounce = true
            return
        }

        if case .won = sim.state.outcome { restart(); return }
        if case .failed = sim.state.outcome { restart(); return }

        activeTouch = touch
        let world = touch.location(in: worldRoot)
        dragOriginWorld = Vec2(world.x, world.y)
        let airborne = sim.state.bandit.isAirborne
        touchInterp.begin(at: simTime(), pos: Vec2(world.x, world.y), airborne: airborne)
        holdActive = true
        lastMove = .zero
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let world = touch.location(in: worldRoot)
        touchInterp.move(to: Vec2(world.x, world.y))
        let delta = Vec2(world.x, world.y) - dragOriginWorld
        let dead = tuning.tapMaxPoints
        if delta.length > dead {
            lastMove = delta.normalized
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else {
            buttonPounce = false
            return
        }
        let world = touch.location(in: worldRoot)
        touchInterp.move(to: Vec2(world.x, world.y))
        let (pounce, flop) = touchInterp.end(at: simTime(), tuning: tuning)
        if pounce { pendingPounce = true }
        if flop { pendingFlop = true }
        holdActive = false
        activeTouch = nil
        // Keep lastMove for coast; clear if it was a tap
        if pounce || flop { lastMove = lastMove.length > 0.1 ? lastMove : sim.state.bandit.facing }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func simTime() -> Double { Double(sim.state.tick) * tuning.dt }

    private func restart() {
        do {
            let map = try NeonAlleyMap.load()
            let variant = sim.state.controlVariant
            sim = Sim(map: map, tuning: tuning, seed: UInt64.random(in: 1...9999), variant: variant)
        } catch {
            return
        }
        outcomeLabel.isHidden = true
        for (id, node) in shinyNodes {
            node.isHidden = false
            node.alpha = 1
            _ = id
        }
        for (_, node) in dummyNodes {
            node.isHidden = false
            node.alpha = 1
            node.setScale(1)
        }
        syncFromSim(force: true)
    }

    // MARK: - Update

    public override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime
        lastTime = currentTime
        if dt > 0.1 { dt = 0.1 }

        #if DEBUG
        fpsAcc += dt
        if fpsAcc >= 0.25 {
            displayedFPS = Int((1.0 / max(dt, 0.0001)).rounded())
            fpsLabel.text = "FPS \(displayedFPS)"
            fpsAcc = 0
        }
        #endif

        if hitPauseRemaining > 0 {
            hitPauseRemaining -= dt
            return
        }

        accumulator += dt
        let stepDt = tuning.dt
        var steps = 0
        while accumulator >= stepDt && steps < 5 {
            let input = InputFrame(
                move: lastMove,
                pouncePressed: pendingPounce || buttonPounce,
                hold: holdActive && sim.state.bandit.isAirborne,
                bellyFlopPressed: pendingFlop
            )
            pendingPounce = false
            pendingFlop = false
            buttonPounce = false
            sim.step(input)
            handleEvents(sim.state.events)
            accumulator -= stepDt
            steps += 1
        }
        syncFromSim(force: false)
    }

    private func handleEvents(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .pounce:
                JuiceSound.shared.play(.pounce)
                squash(scaleX: 0.75, scaleY: 1.25)
            case .land:
                JuiceSound.shared.play(.land)
                squash(scaleX: 1.25, scaleY: 0.7)
                dust(at: e.position)
            case .bellyFlop:
                JuiceSound.shared.play(.flop)
                squash(scaleX: 1.35, scaleY: 0.55)
            case .flopHit:
                JuiceSound.shared.play(.hit)
                hitPauseRemaining = 0.05
                shake(0.35)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                popNumber("+1", at: e.position, color: ArtCatalog.neonPink)
            case .shinyGrab:
                JuiceSound.shared.play(.shiny)
                popNumber("✦", at: e.position, color: ArtCatalog.shinyGold)
            case .bank:
                JuiceSound.shared.play(.bank)
                popNumber("BANK", at: e.position, color: ArtCatalog.neonLime)
            case .maskModeOn:
                JuiceSound.shared.play(.mask)
                flashMask()
                popNumber("MASK MODE", at: e.position, color: ArtCatalog.neonCyan)
            case .win:
                JuiceSound.shared.play(.win)
                outcomeLabel.text = "HEIST COMPLETE\nTap to retry"
                outcomeLabel.fontColor = ArtCatalog.neonLime
                outcomeLabel.numberOfLines = 2
                outcomeLabel.isHidden = false
            case .fail(let reason):
                JuiceSound.shared.play(.fail)
                outcomeLabel.text = reason == .fellInWater ? "SPLASHED\nTap to retry" : "BAGGED\nTap to retry"
                outcomeLabel.fontColor = ArtCatalog.neonPink
                outcomeLabel.numberOfLines = 2
                outcomeLabel.isHidden = false
            case .dust:
                dust(at: e.position)
            }
        }
    }

    private func syncFromSim(force: Bool) {
        let b = sim.state.bandit
        let body = banditNode.childNode(withName: "body")
        let shadow = banditNode.childNode(withName: "shadow")
        banditNode.position = cg(b.position)
        body?.position = CGPoint(x: 0, y: CGFloat(b.height))
        shadow?.setScale(max(0.35, 1.0 - b.height / (tuning.tileSize * 2)))
        let angle = atan2(b.facing.y, b.facing.x) - .pi / 2
        body?.zRotation = CGFloat(angle)

        if let mask = body?.childNode(withName: "mask") as? SKShapeNode {
            mask.fillColor = b.maskMode ? ArtCatalog.neonCyan : ArtCatalog.maskBlack
            mask.glowWidth = b.maskMode ? 6 : 0
        }

        for s in sim.state.shinies {
            guard let node = shinyNodes[s.id] else { continue }
            node.isHidden = !s.alive
            if s.alive, node.action(forKey: "pulse") == nil {
                node.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.12, duration: 0.4),
                    SKAction.scale(to: 1.0, duration: 0.4),
                ])), withKey: "pulse")
            }
        }
        for d in sim.state.dummies {
            let n = dummyNodes[d.id]
            n?.isHidden = !d.alive
            n?.alpha = d.alive ? 1 : 0
        }

        let goal = tuning.shiniesToWin
        carriedLabel.text = "Carried  \(b.carriedShinies)"
        bankedLabel.text = "Banked  \(b.bankedShinies)/\(goal)"
        comboLabel.text = b.combo > 1 ? (b.maskMode ? "MASK x\(b.combo)" : "COMBO x\(b.combo)") : ""
        comboLabel.isHidden = b.combo <= 1

        // Camera look-ahead
        let look = CGPoint(
            x: CGFloat(b.position.x + b.facing.x * tuning.tileSize * 1.5),
            y: CGFloat(b.position.y + b.facing.y * tuning.tileSize * 1.5)
        )
        cameraLook.x += (look.x - cameraLook.x) * 0.12
        cameraLook.y += (look.y - cameraLook.y) * 0.12
        worldRoot.position = CGPoint(x: -cameraLook.x, y: -cameraLook.y)
    }

    private func squash(scaleX: CGFloat, scaleY: CGFloat) {
        guard let body = banditNode.childNode(withName: "body") else { return }
        body.removeAction(forKey: "squash")
        let squash = SKAction.scaleX(to: scaleX, y: scaleY, duration: 0.06)
        let restore = SKAction.scaleX(to: 1, y: 1, duration: 0.10)
        body.run(SKAction.sequence([squash, restore]), withKey: "squash")
    }

    private func dust(at pos: Vec2) {
        for i in 0..<5 {
            let p = SKShapeNode(circleOfRadius: 3)
            p.fillColor = ArtCatalog.neonOrange.withAlphaComponent(0.7)
            p.strokeColor = .clear
            p.position = cg(pos)
            p.zPosition = 40
            worldRoot.addChild(p)
            let dx = CGFloat.random(in: -18...18)
            let dy = CGFloat.random(in: -8...16)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.25),
                    SKAction.fadeOut(withDuration: 0.25),
                    SKAction.scale(to: 0.2, duration: 0.25),
                ]),
                SKAction.removeFromParent(),
            ]))
            _ = i
        }
    }

    private func popNumber(_ text: String, at pos: Vec2, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 14
        label.fontColor = color
        label.position = cg(pos)
        label.zPosition = 60
        worldRoot.addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 28, duration: 0.45),
                SKAction.fadeOut(withDuration: 0.45),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func shake(_ amount: CGFloat) {
        let a = amount * 6
        worldRoot.run(SKAction.sequence([
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
            SKAction.moveBy(x: -2 * a, y: 0, duration: 0.04),
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
        ]))
    }

    private func flashMask() {
        let flash = SKShapeNode(circleOfRadius: 80)
        flash.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.35)
        flash.strokeColor = .clear
        flash.position = banditNode.position
        flash.zPosition = 45
        worldRoot.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.2, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3),
            ]),
            SKAction.removeFromParent(),
        ]))
    }
}
#endif
