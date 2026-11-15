// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore
import Services
import XCTest

final class SmokeTests: XCTestCase {
    func testCoreAndServicesLink() {
        XCTAssertEqual(ModuleInfo.name, "GameCore")
        let clock = MockClock(now: 1)
        XCTAssertEqual(clock.now, 1)
    }

    func testNeonAlleyMapLoads() throws {
        let map = try NeonAlleyMap.load()
        XCTAssertNotNil(map.findFirst(.start))
        XCTAssertNotNil(map.findFirst(.stash))
    }
}
