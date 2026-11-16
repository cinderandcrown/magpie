// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public enum ControlVariant: Equatable, Sendable {
    /// Left stick zone + right face buttons (Jump / Pounce).
    case a
    /// Same layout, alternate Jump button placement (Gate 1 pick).
    case b
}

public struct InputFrame: Equatable, Sendable {
    /// Horizontal intent −1…1.
    public var moveX: Double
    /// Vertical stick intent −1…1 (negative = down). Used to drop through one-way platforms.
    public var moveY: Double
    public var jumpPressed: Bool
    public var jumpHeld: Bool
    public var pouncePressed: Bool

    public init(
        moveX: Double = 0,
        moveY: Double = 0,
        jumpPressed: Bool = false,
        jumpHeld: Bool = false,
        pouncePressed: Bool = false
    ) {
        self.moveX = moveX
        self.moveY = moveY
        self.jumpPressed = jumpPressed
        self.jumpHeld = jumpHeld
        self.pouncePressed = pouncePressed
    }

    public static let idle = InputFrame()
}

/// Converts raw touch samples into taps using Tuning thresholds (shared with render).
public struct TouchInterpreter: Equatable, Sendable {
    public var touchDown: Bool = false
    public var touchStartTime: Double = 0
    public var touchStartPos: Vec2 = .zero
    public var lastPos: Vec2 = .zero

    public init() {}

    public mutating func begin(at time: Double, pos: Vec2) {
        touchDown = true
        touchStartTime = time
        touchStartPos = pos
        lastPos = pos
    }

    public mutating func move(to pos: Vec2) {
        lastPos = pos
    }

    public mutating func end(at time: Double, maxMs: Double, maxPoints: Double) -> Bool {
        guard touchDown else { return false }
        touchDown = false
        let dtMs = (time - touchStartTime) * 1000
        let dist = lastPos.distance(to: touchStartPos)
        return dtMs <= maxMs && dist <= maxPoints
    }
}
