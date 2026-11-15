// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public enum ControlVariant: Equatable, Sendable {
    /// Drag to move; tap to Pounce / air-tap Belly Flop; hold in air for Tail Swing.
    case a
    /// Same as A plus a fixed on-screen Pounce button (Gate 1 pick).
    case b
}

public struct InputFrame: Equatable, Sendable {
    /// Desired move direction in world space, length 0…1.
    public var move: Vec2
    /// True for one frame when a quick tap is recognized (or Pounce button in variant B).
    public var pouncePressed: Bool
    /// Finger is held (for Tail Swing / glide while airborne).
    public var hold: Bool
    /// Air tap: Belly Flop.
    public var bellyFlopPressed: Bool

    public init(
        move: Vec2 = .zero,
        pouncePressed: Bool = false,
        hold: Bool = false,
        bellyFlopPressed: Bool = false
    ) {
        self.move = move
        self.pouncePressed = pouncePressed
        self.hold = hold
        self.bellyFlopPressed = bellyFlopPressed
    }

    public static let idle = InputFrame()
}

/// Converts raw touch samples into InputFrame using Tuning tap thresholds.
public struct TouchInterpreter: Equatable, Sendable {
    public var touchDown: Bool = false
    public var touchStartTime: Double = 0
    public var touchStartPos: Vec2 = .zero
    public var lastPos: Vec2 = .zero
    public var wasAirborneAtDown: Bool = false

    public mutating func begin(at time: Double, pos: Vec2, airborne: Bool) {
        touchDown = true
        touchStartTime = time
        touchStartPos = pos
        lastPos = pos
        wasAirborneAtDown = airborne
    }

    public mutating func move(to pos: Vec2) {
        lastPos = pos
    }

    public mutating func end(at time: Double, tuning: Tuning) -> (pounce: Bool, bellyFlop: Bool) {
        guard touchDown else { return (false, false) }
        touchDown = false
        let dtMs = (time - touchStartTime) * 1000
        let dist = lastPos.distance(to: touchStartPos)
        let isTap = dtMs <= tuning.tapMaxMs && dist <= tuning.tapMaxPoints
        if !isTap { return (false, false) }
        if wasAirborneAtDown {
            return (false, true)
        }
        return (true, false)
    }
}
