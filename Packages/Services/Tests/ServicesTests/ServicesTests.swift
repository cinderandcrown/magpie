// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import XCTest
@testable import Services

final class ServicesTests: XCTestCase {
    func testMockClockReturnsPinnedValue() {
        let clock = MockClock(value: 42)
        XCTAssertEqual(clock.now(), 42)
        XCTAssertEqual(ServicesInfo.name, "Services")
    }

    func testMockGameCenterAuthAndSubmit() {
        let gc = MockGameCenter()
        let exp = expectation(description: "auth")
        gc.authenticate { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(gc.isAuthenticated)
        gc.submitScore(1200, leaderboardID: GameCenterIDs.dailyHeist)
        gc.reportAchievement(id: GameCenterIDs.firstHeist, percentComplete: 100)
        XCTAssertEqual(gc.submitted.first?.1, GameCenterIDs.dailyHeist)
        XCTAssertEqual(gc.achievements.first?.0, GameCenterIDs.firstHeist)
    }

    func testMockGhostStoreKeepsBest() async {
        let store = MockGhostStore()
        let day = "2026-11-20"
        let low = GhostRun(
            dayKey: day, playerID: "p1", displayName: "A",
            score: 100, seconds: 80, samples: []
        )
        let high = GhostRun(
            dayKey: day, playerID: "p1", displayName: "A",
            score: 500, seconds: 50, samples: [GhostSample(t: 0, x: 1, y: 2, facing: 1)]
        )
        await store.saveOwnBest(low)
        await store.saveOwnBest(high)
        let best = await store.loadOwnBest(dayKey: day)
        XCTAssertEqual(best?.score, 500)
        XCTAssertEqual(best?.samples.count, 1)
        let world = await store.loadWorldBest(dayKey: day)
        XCTAssertEqual(world?.score, 500)
    }

    func testCloudKitGhostsDefaultOffAndFactoryUsesMock() {
        XCTAssertFalse(FeatureFlags.cloudKitGhostsEnabled)
        let store = GhostStoreFactory.make()
        XCTAssertTrue(store is MockGhostStore)
    }

    func testCloudKitGhostStoreSharedDoesNotRequireContainer() async {
        // Touching shared / saving must not require a CKContainer when the flag is off.
        let store = CloudKitGhostStore.shared
        let day = "2026-11-20"
        await store.saveOwnBest(
            GhostRun(dayKey: day, playerID: "p1", displayName: "A", score: 1, seconds: 1, samples: [])
        )
        let best = await store.loadOwnBest(dayKey: day)
        XCTAssertEqual(best?.score, 1)
    }
}
