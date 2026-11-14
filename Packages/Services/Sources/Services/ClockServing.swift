// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Mission 0 stub protocol — real Store / Game Center / clips arrive later.
/// Each service sits behind a protocol with a mock for tests (plan §11).
public protocol ClockServing: Sendable {
    func now() -> Double
}

public struct SystemClock: ClockServing {
    public init() {}
    public func now() -> Double { 0 }
}

public struct MockClock: ClockServing {
    public var value: Double
    public init(value: Double = 0) { self.value = value }
    public func now() -> Double { value }
}

public enum ServicesInfo: Sendable {
    public static let name = "Services"
}
