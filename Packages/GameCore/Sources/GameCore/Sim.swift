// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public struct SimEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case pounce
        case land
        case bellyFlop
        case flopHit
        case shinyGrab
        case bank
        case maskModeOn
        case win
        case fail(FailReason)
        case dust
    }

    public var kind: Kind
    public var position: Vec2
}

public struct SimState: Equatable, Sendable {
    public var tick: Int
    public var bandit: BanditState
    public var shinies: [ShinyPickup]
    public var dummies: [FlopDummy]
    public var outcome: RunOutcome
    public var controlVariant: ControlVariant
    public var events: [SimEvent]

    public var stateHash: UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        func mix(_ v: UInt64) {
            h ^= v
            h &*= 0x100000001b3
        }
        func mixD(_ d: Double) {
            mix(d.bitPattern)
        }
        mix(UInt64(tick))
        mixD(bandit.position.x)
        mixD(bandit.position.y)
        mixD(bandit.height)
        mixD(bandit.velocity.x)
        mixD(bandit.velocity.y)
        mix(UInt64(bandit.combo))
        mix(UInt64(bandit.carriedShinies))
        mix(UInt64(bandit.bankedShinies))
        mix(UInt64(bandit.hearts))
        mix(bandit.maskMode ? 1 : 0)
        for s in shinies {
            mix(UInt64(s.id))
            mix(s.alive ? 1 : 0)
        }
        for d in dummies {
            mix(UInt64(d.id))
            mix(d.alive ? 1 : 0)
            mixD(d.respawnTimer)
        }
        switch outcome {
        case .playing: mix(0)
        case .won: mix(1)
        case .failed(let r):
            mix(2)
            mix(r == .fellInWater ? 1 : 2)
        }
        return h
    }
}

public struct Sim: Equatable, Sendable {
    public var tuning: Tuning
    public var map: TileMap
    public var state: SimState
    public var seed: UInt64

    public init(map: TileMap, tuning: Tuning = .default, seed: UInt64 = 1, variant: ControlVariant = .a) {
        self.tuning = tuning
        self.map = map
        self.seed = seed
        let tile = tuning.tileSize
        let start = map.findFirst(.start).map { map.worldCenter(ofX: $0.0, y: $0.1, tileSize: tile) }
            ?? map.worldCenter(ofX: 1, y: 1, tileSize: tile)
        var shinies: [ShinyPickup] = []
        for (i, cell) in map.findAll(.shinySpawn).enumerated() {
            shinies.append(ShinyPickup(id: i, position: map.worldCenter(ofX: cell.0, y: cell.1, tileSize: tile), alive: true))
        }
        var dummies: [FlopDummy] = []
        for (i, cell) in map.findAll(.dummySpawn).enumerated() {
            dummies.append(FlopDummy(id: i, position: map.worldCenter(ofX: cell.0, y: cell.1, tileSize: tile), alive: true, respawnTimer: 0))
        }
        self.state = SimState(
            tick: 0,
            bandit: .spawn(at: start, hearts: tuning.hearts),
            shinies: shinies,
            dummies: dummies,
            outcome: .playing,
            controlVariant: variant,
            events: []
        )
    }

    public mutating func step(_ input: InputFrame) {
        state.events.removeAll(keepingCapacity: true)
        guard case .playing = state.outcome else {
            state.tick += 1
            return
        }

        let dt = tuning.dt
        var b = state.bandit

        if input.pouncePressed {
            b.pounceBuffer = tuning.inputBufferSeconds
        } else if b.pounceBuffer > 0 {
            b.pounceBuffer = max(0, b.pounceBuffer - dt)
        }

        applyGroundMovement(input: input, bandit: &b, dt: dt)
        applyAir(input: input, bandit: &b, dt: dt)
        resolveTiles(bandit: &b)
        collectShinies(bandit: &b)
        bankIfNeeded(bandit: &b)
        updateCombo(bandit: &b, dt: dt)
        respawnDummies(dt: dt)
        checkFail(bandit: &b)

        state.bandit = b
        state.tick += 1
    }

    private mutating func applyGroundMovement(input: InputFrame, bandit: inout BanditState, dt: Double) {
        let move = input.move
        if !bandit.isAirborne {
            if move.length > 0.05 {
                let dir = move.normalized
                bandit.facing = dir
                bandit.velocity = dir * (tuning.runSpeed * tuning.tileSize)
                bandit.coastTimer = tuning.coastSeconds
            } else if bandit.coastTimer > 0 {
                bandit.coastTimer -= dt
                let coastFactor = max(0, bandit.coastTimer / tuning.coastSeconds)
                bandit.velocity = bandit.facing * (tuning.runSpeed * tuning.tileSize * coastFactor)
            } else {
                bandit.velocity = .zero
            }

            if bandit.pounceBuffer > 0 || input.pouncePressed {
                startPounce(&bandit)
            }
        } else if bandit.air == .pouncing || bandit.air == .bouncing, move.length > 0.05 {
            // Light air steer
            let dir = move.normalized
            bandit.facing = dir
            let airControl = 0.55
            bandit.velocity = bandit.velocity * (1 - airControl) + dir * (tuning.runSpeed * tuning.tileSize) * airControl
        }

        bandit.position = bandit.position + bandit.velocity * dt
    }

