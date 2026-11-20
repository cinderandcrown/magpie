// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

#if canImport(GameKit) && canImport(UIKit)
import GameKit
import UIKit

/// Live GameKit wrapper. Auth never blocks play — failure leaves the mock-like signed-out state.
/// Not `@MainActor`-typed so protocol conformance stays Sendable-safe under Swift 6;
/// UIKit / GameKit calls hop to the main actor explicitly.
public final class GameCenterService: NSObject, GameCenterServing, @unchecked Sendable {
    public static let shared = GameCenterService()

    public private(set) var isAuthenticated = false
    public private(set) var localPlayerID: String?
    public private(set) var localDisplayName: String?

    private var authCompletion: (@Sendable (Bool) -> Void)?

    private override init() {
        super.init()
    }

    public func authenticate(completion: (@Sendable (Bool) -> Void)?) {
        // Unsigned CI simulators invalidate gamed — never arm the handler under harness.
        if ProcessInfo.processInfo.underAutomatedHarness {
            isAuthenticated = false
            localPlayerID = nil
            localDisplayName = nil
            completion?(false)
            return
        }
        authCompletion = completion
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            // Snapshot Sendable values only — never send GKLocalPlayer into a Task.
            let local = GKLocalPlayer.local
            let ok = error == nil && local.isAuthenticated
            let pid = local.gamePlayerID
            let name = local.displayName
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let viewController, let root = Self.topViewController() {
                    root.present(viewController, animated: true)
                    return
                }
                if !ok {
                    self.isAuthenticated = false
                    self.localPlayerID = nil
                    self.localDisplayName = nil
                    self.authCompletion?(false)
                    self.authCompletion = nil
                    return
                }
                self.isAuthenticated = true
                self.localPlayerID = pid
                self.localDisplayName = name
                self.authCompletion?(true)
                self.authCompletion = nil
            }
        }
    }

    public func setAccessPointVisible(_ visible: Bool, showHighlights: Bool) {
        let active = visible && isAuthenticated
        Task { @MainActor in
            let point = GKAccessPoint.shared
            point.location = .topLeading
            point.showHighlights = showHighlights
            point.isActive = active
        }
    }

    public func submitScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { _ in }
    }

    public func reportAchievement(id: String, percentComplete: Double) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = min(100, max(0, percentComplete))
        achievement.showsCompletionBanner = percentComplete >= 100
        GKAchievement.report([achievement]) { _ in }
    }

    public func presentLeaderboard(id: String?) {
        guard isAuthenticated else { return }
        Task { @MainActor in
            guard let root = Self.topViewController() else { return }
            let gc: GKGameCenterViewController
            if let id {
                // iOS 14+ initializer — avoids deprecated `leaderboardIdentifier`.
                gc = GKGameCenterViewController(
                    leaderboardID: id,
                    playerScope: .global,
                    timeScope: .allTime
                )
            } else {
                gc = GKGameCenterViewController(state: .leaderboards)
            }
            gc.gameCenterDelegate = self
            root.present(gc, animated: true)
        }
    }

    public func presentAchievements() {
        guard isAuthenticated else { return }
        Task { @MainActor in
            guard let root = Self.topViewController() else { return }
            let gc = GKGameCenterViewController(state: .achievements)
            gc.gameCenterDelegate = self
            root.present(gc, animated: true)
        }
    }

    public func challengeFriends(leaderboardID: String, message: String) {
        guard isAuthenticated else { return }
        // Prefer modern Activities / share when available; fall back to leaderboard UI.
        presentLeaderboard(id: leaderboardID)
        _ = message
    }

    @MainActor
    private static func topViewController(
        base: UIViewController? = nil
    ) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

extension GameCenterService: GKGameCenterControllerDelegate {
    public nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
#else

/// Stub when GameKit is unavailable (Linux CI / macOS package tests).
public final class GameCenterService: GameCenterServing, @unchecked Sendable {
    public static let shared = GameCenterService()
    private let mock = MockGameCenter()
    public var isAuthenticated: Bool { mock.isAuthenticated }
    public var localPlayerID: String? { mock.localPlayerID }
    public var localDisplayName: String? { mock.localDisplayName }
    private init() {}
    public func authenticate(completion: (@Sendable (Bool) -> Void)?) { mock.authenticate(completion: completion) }
    public func setAccessPointVisible(_ visible: Bool, showHighlights: Bool) {
        mock.setAccessPointVisible(visible, showHighlights: showHighlights)
    }
    public func submitScore(_ score: Int, leaderboardID: String) { mock.submitScore(score, leaderboardID: leaderboardID) }
    public func reportAchievement(id: String, percentComplete: Double) {
        mock.reportAchievement(id: id, percentComplete: percentComplete)
    }
    public func presentLeaderboard(id: String?) { mock.presentLeaderboard(id: id) }
    public func presentAchievements() { mock.presentAchievements() }
    public func challengeFriends(leaderboardID: String, message: String) {
        mock.challengeFriends(leaderboardID: leaderboardID, message: message)
    }
}
#endif
