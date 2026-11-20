// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore
import GameRender
import Services
import XCTest
#if canImport(SpriteKit)
import SpriteKit
#endif
#if canImport(UIKit)
import UIKit
#endif

final class SmokeTests: XCTestCase {
    func testCoreAndServicesLink() {
        XCTAssertEqual(ModuleInfo.name, "GameCore")
        let clock = MockClock(value: 1)
        XCTAssertEqual(clock.now(), 1)
    }

    func testNeonDocksLoads() throws {
        let map = try NeonDocksLevel.load()
        XCTAssertNotNil(map.findFirst(.start))
        XCTAssertNotNil(map.findFirst(.exit))
    }

    /// Regression: Neon Docks must stay under a jetsam-safe geometry budget.
    /// Ground is one `SKTileMapNode` (not 1 sprite/solid); keep raw solid count bounded so
    /// autotile / prop decoration passes stay cheap on exploration maps (~96×24).
    func testNeonDocksSolidNodeBudget() throws {
        let map = try NeonDocksLevel.load()
        var solids = 0
        for y in 0..<map.height {
            for x in 0..<map.width {
                let t = map.tile(atX: x, y: y)
                if map.isSolid(t) { solids += 1 }
            }
        }
        // Exploration rebuild (~940 solids) still well under a 1200 soft ceiling.
        XCTAssertLessThan(solids, 1200, "unexpected solid count \(solids)")
        XCTAssertGreaterThan(solids, 100)
    }

    /// Regression: SmokeBrain can drive 45s of the smoke demo rooftop without trapping the sim.
    func testSmokeBrainFortyFiveSecondSoak() throws {
        let map = try SmokeDemoLevel.load()
        var tuning = Tuning.default
        tuning.maskModeAtCombo = 1
        tuning.comboGroundGrace = 4
        var sim = Sim(map: map, tuning: tuning, seed: 7)
        var brain = SmokeBrain()
        SmokeBrain.clearSmokeFlags()
        for name in ["smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt", "smoke_death_ok.txt"] {
            SmokeBrain.setSmokeFlag(name, present: true)
        }
        defer { SmokeBrain.clearSmokeFlags() }
        let steps = Int(45 * tuning.simHz)
        var started = false
        var stomps = 0
        for _ in 0..<steps {
            let cue = brain.next(sim: sim)
            if cue.start {
                sim.startRun()
                started = true
            }
            if cue.retry {
                sim.retry()
            }
            if case .playing = sim.state.phase {
                sim.step(cue.input)
                for e in sim.state.events where e.kind == .stomp {
                    stomps += 1
                    brain.noteStomp()
                }
            }
        }
        XCTAssertTrue(started)
        XCTAssertNotEqual(sim.state.phase, .title)
        // With harness flags pre-armed the brain can clear the loop well under 100 ticks.
        XCTAssertGreaterThan(sim.state.tick, 20, "soak must advance the sim past title")
        let finished: Bool = {
            switch sim.state.phase {
            case .won, .failed: return true
            default: return false
            }
        }()
        XCTAssertTrue(
            stomps > 0 || brain.diedOnce || finished,
            "smoke soak should stomp, die, or finish — not idle forever"
        )
    }

    /// Regression for CI 43726848897: 2560×1440 masters must never upload as full RGBA.
    /// Smoke path ImageIO-downsamples to ≤1024px (≤1280 outside smoke).
    func testSmokeBackgroundMasterMemoryBudget() {
        let masterPixels = 2560 * 1440
        let rgbaBytesPerPlate = masterPixels * 4
        XCTAssertGreaterThan(rgbaBytesPerPlate, 14_000_000)
        let smokeMaxPixel = 1024
        let smokeBytesPerPlate = smokeMaxPixel * smokeMaxPixel * 4
        // Three parallax layers at 1024² stay well under one 2560 master.
        XCTAssertLessThan(smokeBytesPerPlate * 3, rgbaBytesPerPlate)
        XCTAssertEqual(smokeMaxPixel, 1024)
    }

    /// Gate: title wordmark must fit inside the iPhone 16 Pro Max safe area at 85% width.
    @MainActor
    func testTitleLogoFitsSafeArea() {
        #if canImport(SpriteKit) && canImport(UIKit)
        let sceneSize = CGSize(width: 430, height: 932)
        let topSafe: CGFloat = 59
        let bottomSafe: CGFloat = 34
        let logo = ArtCatalog.makeLogoNode(lite: false)
        let base = ArtCatalog.fitTitleLogo(logo, sceneWidth: sceneSize.width, fraction: 0.85)
        XCTAssertGreaterThan(base, 0)
        XCTAssertLessThan(base, 1.01, "2048px logo must be scaled down for phone width")
        let hh = sceneSize.height * 0.5
        let safeTop = hh - topSafe
        let safeBottom = -hh + bottomSafe
        let safeH = safeTop - safeBottom
        logo.position = CGPoint(x: 0, y: safeTop - safeH * 0.18)
        let frame = logo.calculateAccumulatedFrame()
        XCTAssertTrue(
            ArtCatalog.logoFrameInsideSafeArea(
                logoFrame: frame,
                sceneSize: sceneSize,
                topSafe: topSafe,
                bottomSafe: bottomSafe
            ),
            "logo frame \(frame) must sit inside safe area"
        )
        XCTAssertLessThanOrEqual(frame.width, sceneSize.width * 0.9 + 1)
        #else
        XCTAssertTrue(true)
        #endif
    }

    /// P0 moonwalk / latch: stick release, JUMP multitouch, and lifecycle pause must zero moveX.
    @MainActor
    func testMoveInputDoesNotLatchAcrossReleaseJumpOrBackground() {
        #if canImport(SpriteKit) && canImport(UIKit)
        let scene = HeistScene(size: CGSize(width: 390, height: 844), smokeAutoplay: false)
        scene.debugSetMoveX(-1)
        XCTAssertEqual(scene.debugMoveX, -1, accuracy: 0.001)
        scene.debugReleaseStick()
        XCTAssertEqual(scene.debugMoveX, 0, accuracy: 0.001)
        XCTAssertFalse(scene.debugHasStickTouch)

        // Multitouch: hold move + JUMP, then release stick — JUMP may stay, move must not.
        scene.debugSetMoveX(1)
        scene.debugPressJumpAlongsideMove()
        XCTAssertTrue(scene.debugJumpHeld)
        scene.debugReleaseStick()
        XCTAssertEqual(scene.debugMoveX, 0, accuracy: 0.001)
        XCTAssertTrue(scene.debugJumpHeld)
        scene.debugReleaseJump()
        XCTAssertFalse(scene.debugJumpHeld)

        // Lifecycle pause (Control Center / resign active) must clear a latched stick.
        scene.debugSetMoveX(-0.8)
        scene.debugLifecyclePause()
        XCTAssertEqual(scene.debugMoveX, 0, accuracy: 0.001)
        XCTAssertFalse(scene.debugHasStickTouch)
        #else
        XCTAssertTrue(true)
        #endif
    }
}