    private mutating func startPounce(_ bandit: inout BanditState) {
        guard !bandit.isAirborne || bandit.coyoteTimer > 0 else { return }
        bandit.air = .pouncing
        bandit.airTimer = tuning.pounceAirtime
        bandit.height = 0
        bandit.coyoteTimer = 0
        bandit.pounceBuffer = 0
        // Forward hop so a Pounce clears a 1-tile gap.
        let hop = bandit.facing.length > 0.1 ? bandit.facing.normalized : Vec2(0, 1)
        bandit.velocity = hop * (tuning.runSpeed * tuning.tileSize * 1.15)
        state.events.append(SimEvent(kind: .pounce, position: bandit.position))
        state.events.append(SimEvent(kind: .dust, position: bandit.position))
    }

    private mutating func applyAir(input: InputFrame, bandit: inout BanditState, dt: Double) {
        if !bandit.isAirborne {
            bandit.coyoteTimer = tuning.coyoteSeconds
            return
        }

        bandit.coyoteTimer = max(0, bandit.coyoteTimer - dt)

        switch bandit.air {
        case .pouncing, .bouncing:
            bandit.airTimer -= dt
            let total = bandit.air == .pouncing ? tuning.pounceAirtime : tuning.bellyFlopBounceAirtime
            let peak = bandit.air == .pouncing ? tuning.pounceHeight : tuning.bellyFlopBounceHeight
            let t = max(0, min(1, 1 - bandit.airTimer / total))
            // Parabola 0→1→0
            bandit.height = peak * 4 * t * (1 - t) * tuning.tileSize
            if bandit.airTimer <= 0 {
                land(&bandit)
            } else if input.bellyFlopPressed {
                beginBellyFlop(&bandit)
            } else if input.hold {
                beginSwingOrGlide(&bandit)
            }

        case .bellyFlopping:
            bandit.airTimer -= dt
            bandit.height = max(0, bandit.height - tuning.tileSize * 8 * dt)
            if bandit.height <= 0 || bandit.airTimer <= 0 {
                resolveBellyFlopLanding(&bandit)
            }

        case .tailSwinging, .gliding:
            bandit.airTimer -= dt
            let speed = tuning.tailSwingSpeed * tuning.tileSize
            bandit.velocity = bandit.facing * speed
            bandit.height = max(0.35 * tuning.tileSize, bandit.height - tuning.tileSize * 0.35 * dt)
            if input.bellyFlopPressed {
                beginBellyFlop(&bandit)
            } else if bandit.airTimer <= 0 || !input.hold {
                // Drop to land
                bandit.air = .pouncing
                bandit.airTimer = 0.12
            }

        case .grounded:
            break
        }
    }

    private mutating func beginSwingOrGlide(_ bandit: inout BanditState) {
        if tuning.useTailSwing {
            // Prefer latch within 2 tiles ahead
            let look = bandit.position + bandit.facing * (2.0 * tuning.tileSize)
            let tile = map.tile(atWorld: look, tileSize: tuning.tileSize)
            if tile == .latch || nearbyLatch(from: bandit.position) {
                bandit.air = .tailSwinging
            } else {
                bandit.air = .tailSwinging // short coat-flap still uses swing feel
            }
        } else {
            bandit.air = .gliding
        }
        bandit.airTimer = tuning.tailSwingMaxTime
    }

    private func nearbyLatch(from pos: Vec2) -> Bool {
        for dy in -2...2 {
            for dx in -2...2 {
                let probe = pos + Vec2(Double(dx), Double(dy)) * tuning.tileSize
                if map.tile(atWorld: probe, tileSize: tuning.tileSize) == .latch {
                    return true
                }
            }
        }
        return false
    }

    private mutating func beginBellyFlop(_ bandit: inout BanditState) {
        bandit.air = .bellyFlopping
        bandit.airTimer = 0.25
        state.events.append(SimEvent(kind: .bellyFlop, position: bandit.position))
    }

