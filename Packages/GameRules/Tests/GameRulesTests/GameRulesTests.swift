// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

import XCTest
@testable import GameRules

final class GameRulesTests: XCTestCase {
    func testRunDurationIs180Seconds() {
        XCTAssertEqual(RunRules.durationSeconds, 180)
    }

    func testHeatClampsToZeroThroughFive() {
        XCTAssertEqual(RunRules.Heat.clamped(-3), .zero)
        XCTAssertEqual(RunRules.Heat.clamped(0), .zero)
        XCTAssertEqual(RunRules.Heat.clamped(3), .three)
        XCTAssertEqual(RunRules.Heat.clamped(5), .five)
        XCTAssertEqual(RunRules.Heat.clamped(99), .five)
        XCTAssertEqual(RunRules.Heat.allCases.count, 6)
    }

    func testHeatOrdering() {
        XCTAssertLessThan(RunRules.Heat.zero, RunRules.Heat.five)
    }

    func testHopPeakY() {
        XCTAssertEqual(HopMotion.peakY(startY: 100, lift: 50), 150)
        XCTAssertEqual(HopMotion.peakY(startY: 10, lift: -5), 10)
    }

    func testCanHopOnlyWhenIdle() {
        XCTAssertTrue(HopMotion.canHop(isHopping: false))
        XCTAssertFalse(HopMotion.canHop(isHopping: true))
    }

    func testBuildLabelFormatAndTitle() {
        XCTAssertEqual(BuildLabel.title, "MAGPIE")
        XCTAssertEqual(BuildLabel.text(version: "1.0.0", build: "12.1"), "v1.0.0 (12.1)")
    }
}
