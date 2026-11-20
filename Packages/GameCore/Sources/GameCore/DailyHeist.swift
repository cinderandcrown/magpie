// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Daily Heist — one layout per UTC day, same for everyone.
/// Starts from Neon Docks grammar (reachability-proven) and applies deterministic
/// seed-based MOP/shiny jitter via `Sim` (not ASCII rewriting).
public enum DailyHeist: Sendable {
    public static func dayKey(date: Date = Date()) -> String {
        ProgressStore.dayKey(date: date)
    }

    public static func seed(dayKey: String) -> UInt64 {
        ProgressStore.dailySeed(dayKey: dayKey)
    }

    public static func loadMap() throws -> TileMap {
        try NeonDocksLevel.load()
    }

    public static func makeSim(dayKey: String, tuning: Tuning = .default) throws -> Sim {
        let map = try loadMap()
        return Sim(map: map, tuning: tuning, seed: seed(dayKey: dayKey), variant: .a)
    }
}
