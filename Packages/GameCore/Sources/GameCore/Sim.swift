// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public struct SimEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case jump, land, pounce, flop, stomp, shiny, bank, maskOn, hurt, win, fail(FailReason), checkpoint, dust, shake
    }
    public var kind: Kind
    public var position: Vec2
}

public struct SimState: Equatable, Sendable {
    public var tick: Int
    public var elapsed: Double
    public var bandit: BanditState
    public var shinies: [ShinyPickup]
    public var mops: [MopEnemy]
    public var checkpoints: [Checkpoint]
    public var spawn: Vec2
    public var phase: RunPhase
    public var controlVariant: ControlVariant
    public var events: [SimEvent]
    public var bestCombo: Int

    public var stateHash: UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        func mix(_ v: UInt64) { h ^= v; h &*= 0x100000001b3 }
        func mixD(_ d: Double) { mix(d.bitPattern) }
        mix(UInt64(tick))
        mixD(bandit.position.x); mixD(bandit.position.y)
        mixD(bandit.velocity.x); mixD(bandit.velocity.y)
        mix(UInt64(bandit.combo)); mix(UInt64(bandit.carriedShinies)); mix(UInt64(bandit.bankedShinies))
        mix(UInt64(bandit.hearts)); mix(bandit.maskMode ? 1 : 0)
        for s in shinies { mix(UInt64(s.id)); mix(s.alive ? 1 : 0) }
        for m in mops { mix(UInt64(m.id)); mix(m.alive ? 1 : 0); mixD(m.position.x) }
        switch phase {
        case .title: mix(0)
        case .playing: mix(1)
        case .won: mix(2)
        case .failed(let r):
            mix(3)
            mix(r == .fellInWater ? 1 : (r == .spiked ? 2 : 3))
        }
        return h
    }
}

public struct Sim: Equatable, Sendable {
    public var tuning: Tuning
    public var map: TileMap
    public var state: SimState
    public var seed: UInt64

    private let halfW: Double = 10
    private let halfH: Double = 14

    public init(map: TileMap, tuning: Tuning = .default, seed: UInt64 = 1, variant: ControlVariant = .a) {
        self.tuning = tuning
        self.map = map
        self.seed = seed
        let tile = tuning.tileSize
        let start = map.findFirst(.start).map { map.worldCenter(ofX: $0.0, y: $0.1, tileSize: tile) }
            ?? Vec2(tile * 2, tile * 3)

        var shinies: [ShinyPickup] = []
        for (i, c) in map.findAll(.shinySpawn).enumerated() {
            shinies.append(ShinyPickup(id: i, position: map.worldCenter(ofX: c.0, y: c.1, tileSize: tile), alive: true))
        }
        var cps: [Checkpoint] = []
        for (i, c) in map.findAll(.checkpoint).enumerated() {
            cps.append(Checkpoint(id: i, position: map.worldCenter(ofX: c.0, y: c.1, tileSize: tile), activated: false))
        }
        var mops: [MopEnemy] = []
        var mopID = 0
        for (i, c) in map.findAll(.mopSpawn).enumerated() {
            let p = map.worldStandOnDeckBelow(ofX: c.0, markerY: c.1, tileSize: tile)
            // Keep a 4-tile clear zone around spawn / checkpoints so knockback doesn't feed a mob pile-up.
            if abs(p.x - start.x) < tile * 4 { continue }
            if cps.contains(where: { abs(p.x - $0.position.x) < tile * 4 }) { continue }
            // Opening pack: tiny patrol so hop-stomps chain into Mask without side-bags.
            let span = tile * (mopID < 6 ? 0.35 : 2.2)
            mops.append(MopEnemy(
                id: mopID, position: p, home: p, patrolSpan: span, phase: Double(i) * 0.85,
                alive: true, respawn: 0, anim: .walk, animHold: 0, facing: 1, stun: 0
            ))
            mopID += 1
        }

        self.state = SimState(
            tick: 0,
            elapsed: 0,
            bandit: .spawn(at: start, hearts: tuning.hearts),
            shinies: shinies,
            mops: mops,
            checkpoints: cps,
            spawn: start,
            phase: .title,
            controlVariant: variant,
            events: [],
            bestCombo: 0
        )
    }

