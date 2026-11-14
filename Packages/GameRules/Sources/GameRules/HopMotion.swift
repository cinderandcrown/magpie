// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

/// Placeholder hop math for Mission 0 (tap → hop).
/// SpriteKit animates with the same numbers; tests assert them without Apple frameworks.
public enum HopMotion: Sendable {
    /// Vertical lift applied by one tap hop, in points.
    public static let defaultLift: Double = 96

    /// Duration of the up-then-down hop cycle, in seconds.
    public static let defaultDuration: Double = 0.42

    /// Peak Y after a hop from `startY` with the given lift (SpriteKit Y-up).
    public static func peakY(startY: Double, lift: Double = defaultLift) -> Double {
        startY + max(0, lift)
    }

    /// Whether a hop is allowed (Mission 0: always, unless already mid-hop).
    public static func canHop(isHopping: Bool) -> Bool {
        !isHopping
    }
}
