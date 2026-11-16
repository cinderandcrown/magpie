// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public struct SimEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case jump, land, pounce, flop, stomp, shiny, bank, maskOn, hurt, win, fail(FailReason), checkpoint, dust, shake
        case crewFreed(crewID: String)
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
    public var crewCages: [CrewCage]
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
        var cages: [CrewCage] = []
        let crewIDs = ["scrapz", "glitch", "fizz", "pip"]
        for (i, c) in map.findAll(.crewCage).enumerated() {
            cages.append(CrewCage(
                id: i,
                position: map.worldCenter(ofX: c.0, y: c.1, tileSize: tile),
                freed: false,
                crewID: crewIDs[i % crewIDs.count]
            ))
        }
        var mops: [MopEnemy] = []
        var mopID = 0
        for (i, c) in map.findAll(.mopSpawn).enumerated() {
            let p = map.worldStandOnDeckBelow(ofX: c.0, markerY: c.1, tileSize: tile)
            // Keep a 4-tile clear zone around spawn / checkpoints so knockback doesn't feed a mob pile-up.
            if abs(p.x - start.x) < tile * 4 { continue }
            if cps.contains(where: { abs(p.x - $0.position.x) < tile * 4 }) { continue }
            // Opening pack: tiny patrol so hop-stomps chain into Mask without side-bags.
            let span = tile * (mopID < 8 ? 0.25 : 2.2)
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
            crewCages: cages,
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
        // Chain armor: active combo keeps light i-frames so a just-respawned MOP
        // can't side-bag the run before the next hop (Nick feel pass).
        if b.combo > 0, b.comboTimer > 0 {
            b.invuln = max(b.invuln, b.onGround ? 0.2 : 0.15)
        }
        if b.landCooldown > 0 { b.landCooldown = max(0, b.landCooldown - dt) }
        if b.dropThrough > 0 { b.dropThrough = max(0, b.dropThrough - dt) }
        if b.animHold > 0 {
            b.animHold = max(0, b.animHold - dt)
            if b.animHold <= 0, b.anim == .hurt || b.anim == .pickUp {
                b.anim = .idle
            }
        }

        // Drop through one-ways: hold down on a one-way deck.
        if b.onGround, input.moveY < -0.45 {
            let tile = tuning.tileSize
            let feet = b.position.y - halfH - 1
            let tx = Int(floor(b.position.x / tile))
            let ty = Int(floor(feet / tile))
            if map.tile(atX: tx, y: ty) == .oneWay {
                b.dropThrough = 0.22
                b.onGround = false
            }
        }

        // Airborne before integrate/collide — walking must not look like a stomp
        // just because gravity briefly pulls vy negative on solid ground.
        let wasAirborne = !b.onGround || b.flopping
        integrate(input: input, bandit: &b, dt: dt)
        // Stomp window: falling, OR within a few frames of apex (Nick feel pass).
        let feel = tuning.feel
        let apexSpeed = feel.apexHangSpeed * tuning.tileSize / 2.2
        if wasAirborne, abs(b.velocity.y) <= apexSpeed {
            b.apexStompFrames = max(b.apexStompFrames, feel.stompApexFrames)
        } else if b.apexStompFrames > 0 {
            b.apexStompFrames -= 1
        }
        if b.onGround { b.apexStompFrames = 0 }
        let stompFalling = b.flopping
            || (wasAirborne && (b.velocity.y < 0 || b.apexStompFrames > 0))
        collide(bandit: &b)
        updateAnim(bandit: &b)
        collectShinies(bandit: &b)
        collectCrew(bandit: &b)
        updateCheckpoints(bandit: &b)
        bankAndExit(bandit: &b)
        updateMops(bandit: &b, dt: dt, stompFalling: stompFalling, jumpHeld: input.jumpHeld)
        updateCombo(bandit: &b, dt: dt)
        hazards(bandit: &b)

        state.bandit = b
        state.bestCombo = max(state.bestCombo, b.combo)
        state.tick += 1
    }

    // MARK: - Physics

    private mutating func integrate(input: InputFrame, bandit: inout BanditState, dt: Double) {
        let feel = tuning.feel
        let move = max(-1, min(1, input.moveX))
        if abs(move) > feel.stickDeadZone { bandit.facing = move >= 0 ? 1 : -1 }

        // Accel from time-to-speed: reach runPx in groundAccelTime; stop in groundStopTime.
        let walkPx = feel.walkSpeed * tuning.tileSize
        let runPx = feel.runSpeed * tuning.tileSize
        let groundAccel = runPx / max(0.04, feel.groundAccelTime)
        let groundDecel = runPx / max(0.04, feel.groundStopTime)
        let accelBase = bandit.onGround ? groundAccel : groundAccel * feel.airControlMul
        let mag = abs(move)
        let thresh = max(feel.stickDeadZone + 0.01, min(0.9, feel.walkRunStickThreshold))
        let speedPx: Double
        if mag <= feel.stickDeadZone {
            speedPx = 0
        } else if mag < thresh {
            let t = (mag - feel.stickDeadZone) / max(0.05, thresh - feel.stickDeadZone)
            speedPx = walkPx * min(1, t)
        } else {
            let u = (mag - thresh) / max(0.05, 1 - thresh)
            speedPx = walkPx + (runPx - walkPx) * min(1, u)
        }
        let targetVx = (move >= 0 ? 1.0 : -1.0) * speedPx
        if mag > feel.stickDeadZone {
            let reversing = bandit.velocity.x * targetVx < 0
            let accel = accelBase * (reversing ? feel.turnAccelMul : 1)
            if bandit.velocity.x < targetVx {
                bandit.velocity.x = min(targetVx, bandit.velocity.x + accel * dt)
            } else if bandit.velocity.x > targetVx {
                bandit.velocity.x = max(targetVx, bandit.velocity.x - accel * dt)
            }
        } else if bandit.onGround {
            let fr = groundDecel * dt
            if bandit.velocity.x > 0 { bandit.velocity.x = max(0, bandit.velocity.x - fr) }
            else { bandit.velocity.x = min(0, bandit.velocity.x + fr) }
        }

        // Jump
        let canCoyote = bandit.coyote > 0
        let canWall = (bandit.onWallLeft || bandit.onWallRight) && !bandit.onGround
        if bandit.jumpBuffer > 0 && (bandit.onGround || canCoyote || canWall) {
            if canWall && !bandit.onGround {
                let dir: Double = bandit.onWallLeft ? 1 : -1
                bandit.velocity.x = dir * feel.wallJumpVelocityX * tuning.tileSize / 2.2
                bandit.velocity.y = feel.wallJumpVelocityY * tuning.tileSize / 2.2
                bandit.facing = dir
                bandit.wallCling = 0
            } else {
                bandit.velocity.y = feel.jumpVelocity * tuning.tileSize / 2.2
            }
            bandit.onGround = false
            bandit.coyote = 0
            bandit.jumpBuffer = 0
            bandit.pouncing = false
            bandit.flopping = false
            bandit.jumpCutArmed = true
            state.events.append(SimEvent(kind: .jump, position: bandit.position))
            state.events.append(SimEvent(kind: .dust, position: bandit.position))
        }

        // Variable jump: early release cuts upward velocity once by jumpCutFraction.
        if bandit.jumpCutArmed, !input.jumpHeld, bandit.velocity.y > 0 {
            bandit.velocity.y *= feel.jumpCutFraction
            bandit.jumpCutArmed = false
        }

        // Asymmetric gravity: rise → fall×1.8, apex hang when |vy| is small.
        let scale = tuning.tileSize / 2.2
        let riseG = feel.gravity * scale
        let fallG = feel.gravity * feel.fallGravityMul * scale
        let apexSpeed = feel.apexHangSpeed * scale
        let g: Double
        if abs(bandit.velocity.y) <= apexSpeed, !bandit.onGround {
            g = riseG * feel.apexHangMul
        } else if bandit.velocity.y > 0 {
            g = riseG
        } else {
            g = fallG
        }

        // Pounce (forward boost) / Belly Flop (fast fall) while airborne.
        // Only arm once per aerial — re-pressing must not keep boosting or we soft-float.
        if input.pouncePressed && !bandit.onGround && !bandit.pouncing && !bandit.flopping {
            bandit.pouncing = true
            bandit.velocity.x += bandit.facing * feel.pounceBoostX * tuning.tileSize / 2
            bandit.velocity.y += feel.pounceBoostY * tuning.tileSize / 3
            applyPounceMagnet(bandit: &bandit)
            state.events.append(SimEvent(kind: .pounce, position: bandit.position))
            state.events.append(SimEvent(kind: .shake, position: bandit.position))
            if bandit.velocity.y < 2 {
                bandit.flopping = true
                bandit.velocity.y = -feel.bellyFlopFallBoost * tuning.tileSize / 2.5
                state.events.append(SimEvent(kind: .flop, position: bandit.position))
            }
        } else if input.pouncePressed && !bandit.onGround && bandit.pouncing && !bandit.flopping && bandit.velocity.y < 2 {
            bandit.flopping = true
            bandit.velocity.y = -feel.bellyFlopFallBoost * tuning.tileSize / 2.5
            state.events.append(SimEvent(kind: .flop, position: bandit.position))
        } else if bandit.pouncing || bandit.flopping {
            applyPounceMagnet(bandit: &bandit)
        }

        // Wall slide
        if !bandit.onGround && (bandit.onWallLeft || bandit.onWallRight) && bandit.velocity.y < 0 {
            let slide = -feel.wallSlideSpeed * tuning.tileSize / 2
            if bandit.velocity.y < slide { bandit.velocity.y = slide }
            bandit.wallCling = feel.wallClingSeconds
        } else if bandit.wallCling > 0 {
            bandit.wallCling = max(0, bandit.wallCling - dt)
        }

        bandit.velocity.y -= g * dt
        let maxFall = -feel.maxFall * tuning.tileSize / 2.2
        if bandit.velocity.y < maxFall { bandit.velocity.y = maxFall }

        bandit.position.x += bandit.velocity.x * dt
        bandit.position.y += bandit.velocity.y * dt

        if bandit.onGround {
            bandit.coyote = feel.coyoteSeconds
            bandit.jumpCutArmed = false
        } else if bandit.coyote > 0 {
            bandit.coyote = max(0, bandit.coyote - dt)
        }
    }

    /// Soft homing toward the nearest MOP within ~2 tiles ahead and below while pouncing.
    private mutating func applyPounceMagnet(bandit: inout BanditState) {
        let feel = tuning.feel
        let reach = feel.pounceMagnetTiles * tuning.tileSize
        var best: (idx: Int, dist: Double)?
        for (i, mop) in state.mops.enumerated() where mop.alive {
            let dx = mop.position.x - bandit.position.x
            let dy = mop.position.y - bandit.position.y
            // Ahead (facing) and at/below the bandit.
            if dx * bandit.facing < 0 { continue }
            if dy > halfH { continue }
            let d = hypot(dx, dy)
            if d > reach { continue }
            if best == nil || d < best!.dist { best = (i, d) }
        }
        guard let best else { return }
        let mop = state.mops[best.idx]
        let dx = mop.position.x - bandit.position.x
        let dy = mop.position.y - bandit.position.y
        let d = max(1, hypot(dx, dy))
        let pull = feel.pounceMagnetAccel * tuning.tileSize * tuning.dt
        bandit.velocity.x += (dx / d) * pull
        bandit.velocity.y += (dy / d) * pull * 0.65
    }

    private mutating func collide(bandit: inout BanditState) {
        let tile = tuning.tileSize
        // Capture before the probe reset — otherwise every grounded step looks like a landing.
        let wasGrounded = bandit.onGround
        bandit.onGround = false
        bandit.onWallLeft = false
        bandit.onWallRight = false

        // Full solids block sides / head. One-ways only block feet when falling (and not dropping).
        func solidAt(_ wx: Double, _ wy: Double) -> Bool {
            let tx = Int(floor(wx / tile))
            let ty = Int(floor(wy / tile))
            return map.isSolid(map.tile(atX: tx, y: ty))
        }
        func landableAt(_ wx: Double, _ wy: Double) -> Bool {
            let tx = Int(floor(wx / tile))
            let ty = Int(floor(wy / tile))
            let kind = map.tile(atX: tx, y: ty)
            if map.isSolid(kind) { return true }
            if kind == .oneWay {
                if bandit.dropThrough > 0 { return false }
                // Only when approaching from above the platform top.
                let top = Double(ty + 1) * tile
                return bandit.velocity.y <= 0 && (bandit.position.y - halfH) <= top + 2
            }
            return false
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
        let corner = tuning.feel.cornerCorrectPx
        if bandit.velocity.y <= 0 {
            let feet = bandit.position.y - halfH
            let footL = landableAt(bandit.position.x - halfW * 0.6, feet)
            let footR = landableAt(bandit.position.x + halfW * 0.6, feet)
            if footL || footR {
                // Near-miss landing: only one foot catches a ledge — nudge onto the solid.
                if footL != footR, corner > 0 {
                    let dir: Double = footR ? 1 : -1
                    for step in stride(from: 1.0, through: corner, by: 1.0) {
                        let nx = bandit.position.x + dir * step
                        if landableAt(nx - halfW * 0.6, feet), landableAt(nx + halfW * 0.6, feet) {
                            bandit.position.x = nx
                            break
                        }
                    }
                }
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
                bandit.jumpCutArmed = false
                // Landing during a combo keeps brief i-frames so the next hop isn't a side-bag.
                if bandit.combo > 0, bandit.comboTimer > 0 {
                    bandit.invuln = max(bandit.invuln, 0.45)
                }
            }
        } else {
            let head = bandit.position.y + halfH
            let headHit = solidAt(bandit.position.x - halfW * 0.5, head) || solidAt(bandit.position.x + halfW * 0.5, head)
            if headHit {
                // Corner correction: nudge sideways up to cornerCorrectPx to slip past a ledge lip.
                var cleared = false
                if corner > 0 {
                    for step in stride(from: 1.0, through: corner, by: 1.0) {
                        for dir: Double in [1, -1] {
                            let nx = bandit.position.x + dir * step
                            if !solidAt(nx - halfW * 0.5, head), !solidAt(nx + halfW * 0.5, head) {
                                bandit.position.x = nx
                                cleared = true
                                break
                            }
                        }
                        if cleared { break }
                    }
                }
                if !cleared {
                    let ty = Int(floor(head / tile))
                    bandit.position.y = Double(ty) * tile - halfH - 0.01
                    bandit.velocity.y = 0
                }
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

    private mutating func collectCrew(bandit: inout BanditState) {
        let r = tuning.tileSize * 0.85
        for i in state.crewCages.indices where !state.crewCages[i].freed {
            if state.crewCages[i].position.distance(to: bandit.position) <= r {
                state.crewCages[i].freed = true
                bandit.anim = .pickUp
                bandit.animHold = 0.55
                state.events.append(SimEvent(
                    kind: .crewFreed(crewID: state.crewCages[i].crewID),
                    position: state.crewCages[i].position
                ))
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

    private mutating func updateMops(bandit: inout BanditState, dt: Double, stompFalling: Bool, jumpHeld: Bool) {
        let feel = tuning.feel
        let mopW = feel.mopSpriteWidthTiles * tuning.tileSize
        let stompHalfW = mopW * feel.stompWidthMul * 0.5
        let hurtHalfW = mopW * feel.hurtWidthMul * 0.5
        let mopHalfH = halfH

        // Respawn + stun clocks before combat so a just-revived MOP can be stomped.
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
        }

        // Stomp / hurt against the pre-patrol pose so the MOP doesn't slide out from
        // under the feet on the same frame (patrol used to break chains after combo 3).
        var didStomp = false
        if stompFalling {
            for i in state.mops.indices where state.mops[i].alive {
                let dx = abs(bandit.position.x - state.mops[i].position.x)
                let feetY = bandit.position.y - halfH
                let mopMidY = state.mops[i].position.y + mopHalfH
                // Feet above MOP mid, or body still above MOP center (fast-fall contact).
                let aboveMid = feetY >= mopMidY - 6 || bandit.position.y >= state.mops[i].position.y
                guard aboveMid, dx <= stompHalfW else { continue }
                // Don't stomp from far below / deep underground overlaps.
                guard bandit.position.y >= state.mops[i].position.y - mopHalfH * 0.5 else { continue }

                state.mops[i].alive = false
                // Longer respawn while chaining so the pack doesn't pop back underfoot.
                state.mops[i].respawn = bandit.combo >= 2 ? 5.5 : 3.5
                state.mops[i].anim = .death
                state.mops[i].animHold = 0.8
                var bounce = feel.stompBounceVelocity * tuning.tileSize / 2.2
                if jumpHeld { bounce *= feel.stompBounceHoldMul }
                bandit.velocity.y = bounce
                bandit.flopping = false
                bandit.pouncing = false
                bandit.jumpCutArmed = jumpHeld
                bandit.invuln = max(bandit.invuln, max(0.85, feel.invulnSeconds * 0.85))
                bandit.combo = min(tuning.comboCap, bandit.combo + 1)
                bandit.comboTimer = tuning.comboGroundGrace
                if bandit.combo >= tuning.maskModeAtCombo && !bandit.maskMode {
                    bandit.maskMode = true
                    bandit.maskTimer = tuning.maskDuration
                    state.events.append(SimEvent(kind: .maskOn, position: bandit.position))
                } else if bandit.maskMode {
                    bandit.maskTimer = max(bandit.maskTimer, tuning.maskDuration * 0.55)
                }
                state.events.append(SimEvent(kind: .stomp, position: state.mops[i].position))
                state.events.append(SimEvent(kind: .shake, position: state.mops[i].position))
                didStomp = true
                break // one stomp per frame keeps bounce/combo readable
            }
        }

        // Patrol after combat so sin-phase motion doesn't dodge the stomp frame.
        for i in state.mops.indices where state.mops[i].alive {
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
        }

        if didStomp { return }

        // Never side-bag while descending / flopping / near-apex — those frames are stomp dives.
        if stompFalling || bandit.velocity.y < 0 || bandit.flopping || bandit.apexStompFrames > 0 {
            return
        }

        for i in state.mops.indices where state.mops[i].alive {
            let dx = abs(bandit.position.x - state.mops[i].position.x)
            let dy = abs(bandit.position.y - state.mops[i].position.y)
            // Hurt box stays smaller than the MOP sprite; only when grounded / rising beside them.
            if dx <= hurtHalfW, dy <= mopHalfH * 1.35, bandit.invuln <= 0 {
                bandit.hearts -= 1
                bandit.invuln = feel.invulnSeconds
                var away = bandit.position.x >= state.mops[i].position.x ? 1.0 : -1.0
                let tile = tuning.tileSize
                let minSafe = tile * 5
                let maxSafe = Double(map.width) * tile - tile * 5
                var nx = bandit.position.x + away * tile * 1.2
                if nx < minSafe {
                    away = 1
                    nx = minSafe
                } else if nx > maxSafe {
                    away = -1
                    nx = maxSafe
                }
                bandit.position.x = nx
                bandit.velocity.y = feel.jumpVelocity * tile / 3
                bandit.velocity.x = away * feel.runSpeed * tile * 0.85
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
                break
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