    public mutating func startRun() {
        guard case .title = state.phase else { return }
        state.phase = .playing
    }

    public mutating func retry() {
        let variant = state.controlVariant
        let map = self.map
        let tuning = self.tuning
        let seed = self.seed &+ 1
        self = Sim(map: map, tuning: tuning, seed: seed, variant: variant)
        state.phase = .playing
    }

    public mutating func step(_ input: InputFrame) {
        state.events.removeAll(keepingCapacity: true)
        guard case .playing = state.phase else {
            state.tick += 1
            return
        }

        let dt = tuning.dt
        state.elapsed += dt
        var b = state.bandit

        if input.jumpPressed { b.jumpBuffer = tuning.jumpBufferSeconds }
        else if b.jumpBuffer > 0 { b.jumpBuffer = max(0, b.jumpBuffer - dt) }

        if b.invuln > 0 { b.invuln = max(0, b.invuln - dt) }
        if b.landCooldown > 0 { b.landCooldown = max(0, b.landCooldown - dt) }
        if b.animHold > 0 {
            b.animHold = max(0, b.animHold - dt)
            if b.animHold <= 0, b.anim == .hurt || b.anim == .pickUp {
                b.anim = .idle
            }
        }

        // Airborne before integrate/collide — walking must not look like a stomp
        // just because gravity briefly pulls vy negative on solid ground.
        let wasAirborne = !b.onGround || b.flopping
        integrate(input: input, bandit: &b, dt: dt)
        // Snapshot fall intent before collide zeroes vy on landing — tight stomp
        // hitboxes still connect on the contact frame.
        let fallSpeed = -b.velocity.y / max(tuning.tileSize, 1)
        let stompFalling = b.flopping
            || (wasAirborne && b.velocity.y < 0 && fallSpeed >= tuning.stompMinFallSpeed)
        collide(bandit: &b)
        updateAnim(bandit: &b)
        collectShinies(bandit: &b)
        updateCheckpoints(bandit: &b)
        bankAndExit(bandit: &b)
        updateMops(bandit: &b, dt: dt, stompFalling: stompFalling)
        updateCombo(bandit: &b, dt: dt)
        hazards(bandit: &b)

        state.bandit = b
        state.bestCombo = max(state.bestCombo, b.combo)
        state.tick += 1
    }

    // MARK: - Physics