    private mutating func resolveBellyFlopLanding(_ bandit: inout BanditState) {
        bandit.height = 0
        var hit = false
        let radius = tuning.stompTargetRadiusTiles * tuning.tileSize
        for i in state.dummies.indices where state.dummies[i].alive {
            if state.dummies[i].position.distance(to: bandit.position) <= radius {
                state.dummies[i].alive = false
                state.dummies[i].respawnTimer = 2.5
                hit = true
                state.events.append(SimEvent(kind: .flopHit, position: state.dummies[i].position))
            }
        }
        if hit {
            bandit.combo = min(tuning.comboCap, bandit.combo + 1)
            bandit.comboGroundTimer = tuning.comboGroundGrace
            if bandit.combo >= tuning.maskModeAtCombo && !bandit.maskMode {
                bandit.maskMode = true
                state.events.append(SimEvent(kind: .maskModeOn, position: bandit.position))
            }
            // Bounce + refresh swing window
            bandit.air = .bouncing
            bandit.airTimer = tuning.bellyFlopBounceAirtime
            state.events.append(SimEvent(kind: .dust, position: bandit.position))
        } else {
            land(&bandit)
        }
    }

    private mutating func land(_ bandit: inout BanditState) {
        bandit.air = .grounded
        bandit.height = 0
        bandit.airTimer = 0
        state.events.append(SimEvent(kind: .land, position: bandit.position))
        state.events.append(SimEvent(kind: .dust, position: bandit.position))
    }

    private mutating func resolveTiles(bandit: inout BanditState) {
        let tileSize = tuning.tileSize
        // Push out of walls
        for _ in 0..<4 {
            let t = map.tile(atWorld: bandit.position, tileSize: tileSize)
            if map.isSolid(t) {
                // Nudge toward previous walkable by stepping back along velocity
                let back = bandit.facing * (-0.35 * tileSize)
                bandit.position = bandit.position + back
                bandit.velocity = .zero
            } else {
                break
            }
        }
        // Clamp to map
        let minP = Vec2(tileSize * 0.5, tileSize * 0.5)
        let maxP = Vec2(Double(map.width) * tileSize - tileSize * 0.5, Double(map.height) * tileSize - tileSize * 0.5)
        bandit.position = bandit.position.clamped(to: minP, max: maxP)
    }

    private mutating func collectShinies(bandit: inout BanditState) {
        let grabR = tuning.tileSize * 0.55
        for i in state.shinies.indices where state.shinies[i].alive {
            if state.shinies[i].position.distance(to: bandit.position) <= grabR {
                state.shinies[i].alive = false
                let gain = bandit.maskMode ? 2 : 1
                bandit.carriedShinies += gain
                state.events.append(SimEvent(kind: .shinyGrab, position: state.shinies[i].position))
            }
        }
    }

    private mutating func bankIfNeeded(bandit: inout BanditState) {
        let t = map.tile(atWorld: bandit.position, tileSize: tuning.tileSize)
        guard t == .stash, bandit.carriedShinies > 0, !bandit.isAirborne else { return }
        bandit.bankedShinies += bandit.carriedShinies
        bandit.carriedShinies = 0
        state.events.append(SimEvent(kind: .bank, position: bandit.position))
        if bandit.bankedShinies >= tuning.shiniesToWin {
            state.outcome = .won
            state.events.append(SimEvent(kind: .win, position: bandit.position))
        }
    }

    private mutating func updateCombo(bandit: inout BanditState, dt: Double) {
        guard !bandit.isAirborne else { return }
        if bandit.combo > 0 {
            bandit.comboGroundTimer -= dt
            if bandit.comboGroundTimer <= 0 {
                bandit.combo = 0
                bandit.maskMode = false
            }
        }
    }

    private mutating func respawnDummies(dt: Double) {
        for i in state.dummies.indices where !state.dummies[i].alive {
            state.dummies[i].respawnTimer -= dt
            if state.dummies[i].respawnTimer <= 0 {
                state.dummies[i].alive = true
            }
        }
    }

    private mutating func checkFail(bandit: inout BanditState) {
        let t = map.tile(atWorld: bandit.position, tileSize: tuning.tileSize)
        if t == .water && !bandit.isAirborne {
            state.outcome = .failed(.fellInWater)
            state.events.append(SimEvent(kind: .fail(.fellInWater), position: bandit.position))
        }
        if bandit.hearts <= 0 {
            state.outcome = .failed(.bagged)
            state.events.append(SimEvent(kind: .fail(.bagged), position: bandit.position))
        }
    }
}

/// Deterministic replay recorder.
public struct ReplayRecorder: Equatable, Sendable {
    public var inputs: [InputFrame] = []

    public mutating func record(_ input: InputFrame) {
        inputs.append(input)
    }
}

public enum ReplayPlayer {
    public static func play(map: TileMap, tuning: Tuning, seed: UInt64, inputs: [InputFrame], variant: ControlVariant = .a) -> SimState {
        var sim = Sim(map: map, tuning: tuning, seed: seed, variant: variant)
        for input in inputs {
            sim.step(input)
        }
        return sim.state
    }
}
