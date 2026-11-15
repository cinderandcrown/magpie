// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Three medals per level — finish / all Shinies / par time. Awarded on clear only.
public struct LevelMedals: Equatable, Sendable, Codable {
    public var finish: Bool
    public var allShinies: Bool
    public var parTime: Bool

    public init(finish: Bool = false, allShinies: Bool = false, parTime: Bool = false) {
        self.finish = finish
        self.allShinies = allShinies
        self.parTime = parTime
    }

    public var count: Int {
        (finish ? 1 : 0) + (allShinies ? 1 : 0) + (parTime ? 1 : 0)
    }

    public mutating func merge(_ other: LevelMedals) {
        finish = finish || other.finish
        allShinies = allShinies || other.allShinies
        parTime = parTime || other.parTime
    }
}

public enum DistrictID: String, Equatable, Sendable, Codable, CaseIterable {
    case neonDocks = "neon_docks"
    case arcadeRow = "arcade_row"
    case rooftops = "rooftops"
    case sewerGrid = "sewer_grid"

    public var displayName: String {
        switch self {
        case .neonDocks: return "Neon Docks"
        case .arcadeRow: return "Arcade Row"
        case .rooftops: return "Rooftops"
        case .sewerGrid: return "Sewer Grid"
        }
    }
}

public struct PlayerProgress: Equatable, Sendable, Codable {
    public var medalsByLevel: [String: LevelMedals]
    public var unlockedDistricts: [String]
    public var bestCombo: Int
    public var dailyClears: Int
    public var lastDailyDay: String?

    public init(
        medalsByLevel: [String: LevelMedals] = [:],
        unlockedDistricts: [String] = [DistrictID.neonDocks.rawValue],
        bestCombo: Int = 0,
        dailyClears: Int = 0,
        lastDailyDay: String? = nil
    ) {
        self.medalsByLevel = medalsByLevel
        self.unlockedDistricts = unlockedDistricts
        self.bestCombo = bestCombo
        self.dailyClears = dailyClears
        self.lastDailyDay = lastDailyDay
    }

    public func isUnlocked(_ district: DistrictID) -> Bool {
        unlockedDistricts.contains(district.rawValue)
    }

    public var totalMedals: Int {
        medalsByLevel.values.reduce(0) { $0 + $1.count }
    }
}

/// Local persistence for medals / district unlocks / Daily Heist day key.
public struct ProgressStore: Sendable {
    public static let neonDocksLevelID = "neon_docks_01"
    public static let dailyLevelID = "daily_heist"
    /// Par time (seconds) for the smoke rooftop / first docks clear medal.
    public static let defaultParSeconds: Double = 45

    private let defaultsKey = "magpie.playerProgress.v1"

    public init() {}

    public func load() -> PlayerProgress {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(PlayerProgress.self, from: data) else {
            return PlayerProgress()
        }
        return decoded
    }

    public func save(_ progress: PlayerProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Compute medals for a clear and merge into progress. Death awards nothing.
    @discardableResult
    public func recordClear(
        levelID: String,
        shiniesCollected: Int,
        shiniesTotal: Int,
        seconds: Double,
        parSeconds: Double = ProgressStore.defaultParSeconds,
        combo: Int
    ) -> LevelMedals {
        var progress = load()
        var earned = LevelMedals(
            finish: true,
            allShinies: shiniesTotal > 0 && shiniesCollected >= shiniesTotal,
            parTime: seconds <= parSeconds
        )
        var existing = progress.medalsByLevel[levelID] ?? LevelMedals()
        existing.merge(earned)
        progress.medalsByLevel[levelID] = existing
        progress.bestCombo = max(progress.bestCombo, combo)
        // Unlock Arcade Row after any Neon Docks clear with ≥1 medal.
        if levelID.hasPrefix("neon_docks"), existing.count >= 1,
           !progress.unlockedDistricts.contains(DistrictID.arcadeRow.rawValue) {
            progress.unlockedDistricts.append(DistrictID.arcadeRow.rawValue)
        }
        save(progress)
        return earned
    }

    public func recordDailyClear(dayKey: String) {
        var progress = load()
        if progress.lastDailyDay != dayKey {
            progress.dailyClears += 1
            progress.lastDailyDay = dayKey
            save(progress)
        }
    }

    /// Stable UTC day key for Daily Heist (same seed for everyone that day).
    public static func dayKey(date: Date = Date(), calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Deterministic Daily Heist seed from the UTC day key.
    public static func dailySeed(dayKey: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in dayKey.utf8 {
            hash ^= UInt64(b)
            hash &*= 0x100_0000_01b3
        }
        return hash == 0 ? 1 : hash
    }
}
