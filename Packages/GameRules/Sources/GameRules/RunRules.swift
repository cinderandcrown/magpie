// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

/// Pure run-length and Heat rules for MAGPIE.
/// Kept free of UIKit/SpriteKit so tests run on Linux and macOS.
public enum RunRules: Sendable {
    /// Standard run length in seconds (Mission design: 180-second runs).
    public static let durationSeconds: Int = 180

    /// Heat meter range used by later systems (0…5 inclusive).
    public enum Heat: Int, CaseIterable, Sendable, Comparable {
        case zero = 0
        case one = 1
        case two = 2
        case three = 3
        case four = 4
        case five = 5

        public static func < (lhs: Heat, rhs: Heat) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// Clamps an integer into a valid Heat value.
        public static func clamped(_ value: Int) -> Heat {
            let bounded = min(max(value, Heat.zero.rawValue), Heat.five.rawValue)
            return Heat(rawValue: bounded) ?? .zero
        }
    }
}
