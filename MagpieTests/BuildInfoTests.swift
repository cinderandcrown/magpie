// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

import GameRules
import XCTest

final class BuildInfoTests: XCTestCase {
    func testTitleConstantMatchesGameRules() {
        XCTAssertEqual(BuildLabel.title, "MAGPIE")
    }

    func testHopDefaultsArePositive() {
        XCTAssertGreaterThan(HopMotion.defaultLift, 0)
        XCTAssertGreaterThan(HopMotion.defaultDuration, 0)
    }
}
