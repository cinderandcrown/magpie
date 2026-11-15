// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Deterministic autoplay director for `-SmokeAutoplay`.
/// Timeline: title → run/jump/wall → MOP stomp → Mask Mode showcase → water death → retry → exit RESULTS.
public struct SmokeBrain: Equatable, Sendable {
    public enum Act: Equatable, Sendable {
        case idle
        case start
        case play
        case showcaseMask
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
    public var maskShowcaseFrames: Int = 0

    public init() {}

    public mutating func next(sim: Sim) -> (input: InputFrame, start: Bool, retry: Bool) {
        tick += 1
        var input = InputFrame()
        var start = false
        var retry = false

        switch sim.state.phase {
        case .title:
            titleFrames += 1
            if titleFrames >= 180 {
                start = true
                act = .play
            }
            return (input, start, retry)

        case .failed:
            if !diedOnce { diedOnce = true }
            failWait += 1
            if failWait >= 100 {
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
            } else {
                switch act {
                case .play:
                    if sawMask {
                        act = .showcaseMask
                        maskShowcaseFrames = 0
                    } else if sim.state.elapsed > 35 {
                        act = .seekDeath
                    }
                case .showcaseMask:
                    maskShowcaseFrames += 1
                    // Hold Mask Mode on screen ~2.5s so 04-mask-mode captures the glow.
                    if maskShowcaseFrames >= 150 {
                        act = .seekDeath
                    }
                default:
                    break
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

        if act == .showcaseMask {
            // Drift right for Mask Mode visibility, but stop short of the spike trap so seekDeath can walk in.
            var moveX = 0.55
            var jumpPressed = false
            var jumpHeld = false
            if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 3) {
                moveX = 0
            } else if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = tick % 30 == 0
                jumpHeld = true
                moveX = b.onWallRight ? -0.4 : 0.6
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld)
        }

        if act == .finishPush {
            // Always press right — never turn back to re-hunt respawning MOPs.
            var moveX = 1.0
            var jumpPressed = false
            var jumpHeld = false
            var pouncePressed = false

            if let mop = nearestMop(sim: sim) {
                let dx = mop.position.x - b.position.x
                if dx > 0, dx < tile * 2.2, abs(mop.position.y - b.position.y) < tile * 1.5 {
                    // Hop-stomp only when a MOP is immediately ahead, then keep moving.
                    if b.onGround { jumpPressed = true; jumpHeld = true }
                    else if b.velocity.y <= 0 { pouncePressed = true; jumpHeld = true }
                }
            }

            // Leap the 2-tile canal pit (water sits one row below the deck).
            if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 5) || gapAhead(sim: sim, tx: tx, ty: ty) {
                jumpPressed = jumpPressed || b.onGround || b.coyote > 0
                jumpHeld = true
            }
            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
            }
            if let exit = sim.map.findFirst(.exit), b.position.x > Double(exit.0 - 6) * tile {
                jumpPressed = false
                jumpHeld = b.velocity.y > 0
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld, pouncePressed: pouncePressed)
        }

        // Beat 1 — run / jump / wall-slide for midrun screenshots before hunting MOPs.
        if !sawMask, sim.state.elapsed < 4.2 {
            return showcaseRunInput(sim: sim, tx: tx, ty: ty)
        }

        // Beat 2 — hunt MOPs for stomp → Mask Mode.
        if let mop = nearestMop(sim: sim), !sawMask {
            let dx = mop.position.x - b.position.x
            let dy = mop.position.y - b.position.y
            var moveX = dx > 2 ? 1.0 : (dx < -2 ? -1.0 : b.facing)
            var jumpPressed = false
            var jumpHeld = false
            var pouncePressed = false

            if abs(dx) < tile * 1.6, abs(dy) < tile * 1.2 {
                if b.onGround {
                    jumpPressed = true
                    jumpHeld = true
                } else if b.velocity.y <= 0, b.position.y >= mop.position.y - 2 {
                    pouncePressed = true
                } else {
                    jumpHeld = true
                }
            } else if abs(dx) < tile * 3, b.onGround, tick % 18 < 3 {
                jumpPressed = true
                jumpHeld = true
            } else if gapAhead(sim: sim, tx: tx, ty: ty), !hazardAhead(sim: sim, tx: tx, ty: ty, reach: 3) {
                jumpPressed = b.onGround
                jumpHeld = true
            }

            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
                moveX = b.onWallRight ? -1 : 1
            }

