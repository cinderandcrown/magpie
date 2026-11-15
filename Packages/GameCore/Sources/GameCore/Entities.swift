// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public enum BanditAirState: Equatable, Sendable {
    case grounded
    case pouncing
    case bellyFlopping
    case bouncing
    case tailSwinging
    case gliding
}

public struct BanditState: Equatable, Sendable {
    public var position: Vec2
    public var height: Double
    public var velocity: Vec2
    public var facing: Vec2
    public var air: BanditAirState
    public var airTimer: Double
    public var coastTimer: Double
    public var coyoteTimer: Double
    public var pounceBuffer: Double
    public var combo: Int
    public var comboGroundTimer: Double
    public var maskMode: Bool
    public var hearts: Int
    public var carriedShinies: Int
    public var bankedShinies: Int

    public var isAirborne: Bool { air != .grounded }

    public static func spawn(at position: Vec2, hearts: Int) -> BanditState {
        BanditState(
            position: position,
            height: 0,
            velocity: .zero,
            facing: Vec2(0, 1),
            air: .grounded,
            airTimer: 0,
            coastTimer: 0,
            coyoteTimer: 0,
            pounceBuffer: 0,
            combo: 0,
            comboGroundTimer: 0,
            maskMode: false,
            hearts: hearts,
            carriedShinies: 0,
            bankedShinies: 0
        )
    }
}

public struct ShinyPickup: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: Vec2
    public var alive: Bool
}

public struct FlopDummy: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: Vec2
    public var alive: Bool
    public var respawnTimer: Double
}

public enum RunOutcome: Equatable, Sendable {
    case playing
    case won
    case failed(FailReason)
}

public enum FailReason: Equatable, Sendable {
    case fellInWater
    case bagged
}
