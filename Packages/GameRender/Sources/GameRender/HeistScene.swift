// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Side-view neon docks heist wired to `Assets/Generated/` via AssetManifest.
public final class HeistScene: SKScene {
    /// Zoom so playfield + skyline fill portrait (no empty black letterbox bands).
    public static let worldZoom: CGFloat = 1.85
    private var tileMapNode: SKTileMapNode?

    private var sim: Sim!
    private var tuning = Tuning.default
    private let stage = SKNode()
    private let world = SKNode()
    /// Must use the color initializer — bare `SKSpriteNode()` keeps a white texture at blendFactor 0.
    private let skyFill = SKSpriteNode(color: ArtCatalog.nightSky, size: CGSize(width: 4, height: 4))
    private let parallaxFar = SKNode()
    /// Physics body center → foot-anchor visual offset (matches Sim halfH).
    private let bodyCenterToFeet: CGFloat = 14
    private let parallaxMid = SKNode()
    private let parallaxNear = SKNode()
    private let rainLayer = SKNode()
    private var bandit: BanditVisual!
    private var shinyNodes: [Int: SKNode] = [:]
    private var mopNodes: [Int: MopVisual] = [:]
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
    private var publisherIdentRoot: SKNode?
    private var showingPublisherIdent = false
    /// Process-lifetime gate: cold launch only (never on resume / return-to-title).
    private static var didShowPublisherIdentThisProcess = false
    private var outcomeRoot = SKNode()
    private var retentionRoot = SKNode()
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
    /// Smoothed facing (−1…1) for the single camera look-ahead (ease ~0.4s on turn).
    private var cameraFacing: CGFloat = 1
    /// Smoke: after 04 is snapped, let Mask expire once before holding for 04b re-entry.
    private var smokeSawMaskDropAfterFirst = false
    /// Smoke harness accounting (written to Documents/smoke_forced_detail.txt).
    private var smokeMaskPinSeconds: Double = 0
    private var smokeMaskForceOffCount: Int = 0
    private var smokeMaskForceOffSeconds: Double = 0
    private var smokeSoftReviveCount: Int = 0
    private var smokePreMidrunMaskCancelCount: Int = 0
    private var smokeInvulnTopUpCount: Int = 0
    private var smokeMaskPinActive = false
    private var smokeLastForcedWrite: TimeInterval = 0
    /// After 04: decay-only Mask timer so mop-pack bounce stomps cannot refresh forever.
    private var smokeMaskDecayCap: Double = -1
    private var smokeMaskRefreshSuppressSeconds: Double = 0
    private var smokeMaskDecayArmed = false
    /// Camera side-switch hysteresis — ignore brief facing flips for lead direction.
    private var cameraFacingHoldUntil: TimeInterval = 0
    private var cameraWantFace: CGFloat = 1
    private var maskMusicOn = false
    /// MOP ids that already barked `mop_bot_alert` this approach.
    private var mopAlerted: Set<Int> = []
    private var hapticLight = UIImpactFeedbackGenerator(style: .light)
    private var hapticMed = UIImpactFeedbackGenerator(style: .medium)
    private var hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    private var smokeEnabled = false
    private var smoke = SmokeBrain()
    private var smokeStatus = SmokeStatus()
    private var progressStore = ProgressStore()
    /// Sum of frame durations (seconds) after the startup hitch — avg FPS = samples / fpsTimeSum.
    private var fpsTimeSum: Double = 0
    private var fpsCount: Int = 0
    private var maxFrameMs: Double = 0
    /// Skip one freeze sample after pause/resume so the gap does not look like a hitch.
    private var skipFreezeSample = false
    /// One title→play transition frame may be up to this many ms without failing the freeze gate.
    private var transitionBudgetMs: Double = 0
    private let titlePlayTransitionBudgetMs: Double = 250
    private var moveY: Double = 0
    private var story = StoryCatalog.load()
    private var introRoot = SKNode()
    private var introPanelIndex = 0
    private var showingIntro = false
    private var districtCardRoot = SKNode()
    private var showingDistrictCard = false
    private var crewNodes: [Int: SKNode] = [:]
    private var pendingDistrict: DistrictID = .neonDocks
    private var mopChatterAcc: TimeInterval = 0
    private var statusAcc: TimeInterval = 0
    /// Shiny nodes mid collect-anim — sync must not hard-hide them.
    private var shinyCollecting: Set<Int> = []
    private var maskParticleAcc: CGFloat = 0
    private var maskGradePulse: CGFloat = 0
    private var lastAwardedMedals = 0
    private var retentionMode: String? = nil // "map" | "daily"
    /// Gameplay pause (not SKScene.isPaused — that freezes the whole tree).
    private var runPaused = false
    private var pauseFromSystem = false
    private var resumeCountdown: TimeInterval = 0
    private var failOutcomeHold: TimeInterval = 0
    /// Reusable land dust burst (replaces 8 SKShapeNodes per land).
    private var landDustEmitter: SKEmitterNode?
    private let pauseRoot = SKNode()
    private var pauseBtn: SKShapeNode!
    private var pauseCountLabel: SKLabelNode?
    /// First-minute pacing: objective banner, early win, mid-run surprise.
    private var objectiveBanner: SKNode?
    private var celebratedFirstStomp = false
    private var celebratedEarlyWin = false
    private var midSurpriseFired = false
    private var exitBeacon: SKNode?
    /// Wall-clock play timer for smoke (monotonic across death/retry — review gate).
    private var smokeWallStart: TimeInterval = 0
    private var smokeWallElapsed: TimeInterval = 0
    /// Photosensitivity: timestamps of full-screen flashes in the last second.
    private var flashHistory: [TimeInterval] = []
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
        // Smoke uses ship tuning + real Neon Docks — only input source / seed / status flags differ.
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
            let map = try NeonDocksLevel.load()
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
        // Pre-warm KO / Mask / dust so first hurt/Mask entry doesn't hitch ~170ms.
        _ = ArtCatalog.texture(.raccoonMaskMode)
        _ = ArtCatalog.texture(.raccoonBellyFlop)
        _ = ArtCatalog.softCircleTexture()
        // Preload gameplay textures while title is up so beginPlay stays within the 250ms budget.
        ArtCatalog.preloadGameplayTextures()
        // Scene night only — no opaque full-map wash quads (they hid the neon city).
        skyFill.color = ArtCatalog.nightSky
        skyFill.colorBlendFactor = 1
        skyFill.zPosition = -100
        addChild(skyFill)
        stage.setScale(Self.worldZoom)
        addChild(stage)
        stage.addChild(parallaxFar)
        stage.addChild(parallaxMid)
        stage.addChild(parallaxNear)
        stage.addChild(world)
        world.addChild(rainLayer)
        view.allowsTransparency = false
        backgroundColor = ArtCatalog.nightSky
        buildParallax()
        buildTiles()
        buildMaskVignette()
        ensureLandDustEmitter()

        bandit = ArtCatalog.makeBanditVisual()
        bandit.zPosition = 50
        world.addChild(bandit)
        // Touch death + Mask sheets once so GPU upload isn't on the KO/Mask frame.
        bandit.prewarmCombatTextures()

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
        for c in sim.state.crewCages {
            let n = makeCrewCageNode(crewID: c.crewID)
            n.position = cg(c.position)
            n.zPosition = 28
            world.addChild(n)
            crewNodes[c.id] = n
        }