            // Stay on the MOP deck — don't stroll into the canal before Mask/death beats.
            if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 2), dx > 0 {
                moveX = min(moveX, 0)
            }

            return InputFrame(
                moveX: moveX,
                jumpPressed: jumpPressed,
                jumpHeld: jumpHeld || jumpPressed,
                pouncePressed: pouncePressed
            )
        }

        return showcaseRunInput(sim: sim, tx: tx, ty: ty)
    }

    private func showcaseRunInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        var moveX = 1.0
        var jumpPressed = false
        var jumpHeld = false
        // Periodic hops + wall-slide taps so 02-midrun reads as Celeste-feel movement.
        if b.onGround, tick % 42 < 4 {
            jumpPressed = true
            jumpHeld = true
        }
        if gapAhead(sim: sim, tx: tx, ty: ty), !hazardAhead(sim: sim, tx: tx, ty: ty, reach: 3) {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
        }
        if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 2) {
            moveX = 0.15
            jumpPressed = false
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = tick % 20 == 0
            jumpHeld = true
            moveX = b.onWallRight ? -0.35 : 0.85
        }
        return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed)
    }

    private func seekDeathInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let here = sim.map.tile(atX: tx, y: ty)
        let right = sim.map.tile(atX: tx + 1, y: ty)
        let left = sim.map.tile(atX: tx - 1, y: ty)
        if here == .spike || here == .water || right == .spike || right == .water || left == .spike || left == .water {
            // Commit into the trap — no jump.
            let dir: Double = (left == .spike || left == .water) ? -0.55 : 0.55
            return InputFrame(moveX: dir)
        }
        // Steer toward the nearest hazard; never jump during seekDeath.
        if let hx = nearestHazardX(sim: sim) {
            let dx = Double(hx) * sim.tuning.tileSize - sim.state.bandit.position.x
            return InputFrame(moveX: dx >= 0 ? 1 : -1)
        }
        return InputFrame(moveX: 1)
    }

    private func nearestMop(sim: Sim) -> MopEnemy? {
        let b = sim.state.bandit.position
        return sim.state.mops
            .filter(\.alive)
            .min(by: { $0.position.distance(to: b) < $1.position.distance(to: b) })
    }

    private func nearestHazardX(sim: Sim) -> Int? {
        var best: Int?
        var bestDist = Int.max
        let bx = Int(floor(sim.state.bandit.position.x / sim.tuning.tileSize))
        for y in 0..<sim.map.height {
            for x in 0..<sim.map.width {
                let t = sim.map.tile(atX: x, y: y)
                if t == .water || t == .spike {
                    let d = abs(x - bx)
                    if d < bestDist {
                        bestDist = d
                        best = x
                    }
                }
            }
        }
        return best
    }

    private func hazardAhead(sim: Sim, tx: Int, ty: Int, reach: Int) -> Bool {
        for d in 1...reach {
            let here = sim.map.tile(atX: tx + d, y: ty)
            let under = sim.map.tile(atX: tx + d, y: ty - 1)
            if here == .water || here == .spike || under == .water || under == .spike { return true }
        }
        return false
    }

    private func gapAhead(sim: Sim, tx: Int, ty: Int) -> Bool {
        let under1 = sim.map.tile(atX: tx + 1, y: ty - 1)
        let under2 = sim.map.tile(atX: tx + 2, y: ty - 1)
        let solid1 = sim.map.isSolid(under1)
        let solid2 = sim.map.isSolid(under2)
        return !solid1 && (solid2 || under1 == .water || under1 == .empty)
    }
}
