// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public struct Vec2: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public var normalized: Vec2 {
        let len = length
        guard len > 1e-9 else { return .zero }
        return Vec2(x / len, y / len)
    }

    public static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x + rhs.x, lhs.y + rhs.y) }
    public static func - (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x - rhs.x, lhs.y - rhs.y) }
    public static func * (lhs: Vec2, rhs: Double) -> Vec2 { Vec2(lhs.x * rhs, lhs.y * rhs) }
    public static func * (lhs: Double, rhs: Vec2) -> Vec2 { rhs * lhs }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    public func clamped(to rectMin: Vec2, max rectMax: Vec2) -> Vec2 {
        Vec2(min(max(x, rectMin.x), rectMax.x), min(max(y, rectMin.y), rectMax.y))
    }
}
