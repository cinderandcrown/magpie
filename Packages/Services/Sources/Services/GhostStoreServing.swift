// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Compact ghost sample — position + facing at ~10 Hz (or on input edges).
public struct GhostSample: Codable, Equatable, Sendable {
    public var t: Float
    public var x: Float
    public var y: Float
    public var facing: Int8

    public init(t: Float, x: Float, y: Float, facing: Int8) {
        self.t = t
        self.x = x
        self.y = y
        self.facing = facing
    }
}

public struct GhostRun: Codable, Equatable, Sendable {
    public var dayKey: String
    public var playerID: String
    public var displayName: String
    public var score: Int
    public var seconds: Float
    public var samples: [GhostSample]

    public init(
        dayKey: String,
        playerID: String,
        displayName: String,
        score: Int,
        seconds: Float,
        samples: [GhostSample]
    ) {
        self.dayKey = dayKey
        self.playerID = playerID
        self.displayName = displayName
        self.score = score
        self.seconds = seconds
        self.samples = samples
    }
}

public enum GhostKind: String, Sendable {
    case worldBest = "world_best"
    case friend
    case own
}

/// CloudKit public DB (free) for Daily Heist ghosts — keyed by date + player.
public protocol GhostStoreServing: AnyObject, Sendable {
    func saveOwnBest(_ run: GhostRun) async
    func loadOwnBest(dayKey: String) async -> GhostRun?
    func loadWorldBest(dayKey: String) async -> GhostRun?
    func loadFriendBest(dayKey: String, friendID: String) async -> GhostRun?
}

/// Local UserDefaults-backed mock for tests and offline.
public final class MockGhostStore: GhostStoreServing, @unchecked Sendable {
    private var own: [String: GhostRun] = [:]
    private var world: [String: GhostRun] = [:]
    private var friends: [String: GhostRun] = [:]

    public init() {}

    public func saveOwnBest(_ run: GhostRun) async {
        let prior = own[run.dayKey]
        if prior == nil || run.score > (prior?.score ?? 0) {
            own[run.dayKey] = run
        }
        let worldPrior = world[run.dayKey]
        if worldPrior == nil || run.score > (worldPrior?.score ?? 0) {
            world[run.dayKey] = run
        }
    }

    public func loadOwnBest(dayKey: String) async -> GhostRun? { own[dayKey] }
    public func loadWorldBest(dayKey: String) async -> GhostRun? { world[dayKey] }
    public func loadFriendBest(dayKey: String, friendID: String) async -> GhostRun? {
        friends["\(dayKey):\(friendID)"]
    }

    public func seedFriend(_ run: GhostRun) {
        friends["\(run.dayKey):\(run.playerID)"] = run
    }
}
