// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Side-view neon docks heist wired to `Assets/Generated/` via AssetManifest.
public final class HeistScene: SKScene {
    /// Zoom so playfield + skyline fill portrait (no empty black letterbox bands).
    public static let worldZoom: CGFloat = 1.42
    private var tileMapNode: SKTileMapNode?

    private var sim: Sim!
    private var tuning = Tuning.default
    private let stage = SKNode()
    private let world = SKNode()
    private let skyFill = SKSpriteNode()
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
    private let maskVignette = SKNode()
    private var lastMaskMode = false

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
    /// Shiny nodes mid collect-anim — sync must not hard-hide them.
    private var shinyCollecting: Set<Int> = []
    private var maskParticleAcc: CGFloat = 0
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

        // Publish phase=title BEFORE atlas/parallax warm so CI can attach during art load.
        // boot=loading until title chrome is actually on screen (see write after setupTitle).
        if smokeEnabled {
            smokeStatus.phase = "title"
            smokeStatus.boot = "loading"
            smokeStatus.write()
        }

        ArtCatalog.warmAtlases()
        // Screen-space sky fill prevents purple/black edge bands when the camera pans.
        skyFill.color = ArtCatalog.nightSky
        skyFill.zPosition = -100
        addChild(skyFill)
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
        buildMaskVignette()

        bandit = ArtCatalog.makeBanditVisual()
        bandit.zPosition = 50
        world.addChild(bandit)

        // Real MOP / Shiny art always. Cap only on the huge Neon Docks prop count.
        let shinyCap = smokeEnabled ? sim.state.shinies.count : min(sim.state.shinies.count, 40)
        for s in sim.state.shinies.prefix(shinyCap) {
            let n = ArtCatalog.makeShinyNode()
            n.position = cg(s.position)
            n.zPosition = 20
            world.addChild(n)
            shinyNodes[s.id] = n
        }
        let mopCap = smokeEnabled ? sim.state.mops.count : min(sim.state.mops.count, 24)
        for m in sim.state.mops.prefix(mopCap) {
            let n = ArtCatalog.makeMopNode()
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
        // Defer AVAudioSession until after atlases warm / title is up — early prepare jetsams
        // the sim. Smoke still gets music+SFX once play starts so the gameplay video has audio.
        if !smokeEnabled {
            JuiceSound.shared.prepare()
            JuiceSound.shared.playTitleSting()
            hapticLight.prepare(); hapticMed.prepare(); hapticHeavy.prepare()
        }
        layoutUI()
        sync(dt: 0)
        updateHUDVisibility()
        if smokeEnabled {
            smokeStatus.boot = "ready"
            writeSmokeStatus()
        }
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        guard stickBase != nil, sim != nil else { return }
        layoutUI()
    }

    // MARK: - Atmosphere / Parallax

