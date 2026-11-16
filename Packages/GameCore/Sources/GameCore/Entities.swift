// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public enum BanditAnim: Equatable, Sendable {
    case idle, walk, run, jump, apex, fall, pounce, wallSlide, hurt, death, pickUp
}

public struct BanditState: Equatable, Sendable {
    public var position: Vec2
    public var velocity: Vec2
    public var facing: Double // −1 or 1
    public var onGround: Bool
    public var onWallLeft: Bool
    public var onWallRight: Bool
    public var coyote: Double
    public var jumpBuffer: Double
    public var wallCling: Double
    public var pouncing: Bool
    public var flopping: Bool
    public var combo: Int
    public var comboTimer: Double
    public var maskMode: Bool
    public var hearts: Int
    public var invuln: Double
    public var carriedShinies: Int
    public var bankedShinies: Int
    public var anim: BanditAnim
    /// While > 0, `anim` stays locked (hurt / death / pickUp one-shots).
    public var animHold: Double

    public static func spawn(at position: Vec2, hearts: Int) -> BanditState {
        BanditState(
            position: position,
            velocity: .zero,
            facing: 1,
            onGround: false,
            onWallLeft: false,
            onWallRight: false,
            coyote: 0,
            jumpBuffer: 0,
            wallCling: 0,
            pouncing: false,
            flopping: false,
            combo: 0,
            comboTimer: 0,
            maskMode: false,
            hearts: hearts,
            invuln: 0,
            carriedShinies: 0,
            bankedShinies: 0,
            anim: .idle,
            animHold: 0
        )
    }
}

public struct ShinyPickup: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: Vec2
    public var alive: Bool
}

public enum MopAnim: Equatable, Sendable {
    case walk, attack, hurt, death
}

public struct MopEnemy: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: Vec2
    public var home: Vec2
    public var patrolSpan: Double
    public var phase: Double
    public var alive: Bool
    public var respawn: Double
    public var anim: MopAnim
    public var animHold: Double
    public var facing: Double
}

public struct Checkpoint: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: Vec2
    public var activated: Bool
}

public enum RunPhase: Equatable, Sendable {
    case title
    case playing
    case won(seconds: Double, shinies: Int, combo: Int)
    case failed(FailReason)
}

public enum FailReason: Equatable, Sendable {
    case fellInWater
    case spiked
    case bagged
}
