// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import XCTest
@testable import GameRender

final class GameRenderTests: XCTestCase {
    func testRenderDependsOnCore() {
        XCTAssertEqual(RenderInfo.name, "GameRender")
        XCTAssertEqual(RenderInfo.dependsOnCore, "GameCore")
    }
}
