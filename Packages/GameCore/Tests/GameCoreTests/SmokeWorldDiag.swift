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
        var maxTXBeforeDeath = 0
        var died = false
        var won = false
        var sawMask = false
        var postMidrunStomps = 0
        var prematureWin = false
        let hz = tuning.simHz

        for _ in 0..<Int(260 * hz) {
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
            } else if t < 70 {
                setFlags([
                    "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt",
                    "smoke_foreground.txt",
                ])
            } else {
                // Release death + second mask as soon as the street beats have had time.
                setFlags([
                    "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt",
                    "smoke_mask2_ok.txt", "smoke_foreground.txt", "smoke_death_ok.txt",
                ])
            }

            let midrunOk = SmokeBrain.smokeFlagExists("smoke_midrun_ok.txt")
            let cue = brain.next(sim: sim)
            if cue.start { sim.startRun() }
            if cue.retry {
                // Premature EXIT retry stays on .play; death retry uses finishPush from brain.
                if brain.act != .finishPush, case .won = sim.state.phase {
                    prematureWin = true
                }
                sim.retry()
                if brain.diedOnce {
                    brain.act = .finishPush
                }
            }
            switch sim.state.phase {
            case .playing:
                sim.step(cue.input)
                for e in sim.state.events {
                    if case .stomp = e.kind {
                        brain.noteStomp()
                        if midrunOk { postMidrunStomps += 1 }
                    }
                    if case .maskOn = e.kind { sawMask = true }
                    if case .fail = e.kind { died = true }
                    if case .win = e.kind { won = true }
                }
            case .failed: died = true
            case .won:
                if !brain.diedOnce { prematureWin = true }
                won = brain.diedOnce
            default: break
            }

            let tx = Int(floor(sim.state.bandit.position.x / tile))
            maxTX = max(maxTX, tx)
            if !died { maxTXBeforeDeath = max(maxTXBeforeDeath, tx) }
            if won && brain.diedOnce { break }
        }

        XCTAssertLessThan(
            maxTXBeforeDeath, exitX - 2,
            "must not reach EXIT before death (maxTXBeforeDeath=\(maxTXBeforeDeath) exit=\(exitX))"
        )
        XCTAssertGreaterThanOrEqual(postMidrunStomps, 3, "post-midrun stomp-chain without force (got \(postMidrunStomps))")
        XCTAssertTrue(sawMask, "Mask without smoke_force_mask")
        XCTAssertTrue(died, "canal death without smoke_force_fail")
        XCTAssertTrue(won, "EXIT after death retry (maxTX=\(maxTX) exit=\(exitX) prematureWin=\(prematureWin))")
        XCTAssertGreaterThanOrEqual(
            maxTX, exitX - 1,
            "finishPush must reach EXIT (maxTX=\(maxTX) exit=\(exitX))"
        )
        XCTAssertFalse(
            SmokeBrain.smokeFlagExists("smoke_force_mask.txt")
                || SmokeBrain.smokeFlagExists("smoke_force_fail.txt"),
            "test must not leave force flags armed"
        )
        _ = canalX
    }
}
