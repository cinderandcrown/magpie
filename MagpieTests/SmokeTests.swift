// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore
import Services
import XCTest

final class SmokeTests: XCTestCase {
    func testCoreAndServicesLink() {
        XCTAssertEqual(ModuleInfo.name, "GameCore")
        XCTAssertEqual(ServicesInfo.name, "Services")
    }
}
