// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Deterministic-ish autoplay director for `-SmokeAutoplay` simulator demos.
/// Drives Neon Docks: run, jump, wall slide, stomp MOPs → Mask Mode, die once, retry, push for exit.
public struct SmokeBrain: Equatable, Sendable {
    public enum Act: Equatable, Sendable {
        case idle
        case start
        case play
        case seekDeath
        case waitRetry
        case finishPush
        case done
    }

    public var act: Act = .idle
    public var tick: Int = 0
    public var diedOnce: Bool = false
    public var sawMask: Bool = false
    public var sawStomp: Bool = false
    public var titleFrames: Int = 0
    public var failWait: Int = 0

    public init() {}

    public mutating func next(sim: Sim) -> (input: InputFrame, start: Bool, retry: Bool) {
        tick += 1
        var input = InputFrame()
        var start = false
        var retry = false

        switch sim.state.phase {
        case .title:
            titleFrames += 1
            // Hold title briefly so smoke can capture 01-title, then start.
            if titleFrames >= 90 { // 1.5s
                start = true
                act = .play
            }
            return (input, start, retry)

        case .failed:
            if !diedOnce {
                diedOnce = true
            }
            failWait += 1
            if failWait >= 75 { // ~1.25s on results
                retry = true
                failWait = 0
                act = .finishPush
            }
            return (input, start, retry)

        case .won:
            act = .done
            return (input, start, retry)

        case .playing:
            failWait = 0
            if sim.state.bandit.maskMode { sawMask = true }
            if sim.state.bestCombo > 0 || sim.state.bandit.combo > 0 { /* stomps tracked via events in scene */ }

            // After ~22s of play without a death, seek the water hazard once.
            if !diedOnce, sim.state.elapsed > 22, act == .play {
                act = .seekDeath
            }
            // After Mask Mode or enough stomps, still push forward.
            if diedOnce { act = .finishPush }
            if sawMask, !diedOnce, sim.state.elapsed > 28 {
                act = .seekDeath
            }

            input = decidePlaying(sim: sim)
            return (input, start, retry)
        }
    }

    public mutating func noteStomp() { sawStomp = true }

    private mutating func decidePlaying(sim: Sim) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let tx = Int(floor(b.position.x / tile))
        let ty = Int(floor(b.position.y / tile))

        var moveX = 1.0
        var jumpPressed = false
        var jumpHeld = false
        var pouncePressed = false

        // Seek death: walk toward known water pocket then fall.
        if act == .seekDeath {
            // Water sits around mid-map on the canal row — head right until over water, then stop and fall.
            let waterAhead = !sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty - 1))
                && sim.map.tile(atX: tx + 1, y: max(0, ty - 1)) == .water
            if waterAhead || sim.map.tile(atX: tx, y: max(0, ty - 1)) == .water {
                moveX = 0.15
                // Walk off
            } else if b.position.x < tile * 40 {
                moveX = 1
                if gapAhead(sim: sim, tx: tx, ty: ty) {
                    jumpPressed = true
                    jumpHeld = true
                }
            } else {
                moveX = 1
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld, pouncePressed: false)
        }

        // Hunt nearest living MOP slightly above or ahead for stomps / Mask Mode.
        if let mop = nearestMop(sim: sim), !sawMask || b.combo < sim.tuning.maskModeAtCombo {
            let dx = mop.position.x - b.position.x
            let dy = mop.position.y - b.position.y
            moveX = dx > 4 ? 1 : (dx < -4 ? -1 : b.facing)
            if abs(dx) < tile * 2.2, dy > -tile * 0.5, dy < tile * 3 {
                // Jump up then pounce/flop onto it
                if b.onGround {
                    jumpPressed = true
                    jumpHeld = true
                } else if b.position.y > mop.position.y - 4 {
                    pouncePressed = true
                    jumpHeld = false
                } else {
                    jumpHeld = true
                }
            } else if gapAhead(sim: sim, tx: tx, ty: ty) || platformAbove(sim: sim, tx: tx, ty: ty) {
                jumpPressed = b.onGround
                jumpHeld = true
            }
            // Wall slide + jump for vertical routes
            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
                moveX = b.onWallRight ? -1 : 1
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed, pouncePressed: pouncePressed)
        }

        // Default: run toward exit, jump gaps, climb with wall jumps.
        moveX = 1
        if gapAhead(sim: sim, tx: tx, ty: ty) {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
        }
        if platformAbove(sim: sim, tx: tx, ty: ty), b.onGround, tick % 40 < 2 {
            jumpPressed = true
            jumpHeld = true
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = true
            jumpHeld = true
            moveX = b.onWallRight ? -0.2 : 1
        }
        // Opportunistic pounce when airborne near a mop
        if !b.onGround, let mop = nearestMop(sim: sim),
           abs(mop.position.x - b.position.x) < tile * 1.8,
           b.position.y > mop.position.y {
            pouncePressed = true
        }

        return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed, pouncePressed: pouncePressed)
    }

    private func nearestMop(sim: Sim) -> MopEnemy? {
        let b = sim.state.bandit.position
        return sim.state.mops
            .filter(\.alive)
            .min(by: { $0.position.distance(to: b) < $1.position.distance(to: b) })
    }

    private func gapAhead(sim: Sim, tx: Int, ty: Int) -> Bool {
        let under1 = sim.map.tile(atX: tx + 1, y: ty - 1)
        let under2 = sim.map.tile(atX: tx + 2, y: ty - 1)
        let solid1 = sim.map.isSolid(under1)
        let solid2 = sim.map.isSolid(under2)
        // Jump when the next foot cell is empty (gap / water) even if a ledge exists further.
        return !solid1 && (solid2 || under1 == .water || under1 == .empty)
    }

    private func platformAbove(sim: Sim, tx: Int, ty: Int) -> Bool {
        sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty + 2))
            || sim.map.isSolid(sim.map.tile(atX: tx, y: ty + 3))
    }
}
