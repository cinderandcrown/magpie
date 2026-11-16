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
    public var seekDeathFrames: Int = 0

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
            "smoke_proceed.txt", "smoke_midrun_ok.txt", "smoke_mask_ok.txt", "smoke_mask2_ok.txt",
            "smoke_death_ok.txt",
            "smoke_show_pause.txt", "smoke_pause_ok.txt",
            "smoke_background.txt", "smoke_foreground.txt",
            "smoke_show_map.txt", "smoke_map_ok.txt", "smoke_show_daily.txt", "smoke_daily_ok.txt",
            "smoke_prefer_roof.txt",
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
            // Canonical death beat after Mask: hold until harness snaps 05.
            // When the smoke harness is driving (mask_ok present), NEVER auto-retry on
            // failWait — a premature splash during pause/bg used to hit 3600 (~60s),
            // retry into finishPush, and race the death wait with phase=won.
            if !diedOnce { diedOnce = true }
            let harnessDriving = Self.smokeFlagExists("smoke_mask_ok.txt")
            let manualFallback = !harnessDriving && failWait >= 3600
            if deathOk || manualFallback {
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
            // Defer Mask credit until midrun still is done — early alley stomps used to
            // flip act→showcaseMask, then freeze with maskOn=0 waiting for 04 forever.
            let midrunReady = Self.smokeFlagExists("smoke_midrun_ok.txt")
                || !Self.smokeFlagExists("smoke_proceed.txt")
            if sim.state.bandit.maskMode, midrunReady {
                sawMask = true
            }

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
                    // Hold until harness snaps 04 + 04b (second Mask) AND finishes pause/bg.
                    // Seeking death right after mask_ok races pause-resume (phase=failed
                    // while the script still waits for phase=playing).
                    let maskOk = Self.smokeFlagExists("smoke_mask_ok.txt")
                    let mask2Ok = Self.smokeFlagExists("smoke_mask2_ok.txt")
                    let pauseBgDone = Self.smokeFlagExists("smoke_foreground.txt")
                    if (maskOk && mask2Ok && pauseBgDone) || maskShowcaseFrames >= 3600 {
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

        let midrunOk = Self.smokeFlagExists("smoke_midrun_ok.txt")

        // Beat 1 — street run until midrun still lands (palette needs magenta neon, not Mask/roof).
        // Prefer_roof is armed only AFTER midrun_ok by the harness.
        if !midrunOk, sim.state.elapsed < 90, act != .seekDeath, act != .finishPush {
            return showcaseRunInput(sim: sim, tx: tx, ty: ty)
        }

        // Harness rooftop clip: climb while prefer_roof is set (even during showcaseMask).
        if Self.smokeFlagExists("smoke_prefer_roof.txt"),
           act != .seekDeath, act != .finishPush {
            return preferRoofClimbInput(sim: sim, tx: tx, ty: ty)
        }

        if act == .seekDeath {
            seekDeathFrames += 1
            return seekDeathInput(sim: sim, tx: tx, ty: ty)
        }

        if act == .showcaseMask {
            let maskOk = Self.smokeFlagExists("smoke_mask_ok.txt")
            let mask2Ok = Self.smokeFlagExists("smoke_mask2_ok.txt")
            // Hunt whenever Mask is off and a Mask still (04 / 04b) is still pending.
            if !b.maskMode, (!maskOk || !mask2Ok) {
                return maskReentryHuntInput(sim: sim, tx: tx, ty: ty)
            }
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

        // Beat 2 — hunt MOPs for stomp → Mask Mode (ship combo 5 on Neon Docks).
        if let mop = nearestMop(sim: sim), !sawMask {
            let dx = mop.position.x - b.position.x
            let dy = mop.position.y - b.position.y
            // Keep rightward pressure; only ease if we clearly overshot a same-deck MOP.
            var moveX: Double = 1.0
            if dx < -8 { moveX = -0.35 }
            else if abs(dx) < tile * 1.2 { moveX = dx >= 0 ? 0.55 : -0.35 }
            var jumpPressed = false
            var jumpHeld = false
            var pouncePressed = false

            if b.onGround || b.coyote > 0 {
                // Jump earlier for chains — bounce into the next patrol.
                if dx < tile * 6.5, abs(dy) < tile * 2.2 { jumpPressed = true; jumpHeld = true }
            } else if b.velocity.y > 0 {
                jumpHeld = true // variable-jump + stomp bounce height
            } else {
                // Falling: hold jump for higher bounce; pounce for magnet assist.
                jumpHeld = true
                if !b.flopping { pouncePressed = true }
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

    /// Clear Neon Docks after the death beat: stay on the street deck to EXIT.
    private func finishPushInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let exitTile = sim.map.findFirst(.exit)
        let exit = exitTile.map { sim.map.worldCenter(ofX: $0.0, y: $0.1, tileSize: tile) }
        let targetX = exit?.x ?? (Double(sim.map.width - 2) * tile)
        let targetY = exit?.y ?? b.position.y
        let dx = targetX - b.position.x
        let streetY = sim.map.findFirst(.start).map { Double($0.1) * tile } ?? targetY

        // If we overshot onto a roof after the high jump buff, drop back to street.
        if b.position.y > streetY + tile * 0.45 {
            let edgeR = !sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty - 1))
                || sim.map.tile(atX: tx + 1, y: ty - 1) == .oneWay
            if edgeR || !b.onGround {
                return InputFrame(moveX: 1, moveY: -1)
            }
            // Walk toward the nearest ledge (prefer right / exit).
            return InputFrame(moveX: 1, moveY: -1, jumpPressed: false, jumpHeld: false)
        }

        // Hard right on the main deck; only ease if we overshoot EXIT.
        var moveX: Double = dx < -tile * 0.5 ? -0.55 : 1.0
        var jumpPressed = false
        var jumpHeld = false
        var pouncePressed = false

        let gapNear = gapAhead(sim: sim, tx: tx, ty: ty) || gapWithin(sim: sim, tx: tx, ty: ty, reach: 4)
        let hazard = hazardAhead(sim: sim, tx: tx, ty: ty, reach: 6)
        let solidAhead = sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty))

        // Hop crates / 3-tile canal. Hold through apex so we clear water, then cut so we stay low.
        if solidAhead || gapNear || hazard {
            jumpPressed = b.onGround || b.coyote > 0
            jumpHeld = !b.onGround && b.velocity.y > 0
            moveX = 1.0
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            jumpPressed = true
            jumpHeld = true
            moveX = b.onWallRight ? -0.4 : 1
        }

        // After the death beat, do NOT stomp-farm — bounce loops stall the EXIT run.
        // Hop over same-deck MOPs; ignore elevated ones.
        if let mop = nearestMop(sim: sim) {
            let mdx = mop.position.x - b.position.x
            let mdy = mop.position.y - b.position.y
            if mdx > 0, mdx < tile * 2.8, abs(mdy) < tile * 1.0, b.onGround {
                jumpPressed = true
                jumpHeld = false // short hop over, then keep running
            } else if mdy > tile * 0.8 {
                jumpPressed = false
                jumpHeld = false
            }
            _ = mdx
        }
        pouncePressed = false

        return InputFrame(
            moveX: moveX,
            jumpPressed: jumpPressed,
            jumpHeld: jumpHeld,
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

    /// Drop from rooftops / mid ledges, then stomp-hunt street MOPs for Mask re-entry.
    private func maskReentryHuntInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let halfH = 14.0
        let streetY = sim.map.findFirst(.start).map { Double($0.1) * tile } ?? b.position.y
        let feetY = b.position.y - halfH
        let elevated = feetY > streetY + tile * 0.35
        let onOneWay = standingOnOneWay(sim: sim, halfH: halfH)

        // Prefer street-deck MOPs for the second Mask (opening pack / patrols).
        let streetMops = sim.state.mops.filter {
            $0.alive && abs($0.position.y - streetY) < tile * 2.5
        }
        let mop = streetMops.min(by: {
            $0.position.distance(to: b.position) < $1.position.distance(to: b.position)
        }) ?? nearestMop(sim: sim)

        // Still perched after the rooftop beat — drop one-ways / walk off solid ledges.
        // CI failure mode: Bandit stuck on latch-tower --- / short ==== above street MOPs.
        if elevated || onOneWay {
            var moveX: Double = 1.0
            if b.onWallRight { moveX = -1.0 }
            else if b.onWallLeft { moveX = 1.0 }
            else if let mop {
                let dx = mop.position.x - b.position.x
                // Prefer the nearer open ledge when a wall hems us in on a one-way.
                if floorSupport(sim: sim, tx: tx + 1, ty: ty) && !floorSupport(sim: sim, tx: tx - 1, ty: ty) {
                    moveX = -1.0
                } else if !floorSupport(sim: sim, tx: tx + 1, ty: ty) {
                    moveX = 1.0
                } else if dx < -tile {
                    moveX = -0.85
                }
            } else if !floorSupport(sim: sim, tx: tx + 1, ty: ty) {
                moveX = 1.0
            } else if !floorSupport(sim: sim, tx: tx - 1, ty: ty) {
                moveX = -1.0
            }

            // Against a latch wall on a one-way: hold down + nudge (no jump) so Sim dropThrough fires.
            if onOneWay, b.onGround {
                return InputFrame(moveX: moveX, moveY: -1, jumpPressed: false, jumpHeld: false)
            }
            if !b.onGround {
                return InputFrame(moveX: moveX, moveY: -1, pouncePressed: !b.flopping)
            }
            // Solid mid ledge: walk toward open air; hop only when both sides are blocked.
            let blockedBoth = floorSupport(sim: sim, tx: tx + 1, ty: ty)
                && floorSupport(sim: sim, tx: tx - 1, ty: ty)
                && (b.onWallLeft || b.onWallRight
                    || sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty))
                    || sim.map.isSolid(sim.map.tile(atX: tx - 1, y: ty)))
            if blockedBoth {
                return InputFrame(moveX: moveX, moveY: -1, jumpPressed: true, jumpHeld: true)
            }
            return InputFrame(moveX: moveX, moveY: -1, jumpPressed: false, jumpHeld: false)
        }

        guard let mop else {
            return InputFrame(moveX: 1.0)
        }
        let dx = mop.position.x - b.position.x
        var moveX: Double = dx < -8 ? -0.35 : 1.0
        var jumpPressed = false
        var jumpHeld = false
        var pouncePressed = false
        if b.onGround || b.coyote > 0 {
            if abs(dx) < tile * 5.5 { jumpPressed = true; jumpHeld = true }
        } else if b.velocity.y > 0 {
            jumpHeld = true
        } else if !b.flopping {
            pouncePressed = true
            jumpHeld = true
        }
        if tx <= 5 { moveX = max(moveX, 0.85) }
        return InputFrame(
            moveX: moveX,
            jumpPressed: jumpPressed,
            jumpHeld: jumpHeld || jumpPressed,
            pouncePressed: pouncePressed
        )
    }

    private func standingOnOneWay(sim: Sim, halfH: Double) -> Bool {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let feet = b.position.y - halfH - 1
        let tx = Int(floor(b.position.x / tile))
        let ty = Int(floor(feet / tile))
        if sim.map.tile(atX: tx, y: ty) == .oneWay { return true }
        // Foot samples near walls / tile seams.
        let tyLo = Int(floor((feet - 2) / tile))
        return sim.map.tile(atX: tx, y: tyLo) == .oneWay
            || sim.map.tile(atX: tx - 1, y: ty) == .oneWay
            || sim.map.tile(atX: tx + 1, y: ty) == .oneWay
    }

    /// True when the cell under (tx, ty-1) can be stood on (solid or one-way).
    private func floorSupport(sim: Sim, tx: Int, ty: Int) -> Bool {
        let below = sim.map.tile(atX: tx, y: ty - 1)
        return sim.map.isStandable(below)
    }

    /// Drive toward latch / one-way climb for the rooftop-route smoke still + clip.
    private func preferRoofClimbInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let streetY = sim.map.findFirst(.start).map { Double($0.1) * tile } ?? b.position.y
        // Already high enough — strafe right along the roof deck.
        if b.position.y > streetY + tile * 2.2 {
            var jumpHeld = !b.onGround && b.velocity.y > 0
            var jumpPressed = false
            if gapAhead(sim: sim, tx: tx, ty: ty) {
                jumpPressed = b.onGround || b.coyote > 0
                jumpHeld = true
            }
            return InputFrame(moveX: 1.0, jumpPressed: jumpPressed, jumpHeld: jumpHeld)
        }
        let above = sim.map.tile(atX: tx, y: ty + 1)
        let latchNear = sim.map.tile(atX: tx, y: ty) == .latch
            || sim.map.tile(atX: tx + 1, y: ty) == .latch
            || sim.map.tile(atX: tx - 1, y: ty) == .latch
            || sim.map.tile(atX: tx + 1, y: ty + 1) == .latch
        let oneWayAbove = above == .oneWay
            || sim.map.tile(atX: tx, y: ty + 2) == .oneWay
            || sim.map.tile(atX: tx + 1, y: ty + 1) == .oneWay
        var moveX: Double = 1.0
        var jumpPressed = false
        var jumpHeld = false
        if latchNear || oneWayAbove || b.onWallLeft || b.onWallRight {
            jumpPressed = b.onGround || b.coyote > 0 || b.onWallLeft || b.onWallRight || tick % 12 == 0
            jumpHeld = true
            moveX = b.onWallRight ? -0.25 : 0.75
        } else if b.onGround || b.coyote > 0 {
            // Keep hopping toward the mid-map latch tower (~x 20–40).
            jumpPressed = tick % 18 == 0 || sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty))
            jumpHeld = jumpPressed || (!b.onGround && b.velocity.y > 0)
            if tx < 22 { moveX = 1.0 }
            else if tx > 48 { moveX = -0.4 }
        } else {
            jumpHeld = b.velocity.y > 0
            if b.velocity.y < 0, !b.flopping {
                return InputFrame(moveX: 0.85, jumpHeld: true, pouncePressed: false)
            }
        }
        if tx <= 5 { moveX = max(moveX, 0.9) }
        return InputFrame(moveX: moveX, jumpPressed: jumpPressed, jumpHeld: jumpHeld || jumpPressed)
    }

    private func seekDeathInput(sim: Sim, tx: Int, ty: Int) -> InputFrame {
        let b = sim.state.bandit
        let tile = sim.tuning.tileSize
        let streetY = sim.map.findFirst(.start).map { Double($0.1) * tile } ?? b.position.y
        // Get down to the street first — walk off ledges / drop one-ways.
        if b.position.y > streetY + tile * 0.45 {
            if !b.onGround {
                // Belly-flop down if we're floating above the street.
                return InputFrame(moveX: 1, moveY: -1, pouncePressed: !b.flopping)
            }
            let edgeR = !sim.map.isSolid(sim.map.tile(atX: tx + 1, y: ty - 1))
            let edgeL = !sim.map.isSolid(sim.map.tile(atX: tx - 1, y: ty - 1))
            if edgeR { return InputFrame(moveX: 1, moveY: -1) }
            if edgeL { return InputFrame(moveX: -1, moveY: -1) }
            if b.onWallLeft || b.onWallRight {
                return InputFrame(moveX: b.onWallRight ? -1 : 1, jumpPressed: true, jumpHeld: true)
            }
            // After ~3s still perched, keep marching; after ~8s prefer left ledges too.
            let dir: Double = (seekDeathFrames % 240) < 180 ? 1 : -1
            return InputFrame(moveX: dir, moveY: -1)
        }
        // Street: run into the canal spike/water. Never jump a water/spike lip.
        let underR = sim.map.tile(atX: tx + 1, y: ty - 1)
        let ahead = sim.map.tile(atX: tx + 1, y: ty)
        let lipIsHazard = underR == .water || underR == .spike || underR == .empty
            || ahead == .water || ahead == .spike
            || sim.map.tile(atX: tx + 1, y: ty - 2) == .water
        if lipIsHazard || seekDeathFrames > 600 {
            return InputFrame(moveX: 1) // walk off / commit
        }
        if b.onWallRight || sim.map.isSolid(ahead) {
            return InputFrame(moveX: 1, jumpPressed: b.onGround || b.coyote > 0, jumpHeld: false)
        }
        if b.onWallLeft || b.onWallRight, !b.onGround {
            return InputFrame(moveX: b.onWallRight ? -1 : 1, jumpPressed: true, jumpHeld: true)
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