    private mutating func integrate(input: InputFrame, bandit: inout BanditState, dt: Double) {
        let move = max(-1, min(1, input.moveX))
        if abs(move) > 0.05 { bandit.facing = move >= 0 ? 1 : -1 }

        let accel = bandit.onGround ? tuning.accelGround : tuning.accelAir
        // Slight stick = walk, full stick = run (placement-insensitive virtual stick).
        let mag = abs(move)
        let walkPx = tuning.walkSpeed * tuning.tileSize
        let runPx = tuning.runSpeed * tuning.tileSize
        let thresh = max(0.15, min(0.9, tuning.walkRunStickThreshold))
        let speedPx: Double
        if mag <= 0.05 {
            speedPx = 0
        } else if mag < thresh {
            speedPx = walkPx * (mag / thresh)
        } else {
            let u = (mag - thresh) / max(0.05, 1 - thresh)
            speedPx = walkPx + (runPx - walkPx) * min(1, u)
        }
        let targetVx = (move >= 0 ? 1.0 : -1.0) * speedPx
        if mag > 0.05 {
            if bandit.velocity.x < targetVx {
                bandit.velocity.x = min(targetVx, bandit.velocity.x + accel * tuning.tileSize * dt)
            } else if bandit.velocity.x > targetVx {
                bandit.velocity.x = max(targetVx, bandit.velocity.x - accel * tuning.tileSize * dt)
            }
        } else if bandit.onGround {
            let fr = tuning.frictionGround * tuning.tileSize * dt
            if bandit.velocity.x > 0 { bandit.velocity.x = max(0, bandit.velocity.x - fr) }
            else { bandit.velocity.x = min(0, bandit.velocity.x + fr) }
        }

        // Jump
        let canCoyote = bandit.coyote > 0
        let canWall = (bandit.onWallLeft || bandit.onWallRight) && !bandit.onGround
        if bandit.jumpBuffer > 0 && (bandit.onGround || canCoyote || canWall) {
            if canWall && !bandit.onGround {
                let dir: Double = bandit.onWallLeft ? 1 : -1
                bandit.velocity.x = dir * tuning.wallJumpVelocityX * tuning.tileSize / 2.2
                bandit.velocity.y = tuning.wallJumpVelocityY * tuning.tileSize / 2.2
                bandit.facing = dir
                bandit.wallCling = 0
            } else {
                bandit.velocity.y = tuning.jumpVelocity * tuning.tileSize / 2.2
            }
            bandit.onGround = false
            bandit.coyote = 0
            bandit.jumpBuffer = 0
            bandit.pouncing = false
            bandit.flopping = false
            state.events.append(SimEvent(kind: .jump, position: bandit.position))
            state.events.append(SimEvent(kind: .dust, position: bandit.position))
        }

        // Variable jump + snappy fall: hold softens ascent; release cuts; falling uses fallGravity.
        let scale = tuning.tileSize / 2.2
        var g = tuning.gravity * scale
        if bandit.velocity.y > 0 {
            if input.jumpHeld {
                g = tuning.gravity * scale * (1.0 - tuning.variableJumpHoldBoost * 0.4)
            } else {
                g = tuning.jumpCutGravity * scale
            }
        } else if bandit.velocity.y < 0 {
            g = tuning.fallGravity * scale
        }

        // Pounce (forward boost) / Belly Flop (fast fall) while airborne.
        // Only arm once per aerial — re-pressing must not keep boosting or we soft-float.
        if input.pouncePressed && !bandit.onGround && !bandit.pouncing && !bandit.flopping {
            bandit.pouncing = true
            bandit.velocity.x += bandit.facing * tuning.pounceBoostX * tuning.tileSize / 2
            bandit.velocity.y += tuning.pounceBoostY * tuning.tileSize / 3
            state.events.append(SimEvent(kind: .pounce, position: bandit.position))
            state.events.append(SimEvent(kind: .shake, position: bandit.position))
            if bandit.velocity.y < 2 {
                bandit.flopping = true
                bandit.velocity.y = -tuning.bellyFlopFallBoost * tuning.tileSize / 2.5
                state.events.append(SimEvent(kind: .flop, position: bandit.position))
            }
        } else if input.pouncePressed && !bandit.onGround && bandit.pouncing && !bandit.flopping && bandit.velocity.y < 2 {
            bandit.flopping = true
            bandit.velocity.y = -tuning.bellyFlopFallBoost * tuning.tileSize / 2.5
            state.events.append(SimEvent(kind: .flop, position: bandit.position))
        }

        // Wall slide
        if !bandit.onGround && (bandit.onWallLeft || bandit.onWallRight) && bandit.velocity.y < 0 {
            let slide = -tuning.wallSlideSpeed * tuning.tileSize / 2
            if bandit.velocity.y < slide { bandit.velocity.y = slide }
            bandit.wallCling = tuning.wallClingSeconds
        } else if bandit.wallCling > 0 {
            bandit.wallCling = max(0, bandit.wallCling - dt)
        }

        bandit.velocity.y -= g * dt
        let maxFall = -tuning.maxFall * tuning.tileSize / 2.2
        if bandit.velocity.y < maxFall { bandit.velocity.y = maxFall }

        bandit.position.x += bandit.velocity.x * dt
        bandit.position.y += bandit.velocity.y * dt

        if bandit.onGround {
            bandit.coyote = tuning.coyoteSeconds
        } else if bandit.coyote > 0 {
            bandit.coyote = max(0, bandit.coyote - dt)
        }
    }

