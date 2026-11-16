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

    func testTitleArtIsNeonCityBandit() {
        XCTAssertFalse(TitleArt.logoCandidates.isEmpty)
        XCTAssertEqual(TitleArt.logoCandidates.first, "ui/logo_neon_city_bandit@1024")
        XCTAssertEqual(TitleArt.displayTitle, "The Neon City Bandit")
        XCTAssertTrue(TitleArt.fallbackWordmark.contains("BANDIT"))
        XCTAssertFalse(TitleArt.displayTitle.localizedCaseInsensitiveContains("Trash Panda"))
        XCTAssertFalse(TitleArt.displayTitle.localizedCaseInsensitiveContains("Magpie"))
        XCTAssertTrue(TitleArt.assetCredits.contains("null-painter-error"))
        XCTAssertTrue(TitleArt.assetCredits.localizedCaseInsensitiveContains("CC-BY"))
    }
    #endif
}
