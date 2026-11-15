// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Side-view neon docks heist wired to `Assets/Generated/` via AssetManifest.
public final class HeistScene: SKScene {
    private var sim: Sim!
    private var tuning = Tuning.default
    private let world = SKNode()
    private let parallaxFar = SKNode()
    private let parallaxMid = SKNode()
    private let parallaxNear = SKNode()
    private let rainLayer = SKNode()
    private var bandit: BanditVisual!
    private var shinyNodes: [Int: SKNode] = [:]
    private var mopNodes: [Int: SKSpriteNode] = [:]
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
    private var cameraFocus = CGPoint.zero
    private var maskMusicOn = false
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
        addChild(parallaxNear)
        addChild(world)
        world.addChild(rainLayer)
        buildParallax()
        buildTiles()

        bandit = ArtCatalog.makeBanditVisual()
        bandit.zPosition = 50
        world.addChild(bandit)

        for s in sim.state.shinies {
            let n = ArtCatalog.makeShinyNode()
            n.position = cg(s.position)
            n.zPosition = 20
            world.addChild(n)
            shinyNodes[s.id] = n
        }
        for m in sim.state.mops {
            let n = ArtCatalog.makeMopNode()
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
        JuiceSound.shared.playTitleSting()
        hapticLight.prepare(); hapticMed.prepare(); hapticHeavy.prepare()
        layoutUI()
        sync(dt: 0)
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        // SpriteKit can call this before didMove; force-unwrapped UI is not ready yet.
        guard stickBase != nil, sim != nil else { return }
        layoutUI()
    }

    // MARK: - Parallax (known issues handled)

