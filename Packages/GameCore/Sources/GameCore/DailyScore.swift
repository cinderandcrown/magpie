// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Daily Heist / Most Wanted score: time + loot + no-damage bonus.
/// Higher is better. Retries unlimited; only best score counts on the board.
public enum DailyScore: Sendable {
    /// Par time for the daily layout (seconds). Under-par earns a time bonus.
    public static let parSeconds: Double = 90

    public static func compute(
        seconds: Double,
        shiniesCollected: Int,
        shiniesTotal: Int,
        tookDamage: Bool,
        combo: Int
    ) -> Int {
        let loot = shiniesCollected * 100
        let lootBonus = shiniesTotal > 0 && shiniesCollected >= shiniesTotal ? 250 : 0
        let timeBonus = max(0, Int((parSeconds - seconds) * 12))
        let clean = tookDamage ? 0 : 500
        let comboPts = combo * 50
        return max(0, loot + lootBonus + timeBonus + clean + comboPts)
    }
}
