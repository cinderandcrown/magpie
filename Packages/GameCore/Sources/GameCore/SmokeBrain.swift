// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Deterministic-ish autoplay director for `-SmokeAutoplay` simulator demos.
/// Tuned for `SmokeDemoLevel`: run, jump-stomp MOPs → Mask Mode, wall slide, water death, retry.
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
    public var stompCount: Int = 0

    public init() {}

    public mutating func next(sim: Sim) -> (input: InputFrame, start: Bool, retry: Bool) {
        tick += 1
        var input = InputFrame()
        var start = false
        var retry = false

        switch sim.state.phase {
        case .title:
            titleFrames += 1
            // ~3s at 60Hz / 1 step/frame so 01-title catches TAP TO START.
            if titleFrames >= 180 {
                start = true
                act = .play
            }
            return (input, start, retry)

        case .failed:
            if !diedOnce { diedOnce = true }
            failWait += 1
            if failWait >= 90 {
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

            if diedOnce {
                act = .finishPush
            } else if act == .play {
                if sawMask || (sawStomp && sim.state.elapsed > 12) || sim.state.elapsed > 35 {
                    act = .seekDeath
                }
            }

            input = decidePlaying(sim: sim)
            return (input, start, retry)
        }
    }

    public mutating func noteStomp() {
        sawStomp = true
        stompCount += 1
    }

    private mutating func decidePlaying(sim: Sim) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let tx = Int(floor(b.position.x / tile))
        let ty = Int(floor(b.position.y / tile))

        if act == .seekDeath {
            return seekDeathInput(sim: sim, tx: tx, ty: ty)
        }

        // Finish push after retry: run right, jump gaps, graze the wall for a slide beat.
        if act == .finishPush {
            var moveX = 1.0
            var jumpPressed = false
            var jumpHeld = false
            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
                moveX = b.onWallRight ? -0.3 : 1
            } else if gapAhead(sim: sim, tx: tx, ty: ty) {
                jumpPressed = b.onGround
                jumpHeld = true
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld)
        }

        // Hunt MOPs on the rooftop deck — jump and fall onto their heads.
        if let mop = nearestMop(sim: sim), !sawMask {
            let dx = mop.position.x - b.position.x
            let dy = mop.position.y - b.position.y
            var moveX = dx > 2 ? 1.0 : (dx < -2 ? -1.0 : b.facing)
            var jumpPressed = false
            var jumpHeld = false
            var pouncePressed = false

            if abs(dx) < tile * 1.6, abs(dy) < tile * 1.2 {
                // Beside mop: hop then stomp on the way down.
                if b.onGround {
                    jumpPressed = true
                    jumpHeld = true
                } else if b.velocity.y <= 0, b.position.y >= mop.position.y - 2 {
                    pouncePressed = true
                } else {
                    jumpHeld = true
                }
            } else if abs(dx) < tile * 3, b.onGround, tick % 20 < 4 {
                jumpPressed = true
                jumpHeld = true
            } else if gapAhead(sim: sim, tx: tx, ty: ty) {
                jumpPressed = b.onGround
                jumpHeld = true
            }

            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
                moveX = b.onWallRight ? -1 : 1
            }

            return InputFrame(
                moveX: moveX,
                jumpPressed: jumpPressed,
                jumpHeld: jumpHeld || jumpPressed,
                pouncePressed: pouncePressed
            )
        }

        var moveX = 1.0
        var jumpPressed = false
        var jumpHeld = false
        if gapAhead(sim: sim, tx: tx, ty: ty) {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = true
            jumpHeld = true
            moveX = b.onWallRight ? -0.2 : 1
        }
        return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed)
    }

    private func seekDeathInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let under = sim.map.tile(atX: tx, y: ty - 1)
        let underR = sim.map.tile(atX: tx + 1, y: ty - 1)
        let here = sim.map.tile(atX: tx, y: ty)
        // Walk into water — never jump over it.
        if here == .water || under == .water || underR == .water {
            return InputFrame(moveX: 0.35)
        }
        if underR == .water || !sim.map.isSolid(underR) && underR != .wall {
            // Approach hazard / open pit without jumping.
            return InputFrame(moveX: 1)
        }
        // Keep moving right toward the canal; hop only onto solid ledges that aren't hazards.
        var jumpPressed = false
        var jumpHeld = false
        if gapAhead(sim: sim, tx: tx, ty: ty),
           sim.map.tile(atX: tx + 1, y: ty - 1) != .water,
           sim.map.isSolid(sim.map.tile(atX: tx + 2, y: ty - 1)) {
            jumpPressed = b.onGround
            jumpHeld = true
        }
        return InputFrame(moveX: 1, jumpPressed: jumpPressed, jumpHeld: jumpHeld)
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
        return !solid1 && (solid2 || under1 == .water || under1 == .empty)
    }
}