    private mutating func collide(bandit: inout BanditState) {
        let tile = tuning.tileSize
        // Capture before the probe reset — otherwise every grounded step looks like a landing.
        let wasGrounded = bandit.onGround
        bandit.onGround = false
        bandit.onWallLeft = false
        bandit.onWallRight = false

        // Sample corners + mid edges
        func solidAt(_ wx: Double, _ wy: Double) -> Bool {
            let tx = Int(floor(wx / tile))
            let ty = Int(floor(wy / tile))
            return map.isSolid(map.tile(atX: tx, y: ty))
        }

        // Horizontal
        if bandit.velocity.x > 0 {
            let right = bandit.position.x + halfW
            if solidAt(right, bandit.position.y + halfH * 0.6) || solidAt(right, bandit.position.y - halfH * 0.6) {
                let tx = Int(floor(right / tile))
                bandit.position.x = Double(tx) * tile - halfW - 0.01
                bandit.velocity.x = 0
                bandit.onWallRight = true
            }
        } else if bandit.velocity.x < 0 {
            let left = bandit.position.x - halfW
            if solidAt(left, bandit.position.y + halfH * 0.6) || solidAt(left, bandit.position.y - halfH * 0.6) {
                let tx = Int(floor(left / tile))
                bandit.position.x = Double(tx + 1) * tile + halfW + 0.01
                bandit.velocity.x = 0
                bandit.onWallLeft = true
            }
        }

        // Vertical
        if bandit.velocity.y <= 0 {
            let feet = bandit.position.y - halfH
            if solidAt(bandit.position.x - halfW * 0.6, feet) || solidAt(bandit.position.x + halfW * 0.6, feet) {
                let ty = Int(floor(feet / tile))
                bandit.position.y = Double(ty + 1) * tile + halfH
                // Fire land/dust only on the air → ground transition, with a short cooldown
                // so pounce whoosh → land → land (20–67 ms) collapses to one event.
                if !wasGrounded, bandit.landCooldown <= 0 {
                    state.events.append(SimEvent(kind: .land, position: bandit.position))
                    state.events.append(SimEvent(kind: .dust, position: bandit.position))
                    if bandit.velocity.y < -40 {
                        state.events.append(SimEvent(kind: .shake, position: bandit.position))
                    }
                    bandit.landCooldown = 0.10
                }
                bandit.velocity.y = 0
                bandit.onGround = true
                bandit.pouncing = false
                bandit.flopping = false
            }
        } else {
            let head = bandit.position.y + halfH
            if solidAt(bandit.position.x - halfW * 0.5, head) || solidAt(bandit.position.x + halfW * 0.5, head) {
                let ty = Int(floor(head / tile))
                bandit.position.y = Double(ty) * tile - halfH - 0.01
                bandit.velocity.y = 0
            }
        }

        // Wall probes when falling beside walls
        if !bandit.onGround {
            if solidAt(bandit.position.x + halfW + 2, bandit.position.y) { bandit.onWallRight = true }
            if solidAt(bandit.position.x - halfW - 2, bandit.position.y) { bandit.onWallLeft = true }
        }

        // Clamp to map
        let minX = halfW, maxX = Double(map.width) * tile - halfW
        let minY = halfH
        bandit.position.x = min(max(bandit.position.x, minX), maxX)
        if bandit.position.y < minY - tile * 2 {
            fail(.fellInWater, at: bandit.position)
        }
    }

    private func updateAnim(bandit: inout BanditState) {
        // Hurt / death / pick-up are sticky until animHold expires.
        if bandit.animHold > 0 { return }
        if bandit.onGround {
            let speed = abs(bandit.velocity.x)
            let walkPx = tuning.walkSpeed * tuning.tileSize
            if speed <= 20 {
                bandit.anim = .idle
            } else if speed < walkPx * 0.85 {
                bandit.anim = .walk
            } else {
                bandit.anim = .run
            }
        } else if bandit.onWallLeft || bandit.onWallRight {
            bandit.anim = .wallSlide
        } else if bandit.pouncing || bandit.flopping {
            bandit.anim = .pounce
        } else if bandit.velocity.y > 60 {
            bandit.anim = .jump
        } else if bandit.velocity.y > -50 {
            bandit.anim = .apex
        } else {
            bandit.anim = .fall
        }
    }

