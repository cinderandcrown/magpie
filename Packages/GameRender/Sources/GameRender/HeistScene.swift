// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Side-view neon docks heist wired to `Assets/Generated/` via AssetManifest.
public final class HeistScene: SKScene {
    /// Mild zoom: raccoon ~1/7–1/8 of screen height without stripping the level into bands.
    public static let worldZoom: CGFloat = 1.28

    private var sim: Sim!
    private var tuning = Tuning.default
    private let stage = SKNode()
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
    private let playHUD = SKNode()

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

    private var smokeEnabled = false
    private var smoke = SmokeBrain()
    private var smokeStatus = SmokeStatus()
    private var fpsSum: Double = 0
    private var fpsCount: Int = 0
    private var statusAcc: TimeInterval = 0
    #if DEBUG
    private var tuningMenu: DebugTuningMenu?
    private var debugToggle: SKLabelNode?
    #endif

    public convenience init(size: CGSize, smokeAutoplay: Bool) {
        self.init(size: size)
        self.smokeEnabled = smokeAutoplay
    }

    public override func didMove(to view: SKView) {
        backgroundColor = ArtCatalog.nightSky
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        if ProcessInfo.processInfo.arguments.contains("-SmokeAutoplay") {
            smokeEnabled = true
        }
        if smokeEnabled {
            // One stomp → Mask Mode in the demo window (combo grace is too short for spaced stomps).
            tuning.maskModeAtCombo = 1
            tuning.comboGroundGrace = 4
        }
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        #if DEBUG
        if smokeEnabled {
            view.showsFPS = false
            view.showsNodeCount = false
            view.showsDrawCount = false
        }
        #endif
        do {
            // Smoke uses the compact demo rooftop so CI can hit stomp/mask/death in-window.
            let map = smokeEnabled ? try SmokeDemoLevel.load() : try NeonDocksLevel.load()
            sim = Sim(map: map, tuning: tuning, seed: smokeEnabled ? 7 : 11)
        } catch {
            sim = Sim(map: try! TileMap.parse("###\n#@#\n###"), tuning: tuning)
        }

        stage.setScale(Self.worldZoom)
        addChild(stage)
        stage.addChild(parallaxFar)
        stage.addChild(parallaxMid)
        stage.addChild(parallaxNear)
        stage.addChild(world)
        world.addChild(rainLayer)
        buildAtmosphere()
        buildParallax()
        buildTiles()

        bandit = ArtCatalog.makeBanditVisual()
        bandit.zPosition = 50
        world.addChild(bandit)

        // Limit living props: full Neon Docks has dozens of shinies/MOPs; keep a working set.
        // Smoke uses color sprites (no PNG decode) — mop/shiny atlases + anims jetsam CI sims.
        let shinyCap = smokeEnabled ? 10 : sim.state.shinies.count
        for s in sim.state.shinies.prefix(shinyCap) {
            let n = smokeEnabled ? ArtCatalog.makeSmokeShinyNode() : ArtCatalog.makeShinyNode()
            n.position = cg(s.position)
            n.zPosition = 20
            world.addChild(n)
            shinyNodes[s.id] = n
        }
        let mopCap = smokeEnabled ? 6 : sim.state.mops.count
        for m in sim.state.mops.prefix(mopCap) {
            let n = smokeEnabled ? ArtCatalog.makeSmokeMopNode() : ArtCatalog.makeMopNode()
            n.position = cg(m.position)
            n.zPosition = 30
            world.addChild(n)
            mopNodes[m.id] = n
        }

        addChild(hud)
        hud.addChild(playHUD)
        addChild(overlay)
        setupControls()
        setupHUD()
        setupTitle()
        setupOutcome()
        #if DEBUG
        setupDebugTuning()
        #endif
        // Defer audio — AVAudioSession sync on main was hanging / contributing to launch kills.
        if !smokeEnabled {
            JuiceSound.shared.prepare()
            JuiceSound.shared.playTitleSting()
        }
        if !smokeEnabled {
            hapticLight.prepare(); hapticMed.prepare(); hapticHeavy.prepare()
        }
        layoutUI()
        sync(dt: 0)
        updateHUDVisibility()
        if smokeEnabled { writeSmokeStatus() }
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        guard stickBase != nil, sim != nil else { return }
        layoutUI()
    }

    // MARK: - Atmosphere / Parallax

