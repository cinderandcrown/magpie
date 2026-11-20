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
    /// Consecutive Daily Heist clear streak (UTC days).
    public var dailyClears: Int
    public var lastDailyDay: String?
    /// Best Daily Heist score for the current UTC day (higher is better).
    public var bestDailyScore: Int
    /// Best clear time per level (seconds). Lower is better.
    public var bestSecondsByLevel: [String: Double]
    /// Soft XP from medals / clears — drives the results level-up sting.
    public var xp: Int
    /// Freed crew member IDs (from Story.json).
    public var freedCrewIDs: [String]
    /// First-launch comic intro completed / skipped.
    public var sawIntro: Bool
    /// Local flags for reported Game Center achievements (idempotent).
    public var unlockedAchievementIDs: [String]

    public init(
        medalsByLevel: [String: LevelMedals] = [:],
        unlockedDistricts: [String] = [DistrictID.neonDocks.rawValue],
        bestCombo: Int = 0,
        dailyClears: Int = 0,
        lastDailyDay: String? = nil,
        bestDailyScore: Int = 0,
        bestSecondsByLevel: [String: Double] = [:],
        xp: Int = 0,
        freedCrewIDs: [String] = [],
        sawIntro: Bool = false,
        unlockedAchievementIDs: [String] = []
    ) {
        self.medalsByLevel = medalsByLevel
        self.unlockedDistricts = unlockedDistricts
        self.bestCombo = bestCombo
        self.dailyClears = dailyClears
        self.lastDailyDay = lastDailyDay
        self.bestDailyScore = bestDailyScore
        self.bestSecondsByLevel = bestSecondsByLevel
        self.xp = xp
        self.freedCrewIDs = freedCrewIDs
        self.sawIntro = sawIntro
        self.unlockedAchievementIDs = unlockedAchievementIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        medalsByLevel = try c.decodeIfPresent([String: LevelMedals].self, forKey: .medalsByLevel) ?? [:]
        unlockedDistricts = try c.decodeIfPresent([String].self, forKey: .unlockedDistricts)
            ?? [DistrictID.neonDocks.rawValue]
        bestCombo = try c.decodeIfPresent(Int.self, forKey: .bestCombo) ?? 0
        dailyClears = try c.decodeIfPresent(Int.self, forKey: .dailyClears) ?? 0
        lastDailyDay = try c.decodeIfPresent(String.self, forKey: .lastDailyDay)
        bestDailyScore = try c.decodeIfPresent(Int.self, forKey: .bestDailyScore) ?? 0
        bestSecondsByLevel = try c.decodeIfPresent([String: Double].self, forKey: .bestSecondsByLevel) ?? [:]
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        freedCrewIDs = try c.decodeIfPresent([String].self, forKey: .freedCrewIDs) ?? []
        sawIntro = try c.decodeIfPresent(Bool.self, forKey: .sawIntro) ?? false
        unlockedAchievementIDs = try c.decodeIfPresent([String].self, forKey: .unlockedAchievementIDs) ?? []
    }

    public var rankLevel: Int { max(1, xp / 3 + 1) }

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
    public static let arcadeRowLevelID = "arcade_row_01"
    public static let rooftopsLevelID = "rooftops_01"
    public static let sewerGridLevelID = "sewer_grid_01"
    public static let dailyLevelID = "daily_heist"

    /// Primary level id for a district (heists 1–3 + finale).
    public static func levelID(for district: DistrictID) -> String {
        switch district {
        case .neonDocks: return neonDocksLevelID
        case .arcadeRow: return arcadeRowLevelID
        case .rooftops: return rooftopsLevelID
        case .sewerGrid: return sewerGridLevelID
        }
    }
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

    public struct ClearResult: Equatable, Sendable {
        public var medals: LevelMedals
        public var isNewBest: Bool
        public var didLevelUp: Bool
        public var rankLevel: Int
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
    ) -> ClearResult {
        var progress = load()
        let priorLevel = progress.rankLevel
        let earned = LevelMedals(
            finish: true,
            allShinies: shiniesTotal > 0 && shiniesCollected >= shiniesTotal,
            parTime: seconds <= parSeconds
        )
        var existing = progress.medalsByLevel[levelID] ?? LevelMedals()
        let beforeCount = existing.count
        existing.merge(earned)
        progress.medalsByLevel[levelID] = existing
        progress.bestCombo = max(progress.bestCombo, combo)
        let prevBest = progress.bestSecondsByLevel[levelID]
        let isNewBest = prevBest == nil || seconds < (prevBest ?? .greatestFiniteMagnitude)
        if isNewBest {
            progress.bestSecondsByLevel[levelID] = seconds
        }
        // XP: +1 per newly earned medal slot this clear.
        let gained = max(0, existing.count - beforeCount)
        progress.xp += max(1, gained)
        // Heist unlock chain: Docks → Arcade Row → Rooftops → Sewer Grid (finale).
        if existing.count >= 1 {
            if levelID.hasPrefix("neon_docks"),
               !progress.unlockedDistricts.contains(DistrictID.arcadeRow.rawValue) {
                progress.unlockedDistricts.append(DistrictID.arcadeRow.rawValue)
            }
            if levelID.hasPrefix("arcade_row"),
               !progress.unlockedDistricts.contains(DistrictID.rooftops.rawValue) {
                progress.unlockedDistricts.append(DistrictID.rooftops.rawValue)
            }
            if levelID.hasPrefix("rooftops"),
               !progress.unlockedDistricts.contains(DistrictID.sewerGrid.rawValue) {
                progress.unlockedDistricts.append(DistrictID.sewerGrid.rawValue)
            }
        }
        let didLevelUp = progress.rankLevel > priorLevel
        save(progress)
        return ClearResult(
            medals: earned,
            isNewBest: isNewBest,
            didLevelUp: didLevelUp,
            rankLevel: progress.rankLevel
        )
    }

    /// Record a Daily Heist clear. Retries the same UTC day do not inflate the streak;
    /// only the first clear of a new day extends it. Returns the updated streak.
    @discardableResult
    public func recordDailyClear(dayKey: String, score: Int = 0) -> Int {
        var progress = load()
        if progress.lastDailyDay == dayKey {
            if score > progress.bestDailyScore {
                progress.bestDailyScore = score
                save(progress)
            }
            return progress.dailyClears
        }
        if let last = progress.lastDailyDay, Self.isConsecutiveDay(previous: last, current: dayKey) {
            progress.dailyClears += 1
        } else {
            progress.dailyClears = 1
        }
        progress.lastDailyDay = dayKey
        progress.bestDailyScore = score
        save(progress)
        return progress.dailyClears
    }

    /// True when `current` is exactly one UTC calendar day after `previous`.
    public static func isConsecutiveDay(previous: String, current: String) -> Bool {
        let parts: (String) -> DateComponents? = { key in
            let bits = key.split(separator: "-").compactMap { Int($0) }
            guard bits.count == 3 else { return nil }
            return DateComponents(year: bits[0], month: bits[1], day: bits[2])
        }
        guard let a = parts(previous), let b = parts(current) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let da = cal.date(from: a), let db = cal.date(from: b) else { return false }
        let days = cal.dateComponents([.day], from: da, to: db).day ?? 0
        return days == 1
    }

    public func recordCrewFreed(_ crewID: String) {
        var progress = load()
        if !progress.freedCrewIDs.contains(crewID) {
            progress.freedCrewIDs.append(crewID)
            progress.xp += 2
            save(progress)
        }
    }

    public func markIntroSeen() {
        var progress = load()
        progress.sawIntro = true
        save(progress)
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
