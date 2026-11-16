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

    /// Smoke harness handshake files in the app Documents directory.
    public static func smokeFlagExists(_ name: String) -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return FileManager.default.fileExists(atPath: docs.appendingPathComponent(name).path)
    }

    /// Unit-test helper: create/remove harness flags in Documents.
    public static func setSmokeFlag(_ name: String, present: Bool) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = docs.appendingPathComponent(name)
        if present {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            try? "ok".write(to: url, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func clearSmokeFlags() {
        for name in [
            "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt", "smoke_death_ok.txt",
            "smoke_show_pause.txt", "smoke_pause_ok.txt",
            "smoke_background.txt", "smoke_foreground.txt",
            "smoke_show_map.txt", "smoke_map_ok.txt", "smoke_show_daily.txt", "smoke_daily_ok.txt",
        ] {
            setSmokeFlag(name, present: false)
        }
    }

    public mutating func next(sim: Sim) -> (input: InputFrame, start: Bool, retry: Bool) {
        tick += 1
        var input = InputFrame()
        var start = false
        var retry = false

        switch sim.state.phase {
        case .title:
            // Stay on title until harness writes `smoke_proceed.txt` (after 01-title shot).
            titleFrames += 1
            let proceed = Self.smokeFlagExists("smoke_proceed.txt")
            let fallback = titleFrames >= 3600 // ~60s @ 60Hz for manual runs
            if proceed || fallback {
                start = true
                act = .play
            }
            return (input, start, retry)

        case .failed:
            failWait += 1
            let deathOk = Self.smokeFlagExists("smoke_death_ok.txt")
            // Premature splash before Mask Mode itself: bounce back fast and forget.
            // Gate on `sawMask` (not the harness file) so unit tests can pre-arm flags
            // without skipping the stomp→Mask beats.
            if !sawMask {
                if failWait >= 45 {
                    retry = true
                    failWait = 0
                    diedOnce = false
                    sawMask = false
                    maskShowcaseFrames = 0
                    act = .play
                }
                return (input, start, retry)
            }
            // Canonical death beat after Mask: hold until harness snaps 05 (~60s manual fallback).
            if !diedOnce { diedOnce = true }
            if deathOk || failWait >= 3600 {
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
                    } else if sim.state.elapsed > 120 {
                        // Ship Mask needs combo 5 on Neon Docks — give the hunt time.
                        act = .seekDeath
                    }
                case .showcaseMask:
                    maskShowcaseFrames += 1
                    // Hold Mask Mode until harness snaps 04. Fallback ~60s for manual runs —
                    // a short hold lets seekDeath/die/retry finish during a slow 04 screenshot,
                    // so the death wait never sees phase=failed.
                    let maskOk = Self.smokeFlagExists("smoke_mask_ok.txt")
                    if maskOk || maskShowcaseFrames >= 3600 {
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
            // Hold on deck for Mask screenshot — maskTimer keeps maskOn=1 while we wait.
            var moveX: Double = 0.08
            if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 6) {
                moveX = -0.35
            } else if b.onWallLeft || b.onWallRight, !b.onGround {
                moveX = b.onWallRight ? -0.5 : 0.4
            }
            if b.maskMode { moveX = min(abs(moveX), 0.12) * (moveX < 0 ? -1 : 1) }
            return InputFrame(moveX: moveX, jumpPressed: false, jumpHeld: false)
        }

        if act == .finishPush {
            return finishPushInput(sim: sim, tx: tx, ty: ty)
        }

        // Beat 1 — run / jump / wall-slide until harness snaps 02-midrun (or elapsed fallback).
        // Do NOT leave this hold on an accidental early stomp/mask — midrun shot must land first.
        let midrunOk = Self.smokeFlagExists("smoke_midrun_ok.txt")
        if !midrunOk, sim.state.elapsed < 90 {
            return showcaseRunInput(sim: sim, tx: tx, ty: ty)
        }

        // Beat 2 — hunt MOPs for stomp → Mask Mode (ship combo 5 on Neon Docks).
        if let mop = nearestMop(sim: sim), !sawMask {
            let dx = mop.position.x - b.position.x
            // Keep rightward pressure; only ease if we clearly overshot a same-deck MOP.
            var moveX: Double = 1.0
            if dx < -8 { moveX = -0.2 }
            var jumpPressed = false
            var jumpHeld = false
            var pouncePressed = false

            if b.onGround || b.coyote > 0 {
                if dx < tile * 5.0 { jumpPressed = true; jumpHeld = true }
            } else if b.velocity.y > 0 {
                jumpHeld = true
            } else if !b.flopping {
                pouncePressed = true
            }

            // Hard block backing into the left water pit.
            if tx <= 5 { moveX = max(moveX, 0.85) }

            return InputFrame(
                moveX: moveX,
                jumpPressed: jumpPressed,
                jumpHeld: jumpHeld || jumpPressed,
                pouncePressed: pouncePressed
            )
        }

        return showcaseRunInput(sim: sim, tx: tx, ty: ty)
    }

    /// Clear Neon Docks after the death beat: run the main deck to EXIT, hop the canal, avoid MOP bags.
    private func finishPushInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let exitTile = sim.map.findFirst(.exit)
        let exit = exitTile.map { sim.map.worldCenter(ofX: $0.0, y: $0.1, tileSize: tile) }
        let targetX = exit?.x ?? (Double(sim.map.width - 2) * tile)
        let targetY = exit?.y ?? b.position.y
        let dx = targetX - b.position.x
        let dy = targetY - b.position.y

        // Hard right on the main deck; only ease if we overshoot EXIT.
        var moveX: Double = dx < -tile * 0.5 ? -0.55 : 1.0
        var jumpPressed = false
        var jumpHeld = false
        var pouncePressed = false

        let needClimb = dy > tile * 0.9
        let gapNear = gapAhead(sim: sim, tx: tx, ty: ty) || gapWithin(sim: sim, tx: tx, ty: ty, reach: 4)
        let hazard = hazardAhead(sim: sim, tx: tx, ty: ty, reach: 6)

        // Canal / pits — jump early from a few tiles back and hold through the apex.
        if gapNear || hazard {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
            moveX = 1.0
            // Stay committed while airborne over the canal.
            if !b.onGround { jumpHeld = b.velocity.y > -10 }
        } else if needClimb, b.onGround {
            jumpPressed = true
            jumpHeld = true
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = true
            jumpHeld = true
            moveX = b.onWallRight ? -0.4 : 1
        }

        // Same-deck MOP: hop-stomp. Higher MOPs: stay low and run under (no cadence hops).
        if let mop = nearestMop(sim: sim) {
            let mdx = mop.position.x - b.position.x
            let mdy = mop.position.y - b.position.y
            if mdx > -tile, mdx < tile * 3.0, abs(mdy) < tile * 1.1 {
                if b.onGround {
                    jumpPressed = true
                    jumpHeld = true
                } else if !b.flopping, b.velocity.y <= 0, b.position.y >= mop.position.y - 4 {
                    pouncePressed = true
                }
            } else if mdx > 0, mdx < tile * 2.5, mdy > tile * 0.8 {
                // MOP above — do not jump into its bag hitbox.
                jumpPressed = false
                jumpHeld = false
            }
        }

        return InputFrame(
            moveX: moveX,
            jumpPressed: jumpPressed,
            jumpHeld: jumpHeld || jumpPressed,
            pouncePressed: pouncePressed
        )
    }

    private func showcaseRunInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        // Midrun beat: keep moving so the screenshot shows a running ship build (no wall-idle).
        // Cycle walk → run → hop every ~3.5s for sheet coverage.
        let phase = tick % 210
        var moveX: Double
        var jumpPressed = false
        var jumpHeld = false
        if phase < 90 {
            moveX = 0.4 // walk
        } else if phase < 170 {
            moveX = 1.0 // run
        } else {
            moveX = 1.0
            if b.onGround, phase == 170 || phase == 190 {
                jumpPressed = true
                jumpHeld = true
            } else if !b.onGround {
                jumpHeld = b.velocity.y > 0
            }
        }
        // Softly keep clear of MOPs without pinning to a wall.
        if let mop = nearestMop(sim: sim) {
            let dx = mop.position.x - b.position.x
            if dx > 0, dx < tile * 3.5 {
                moveX = min(moveX, 0.15)
            }
        }
        if gapAhead(sim: sim, tx: tx, ty: ty), !hazardAhead(sim: sim, tx: tx, ty: ty, reach: 3) {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
            moveX = max(moveX, 0.85)
        }
        if hazardAhead(sim: sim, tx: tx, ty: ty, reach: 2) {
            // Jump the hazard — never reverse into the left water pit by spawn.
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = true
            moveX = max(moveX, 0.85)
        }
        if tx <= 5 {
            moveX = max(moveX, 0.9)
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = tick % 20 == 0
            jumpHeld = true
            moveX = b.onWallRight ? -0.55 : 0.85
        }
        return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed)
    }

    private func seekDeathInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let here = sim.map.tile(atX: tx, y: ty)
        let under = sim.map.tile(atX: tx, y: ty - 1)
        let right = sim.map.tile(atX: tx + 1, y: ty)
        let left = sim.map.tile(atX: tx - 1, y: ty)
        let underR = sim.map.tile(atX: tx + 1, y: ty - 1)
        let underL = sim.map.tile(atX: tx - 1, y: ty - 1)
        if here == .spike || here == .water || under == .spike || under == .water
            || right == .spike || right == .water || left == .spike || left == .water
            || underR == .water || underL == .water {
            // Commit into the trap — walk off, no jump.
            let dir: Double = (left == .spike || left == .water || underL == .water) ? -1 : 1
            return InputFrame(moveX: dir)
        }
        // Steer toward the canal; jump gaps/walls so we don't soft-lock on a ledge.
        if let hx = nearestHazardX(sim: sim) {
            let dx = Double(hx) * tile - b.position.x
            var moveX: Double = dx >= 0 ? 1 : -1
            var jumpPressed = false
            var jumpHeld = false
            if b.onWallLeft || b.onWallRight, !b.onGround {
                jumpPressed = true
                jumpHeld = true
                moveX = b.onWallRight ? -1 : 1
            } else if gapAhead(sim: sim, tx: tx, ty: ty), dx > 0 {
                // Leap toward the canal across platform gaps.
                jumpPressed = b.onGround || b.coyote > 0
                jumpHeld = true
            } else if !sim.map.isSolid(under), under != .water, abs(dx) > tile * 2 {
                // Already airborne over a gap — keep moving toward the hazard.
                moveX = dx >= 0 ? 1 : -1
            }
            return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld)
        }
        return InputFrame(moveX: 1)
    }

    private func nearestMop(sim: Sim) -> MopEnemy? {
        let b = sim.state.bandit.position
        let tile = sim.tuning.tileSize
        let alive = sim.state.mops.filter(\.alive)
        // Prefer same-deck targets (small |dy|) so hunt doesn't climb away from the opening pack.
        let sameDeck = alive.filter { abs($0.position.y - b.y) < tile * 1.6 }
        let pool = sameDeck.isEmpty ? alive : sameDeck
        return pool.min(by: { $0.position.distance(to: b) < $1.position.distance(to: b) })
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

    /// True when a non-solid floor cell exists within `reach` tiles ahead (canal approach).
    private func gapWithin(sim: Sim, tx: Int, ty: Int, reach: Int) -> Bool {
        for d in 1...reach {
            let under = sim.map.tile(atX: tx + d, y: ty - 1)
            if !sim.map.isSolid(under) || under == .water { return true }
        }
        return false
    }
}
