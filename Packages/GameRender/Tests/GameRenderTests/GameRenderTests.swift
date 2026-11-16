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
        XCTAssertEqual(TitleArt.logoCandidates.first, "ui/logo_b1_holo_glass@1024")
        XCTAssertTrue(TitleArt.compactLogoCandidates.contains("ui/logo_b1_holo_glass_compact"))
        XCTAssertEqual(TitleArt.displayTitle, "The Neon City Bandit")
        XCTAssertTrue(TitleArt.fallbackWordmark.contains("BANDIT"))
        XCTAssertFalse(TitleArt.displayTitle.localizedCaseInsensitiveContains("Trash Panda"))
        XCTAssertFalse(TitleArt.displayTitle.localizedCaseInsensitiveContains("Magpie"))
        XCTAssertTrue(TitleArt.assetCredits.contains("Spriterrific"))
        XCTAssertTrue(TitleArt.assetCredits.localizedCaseInsensitiveContains("Cinder"))
    }

    func testTitleButtonFramesNonOverlappingHelper() {
        let a = CGRect(x: 0, y: 0, width: 40, height: 20)
        let b = CGRect(x: 50, y: 0, width: 40, height: 20)
        let c = CGRect(x: 30, y: 0, width: 40, height: 20)
        XCTAssertTrue(ArtCatalog.framesNonOverlapping([a, b], gap: 4))
        XCTAssertFalse(ArtCatalog.framesNonOverlapping([a, c], gap: 4))
    }
    #endif
}
