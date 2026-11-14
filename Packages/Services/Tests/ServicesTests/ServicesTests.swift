// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import XCTest
@testable import Services

final class ServicesTests: XCTestCase {
    func testMockClockReturnsPinnedValue() {
        let clock = MockClock(value: 42)
        XCTAssertEqual(clock.now(), 42)
        XCTAssertEqual(ServicesInfo.name, "Services")
    }
}
