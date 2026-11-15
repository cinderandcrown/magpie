// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import GameCore
import SpriteKit
import UIKit

/// District map + Daily Heist chrome builders (SpriteKit overlays — no UIKit sheets).
@MainActor
public enum RetentionChrome {
    public static func makeDistrictMap(size: CGSize, progress: PlayerProgress) -> SKNode {
        let root = SKNode()
        root.name = "districtMap"

        let wash = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        wash.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.1, alpha: 0.88)
        wash.strokeColor = .clear
        wash.name = "mapWash"
        root.addChild(wash)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "NEON CITY"
        title.fontSize = 28
        title.fontColor = ArtCatalog.neonCyan
        title.position = CGPoint(x: 0, y: size.height * 0.34)
        title.name = "mapTitle"
        root.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = "Pick a district"
        sub.fontSize = 14
        sub.fontColor = ArtCatalog.neonPink
        sub.position = CGPoint(x: 0, y: size.height * 0.28)
        sub.name = "mapSub"
        root.addChild(sub)

        let districts = DistrictID.allCases
        let startY = size.height * 0.12
        for (i, d) in districts.enumerated() {
            let unlocked = progress.isUnlocked(d)
            let row = SKShapeNode(rectOf: CGSize(width: min(320, size.width * 0.78), height: 52), cornerRadius: 12)
            row.name = "district_\(d.rawValue)"
            row.fillColor = SKColor(red: 0.07, green: 0.05, blue: 0.16, alpha: unlocked ? 0.95 : 0.55)
            row.strokeColor = unlocked ? ArtCatalog.neonLime : ArtCatalog.neonPink.withAlphaComponent(0.35)
            row.lineWidth = 2
            row.glowWidth = unlocked ? 1.5 : 0
            row.position = CGPoint(x: 0, y: startY - CGFloat(i) * 62)
            root.addChild(row)

            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = unlocked ? d.displayName : "🔒 \(d.displayName)"
            label.fontSize = 16
            label.fontColor = unlocked ? .white : SKColor(white: 0.55, alpha: 1)
            label.verticalAlignmentMode = .center
            label.name = "districtLabel"
            row.addChild(label)

            if d == .neonDocks {
                let medals = progress.medalsByLevel[ProgressStore.neonDocksLevelID]?.count ?? 0
                let m = SKLabelNode(fontNamed: "AvenirNext-Bold")
                m.text = String(repeating: "★", count: medals) + String(repeating: "☆", count: max(0, 3 - medals))
                m.fontSize = 12
                m.fontColor = ArtCatalog.neonOrange
                m.verticalAlignmentMode = .center
                m.horizontalAlignmentMode = .right
                m.position = CGPoint(x: min(140, size.width * 0.32), y: 0)
                m.name = "districtMedals"
                row.addChild(m)
            }
        }

        let back = makeChromeButton(title: "BACK", color: ArtCatalog.neonPink, name: "mapBack")
        back.position = CGPoint(x: 0, y: -size.height * 0.38)
        root.addChild(back)
        return root
    }

    public static func makeDailyHeist(size: CGSize, dayKey: String, progress: PlayerProgress) -> SKNode {
        let root = SKNode()
        root.name = "dailyHeist"

        let wash = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        wash.fillColor = SKColor(red: 0.04, green: 0.02, blue: 0.12, alpha: 0.9)
        wash.strokeColor = .clear
        wash.name = "dailyWash"
        root.addChild(wash)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "DAILY HEIST"
        title.fontSize = 30
        title.fontColor = ArtCatalog.neonLime
        title.position = CGPoint(x: 0, y: size.height * 0.22)
        title.name = "dailyTitle"
        root.addChild(title)

        let day = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        day.text = dayKey
        day.fontSize = 15
        day.fontColor = ArtCatalog.neonCyan
        day.position = CGPoint(x: 0, y: size.height * 0.14)
        day.name = "dailyDay"
        root.addChild(day)

        let blurb = SKLabelNode(fontNamed: "AvenirNext-Medium")
        blurb.text = "Same rooftop. Same seed. Beat the city."
        blurb.fontSize = 14
        blurb.fontColor = SKColor(white: 0.9, alpha: 1)
        blurb.position = CGPoint(x: 0, y: size.height * 0.06)
        blurb.name = "dailyBlurb"
        root.addChild(blurb)

        let clears = SKLabelNode(fontNamed: "AvenirNext-Bold")
        clears.text = "Clears \(progress.dailyClears)"
        clears.fontSize = 16
        clears.fontColor = ArtCatalog.neonOrange
        clears.position = CGPoint(x: 0, y: -10)
        clears.name = "dailyClears"
        root.addChild(clears)

        let play = makeChromeButton(title: "RUN HEIST", color: ArtCatalog.neonLime, name: "dailyPlay", wide: true)
        play.position = CGPoint(x: 0, y: -70)
        root.addChild(play)

        let back = makeChromeButton(title: "BACK", color: ArtCatalog.neonPink, name: "dailyBack")
        back.position = CGPoint(x: 0, y: -130)
        root.addChild(back)
        return root
    }

    public static func makeChromeButton(title: String, color: SKColor, name: String, wide: Bool = false) -> SKShapeNode {
        let size = wide ? CGSize(width: 220, height: 48) : CGSize(width: 140, height: 40)
        let b = SKShapeNode(rectOf: size, cornerRadius: wide ? 12 : 10)
        b.fillColor = color.withAlphaComponent(wide ? 0.38 : 0.22)
        b.strokeColor = color
        b.lineWidth = 2
        b.glowWidth = wide ? 1.5 : 1
        b.name = name
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = title
        t.fontSize = wide ? 17 : 14
        t.fontColor = .white
        t.verticalAlignmentMode = .center
        t.name = name
        b.addChild(t)
        return b
    }

    /// Animate a retention panel in (scale 0.8 ease-out + fade).
    public static func present(_ node: SKNode) {
        node.setScale(0.8)
        node.alpha = 0
        node.isHidden = false
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.26),
            SKAction.scale(to: 1.0, duration: 0.3),
        ])
        appear.timingMode = .easeOut
        node.run(appear)
    }
}
#endif