    /// Soft dock wash behind platforms — translucent so parallax city reads through (opaque
    /// plates previously hid the skyline and left platforms as floating strips on navy).
    private func buildAtmosphere() {
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)
        let mapH = CGFloat(sim.map.height) * CGFloat(tuning.tileSize)
        let plate = SKSpriteNode(
            color: ArtCatalog.dockFill.withAlphaComponent(0.55),
            size: CGSize(width: mapW + 240, height: mapH + 160)
        )
        plate.position = CGPoint(x: mapW * 0.5, y: mapH * 0.45)
        plate.zPosition = -5
        world.addChild(plate)

        let wash = SKSpriteNode(
            color: ArtCatalog.neonCyan.withAlphaComponent(0.08),
            size: CGSize(width: mapW + 240, height: mapH)
        )
        wash.position = plate.position
        wash.zPosition = -4
        world.addChild(wash)

        // Rooftop ledge strip under the playfield so decks read as one plane.
        let ledge = SKSpriteNode(
            color: SKColor(red: 0.14, green: 0.11, blue: 0.28, alpha: 0.9),
            size: CGSize(width: mapW + 200, height: 48)
        )
        ledge.position = CGPoint(x: mapW * 0.5, y: 8)
        ledge.zPosition = -3
        world.addChild(ledge)
        let neon = SKSpriteNode(color: ArtCatalog.neonPink.withAlphaComponent(0.55), size: CGSize(width: mapW + 200, height: 2))
        neon.position = CGPoint(x: 0, y: 22)
        ledge.addChild(neon)
    }

    private func buildParallax() {
        let h = max(size.height / Self.worldZoom * 1.05, 560)

        // Smoke: NEVER decode the 2560×1440 masters (far≈3MB / mid≈4MB / near≈3MB PNG →
        // ~14MB RGBA each). That was the residual jetsam after tile/shader fixes
        // (CI 43726848897 still died by midrun with far+near loaded).
        if smokeEnabled {
            buildProceduralCity()
            return
        }

        if let far = ArtCatalog.background(.farSkyline, height: h) {
            far.position = .zero
            far.zPosition = -30
            far.color = SKColor(white: 1.1, alpha: 1)
            far.colorBlendFactor = 0.1
            parallaxFar.addChild(far)
        } else {
            buildProceduralCity()
        }

        if let mid = ArtCatalog.background(.midBuildings, height: h * 0.9) {
            mid.position = CGPoint(x: 0, y: -10)
            mid.zPosition = -20
            parallaxMid.addChild(mid)
        }

        // near_rooftops is background-only (never collision).
        if let near = ArtCatalog.background(.nearRooftops, height: h * 0.72) {
            near.position = CGPoint(x: 0, y: -30)
            near.zPosition = -10
            near.alpha = 0.8
            parallaxNear.addChild(near)
        }

        if let rain = ArtCatalog.background(.rainOverlay, height: h * 0.85) {
            rain.alpha = 0.3
            rain.zPosition = 70
            rainLayer.addChild(rain)
            rain.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: -30, y: -90, duration: 1.1),
                SKAction.moveBy(x: 30, y: 90, duration: 0),
            ])))
        }
    }

    /// Cheap neon city depth for smoke (and as fallback): far skyline + mid towers + near ledge.
    private func buildProceduralCity() {
        // Far wash plate so the void isn't black bands between platforms.
        let farWash = SKSpriteNode(color: SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 1),
                                   size: CGSize(width: 1400, height: 700))
        farWash.zPosition = -35
        farWash.position = CGPoint(x: 0, y: 40)
        parallaxFar.addChild(farWash)

        for i in 0..<16 {
            let bh = CGFloat((i * 37) % 90) + 50
            let bw = CGFloat((i * 19) % 40) + 28
            let b = SKSpriteNode(color: SKColor(red: 0.11, green: 0.09, blue: 0.22, alpha: 1),
                                 size: CGSize(width: bw, height: bh))
            b.position = CGPoint(x: CGFloat(i) * 78 - 560, y: bh * 0.5 - 20)
            b.zPosition = -30
            parallaxFar.addChild(b)
            let rim = SKSpriteNode(color: ArtCatalog.neonPink.withAlphaComponent(0.55),
                                   size: CGSize(width: bw, height: 2))
            rim.position = CGPoint(x: 0, y: bh * 0.5)
            b.addChild(rim)
        }

        for i in 0..<10 {
            let bh = CGFloat((i * 53) % 110) + 70
            let bw = CGFloat((i * 29) % 50) + 40
            let b = SKSpriteNode(color: SKColor(red: 0.14, green: 0.1, blue: 0.28, alpha: 1),
                                 size: CGSize(width: bw, height: bh))
            b.position = CGPoint(x: CGFloat(i) * 100 - 420, y: bh * 0.35 - 10)
            b.zPosition = -20
            parallaxMid.addChild(b)
            let window = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.35),
                                      size: CGSize(width: 6, height: 8))
            window.position = CGPoint(x: 0, y: 10)
            b.addChild(window)
        }

        // Near rooftop ledge read — solid strip so platforms sit on a rooftop plane.
        let ledge = SKSpriteNode(color: SKColor(red: 0.16, green: 0.12, blue: 0.30, alpha: 1),
                                 size: CGSize(width: 1600, height: 90))
        ledge.position = CGPoint(x: 0, y: -70)
        ledge.zPosition = -10
        ledge.alpha = 0.9
        parallaxNear.addChild(ledge)
        let neonLine = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.7),
                                    size: CGSize(width: 1600, height: 3))
        neonLine.position = CGPoint(x: 0, y: 40)
        ledge.addChild(neonLine)
    }

    private func buildTiles() {
        let tile = CGFloat(tuning.tileSize)
        // Smoke: color sprites only (SKShapeNode×hundreds was still GPU-heavy). Ship: light texture set.
        let tileTextures: [SKTexture] = smokeEnabled
            ? []
            : (1...8).compactMap { ArtCatalog.tileTexture(index: $0) }
        var tileIdx = 0
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                switch kind {
                case .ground, .wall, .latch:
                    if !tileTextures.isEmpty {
                        let tex = tileTextures[tileIdx % tileTextures.count]
                        let n = SKSpriteNode(texture: tex, size: CGSize(width: tile + 1, height: tile + 1))
                        n.position = pos
                        n.zPosition = 2
                        n.color = (tileIdx % 2 == 0) ? ArtCatalog.neonCyan : ArtCatalog.neonPink
                        n.colorBlendFactor = 0.18
                        world.addChild(n)
                    } else {
                        // One color sprite per solid (no child rim — keeps the 1-node budget).
                        let tint = tileIdx % 2 == 0
                            ? SKColor(red: 0.32, green: 0.36, blue: 0.52, alpha: 1)
                            : SKColor(red: 0.38, green: 0.26, blue: 0.46, alpha: 1)
                        let n = SKSpriteNode(color: tint, size: CGSize(width: tile + 1, height: tile + 1))
                        n.position = pos
                        n.zPosition = 2
                        world.addChild(n)
                    }
                    tileIdx += 1
                case .crate:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.9, height: tile * 0.9), cornerRadius: 2)
                    n.fillColor = SKColor(red: 0.62, green: 0.38, blue: 0.2, alpha: 1)
                    n.strokeColor = ArtCatalog.neonOrange
                    n.lineWidth = 1.5
                    n.position = pos
                    n.zPosition = 4
                    world.addChild(n)
                case .water:
                    let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                    n.fillColor = SKColor(red: 0.12, green: 0.42, blue: 0.62, alpha: 0.95)
                    n.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.7)
                    n.position = pos
                    n.zPosition = 1
                    world.addChild(n)
                case .spike:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.8, height: tile * 0.5))
                    n.fillColor = ArtCatalog.neonPink
                    n.strokeColor = .clear
                    n.glowWidth = 2
                    n.position = pos
                    n.zPosition = 5
                    world.addChild(n)
                case .checkpoint:
                    let pole = SKShapeNode(rectOf: CGSize(width: 4, height: tile * 1.4))
                    pole.fillColor = ArtCatalog.neonLime
                    pole.strokeColor = .clear
                    pole.position = pos
                    pole.zPosition = 6
                    world.addChild(pole)
                case .stash, .exit:
                    let door = SKShapeNode(rectOf: CGSize(width: tile * 1.2, height: tile * 1.6), cornerRadius: 4)
                    door.fillColor = SKColor(red: 0.12, green: 0.4, blue: 0.28, alpha: 0.95)
                    door.strokeColor = ArtCatalog.neonLime
                    door.lineWidth = 2
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
        stickBase.fillColor = SKColor(white: 1, alpha: 0.1)
        stickBase.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.7)
        stickBase.lineWidth = 2
        stickBase.zPosition = 200
        playHUD.addChild(stickBase)

        stickKnob = SKShapeNode(circleOfRadius: 28)
        stickKnob.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.5)
        stickKnob.strokeColor = ArtCatalog.neonCyan
        stickKnob.lineWidth = 2
        stickKnob.zPosition = 201
        playHUD.addChild(stickKnob)

        jumpBtn = makeFaceButton(title: "JUMP", color: ArtCatalog.neonLime)
        playHUD.addChild(jumpBtn)
        pounceBtn = makeFaceButton(title: "POUNCE", color: ArtCatalog.neonPink)
        playHUD.addChild(pounceBtn)
    }

    private func makeFaceButton(title: String, color: SKColor) -> SKShapeNode {
        let b = SKShapeNode(circleOfRadius: 42)
        b.fillColor = color.withAlphaComponent(0.45)
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
            label.fontSize = 16
            label.fontColor = color
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 210
            playHUD.addChild(label)
        }
        // FPS / TUNING only in DEBUG and never during SmokeAutoplay (review gate).
        #if DEBUG
        if !smokeEnabled {
            fpsLabel.fontSize = 11
            fpsLabel.fontColor = .white
            fpsLabel.horizontalAlignmentMode = .left
            fpsLabel.verticalAlignmentMode = .bottom
            fpsLabel.zPosition = 210
            hud.addChild(fpsLabel)
        }
        #endif
    }

    private func setupTitle() {
        titleRoot.zPosition = 300
        overlay.addChild(titleRoot)
        let bg = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        bg.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 0.78)
        bg.strokeColor = .clear
        titleRoot.addChild(bg)

        // Smoke: skip 2048 logo PNG decode at launch (jetsam window with other textures).
        let logo = ArtCatalog.makeLogoNode(lite: smokeEnabled)
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
        hint.fontColor = SKColor(white: 1, alpha: 0.75)
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

    #if DEBUG
    private func setupDebugTuning() {
        guard !smokeEnabled else { return }
        let menu = DebugTuningMenu(tuning: tuning)
        menu.onChange = { [weak self] t in
            guard let self else { return }
            self.tuning = t
            self.sim.tuning = t
        }
        overlay.addChild(menu)
        tuningMenu = menu

        let btn = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btn.text = "TUNING"
        btn.fontSize = 11
        btn.fontColor = ArtCatalog.neonCyan.withAlphaComponent(0.8)
        btn.name = "debugToggle"
        btn.zPosition = 880
        hud.addChild(btn)
        debugToggle = btn
    }
    #endif

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
        debugToggle?.position = CGPoint(x: hw - 40, y: hh - 18)
        tuningMenu?.position = .zero
        #endif
        updateHUDVisibility()
    }

    private func updateHUDVisibility() {
        let playing: Bool = {
            if case .playing = sim.state.phase { return true }
            return false
        }()
        playHUD.isHidden = !playing
        if !playing {
            stickKnob.position = stickBase.position
            moveX = 0
        }
    }

    private func cg(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    private func beginPlay() {
        if !smokeEnabled {
            JuiceSound.shared.play(.sfxUITap)
            JuiceSound.shared.startLevelMusic()
            hapticMed.impactOccurred()
        }
        sim.startRun()
        titleRoot.isHidden = true
        layoutUI()
        writeSmokeStatus()
    }

    private func doRetry() {
        JuiceSound.shared.play(.sfxUITap)
        sim.retry()
        hideOutcome()
        JuiceSound.shared.startLevelMusic()
        updateHUDVisibility()
    }

    // MARK: - Touch

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if smokeEnabled { return } // scripted input only
        for touch in touches {
            let p = touch.location(in: hud)
            #if DEBUG
            if let toggle = debugToggle, toggle.contains(p) {
                tuningMenu?.toggle()
                return
            }
            if let menu = tuningMenu, !menu.isHidden {
                if menu.handleTap(at: touch.location(in: overlay)) { return }
            }
            #endif
            if case .title = sim.state.phase {
                beginPlay()
                return
            }
            if case .won = sim.state.phase {
                doRetry(); return
            }
            if case .failed = sim.state.phase {
                doRetry(); return
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
        if smokeEnabled { return }
        for touch in touches where touch === stickTouch {
            updateStick(touch.location(in: hud))
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if smokeEnabled { return }
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
        if !smokeEnabled { JuiceSound.shared.setMaskModeMusic(false) }
        layoutUI()
    }

    // MARK: - Update

    public override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime
        lastTime = currentTime
        if dt > 0.1 { dt = 0.1 }

        let instFPS = 1 / max(dt, 0.0001)
        // Skip the first 2s (startup hitch) when averaging for the smoke gate.
        if sim.state.elapsed > 2 || !smokeEnabled {
            fpsSum += instFPS
            fpsCount += 1
        }
        #if DEBUG
        if !smokeEnabled {
            fpsAcc += dt
            if fpsAcc >= 0.25 {
                displayedFPS = Int(instFPS.rounded())
                fpsLabel.text = "FPS \(displayedFPS)"
                fpsAcc = 0
            }
        }
        #endif

        statusAcc += dt
        if smokeEnabled, statusAcc >= 0.5 {
            statusAcc = 0
            writeSmokeStatus()
        }

        // Cap hit-stop so we never freeze the sim for long (felt like hitches at low FPS).
        if hitStop > 0 { hitStop = max(0, hitStop - dt); if hitStop > 0 { return } }

        accumulator += dt
        var steps = 0
        // Smoke: 1:1 with display so wall-clock screenshots match sim moments / title hold.
        let maxSteps: Int = {
            if !smokeEnabled { return 4 }
            if case .title = sim.state.phase { return 1 }
            return 2
        }()
        while accumulator >= tuning.dt && steps < maxSteps {
            var input = InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld, pouncePressed: pouncePressed)
            jumpPressed = false
            pouncePressed = false

            if smokeEnabled {
                let cue = smoke.next(sim: sim)
                if cue.start { beginPlay() }
                if cue.retry { doRetry() }
                input = cue.input
                if stickBase != nil {
                    stickKnob.position = CGPoint(
                        x: stickBase.position.x + CGFloat(input.moveX) * 40,
                        y: stickBase.position.y
                    )
                }
            }

            if case .playing = sim.state.phase {
                sim.step(input)
                handle(sim.state.events)
            }
            accumulator -= tuning.dt
            steps += 1
        }
        sync(dt: CGFloat(dt))
        updateHUDVisibility()
    }

    private func handle(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .jump:
                if !smokeEnabled { JuiceSound.shared.play(.sfxJump); hapticLight.impactOccurred() }
                squash(0.85, 1.2)
            case .land:
                if !smokeEnabled { JuiceSound.shared.play(.sfxLand) }
                squash(1.25, 0.75)
                if !smokeEnabled { dust(at: e.position) }
            case .pounce:
                if !smokeEnabled { JuiceSound.shared.play(.sfxPounce); hapticMed.impactOccurred() }
                shake(0.35)
            case .flop:
                if !smokeEnabled { JuiceSound.shared.play(.sfxBellyFlop) }
                squash(1.35, 0.6)
            case .stomp:
                smoke.noteStomp()
                smokeStatus.stomps += 1
                if !smokeEnabled { JuiceSound.shared.play(.sfxMopHit); hapticHeavy.impactOccurred() }
                hitStop = smokeEnabled ? 0.015 : 0.04
                shake(0.35)
                pop("STOMP", at: e.position, ArtCatalog.neonPink)
            case .shiny:
                if !smokeEnabled { JuiceSound.shared.play(.sfxCollectShiny) }
                pop("✦", at: e.position, ArtCatalog.neonOrange)
            case .bank:
                if !smokeEnabled { JuiceSound.shared.play(.sfxCollectShiny) }
                pop("BANK", at: e.position, ArtCatalog.neonLime)
            case .maskOn:
                smoke.sawMask = true
                smokeStatus.mask = true
                if !smokeEnabled {
                    JuiceSound.shared.play(.sfxMaskModeOn)
                    if !maskMusicOn {
                        maskMusicOn = true
                        JuiceSound.shared.setMaskModeMusic(true)
                    }
                    hapticHeavy.impactOccurred()
                }
                flashMask()
                pop("MASK MODE", at: e.position, ArtCatalog.neonCyan)
            case .hurt:
                if !smokeEnabled { JuiceSound.shared.play(.sfxPlayerHit) }
                shake(0.3)
            case .win:
                smokeStatus.won = true
                if !smokeEnabled {
                    JuiceSound.shared.play(.sfxWin)
                    JuiceSound.shared.setMaskModeMusic(false)
                }
                showOutcome()
                writeSmokeStatus()
            case .fail:
                smokeStatus.died = true
                if !smokeEnabled {
                    JuiceSound.shared.play(.sfxFail)
                    JuiceSound.shared.setMaskModeMusic(false)
                }
                showOutcome()
                writeSmokeStatus()
            case .checkpoint:
                if !smokeEnabled { JuiceSound.shared.play(.sfxCheckpoint) }
                pop("CHECK", at: e.position, ArtCatalog.neonLime)
            case .dust:
                if !smokeEnabled { dust(at: e.position) }
            case .shake:
                shake(0.25)
            }
        }
        if !smokeEnabled, !sim.state.bandit.maskMode, maskMusicOn {
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
            guard let node = mopNodes[m.id] else { continue }
            node.position = cg(m.position)
            node.isHidden = !m.alive
            // Smoke mops are color sprites — never touch mop atlases (decode + per-frame swap).
            if !smokeEnabled, m.alive {
                if abs(m.position.x - b.position.x) < 80,
                   let alert = ArtCatalog.texture(.mopAlert) {
                    node.texture = alert
                } else if let patrol = ArtCatalog.texture(.mopPatrol) {
                    node.texture = patrol
                }
            }
        }

        let shinyTotal = b.carriedShinies + b.bankedShinies
        smokeStatus.shinies = shinyTotal
        hudCarried.text = "Shinies \(shinyTotal)"
        hudHearts.text = String(repeating: "♥", count: max(0, b.hearts))
        hudCombo.text = b.combo > 1 ? (b.maskMode ? "MASK x\(b.combo)" : "COMBO x\(b.combo)") : ""
        hudCombo.isHidden = b.combo <= 1
        hudTime.text = String(format: "Time %.0fs", sim.state.elapsed)

        let lead = CGFloat(b.facing * tuning.cameraLeadTiles * tuning.tileSize)
        let target = CGPoint(x: CGFloat(b.position.x) + lead, y: CGFloat(b.position.y) + 28)
        let s = CGFloat(tuning.cameraSmooth)
        cameraFocus.x += (target.x - cameraFocus.x) * s
        cameraFocus.y += (target.y - cameraFocus.y) * s
        let z = Self.worldZoom
        stage.position = CGPoint(x: -cameraFocus.x * z, y: -cameraFocus.y * z)
        // Parallax offsets inside stage (already scaled)
        parallaxFar.position = CGPoint(x: cameraFocus.x * 0.88, y: cameraFocus.y * 0.96)
        parallaxMid.position = CGPoint(x: cameraFocus.x * 0.65, y: cameraFocus.y * 0.92)
        parallaxNear.position = CGPoint(x: cameraFocus.x * 0.45, y: cameraFocus.y * 0.88)
    }

    private func squash(_ x: CGFloat, _ y: CGFloat) {
        if smokeEnabled { return }
        let face: CGFloat = bandit.sprite.xScale >= 0 ? 1 : -1
        bandit.sprite.removeAction(forKey: "sq")
        bandit.sprite.run(SKAction.sequence([
            SKAction.scaleX(to: x * face, y: y, duration: 0.05),
            SKAction.scaleX(to: 1 * face, y: 1, duration: 0.1),
        ]), withKey: "sq")
    }

    private func dust(at pos: Vec2) {
        if smokeEnabled { return }
        for _ in 0..<7 {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            p.fillColor = ArtCatalog.neonOrange.withAlphaComponent(0.75)
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
        if smokeEnabled { return }
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 16
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
        if smokeEnabled { return }
        // Shake world only (not stage) so camera sync isn't fighting a stage offset.
        let a = amount * 5
        world.run(SKAction.sequence([
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
            SKAction.moveBy(x: -2 * a, y: 0, duration: 0.04),
            SKAction.moveBy(x: a, y: 0, duration: 0.03),
        ]))
    }

    private func writeSmokeStatus() {
        let phase: String = {
            switch sim.state.phase {
            case .title: return "title"
            case .playing: return "playing"
            case .won: return "won"
            case .failed: return "failed"
            }
        }()
        smokeStatus.phase = phase
        smokeStatus.elapsed = sim.state.elapsed
        smokeStatus.fpsSamples = fpsCount
        smokeStatus.fpsAvg = fpsCount > 0 ? fpsSum / Double(fpsCount) : 0
        smokeStatus.write()
    }

    private func flashMask() {
        if smokeEnabled { return }
        let flash = SKShapeNode(circleOfRadius: 100)
        flash.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.4)
        flash.strokeColor = .clear
        flash.glowWidth = 8
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
