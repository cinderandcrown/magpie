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
    /// Glow is baked into PNGs; solids stay one visual node (SKTileMap / atlas).
    func testBakedGlowNodeBudget() {
        XCTAssertEqual(ArtCatalog.expectedNodesPerSolidTile, 1)
        XCTAssertGreaterThan(ArtCatalog.paletteMagenta.r, 0.8)
        XCTAssertGreaterThan(ArtCatalog.paletteTeal.b, 0.8)
    }
    #endif
}