    private mutating func collectShinies(bandit: inout BanditState) {
        let r = tuning.tileSize * 0.6
        for i in state.shinies.indices where state.shinies[i].alive {
            if state.shinies[i].position.distance(to: bandit.position) <= r {
                state.shinies[i].alive = false
                let gain = bandit.maskMode ? 2 : 1
                bandit.carriedShinies += gain
                bandit.anim = .pickUp
                bandit.animHold = 0.35
                state.events.append(SimEvent(kind: .shiny, position: state.shinies[i].position))
            }
        }
    }

    private mutating func updateCheckpoints(bandit: inout BanditState) {
        for i in state.checkpoints.indices where !state.checkpoints[i].activated {
            if state.checkpoints[i].position.distance(to: bandit.position) < tuning.tileSize {
                state.checkpoints[i].activated = true
                state.spawn = state.checkpoints[i].position
                state.events.append(SimEvent(kind: .checkpoint, position: state.checkpoints[i].position))
            }
        }
    }

    private mutating func bankAndExit(bandit: inout BanditState) {
        let tile = tuning.tileSize
        let tx = Int(floor(bandit.position.x / tile))
        let ty = Int(floor(bandit.position.y / tile))
        let t = map.tile(atX: tx, y: ty)
        if t == .stash, bandit.carriedShinies > 0, bandit.onGround {
            bandit.bankedShinies += bandit.carriedShinies
            bandit.carriedShinies = 0
            state.events.append(SimEvent(kind: .bank, position: bandit.position))
        }
        if t == .exit || (t == .stash && bandit.bankedShinies + bandit.carriedShinies >= 0 && nearExit(bandit)) {
            // Win when reaching exit tile
            if t == .exit {
                let total = bandit.bankedShinies + bandit.carriedShinies
                bandit.bankedShinies = total
                bandit.carriedShinies = 0
                state.phase = .won(seconds: state.elapsed, shinies: bandit.bankedShinies, combo: state.bestCombo)
                state.events.append(SimEvent(kind: .win, position: bandit.position))
            }
        }
    }

    private func nearExit(_ bandit: BanditState) -> Bool {
        guard let e = map.findFirst(.exit) else { return false }
        let p = map.worldCenter(ofX: e.0, y: e.1, tileSize: tuning.tileSize)
        return p.distance(to: bandit.position) < tuning.tileSize * 1.2
    }

