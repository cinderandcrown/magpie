// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore
import XCTest
@testable import GameRender

final class GameRenderTests: XCTestCase {
    func testRenderDependsOnCore() {
        XCTAssertEqual(RenderInfo.dependsOnCore, ModuleInfo.name)
    }

    func testRenderModuleName() {
        XCTAssertEqual(RenderInfo.name, "GameRender")
    }

    #if canImport(SpriteKit) && canImport(UIKit)
    /// Regression for CI 43726848897 jetsam: smoke must refuse 2560 background masters.
    func testSmokeForbidsBackgroundMasters() {
        XCTAssertEqual(ArtCatalog.smokeForbiddenBackgroundKeys.count, 4)
        XCTAssertEqual(ArtCatalog.expectedNodesPerSolidTile, 1)
        XCTAssertTrue(ArtCatalog.smokeForbiddenBackgroundKeys.contains(.farSkyline))
        XCTAssertTrue(ArtCatalog.smokeForbiddenBackgroundKeys.contains(.nearRooftops))
    }
    #endif
}