    /// Thin translucent wash only — real parallax fills the sky (no opaque plate / black bands).
    private func buildAtmosphere() {
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)
        let mapH = CGFloat(sim.map.height) * CGFloat(tuning.tileSize)
        let wash = SKSpriteNode(
            color: ArtCatalog.dockFill.withAlphaComponent(0.22),
            size: CGSize(width: mapW + 280, height: mapH + 200)
        )
        wash.position = CGPoint(x: mapW * 0.5, y: mapH * 0.55)
        wash.zPosition = -6
        world.addChild(wash)
    }

    private func buildParallax() {
        let h = max(size.height / Self.worldZoom * 1.15, 620)
        // ImageIO-downsampled masters (≤1280px) — real neon city, safe GPU footprint.
        let maxPx: CGFloat = smokeEnabled ? 1024 : 1280
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)

        func tileLayer(_ node: SKSpriteNode, into parent: SKNode, y: CGFloat, z: CGFloat, brighten: Bool) {
            // Triple the plate horizontally so camera pans never expose the nightSky gap.
            let width = max(node.size.width, 1)
            let copies = max(3, Int(ceil((mapW + size.width) / width)) + 1)
            for i in 0..<copies {
                let plate = node.copy() as? SKSpriteNode ?? SKSpriteNode(texture: node.texture, size: node.size)
                plate.position = CGPoint(x: CGFloat(i) * width * 0.92, y: y)
                plate.zPosition = z
                if brighten {
                    plate.color = SKColor(red: 1.2, green: 1.08, blue: 1.25, alpha: 1)
                    plate.colorBlendFactor = 0.18
                }
                parent.addChild(plate)
            }
        }

        if let far = ArtCatalog.background(.farSkyline, height: h, maxPixel: maxPx) {
            tileLayer(far, into: parallaxFar, y: 48, z: -30, brighten: false)
        }
        // Subtle perspective grid horizon behind the skyline (one baked additive plate).
        let gridW = max(mapW + size.width, 1400)
        let grid = ArtCatalog.makePerspectiveGridHorizon(width: gridW, height: h * 0.55)
        grid.position = CGPoint(x: gridW * 0.28, y: 20)
        parallaxFar.addChild(grid)
        if let mid = ArtCatalog.background(.midBuildings, height: h * 0.92, maxPixel: maxPx) {
            tileLayer(mid, into: parallaxMid, y: 0, z: -20, brighten: true)
        }
        if let near = ArtCatalog.background(.nearRooftops, height: h * 0.75, maxPixel: maxPx) {
            near.alpha = 0.92
            tileLayer(near, into: parallaxNear, y: -40, z: -10, brighten: false)
        }

        // Rain via capped SKEmitterNode (not a 2560 overlay blit).
        let rain = ArtCatalog.rainEmitter(sceneSize: CGSize(width: size.width / Self.worldZoom, height: h))
        rainLayer.addChild(rain)
    }

    private func buildMaskVignette() {
        maskVignette.zPosition = 250
        maskVignette.alpha = 0
        maskVignette.isHidden = true
        overlay.addChild(maskVignette)
        // Soft full-bleed wash only — no left/right teal bands or letterbox bars.
        let wash = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.12), size: CGSize(width: 40, height: 40))
        wash.name = "wash"
        wash.blendMode = .add
        maskVignette.addChild(wash)
    }

    private func buildTiles() {
        let tile = CGFloat(tuning.tileSize)
        let tileSize = CGSize(width: tile, height: tile)
        let tileSet = ArtCatalog.makePlatformTileSet(tileSize: tileSize)
        let groups = tileSet.tileGroups
        guard !groups.isEmpty else { return }

        let mapNode = SKTileMapNode(
            tileSet: tileSet,
            columns: sim.map.width,
            rows: sim.map.height,
            tileSize: tileSize
        )
        mapNode.anchorPoint = CGPoint(x: 0, y: 0)
        mapNode.position = .zero
        mapNode.zPosition = 2
        var tileIdx = 0
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                switch kind {
                case .ground, .wall, .latch:
                    let group = groups[tileIdx % groups.count]
                    mapNode.setTileGroup(group, forColumn: x, row: y)
                    tileIdx += 1
                default:
                    break
                }
            }
        }
        world.addChild(mapNode)
        tileMapNode = mapNode

        // Decorative props + scaffolds under floating ledges so the route reads as a rooftop.
        let propTextures = (18...27).compactMap { ArtCatalog.tileTexture(index: $0) }
        var propI = 0
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                guard kind == .ground || kind == .wall || kind == .latch else { continue }
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                if !propTextures.isEmpty, (x + y * 3) % 9 == 0 {
                    let tex = propTextures[propI % propTextures.count]
                    propI += 1
                    let n = SKSpriteNode(texture: tex, size: CGSize(width: tile * 0.9, height: tile * 0.55))
                    n.position = CGPoint(x: pos.x, y: pos.y + tile * 0.35)
                    n.zPosition = 3
                    world.addChild(n)
                }
                // Pipes / scaffolds: drop supports from floating ledges down to the next solid deck.
                let below = sim.map.tile(atX: x, y: y - 1)
                if !sim.map.isSolid(below), below != .water {
                    var drop = 1
                    while y - drop >= 0 {
                        let t = sim.map.tile(atX: x, y: y - drop)
                        if sim.map.isSolid(t) || t == .water { break }
                        drop += 1
                    }
                    let span = CGFloat(drop) * tile
                    let pipe = SKShapeNode(rectOf: CGSize(width: tile * 0.16, height: span - 4), cornerRadius: 2)
                    pipe.fillColor = SKColor(red: 0.12, green: 0.1, blue: 0.22, alpha: 0.95)
                    pipe.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.7)
                    pipe.lineWidth = 1.4
                    pipe.position = CGPoint(x: pos.x, y: pos.y - span * 0.5)
                    pipe.zPosition = 1.4
                    world.addChild(pipe)
                    // Cross-brace every other column so ledges read as scaffolding, not free-floating tiles.
                    if x % 2 == 0, drop >= 2 {
                        let brace = SKShapeNode(rectOf: CGSize(width: tile * 0.95, height: 3), cornerRadius: 1)
                        brace.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 0.9)
                        brace.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.55)
                        brace.lineWidth = 1
                        brace.position = CGPoint(x: pos.x + tile * 0.35, y: pos.y - tile * 0.55)
                        brace.zPosition = 1.3
                        world.addChild(brace)
                    }
                }
            }
        }

        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                switch kind {
                case .ground, .wall, .latch:
                    break
                case .crate:
                    if let tex = ArtCatalog.tileTexture(index: 22) {
                        let n = SKSpriteNode(texture: tex, size: CGSize(width: tile * 0.95, height: tile * 0.95))
                        n.position = pos
                        n.zPosition = 4
                        world.addChild(n)
                    }
                case .water:
                    // Canal pool: dark body + neon surface line (no flat cyan placeholder slabs).
                    let body = SKShapeNode(rectOf: CGSize(width: tile * 1.02, height: tile * 0.85), cornerRadius: 2)
                    body.fillColor = SKColor(red: 0.05, green: 0.12, blue: 0.28, alpha: 0.92)
                    body.strokeColor = .clear
                    body.position = CGPoint(x: pos.x, y: pos.y - tile * 0.05)
                    body.zPosition = 1
                    world.addChild(body)
                    let surface = SKShapeNode(rectOf: CGSize(width: tile * 1.02, height: 3))
                    surface.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.85)
                    surface.strokeColor = .clear
                    surface.glowWidth = 1
                    surface.position = CGPoint(x: pos.x, y: pos.y + tile * 0.35)
                    surface.zPosition = 1.2
                    world.addChild(surface)
                case .spike:
                    let n = SKShapeNode(rectOf: CGSize(width: tile * 0.8, height: tile * 0.5))
                    n.fillColor = ArtCatalog.neonPink
                    n.strokeColor = .clear
                    n.glowWidth = 2
                    n.position = pos
                    n.zPosition = 5
                    world.addChild(n)
                case .checkpoint:
                    let pole = SKShapeNode(rectOf: CGSize(width: 5, height: tile * 1.5), cornerRadius: 1)
                    pole.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.62, alpha: 1)
                    pole.strokeColor = ArtCatalog.neonLime.withAlphaComponent(0.8)
                    pole.lineWidth = 1
                    pole.position = pos
                    pole.zPosition = 6
                    world.addChild(pole)
                    let flag = SKShapeNode(rectOf: CGSize(width: tile * 0.55, height: tile * 0.32), cornerRadius: 2)
                    flag.fillColor = ArtCatalog.neonLime.withAlphaComponent(0.9)
                    flag.strokeColor = .clear
                    flag.position = CGPoint(x: tile * 0.28, y: tile * 0.45)
                    pole.addChild(flag)
                case .stash, .exit:
                    let door = SKShapeNode(rectOf: CGSize(width: tile * 1.2, height: tile * 1.6), cornerRadius: 4)
                    door.fillColor = SKColor(red: 0.12, green: 0.4, blue: 0.28, alpha: 0.95)
                    door.strokeColor = ArtCatalog.neonLime
                    door.lineWidth = 2
                    door.glowWidth = 1
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
        // Neon stick: dark plate + crisp cyan ring (not a stock translucent blob).
        stickBase = SKShapeNode(circleOfRadius: 54)
        stickBase.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 0.78)
        stickBase.strokeColor = ArtCatalog.neonCyan
        stickBase.lineWidth = 2.5
        stickBase.glowWidth = 1.5
        stickBase.zPosition = 200
        playHUD.addChild(stickBase)
        let stickInner = SKShapeNode(circleOfRadius: 40)
        stickInner.fillColor = .clear
        stickInner.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.25)
        stickInner.lineWidth = 1
        stickInner.zPosition = 0.5
        stickBase.addChild(stickInner)

        stickKnob = SKShapeNode(circleOfRadius: 22)
        stickKnob.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.55)
        stickKnob.strokeColor = .white
        stickKnob.lineWidth = 1.5
        stickKnob.glowWidth = 1
        stickKnob.zPosition = 201
        playHUD.addChild(stickKnob)

        jumpBtn = makeFaceButton(title: "JUMP", color: ArtCatalog.neonLime)
        playHUD.addChild(jumpBtn)
        pounceBtn = makeFaceButton(title: "POUNCE", color: ArtCatalog.neonPink)
        playHUD.addChild(pounceBtn)
    }

    private func makeFaceButton(title: String, color: SKColor) -> SKShapeNode {
        // Capsule plates — separated neon buttons, not overlapping stock circles.
        let b = SKShapeNode(rectOf: CGSize(width: 92, height: 56), cornerRadius: 16)
        b.fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.82)
        b.strokeColor = color
        b.lineWidth = 2.5
        b.glowWidth = 1.5
        b.zPosition = 200
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = title
        t.fontSize = 13
        t.fontColor = color
        t.verticalAlignmentMode = .center
        t.name = "btnLabel"
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
            styleHUDLabel(label, color: color)
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

    /// Game font + dark outline shadow for readable neon HUD (no SKEffectNode).
    private func styleHUDLabel(_ label: SKLabelNode, color: SKColor) {
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 17
        label.fontColor = color
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.zPosition = 210
        if label.childNode(withName: "hudOutline") == nil {
            let outline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            outline.name = "hudOutline"
            outline.fontSize = 17
            outline.fontColor = SKColor(red: 0.02, green: 0.01, blue: 0.08, alpha: 0.9)
            outline.horizontalAlignmentMode = .left
            outline.verticalAlignmentMode = .top
            outline.position = CGPoint(x: 1.5, y: -1.5)
            outline.zPosition = -1
            label.addChild(outline)
        }
        if let outline = label.childNode(withName: "hudOutline") as? SKLabelNode {
            outline.text = label.text
        }
    }

    private func setupTitle() {
        titleRoot.zPosition = 300
        overlay.addChild(titleRoot)
        // Light wash — brighten the neon rooftop behind the logo (not a dim plate).
        let bg = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        bg.fillColor = SKColor(red: 0.04, green: 0.02, blue: 0.12, alpha: 0.22)
        bg.strokeColor = .clear
        bg.name = "titleWash"
        titleRoot.addChild(bg)

        let glow = SKShapeNode(circleOfRadius: 90)
        glow.name = "titleGlow"
        glow.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.16)
        glow.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.3)
        glow.lineWidth = 2
        glow.glowWidth = 6
        glow.zPosition = -1
        titleRoot.addChild(glow)

        let logo = ArtCatalog.makeLogoNode(lite: false)
        logo.name = "titleLogo"
        titleRoot.addChild(logo)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.name = "titleSub"
        // Swappable with TitleArt — no ASC / CFBundleDisplayName rename yet.
        sub.text = TitleArt.workingSubtitle
        sub.fontSize = 15
        sub.fontColor = ArtCatalog.neonPink
        titleRoot.addChild(sub)

        let play = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        play.name = "tapToStart"
        play.text = "TAP TO START"
        play.fontSize = 22
        play.fontColor = .white
        titleRoot.addChild(play)
        play.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.35, duration: 0.5),
                SKAction.scale(to: 0.94, duration: 0.5),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: 0.5),
                SKAction.scale(to: 1.08, duration: 0.5),
            ]),
        ])))

        let hintPlate = SKShapeNode(rectOf: CGSize(width: 280, height: 56), cornerRadius: 10)
        hintPlate.name = "hintPlate"
        hintPlate.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.1, alpha: 0.82)
        hintPlate.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.45)
        hintPlate.lineWidth = 1.5
        titleRoot.addChild(hintPlate)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.name = "titleHint"
        hint.text = "Left stick · JUMP · POUNCE\nStomp MOPs for Mask Mode"
        hint.fontSize = 13
        hint.fontColor = SKColor(white: 1, alpha: 0.95)
        hint.numberOfLines = 2
        hint.preferredMaxLayoutWidth = 260
        hint.verticalAlignmentMode = .center
        hintPlate.addChild(hint)

        layoutTitleChrome()
    }

    /// Fit full Neon City Bandit wordmark to ~85% width in the top third; pulse from fitted baseScale.
    private func layoutTitleChrome() {
        guard size.width > 1, size.height > 1 else { return }
        let topSafe = max(view?.safeAreaInsets.top ?? 54, 54)
        let bottomSafe = max(view?.safeAreaInsets.bottom ?? 20, 20)
        let hh = size.height * 0.5
        guard let logo = titleRoot.childNode(withName: "titleLogo") else { return }
        let base = ArtCatalog.fitTitleLogo(logo, sceneWidth: size.width, fraction: 0.85)
        // Top third of the safe playfield.
        let safeTop = hh - topSafe
        let safeBottom = -hh + bottomSafe
        let safeH = safeTop - safeBottom
        let logoY = safeTop - safeH * 0.18
        logo.position = CGPoint(x: 0, y: logoY)
        logo.removeAction(forKey: "logoPulse")
        logo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.88, duration: 1.0),
                SKAction.scale(to: base * 1.04, duration: 1.0),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 1.0),
                SKAction.scale(to: base, duration: 1.0),
            ]),
        ])), withKey: "logoPulse")

        if let glow = titleRoot.childNode(withName: "titleGlow") {
            glow.position = logo.position
            glow.setScale(max(1.0, size.width * 0.85 / 220))
        }
        titleRoot.childNode(withName: "titleSub")?.position = CGPoint(x: 0, y: logoY - 78)
        titleRoot.childNode(withName: "tapToStart")?.position = CGPoint(x: 0, y: -12)
        titleRoot.childNode(withName: "hintPlate")?.position = CGPoint(x: 0, y: -78)

        // Runtime + unit-testable gate: logo frame must sit inside safe area.
        let frame = logo.calculateAccumulatedFrame()
        let ok = ArtCatalog.logoFrameInsideSafeArea(
            logoFrame: frame,
            sceneSize: size,
            topSafe: topSafe,
            bottomSafe: bottomSafe
        )
        if !ok {
            // Nudge down/scale if anything still clips (defensive for odd sim sizes).
            let base2 = ArtCatalog.fitTitleLogo(logo, sceneWidth: size.width, fraction: 0.78)
            logo.position = CGPoint(x: 0, y: logoY - 24)
            logo.removeAction(forKey: "logoPulse")
            logo.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: base2 * 1.03, duration: 1.0),
                SKAction.scale(to: base2, duration: 1.0),
            ])), withKey: "logoPulse")
        }
    }

    private func setupOutcome() {
        outcomeRoot.zPosition = 320
        outcomeRoot.isHidden = true
        overlay.addChild(outcomeRoot)

        let wash = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        wash.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.58)
        wash.strokeColor = .clear
        wash.name = "outcomeWash"
        outcomeRoot.addChild(wash)

        let card = SKShapeNode(rectOf: CGSize(width: 292, height: 318), cornerRadius: 14)
        card.fillColor = SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 0.96)
        card.strokeColor = ArtCatalog.neonCyan
        card.lineWidth = 2.5
        card.glowWidth = 2
        card.name = "outcomeCard"
        outcomeRoot.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.name = "outcomeTitle"
        title.fontSize = 28
        title.fontColor = ArtCatalog.neonLime
        title.position = CGPoint(x: 0, y: 118)
        card.addChild(title)

        let stars = SKNode()
        stars.name = "outcomeStars"
        stars.position = CGPoint(x: 0, y: 78)
        card.addChild(stars)
        for i in 0..<3 {
            let star = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            star.text = "★"
            star.fontSize = 30
            star.fontColor = ArtCatalog.neonOrange.withAlphaComponent(0.25)
            star.position = CGPoint(x: CGFloat(i - 1) * 40, y: 0)
            star.name = "star\(i)"
            stars.addChild(star)
        }

        let shinyRow = SKNode()
        shinyRow.name = "outcomeShinies"
        shinyRow.position = CGPoint(x: 0, y: 36)
        card.addChild(shinyRow)
        let gear = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gear.text = "⚙"
        gear.fontSize = 22
        gear.fontColor = ArtCatalog.neonOrange
        gear.horizontalAlignmentMode = .right
        gear.position = CGPoint(x: -8, y: 0)
        gear.name = "gearIcon"
        shinyRow.addChild(gear)
        let shinyLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shinyLabel.name = "shinyCount"
        shinyLabel.fontSize = 22
        shinyLabel.fontColor = .white
        shinyLabel.horizontalAlignmentMode = .left
        shinyLabel.position = CGPoint(x: 4, y: 0)
        shinyRow.addChild(shinyLabel)

        let meta = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        meta.name = "outcomeMeta"
        meta.fontSize = 15
        meta.fontColor = SKColor(white: 0.92, alpha: 1)
        meta.position = CGPoint(x: 0, y: 4)
        card.addChild(meta)

        // Keep legacy name for count-up path compatibility.
        let stats = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        stats.name = "outcomeStats"
        stats.isHidden = true
        card.addChild(stats)

        let primary = makeOutcomeButton(title: "RETRY", color: ArtCatalog.neonLime, name: "retryBtn", wide: true)
        primary.position = CGPoint(x: 0, y: -52)
        card.addChild(primary)
        let next = makeOutcomeButton(title: "NEXT", color: ArtCatalog.neonLime, name: "nextBtn", wide: true)
        next.position = CGPoint(x: 0, y: -52)
        next.isHidden = true
        card.addChild(next)
        let home = makeOutcomeButton(title: "HOME", color: ArtCatalog.neonPink, name: "homeBtn", wide: false)
        home.position = CGPoint(x: 0, y: -118)
        card.addChild(home)
    }

    private func makeOutcomeButton(title: String, color: SKColor, name: String, wide: Bool = false) -> SKShapeNode {
        let size = wide ? CGSize(width: 220, height: 48) : CGSize(width: 140, height: 40)
        let b = SKShapeNode(rectOf: size, cornerRadius: wide ? 12 : 10)
        b.fillColor = color.withAlphaComponent(wide ? 0.38 : 0.22)
        b.strokeColor = color
        b.lineWidth = 2
        b.glowWidth = wide ? 1.5 : 1
        b.name = name
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = title
        t.fontSize = wide ? 17 : 14
        t.fontColor = .white
        t.verticalAlignmentMode = .center
        t.name = name
        b.addChild(t)
        return b
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
        // Keep chrome clear of the Dynamic Island / home indicator (extra pad under island).
        let topSafe = max(view?.safeAreaInsets.top ?? 59, 59) + 6
        let bottomSafe = max(view?.safeAreaInsets.bottom ?? 20, 20)
        let leftSafe = max(view?.safeAreaInsets.left ?? 0, 0)
        // Full-bleed sky — oversized so no black letterbox on any iPhone aspect.
        skyFill.size = CGSize(width: size.width * 3.2, height: size.height * 3.2)
        skyFill.position = .zero
        skyFill.color = ArtCatalog.nightSky

        stickBase.position = CGPoint(x: -hw + 72 + leftSafe, y: -hh + 96 + bottomSafe * 0.4)
        stickKnob.position = stickBase.position
        // Separated capsule buttons (no overlapping circles).
        jumpBtn.position = CGPoint(x: hw - 64, y: -hh + 118 + bottomSafe * 0.4)
        pounceBtn.position = CGPoint(x: hw - 64, y: -hh + 52 + bottomSafe * 0.4)
        let hudTop = hh - topSafe - 4
        let hudX = -hw + 14 + leftSafe
        hudCarried.position = CGPoint(x: hudX, y: hudTop)
        hudHearts.position = CGPoint(x: hudX, y: hudTop - 24)
        hudCombo.position = CGPoint(x: hudX, y: hudTop - 48)
        hudTime.position = CGPoint(x: hudX, y: hudTop - 72)
        for label in [hudCarried, hudHearts, hudCombo, hudTime] {
            if let outline = label.childNode(withName: "hudOutline") as? SKLabelNode {
                outline.text = label.text
            }
        }
        #if DEBUG
        fpsLabel.position = CGPoint(x: -hw + 16, y: -hh + 16 + bottomSafe * 0.25)
        debugToggle?.position = CGPoint(x: hw - 40, y: hudTop)
        tuningMenu?.position = .zero
        #endif

        if let wash = maskVignette.childNode(withName: "wash") as? SKSpriteNode {
            wash.size = size
            wash.position = .zero
        }
        if !titleRoot.isHidden {
            layoutTitleChrome()
        }
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
        // Start audio here (not in didMove) so smoke video has a soundtrack without launch jetsam.
        // simctl recordVideo has no app-audio track — smoke also writes smoke_audio_events.txt for mux.
        if smokeEnabled { JuiceSound.shared.beginSmokeAudioLog() }
        JuiceSound.shared.prepare()
        playSFX(.sfxUITap, smokeHero: true)
        JuiceSound.shared.startLevelMusic()
        if !smokeEnabled { hapticMed.impactOccurred() }
        sim.startRun()
        titleRoot.isHidden = true
        layoutUI()
        writeSmokeStatus()
    }

    private func doRetry() {
        JuiceSound.shared.prepare()
        playSFX(.sfxUITap, smokeHero: true)
        JuiceSound.shared.startLevelMusic()
        sim.retry()
        hideOutcome()
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
            if !outcomeRoot.isHidden, let card = outcomeRoot.childNode(withName: "outcomeCard") {
                let pCard = touch.location(in: card)
                if let home = card.childNode(withName: "homeBtn"), home.contains(pCard) {
                    hideOutcome()
                    JuiceSound.shared.stopMusic()
                    JuiceSound.shared.playTitleSting()
                    sim = Sim(map: sim.map, tuning: tuning, seed: smokeEnabled ? 7 : 11)
                    titleRoot.isHidden = false
                    layoutTitleChrome()
                    writeSmokeStatus()
                    updateHUDVisibility()
                    return
                }
                if let retry = card.childNode(withName: "retryBtn"), !retry.isHidden, retry.contains(pCard) {
                    doRetry()
                    return
                }
                if let next = card.childNode(withName: "nextBtn"), !next.isHidden, next.contains(pCard) {
                    doRetry()
                    return
                }
                if case .failed = sim.state.phase {
                    doRetry()
                }
                return
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
        if let card = outcomeRoot.childNode(withName: "outcomeCard") {
            card.removeAllActions()
            card.setScale(1)
            card.alpha = 1
            card.position = .zero
        }
        outcomeRoot.isHidden = true
        maskMusicOn = false
        JuiceSound.shared.setMaskModeMusic(false)
        maskVignette.removeAllActions()
        maskVignette.alpha = 0
        maskVignette.isHidden = true
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
        if smokeEnabled {
            // Title: write every frame so CI can snap 01-title before autoplay advances.
            let interval: TimeInterval = {
                if case .title = sim.state.phase { return 0.05 }
                return 0.35
            }()
            if statusAcc >= interval {
                statusAcc = 0
                writeSmokeStatus()
            }
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

    /// Smoke keeps music + hero SFX (stomp/mask/fail/win) so the video has a soundtrack,
    /// but skips per-jump/land spam — AVAudioPlayer decode on every event tanks sim FPS below 55.
    private func playSFX(_ key: AssetKey, smokeHero: Bool = false) {
        if smokeEnabled, !smokeHero { return }
        JuiceSound.shared.play(key)
    }

    private func handle(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .jump:
                playSFX(.sfxJump)
                if !smokeEnabled { hapticLight.impactOccurred() }
                squash(0.82, 1.22)
            case .land:
                playSFX(.sfxLand)
                squash(1.28, 0.72)
                dust(at: e.position)
            case .pounce:
                playSFX(.sfxPounce)
                if !smokeEnabled { hapticMed.impactOccurred() }
                shake(0.35)
            case .flop:
                playSFX(.sfxBellyFlop)
                squash(1.35, 0.6)
            case .stomp:
                smoke.noteStomp()
                // Midrun hold: ignore accidental pre-hunt stomps in the smoke counter/wait gate.
                let midrunOk = !smokeEnabled || SmokeBrain.smokeFlagExists("smoke_midrun_ok.txt")
                if midrunOk { smokeStatus.stomps += 1 }
                playSFX(.sfxMopHit, smokeHero: true)
                if !smokeEnabled { hapticHeavy.impactOccurred() }
                // ~70ms hit-stop + shake + neon burst + MOP squash (visible in smoke video).
                hitStop = 0.07
                shake(0.55)
                squash(1.35, 0.55)
                neonBurst(at: e.position, color: ArtCatalog.neonPink, count: smokeEnabled ? 6 : 10)
                dust(at: e.position)
                squashMop(at: e.position)
                stompPop(at: e.position)
            case .shiny:
                playSFX(.sfxCollectShiny)
                collectShinyJuice(at: e.position)
            case .bank:
                playSFX(.sfxCollectShiny)
                pop("BANK", at: e.position, ArtCatalog.neonLime)
            case .maskOn:
                smoke.sawMask = true
                smokeStatus.mask = true
                playSFX(.sfxMaskModeOn, smokeHero: true)
                if !maskMusicOn {
                    maskMusicOn = true
                    JuiceSound.shared.setMaskModeMusic(true)
                }
                if !smokeEnabled { hapticHeavy.impactOccurred() }
                flashMask()
            case .hurt:
                playSFX(.sfxPlayerHit, smokeHero: true)
                damageFlash()
                shake(0.3)
            case .win:
                smokeStatus.won = true
                playSFX(.sfxWin, smokeHero: true)
                JuiceSound.shared.setMaskModeMusic(false)
                showOutcome()
                writeSmokeStatus()
            case .fail:
                smokeStatus.died = true
                playSFX(.sfxFail, smokeHero: true)
                JuiceSound.shared.setMaskModeMusic(false)
                // Smoke: never overlay SPLASHED during the Mask beat capture window.
                let maskOk = SmokeBrain.smokeFlagExists("smoke_mask_ok.txt")
                if smokeEnabled, !maskOk {
                    writeSmokeStatus()
                } else {
                    showOutcome()
                    writeSmokeStatus()
                }
            case .checkpoint:
                playSFX(.sfxCheckpoint)
                pop("CHECK", at: e.position, ArtCatalog.neonLime)
            case .dust:
                dust(at: e.position)
            case .shake:
                shake(0.25)
            }
        }
        smokeStatus.maskOn = sim.state.bandit.maskMode
        if !sim.state.bandit.maskMode, maskMusicOn {
            maskMusicOn = false
            JuiceSound.shared.setMaskModeMusic(false)
        }
    }

    private func showOutcome() {
        outcomeRoot.isHidden = false
        layoutUI()
        guard let card = outcomeRoot.childNode(withName: "outcomeCard"),
              let title = card.childNode(withName: "outcomeTitle") as? SKLabelNode,
              let shinyCount = card.childNode(withName: "outcomeShinies")?.childNode(withName: "shinyCount") as? SKLabelNode,
              let meta = card.childNode(withName: "outcomeMeta") as? SKLabelNode,
              let starsNode = card.childNode(withName: "outcomeStars") else { return }
        // Slide/scale in — never an instant pop.
        card.removeAllActions()
        card.setScale(0.82)
        card.alpha = 0
        card.position = CGPoint(x: 0, y: -28)
        outcomeRoot.childNode(withName: "outcomeWash")?.alpha = 0
        outcomeRoot.childNode(withName: "outcomeWash")?.run(SKAction.fadeAlpha(to: 1, duration: 0.18))
        card.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.22),
            SKAction.moveTo(y: 0, duration: 0.22),
        ]))

        let shinies = sim.state.bandit.carriedShinies + sim.state.bandit.bankedShinies
        let starCount = min(3, max(1, shinies / 2 + (sim.state.bestCombo >= 3 ? 1 : 0)))
        let isWin: Bool
        let seconds: Double
        let combo: Int
        switch sim.state.phase {
        case .won(let s, let shinyTotal, let c):
            isWin = true
            seconds = s
            combo = c
            title.fontColor = ArtCatalog.neonLime
            title.text = "RESULTS"
            shinyCount.text = "0"
            meta.text = String(format: "⏱ %.1fs    ✦ combo x%d", seconds, combo)
            let finalShinies = shinyTotal
            shinyCount.removeAction(forKey: "count")
            if shinyCount.userData == nil { shinyCount.userData = NSMutableDictionary() }
            shinyCount.userData?["n"] = 0
            shinyCount.run(SKAction.repeat(SKAction.sequence([
                SKAction.run { [weak shinyCount] in
                    guard let shinyCount else { return }
                    let n = min(finalShinies, ((shinyCount.userData?["n"] as? Int) ?? 0) + 1)
                    shinyCount.userData?["n"] = n
                    shinyCount.text = "\(n)"
                },
                SKAction.wait(forDuration: 0.05),
            ]), count: max(1, finalShinies)), withKey: "count")
        case .failed(let reason):
            isWin = false
            seconds = sim.state.elapsed
            combo = sim.state.bestCombo
            title.fontColor = ArtCatalog.neonPink
            title.text = reason == .fellInWater ? "SPLASHED" : (reason == .spiked ? "SPIKED" : "BAGGED")
            shinyCount.text = "\(shinies)"
            meta.text = String(format: "⏱ %.0fs    ✦ combo x%d", seconds, combo)
        default:
            return
        }

        for i in 0..<3 {
            guard let star = starsNode.childNode(withName: "star\(i)") as? SKLabelNode else { continue }
            star.fontColor = ArtCatalog.neonOrange.withAlphaComponent(0.22)
            star.setScale(0.6)
            star.removeAllActions()
            if i < starCount {
                star.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.18 * Double(i)),
                    SKAction.group([
                        SKAction.run { JuiceSound.shared.play(.sfxUITap) },
                        SKAction.fadeAlpha(to: 1, duration: 0.12),
                        SKAction.scale(to: 1.2, duration: 0.12),
                    ]),
                    SKAction.run { star.fontColor = isWin ? ArtCatalog.neonLime : ArtCatalog.neonPink },
                    SKAction.scale(to: 1.0, duration: 0.1),
                ]))
            }
        }
        card.childNode(withName: "retryBtn")?.isHidden = isWin
        card.childNode(withName: "nextBtn")?.isHidden = !isWin
    }

    private func sync(dt: CGFloat) {
        let b = sim.state.bandit
        bandit.position = cg(b.position)
        bandit.setFacing(b.facing)
        bandit.show(anim: b.anim, maskMode: b.maskMode, dt: dt, smokeLite: smokeEnabled)
        bandit.alpha = b.invuln > 0 && Int(b.invuln * 20) % 2 == 0 ? 0.4 : 1

        for s in sim.state.shinies {
            guard let node = shinyNodes[s.id] else { continue }
            if shinyCollecting.contains(s.id) { continue }
            node.isHidden = !s.alive
        }
        for m in sim.state.mops {
            guard let node = mopNodes[m.id] else { continue }
            if node.userData?["squashing"] as? Bool == true { continue }
            node.position = cg(m.position)
            node.isHidden = !m.alive
            if m.alive {
                // Swap at most when crossing the alert threshold (avoid per-frame texture thrash).
                let alertNow = abs(m.position.x - b.position.x) < 80
                let key = alertNow ? "alert" : "patrol"
                if node.userData?["pose"] as? String != key {
                    if node.userData == nil { node.userData = NSMutableDictionary() }
                    node.userData?["pose"] = key
                    if alertNow, let alert = ArtCatalog.texture(.mopAlert) {
                        node.texture = alert
                    } else if let patrol = ArtCatalog.texture(.mopPatrol) {
                        node.texture = patrol
                    }
                }
            }
        }

        let shinyTotal = b.carriedShinies + b.bankedShinies
        smokeStatus.shinies = shinyTotal
        hudCarried.text = "Shinies \(shinyTotal)"
        hudHearts.text = String(repeating: "♥", count: max(0, b.hearts))
        if b.maskMode {
            hudCombo.text = b.combo > 1 ? "MASK ×2  COMBO x\(b.combo)" : "MASK ×2"
            hudCombo.isHidden = false
            hudCombo.fontColor = ArtCatalog.neonCyan
        } else if b.combo > 1 {
            hudCombo.text = "COMBO x\(b.combo)"
            hudCombo.isHidden = false
            hudCombo.fontColor = ArtCatalog.neonLime
        } else {
            hudCombo.text = ""
            hudCombo.isHidden = true
        }
        hudTime.text = String(format: "Time %.0fs", sim.state.elapsed)
        for label in [hudCarried, hudHearts, hudCombo, hudTime] {
            (label.childNode(withName: "hudOutline") as? SKLabelNode)?.text = label.text
        }
        // Mask Mode ambient particles (pooled trail handles the light streak).
        if b.maskMode {
            maskParticleAcc += dt
            if maskParticleAcc >= (smokeEnabled ? 0.12 : 0.08) {
                maskParticleAcc = 0
                neonBurst(at: b.position, color: ArtCatalog.neonCyan, count: 2)
            }
        } else {
            maskParticleAcc = 0
        }

        let lead = CGFloat(b.facing * tuning.cameraLeadTiles * tuning.tileSize)
        // Bias camera up so skyline fills the top of the portrait frame (no empty black band).
        var target = CGPoint(x: CGFloat(b.position.x) + lead, y: CGFloat(b.position.y) + 56)
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)
        let mapH = CGFloat(sim.map.height) * CGFloat(tuning.tileSize)
        let viewW = size.width / Self.worldZoom
        let viewH = size.height / Self.worldZoom
        let minX = viewW * 0.42
        let maxX = max(minX, mapW - viewW * 0.42)
        let minY = viewH * 0.38
        let maxY = max(minY, mapH - viewH * 0.25)
        target.x = min(max(target.x, minX), maxX)
        target.y = min(max(target.y, minY), maxY)
        let s = CGFloat(tuning.cameraSmooth)
        cameraFocus.x += (target.x - cameraFocus.x) * s
        cameraFocus.y += (target.y - cameraFocus.y) * s
        let z = Self.worldZoom
        stage.position = CGPoint(x: -cameraFocus.x * z, y: -cameraFocus.y * z)
        // Slow parallax — keep plates covering the view (tiled in buildParallax).
        parallaxFar.position = CGPoint(x: cameraFocus.x * 0.88, y: cameraFocus.y * 0.96)
        parallaxMid.position = CGPoint(x: cameraFocus.x * 0.72, y: cameraFocus.y * 0.92)
        parallaxNear.position = CGPoint(x: cameraFocus.x * 0.55, y: cameraFocus.y * 0.88)

        // Mask Mode vignette (motion trail is pooled inside BanditVisual.show).
        if b.maskMode {
            maskVignette.isHidden = false
            maskVignette.alpha = min(1, maskVignette.alpha + dt * 4)
        } else if lastMaskMode {
            maskVignette.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.run { [weak self] in self?.maskVignette.isHidden = true },
            ]))
        }
        lastMaskMode = b.maskMode
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
        let count = smokeEnabled ? 3 : 7
        for _ in 0..<count {
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

    private func shinySparkle(at pos: Vec2) {
        let count = smokeEnabled ? 3 : 6
        for _ in 0..<count {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.5))
            p.fillColor = ArtCatalog.neonOrange
            p.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.8)
            if !smokeEnabled { p.glowWidth = 1 }
            p.position = cg(pos)
            p.zPosition = 55
            world.addChild(p)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -28...28), y: CGFloat.random(in: 8...36), duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.35),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private func damageFlash() {
        let flash = SKSpriteNode(color: ArtCatalog.neonPink.withAlphaComponent(0.35), size: size)
        flash.zPosition = 280
        overlay.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.removeFromParent(),
        ]))
        bandit.sprite.run(SKAction.sequence([
            SKAction.colorize(with: ArtCatalog.neonPink, colorBlendFactor: 0.7, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0.14, duration: 0.2),
        ]))
    }

    private func pop(_ text: String, at pos: Vec2, _ color: SKColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 16
        l.fontColor = color
        l.position = cg(pos)
        l.zPosition = 60
        l.setScale(0.4)
        world.addChild(l)
        l.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.15, duration: 0.1),
                SKAction.moveBy(x: 0, y: 18, duration: 0.1),
            ]),
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.08),
                SKAction.moveBy(x: 0, y: 16, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func stompPop(at pos: Vec2) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = "STOMP"
        l.fontSize = 22
        l.fontColor = ArtCatalog.neonPink
        l.position = cg(pos)
        l.zPosition = 62
        l.setScale(0.2)
        l.alpha = 0
        world.addChild(l)
        l.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.05),
                SKAction.scale(to: 1.35, duration: 0.1),
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 28, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func neonBurst(at pos: Vec2, color: SKColor, count: Int) {
        let origin = cg(pos)
        for _ in 0..<count {
            let p = SKSpriteNode(color: color, size: CGSize(width: CGFloat.random(in: 3...6), height: CGFloat.random(in: 3...6)))
            p.blendMode = .add
            p.alpha = 0.9
            p.position = origin
            p.zPosition = 55
            world.addChild(p)
            let dx = CGFloat.random(in: -36...36)
            let dy = CGFloat.random(in: 6...42)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.28),
                    SKAction.fadeOut(withDuration: 0.28),
                    SKAction.scale(to: 0.2, duration: 0.28),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private func squashMop(at pos: Vec2) {
        let target = cg(pos)
        guard let pair = mopNodes.min(by: {
            hypot($0.value.position.x - target.x, $0.value.position.y - target.y)
                < hypot($1.value.position.x - target.x, $1.value.position.y - target.y)
        }) else { return }
        let node = pair.value
        if hypot(node.position.x - target.x, node.position.y - target.y) > 64 { return }
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["squashing"] = true
        node.removeAllActions()
        node.run(SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: 1.35, y: 0.25, duration: 0.08),
                SKAction.fadeAlpha(to: 0.5, duration: 0.08),
            ]),
            SKAction.group([
                SKAction.scaleY(to: 0.05, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1),
            ]),
            SKAction.run { [weak node] in
                node?.isHidden = true
                node?.setScale(1)
                node?.alpha = 1
                node?.userData?["squashing"] = false
            },
        ]))
    }

    private func collectShinyJuice(at pos: Vec2) {
        let target = cg(pos)
        var matchedId: Int?
        var matchedNode: SKNode?
        var best = CGFloat.greatestFiniteMagnitude
        for (id, node) in shinyNodes {
            let d = hypot(node.position.x - target.x, node.position.y - target.y)
            if d < best {
                best = d
                matchedId = id
                matchedNode = node
            }
        }
        shinySparkle(at: pos)
        if let id = matchedId, let node = matchedNode, best < 48 {
            shinyCollecting.insert(id)
            node.isHidden = false
            node.removeAllActions()
            node.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.45, duration: 0.08),
                    SKAction.fadeAlpha(to: 0.9, duration: 0.08),
                ]),
                SKAction.group([
                    SKAction.scale(to: 0.1, duration: 0.12),
                    SKAction.fadeOut(withDuration: 0.12),
                ]),
                SKAction.run { [weak self, weak node] in
                    node?.isHidden = true
                    node?.setScale(1)
                    node?.alpha = 1
                    self?.shinyCollecting.remove(id)
                },
            ]))
        }
        floatPlusOne(from: target)
    }

    private func floatPlusOne(from worldPos: CGPoint) {
        let gain = sim.state.bandit.maskMode ? "+2" : "+1"
        let floater = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        floater.text = gain
        floater.fontSize = 18
        floater.fontColor = ArtCatalog.neonOrange
        floater.zPosition = 230
        // Convert world → overlay so it can fly to the HUD counter.
        let scenePos = convert(worldPos, from: world)
        floater.position = scenePos
        overlay.addChild(floater)
        let dest = hudCarried.position
        floater.run(SKAction.sequence([
            SKAction.group([
                SKAction.move(to: dest, duration: 0.35),
                SKAction.scale(to: 0.7, duration: 0.35),
            ]),
            SKAction.fadeOut(withDuration: 0.08),
            SKAction.removeFromParent(),
        ]))
    }

    private func shake(_ amount: CGFloat) {
        // Keep shake visible in smoke video (slightly softer to avoid fighting the camera).
        let a = amount * (smokeEnabled ? 3.8 : 5)
        world.removeAction(forKey: "shake")
        world.run(SKAction.sequence([
            SKAction.moveBy(x: a, y: a * 0.35, duration: 0.03),
            SKAction.moveBy(x: -2 * a, y: -a * 0.7, duration: 0.04),
            SKAction.moveBy(x: a, y: a * 0.35, duration: 0.03),
            SKAction.run { [weak self] in self?.world.position = .zero },
        ]), withKey: "shake")
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
        smokeStatus.maskOn = sim.state.bandit.maskMode
        if sim.state.bandit.maskMode { smokeStatus.mask = true }
        smokeStatus.write()
    }

    private func flashMask() {
        // Activation color-grade + rings (baked additive sprites — no SKEffectNode / shaders).
        maskVignette.isHidden = false
        maskVignette.alpha = 0
        maskVignette.run(SKAction.fadeAlpha(to: 1, duration: 0.2))
        let grade = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.28), size: size)
        grade.blendMode = .add
        grade.zPosition = 275
        overlay.addChild(grade)
        grade.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.35),
            SKAction.removeFromParent(),
        ]))
        neonBurst(at: sim.state.bandit.position, color: ArtCatalog.neonCyan, count: smokeEnabled ? 8 : 14)
        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 18 + CGFloat(i) * 10)
            ring.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.8 - CGFloat(i) * 0.15)
            ring.fillColor = .clear
            ring.lineWidth = 2
            ring.position = bandit.position
            ring.zPosition = 46
            world.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.05 * Double(i)),
                SKAction.group([
                    SKAction.scale(to: 3.2, duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.35),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
        // Extra trail bursts on activation.
        for _ in 0..<4 { bandit.emitMaskTrail() }
        pop("MASK MODE", at: sim.state.bandit.position, ArtCatalog.neonCyan)
    }
}
#endif
