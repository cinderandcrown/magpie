// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// Lightweight, skippable story overlays — intro comic, district cards, crew toast.
@MainActor
public enum StoryChrome {
    public static func makeIntroComic(
        size: CGSize,
        story: StoryCatalog,
        panelIndex: Int
    ) -> SKNode {
        let root = SKNode()
        root.name = "introComic"

        let wash = SKShapeNode(rectOf: CGSize(width: size.width * 2.2, height: size.height * 2.2))
        wash.fillColor = SKColor(red: 0.02, green: 0.015, blue: 0.08, alpha: 0.94)
        wash.strokeColor = .clear
        wash.name = "introWash"
        root.addChild(wash)

        let panel = story.introPanels.indices.contains(panelIndex)
            ? story.introPanels[panelIndex]
            : StoryCatalog.IntroPanel(id: "empty", caption: "", artHint: "")

        let frame = SKShapeNode(rectOf: CGSize(width: min(340, size.width * 0.88), height: min(420, size.height * 0.62)), cornerRadius: 14)
        frame.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.14, alpha: 0.98)
        frame.strokeColor = ArtCatalog.neonCyan
        frame.lineWidth = 2.5
        frame.glowWidth = 1.5
        frame.name = "introFrame"
        frame.position = CGPoint(x: 0, y: 18)
        root.addChild(frame)

        // Art: spriterrific bandit / mop / skyline layered with a light zoom.
        let art = SKNode()
        art.name = "introArt"
        art.position = CGPoint(x: 0, y: 36)
        frame.addChild(art)

        if let far = ArtCatalog.background(.farSkyline, height: 220, maxPixel: 640) {
            far.alpha = 0.85
            far.position = CGPoint(x: 0, y: 40)
            far.setScale(1.05)
            art.addChild(far)
        }
        if let mid = ArtCatalog.background(.midBuildings, height: 180, maxPixel: 640) {
            mid.alpha = 0.9
            mid.position = CGPoint(x: 0, y: 10)
            art.addChild(mid)
        }

        switch panel.id {
        case "raid", "bagged":
            if let mop = ArtCatalog.texture(.mopAlert) ?? ArtCatalog.texture(.mopIdle) {
                let m = SKSpriteNode(texture: mop, size: CGSize(width: 96, height: 96))
                m.position = CGPoint(x: 70, y: -20)
                art.addChild(m)
            }
            fallthrough
        default:
            let bandit = ArtCatalog.makeBanditFrontMascot(size: CGSize(width: 110, height: 110))
            bandit.position = CGPoint(x: panel.id == "raid" ? -50 : 0, y: -28)
            art.addChild(bandit)
        }

        art.setScale(0.92)
        art.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.45),
            SKAction.moveBy(x: 0, y: 6, duration: 0.45),
        ]))

        let caption = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        caption.text = panel.caption
        caption.fontSize = 14
        caption.fontColor = .white
        caption.preferredMaxLayoutWidth = min(300, size.width * 0.78)
        caption.numberOfLines = 3
        caption.verticalAlignmentMode = .center
        caption.horizontalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: -150)
        caption.name = "introCaption"
        frame.addChild(caption)

        let progress = SKLabelNode(fontNamed: "AvenirNext-Medium")
        progress.text = "\(panelIndex + 1) / \(max(1, story.introPanels.count))"
        progress.fontSize = 12
        progress.fontColor = ArtCatalog.neonCyan
        progress.position = CGPoint(x: 0, y: -size.height * 0.38)
        progress.name = "introProgress"
        root.addChild(progress)

        let tap = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tap.text = "TAP"
        tap.fontSize = 13
        tap.fontColor = ArtCatalog.neonLime
        tap.position = CGPoint(x: -40, y: -size.height * 0.44)
        tap.name = "introAdvance"
        root.addChild(tap)

        let skip = RetentionChrome.makeChromeButton(title: "SKIP", color: ArtCatalog.neonPink, name: "introSkip")
        skip.position = CGPoint(x: 70, y: -size.height * 0.44)
        skip.setScale(0.85)
        root.addChild(skip)

        return root
    }

    public static func makeDistrictCard(
        size: CGSize,
        district: DistrictID,
        story: StoryCatalog
    ) -> SKNode {
        let root = SKNode()
        root.name = "districtCard"

        let wash = SKShapeNode(rectOf: CGSize(width: size.width * 2.2, height: size.height * 2.2))
        wash.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.1, alpha: 0.72)
        wash.strokeColor = .clear
        root.addChild(wash)

        let beat = story.district(id: district)
        let card = SKShapeNode(rectOf: CGSize(width: min(320, size.width * 0.86), height: 150), cornerRadius: 14)
        card.fillColor = SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 0.96)
        card.strokeColor = ArtCatalog.neonLime
        card.lineWidth = 2
        card.glowWidth = 1.5
        card.name = "districtCardBody"
        root.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = beat?.title ?? district.displayName
        title.fontSize = 26
        title.fontColor = ArtCatalog.neonLime
        title.position = CGPoint(x: 0, y: 28)
        title.name = "districtTitle"
        card.addChild(title)

        let flavor = SKLabelNode(fontNamed: "AvenirNext-Medium")
        flavor.text = beat?.flavor ?? ""
        flavor.fontSize = 13
        flavor.fontColor = SKColor(white: 0.9, alpha: 1)
        flavor.preferredMaxLayoutWidth = min(280, size.width * 0.75)
        flavor.numberOfLines = 3
        flavor.verticalAlignmentMode = .center
        flavor.horizontalAlignmentMode = .center
        flavor.position = CGPoint(x: 0, y: -18)
        flavor.name = "districtFlavor"
        card.addChild(flavor)

        let tap = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tap.text = "TAP TO HEIST"
        tap.fontSize = 12
        tap.fontColor = ArtCatalog.neonCyan
        tap.position = CGPoint(x: 0, y: -size.height * 0.28)
        tap.name = "districtCardAdvance"
        root.addChild(tap)

        card.setScale(0.86)
        card.alpha = 0
        card.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.22),
            SKAction.scale(to: 1.0, duration: 0.26),
        ]))

        return root
    }

    public static func makeCrewToast(name: String, line: String) -> SKNode {
        let root = SKNode()
        root.name = "crewToast"
        let card = SKShapeNode(rectOf: CGSize(width: 260, height: 72), cornerRadius: 12)
        card.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.1, alpha: 0.94)
        card.strokeColor = ArtCatalog.neonLime
        card.lineWidth = 2
        root.addChild(card)
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = "FREED \(name.uppercased())!"
        t.fontSize = 16
        t.fontColor = ArtCatalog.neonLime
        t.position = CGPoint(x: 0, y: 10)
        card.addChild(t)
        let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
        l.text = line
        l.fontSize = 11
        l.fontColor = .white
        l.preferredMaxLayoutWidth = 230
        l.numberOfLines = 2
        l.verticalAlignmentMode = .center
        l.position = CGPoint(x: 0, y: -14)
        card.addChild(l)
        return root
    }
}
#endif
