// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import XCTest
@testable import GameCore

/// Proves SmokeBrain progresses in *world* tile X (not screen heroX) without smoke_force_*.
final class SmokeWorldProgressTests: XCTestCase {
    func testSmokeBrainWorldProgressWithoutForceFlags() throws {
        let map = try NeonDocksLevel.load()
        let tuning = Tuning.default
        var sim = Sim(map: map, tuning: tuning, seed: 7)
        var brain = SmokeBrain()
        SmokeBrain.clearSmokeFlags()
        defer { SmokeBrain.clearSmokeFlags() }

        let tile = tuning.tileSize
        let exitX = map.findFirst(.exit)!.0
        let canalX = map.findAll(.water).map(\.0).min() ?? 45

        func setFlags(_ names: Set<String>) {
            let all = [
                "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_prefer_roof.txt",
                "smoke_mask_ok.txt", "smoke_mask2_ok.txt", "smoke_foreground.txt",
                "smoke_death_ok.txt", "smoke_force_mask.txt", "smoke_force_fail.txt",
            ]
            for n in all { SmokeBrain.setSmokeFlag(n, present: names.contains(n)) }
        }

        var maxTX = 0
        var died = false
        var won = false
        var sawMask = false
        let hz = tuning.simHz

        for _ in 0..<Int(220 * hz) {
            let t = sim.state.elapsed
            // CI-like cadence, but never arm force_*.
            if case .title = sim.state.phase {
                setFlags(["smoke_proceed.txt"])
            } else if t < 9 {
                setFlags(["smoke_proceed.txt"])
            } else if t < 16 {
                setFlags(["smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_prefer_roof.txt"])
            } else if t < 55 {
                setFlags(["smoke_proceed.txt", "smoke_midrun_ok.txt"])
            } else if t < 95 {
                setFlags([
                    "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt",
                    "smoke_foreground.txt",
                ])
            } else {
                setFlags([
                    "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt",
                    "smoke_mask2_ok.txt", "smoke_foreground.txt", "smoke_death_ok.txt",
                ])
            }

            let cue = brain.next(sim: sim)
            if cue.start { sim.startRun() }
            if cue.retry {
                sim.retry()
                brain.act = .finishPush
            }
            switch sim.state.phase {
            case .playing:
                sim.step(cue.input)
                for e in sim.state.events {
                    if case .stomp = e.kind { brain.noteStomp() }
                    if case .maskOn = e.kind { sawMask = true }
                    if case .fail = e.kind { died = true }
                    if case .win = e.kind { won = true }
                }
            case .failed: died = true
            case .won: won = true
            default: break
            }

            let tx = Int(floor(sim.state.bandit.position.x / tile))
            maxTX = max(maxTX, tx)
            if won { break }
        }

        XCTAssertGreaterThan(
            maxTX, canalX - 2,
            "worldTX must clear canal (maxTX=\(maxTX) canal=\(canalX)); heroX≈0.32 is camera framing only"
        )
        XCTAssertTrue(sawMask, "Mask without smoke_force_mask")
        XCTAssertTrue(died, "canal death without smoke_force_fail")
        XCTAssertTrue(won, "EXIT after retry without force flags (maxTX=\(maxTX) exit=\(exitX))")
        XCTAssertFalse(
            SmokeBrain.smokeFlagExists("smoke_force_mask.txt")
                || SmokeBrain.smokeFlagExists("smoke_force_fail.txt"),
            "test must not leave force flags armed"
        )
    }
}