    private mutating func updateMops(bandit: inout BanditState, dt: Double, stompFalling: Bool) {
        for i in state.mops.indices {
            if !state.mops[i].alive {
                state.mops[i].respawn -= dt
                if state.mops[i].respawn <= 0 {
                    state.mops[i].alive = true
                    state.mops[i].position = state.mops[i].home
                }
                continue
            }
            if state.mops[i].animHold > 0 {
                state.mops[i].animHold = max(0, state.mops[i].animHold - dt)
            }
            if state.mops[i].stun > 0 {
                state.mops[i].stun = max(0, state.mops[i].stun - dt)
            }
            if state.mops[i].stun <= 0 {
                let prevX = state.mops[i].position.x
                state.mops[i].phase += dt
                let ox = sin(state.mops[i].phase) * state.mops[i].patrolSpan
                state.mops[i].position.x = state.mops[i].home.x + ox
                state.mops[i].position.y = state.mops[i].home.y
                let dx = state.mops[i].position.x - prevX
                if abs(dx) > 0.01 { state.mops[i].facing = dx >= 0 ? 1 : -1 }
            } else {
                state.mops[i].position.y = state.mops[i].home.y
            }
            if state.mops[i].animHold <= 0 {
                state.mops[i].anim = .walk
            }

            let d = state.mops[i].position.distance(to: bandit.position)
            // Stomp on contact: use pre-collide fall intent so landing frames still connect.
            let aboveMop = bandit.position.y >= state.mops[i].position.y + halfH * 0.25
            if stompFalling
                && d <= tuning.stompHitRadius
                && aboveMop
            {
                state.mops[i].alive = false
                state.mops[i].respawn = 3.5
                state.mops[i].anim = .death
                state.mops[i].animHold = 0.8
                bandit.velocity.y = tuning.stompBounceVelocity * tuning.tileSize / 2.2
                bandit.flopping = false
                // I-frames through the bounce so chains don't side-bag the next MOP.
                bandit.invuln = max(bandit.invuln, 0.55)
                bandit.combo = min(tuning.comboCap, bandit.combo + 1)
                bandit.comboTimer = tuning.comboGroundGrace
                if bandit.combo >= tuning.maskModeAtCombo && !bandit.maskMode {
                    bandit.maskMode = true
                    bandit.maskTimer = tuning.maskDuration
                    state.events.append(SimEvent(kind: .maskOn, position: bandit.position))
                } else if bandit.maskMode {
                    // Refresh Mask window on continued stomps.
                    bandit.maskTimer = max(bandit.maskTimer, tuning.maskDuration * 0.55)
                }
                state.events.append(SimEvent(kind: .stomp, position: state.mops[i].position))
                state.events.append(SimEvent(kind: .shake, position: state.mops[i].position))
                continue
            }
            // Hurt on tight contact; suppress only during a real falling stomp window.
            if d <= tuning.hurtHitRadius && bandit.invuln <= 0 && !(stompFalling && aboveMop) {
                bandit.hearts -= 1
                bandit.invuln = tuning.invulnSeconds
                var away = bandit.position.x >= state.mops[i].position.x ? 1.0 : -1.0
                let tile = tuning.tileSize
                let minSafe = tile * 5
                let maxSafe = Double(map.width) * tile - tile * 5
                var nx = bandit.position.x + away * tile * 1.2
                // Never knock into the map lip — that pinned him in the camera clamp / mob pile.
                if nx < minSafe {
                    away = 1
                    nx = minSafe
                } else if nx > maxSafe {
                    away = -1
                    nx = maxSafe
                }
                bandit.position.x = nx
                bandit.velocity.y = tuning.jumpVelocity * tile / 3
                bandit.velocity.x = away * tuning.runSpeed * tile * 0.85
                state.mops[i].position.x -= away * tile * 0.5
                state.mops[i].home.x = state.mops[i].position.x
                state.mops[i].stun = 0.5
                bandit.anim = .hurt
                bandit.animHold = 0.35
                state.mops[i].anim = .attack
                state.mops[i].animHold = 0.5
                state.events.append(SimEvent(kind: .hurt, position: bandit.position))
                if bandit.hearts <= 0 {
                    bandit.anim = .death
                    bandit.animHold = 1.35
                    bandit.invuln = 0
                    fail(.bagged, at: bandit.position)
                }
            }
        }
    }

    private mutating func updateCombo(bandit: inout BanditState, dt: Double) {
        if bandit.combo > 0 {
            bandit.comboTimer -= dt
            if bandit.comboTimer <= 0 {
                bandit.combo = 0
            }
        }
        if bandit.maskMode {
            bandit.maskTimer = max(0, bandit.maskTimer - dt)
            if bandit.maskTimer <= 0 {
                bandit.maskMode = false
            }
        }
    }

    private mutating func hazards(bandit: inout BanditState) {
        let tile = tuning.tileSize
        let tx = Int(floor(bandit.position.x / tile))
        let ty = Int(floor((bandit.position.y - halfH * 0.8) / tile))
        let t = map.tile(atX: tx, y: ty)
        if t == .water {
            fail(.fellInWater, at: bandit.position)
        } else if t == .spike && bandit.invuln <= 0 {
            fail(.spiked, at: bandit.position)
        }
    }

    private mutating func fail(_ reason: FailReason, at pos: Vec2) {
        guard case .playing = state.phase else { return }
        state.bandit.anim = .death
        state.bandit.animHold = 1.35
        state.bandit.invuln = 0
        state.phase = .failed(reason)
        state.events.append(SimEvent(kind: .fail(reason), position: pos))
    }
}

public struct ReplayRecorder: Equatable, Sendable {
    public var inputs: [InputFrame] = []
    public init() {}
    public mutating func record(_ input: InputFrame) { inputs.append(input) }
}

public enum ReplayPlayer {
    public static func play(map: TileMap, tuning: Tuning, seed: UInt64, inputs: [InputFrame], variant: ControlVariant = .a) -> SimState {
        var sim = Sim(map: map, tuning: tuning, seed: seed, variant: variant)
        sim.state.phase = .playing
        for input in inputs { sim.step(input) }
        return sim.state
    }
}
