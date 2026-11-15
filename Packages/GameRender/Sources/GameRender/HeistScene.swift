// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Side-view neon docks heist — Celeste-leaning feel, title → play → win/fail.
public final class HeistScene: SKScene {
    private var sim: Sim!
    private var tuning = Tuning.default
    private let world = SKNode()
    private let parallaxFar = SKNode()
    private let parallaxMid = SKNode()
    private let rainLayer = SKNode()
    private var banditNode: SKNode!
    private var shinyNodes: [Int: SKNode] = [:]
    private var mopNodes: [Int: SKNode] = [:]
    private let hud = SKNode()
    private let overlay = SKNode()

    private var moveX: Double = 0
    private var jumpHeld = false
    private var jumpPressed = false
    private var pouncePressed = false
    private var stickTouch: UITouch?
    private var jumpTouch: UITouch?
    private var stickOrigin = CGPoint.zero

    private var stickBase: SKShapeNode!
    private var stickKnob: SKShapeNode!
    private var jumpBtn: SKShapeNode!
    private var pounceBtn: SKShapeNode!

    private var titleRoot = SKNode()
    private var outcomeRoot = SKNode()
    private var hudCarried = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var hudHearts = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var hudCombo = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var hudTime = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var fpsLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var fpsAcc: TimeInterval = 0
    private var displayedFPS = 0
    private var hitStop: TimeInterval = 0
    private var camera = CGPoint.zero
    private var runAnimT: CGFloat = 0
    private var hapticLight = UIImpactFeedbackGenerator(style: .light)
    private var hapticMed = UIImpactFeedbackGenerator(style: .medium)
    private var hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    public override func didMove(to view: SKView) {
        backgroundColor = ArtCatalog.nightSky
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        do {
            sim = Sim(map: try NeonDocksLevel.load(), tuning: tuning, seed: 11)
        } catch {
            sim = Sim(map: try! TileMap.parse("###\n#@#\n###"), tuning: tuning)
        }

        addChild(parallaxFar)
        addChild(parallaxMid)
        addChild(world)
        world.addChild(rainLayer)
        buildParallax()
        buildTiles()
        banditNode = ArtCatalog.makeBandit()
        banditNode.zPosition = 50
        world.addChild(banditNode)

        for s in sim.state.shinies {
            let n = ArtCatalog.makeShiny()
            n.position = cg(s.position)
            n.zPosition = 20
            world.addChild(n)
            shinyNodes[s.id] = n
            n.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.2, duration: 0.35), SKAction.fadeAlpha(to: 1, duration: 0.35)]),
                SKAction.group([SKAction.scale(to: 0.9, duration: 0.35), SKAction.fadeAlpha(to: 0.85, duration: 0.35)]),
            ])))
        }
        for m in sim.state.mops {
            let n = ArtCatalog.makeMop()
            n.position = cg(m.position)
            n.zPosition = 30
            world.addChild(n)
            mopNodes[m.id] = n
        }

        addChild(hud)
        addChild(overlay)
        setupControls()
        setupHUD()
        setupTitle()
        setupOutcome()
        JuiceSound.shared.prepare()
        hapticLight.prepare(); hapticMed.prepare(); hapticHeavy.prepare()
        layoutUI()
        sync(force: true)
    }

    public override func didChangeSize(_ oldSize: CGSize) { layoutUI() }

    // MARK: - World build

    private func buildParallax() {
        // Far skyline silhouettes
        for i in 0..<24 {
            let h = CGFloat.random(in: 40...140)
            let w = CGFloat.random(in: 28...70)
            let b = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            b.fillColor = SKColor(red: 0.08, green: 0.07, blue: 0.18, alpha: 1)
            b.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.15)
            b.position = CGPoint(x: CGFloat(i) * 90 - 200, y: h * 0.5 - 40)
            b.zPosition = -20
            parallaxFar.addChild(b)
            // Window glow
            for _ in 0..<Int.random(in: 2...6) {
                let win = SKShapeNode(rectOf: CGSize(width: 5, height: 7))
                win.fillColor = Bool.random() ? ArtCatalog.neonCyan : ArtCatalog.neonOrange
                win.alpha = 0.55
                win.strokeColor = .clear
                win.position = CGPoint(
                    x: b.position.x + CGFloat.random(in: -w/3...w/3),
                    y: b.position.y + CGFloat.random(in: -h/3...h/3)
                )
                win.zPosition = -19
                parallaxFar.addChild(win)
            }
        }
        // Mid neon signs
        for i in 0..<10 {
            let sign = SKShapeNode(rectOf: CGSize(width: 70, height: 18), cornerRadius: 3)
            sign.fillColor = SKColor(white: 0.05, alpha: 0.8)
            sign.strokeColor = i % 2 == 0 ? ArtCatalog.neonCyan : ArtCatalog.neonPink
            sign.lineWidth = 2
            sign.glowWidth = 3
            sign.position = CGPoint(x: CGFloat(i) * 160 - 100, y: CGFloat(60 + (i % 3) * 30))
            sign.zPosition = -10
            parallaxMid.addChild(sign)
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = ["SPOTLESS", "OPEN 24", "MOP CO", "NEON", "DOCKS"][i % 5]
            label.fontSize = 9
            label.fontColor = sign.strokeColor
            label.verticalAlignmentMode = .center
            sign.addChild(label)
        }
        // Rain
        for _ in 0..<60 {
            let drop = SKShapeNode(rectOf: CGSize(width: 1.5, height: CGFloat.random(in: 8...16)))
            drop.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.25)
            drop.strokeColor = .clear
            drop.position = CGPoint(x: CGFloat.random(in: -600...2000), y: CGFloat.random(in: -200...400))
            drop.zPosition = 80
            rainLayer.addChild(drop)
            let fall = SKAction.moveBy(x: -20, y: -500, duration: Double.random(in: 0.6...1.2))
            let reset = SKAction.run { [weak drop] in
                drop?.position.y = 400
                drop?.position.x += CGFloat.random(in: -40...40)
            }
            drop.run(SKAction.repeatForever(SKAction.sequence([fall, reset])))
        }
    }

    private func buildTiles() {
        let tile = CGFloat(tuning.tileSize)
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                switch kind {
                case .ground, .wall, .latch:
                    let n = SKShapeNode(rectOf: CGSize(width: tile + 1, height: tile + 1), cornerRadius: 2)
                    n.fillColor = ArtCatalog.asphalt
                    n.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.25)
                    n.lineWidth = 1
                    n.position = pos
                    n.zPosition = 2
                    world.addChild(n)
                    if (x + y) % 4 == 0 {
                        let glow = SKShapeNode(rectOf: CGSize(width: tile * 0.3, height: 3))
                        glow.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.4)
                        glow.strokeColor = .clear
                        glow.position = CGPoint(x: pos.x, y: pos.y + tile * 0.35)
                        glow.zPosition = 3
                        world.addChild(glow)
                    }
                case .crate:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.9, height: tile * 0.9), cornerRadius: 2)
                    n.fillColor = SKColor(red: 0.55, green: 0.32, blue: 0.18, alpha: 1)
                    n.strokeColor = ArtCatalog.neonOrange
                    n.position = pos
                    n.zPosition = 4
                    world.addChild(n)
                case .water:
                    let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    n.fillColor = SKColor(red: 0.08, green: 0.28, blue: 0.48, alpha: 0.9)
                    n.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.4)
                    n.position = pos
                    n.zPosition = 1
                    world.addChild(n)
                case .spike:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.8, height: tile * 0.5))
                    n.fillColor = ArtCatalog.neonPink
                    n.strokeColor = .clear
                    n.position = pos
                    n.zPosition = 5
                    world.addChild(n)
                case .checkpoint:
                    let pole = SKShapeNode(rectOf: CGSize(width: 4, height: tile * 1.4))
                    pole.fillColor = ArtCatalog.neonLime
                    pole.strokeColor = .clear
                    pole.glowWidth = 3
                    pole.position = pos
                    pole.zPosition = 6
                    pole.name = "cp-\(x)-\(y)"
                    world.addChild(pole)
                case .stash, .exit:
                    let door = SKShapeNode(rectOf: CGSize(width: tile * 1.2, height: tile * 1.6), cornerRadius: 4)
                    door.fillColor = SKColor(red: 0.1, green: 0.35, blue: 0.25, alpha: 0.9)
                    door.strokeColor = ArtCatalog.neonLime
                    door.lineWidth = 2
                    door.glowWidth = 4
                    door.position = pos
                    door.zPosition = 6
                    world.addChild(door)
                    let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
                    t.text = kind == .exit ? "EXIT" : "STASH"
                    t.fontSize = 9
                    t.fontColor = ArtCatalog.neonLime
                    t.verticalAlignmentMode = .center
                    door.addChild(t)
                default:
                    break
                }
            }
        }
    }

    // MARK: - UI

    private func setupControls() {
        stickBase = SKShapeNode(circleOfRadius: 56)
        stickBase.fillColor = SKColor(white: 1, alpha: 0.08)
        stickBase.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.5)
        stickBase.lineWidth = 2
        stickBase.zPosition = 200
        stickBase.name = "stickBase"
        hud.addChild(stickBase)

        stickKnob = SKShapeNode(circleOfRadius: 28)
        stickKnob.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.45)
        stickKnob.strokeColor = ArtCatalog.neonCyan
        stickKnob.lineWidth = 2
        stickKnob.zPosition = 201
        stickKnob.name = "stickKnob"
        hud.addChild(stickKnob)

        jumpBtn = makeFaceButton(title: "JUMP", color: ArtCatalog.neonLime)
        jumpBtn.name = "jumpBtn"
        hud.addChild(jumpBtn)

        pounceBtn = makeFaceButton(title: "POUNCE", color: ArtCatalog.neonPink)
        pounceBtn.name = "pounceBtn"
        hud.addChild(pounceBtn)
    }

    private func makeFaceButton(title: String, color: SKColor) -> SKShapeNode {
        let b = SKShapeNode(circleOfRadius: 42)
        b.fillColor = color.withAlphaComponent(0.4)
        b.strokeColor = color
        b.lineWidth = 2
        b.glowWidth = 2
        b.zPosition = 200
        let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
        t.text = title
        t.fontSize = 11
        t.fontColor = .white
        t.verticalAlignmentMode = .center
        b.addChild(t)
        return b
    }

    private func setupHUD() {
        for (label, color) in [
            (hudCarried, ArtCatalog.neonOrange),
            (hudHearts, ArtCatalog.neonPink),
            (hudCombo, ArtCatalog.neonCyan),
            (hudTime, SKColor.white),
        ] as [(SKLabelNode, SKColor)] {
            label.fontSize = 15
            label.fontColor = color
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 210
            hud.addChild(label)
        }
        #if DEBUG
        fpsLabel.fontSize = 11
        fpsLabel.fontColor = .white
        fpsLabel.horizontalAlignmentMode = .left
        fpsLabel.verticalAlignmentMode = .bottom
        fpsLabel.zPosition = 210
        hud.addChild(fpsLabel)
        #endif
    }

    private func setupTitle() {
        titleRoot.zPosition = 300
        overlay.addChild(titleRoot)
        let bg = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        bg.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.1, alpha: 0.82)
        bg.strokeColor = .clear
        titleRoot.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "TRASH PANDA"
        title.fontSize = 42
        title.fontColor = ArtCatalog.neonCyan
        title.position = CGPoint(x: 0, y: 60)
        titleRoot.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = "Neon Docks · Free the crew"
        sub.fontSize = 14
        sub.fontColor = ArtCatalog.neonPink
        sub.position = CGPoint(x: 0, y: 24)
        titleRoot.addChild(sub)

        let play = SKLabelNode(fontNamed: "AvenirNext-Bold")
        play.text = "TAP TO START"
        play.fontSize = 18
        play.fontColor = .white
        play.position = CGPoint(x: 0, y: -40)
        play.name = "tapStart"
        titleRoot.addChild(play)
        play.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.6),
            SKAction.fadeAlpha(to: 1, duration: 0.6),
        ])))

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = "Left stick · JUMP · POUNCE/FLOP  ·  Stomp MOPs for Mask Mode"
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position = CGPoint(x: 0, y: -90)
        titleRoot.addChild(hint)
    }

    private func setupOutcome() {
        outcomeRoot.zPosition = 320
        outcomeRoot.isHidden = true
        overlay.addChild(outcomeRoot)
        let bg = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        bg.fillColor = SKColor(white: 0, alpha: 0.72)
        bg.strokeColor = .clear
        bg.name = "obg"
        outcomeRoot.addChild(bg)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.name = "olabel"
        label.fontSize = 28
        label.numberOfLines = 4
        label.preferredMaxLayoutWidth = 320
        label.verticalAlignmentMode = .center
        outcomeRoot.addChild(label)
    }

    private func layoutUI() {
        let hw = size.width * 0.5
        let hh = size.height * 0.5
        stickBase.position = CGPoint(x: -hw + 78, y: -hh + 90)
        stickKnob.position = stickBase.position
        jumpBtn.position = CGPoint(x: hw - 58, y: -hh + 120)
        pounceBtn.position = CGPoint(x: hw - 120, y: -hh + 70)
        hudCarried.position = CGPoint(x: -hw + 16, y: hh - 18)
        hudHearts.position = CGPoint(x: -hw + 16, y: hh - 40)
        hudCombo.position = CGPoint(x: -hw + 16, y: hh - 62)
        hudTime.position = CGPoint(x: -hw + 16, y: hh - 84)
        #if DEBUG
        fpsLabel.position = CGPoint(x: -hw + 16, y: -hh + 16)
        #endif
        let playing = {
            if case .playing = sim.state.phase { return true }
            return false
        }()
        stickBase.isHidden = !playing
        stickKnob.isHidden = !playing
        jumpBtn.isHidden = !playing
        pounceBtn.isHidden = !playing
    }

    private func cg(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    // MARK: - Touch

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: hud)
            let op = touch.location(in: overlay)

            if case .title = sim.state.phase {
                sim.startRun()
                titleRoot.isHidden = true
                JuiceSound.shared.startMusic()
                layoutUI()
                hapticMed.impactOccurred()
                return
            }
            if case .won = sim.state.phase, outcomeRoot.contains(op) || true {
                sim.retry(); hideOutcome(); return
            }
            if case .failed = sim.state.phase {
                sim.retry(); hideOutcome(); return
            }

            if jumpBtn.contains(p) {
                jumpTouch = touch
                jumpPressed = true
                jumpHeld = true
                hapticLight.impactOccurred()
                continue
            }
            if pounceBtn.contains(p) {
                pouncePressed = true
                hapticMed.impactOccurred()
                continue
            }
            // Stick zone: left half
            if p.x < 0 {
                stickTouch = touch
                stickOrigin = stickBase.position
                updateStick(touch.location(in: hud))
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === stickTouch {
                updateStick(touch.location(in: hud))
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === stickTouch {
                stickTouch = nil
                moveX = 0
                stickKnob.position = stickBase.position
            }
            if touch === jumpTouch {
                jumpTouch = nil
                jumpHeld = false
            }
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateStick(_ p: CGPoint) {
        let delta = CGPoint(x: p.x - stickOrigin.x, y: p.y - stickOrigin.y)
        let maxR: CGFloat = 48
        var dx = delta.x, dy = delta.y
        let len = sqrt(dx * dx + dy * dy)
        if len > maxR {
            dx = dx / len * maxR
            dy = dy / len * maxR
        }
        stickKnob.position = CGPoint(x: stickOrigin.x + dx, y: stickOrigin.y + dy)
        moveX = Double(dx / maxR)
        // Vertical on stick can also jump if flicked up hard
        if dy > 36 && !jumpHeld {
            jumpPressed = true
            jumpHeld = true
        }
    }

    private func hideOutcome() {
        outcomeRoot.isHidden = true
        layoutUI()
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
            displayedFPS = Int((1 / max(dt, 0.0001)).rounded())
            fpsLabel.text = "FPS \(displayedFPS)"
            fpsAcc = 0
        }
        #endif

        if hitStop > 0 {
            hitStop -= dt
            return
        }

        accumulator += dt
        var steps = 0
        while accumulator >= tuning.dt && steps < 5 {
            let input = InputFrame(
                moveX: moveX,
                jumpPressed: jumpPressed,
                jumpHeld: jumpHeld,
                pouncePressed: pouncePressed
            )
            jumpPressed = false
            pouncePressed = false
            if case .playing = sim.state.phase {
                sim.step(input)
                handle(sim.state.events)
            }
            accumulator -= tuning.dt
            steps += 1
        }
        sync(force: false)
        animateBandit(dt)
    }

    private func handle(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .jump:
                JuiceSound.shared.play(.sfxJump)
                squash(0.8, 1.25)
                hapticLight.impactOccurred()
            case .land:
                JuiceSound.shared.play(.sfxLand)
                squash(1.3, 0.7)
                dust(at: e.position)
            case .pounce:
                JuiceSound.shared.play(.sfxPounce)
                shake(0.5)
                hapticMed.impactOccurred()
            case .flop:
                JuiceSound.shared.play(.sfxPounce)
                squash(1.4, 0.55)
            case .stomp:
                JuiceSound.shared.play(.sfxHit)
                hitStop = 0.05
                shake(0.7)
                hapticHeavy.impactOccurred()
                pop("STOMP", at: e.position, ArtCatalog.neonPink)
            case .shiny:
                JuiceSound.shared.play(.sfxCollectShiny)
                pop("✦", at: e.position, ArtCatalog.neonOrange)
            case .bank:
                JuiceSound.shared.play(.sfxCollectShiny)
                pop("BANK", at: e.position, ArtCatalog.neonLime)
            case .maskOn:
                JuiceSound.shared.play(.sfxMaskMode)
                flashMask()
                pop("MASK MODE", at: e.position, ArtCatalog.neonCyan)
                hapticHeavy.impactOccurred()
            case .hurt:
                JuiceSound.shared.play(.sfxHit)
                shake(0.4)
            case .win:
                JuiceSound.shared.play(.sfxWin)
                showOutcome()
            case .fail:
                JuiceSound.shared.play(.sfxFail)
                showOutcome()
            case .checkpoint:
                pop("CHECK", at: e.position, ArtCatalog.neonLime)
            case .dust:
                dust(at: e.position)
            case .shake:
                shake(0.35)
            }
        }
    }

    private func showOutcome() {
        outcomeRoot.isHidden = false
        layoutUI()
        guard let label = outcomeRoot.childNode(withName: "olabel") as? SKLabelNode else { return }
        switch sim.state.phase {
        case .won(let seconds, let shinies, let combo):
            label.fontColor = ArtCatalog.neonLime
            label.text = "HEIST COMPLETE\n\(String(format: "%.1f", seconds))s · \(shinies) Shinies\nBest combo x\(combo)\nTap to retry"
        case .failed(let reason):
            label.fontColor = ArtCatalog.neonPink
            let why = reason == .fellInWater ? "SPLASHED" : (reason == .spiked ? "SPIKED" : "BAGGED")
            label.text = "\(why)\nTap to retry"
        default:
            break
        }
    }

    private func sync(force: Bool) {
        let b = sim.state.bandit
        banditNode.position = cg(b.position)
        if let body = banditNode.childNode(withName: "body") {
            body.xScale = CGFloat(b.facing)
        }
        if let mask = banditNode.childNode(withName: "//mask") as? SKShapeNode {
            mask.fillColor = b.maskMode ? ArtCatalog.neonCyan : ArtCatalog.maskBlack
            mask.glowWidth = b.maskMode ? 8 : 0
        }
        banditNode.alpha = b.invuln > 0 && Int(b.invuln * 20) % 2 == 0 ? 0.4 : 1

        for s in sim.state.shinies {
            shinyNodes[s.id]?.isHidden = !s.alive
        }
        for m in sim.state.mops {
            mopNodes[m.id]?.position = cg(m.position)
            mopNodes[m.id]?.isHidden = !m.alive
        }

        hudCarried.text = "Shinies \(b.carriedShinies + b.bankedShinies)"
        hudHearts.text = String(repeating: "♥", count: max(0, b.hearts))
        hudCombo.text = b.combo > 1 ? (b.maskMode ? "MASK x\(b.combo)" : "COMBO x\(b.combo)") : ""
        hudCombo.isHidden = b.combo <= 1
        hudTime.text = String(format: "Time %.0fs", sim.state.elapsed)

        // Camera lead + smooth
        let lead = CGFloat(b.facing * tuning.cameraLeadTiles * tuning.tileSize)
        let target = CGPoint(x: CGFloat(b.position.x) + lead, y: CGFloat(b.position.y) + 40)
        let s = CGFloat(tuning.cameraSmooth)
        camera.x += (target.x - camera.x) * s
        camera.y += (target.y - camera.y) * s
        world.position = CGPoint(x: -camera.x, y: -camera.y)
        parallaxFar.position = CGPoint(x: -camera.x * 0.2, y: -camera.y * 0.05)
        parallaxMid.position = CGPoint(x: -camera.x * 0.45, y: -camera.y * 0.1)
    }

    private func animateBandit(_ dt: TimeInterval) {
        guard let body = banditNode.childNode(withName: "body") else { return }
        let anim = sim.state.bandit.anim
        if anim == .run {
            runAnimT += CGFloat(dt) * 12
            let bob = sin(runAnimT) * 3
            body.childNode(withName: "legL")?.position.y = -18 + bob
            body.childNode(withName: "legR")?.position.y = -18 - bob
            body.childNode(withName: "tail")?.zRotation = sin(runAnimT) * 0.2
        } else if anim == .jump || anim == .pounce {
            body.childNode(withName: "legL")?.position.y = -14
            body.childNode(withName: "legR")?.position.y = -14
        } else {
            body.childNode(withName: "legL")?.position.y = -18
            body.childNode(withName: "legR")?.position.y = -18
        }
    }

    private func squash(_ x: CGFloat, _ y: CGFloat) {
        guard let body = banditNode.childNode(withName: "body") else { return }
        let face = CGFloat(sim.state.bandit.facing)
        body.removeAction(forKey: "sq")
        body.run(SKAction.sequence([
            SKAction.scaleX(to: x * face, y: y, duration: 0.05),
            SKAction.scaleX(to: 1 * face, y: 1, duration: 0.1),
        ]), withKey: "sq")
    }

    private func dust(at pos: Vec2) {
        for _ in 0..<7 {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            p.fillColor = ArtCatalog.neonOrange.withAlphaComponent(0.7)
            p.strokeColor = .clear
            p.position = cg(pos)
            p.zPosition = 40
            world.addChild(p)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -22...22), y: CGFloat.random(in: 0...18), duration: 0.28),
                    SKAction.fadeOut(withDuration: 0.28),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private func pop(_ text: String, at pos: Vec2, _ color: SKColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 14
        l.fontColor = color
        l.position = cg(pos)
        l.zPosition = 60
        world.addChild(l)
        l.run(SKAction.sequence([
            SKAction.group([SKAction.moveBy(x: 0, y: 30, duration: 0.45), SKAction.fadeOut(withDuration: 0.45)]),
            SKAction.removeFromParent(),
        ]))
    }

    private func shake(_ amount: CGFloat) {
        let a = amount * 7
        world.run(SKAction.sequence([
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
            SKAction.moveBy(x: -2 * a, y: 0, duration: 0.04),
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
        ]))
    }

    private func flashMask() {
        let flash = SKShapeNode(circleOfRadius: 90)
        flash.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.35)
        flash.strokeColor = .clear
        flash.position = banditNode.position
        flash.zPosition = 45
        world.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2.4, duration: 0.35), SKAction.fadeOut(withDuration: 0.35)]),
            SKAction.removeFromParent(),
        ]))
    }
}
#endif