        addChild(hud)
        hud.addChild(playHUD)
        addChild(overlay)
        setupControls()
        setupHUD()
        setupTitle()
        setupStoryOverlays()
        setupOutcome()
        setupPauseMenu()
        setupRetention()
        #if DEBUG
        setupDebugTuning()
        #endif
        // Defer AVAudioSession until after atlases warm — early prepare jetsams the sim.
        // Title sting waits until after the publisher ident (or immediately if skipped).
        JuiceSound.shared.prepare()
        if !smokeEnabled {
            hapticLight.prepare(); hapticMed.prepare(); hapticHeavy.prepare()
        }
        layoutUI()
        // Safe-area insets often arrive a beat after didMove — re-layout so HUD clears the island.
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.layoutUI() },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in self?.layoutUI() },
        ]), withKey: "safeAreaRelayout")
        sync(dt: 0)
        // Publisher splash first (cold launch / smoke). Gameplay textures already preloading above.
        if shouldPresentPublisherIdent() {
            presentPublisherIdent()
        } else {
            finishPublisherIdentAndShowTitle()
        }
        updateHUDVisibility()
    }

    private func shouldPresentPublisherIdent() -> Bool {
        // Smoke always shows once per launch so CI can artifact the still.
        if smokeEnabled { return !Self.didShowPublisherIdentThisProcess }
        return !Self.didShowPublisherIdentThisProcess
    }

    private func presentPublisherIdent() {
        Self.didShowPublisherIdentThisProcess = true
        showingPublisherIdent = true
        titleRoot.isHidden = true
        // Scene-level (above overlay) so the charcoal splash can't sit under title chrome.
        let root = PublisherIdent.buildRoot(sceneSize: size)
        root.zPosition = 900
        publisherIdentRoot = root
        addChild(root)
        layoutPublisherIdentBackground()
        if smokeEnabled {
            smokeStatus.phase = "title"
            smokeStatus.boot = "ident"
            writeSmokeStatus()
        }
        JuiceSound.shared.playPublisherIdentWhoosh()
        let reduce = PublisherIdent.reduceMotionEnabled
        PublisherIdent.runPresentation(
            on: root,
            reduceMotion: reduce,
            smokeHold: smokeEnabled
        ) { [weak self] in
            self?.finishPublisherIdentAndShowTitle()
        }
    }

    private func layoutPublisherIdentBackground() {
        guard let root = publisherIdentRoot,
              let bg = root.childNode(withName: "publisherBg") as? SKSpriteNode else { return }
        bg.xScale = 1
        bg.yScale = 1
        bg.size = CGSize(width: max(size.width, 1) * 4, height: max(size.height, 1) * 4)
        bg.position = .zero
        bg.alpha = 1
    }

    private func skipPublisherIdentIfNeeded() {
        guard showingPublisherIdent else { return }
        publisherIdentRoot?.removeAction(forKey: "publisherIdent")
        finishPublisherIdentAndShowTitle()
    }

    private func finishPublisherIdentAndShowTitle() {
        publisherIdentRoot?.removeAllActions()
        publisherIdentRoot?.removeFromParent()
        publisherIdentRoot = nil
        showingPublisherIdent = false
        presentIntroIfNeededAfterIdent()
        if showingIntro {
            // Intro covers title; still mark boot ready so smoke can proceed after comic skip paths.
            if smokeEnabled {
                smokeStatus.boot = "ready"
                writeSmokeStatus()
            }
            updateHUDVisibility()
            return
        }
        showTitleScreen()
        JuiceSound.shared.playTitleSting()
        if smokeEnabled {
            smokeStatus.boot = "ready"
            writeSmokeStatus()
        }
        updateHUDVisibility()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        guard stickBase != nil, sim != nil else { return }
        layoutUI()
    }

    // MARK: - Atmosphere / Parallax

    private func buildParallax() {
        // Cover the full viewport height so the neon city is visible behind platforms.
        let viewH = size.height / Self.worldZoom
        let h = max(viewH * 1.25, 680)
        // Cap plate resolution — 1280px tiles were crushing simulator FPS.
        let maxPx: CGFloat = 960
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)

        func tileLayer(
            _ node: SKSpriteNode,
            into parent: SKNode,
            y: CGFloat,
            z: CGFloat,
            neonBoost: Bool
        ) {
            let width = max(node.size.width, 1)
            // Cover the camera lead without over-tiling the full map width.
            let cover = min(mapW, size.width / Self.worldZoom * 4) + width
            let copies = max(2, Int(ceil(cover / width)) + 1)
            for i in 0..<copies {
                let plate = node.copy() as? SKSpriteNode ?? SKSpriteNode(texture: node.texture, size: node.size)
                plate.position = CGPoint(x: CGFloat(i) * width * 0.92, y: y)
                plate.zPosition = z
                // Keep storefront neon readable for the midrun palette gate — do NOT
                // wash toward muted purple-gray (that hid magenta/teal and dimmed the city).
                if neonBoost {
                    // Lift mid-tones so the alley isn't a grimy 22–33/255 wash,
                    // but keep sky darker than lit sprites (readability).
                    plate.color = SKColor(red: 1.0, green: 0.55, blue: 0.92, alpha: 1)
                    plate.colorBlendFactor = 0.22
                    plate.alpha = 1.0
                } else {
                    plate.color = SKColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1)
                    plate.colorBlendFactor = 0.12
                    plate.alpha = 0.95
                }
                parent.addChild(plate)
            }
        }

        // Raise skyline into the midrun sample band (y 18–62% of the frame).
        let midY = viewH * 0.18
        if let far = ArtCatalog.background(.farSkyline, height: h, maxPixel: maxPx) {
            tileLayer(far, into: parallaxFar, y: midY + 60, z: -30, neonBoost: false)
        }
        let gridW = min(max(mapW * 0.5, size.width / Self.worldZoom * 3), 1800)
        let grid = ArtCatalog.makePerspectiveGridHorizon(width: gridW, height: h * 0.55)
        grid.position = CGPoint(x: gridW * 0.28, y: midY)
        grid.alpha = 0.4
        parallaxFar.addChild(grid)
        // Living far city: twinkling windows + a slow skyline transit.
        let windows = ArtCatalog.livingWindowLights(width: min(mapW * 0.6, 1400), height: h * 0.35)
        windows.position = CGPoint(x: mapW * 0.22, y: midY + 90)
        parallaxFar.addChild(windows)
        parallaxFar.addChild(ArtCatalog.skylineTransit(width: min(mapW * 0.7, 1600), y: midY + 40))
        if let mid = ArtCatalog.background(.midBuildings, height: h * 1.1, maxPixel: maxPx) {
            tileLayer(mid, into: parallaxMid, y: midY + 10, z: -20, neonBoost: true)
        }
        // Magenta + teal storefront signage in the mid band (readability + palette).
        // Keep strips high enough that the midrun storefront-band (12–48% screen) sees them.
        let signs = ArtCatalog.neonSignageStrip(width: mapW * 0.7, height: 96)
        signs.position = CGPoint(x: mapW * 0.18, y: midY + 118)
        parallaxMid.addChild(signs)
        let signsLow = ArtCatalog.neonSignageStrip(width: mapW * 0.45, height: 56)
        signsLow.position = CGPoint(x: mapW * 0.4, y: midY + 52)
        signsLow.alpha = 0.9
        parallaxMid.addChild(signsLow)
        // Sweeping searchlight + street steam so the mid band feels alive.
        let light = ArtCatalog.neonSearchlight(height: h * 0.5)
        light.position = CGPoint(x: mapW * 0.3, y: midY + 40)
        parallaxMid.addChild(light)
        if let near = ArtCatalog.background(.nearRooftops, height: h * 0.9, maxPixel: maxPx) {
            tileLayer(near, into: parallaxNear, y: midY - 40, z: -10, neonBoost: false)
        }
        let steam = ArtCatalog.streetSteamEmitter(width: size.width / Self.worldZoom)
        steam.position = CGPoint(x: 0, y: -viewH * 0.12)
        parallaxNear.addChild(steam)

        let rain = ArtCatalog.rainEmitter(sceneSize: CGSize(width: size.width / Self.worldZoom, height: h))
        rainLayer.addChild(rain)
    }

    /// Wet-floor neon reflections under walkable tops (soft cyan/magenta puddles, not solid bars).
    private func addWetFloorReflection(at pos: CGPoint, tile: CGFloat) {
        let puddle = SKSpriteNode(texture: ArtCatalog.softCircleTexture(), size: CGSize(width: tile * 1.1, height: tile * 0.35))
        puddle.name = "wetFloor"
        puddle.position = CGPoint(x: pos.x, y: pos.y + tile * 0.42)
        puddle.color = ArtCatalog.neonPink
        puddle.colorBlendFactor = 1
        puddle.alpha = 0.45
        puddle.blendMode = .add
        puddle.zPosition = 3.04
        world.addChild(puddle)
        let cyan = SKSpriteNode(texture: ArtCatalog.softCircleTexture(), size: CGSize(width: tile * 0.85, height: tile * 0.22))
        cyan.name = "wetFloorCyan"
        cyan.position = CGPoint(x: pos.x + tile * 0.12, y: pos.y + tile * 0.36)
        cyan.color = ArtCatalog.neonCyan
        cyan.colorBlendFactor = 1
        cyan.alpha = 0.4
        cyan.blendMode = .add
        cyan.zPosition = 3.05
        world.addChild(cyan)
    }

    /// World-space storefront sign crops (SPOTLESS / GLOW MART / …) so midrun stills show real neon.
    private func placeWorldStorefrontSigns() {
        let signs = ArtCatalog.worldStorefrontSigns(
            mapWidth: CGFloat(sim.map.width) * CGFloat(tuning.tileSize),
            tile: CGFloat(tuning.tileSize)
        )
        world.addChild(signs)
    }

    private func buildMaskVignette() {
        maskVignette.zPosition = 250
        maskVignette.alpha = 0
        maskVignette.isHidden = true
        overlay.addChild(maskVignette)
        // No full-screen cyan/magenta color plates — SKSpriteNode(color:) + purge can
        // read as an opaque neon wash and trip the CI cyanWash gate. Mask Mode grade is
        // character glow + a soft dark edge only.
        let edge = SKSpriteNode(color: SKColor(red: 0.02, green: 0.01, blue: 0.08, alpha: 1), size: CGSize(width: 40, height: 40))
        edge.name = "vignetteEdge"
        edge.blendMode = .alpha
        edge.zPosition = 2
        edge.alpha = 0.22
        maskVignette.addChild(edge)
    }

    /// Prefer live view/window insets; fall back to iPhone island/home values so HUD never sits under chrome.
    private func safeInsets() -> UIEdgeInsets {
        var s = view?.safeAreaInsets ?? .zero
        if s.top < 20, let win = view?.window {
            s = win.safeAreaInsets
        }
        if s.top < 20 {
            s.top = 59
            s.bottom = max(s.bottom, 34)
        }
        return s
    }

    private func buildTiles() {
        let tile = CGFloat(tuning.tileSize)
        let tileSize = CGSize(width: tile, height: tile)
        let tileSet = ArtCatalog.makePlatformTileSet(tileSize: tileSize)
        let groups = tileSet.tileGroups
        guard groups.count >= 16 else { return }

        func isGroundSolid(_ kind: Tile) -> Bool {
            kind == .ground || kind == .wall || kind == .latch || kind == .crate
        }
        func solidNeighbor(x: Int, y: Int) -> Bool {
            guard x >= 0, y >= 0, x < sim.map.width, y < sim.map.height else { return true }
            return isGroundSolid(sim.map.tile(atX: x, y: y))
        }

        let mapNode = SKTileMapNode(
            tileSet: tileSet,
            columns: sim.map.width,
            rows: sim.map.height,
            tileSize: tileSize
        )
        mapNode.anchorPoint = CGPoint(x: 0, y: 0)
        mapNode.position = .zero
        mapNode.zPosition = 2
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                // Latch poles are drawn as neon pillars below — skip autotile (isolated
                // neighbour masks read as a grey "X" placeholder on the climb tower).
                guard kind == .ground || kind == .wall || kind == .crate else { continue }
                // 4-neighbour mask: N=1 E=2 S=4 W=8
                var mask = 0
                if solidNeighbor(x: x, y: y + 1) { mask |= 1 }
                if solidNeighbor(x: x + 1, y: y) { mask |= 2 }
                if solidNeighbor(x: x, y: y - 1) { mask |= 4 }
                if solidNeighbor(x: x - 1, y: y) { mask |= 8 }
                mapNode.setTileGroup(groups[mask], forColumn: x, row: y)
            }
        }
        world.addChild(mapNode)
        tileMapNode = mapNode
        placeWorldStorefrontSigns()

        // Neon latch poles (climbable) — thin cyan/magenta shaft, not grey autotile X.
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                guard sim.map.tile(atX: x, y: y) == .latch else { continue }
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                let shaft = SKShapeNode(rectOf: CGSize(width: tile * 0.28, height: tile * 0.98), cornerRadius: 2)
                shaft.fillColor = SKColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 0.95)
                shaft.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.75)
                shaft.lineWidth = 1.2
                shaft.glowWidth = 0.6
                shaft.position = pos
                shaft.zPosition = 2.6
                world.addChild(shaft)
                let rim = SKSpriteNode(color: ArtCatalog.neonPink.withAlphaComponent(0.55), size: CGSize(width: tile * 0.08, height: tile * 0.9))
                rim.position = CGPoint(x: pos.x + tile * 0.1, y: pos.y)
                rim.zPosition = 2.65
                rim.blendMode = .add
                world.addChild(rim)
            }
        }

        // Kenney CC0 crates/pipes as sparse decoration — never as collision face / under-ledge drips.
        let propTextures = ArtCatalog.sidePropTextures()
        var propI = 0
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let kind = sim.map.tile(atX: x, y: y)
                guard kind == .ground || kind == .wall else { continue }
                let pos = cg(sim.map.worldCenter(ofX: x, y: y, tileSize: tuning.tileSize))
                let below = sim.map.tile(atX: x, y: y - 1)
                let openBelow = !sim.map.isSolid(below) && below != .water

                // Occasional crate / pipe on walkable tops only (never hanging under ledges).
                if !propTextures.isEmpty, !openBelow, (x + y * 5) % 17 == 0 {
                    let tex = propTextures[propI % propTextures.count]
                    propI += 1
                    let n = SKSpriteNode(texture: tex, size: CGSize(width: tile * 0.7, height: tile * 0.7))
                    n.position = CGPoint(x: pos.x, y: pos.y + tile * 0.55)
                    n.zPosition = 3.2
                    n.alpha = 0.92
                    // Kill any baked green tint from Kenney sheets (no green drips).
                    n.color = SKColor(red: 0.72, green: 0.68, blue: 0.78, alpha: 1)
                    n.colorBlendFactor = 0.55
                    world.addChild(n)
                }

                // Wet-floor reflections (sparse) under solid tops.
                if !openBelow, (x + y * 3) % 3 == 0 {
                    addWetFloorReflection(at: pos, tile: tile)
                }

                // Short neon strip lights (1–2 tiles) on every other floating ledge — soft glow, not full pink bars.
                if openBelow, x % 2 == 0, (x / 2) % 2 == 0 {
                    let stripW = tile * (1.4 + CGFloat(x % 3) * 0.3)
                    let strip = SKSpriteNode(color: ArtCatalog.neonPink, size: CGSize(width: stripW, height: 3))
                    strip.name = "neonStrip"
                    strip.position = CGPoint(x: pos.x + tile * 0.35, y: pos.y - tile * 0.4)
                    strip.alpha = 0.9
                    strip.blendMode = .add
                    strip.zPosition = 3.1
                    world.addChild(strip)
                    let glow = SKSpriteNode(texture: ArtCatalog.softCircleTexture(), size: CGSize(width: stripW * 1.6, height: 18))
                    glow.name = "neonStripGlow"
                    glow.position = strip.position
                    glow.color = ArtCatalog.neonPink
                    glow.colorBlendFactor = 1
                    glow.alpha = 0.55
                    glow.blendMode = .add
                    glow.zPosition = 3.05
                    world.addChild(glow)
                    // Wet reflection puddle under the strip light.
                    addWetFloorReflection(at: CGPoint(x: pos.x + tile * 0.35, y: pos.y - tile * 1.1), tile: tile)
                }

                // Dark metal brackets under floating ledges (no green Kenney drips).
                if openBelow, x % 2 == 0 {
                    var drop = 1
                    while y - drop >= 0 {
                        let t = sim.map.tile(atX: x, y: y - drop)
                        if sim.map.isSolid(t) || t == .water { break }
                        drop += 1
                    }
                    guard drop >= 2 else { continue }
                    let span = CGFloat(drop) * tile
                    let pipe = SKShapeNode(rectOf: CGSize(width: tile * 0.12, height: span - 6), cornerRadius: 1)
                    pipe.fillColor = SKColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 0.9)
                    pipe.strokeColor = SKColor(white: 0.25, alpha: 0.5)
                    pipe.lineWidth = 0.5
                    pipe.position = CGPoint(x: pos.x, y: pos.y - span * 0.5)
                    pipe.zPosition = 1.2
                    world.addChild(pipe)
                    let brace = SKShapeNode(rectOf: CGSize(width: tile * 0.55, height: 2.5), cornerRadius: 1)
                    brace.fillColor = SKColor(red: 0.16, green: 0.16, blue: 0.2, alpha: 0.95)
                    brace.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.2)
                    brace.lineWidth = 0.4
                    brace.position = CGPoint(x: pos.x, y: pos.y - tile * 0.2)
                    brace.zPosition = 1.25
                    world.addChild(brace)
                }

                // Bare wall columns get rivet / panel detail so they aren't flat grey slabs.
                if kind == .wall, openBelow == false, x % 3 == 1 {
                    let panel = SKShapeNode(rectOf: CGSize(width: tile * 0.7, height: tile * 0.55), cornerRadius: 2)
                    panel.fillColor = SKColor(red: 0.14, green: 0.12, blue: 0.22, alpha: 0.85)
                    panel.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.35)
                    panel.lineWidth = 0.8
                    panel.position = pos
                    panel.zPosition = 2.4
                    world.addChild(panel)
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
                    let tex = ArtCatalog.sidePropTexture(index: 20)
                        ?? ArtCatalog.sidePropTexture(index: 21)
                        ?? ArtCatalog.tileTexture(index: 22)
                    if let tex {
                        let n = SKSpriteNode(texture: tex, size: CGSize(width: tile * 0.95, height: tile * 0.95))
                        n.position = pos
                        n.zPosition = 4
                        world.addChild(n)
                    }
                case .water:
                    let body = SKShapeNode(rectOf: CGSize(width: tile * 1.02, height: tile * 0.85), cornerRadius: 2)
                    body.fillColor = SKColor(red: 0.05, green: 0.12, blue: 0.28, alpha: 0.92)
                    body.strokeColor = .clear
                    body.position = CGPoint(x: pos.x, y: pos.y - tile * 0.05)
                    body.zPosition = 1
                    world.addChild(body)
                    let surface = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.85), size: CGSize(width: tile * 1.02, height: 3))
                    surface.position = CGPoint(x: pos.x, y: pos.y + tile * 0.35)
                    surface.zPosition = 1.2
                    world.addChild(surface)
                case .spike:
                    let n = SKSpriteNode(color: ArtCatalog.neonPink, size: CGSize(width: tile * 0.8, height: tile * 0.5))
                    n.position = pos
                    n.zPosition = 5
                    world.addChild(n)
                case .checkpoint:
                    // Compact cyan gem — no tall lime pole (that read as a stray green line).
                    let gem = SKShapeNode(circleOfRadius: tile * 0.22)
                    gem.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.85)
                    gem.strokeColor = .white
                    gem.lineWidth = 0.8
                    gem.glowWidth = 1.5
                    gem.position = CGPoint(x: pos.x, y: pos.y + tile * 0.15)
                    gem.zPosition = 6
                    world.addChild(gem)
                case .stash, .exit:
                    let door = SKShapeNode(rectOf: CGSize(width: tile * 1.2, height: tile * 1.6), cornerRadius: 4)
                    door.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.22, alpha: 0.95)
                    door.strokeColor = ArtCatalog.neonLime
                    door.lineWidth = 2
                    door.glowWidth = kind == .exit ? 3 : 1
                    door.position = pos
                    door.zPosition = 6
                    door.name = kind == .exit ? "exitDoor" : "stashDoor"
                    world.addChild(door)
                    let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
                    t.text = kind == .exit ? "EXIT" : "STASH"
                    t.fontSize = kind == .exit ? 11 : 9
                    t.fontColor = ArtCatalog.neonLime
                    t.verticalAlignmentMode = .center
                    door.addChild(t)
                    if kind == .exit {
                        placeExitBeacon(at: pos, tile: tile)
                    }
                case .oneWay:
                    let plank = SKShapeNode(rectOf: CGSize(width: tile * 0.98, height: tile * 0.18), cornerRadius: 2)
                    plank.fillColor = SKColor(red: 0.18, green: 0.22, blue: 0.32, alpha: 0.95)
                    plank.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.7)
                    plank.lineWidth = 1
                    plank.position = CGPoint(x: pos.x, y: pos.y + tile * 0.32)
                    plank.zPosition = 4.5
                    world.addChild(plank)
                    let bolts = SKSpriteNode(color: ArtCatalog.neonCyan.withAlphaComponent(0.55), size: CGSize(width: tile * 0.9, height: 2))
                    bolts.position = plank.position
                    bolts.zPosition = 4.6
                    world.addChild(bolts)
                case .crewCage:
                    break // live node from crewNodes
                default:
                    break
                }
            }
        }
    }

    // MARK: - UI

    private func setupControls() {
        // Neon stick: dark plate + crisp cyan ring (not a stock translucent blob).
        // Floating stick: dock hint is faint; active stick appears at the finger (left half).
        stickBase = SKShapeNode(circleOfRadius: 54)
        stickBase.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 0.78)
        stickBase.strokeColor = ArtCatalog.neonCyan
        stickBase.lineWidth = 2.5
        stickBase.glowWidth = 1.5
        stickBase.zPosition = 200
        stickBase.alpha = 0.2
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
        stickKnob.alpha = 0.2
        playHUD.addChild(stickKnob)

        jumpBtn = makeFaceButton(title: "JUMP", color: ArtCatalog.neonLime, large: true)
        playHUD.addChild(jumpBtn)
        pounceBtn = makeFaceButton(title: "POUNCE", color: ArtCatalog.neonPink, large: true)
        playHUD.addChild(pounceBtn)
    }

    private func makeFaceButton(title: String, color: SKColor, large: Bool = false) -> SKShapeNode {
        let edge: CGFloat
        let pad: CGFloat
        let font: CGFloat
        if large {
            // ≥88 pt face buttons with generous hit pads (GameFeel.faceButtonMinPt).
            edge = CGFloat(max(88, tuning.feel.faceButtonMinPt))
            pad = CGFloat(tuning.feel.faceButtonHitPad)
            font = title.count > 5 ? 14 : 16
        } else {
            edge = 92
            pad = 0
            font = 13
        }
        let b = SKShapeNode(
            rectOf: CGSize(width: edge + pad, height: (large ? edge * 0.72 : 56) + pad),
            cornerRadius: large ? 18 : 16
        )
        b.fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.82)
        b.strokeColor = color
        b.lineWidth = 2.5
        b.glowWidth = 1.5
        b.zPosition = 200
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = title
        t.fontSize = font
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

    /// Neon HUD font + multi-layer glow outline (readable under Dynamic Island / night sky).
    private func styleHUDLabel(_ label: SKLabelNode, color: SKColor) {
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 18
        label.fontColor = color
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.zPosition = 210
        if label.childNode(withName: "hudOutline") == nil {
            let outline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            outline.name = "hudOutline"
            outline.fontSize = 18
            outline.fontColor = SKColor(red: 0.02, green: 0.01, blue: 0.08, alpha: 0.95)
            outline.horizontalAlignmentMode = .left
            outline.verticalAlignmentMode = .top
            outline.position = CGPoint(x: 1.5, y: -1.5)
            outline.zPosition = -1
            label.addChild(outline)
            // Soft neon halo behind the outline (baked multi-label glow — no SKEffectNode).
            let glow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            glow.name = "hudGlow"
            glow.fontSize = 18
            glow.fontColor = color.withAlphaComponent(0.45)
            glow.horizontalAlignmentMode = .left
            glow.verticalAlignmentMode = .top
            glow.position = CGPoint(x: 0, y: 0)
            glow.zPosition = -2
            glow.setScale(1.04)
            label.addChild(glow)
        }
        if let outline = label.childNode(withName: "hudOutline") as? SKLabelNode {
            outline.text = label.text
            outline.fontSize = label.fontSize
        }
        if let glow = label.childNode(withName: "hudGlow") as? SKLabelNode {
            glow.text = label.text
            glow.fontSize = label.fontSize
            glow.fontColor = color.withAlphaComponent(0.45)
        }
    }

    private func setupTitle() {
        titleRoot.zPosition = 300
        titleRoot.isHidden = true // Revealed after publisher ident (or immediately if skipped).
        overlay.addChild(titleRoot)

        // Dedicated cyberpunk alley — never live level geometry or pickups.
        let alley = SKNode()
        alley.name = "titleAlley"
        alley.zPosition = -20
        titleRoot.addChild(alley)

        let wash = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        wash.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.07, alpha: 1)
        wash.strokeColor = .clear
        wash.name = "titleWash"
        alley.addChild(wash)

        if let far = ArtCatalog.background(.farSkyline, height: 920, maxPixel: 1024) {
            far.name = "titleFar"
            far.alpha = 0.55
            far.zPosition = 0
            alley.addChild(far)
        }
        if let mid = ArtCatalog.background(.midBuildings, height: 780, maxPixel: 1100) {
            mid.name = "titleMid"
            mid.alpha = 0.92
            mid.zPosition = 1
            mid.color = SKColor(red: 1.2, green: 0.75, blue: 1.35, alpha: 1)
            mid.colorBlendFactor = 0.28
            alley.addChild(mid)
            // Wet-floor reflection: flipped mid plate under the horizon.
            let wet = mid.copy() as? SKSpriteNode ?? SKSpriteNode()
            wet.name = "titleWetFloor"
            wet.yScale = -0.42
            wet.alpha = 0.28
            wet.zPosition = 2
            wet.position = CGPoint(x: 0, y: -210)
            alley.addChild(wet)
        }

        // Real storefront crops as title neon (no flat pink/cyan/lime blade plates).
        let titleSigns = ArtCatalog.neonSignageStrip(width: 420, height: 72)
        titleSigns.name = "titleStorefrontSigns"
        titleSigns.position = CGPoint(x: 0, y: 88)
        titleSigns.zPosition = 3
        titleSigns.alpha = 0.95
        alley.addChild(titleSigns)
        let titleSignsLow = ArtCatalog.neonSignageStrip(width: 280, height: 48)
        titleSignsLow.name = "titleStorefrontSignsLow"
        titleSignsLow.position = CGPoint(x: 24, y: 28)
        titleSignsLow.zPosition = 3
        titleSignsLow.alpha = 0.8
        alley.addChild(titleSignsLow)

        let rain = ArtCatalog.rainEmitter(sceneSize: CGSize(width: 480, height: 900))
        rain.name = "titleRain"
        rain.zPosition = 8
        rain.position = CGPoint(x: 0, y: 220)
        alley.addChild(rain)

        // Background MOPs (atmosphere only — not live sim pickups).
        if let mopA = ArtCatalog.makeMopIdleSprite(size: CGSize(width: 54, height: 54)) {
            mopA.name = "titleMopA"
            mopA.alpha = 0.7
            mopA.zPosition = 4
            alley.addChild(mopA)
        }
        if let mopB = ArtCatalog.makeMopIdleSprite(size: CGSize(width: 48, height: 48)) {
            mopB.name = "titleMopB"
            mopB.alpha = 0.55
            mopB.zPosition = 4
            alley.addChild(mopB)
        }

        let glow = SKShapeNode(circleOfRadius: 110)
        glow.name = "titleGlow"
        glow.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.14)
        glow.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.28)
        glow.lineWidth = 2
        glow.glowWidth = 8
        glow.zPosition = 9
        titleRoot.addChild(glow)

        // B1 holo glass logo — hero of the top third (no font title).
        let logo = ArtCatalog.makeLogoNode(lite: false)
        logo.name = "titleLogo"
        logo.zPosition = 12
        logo.alpha = 0
        titleRoot.addChild(logo)
        runTitleLogoIntro(logo)

        let mascot = ArtCatalog.makeBanditFrontMascot(size: CGSize(width: 118, height: 118))
        mascot.name = "titleBandit"
        mascot.zPosition = 11
        titleRoot.addChild(mascot)

        let play = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        play.name = "tapToStart"
        play.text = "TAP TO START"
        play.fontSize = 22
        play.fontColor = .white
        play.zPosition = 14
        titleRoot.addChild(play)
        play.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.35, duration: 0.55),
                SKAction.scale(to: 0.96, duration: 0.55),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: 0.55),
                SKAction.scale(to: 1.06, duration: 0.55),
            ]),
        ])))

        // Tidy bottom bar — MAP · MUTE · DAILY with spacing (no overlaps).
        let bar = SKNode()
        bar.name = "titleBottomBar"
        bar.zPosition = 15
        titleRoot.addChild(bar)
        let mapBtn = RetentionChrome.makeChromeButton(title: "MAP", color: ArtCatalog.neonCyan, name: "titleMap")
        bar.addChild(mapBtn)
        let muteBtn = RetentionChrome.makeChromeButton(
            title: JuiceSound.shared.muted ? "UNMUTE" : "MUTE",
            color: ArtCatalog.neonPink,
            name: "titleMute"
        )
        bar.addChild(muteBtn)
        let dailyBtn = RetentionChrome.makeChromeButton(title: "DAILY", color: ArtCatalog.neonLime, name: "titleDaily")
        bar.addChild(dailyBtn)

        let credit = SKLabelNode(fontNamed: "AvenirNext-Medium")
        credit.name = "titleCredit"
        credit.text = TitleArt.assetCredits
        credit.fontSize = 9
        credit.fontColor = SKColor(white: 1, alpha: 0.45)
        credit.zPosition = 16
        titleRoot.addChild(credit)

        layoutTitleChrome()
    }

    /// Glitch-in (~0.6s) then idle shimmer/hover + occasional slice glitch.
    private func runTitleLogoIntro(_ logo: SKNode) {
        logo.removeAction(forKey: "logoPulse")
        logo.removeAction(forKey: "logoGlitch")
        logo.alpha = 0
        logo.setScale(1.12)
        let intro = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: 0.22),
                SKAction.scaleX(to: 1.2, duration: 0.08),
            ]),
            SKAction.group([
                SKAction.scaleX(to: 0.82, duration: 0.07),
                SKAction.fadeAlpha(to: 0.55, duration: 0.05),
            ]),
            SKAction.group([
                SKAction.scaleX(to: 1.05, duration: 0.1),
                SKAction.fadeAlpha(to: 1, duration: 0.08),
            ]),
            SKAction.scale(to: 1.0, duration: 0.13),
            SKAction.run { [weak self, weak logo] in
                guard let self, let logo else { return }
                self.runTitleLogoIdle(logo)
            },
        ])
        logo.run(intro, withKey: "logoIntro")
    }

    private func runTitleLogoIdle(_ logo: SKNode) {
        let base = (logo.userData?["baseScale"] as? CGFloat) ?? logo.xScale
        logo.removeAction(forKey: "logoPulse")
        logo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 4, duration: 1.35),
                SKAction.fadeAlpha(to: 0.92, duration: 1.35),
                SKAction.scale(to: base * 1.02, duration: 1.35),
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: -4, duration: 1.35),
                SKAction.fadeAlpha(to: 1.0, duration: 1.35),
                SKAction.scale(to: base, duration: 1.35),
            ]),
        ])), withKey: "logoPulse")
        logo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 3.6),
            SKAction.group([
                SKAction.scaleX(to: base * 1.18, duration: 0.04),
                SKAction.fadeAlpha(to: 0.7, duration: 0.04),
            ]),
            SKAction.group([
                SKAction.scaleX(to: base * 0.9, duration: 0.05),
                SKAction.fadeAlpha(to: 1, duration: 0.05),
            ]),
            SKAction.scale(to: base, duration: 0.08),
        ])), withKey: "logoGlitch")
    }

    private func refreshMuteButton() {
        guard let btn = titleRoot.childNode(withName: "//titleMute") else { return }
        let label = btn.children.compactMap { $0 as? SKLabelNode }.first
        label?.text = JuiceSound.shared.muted ? "UNMUTE" : "MUTE"
    }

    private func setupRetention() {
        retentionRoot.zPosition = 340
        retentionRoot.isHidden = true
        retentionRoot.name = "retentionRoot"
        overlay.addChild(retentionRoot)
    }

    private func showDistrictMap() {
        if retentionMode == "map" { return }
        retentionRoot.removeAllChildren()
        retentionRoot.setScale(1)
        retentionRoot.alpha = 1
        retentionRoot.isHidden = false
        let progress = progressStore.load()
        let map = RetentionChrome.makeDistrictMap(size: size, progress: progress)
        retentionRoot.addChild(map)
        RetentionChrome.present(map)
        retentionMode = "map"
        smokeStatus.map = true
        writeSmokeStatus()
    }

    private func showDailyHeist() {
        if retentionMode == "daily" { return }
        // Leaving map → daily: drop the map flag so we don't flip every frame.
        SmokeBrain.setSmokeFlag("smoke_show_map.txt", present: false)
        retentionRoot.removeAllChildren()
        retentionRoot.setScale(1)
        retentionRoot.alpha = 1
        retentionRoot.isHidden = false
        let progress = progressStore.load()
        let day = ProgressStore.dayKey()
        let daily = RetentionChrome.makeDailyHeist(size: size, dayKey: day, progress: progress)
        retentionRoot.addChild(daily)
        RetentionChrome.present(daily)
        retentionMode = "daily"
        smokeStatus.daily = true
        writeSmokeStatus()
    }

    private func hideRetention() {
        retentionRoot.isHidden = true
        retentionRoot.removeAllChildren()
        retentionRoot.setScale(1)
        retentionRoot.alpha = 1
        retentionMode = nil
    }

    /// B1 logo in the top third; raccoon mid; TAP TO START; bottom bar with non-overlapping buttons.
    private func layoutTitleChrome() {
        guard size.width > 1, size.height > 1 else { return }
        let insets = safeInsets()
        let topSafe = max(insets.top, 54) + 10
        let bottomSafe = max(insets.bottom, 22)
        let hh = size.height * 0.5
        guard let logo = titleRoot.childNode(withName: "titleLogo") else { return }
        // Wide B1 lockup — keep under ~78% width so height stays inside the top safe band.
        let base = ArtCatalog.fitTitleLogo(logo, sceneWidth: size.width, fraction: 0.78)
        let safeTop = hh - topSafe
        let safeBottom = -hh + bottomSafe
        let safeH = safeTop - safeBottom
        // Top third: logo hero (nudge down from the safe top so the tall holo art clears the notch).
        var logoY = safeTop - safeH * 0.20
        logo.position = CGPoint(x: 0, y: logoY)
        if logo.action(forKey: "logoIntro") == nil, logo.action(forKey: "logoPulse") == nil {
            runTitleLogoIdle(logo)
        } else if logo.action(forKey: "logoPulse") != nil {
            runTitleLogoIdle(logo)
        }

        if let glow = titleRoot.childNode(withName: "titleGlow") {
            glow.position = logo.position
            glow.setScale(max(0.85, size.width * 0.72 / 220))
        }
        if let alley = titleRoot.childNode(withName: "titleAlley") {
            alley.childNode(withName: "titleFar")?.position = CGPoint(x: 0, y: 40)
            alley.childNode(withName: "titleMid")?.position = CGPoint(x: 0, y: -20)
            alley.childNode(withName: "titleWetFloor")?.position = CGPoint(x: 0, y: -230)
            alley.childNode(withName: "titleMopA")?.position = CGPoint(x: -118, y: -168)
            alley.childNode(withName: "titleMopB")?.position = CGPoint(x: 132, y: -158)
        }
        if let mascot = titleRoot.childNode(withName: "titleBandit") {
            mascot.position = CGPoint(x: 0, y: safeBottom + safeH * 0.38)
        }
        titleRoot.childNode(withName: "tapToStart")?.position = CGPoint(
            x: 0,
            y: safeBottom + safeH * 0.26
        )

        // Bottom bar: chrome buttons are 140pt wide — scale down and space centers by width+gap
        // so MAP / MUTE / DAILY never intersect (CI titleOk gate).
        let barY = safeBottom + 40
        let btnScale: CGFloat = 0.68
        let btnW: CGFloat = 140 * btnScale
        let centerGap: CGFloat = 14
        let spacing = btnW + centerGap
        if let bar = titleRoot.childNode(withName: "titleBottomBar") {
            bar.position = .zero
            for name in ["titleMap", "titleMute", "titleDaily"] {
                bar.childNode(withName: name)?.setScale(btnScale)
            }
            bar.childNode(withName: "titleMap")?.position = CGPoint(x: -spacing, y: barY)
            bar.childNode(withName: "titleMute")?.position = CGPoint(x: 0, y: barY)
            bar.childNode(withName: "titleDaily")?.position = CGPoint(x: spacing, y: barY)
        }
        titleRoot.childNode(withName: "titleCredit")?.position = CGPoint(x: 0, y: safeBottom + 10)

        var ok = ArtCatalog.logoFrameInsideSafeArea(
            logoFrame: logo.calculateAccumulatedFrame(),
            sceneSize: size,
            topSafe: topSafe,
            bottomSafe: bottomSafe
        )
        if !ok {
            _ = ArtCatalog.fitTitleLogo(logo, sceneWidth: size.width, fraction: 0.68)
            logoY -= 28
            logo.position = CGPoint(x: 0, y: logoY)
            runTitleLogoIdle(logo)
            ok = ArtCatalog.logoFrameInsideSafeArea(
                logoFrame: logo.calculateAccumulatedFrame(),
                sceneSize: size,
                topSafe: topSafe,
                bottomSafe: bottomSafe
            )
        }
        if !ok {
            // Last resort: shrink further — title still ships, gate must clear for smoke.
            _ = ArtCatalog.fitTitleLogo(logo, sceneWidth: size.width, fraction: 0.58)
            logo.position = CGPoint(x: 0, y: safeTop - safeH * 0.28)
            runTitleLogoIdle(logo)
            ok = ArtCatalog.logoFrameInsideSafeArea(
                logoFrame: logo.calculateAccumulatedFrame(),
                sceneSize: size,
                topSafe: topSafe,
                bottomSafe: bottomSafe
            )
        }
        var buttonFrames: [CGRect] = []
        for name in ["titleMap", "titleMute", "titleDaily"] {
            if let n = titleRoot.childNode(withName: "//\(name)") {
                // Use the shape path bounds (ignore glow/label inflation) for the overlap gate.
                let f = n.calculateAccumulatedFrame()
                let tight = CGRect(
                    x: n.position.x - btnW * 0.5,
                    y: n.position.y - 20 * btnScale,
                    width: btnW,
                    height: 40 * btnScale
                )
                // Prefer parent-bar local → scene: buttons live under titleBottomBar at .zero.
                buttonFrames.append(tight.isEmpty ? f : tight)
            }
        }
        let noOverlap = ArtCatalog.framesNonOverlapping(buttonFrames, gap: 2)
        smokeStatus.titleOk = ok && noOverlap
        if smokeEnabled { writeSmokeStatus() }
        _ = base
    }

    private func setupPauseMenu() {
        pauseBtn = makeFaceButton(title: "PAUSE", color: ArtCatalog.neonCyan)
        pauseBtn.name = "pauseBtn"
        pauseBtn.zPosition = 212
        playHUD.addChild(pauseBtn)

        pauseRoot.zPosition = 330
        pauseRoot.isHidden = true
        pauseRoot.name = "pauseRoot"
        overlay.addChild(pauseRoot)

        let wash = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        wash.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.62)
        wash.strokeColor = .clear
        wash.name = "pauseWash"
        pauseRoot.addChild(wash)

        // Tall enough for RESUME / RESTART / volume rows / MUTE / HOME + credit note + padding.
        let card = SKShapeNode(rectOf: CGSize(width: 300, height: 520), cornerRadius: 14)
        card.fillColor = SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 0.96)
        card.strokeColor = ArtCatalog.neonCyan
        card.lineWidth = 2.5
        card.glowWidth = 2
        card.name = "pauseCard"
        pauseRoot.addChild(card)

        let compact = ArtCatalog.makeCompactLogoNode(maxWidth: 148)
        compact.name = "pauseLogo"
        compact.position = CGPoint(x: 0, y: 198)
        card.addChild(compact)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.name = "pauseTitle"
        title.text = "PAUSED"
        title.fontSize = 18
        title.fontColor = ArtCatalog.neonCyan
        title.position = CGPoint(x: 0, y: 158)
        card.addChild(title)

        let resume = makeOutcomeButton(title: "RESUME", color: ArtCatalog.neonLime, name: "pauseResume", wide: true)
        resume.position = CGPoint(x: 0, y: 128)
        card.addChild(resume)
        let restart = makeOutcomeButton(title: "RESTART", color: ArtCatalog.neonOrange, name: "pauseRestart", wide: true)
        restart.position = CGPoint(x: 0, y: 72)
        card.addChild(restart)

        // Music / SFX volume sliders
        card.addChild(makePauseVolumeRow(
            label: "MUSIC",
            namePrefix: "pauseMusic",
            y: 18,
            value: JuiceSound.shared.musicVolume
        ))
        card.addChild(makePauseVolumeRow(
            label: "SFX",
            namePrefix: "pauseSfx",
            y: -22,
            value: JuiceSound.shared.sfxVolume
        ))

        let mute = makeOutcomeButton(
            title: JuiceSound.shared.muted ? "UNMUTE" : "MUTE",
            color: ArtCatalog.neonPink,
            name: "pauseMute",
            wide: true
        )
        mute.position = CGPoint(x: 0, y: -78)
        card.addChild(mute)
        let storyBtn = makeOutcomeButton(title: "STORY", color: ArtCatalog.neonCyan, name: "pauseStory", wide: true)
        storyBtn.position = CGPoint(x: 0, y: -134)
        card.addChild(storyBtn)
        let home = makeOutcomeButton(title: "HOME", color: ArtCatalog.neonPink, name: "pauseHome", wide: true)
        home.position = CGPoint(x: 0, y: -190)
        card.addChild(home)

        let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
        note.name = "pauseVolumeNote"
        note.text = JuiceSound.shared.muted ? "Audio muted" : TitleArt.assetCredits
        note.fontSize = 10
        note.fontColor = SKColor(white: 1, alpha: 0.55)
        note.position = CGPoint(x: 0, y: -236)
        card.addChild(note)

        let count = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        count.name = "pauseCountdown"
        count.fontSize = 48
        count.fontColor = .white
        count.alpha = 0
        count.zPosition = 5
        count.verticalAlignmentMode = .center
        pauseRoot.addChild(count)
        pauseCountLabel = count
    }

    private func makePauseVolumeRow(label: String, namePrefix: String, y: CGFloat, value: Float) -> SKNode {
        let row = SKNode()
        row.name = "\(namePrefix)Row"
        row.position = CGPoint(x: 0, y: y)

        let lab = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lab.text = label
        lab.fontSize = 11
        lab.fontColor = ArtCatalog.neonCyan
        lab.horizontalAlignmentMode = .left
        lab.verticalAlignmentMode = .center
        lab.position = CGPoint(x: -118, y: 0)
        lab.name = "\(namePrefix)Label"
        row.addChild(lab)

        let track = SKShapeNode(rectOf: CGSize(width: 110, height: 6), cornerRadius: 3)
        track.fillColor = SKColor(white: 0.2, alpha: 0.9)
        track.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.4)
        track.lineWidth = 1
        track.position = CGPoint(x: 10, y: 0)
        track.name = "\(namePrefix)Track"
        row.addChild(track)

        let fillW = CGFloat(max(0.05, min(1, value))) * 110
        let fill = SKShapeNode(rectOf: CGSize(width: fillW, height: 6), cornerRadius: 3)
        fill.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.85)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 10 - (110 - fillW) * 0.5, y: 0)
        fill.name = "\(namePrefix)Fill"
        row.addChild(fill)

        let minus = makeFaceButton(title: "−", color: ArtCatalog.neonPink)
        minus.name = "\(namePrefix)Minus"
        minus.childNode(withName: "btnLabel")?.name = "\(namePrefix)Minus"
        minus.setScale(0.55)
        minus.position = CGPoint(x: -52, y: 0)
        row.addChild(minus)

        let plus = makeFaceButton(title: "+", color: ArtCatalog.neonLime)
        plus.name = "\(namePrefix)Plus"
        plus.childNode(withName: "btnLabel")?.name = "\(namePrefix)Plus"
        plus.setScale(0.55)
        plus.position = CGPoint(x: 78, y: 0)
        row.addChild(plus)

        return row
    }

    private func refreshPauseVolumeRows() {
        guard let card = pauseRoot.childNode(withName: "pauseCard") else { return }
        for (prefix, value) in [("pauseMusic", JuiceSound.shared.musicVolume), ("pauseSfx", JuiceSound.shared.sfxVolume)] {
            guard let row = card.childNode(withName: "\(prefix)Row"),
                  let fill = row.childNode(withName: "\(prefix)Fill") as? SKShapeNode else { continue }
            let fillW = CGFloat(max(0.05, min(1, value))) * 110
            fill.path = CGPath(roundedRect: CGRect(x: -fillW * 0.5, y: -3, width: fillW, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
            fill.position = CGPoint(x: 10 - (110 - fillW) * 0.5, y: 0)
        }
    }

    private func refreshPauseMuteButton() {
        guard let card = pauseRoot.childNode(withName: "pauseCard") else { return }
        if let mute = card.childNode(withName: "pauseMute"),
           let label = mute.children.compactMap({ $0 as? SKLabelNode }).first {
            label.text = JuiceSound.shared.muted ? "UNMUTE" : "MUTE"
        }
        if let note = card.childNode(withName: "pauseVolumeNote") as? SKLabelNode {
            note.text = JuiceSound.shared.muted ? "Audio muted" : TitleArt.assetCredits
        }
        refreshPauseVolumeRows()
    }

    private func setPaused(_ on: Bool, system: Bool = false) {
        let playing: Bool = {
            if case .playing = sim.state.phase { return true }
            return false
        }()
        guard playing || runPaused else { return }
        // Manual pause button is ignored under smoke; harness flags drive pause beats instead.
        if on {
            if runPaused { return }
            runPaused = true
            pauseFromSystem = system
            resumeCountdown = 0
            skipFreezeSample = true
            pauseCountLabel?.alpha = 0
            pauseCountLabel?.text = ""
            moveX = 0
            jumpHeld = false
            jumpPressed = false
            pouncePressed = false
            stickTouch = nil
            jumpTouch = nil
            pauseRoot.isHidden = false
            layoutUI()
            if smokeEnabled { writeSmokeStatus() }
        } else {
            runPaused = false
            pauseFromSystem = false
            skipFreezeSample = true
            pauseRoot.isHidden = true
            layoutUI()
            if smokeEnabled { writeSmokeStatus() }
        }
    }

    /// Auto-pause from SwiftUI / UIKit lifecycle (resign active, background).
    public func pauseFromAppLifecycle() {
        setPaused(true, system: true)
    }

    /// Resume after lifecycle pause: brief 3-2-1, else immediate unpause.
    private func beginResumeFromPause() {
        guard runPaused else { return }
        JuiceSound.shared.playUITap()
        runPaused = false
        skipFreezeSample = true
        pauseRoot.isHidden = true
        if pauseFromSystem {
            pauseFromSystem = false
            resumeCountdown = 3.0
            pauseCountLabel?.text = "3"
            pauseCountLabel?.alpha = 1
            pauseCountLabel?.setScale(1.2)
            layoutUI()
        } else {
            layoutUI()
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

        let card = SKShapeNode(rectOf: CGSize(width: 292, height: 340), cornerRadius: 14)
        card.fillColor = SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 0.96)
        card.strokeColor = ArtCatalog.neonCyan
        card.lineWidth = 2.5
        card.glowWidth = 2
        card.name = "outcomeCard"
        outcomeRoot.addChild(card)

        let compact = ArtCatalog.makeCompactLogoNode(maxWidth: 140)
        compact.name = "outcomeLogo"
        compact.position = CGPoint(x: 0, y: 128)
        card.addChild(compact)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.name = "outcomeTitle"
        title.fontSize = 24
        title.fontColor = ArtCatalog.neonLime
        title.position = CGPoint(x: 0, y: 88)
        card.addChild(title)

        let stars = SKNode()
        stars.name = "outcomeStars"
        stars.position = CGPoint(x: 0, y: 52)
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
        shinyRow.position = CGPoint(x: 0, y: 14)
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
        meta.position = CGPoint(x: 0, y: -8)
        card.addChild(meta)

        let pa = SKLabelNode(fontNamed: "AvenirNext-Medium")
        pa.name = "outcomePA"
        pa.fontSize = 11
        pa.fontColor = ArtCatalog.neonPink
        pa.preferredMaxLayoutWidth = 240
        pa.numberOfLines = 2
        pa.verticalAlignmentMode = .top
        pa.horizontalAlignmentMode = .center
        // Two lines of OmniClean PA flavor fully above NEXT/RETRY (was overlapping).
        pa.position = CGPoint(x: 0, y: -18)
        pa.isHidden = true
        card.addChild(pa)

        // Keep legacy name for count-up path compatibility.
        let stats = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        stats.name = "outcomeStats"
        stats.isHidden = true
        card.addChild(stats)

        let primary = makeOutcomeButton(title: "RETRY", color: ArtCatalog.neonLime, name: "retryBtn", wide: true)
        primary.position = CGPoint(x: 0, y: -78)
        card.addChild(primary)
        let next = makeOutcomeButton(title: "NEXT", color: ArtCatalog.neonLime, name: "nextBtn", wide: true)
        next.position = CGPoint(x: 0, y: -78)
        next.isHidden = true
        card.addChild(next)
        let home = makeOutcomeButton(title: "HOME", color: ArtCatalog.neonPink, name: "homeBtn", wide: false)
        home.position = CGPoint(x: 0, y: -138)
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
        let insets = safeInsets()
        // Extra pad under the island — topSafe alone still clips on Pro Max sims.
        let topSafe = max(insets.top, 59) + 22
        let bottomSafe = max(insets.bottom, 20)
        let leftSafe = max(insets.left, 0)
        // Full-bleed sky — oversized so no black letterbox on any iPhone aspect.
        skyFill.size = CGSize(width: size.width * 3.2, height: size.height * 3.2)
        skyFill.position = .zero
        skyFill.color = ArtCatalog.nightSky
        skyFill.colorBlendFactor = 1

        let rightSafe = max(insets.right, 0)
        // Dock / rest position stays inside safe area (same look in smoke + ship).
        if stickTouch == nil {
            stickBase.position = CGPoint(x: -hw + 72 + leftSafe, y: -hh + 96 + bottomSafe * 0.4)
            stickKnob.position = stickBase.position
            stickBase.alpha = 0.22
            stickKnob.alpha = 0.22
        }
        // Separated ≥88pt face buttons — right half, inside safe area.
        let btnX = hw - 70 - rightSafe
        jumpBtn.position = CGPoint(x: btnX, y: -hh + 148 + bottomSafe * 0.35)
        pounceBtn.position = CGPoint(x: btnX, y: -hh + 58 + bottomSafe * 0.35)
        let hudTop = hh - topSafe - 6
        let hudX = -hw + 16 + leftSafe
        hudCarried.position = CGPoint(x: hudX, y: hudTop)
        hudHearts.position = CGPoint(x: hudX, y: hudTop - 26)
        hudCombo.position = CGPoint(x: hudX, y: hudTop - 52)
        hudTime.position = CGPoint(x: hudX, y: hudTop - 78)
        for label in [hudCarried, hudHearts, hudCombo, hudTime] {
            if let outline = label.childNode(withName: "hudOutline") as? SKLabelNode {
                outline.text = label.text
            }
            if let glow = label.childNode(withName: "hudGlow") as? SKLabelNode {
                glow.text = label.text
            }
        }
        if let pauseBtn {
            pauseBtn.position = CGPoint(x: hw - 52 - rightSafe, y: hudTop - 4)
            let pl = pauseBtn.childNode(withName: "btnLabel") as? SKLabelNode
            pl?.fontSize = 11
        }
        #if DEBUG
        fpsLabel.position = CGPoint(x: -hw + 16, y: -hh + 16 + bottomSafe * 0.25)
        debugToggle?.position = CGPoint(x: hw - 40, y: hudTop)
        tuningMenu?.position = .zero
        #endif

        if let edge = maskVignette.childNode(withName: "vignetteEdge") as? SKSpriteNode {
            // Oversized dark plate — corners read heavier; center stays the night playfield.
            edge.size = CGSize(width: size.width * 1.2, height: size.height * 1.2)
            edge.position = .zero
            edge.alpha = 0.22
        }
        if !titleRoot.isHidden {
            layoutTitleChrome()
        }
        if showingPublisherIdent {
            layoutPublisherIdentBackground()
        }
        updateHUDVisibility()
    }

    private func updateHUDVisibility() {
        let playing: Bool = {
            if case .playing = sim.state.phase { return true }
            return false
        }()
        let onTitle = !titleRoot.isHidden || showingPublisherIdent
        // Title owns the screen — hide live level so geometry/shinies can't peek under UI.
        stage.isHidden = onTitle
        skyFill.isHidden = onTitle
        let showPlayHUD = playing && resumeCountdown <= 0 && !onTitle
        playHUD.isHidden = !showPlayHUD
        pauseBtn?.isHidden = !showPlayHUD
        if !showPlayHUD || runPaused {
            stickKnob.position = stickBase.position
            moveX = 0
        }
        if runPaused {
            for node in [stickBase, stickKnob, jumpBtn, pounceBtn, pauseBtn] as [SKNode?] {
                node?.alpha = 0
            }
        } else if playing, resumeCountdown <= 0 {
            let stickA: CGFloat = stickTouch == nil ? 0.22 : 1
            stickBase?.alpha = stickA
            stickKnob?.alpha = stickA
            jumpBtn?.alpha = 1
            pounceBtn?.alpha = 1
            pauseBtn?.alpha = 1
        }
    }

    private func cg(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }


    private func setupStoryOverlays() {
        introRoot.zPosition = 360
        introRoot.isHidden = true
        introRoot.name = "introRoot"
        overlay.addChild(introRoot)
        districtCardRoot.zPosition = 350
        districtCardRoot.isHidden = true
        districtCardRoot.name = "districtCardRoot"
        overlay.addChild(districtCardRoot)

        // Comic intro is presented after the publisher ident (see finishPublisherIdentAndShowTitle).
    }

    private func presentIntroIfNeededAfterIdent() {
        if !smokeEnabled, !progressStore.load().sawIntro {
            presentIntro(fromScratch: true)
        }
    }

    private func makeCrewCageNode(crewID: String) -> SKNode {
        let root = SKNode()
        root.name = "crewCage_\(crewID)"
        let tile = CGFloat(tuning.tileSize)
        let bars = SKShapeNode(rectOf: CGSize(width: tile * 0.95, height: tile * 1.2), cornerRadius: 4)
        bars.fillColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 0.85)
        bars.strokeColor = ArtCatalog.neonOrange
        bars.lineWidth = 2
        root.addChild(bars)
        let mascot = ArtCatalog.makeBanditFrontMascot(size: CGSize(width: tile * 0.7, height: tile * 0.7))
        mascot.setScale(0.7)
        mascot.position = CGPoint(x: 0, y: -4)
        root.addChild(mascot)
        let tag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tag.text = story.crew(id: crewID)?.name ?? "CREW"
        tag.fontSize = 8
        tag.fontColor = ArtCatalog.neonLime
        tag.position = CGPoint(x: 0, y: tile * 0.55)
        root.addChild(tag)
        return root
    }

    private func presentIntro(fromScratch: Bool) {
        if fromScratch { introPanelIndex = 0 }
        showingIntro = true
        introRoot.removeAllChildren()
        introRoot.isHidden = false
        titleRoot.isHidden = true
        let comic = StoryChrome.makeIntroComic(size: size, story: story, panelIndex: introPanelIndex)
        introRoot.addChild(comic)
        if smokeEnabled {
            smokeStatus.phase = "intro"
            smokeStatus.write()
        }
    }

    private func advanceIntro() {
        introPanelIndex += 1
        if introPanelIndex >= story.introPanels.count {
            dismissIntro()
            return
        }
        presentIntro(fromScratch: false)
    }

    private func dismissIntro() {
        showingIntro = false
        introRoot.isHidden = true
        introRoot.removeAllChildren()
        progressStore.markIntroSeen()
        showTitleScreen()
        if smokeEnabled {
            smokeStatus.phase = "title"
            smokeStatus.boot = "ready"
            smokeStatus.write()
        }
    }

    private func presentDistrictCardThenPlay() {
        showingDistrictCard = true
        titleRoot.isHidden = true
        districtCardRoot.removeAllChildren()
        districtCardRoot.isHidden = false
        let card = StoryChrome.makeDistrictCard(size: size, district: pendingDistrict, story: story)
        districtCardRoot.addChild(card)
        // Auto-advance after a short beat so smoke / impatient taps still flow.
        districtCardRoot.removeAction(forKey: "districtAuto")
        districtCardRoot.run(SKAction.sequence([
            SKAction.wait(forDuration: smokeEnabled ? 0.35 : 1.4),
            SKAction.run { [weak self] in self?.finishDistrictCardAndPlay() },
        ]), withKey: "districtAuto")
    }

    private func finishDistrictCardAndPlay() {
        guard showingDistrictCard else { return }
        showingDistrictCard = false
        districtCardRoot.removeAction(forKey: "districtAuto")
        districtCardRoot.isHidden = true
        districtCardRoot.removeAllChildren()
        beginPlay()
    }

    private func reloadDistrictMap(_ id: DistrictID) {
        do {
            let map = try DistrictLevels.load(id)
            sim = Sim(map: map, tuning: tuning, seed: smokeEnabled ? 7 : 11)
            // Soft reload: respawn pickups/enemies/crew for the new district layout.
            shinyNodes.values.forEach { $0.removeFromParent() }
            shinyNodes.removeAll()
            mopNodes.values.forEach { $0.removeFromParent() }
            mopNodes.removeAll()
            crewNodes.values.forEach { $0.removeFromParent() }
            crewNodes.removeAll()
            for s in sim.state.shinies.prefix(smokeEnabled ? sim.state.shinies.count : min(sim.state.shinies.count, 40)) {
                let n = ArtCatalog.makeShinyNode()
                n.position = cg(s.position)
                n.zPosition = 20
                world.addChild(n)
                shinyNodes[s.id] = n
            }
            for m in sim.state.mops.prefix(smokeEnabled ? sim.state.mops.count : min(sim.state.mops.count, 24)) {
                let n = ArtCatalog.makeMopNode()
                n.position = cg(m.position)
                n.zPosition = 30
                world.addChild(n)
                mopNodes[m.id] = n
            }
            for c in sim.state.crewCages {
                let n = makeCrewCageNode(crewID: c.crewID)
                n.position = cg(c.position)
                n.zPosition = 28
                world.addChild(n)
                crewNodes[c.id] = n
            }
        } catch {
            // Keep current map on load failure.
        }
    }

    private func requestBeginPlay() {
        // Smoke skips the district card so title→play timing stays in the freeze budget.
        if smokeEnabled {
            beginPlay()
            return
        }
        presentDistrictCardThenPlay()
    }

    private func showTitleScreen() {
        titleRoot.isHidden = false
        if let rain = titleRoot.childNode(withName: "//titleRain") as? SKEmitterNode {
            rain.isPaused = false
            rain.particleBirthRate = 22
        }
        layoutTitleChrome()
    }

    private func beginPlay() {
        // Start audio here (not in didMove) so smoke video has a soundtrack without launch jetsam.
        // simctl recordVideo has no app-audio track — smoke also writes smoke_audio_events.txt for mux.
        if smokeEnabled {
            JuiceSound.shared.beginSmokeAudioLog()
            if smokeWallStart == 0 {
                smokeWallStart = CACurrentMediaTime()
                try? FileManager.default.removeItem(at: SmokeStatus.timerLogURL)
            }
        }
        JuiceSound.shared.prepare()
        JuiceSound.shared.playUITap()
        // Gameplay bed: main_theme with alt rotation. District beds via startLevelMusic(district:).
        JuiceSound.shared.startLevelMusic()
        mopAlerted.removeAll()
        celebratedFirstStomp = false
        celebratedEarlyWin = false
        midSurpriseFired = false
        if !smokeEnabled { hapticMed.impactOccurred() }
        sim.startRun()
        // Keep the freeze sample — allow one ≤250ms title→play transition frame (preload should
        // keep real devices under that; simctl recordVideo may still brush the budget).
        transitionBudgetMs = titlePlayTransitionBudgetMs
        titleRoot.isHidden = true
        // Stop title rain so hidden emitters do not keep burning GPU during play.
        if let rain = titleRoot.childNode(withName: "//titleRain") as? SKEmitterNode {
            rain.isPaused = true
            rain.particleBirthRate = 0
        }
        layoutUI()
        snapCameraToHero()
        resetHeroFramingSamples()
        showObjectiveBanner()
        writeSmokeStatus()
    }

    private func doRetry() {
        failOutcomeHold = 0
        resumeCountdown = 0
        setPaused(false)
        JuiceSound.shared.prepare()
        JuiceSound.shared.playUITap()
        JuiceSound.shared.startLevelMusic()
        mopAlerted.removeAll()
        sim.retry()
        hideOutcome()
        snapCameraToHero()
        // Keep pre-death heroX min/max for the CI framing gate — finishPush sprints
        // to EXIT and must not wipe (or re-sample) the live-play band.
        if !smoke.diedOnce {
            resetHeroFramingSamples()
        }
        updateHUDVisibility()
    }

    /// Instantly park the camera on the hero so the first frames aren't focus=(0,0) → negative heroX.
    private func snapCameraToHero() {
        cameraFacing = sim.state.bandit.facing >= 0 ? 1 : -1
        cameraFocus = cameraTarget(for: sim.state.bandit)
        let z = Self.worldZoom
        stage.position = CGPoint(x: -cameraFocus.x * z, y: -cameraFocus.y * z)
    }

    private func resetHeroFramingSamples() {
        smokeStatus.heroX = 0.5
        smokeStatus.heroXMin = 1
        smokeStatus.heroXMax = 0
    }

    /// Same look-ahead + soft clamp as the live camera update (single 0.20×viewW lead).
    private func cameraTarget(for b: BanditState) -> CGPoint {
        let mapW = CGFloat(sim.map.width) * CGFloat(tuning.tileSize)
        let mapH = CGFloat(sim.map.height) * CGFloat(tuning.tileSize)
        let viewW = size.width / Self.worldZoom
        let viewH = size.height / Self.worldZoom
        // 0.20×viewW → hero ~30% when facing right (20–45% framing band).
        let lead = cameraFacing * 0.20 * viewW
        var target = CGPoint(
            x: CGFloat(b.position.x) + lead,
            y: CGFloat(b.position.y) + 56
        )
        let minX = viewW * 0.18
        let maxX = max(minX, mapW - viewW * 0.18)
        let minY = viewH * 0.38
        let maxY = max(minY, mapH - viewH * 0.25)
        target.x = min(max(target.x, minX), maxX)
        target.y = min(max(target.y, minY), maxY)
        return target
    }

    /// Undo a post-Mask splash/bag that landed before pause/bg finished — keeps harness order intact.
    private func softReviveSmokeHarness() {
        sim.state.phase = .playing
        if sim.state.bandit.hearts <= 0 {
            sim.state.bandit.hearts = max(1, tuning.hearts)
        }
        sim.state.bandit.anim = .idle
        sim.state.bandit.animHold = 0
        sim.state.bandit.invuln = 2.0
        sim.state.bandit.velocity = .zero
        // Nudge up out of water/spikes if the fail reason was a hazard tile.
        let tile = tuning.tileSize
        let tx = Int(floor(sim.state.bandit.position.x / tile))
        let ty = Int(floor((sim.state.bandit.position.y - 12) / tile))
        let t = sim.map.tile(atX: tx, y: ty)
        if t == .water || t == .spike {
            sim.state.bandit.position.y += tile * 2.5
        }
        failOutcomeHold = 0
        hideOutcome()
        // Cancelled deaths must not sticky-set diedOnce → finishPush → phase=won before 05.
        smoke.diedOnce = false
        smoke.failWait = 0
        if smoke.act != .showcaseMask && smoke.act != .seekDeath {
            smoke.act = .showcaseMask
        }
        snapCameraToHero()
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
            if !retentionRoot.isHidden {
                let hitNames = Set(nodes(at: touch.location(in: self)).compactMap(\.name))
                if hitNames.contains("mapBack") || hitNames.contains("dailyBack") {
                    JuiceSound.shared.playUIBack()
                    hideRetention()
                    return
                }
                if hitNames.contains("dailyPlay") {
                    JuiceSound.shared.playUITap()
                    hideRetention()
                    progressStore.recordDailyClear(dayKey: ProgressStore.dayKey())
                    requestBeginPlay()
                    return
                }
                for d in DistrictID.allCases {
                    if hitNames.contains("district_\(d.rawValue)") {
                        JuiceSound.shared.playUITap()
                        hideRetention()
                        pendingDistrict = d
                        reloadDistrictMap(d)
                        requestBeginPlay()
                        return
                    }
                }
                if hitNames.contains("districtLabel") {
                    JuiceSound.shared.playUITap()
                    hideRetention()
                    requestBeginPlay()
                    return
                }
                return
            }
            if showingIntro {
                let hitNames = Set(nodes(at: touch.location(in: self)).compactMap(\.name))
                if hitNames.contains("introSkip") {
                    JuiceSound.shared.playUITap()
                    dismissIntro()
                    return
                }
                JuiceSound.shared.playUITap()
                advanceIntro()
                return
            }
            if showingDistrictCard {
                JuiceSound.shared.playUITap()
                finishDistrictCardAndPlay()
                return
            }
            if showingPublisherIdent {
                skipPublisherIdentIfNeeded()
                return
            }
            if case .title = sim.state.phase {
                let hitNames = Set(nodes(at: touch.location(in: self)).compactMap(\.name))
                if hitNames.contains("titleMute") {
                    JuiceSound.shared.toggleMute()
                    refreshMuteButton()
                    if !JuiceSound.shared.muted {
                        JuiceSound.shared.playUITap()
                    }
                    return
                }
                if hitNames.contains("titleMap") {
                    JuiceSound.shared.playUITap()
                    showDistrictMap()
                    return
                }
                if hitNames.contains("titleDaily") {
                    JuiceSound.shared.playUITap()
                    showDailyHeist()
                    return
                }
                requestBeginPlay()
                return
            }
            if !pauseRoot.isHidden, let card = pauseRoot.childNode(withName: "pauseCard") {
                let pCard = touch.location(in: card)
                let hitNames = Set(nodes(at: touch.location(in: self)).compactMap(\.name))
                if hitNames.contains("pauseResume") {
                    beginResumeFromPause()
                    return
                }
                if hitNames.contains("pauseRestart") {
                    JuiceSound.shared.playUITap()
                    setPaused(false)
                    doRetry()
                    return
                }
                if hitNames.contains("pauseMusicMinus") {
                    JuiceSound.shared.musicVolume = max(0, JuiceSound.shared.musicVolume - 0.1)
                    refreshPauseVolumeRows()
                    JuiceSound.shared.playUITap()
                    return
                }
                if hitNames.contains("pauseMusicPlus") {
                    JuiceSound.shared.musicVolume = min(1, JuiceSound.shared.musicVolume + 0.1)
                    refreshPauseVolumeRows()
                    JuiceSound.shared.playUITap()
                    return
                }
                if hitNames.contains("pauseSfxMinus") {
                    JuiceSound.shared.sfxVolume = max(0, JuiceSound.shared.sfxVolume - 0.1)
                    refreshPauseVolumeRows()
                    JuiceSound.shared.playUITap()
                    return
                }
                if hitNames.contains("pauseSfxPlus") {
                    JuiceSound.shared.sfxVolume = min(1, JuiceSound.shared.sfxVolume + 0.1)
                    refreshPauseVolumeRows()
                    JuiceSound.shared.playUITap()
                    return
                }
                if hitNames.contains("pauseMute") {
                    JuiceSound.shared.toggleMute()
                    refreshPauseMuteButton()
                    if !JuiceSound.shared.muted { JuiceSound.shared.playUITap() }
                    return
                }
                if hitNames.contains("pauseStory") {
                    JuiceSound.shared.playUITap()
                    setPaused(false)
                    pauseRoot.isHidden = true
                    presentIntro(fromScratch: true)
                    return
                }
                if hitNames.contains("pauseHome") {
                    setPaused(false)
                    hideOutcome()
                    JuiceSound.shared.stopMusic()
                    JuiceSound.shared.playUIBack()
                    JuiceSound.shared.playTitleSting()
                    sim = Sim(map: sim.map, tuning: tuning, seed: smokeEnabled ? 7 : 11)
                    showTitleScreen()
                    writeSmokeStatus()
                    updateHUDVisibility()
                    return
                }
                if card.contains(pCard) { return }
            }
            if case .playing = sim.state.phase, resumeCountdown <= 0, !runPaused {
                let pHud = touch.location(in: hud)
                if pauseBtn?.contains(pHud) == true {
                    JuiceSound.shared.playUITap()
                    setPaused(true)
                    return
                }
            }
            if runPaused || resumeCountdown > 0 { return }
            if !outcomeRoot.isHidden, let card = outcomeRoot.childNode(withName: "outcomeCard") {
                let pCard = touch.location(in: card)
                if let home = card.childNode(withName: "homeBtn"), home.contains(pCard) {
                    hideOutcome()
                    JuiceSound.shared.stopMusic()
                    JuiceSound.shared.playUIBack()
                    JuiceSound.shared.playTitleSting()
                    sim = Sim(map: sim.map, tuning: tuning, seed: smokeEnabled ? 7 : 11)
                    showTitleScreen()
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
            // Left half: stick appears at the finger (placement-insensitive).
            if p.x < 0 {
                stickTouch = touch
                stickOrigin = p
                stickBase.position = p
                stickKnob.position = p
                stickBase.alpha = 1
                stickKnob.alpha = 1
                updateStick(p)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if smokeEnabled || runPaused || resumeCountdown > 0 { return }
        for touch in touches where touch === stickTouch {
            updateStick(touch.location(in: hud))
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if smokeEnabled || runPaused || resumeCountdown > 0 { return }
        for touch in touches {
            if touch === stickTouch {
                stickTouch = nil
                moveX = 0
                moveY = 0
                stickKnob.position = stickBase.position
                stickBase.alpha = 0.22
                stickKnob.alpha = 0.22
                layoutUI()
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
        let maxR = CGFloat(tuning.feel.stickMaxRadius)
        let dead = tuning.feel.stickDeadZone
        var dx = delta.x, dy = delta.y
        let len = hypot(dx, dy)
        if len > maxR {
            dx = dx / len * maxR
            dy = dy / len * maxR
        }
        stickKnob.position = CGPoint(x: stickOrigin.x + dx, y: stickOrigin.y + dy)
        // Radial dead zone + analog ramp on X/Y (down holds drop-through on one-ways).
        let nx = Double(dx / maxR)
        let ny = Double(dy / maxR)
        let ax = abs(nx)
        if ax <= dead {
            moveX = 0
        } else {
            let remapped = (ax - dead) / max(0.05, 1 - dead)
            moveX = (nx < 0 ? -1 : 1) * min(1, remapped)
        }
        let ay = abs(ny)
        if ay <= dead {
            moveY = 0
        } else {
            let remapped = (ay - dead) / max(0.05, 1 - dead)
            moveY = (ny < 0 ? -1 : 1) * min(1, remapped)
        }
        if dy > maxR * 0.72 && !jumpHeld {
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
        if maskMusicOn {
            maskMusicOn = false
            JuiceSound.shared.setMaskModeMusic(false)
        }
        maskVignette.removeAllActions()
        maskVignette.alpha = 0
        maskVignette.isHidden = true
        layoutUI()
    }

    // MARK: - Update

    public override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let rawDt = max(0, currentTime - lastTime)
        lastTime = currentTime
        // Freeze gate: sample live gameplay. Ignore pause/resume gaps + death-hold.
        // Skip the same startup window as the FPS average (first 2s) — title→play / audio
        // prep hitch must not fail the mid-run freeze gate. One transition budget remains
        // as a belt-and-suspenders for the first counted frame after that window.
        let livePlay: Bool = {
            if case .playing = sim.state.phase {
                return !runPaused && resumeCountdown <= 0 && failOutcomeHold <= 0
            }
            return false
        }()
        if skipFreezeSample {
            skipFreezeSample = false
        } else if livePlay, sim.state.elapsed > 2 || !smokeEnabled {
            let ms = rawDt * 1000
            if transitionBudgetMs > 0 {
                // Absorb one post-startup transition frame of any size.
                transitionBudgetMs = 0
            } else {
                maxFrameMs = max(maxFrameMs, ms)
            }
        }
        var dt = rawDt
        if dt > 0.1 { dt = 0.1 }

        let instFPS = 1 / max(dt, 0.0001)
        // Average FPS = frameCount / elapsedTime (not mean of 1/dt).
        // Skip the first 2s (startup hitch) when averaging for the smoke gate.
        if sim.state.elapsed > 2 || !smokeEnabled {
            fpsTimeSum += rawDt
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
            // Write often so screenshot-moment status matches what the still shows.
            let interval: TimeInterval = {
                if case .title = sim.state.phase { return 0.05 }
                if showingPublisherIdent { return 0.05 }
                return 0.08
            }()
            if statusAcc >= interval {
                statusAcc = 0
                writeSmokeStatus()
            }
            // Pause / background beats (harness-driven during live play).
            if case .playing = sim.state.phase {
                let wantPause = SmokeBrain.smokeFlagExists("smoke_show_pause.txt")
                    && !SmokeBrain.smokeFlagExists("smoke_pause_ok.txt")
                let wantBg = SmokeBrain.smokeFlagExists("smoke_background.txt")
                    && !SmokeBrain.smokeFlagExists("smoke_foreground.txt")
                if wantBg {
                    if !runPaused || !pauseFromSystem {
                        setPaused(true, system: true)
                    }
                } else if wantPause {
                    if !runPaused {
                        setPaused(true, system: false)
                    }
                } else if runPaused {
                    // Harness cleared the hold — resume (with countdown after system pause).
                    beginResumeFromPause()
                }
            }
            // Retention screens after RESULTS (harness-driven).
            // Prefer Daily when both flags exist — never flip map↔daily every frame.
            if case .won = sim.state.phase {
                if SmokeBrain.smokeFlagExists("smoke_show_daily.txt") {
                    if retentionMode != "daily" {
                        hideOutcome()
                        titleRoot.isHidden = true
                        showDailyHeist()
                    }
                } else if SmokeBrain.smokeFlagExists("smoke_show_map.txt"), retentionMode != "map" {
                    hideOutcome()
                    titleRoot.isHidden = true
                    showDistrictMap()
                }
            }
        }

        // Safety net: if a post-Mask fail stuck us before pause/bg finished, revive in place.
        if smokeEnabled,
           smoke.sawMask,
           !SmokeBrain.smokeFlagExists("smoke_foreground.txt"),
           case .failed = sim.state.phase
        {
            softReviveSmokeHarness()
            smokeSoftReviveCount += 1
        }

        if failOutcomeHold > 0 {
            failOutcomeHold = max(0, failOutcomeHold - dt)
            sync(dt: CGFloat(dt))
            updateHUDVisibility()
            if failOutcomeHold <= 0 {
                showOutcome()
            }
            return
        }

        if resumeCountdown > 0 {
            resumeCountdown = max(0, resumeCountdown - dt)
            let tick = Int(ceil(resumeCountdown))
            if tick > 0, let count = pauseCountLabel {
                count.text = "\(tick)"
                count.alpha = 1
            } else {
                pauseCountLabel?.alpha = 0
                pauseCountLabel?.text = ""
            }
            sync(dt: CGFloat(dt))
            updateHUDVisibility()
            if resumeCountdown <= 0 {
                skipFreezeSample = true
                layoutUI()
            }
            return
        }

        // Hit-stop must survive screenshot stalls (dt spikes to 0.1). Drain at most ~1 frame.
        if hitStop > 0 {
            hitStop = max(0, hitStop - min(dt, 1.0 / 60.0))
            if hitStop > 0 {
                // Keep camera / particles / squash actions alive while sim freezes.
                sync(dt: 0)
                return
            }
        }

        if runPaused {
            sync(dt: 0)
            updateHUDVisibility()
            return
        }

        accumulator += dt
        var steps = 0
        // Smoke: 1:1 on title (ident/title stills); allow 2 catch-up steps in play so
        // wall-clock harness timeouts keep pace. landCooldown is ≥0.22s so the raw
        // sim-land gate (≥100ms wall) still holds at 2× stepping.
        let maxSteps: Int = {
            if !smokeEnabled { return 4 }
            if case .title = sim.state.phase { return 1 }
            return 2
        }()
        while accumulator >= tuning.dt && steps < maxSteps {
            var input = InputFrame(moveX: moveX, moveY: moveY, jumpPressed: jumpPressed, jumpHeld: jumpHeld, pouncePressed: pouncePressed)
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
                // After Mask, keep the bandit alive through pause/bg so death wait isn't raced by phase=won.
                if smokeEnabled,
                   smoke.sawMask,
                   !SmokeBrain.smokeFlagExists("smoke_foreground.txt"),
                   case .failed = sim.state.phase
                {
                    softReviveSmokeHarness()
                    smokeSoftReviveCount += 1
                    sim.state.events.removeAll {
                        if case .fail = $0.kind { return true }
                        return false
                    }
                }
                handle(sim.state.events)
                // Hold Mask Mode open until the harness snaps 04 / 04b — screenshot I/O
                // can take seconds of wall time while the sim keeps ticking.
                if smokeEnabled {
                    let mask1Pending = !SmokeBrain.smokeFlagExists("smoke_mask_ok.txt")
                    let mask2Pending = SmokeBrain.smokeFlagExists("smoke_mask_ok.txt")
                        && !SmokeBrain.smokeFlagExists("smoke_mask2_ok.txt")
                    // Invuln through Mask showcase + pause/bg (MOPs); water/spikes use soft-revive above.
                    if smoke.sawMask, !SmokeBrain.smokeFlagExists("smoke_foreground.txt") {
                        if sim.state.bandit.invuln < 0.35 {
                            smokeInvulnTopUpCount += 1
                        }
                        sim.state.bandit.invuln = max(sim.state.bandit.invuln, 0.35)
                    }
                    let midrunOk = SmokeBrain.smokeFlagExists("smoke_midrun_ok.txt")
                    // Cancel accidental Mask before midrun still — keeps palette + act machine honest.
                    if !midrunOk, sim.state.bandit.maskMode {
                        sim.state.bandit.maskMode = false
                        sim.state.bandit.maskTimer = 0
                        sim.state.bandit.combo = 0
                        smokePreMidrunMaskCancelCount += 1
                    }
                    // Harness: force Mask Mode for 04 / 04b when the bot can't re-chain in time.
                    if midrunOk, SmokeBrain.smokeFlagExists("smoke_force_mask.txt"),
                       !sim.state.bandit.maskMode
                    {
                        sim.state.bandit.maskMode = true
                        sim.state.bandit.maskTimer = max(sim.state.bandit.maskTimer, 6.0)
                        sim.state.bandit.combo = max(sim.state.bandit.combo, tuning.maskModeAtCombo)
                        smoke.sawMask = true
                        smoke.sawStomp = true
                    }
                    // Harness: dump Bandit into canal water for the death beat if seekDeath stalls.
                    if SmokeBrain.smokeFlagExists("smoke_force_fail.txt"),
                       case .playing = sim.state.phase
                    {
                        let tile = tuning.tileSize
                        if let water = sim.map.findFirst(.water) {
                            sim.state.bandit.position = Vec2(
                                (Double(water.0) + 0.5) * tile,
                                (Double(water.1) + 0.5) * tile
                            )
                        }
                        sim.state.bandit.velocity = .zero
                        sim.state.bandit.invuln = 0
                        sim.state.bandit.maskMode = false
                        sim.state.bandit.maskTimer = 0
                        smoke.act = .seekDeath
                    }
                    // Pin Mask open only while the harness is actively capturing 04 / 04b
                    // (smoke_capture_mask.txt). Do NOT pin from midrun→stomp-chain — that
                    // stretched Mask to ~48s vs the ~design window.
                    let capturingMask = SmokeBrain.smokeFlagExists("smoke_capture_mask.txt")
                    let holdFirst = midrunOk && mask1Pending && capturingMask
                    let holdSecond = midrunOk && mask2Pending && smokeSawMaskDropAfterFirst && capturingMask
                    if sim.state.bandit.maskMode, holdFirst || holdSecond {
                        sim.state.bandit.maskTimer = max(sim.state.bandit.maskTimer, 3.0)
                        smokeMaskPinSeconds += tuning.dt
                        smokeMaskPinActive = true
                    } else {
                        smokeMaskPinActive = false
                    }
                    // After 04: wait for a clean maskOn=0 before allowing Mask re-entry for 04b.
                    // Mop-pack bounce + stomp refresh used to re-arm Mask forever past mask-off.
                    if !mask1Pending, mask2Pending, !smokeSawMaskDropAfterFirst {
                        if sim.state.bandit.maskMode {
                            if !smokeMaskDecayArmed {
                                smokeMaskDecayArmed = true
                                // Cap remaining time so mask-off arrives within a few seconds
                                // of the still (shot already captured under pin).
                                smokeMaskDecayCap = min(sim.state.bandit.maskTimer, 3.0)
                                sim.state.bandit.maskTimer = smokeMaskDecayCap
                            }
                            sim.state.bandit.velocity = .zero
                            let expected = max(0, smokeMaskDecayCap - tuning.dt)
                            if sim.state.bandit.maskTimer > expected {
                                smokeMaskRefreshSuppressSeconds +=
                                    sim.state.bandit.maskTimer - expected
                                sim.state.bandit.maskTimer = expected
                            }
                            smokeMaskDecayCap = sim.state.bandit.maskTimer
                            if sim.state.bandit.maskTimer <= 0 {
                                sim.state.bandit.maskMode = false
                            }
                        } else {
                            // Suppress re-trigger until harness observes the drop.
                            if sim.state.bandit.combo >= tuning.maskModeAtCombo {
                                sim.state.bandit.combo = max(0, tuning.maskModeAtCombo - 1)
                            }
                            smokeMaskDecayArmed = false
                            smokeMaskDecayCap = -1
                        }
                    } else if !sim.state.bandit.maskMode {
                        smokeMaskDecayArmed = false
                        smokeMaskDecayCap = -1
                    }
                    if !sim.state.bandit.maskMode, !mask1Pending {
                        smokeSawMaskDropAfterFirst = true
                    }
                    // Harness can request an immediate status write at shot time.
                    if SmokeBrain.smokeFlagExists("smoke_snap_status.txt") {
                        writeSmokeStatus()
                        SmokeBrain.setSmokeFlag("smoke_snap_status.txt", present: false)
                    }
                    writeSmokeForcedDetailIfNeeded()
                }
            }
            accumulator -= tuning.dt
            steps += 1
        }
        sync(dt: CGFloat(dt))
        updateHUDVisibility()
    }

    private func playSFX(_ key: AssetKey) {
        JuiceSound.shared.play(key)
    }

    private func handle(_ events: [SimEvent]) {
        for e in events {
            switch e.kind {
            case .jump:
                JuiceSound.shared.playJump()
                if !smokeEnabled { hapticLight.impactOccurred() }
                squash(0.72, 1.38)
                shake(0.22)
                dust(at: e.position, count: 5, color: ArtCatalog.neonCyan)
                jumpSpark(at: e.position)
            case .land:
                // Raw sim land for CI double-land gate (before audible debounce).
                JuiceSound.shared.logRawLand()
                JuiceSound.shared.playLand()
                squash(1.42, 0.58)
                shake(0.38)
                dust(at: e.position, count: 14, color: ArtCatalog.neonOrange)
                landRing(at: e.position)
            case .pounce:
                JuiceSound.shared.playPounce()
                if !smokeEnabled { hapticMed.impactOccurred() }
                shake(0.55)
                squash(0.85, 1.2)
                neonBurst(at: e.position, color: ArtCatalog.neonCyan, count: 6)
            case .flop:
                // Belly-flop is mid-air commit — do NOT play land SFX here. Pounce→flop→land
                // within <100ms used to log two "sfx land" lines and fail the CI double-land gate.
                squash(1.48, 0.5)
                shake(0.28)
            case .stomp:
                smoke.noteStomp()
                // Midrun hold: ignore accidental pre-hunt stomps in the smoke counter/wait gate.
                let midrunOk = !smokeEnabled || SmokeBrain.smokeFlagExists("smoke_midrun_ok.txt")
                if midrunOk { smokeStatus.stomps += 1 }
                JuiceSound.shared.playStomp()
                if !smokeEnabled { hapticHeavy.impactOccurred() }
                // Hit-stop: ~55 ms base, ~75 ms at combo ≥3 (stays in the 40–80 ms punch band).
                let stop = sim.state.bandit.combo >= 3
                    ? max(tuning.feel.stompHitstop, 0.075)
                    : tuning.feel.stompHitstop
                hitStop = max(hitStop, stop)
                shake(1.35)
                squash(1.55, 0.42)
                neonBurst(at: e.position, color: ArtCatalog.neonPink, count: 18)
                neonBurst(at: e.position, color: ArtCatalog.neonCyan, count: 10)
                dust(at: e.position, count: 16, color: ArtCatalog.neonPink)
                impactRing(at: e.position, color: ArtCatalog.neonPink)
                squashMop(at: e.position)
                hitSpark(at: e.position, color: ArtCatalog.neonPink)
                scorePop(at: e.position, text: "+\(max(1, sim.state.bandit.combo))", color: ArtCatalog.neonLime)
                if !celebratedFirstStomp {
                    celebratedFirstStomp = true
                    showPlayToast("STOMPED!", color: ArtCatalog.neonLime, hold: 1.1)
                }
            case .shiny:
                let combo = sim.state.bandit.combo
                JuiceSound.shared.playCollect(combo: max(1, combo), loot: false)
                shake(0.18)
                collectShinyJuice(at: e.position)
            case .bank:
                let combo = max(1, sim.state.bandit.combo)
                JuiceSound.shared.playCollect(combo: combo, loot: true)
                shake(0.28)
                shinySparkle(at: e.position)
                hitSpark(at: e.position, color: ArtCatalog.neonLime)
                impactRing(at: e.position, color: ArtCatalog.neonLime)
            case .maskOn:
                smoke.sawMask = true
                smokeStatus.mask = true
                // De-stack from stomp_crunch: wait 90ms, then sting + flash.
                hitStop = max(hitStop, 0.12)
                run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.09),
                    SKAction.run { [weak self] in
                        guard let self else { return }
                        self.playSFX(.sfxMaskModeOn)
                        if !self.maskMusicOn {
                            self.maskMusicOn = true
                            JuiceSound.shared.setMaskModeMusic(true)
                        }
                        if !self.smokeEnabled { self.hapticHeavy.impactOccurred() }
                        self.flashMask()
                        // First-minute win: Mask Mode inside ~20 s is the early payoff.
                        if !self.celebratedEarlyWin, self.sim.state.elapsed <= 22 {
                            self.celebratedEarlyWin = true
                            self.showPlayToast("MASK MODE — FIRST WIN!", color: ArtCatalog.neonCyan, hold: 1.8)
                            self.shake(1.1)
                            self.neonBurst(at: self.sim.state.bandit.position, color: ArtCatalog.neonCyan, count: 22)
                        }
                    },
                ]))
            case .hurt:
                JuiceSound.shared.playHurt()
                damageFlash()
                shake(0.35)
            case .win:
                smokeStatus.won = true
                playSFX(.sfxWin)
                JuiceSound.shared.setMaskModeMusic(false)
                clearMaskGrade()
                showOutcome()
                writeSmokeStatus()
            case .fail:
                smokeStatus.died = true
                JuiceSound.shared.playKO()
                JuiceSound.shared.setMaskModeMusic(false)
                clearMaskGrade()
                // Full-opacity KO in front of the MOP — cancel i-frame blink / ghosting.
                sim.state.bandit.invuln = 0
                bandit.alpha = 1
                bandit.zPosition = 55
                hitStop = max(hitStop, 0.28)
                // Hold so the bandit death sheet plays before SPLASHED.
                // Smoke still defers the card until the Mask screenshot flag lands.
                let maskOk = SmokeBrain.smokeFlagExists("smoke_mask_ok.txt")
                if smokeEnabled, !maskOk {
                    writeSmokeStatus()
                } else {
                    failOutcomeHold = 1.35
                    skipFreezeSample = true
                    writeSmokeStatus()
                }
            case .checkpoint:
                playSFX(.sfxCheckpoint)
                hitSpark(at: e.position, color: ArtCatalog.neonLime)
            case .dust:
                dust(at: e.position)
            case .shake:
                shake(0.3)
            case .crewFreed(let crewID):
                progressStore.recordCrewFreed(crewID)
                let member = story.crew(id: crewID)
                let toast = StoryChrome.makeCrewToast(
                    name: member?.name ?? "Crew",
                    line: member?.line ?? "Back on the heist."
                )
                toast.position = CGPoint(x: 0, y: size.height * 0.22)
                toast.zPosition = 400
                overlay.addChild(toast)
                toast.setScale(0.7)
                toast.alpha = 0
                toast.run(SKAction.sequence([
                    SKAction.group([SKAction.fadeIn(withDuration: 0.15), SKAction.scale(to: 1, duration: 0.2)]),
                    SKAction.wait(forDuration: 1.6),
                    SKAction.fadeOut(withDuration: 0.25),
                    SKAction.removeFromParent(),
                ]))
                JuiceSound.shared.playUITap()
                neonBurst(at: e.position, color: ArtCatalog.neonLime, count: 16)
                for (id, node) in crewNodes {
                    guard let cage = sim.state.crewCages.first(where: { $0.id == id }),
                          cage.crewID == crewID, cage.freed else { continue }
                    node.run(SKAction.sequence([
                        SKAction.group([SKAction.fadeOut(withDuration: 0.35), SKAction.scale(to: 1.3, duration: 0.35)]),
                        SKAction.removeFromParent(),
                    ]))
                    crewNodes.removeValue(forKey: id)
                }
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

        let shinies = sim.state.bandit.carriedShinies + sim.state.bandit.bankedShinies
        let isWin: Bool
        // Results always show the run clock (sim elapsed) — same number the player watched
        // on a normal clear. Smoke wall-clock is harness-only and must not inflate the card.
        let seconds: Double
        let combo: Int
        var clearResult: ProgressStore.ClearResult?
        switch sim.state.phase {
        case .won(_, let shinyTotal, let c):
            isWin = true
            seconds = sim.state.elapsed
            combo = c
            title.fontColor = ArtCatalog.neonLime
            title.text = "RESULTS"
            shinyCount.text = "0"
            meta.text = String(format: "⏱ %.0fs    ✦ combo x%d", seconds, combo)
            if let pa = card.childNode(withName: "outcomePA") as? SKLabelNode {
                let idx = progressStore.load().freedCrewIDs.count
                pa.text = story.paTaunt(index: max(0, idx))
                pa.isHidden = pa.text?.isEmpty != false
            }
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
                    JuiceSound.shared.playTallyTick()
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

        // Stars only on clear — death card shows empty medals (no awarded stars).
        let starCount: Int = {
            guard isWin else { return 0 }
            let totalShinies = sim.state.shinies.count
            let got = sim.state.bandit.carriedShinies + sim.state.bandit.bankedShinies
            let levelID = ProgressStore.neonDocksLevelID
            let earned = progressStore.recordClear(
                levelID: levelID,
                shiniesCollected: got,
                shiniesTotal: totalShinies,
                seconds: seconds,
                combo: combo
            )
            clearResult = earned
            lastAwardedMedals = earned.medals.count
            smokeStatus.medals = earned.medals.count
            smokeStatus.combo = max(smokeStatus.combo, combo)
            return earned.medals.count
        }()

        // Ease-out card (~250ms): scale 0.8 → 1, fade, dim backdrop, then stagger medals/buttons.
        card.removeAllActions()
        card.setScale(0.8)
        card.alpha = 0
        card.position = CGPoint(x: 0, y: -36)
        let wash = outcomeRoot.childNode(withName: "outcomeWash")
        wash?.removeAllActions()
        wash?.alpha = 0
        wash?.run(SKAction.fadeAlpha(to: 1, duration: 0.26))
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.24),
            SKAction.scale(to: 1.0, duration: 0.26),
            SKAction.moveTo(y: 0, duration: 0.26),
        ])
        appear.timingMode = .easeOut
        card.run(appear)

        starsNode.isHidden = false
        card.childNode(withName: "newBestStamp")?.removeFromParent()
        card.childNode(withName: "levelUpStamp")?.removeFromParent()
        for i in 0..<3 {
            guard let star = starsNode.childNode(withName: "star\(i)") as? SKLabelNode else { continue }
            star.removeAllActions()
            star.alpha = 0
            star.setScale(0.45)
            star.fontColor = ArtCatalog.neonOrange.withAlphaComponent(0.22)
            if isWin, i < starCount {
                star.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.28 + 0.14 * Double(i)),
                    SKAction.group([
                        SKAction.run { JuiceSound.shared.playStar(i) },
                        SKAction.fadeAlpha(to: 1, duration: 0.14),
                        SKAction.scale(to: 1.25, duration: 0.14),
                    ]),
                    SKAction.run { star.fontColor = ArtCatalog.neonLime },
                    SKAction.scale(to: 1.0, duration: 0.1),
                ]))
            } else if isWin {
                // Empty medal slot (dim) after stagger.
                star.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.28 + 0.14 * Double(i)),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 1, duration: 0.12),
                        SKAction.scale(to: 1.0, duration: 0.12),
                    ]),
                ]))
            }
            // Death: stars stay alpha 0 — no medals on fail.
        }

        // Star labels (Finish / All Shinies / Par) — keep visible under NEW BEST.
        let starLabels = ["Finish", "All Shinies", "Par"]
        for i in 0..<3 {
            guard let star = starsNode.childNode(withName: "star\(i)") else { continue }
            star.childNode(withName: "starCaption")?.removeFromParent()
            let cap = SKLabelNode(fontNamed: "AvenirNext-Medium")
            cap.name = "starCaption"
            cap.text = starLabels[i]
            cap.fontSize = 8
            cap.fontColor = SKColor(white: 0.78, alpha: 1)
            cap.position = CGPoint(x: 0, y: -16)
            star.addChild(cap)
        }

        if isWin, let result = clearResult {
            if result.isNewBest {
                let stamp = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                stamp.name = "newBestStamp"
                stamp.text = "NEW BEST"
                stamp.fontSize = 14
                stamp.fontColor = ArtCatalog.neonOrange
                // Clear of All Shinies label + gear count — slam beside the count, angled.
                stamp.position = CGPoint(x: 78, y: 18)
                stamp.zRotation = -0.14
                stamp.alpha = 0
                stamp.setScale(1.4)
                stamp.zPosition = 5
                card.addChild(stamp)
                stamp.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.85),
                    SKAction.group([
                        SKAction.run { JuiceSound.shared.playNewBest() },
                        SKAction.fadeIn(withDuration: 0.12),
                        SKAction.scale(to: 1.0, duration: 0.16),
                    ]),
                ]))
            }
            // level_up intentionally unused — no rank system yet.
        }

        let retry = card.childNode(withName: "retryBtn")
        let next = card.childNode(withName: "nextBtn")
        let home = card.childNode(withName: "homeBtn")
        retry?.isHidden = isWin
        next?.isHidden = !isWin
        for (idx, btn) in [retry, next, home].enumerated() {
            guard let btn, !btn.isHidden else { continue }
            btn.alpha = 0
            btn.setScale(0.85)
            btn.removeAllActions()
            let pop = SKAction.group([
                SKAction.fadeIn(withDuration: 0.16),
                SKAction.scale(to: 1.0, duration: 0.18),
            ])
            pop.timingMode = .easeOut
            btn.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.4 + 0.08 * Double(idx)),
                pop,
            ]))
        }
    }

    private func sync(dt: CGFloat) {
        let b = sim.state.bandit
        // Physics uses body center; foot-anchored sprites need the feet on the deck.
        bandit.position = CGPoint(x: CGFloat(b.position.x), y: CGFloat(b.position.y) - bodyCenterToFeet)
        bandit.setFacing(b.facing)
        let moveSpeed = CGFloat(hypot(b.velocity.x, 0) / max(tuning.tileSize, 1))
        let runSpeed = CGFloat(tuning.runSpeed)
        bandit.show(
            anim: b.anim,
            maskMode: b.maskMode,
            dt: dt,
            moveSpeed: moveSpeed,
            runSpeed: runSpeed,
            smokeLite: false
        )
        if b.anim == .death {
            bandit.alpha = 1
            bandit.zPosition = 55
        } else if b.invuln > 0 {
            // Stay at least half-visible during i-frames — never a faint ghost.
            let minA = CGFloat(tuning.feel.invulnMinAlpha)
            bandit.alpha = Int(b.invuln * 16) % 2 == 0 ? minA : 1
            bandit.zPosition = 20
        } else {
            bandit.alpha = 1
            bandit.zPosition = 20
        }

        for s in sim.state.shinies {
            guard let node = shinyNodes[s.id] else { continue }
            if shinyCollecting.contains(s.id) { continue }
            node.isHidden = !s.alive
        }
        for c in sim.state.crewCages {
            guard let node = crewNodes[c.id] else { continue }
            node.position = cg(c.position)
            node.isHidden = c.freed
        }
        for m in sim.state.mops {
            guard let node = mopNodes[m.id] else { continue }
            if node.userData?["squashing"] as? Bool == true { continue }
            // MOP home is already foot-on-deck; nudge 1px into the tile top.
            node.position = CGPoint(x: CGFloat(m.position.x), y: CGFloat(m.position.y) - 1)
            if m.alive {
                node.isHidden = false
                node.alpha = 1
                var pose = m.anim
                let near = abs(m.position.x - b.position.x) < 80
                    && abs(m.position.y - b.position.y) < 60
                if pose == .walk, near {
                    pose = .attack
                    if !mopAlerted.contains(m.id) {
                        mopAlerted.insert(m.id)
                        JuiceSound.shared.playMopAlert()
                        JuiceSound.shared.playMopChatter(story.mopChatter.map(\.file))
                    }
                } else if !near {
                    mopAlerted.remove(m.id)
                }
                node.show(anim: pose, facing: m.facing)
            } else if m.anim == .death, m.animHold > 0 {
                // Stomp juice owns the pop — don't play the tip-over death slide.
                node.isHidden = true
            } else {
                node.isHidden = true
            }
        }

        let shinyTotal = b.carriedShinies + b.bankedShinies
        smokeStatus.shinies = shinyTotal
        hudCarried.text = "✦ \(shinyTotal)"
        hudHearts.text = String(repeating: "♥", count: max(0, b.hearts))
        if b.maskMode {
            hudCombo.text = b.combo > 1 ? "◈ MASK ×2  COMBO x\(b.combo)" : "◈ MASK ×2"
            hudCombo.isHidden = false
            hudCombo.fontColor = ArtCatalog.neonCyan
            (hudCombo.childNode(withName: "hudGlow") as? SKLabelNode)?.fontColor = ArtCatalog.neonCyan.withAlphaComponent(0.45)
        } else if b.combo > 1 {
            hudCombo.text = "COMBO x\(b.combo)"
            hudCombo.isHidden = false
            hudCombo.fontColor = ArtCatalog.neonLime
            (hudCombo.childNode(withName: "hudGlow") as? SKLabelNode)?.fontColor = ArtCatalog.neonLime.withAlphaComponent(0.45)
        } else {
            hudCombo.text = ""
            hudCombo.isHidden = true
        }
        if smokeEnabled, smokeWallStart > 0 {
            smokeWallElapsed = CACurrentMediaTime() - smokeWallStart
            hudTime.text = String(format: "⏱ %.0fs", smokeWallElapsed)
        } else {
            hudTime.text = String(format: "⏱ %.0fs", sim.state.elapsed)
        }
        for label in [hudCarried, hudHearts, hudCombo, hudTime] {
            (label.childNode(withName: "hudOutline") as? SKLabelNode)?.text = label.text
            (label.childNode(withName: "hudGlow") as? SKLabelNode)?.text = label.text
        }
        // Mask Mode: soft edge pulse only — afterimages come from BanditVisual.tickMotionTrail.
        if b.maskMode {
            maskGradePulse += dt
            maskVignette.alpha = 1
            if let edge = maskVignette.childNode(withName: "vignetteEdge") as? SKSpriteNode {
                edge.alpha = 0.18 + 0.06 * sin(maskGradePulse * 3.5)
            }
            skyFill.color = ArtCatalog.nightSky
            skyFill.colorBlendFactor = 1
            if !lastMaskMode {
                applyMaskParallaxGrade(active: true, pulse: 1)
            }
        } else {
            maskParticleAcc = 0
            maskGradePulse = 0
            if lastMaskMode {
                applyMaskParallaxGrade(active: false, pulse: 1)
            }
        }

        // Single look-ahead: facing × 0.20×viewW → hero at ~30% (right) / ~70% (left).
        // Side-switch delay: ignore brief facing flips so a quick reverse doesn't park the
        // hero near ~70% while he faces right again.
        let rawWant: CGFloat = b.facing >= 0 ? 1 : -1
        let nowFace = CACurrentMediaTime()
        // ~0.9s side-switch delay so a quick reverse can't whip the hero to ~70%.
        if rawWant != cameraWantFace {
            if nowFace >= cameraFacingHoldUntil {
                cameraWantFace = rawWant
                cameraFacingHoldUntil = nowFace + 0.9
            }
        } else {
            cameraFacingHoldUntil = nowFace + 0.9
        }
        let faceBlend = min(1, CGFloat(dt) / 0.45)
        cameraFacing += (cameraWantFace - cameraFacing) * faceBlend
        var target = cameraTarget(for: b)
        // Follow the lead without lagging a sprint into the right half.
        let s = min(1, CGFloat(tuning.cameraSmooth) * 1.45)
        cameraFocus.x += (target.x - cameraFocus.x) * s
        cameraFocus.y += (target.y - cameraFocus.y) * s
        let z = Self.worldZoom
        // Keep the hero in the 22–40% band while the right lead is active.
        var banditSceneX = z * (CGFloat(b.position.x) - cameraFocus.x)
        var heroFrac = Double((banditSceneX + size.width * 0.5) / max(size.width, 1))
        if cameraWantFace > 0, cameraFacing > 0.85, (heroFrac > 0.40 || heroFrac < 0.22) {
            let desired = size.width * (0.30 - 0.5) // scene-x for 30% of width
            cameraFocus.x = CGFloat(b.position.x) - desired / z
            target = cameraTarget(for: b)
            cameraFocus.x += (target.x - cameraFocus.x) * 0.45
            banditSceneX = z * (CGFloat(b.position.x) - cameraFocus.x)
            heroFrac = Double((banditSceneX + size.width * 0.5) / max(size.width, 1))
        }
        stage.position = CGPoint(x: -cameraFocus.x * z, y: -cameraFocus.y * z)
        // Mid-level surprise once the player reaches the docks mid-street / ladder zone.
        if case .playing = sim.state.phase, !runPaused, !midSurpriseFired {
            let tx = Int(floor(b.position.x / tuning.tileSize))
            if tx >= 42 {
                fireMidLevelSurprise()
            }
        }
        // Hero screen-x every live frame. Min/max accumulate when the right lead is settled
        // (mid-lerp after a reverse is not a placement the framing gate should measure).
        // Skip post-death EXIT sprint (finishPush) — that intentionally rushes the camera.
        // Samples are preserved across death→retry so the gate still sees live-play framing.
        if case .playing = sim.state.phase,
           !runPaused,
           resumeCountdown <= 0,
           sim.state.elapsed > 1.0,
           !smoke.diedOnce
        {
            smokeStatus.heroX = heroFrac
            let settledRight = cameraWantFace > 0
                && cameraFacing > 0.92
                && abs(cameraFacing - cameraWantFace) < 0.06
            if settledRight {
                smokeStatus.heroXMin = min(smokeStatus.heroXMin, heroFrac)
                smokeStatus.heroXMax = max(smokeStatus.heroXMax, heroFrac)
            }
        }
        // Slow parallax — keep plates covering the view (tiled in buildParallax).
        parallaxFar.position = CGPoint(x: cameraFocus.x * 0.88, y: cameraFocus.y * 0.96)
        parallaxMid.position = CGPoint(x: cameraFocus.x * 0.72, y: cameraFocus.y * 0.92)
        parallaxNear.position = CGPoint(x: cameraFocus.x * 0.55, y: cameraFocus.y * 0.88)

        // Mask Mode: keep vignette visible while active; fade out on exit.
        // Do NOT ramp parent alpha toward 1 over an opaque wash — that cyan-bleaches CI shots.
        if b.maskMode {
            maskVignette.isHidden = false
            maskVignette.alpha = 1
        } else if lastMaskMode {
            maskVignette.removeAllActions()
            maskVignette.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.18),
                SKAction.run { [weak self] in self?.maskVignette.isHidden = true },
            ]))
        }
        lastMaskMode = b.maskMode
    }

    private func squash(_ x: CGFloat, _ y: CGFloat) {
        bandit.squash(x: x, y: y)
    }

    /// Clear first-minute goal: stomp into Mask, then bank at EXIT.
    private func showObjectiveBanner() {
        objectiveBanner?.removeFromParent()
        let root = SKNode()
        root.name = "objectiveBanner"
        root.zPosition = 280
        let bg = SKShapeNode(rectOf: CGSize(width: min(size.width * 0.88, 340), height: 52), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.1, alpha: 0.88)
        bg.strokeColor = ArtCatalog.neonCyan
        bg.lineWidth = 1.5
        bg.glowWidth = 1
        root.addChild(bg)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "STOMP 3 → MASK"
        title.fontSize = 16
        title.fontColor = ArtCatalog.neonLime
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 8)
        root.addChild(title)
        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = "Then race the neon EXIT"
        sub.fontSize = 11
        sub.fontColor = SKColor(white: 0.9, alpha: 1)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: -10)
        root.addChild(sub)
        root.position = CGPoint(x: 0, y: size.height * 0.28)
        root.alpha = 0
        root.setScale(0.85)
        overlay.addChild(root)
        objectiveBanner = root
        root.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.18),
                SKAction.scale(to: 1.0, duration: 0.22),
            ]),
            SKAction.wait(forDuration: 3.2),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.35),
                SKAction.moveBy(x: 0, y: 24, duration: 0.35),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func showPlayToast(_ text: String, color: SKColor, hold: TimeInterval) {
        let toast = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        toast.text = text
        toast.fontSize = 18
        toast.fontColor = color
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toast.zPosition = 290
        toast.alpha = 0
        toast.setScale(0.7)
        toast.position = CGPoint(x: 0, y: size.height * 0.18)
        overlay.addChild(toast)
        toast.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.15, duration: 0.12),
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: hold),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent(),
        ]))
    }

    private func placeExitBeacon(at pos: CGPoint, tile: CGFloat) {
        exitBeacon?.removeFromParent()
        let root = SKNode()
        root.name = "exitBeacon"
        root.position = CGPoint(x: pos.x, y: pos.y + tile * 1.35)
        root.zPosition = 8
        let arrow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        arrow.text = "▼ EXIT"
        arrow.fontSize = 12
        arrow.fontColor = ArtCatalog.neonLime
        arrow.verticalAlignmentMode = .center
        root.addChild(arrow)
        let glow = SKSpriteNode(texture: ArtCatalog.softCircleTexture(), size: CGSize(width: tile * 2.2, height: tile * 1.2))
        glow.color = ArtCatalog.neonLime
        glow.colorBlendFactor = 1
        glow.alpha = 0.35
        glow.blendMode = .add
        glow.zPosition = -1
        root.addChild(glow)
        root.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 6, duration: 0.55),
                SKAction.fadeAlpha(to: 1.0, duration: 0.55),
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: -6, duration: 0.55),
                SKAction.fadeAlpha(to: 0.55, duration: 0.55),
            ]),
        ])))
        world.addChild(root)
        exitBeacon = root
    }

    /// Mid-run beat: neon surge + rooftop tease so the middle of the docks feels alive.
    private func fireMidLevelSurprise() {
        midSurpriseFired = true
        showPlayToast("ROOFTOP ROUTE — GO UP!", color: ArtCatalog.neonPink, hold: 1.6)
        shake(0.9)
        if !smokeEnabled { hapticMed.impactOccurred() }
        // Brief city-wide neon pulse on parallax mid signs.
        for node in [parallaxMid, parallaxNear, parallaxFar] {
            node.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
                SKAction.fadeAlpha(to: 0.55, duration: 0.12),
                SKAction.fadeAlpha(to: 1.0, duration: 0.18),
            ]))
        }
        neonBurst(at: sim.state.bandit.position, color: ArtCatalog.neonPink, count: 16)
        neonBurst(at: sim.state.bandit.position, color: ArtCatalog.neonCyan, count: 12)
        playSFX(.sfxCheckpoint)
    }

    private func ensureLandDustEmitter() {
        guard landDustEmitter == nil else { return }
        let e = SKEmitterNode()
        e.particleTexture = ArtCatalog.softCircleTexture()
        e.particleBirthRate = 0
        e.numParticlesToEmit = 0
        e.particleLifetime = 0.28
        e.particleLifetimeRange = 0.06
        e.particlePositionRange = CGVector(dx: 10, dy: 2)
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 1.1
        e.particleSpeed = 55
        e.particleSpeedRange = 35
        e.particleAlpha = 0.85
        e.particleAlphaSpeed = -3.0
        e.particleScale = 0.35
        e.particleScaleRange = 0.15
        e.particleScaleSpeed = -0.8
        e.particleColor = ArtCatalog.neonOrange
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.zPosition = 40
        e.targetNode = world
        world.addChild(e)
        landDustEmitter = e
    }

    private func dust(at pos: Vec2, count: Int = 8, color: SKColor = ArtCatalog.neonOrange) {
        ensureLandDustEmitter()
        guard let e = landDustEmitter else { return }
        e.position = cg(pos)
        e.particleColor = color
        e.particleBirthRate = 0
        e.numParticlesToEmit = count
        e.particleBirthRate = CGFloat(max(80, count * 12))
        e.resetSimulation()
        e.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak e] in
                e?.particleBirthRate = 0
                e?.numParticlesToEmit = 0
            },
        ]), withKey: "dustBurst")
    }

    /// Tiny upward sparks on jump takeoff.
    private func jumpSpark(at pos: Vec2) {
        let origin = cg(pos)
        for _ in 0..<5 {
            let p = SKSpriteNode(
                texture: ArtCatalog.softCircleTexture(),
                size: CGSize(width: CGFloat.random(in: 3...6), height: CGFloat.random(in: 3...6))
            )
            p.color = ArtCatalog.neonCyan
            p.colorBlendFactor = 1
            p.blendMode = .add
            p.alpha = 0.9
            p.position = CGPoint(x: origin.x + CGFloat.random(in: -8...8), y: origin.y - 6)
            p.zPosition = 48
            world.addChild(p)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -12...12), y: CGFloat.random(in: 12...28), duration: 0.18),
                    SKAction.fadeOut(withDuration: 0.18),
                    SKAction.scale(to: 0.2, duration: 0.18),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    /// Soft landing ripple under the feet.
    private func landRing(at pos: Vec2) {
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.strokeColor = ArtCatalog.neonOrange.withAlphaComponent(0.85)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 2
        ring.position = cg(pos)
        ring.zPosition = 42
        world.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.4, duration: 0.16),
                SKAction.fadeOut(withDuration: 0.16),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    /// Expanding impact ring on stomp / bank — reads as a hit.
    private func impactRing(at pos: Vec2, color: SKColor) {
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.strokeColor = color
        ring.fillColor = color.withAlphaComponent(0.12)
        ring.lineWidth = 2.5
        ring.glowWidth = 3
        ring.position = cg(pos)
        ring.zPosition = 50
        ring.setScale(0.4)
        world.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.8, duration: 0.18),
                SKAction.fadeOut(withDuration: 0.18),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func shinySparkle(at pos: Vec2) {
        for _ in 0..<9 {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.8...4))
            p.fillColor = ArtCatalog.neonOrange
            p.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.85)
            p.lineWidth = 0.8
            p.glowWidth = 1.5
            p.position = cg(pos)
            p.zPosition = 55
            world.addChild(p)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -34...34), y: CGFloat.random(in: 10...42), duration: 0.32),
                    SKAction.fadeOut(withDuration: 0.32),
                    SKAction.scale(to: 0.2, duration: 0.32),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private func damageFlash() {
        _ = tryFullscreenFlash(color: ArtCatalog.neonPink, peakAlpha: 0.2, duration: 0.1)
        bandit.enumerateChildNodes(withName: "//*") { node, _ in
            guard let s = node as? SKSpriteNode, s.name != "trail_*" else { return }
            guard ["torso", "head", "armF", "armB", "legF", "legB", "tail", "sprite"].contains(s.name ?? "") else { return }
            s.run(SKAction.sequence([
                SKAction.colorize(with: ArtCatalog.neonPink, colorBlendFactor: 0.75, duration: 0.05),
                SKAction.colorize(withColorBlendFactor: 0.12, duration: 0.22),
            ]))
        }
    }

    /// Small styled hit popup near the contact — no giant debug words.
    private func hitSpark(at pos: Vec2, color: SKColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = "✦"
        l.fontSize = 14
        l.fontColor = color
        l.position = cg(pos)
        l.zPosition = 62
        l.setScale(0.35)
        l.alpha = 0
        l.name = "hitSpark"
        world.addChild(l)
        l.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.04),
                SKAction.scale(to: 1.2, duration: 0.08),
                SKAction.moveBy(x: 0, y: 10, duration: 0.08),
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 14, duration: 0.28),
                SKAction.fadeOut(withDuration: 0.28),
                SKAction.scale(to: 0.6, duration: 0.28),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    /// Score/combo floater at the hit — large enough to read in smoke video.
    private func scorePop(at pos: Vec2, text: String, color: SKColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 26
        l.fontColor = color
        l.position = cg(pos)
        l.zPosition = 63
        l.setScale(0.35)
        l.alpha = 0
        l.name = "scorePop"
        world.addChild(l)
        l.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.05),
                SKAction.scale(to: 1.55, duration: 0.12),
                SKAction.moveBy(x: 0, y: 30, duration: 0.12),
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 28, duration: 0.38),
                SKAction.fadeOut(withDuration: 0.38),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func neonBurst(at pos: Vec2, color: SKColor, count: Int) {
        let origin = cg(pos)
        for _ in 0..<count {
            let p = SKSpriteNode(color: color, size: CGSize(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8)))
            p.blendMode = .add
            p.alpha = 0.95
            p.position = origin
            p.zPosition = 55
            world.addChild(p)
            let dx = CGFloat.random(in: -48...48)
            let dy = CGFloat.random(in: 8...52)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.32),
                    SKAction.fadeOut(withDuration: 0.32),
                    SKAction.scale(to: 0.15, duration: 0.32),
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
        node.isHidden = false
        node.alpha = 1
        let face: CGFloat = node.xScale >= 0 ? 1 : -1
        // White flash → flat squash pop → debris (no sideways tip/slide).
        node.run(SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.0),
            SKAction.wait(forDuration: 1.0 / 60.0),
            SKAction.group([
                SKAction.scaleX(to: 1.4 * face, y: 0.3, duration: 0.05),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.05),
            ]),
            SKAction.group([
                SKAction.scaleX(to: 1.55 * face, y: 0.08, duration: 0.08),
                SKAction.fadeOut(withDuration: 0.08),
            ]),
            SKAction.run { [weak self, weak node] in
                node?.isHidden = true
                node?.setScale(1)
                node?.alpha = 1
                node?.colorBlendFactor = 0
                node?.userData?["squashing"] = false
                self?.mopDebris(at: target)
            },
        ]))
    }

    private func mopDebris(at worldPos: CGPoint) {
        for _ in 0..<8 {
            let bit = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 3...7), height: CGFloat.random(in: 2...5)), cornerRadius: 1)
            bit.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.9)
            bit.strokeColor = .clear
            bit.position = worldPos
            bit.zPosition = 45
            world.addChild(bit)
            bit.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(
                        x: CGFloat.random(in: -40...40),
                        y: CGFloat.random(in: 8...36),
                        duration: 0.28
                    ),
                    SKAction.fadeOut(withDuration: 0.28),
                    SKAction.scale(to: 0.2, duration: 0.28),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
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
        // Shake world (child of stage) so sync's stage.position rewrite does not cancel it.
        let a = amount * 8.5
        world.removeAction(forKey: "shake")
        world.position = .zero
        // Punchy trauma: hard first kick, quick decay.
        let steps: [(CGFloat, CGFloat, TimeInterval)] = [
            (1.35, 0.7, 0.025),
            (-1.9, -1.05, 0.035),
            (1.25, 0.7, 0.035),
            (-0.85, -0.4, 0.03),
            (0.4, 0.22, 0.025),
            (-0.18, -0.1, 0.02),
        ]
        var actions: [SKAction] = steps.map { dx, dy, dur in
            SKAction.moveBy(x: a * dx, y: a * dy, duration: dur)
        }
        actions.append(SKAction.run { [weak self] in self?.world.position = .zero })
        world.run(SKAction.sequence(actions), withKey: "shake")
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
        if smokeEnabled, smokeWallStart > 0 {
            smokeWallElapsed = CACurrentMediaTime() - smokeWallStart
            smokeStatus.wallElapsed = smokeWallElapsed
        }
        smokeStatus.fpsSamples = fpsCount
        smokeStatus.fpsAvg = (fpsCount > 0 && fpsTimeSum > 0) ? Double(fpsCount) / fpsTimeSum : 0
        smokeStatus.maxFrameMs = maxFrameMs
        smokeStatus.maskOn = sim.state.bandit.maskMode
        if sim.state.bandit.maskMode { smokeStatus.mask = true }
        smokeStatus.paused = runPaused || !pauseRoot.isHidden
        // HUD/overlay only — cheap enough to run every status tick.
        smokeStatus.debugLabels = countBannedDebugLabels()
        smokeStatus.combo = max(smokeStatus.combo, sim.state.bestCombo, sim.state.bandit.combo)
        if case .won = sim.state.phase {
            smokeStatus.medals = max(smokeStatus.medals, lastAwardedMedals)
        }
        if retentionMode == "map" { smokeStatus.map = true }
        if retentionMode == "daily" { smokeStatus.daily = true }
        let streetY = sim.map.findFirst(.start).map { Double($0.1) * tuning.tileSize } ?? 0
        smokeStatus.roof = sim.state.bandit.position.y > streetY + tuning.tileSize * 2.5
        let tile = tuning.tileSize
        let wtx = Int(floor(sim.state.bandit.position.x / tile))
        let wty = Int(floor(sim.state.bandit.position.y / tile))
        smokeStatus.worldTX = wtx
        smokeStatus.worldTY = wty
        smokeStatus.worldTXMax = max(smokeStatus.worldTXMax, wtx)
        smokeStatus.stallSec = smoke.progressStallSeconds
        smokeStatus.write()
    }

    /// Count every smoke-only state edit so CI can report honest forced-fallback totals.
    private func writeSmokeForcedDetailIfNeeded() {
        let now = CACurrentMediaTime()
        guard now - smokeLastForcedWrite >= 0.5 else { return }
        smokeLastForcedWrite = now
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = docs.appendingPathComponent("smoke_forced_detail.txt")
        let body = """
        mask_pin_seconds=\(String(format: "%.1f", smokeMaskPinSeconds))
        mask_force_off_count=\(smokeMaskForceOffCount)
        mask_force_off_seconds=\(String(format: "%.1f", smokeMaskForceOffSeconds))
        soft_revive_count=\(smokeSoftReviveCount)
        pre_midrun_mask_cancel=\(smokePreMidrunMaskCancelCount)
        invuln_topup_count=\(smokeInvulnTopUpCount)
        mask_refresh_suppress_seconds=\(String(format: "%.1f", smokeMaskRefreshSuppressSeconds))
        """
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }

    /// CI gate: any visible SKLabel whose text matches the ban list fails smoke.
    /// Scans HUD/overlay only — world juice uses shapes/sprites + `hitSpark` (✦), not banned words.
    private func countBannedDebugLabels() -> Int {
        var count = 0
        let banned = SmokeStatus.bannedDebugTexts
        let scan: (SKNode) -> Void = { root in
            root.enumerateChildNodes(withName: "//*") { node, _ in
                guard let label = node as? SKLabelNode else { return }
                guard !label.isHidden, label.alpha > 0.05 else { return }
                var p: SKNode? = label.parent
                while let cur = p {
                    if cur.isHidden { return }
                    p = cur.parent
                }
                let raw = (label.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { return }
                if banned.contains(raw.uppercased()) { count += 1 }
            }
        }
        scan(hud)
        scan(overlay)
        return count
    }

    private func applyMaskParallaxGrade(active: Bool, pulse: CGFloat) {
        // Do not recolor city plates. Changing color/blendFactor + texture memory pressure
        // turns mid/near plates into solid cyan or white washes (CI cyanWash/blowout gates).
        // Mask grade is character glow + edge vignette only; grid alpha is a light cue.
        _ = pulse
        if let grid = parallaxFar.childNode(withName: "//gridHorizon") as? SKSpriteNode {
            grid.alpha = active ? 0.55 : 0.42
        }
    }

    private func clearMaskGrade() {
        maskVignette.removeAllActions()
        maskVignette.alpha = 0
        maskVignette.isHidden = true
        applyMaskParallaxGrade(active: false, pulse: 1)
        lastMaskMode = false
        maskGradePulse = 0
    }

    /// Photosensitivity safety: ≤3 full-screen flashes per second; skips if over cap.
    @discardableResult
    private func tryFullscreenFlash(color: SKColor, peakAlpha: CGFloat, duration: TimeInterval) -> Bool {
        let now = CACurrentMediaTime()
        flashHistory = flashHistory.filter { now - $0 < 1.0 }
        guard flashHistory.count < 3 else { return false }
        // SKSpriteNode(color:) ignores UIColor alpha — set node.alpha explicitly.
        let alpha = min(peakAlpha, 0.14)
        let life = min(duration, 0.1)
        flashHistory.append(now)
        let flash = SKSpriteNode(color: color, size: size)
        flash.alpha = alpha
        flash.blendMode = .alpha
        flash.zPosition = 274
        flash.name = "safeFlash"
        overlay.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: life),
            SKAction.removeFromParent(),
        ]))
        return true
    }

    private func flashMask() {
        // Crisp Mask beat: LED glints + rim + short afterimage — no blurry ghost head.
        maskVignette.isHidden = false
        maskVignette.alpha = 1
        if let edge = maskVignette.childNode(withName: "vignetteEdge") as? SKSpriteNode {
            edge.alpha = 0.24
        }
        applyMaskParallaxGrade(active: true, pulse: 1)
        _ = tryFullscreenFlash(color: ArtCatalog.neonCyan, peakAlpha: 0.08, duration: 0.08)
        bandit.flashMaskEntry()
        // Camera punch-in.
        let z = Self.worldZoom
        stage.removeAction(forKey: "maskPunch")
        stage.setScale(z)
        stage.run(SKAction.sequence([
            SKAction.scale(to: z * 1.06, duration: 0.08),
            SKAction.scale(to: z, duration: 0.18),
        ]), withKey: "maskPunch")
        // MASK MODE stamp.
        let stamp = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        stamp.text = "MASK MODE"
        stamp.fontSize = 34
        stamp.fontColor = ArtCatalog.neonCyan
        stamp.zPosition = 280
        stamp.setScale(1.6)
        stamp.alpha = 0
        overlay.addChild(stamp)
        stamp.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.06),
                SKAction.scale(to: 1.0, duration: 0.1),
            ]),
            SKAction.wait(forDuration: 0.28),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.16),
                SKAction.scale(to: 0.85, duration: 0.16),
            ]),
            SKAction.removeFromParent(),
        ]))
        neonBurst(at: sim.state.bandit.position, color: ArtCatalog.neonCyan, count: 10)
        neonBurst(at: sim.state.bandit.position, color: ArtCatalog.neonPink, count: 5)
        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 16 + CGFloat(i) * 12)
            ring.strokeColor = ArtCatalog.neonCyan.withAlphaComponent(0.75 - CGFloat(i) * 0.15)
            ring.fillColor = .clear
            ring.lineWidth = 2
            ring.position = bandit.position
            ring.zPosition = 46
            world.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.04 * Double(i)),
                SKAction.group([
                    SKAction.scale(to: 2.8, duration: 0.32),
                    SKAction.fadeOut(withDuration: 0.32),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
        for _ in 0..<3 { bandit.emitMaskTrail() }
        hitSpark(at: sim.state.bandit.position, color: ArtCatalog.neonCyan)
    }
}
#endif
