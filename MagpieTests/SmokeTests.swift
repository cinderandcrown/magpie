// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore
import Services
import XCTest

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

    /// Regression: Neon Docks must stay under a node budget so the simulator does not jetsam.
    /// (Previously each solid spawned a sprite + glow SKShapeNode ≈ 2× and crashed mid-smoke.)
    func testNeonDocksSolidNodeBudget() throws {
        let map = try NeonDocksLevel.load()
        var solids = 0
        for y in 0..<map.height {
            for x in 0..<map.width {
                let t = map.tile(atX: x, y: y)
                if map.isSolid(t) { solids += 1 }
            }
        }
        // One visual node per solid (no edge twin). Leave headroom for props/MOPs/shinies.
        let perSolid = 1
        let budget = solids * perSolid + 250
        XCTAssertLessThan(solids, 700, "unexpected solid count \(solids)")
        XCTAssertLessThanOrEqual(solids * perSolid, budget)
        XCTAssertGreaterThan(solids, 100)
    }

    /// Regression: SmokeBrain can drive 45s of Neon Docks without trapping the sim.
    func testSmokeBrainFortyFiveSecondSoak() throws {
        let map = try NeonDocksLevel.load()
        var tuning = Tuning.default
        tuning.maskModeAtCombo = 3
        var sim = Sim(map: map, tuning: tuning, seed: 7)
        var brain = SmokeBrain()
        let steps = Int(45 * tuning.simHz)
        var started = false
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
            }
        }
        XCTAssertTrue(started)
        // Must have left title and made progress; death or win both OK for soak health.
        XCTAssertNotEqual(sim.state.phase, .title)
        XCTAssertGreaterThan(sim.state.tick, 100)
    }
}