    private func buildParallax() {
        let h = max(size.height, 700)

        // Far skyline: wide, NON-repeating (centered moon). Slow drift only.
        if let far = ArtCatalog.background(.farSkyline, height: h * 0.95) {
            far.position = .zero
            far.zPosition = -30
            far.name = "farSkyline"
            parallaxFar.addChild(far)
        } else {
            buildProceduralSkyline()
        }

        // Mid buildings: single wide plate (not tiled)
        if let mid = ArtCatalog.background(.midBuildings, height: h * 0.85) {
            mid.position = CGPoint(x: 0, y: -20)
            mid.zPosition = -20
            parallaxMid.addChild(mid)
        }

        // Near rooftops: BACKGROUND ONLY — never used for collision
        if let near = ArtCatalog.background(.nearRooftops, height: h * 0.7) {
            near.position = CGPoint(x: 0, y: -40)
            near.zPosition = -10
            near.alpha = 0.95
            parallaxNear.addChild(near)
        }

        // Rain overlay (additive-ish)
        if let rain = ArtCatalog.background(.rainOverlay, height: h) {
            rain.blendMode = .alpha
            rain.alpha = 0.65
            rain.zPosition = 70
            rain.name = "rain"
            rainLayer.addChild(rain)
            rain.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: -40, y: -120, duration: 0.8),
                SKAction.moveBy(x: 40, y: 120, duration: 0),
            ])))
        } else {
            for _ in 0..<40 {
                let drop = SKShapeNode(rectOf: CGSize(width: 1.5, height: CGFloat.random(in: 8...14)))
                drop.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.25)
                drop.strokeColor = .clear
                drop.position = CGPoint(x: CGFloat.random(in: -800...1200), y: CGFloat.random(in: -200...400))
                drop.zPosition = 70
                rainLayer.addChild(drop)
                drop.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: -20, y: -500, duration: Double.random(in: 0.5...1.0)),
                    SKAction.run { drop.position.y = 400 },
                ])))
            }
        }
    }

    private func buildProceduralSkyline() {
        for i in 0..<20 {
            let h = CGFloat.random(in: 40...120)
            let b = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 30...60), height: h), cornerRadius: 2)
            b.fillColor = SKColor(red: 0.08, green: 0.07, blue: 0.18, alpha: 1)
            b.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.2)
            b.position = CGPoint(x: CGFloat(i) * 80 - 200, y: h * 0.5 - 40)
            parallaxFar.addChild(b)
        }
    }

    private func buildTiles() {
        let tile = CGFloat(tuning.tileSize)
        var tileIdx = 1
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                switch kind {
                case .ground, .wall, .latch:
                    if let tex = ArtCatalog.tileTexture(index: ((tileIdx - 1) % 27) + 1) {
                        let n = SKSpriteNode(texture: tex, size: CGSize(width: tile + 1, height: tile + 1))
                        n.position = pos
                        n.zPosition = 2
                        world.addChild(n)
                    } else {
                        let n = SKShapeNode(rectOf: CGSize(width: tile + 1, height: tile + 1), cornerRadius: 2)
                        n.fillColor = ArtCatalog.asphalt
                        n.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.25)
                        n.position = pos
                        n.zPosition = 2
                        world.addChild(n)
                    }
                    tileIdx += 1
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
        hud.addChild(stickBase)

        stickKnob = SKShapeNode(circleOfRadius: 28)
        stickKnob.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.45)
        stickKnob.strokeColor = ArtCatalog.neonCyan
        stickKnob.lineWidth = 2
        stickKnob.zPosition = 201
        hud.addChild(stickKnob)

        jumpBtn = makeFaceButton(title: "JUMP", color: ArtCatalog.neonLime)
        hud.addChild(jumpBtn)
        pounceBtn = makeFaceButton(title: "POUNCE", color: ArtCatalog.neonPink)
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

        let logo = ArtCatalog.makeLogoNode()
        logo.position = CGPoint(x: 0, y: 70)
        titleRoot.addChild(logo)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = "Neon Docks · Free the crew"
        sub.fontSize = 14
        sub.fontColor = ArtCatalog.neonPink
        sub.position = CGPoint(x: 0, y: -10)
        titleRoot.addChild(sub)

        let play = SKLabelNode(fontNamed: "AvenirNext-Bold")
        play.text = "TAP TO START"
        play.fontSize = 18
        play.fontColor = .white
        play.position = CGPoint(x: 0, y: -60)
        titleRoot.addChild(play)
        play.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.6),
            SKAction.fadeAlpha(to: 1, duration: 0.6),
        ])))

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = "Left stick · JUMP · POUNCE  ·  Stomp MOPs for Mask Mode"
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position = CGPoint(x: 0, y: -100)
        titleRoot.addChild(hint)
    }

    private func setupOutcome() {
        outcomeRoot.zPosition = 320
        outcomeRoot.isHidden = true
        overlay.addChild(outcomeRoot)
        let bg = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        bg.fillColor = SKColor(white: 0, alpha: 0.72)
        bg.strokeColor = .clear
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
        guard stickBase != nil, jumpBtn != nil, pounceBtn != nil, sim != nil else { return }
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
        let playing = { if case .playing = sim.state.phase { return true }; return false }()
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
            if case .title = sim.state.phase {
                JuiceSound.shared.play(.sfxUITap)
                sim.startRun()
                titleRoot.isHidden = true
                JuiceSound.shared.startLevelMusic()
                layoutUI()
                hapticMed.impactOccurred()
                return
            }
            if case .won = sim.state.phase {
                JuiceSound.shared.play(.sfxUITap)
                sim.retry(); hideOutcome(); JuiceSound.shared.startLevelMusic(); return
            }
            if case .failed = sim.state.phase {
                JuiceSound.shared.play(.sfxUITap)
                sim.retry(); hideOutcome(); JuiceSound.shared.startLevelMusic(); return
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
            if p.x < 0 {
                stickTouch = touch
                stickOrigin = stickBase.position
                updateStick(p)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === stickTouch {
            updateStick(touch.location(in: hud))
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
        if len > maxR { dx = dx / len * maxR; dy = dy / len * maxR }
        stickKnob.position = CGPoint(x: stickOrigin.x + dx, y: stickOrigin.y + dy)
        moveX = Double(dx / maxR)
        if dy > 36 && !jumpHeld {
            jumpPressed = true
            jumpHeld = true
        }
    }

    private func hideOutcome() {
        outcomeRoot.isHidden = true
        maskMusicOn = false
        JuiceSound.shared.setMaskModeMusic(false)
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

        if hitStop > 0 { hitStop -= dt; return }

        accumulator += dt
        var steps = 0
        while accumulator >= tuning.dt && steps < 5 {
            let input = InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld, pouncePressed: pouncePressed)
            jumpPressed = false
            pouncePressed = false
            if case .playing = sim.state.phase {
                sim.step(input)
                handle(sim.state.events)
            }
            accumulator -= tuning.dt
            steps += 1
        }
        sync(dt: CGFloat(dt))
    }

    private func handle(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .jump:
                JuiceSound.shared.play(.sfxJump)
                squash(0.85, 1.2)
                hapticLight.impactOccurred()
            case .land:
                JuiceSound.shared.play(.sfxLand)
                squash(1.25, 0.75)
                dust(at: e.position)
            case .pounce:
                JuiceSound.shared.play(.sfxPounce)
                shake(0.5)
                hapticMed.impactOccurred()
            case .flop:
                JuiceSound.shared.play(.sfxBellyFlop)
                squash(1.35, 0.6)
            case .stomp:
                JuiceSound.shared.play(.sfxMopHit)
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
                JuiceSound.shared.play(.sfxMaskModeOn)
                if !maskMusicOn {
                    maskMusicOn = true
                    JuiceSound.shared.setMaskModeMusic(true)
                }
                flashMask()
                pop("MASK MODE", at: e.position, ArtCatalog.neonCyan)
                hapticHeavy.impactOccurred()
            case .hurt:
                JuiceSound.shared.play(.sfxPlayerHit)
                shake(0.4)
            case .win:
                JuiceSound.shared.play(.sfxWin)
                JuiceSound.shared.setMaskModeMusic(false)
                showOutcome()
            case .fail:
                JuiceSound.shared.play(.sfxFail)
                JuiceSound.shared.setMaskModeMusic(false)
                showOutcome()
            case .checkpoint:
                JuiceSound.shared.play(.sfxCheckpoint)
                pop("CHECK", at: e.position, ArtCatalog.neonLime)
            case .dust:
                dust(at: e.position)
            case .shake:
                shake(0.35)
            }
        }
        if !sim.state.bandit.maskMode && maskMusicOn {
            maskMusicOn = false
            JuiceSound.shared.setMaskModeMusic(false)
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
        default: break
        }
    }

    private func sync(dt: CGFloat) {
        let b = sim.state.bandit
        bandit.position = cg(b.position)
        bandit.setFacing(b.facing)
        bandit.show(anim: b.anim, maskMode: b.maskMode, dt: dt)
        bandit.alpha = b.invuln > 0 && Int(b.invuln * 20) % 2 == 0 ? 0.4 : 1

        for s in sim.state.shinies { shinyNodes[s.id]?.isHidden = !s.alive }
        for m in sim.state.mops {
            mopNodes[m.id]?.position = cg(m.position)
            mopNodes[m.id]?.isHidden = !m.alive
            // Alert texture when close
            if m.alive, abs(m.position.x - b.position.x) < 80,
               let alert = ArtCatalog.texture(.mopAlert) {
                mopNodes[m.id]?.texture = alert
            } else if m.alive, let patrol = ArtCatalog.texture(.mopPatrol) {
                mopNodes[m.id]?.texture = patrol
            }
        }

        hudCarried.text = "Shinies \(b.carriedShinies + b.bankedShinies)"
        hudHearts.text = String(repeating: "♥", count: max(0, b.hearts))
        hudCombo.text = b.combo > 1 ? (b.maskMode ? "MASK x\(b.combo)" : "COMBO x\(b.combo)") : ""
        hudCombo.isHidden = b.combo <= 1
        hudTime.text = String(format: "Time %.0fs", sim.state.elapsed)

        let lead = CGFloat(b.facing * tuning.cameraLeadTiles * tuning.tileSize)
        let target = CGPoint(x: CGFloat(b.position.x) + lead, y: CGFloat(b.position.y) + 40)
        let s = CGFloat(tuning.cameraSmooth)
        cameraFocus.x += (target.x - cameraFocus.x) * s
        cameraFocus.y += (target.y - cameraFocus.y) * s
        world.position = CGPoint(x: -cameraFocus.x, y: -cameraFocus.y)
        // Slow non-tiling parallax (far skyline must not repeat)
        parallaxFar.position = CGPoint(x: -cameraFocus.x * 0.12, y: -cameraFocus.y * 0.04)
        parallaxMid.position = CGPoint(x: -cameraFocus.x * 0.35, y: -cameraFocus.y * 0.08)
        parallaxNear.position = CGPoint(x: -cameraFocus.x * 0.55, y: -cameraFocus.y * 0.12)
    }

    private func squash(_ x: CGFloat, _ y: CGFloat) {
        let face: CGFloat = bandit.sprite.xScale >= 0 ? 1 : -1
        bandit.sprite.removeAction(forKey: "sq")
        bandit.sprite.run(SKAction.sequence([
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
        flash.position = bandit.position
        flash.zPosition = 45
        world.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2.4, duration: 0.35), SKAction.fadeOut(withDuration: 0.35)]),
            SKAction.removeFromParent(),
        ]))
    }
}
#endif
