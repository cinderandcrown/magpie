// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Game Center façade — live on device, mock in tests / Linux.
/// Auth is always non-blocking: the game plays fully while signed out.
public protocol GameCenterServing: AnyObject, Sendable {
    var isAuthenticated: Bool { get }
    var localPlayerID: String? { get }
    var localDisplayName: String? { get }

    /// Kick off GKLocalPlayer auth. Never blocks the main loop; completion may be nil.
    func authenticate(completion: (@Sendable (Bool) -> Void)?)

    /// Show / hide the system Game Center access point (menu + results).
    func setAccessPointVisible(_ visible: Bool, showHighlights: Bool)

    func submitScore(_ score: Int, leaderboardID: String)
    func reportAchievement(id: String, percentComplete: Double)
    func presentLeaderboard(id: String?)
    func presentAchievements()
    /// Friend "beat my score" share / challenge when the OS supports it.
    func challengeFriends(leaderboardID: String, message: String)
}

/// Catalog IDs — must match `Assets/GameCenter/catalog.json` vendorIdentifiers.
public enum GameCenterIDs: Sendable {
    public static let dailyHeist = "daily_heist"
    public static let mostWantedWeekly = "most_wanted_weekly"
    public static let bestCombo = "best_combo"

    public static let firstHeist = "first_heist"
    public static let threeStarHeist = "three_star_heist"
    public static let noDamageHeist = "no_damage_heist"
    public static let beatFriendGhost = "beat_friend_ghost"
    public static let dailyStreak3 = "daily_streak_3"
    public static let dailyStreak7 = "daily_streak_7"
    public static let dailyStreak30 = "daily_streak_30"
    public static let mostWantedTop10 = "most_wanted_top10"
    public static let firstMaskMode = "first_mask_mode"
    public static let firstCrewRescue = "first_crew_rescue"
    public static let clearArcadeRow = "clear_arcade_row"
    public static let clearRooftops = "clear_rooftops"
    public static let dailyRank1 = "daily_rank_1"
    public static let beatOwnGhost = "beat_own_ghost"
    public static let banditOfBothWorlds = "bandit_of_both_worlds"
}

/// No-op mock — unit tests and unsigned-out play.
public final class MockGameCenter: GameCenterServing, @unchecked Sendable {
    public private(set) var isAuthenticated = false
    public private(set) var localPlayerID: String? = nil
    public private(set) var localDisplayName: String? = nil
    public private(set) var submitted: [(Int, String)] = []
    public private(set) var achievements: [(String, Double)] = []
    public private(set) var accessPointVisible = false
    public var autoAuthSucceeds = true

    public init() {}

    public func authenticate(completion: (@Sendable (Bool) -> Void)?) {
        isAuthenticated = autoAuthSucceeds
        localPlayerID = autoAuthSucceeds ? "mock.player" : nil
        localDisplayName = autoAuthSucceeds ? "Mock Bandit" : nil
        completion?(isAuthenticated)
    }

    public func setAccessPointVisible(_ visible: Bool, showHighlights: Bool) {
        accessPointVisible = visible
        _ = showHighlights
    }

    public func submitScore(_ score: Int, leaderboardID: String) {
        submitted.append((score, leaderboardID))
    }

    public func reportAchievement(id: String, percentComplete: Double) {
        achievements.append((id, percentComplete))
    }

    public func presentLeaderboard(id: String?) { _ = id }
    public func presentAchievements() {}
    public func challengeFriends(leaderboardID: String, message: String) {
        _ = (leaderboardID, message)
    }
}
