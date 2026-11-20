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
        wash.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.1, alpha: 0.92)
        wash.strokeColor = .clear
        wash.name = "mapWash"
        root.addChild(wash)

        // Stylized neon city board (not a flat button list).
        let boardW = min(340, size.width * 0.86)
        let boardH = min(420, size.height * 0.58)
        let board = SKShapeNode(rectOf: CGSize(width: boardW, height: boardH), cornerRadius: 18)
        board.fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.96)
        board.strokeColor = ArtCatalog.neonCyan
        board.lineWidth = 2
        board.glowWidth = 2
        board.name = "mapBoard"
        board.position = CGPoint(x: 0, y: 10)
        root.addChild(board)

        // Higgsfield city map under the district nodes when present.
        if let mapTex = ArtCatalog.downsampledTexture(
            relative: "sprites/library/map/city-map",
            maxPixel: 768
        ) {
            let art = SKSpriteNode(texture: mapTex)
            let fit = min((boardW - 24) / max(art.size.width, 1), (boardH - 24) / max(art.size.height, 1))
            art.setScale(fit)
            art.alpha = 0.55
            art.zPosition = 0
            art.name = "cityMapArt"
            board.addChild(art)
        }

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "NEON CITY"
        title.fontSize = 26
        title.fontColor = ArtCatalog.neonCyan
        title.position = CGPoint(x: 0, y: size.height * 0.36)
        title.name = "mapTitle"
        root.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = "District map"
        sub.fontSize = 13
        sub.fontColor = ArtCatalog.neonPink
        sub.position = CGPoint(x: 0, y: size.height * 0.31)
        sub.name = "mapSub"
        root.addChild(sub)

        // Node positions on the board (relative path through the city).
        let layout: [(DistrictID, CGPoint)] = [
            (.neonDocks, CGPoint(x: -90, y: -110)),
            (.arcadeRow, CGPoint(x: 70, y: -40)),
            (.rooftops, CGPoint(x: -40, y: 50)),
            (.sewerGrid, CGPoint(x: 85, y: 110)),
        ]

        // Glowing path polyline between districts (draw before nodes).
        for i in 0..<(layout.count - 1) {
            let a = layout[i].1
            let b = layout[i + 1].1
            let unlocked = progress.isUnlocked(layout[i].0) && progress.isUnlocked(layout[i + 1].0)
            let path = CGMutablePath()
            path.move(to: a)
            let mid = CGPoint(x: (a.x + b.x) * 0.5 + (i % 2 == 0 ? 24 : -24), y: (a.y + b.y) * 0.5)
            path.addQuadCurve(to: b, control: mid)
            let line = SKShapeNode(path: path)
            line.strokeColor = unlocked
                ? ArtCatalog.neonLime.withAlphaComponent(0.85)
                : ArtCatalog.neonPink.withAlphaComponent(0.25)
            line.lineWidth = unlocked ? 3 : 1.5
            line.glowWidth = unlocked ? 1.5 : 0
            line.fillColor = .clear
            line.zPosition = 1
            line.name = "mapPath\(i)"
            board.addChild(line)
        }

        for (d, pos) in layout {
            let unlocked = progress.isUnlocked(d)
            let node = SKShapeNode(circleOfRadius: unlocked ? 22 : 18)
            node.name = "district_\(d.rawValue)"
            node.position = pos
            node.zPosition = 2
            node.fillColor = unlocked
                ? SKColor(red: 0.08, green: 0.12, blue: 0.2, alpha: 0.95)
                : SKColor(red: 0.06, green: 0.05, blue: 0.1, alpha: 0.55)
            node.strokeColor = unlocked ? ArtCatalog.neonLime : ArtCatalog.neonPink.withAlphaComponent(0.35)
            node.lineWidth = 2.5
            node.glowWidth = unlocked ? 2 : 0
            node.alpha = unlocked ? 1 : 0.45
            board.addChild(node)

            if unlocked {
                node.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.group([
                        SKAction.fadeAlpha(to: 0.75, duration: 0.7),
                        SKAction.scale(to: 1.08, duration: 0.7),
                    ]),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 1.0, duration: 0.7),
                        SKAction.scale(to: 1.0, duration: 0.7),
                    ]),
                ])), withKey: "pulse")
            }

            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = unlocked ? d.displayName : "🔒"
            label.fontSize = unlocked ? 11 : 14
            label.fontColor = unlocked ? .white : SKColor(white: 0.5, alpha: 1)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: unlocked ? -34 : 0)
            label.name = "districtLabel"
            node.addChild(label)

            if d == .neonDocks {
                let medals = progress.medalsByLevel[ProgressStore.neonDocksLevelID]?.count ?? 0
                let m = SKLabelNode(fontNamed: "AvenirNext-Bold")
                m.text = String(repeating: "★", count: medals) + String(repeating: "☆", count: max(0, 3 - medals))
                m.fontSize = 11
                m.fontColor = ArtCatalog.neonOrange
                m.verticalAlignmentMode = .center
                m.position = CGPoint(x: 0, y: 34)
                m.name = "districtMedals"
                node.addChild(m)
            }
        }

        // Decorative skyline ticks on the board.
        for i in 0..<7 {
            let tick = SKShapeNode(rectOf: CGSize(width: 3, height: CGFloat(8 + (i % 3) * 10)), cornerRadius: 1)
            tick.fillColor = ArtCatalog.neonCyan.withAlphaComponent(0.25)
            tick.strokeColor = .clear
            tick.position = CGPoint(x: -120 + CGFloat(i) * 40, y: 160)
            tick.zPosition = 0
            board.addChild(tick)
        }

        // Raccoon sits on the unlocked Neon Docks node (not floating under the board).
        if let docks = board.childNode(withName: "district_neon_docks") {
            let mascot = ArtCatalog.makeBanditFrontMascot(size: CGSize(width: 48, height: 48))
            mascot.name = "mapBandit"
            mascot.position = CGPoint(x: 0, y: 28)
            mascot.zPosition = 5
            docks.addChild(mascot)
        }

        // Soft skyline silhouette behind the district path.
        for i in 0..<9 {
            let h = CGFloat(18 + (i % 4) * 14)
            let bil = SKShapeNode(rectOf: CGSize(width: 18, height: h), cornerRadius: 2)
            bil.fillColor = SKColor(red: 0.08, green: 0.07, blue: 0.18, alpha: 0.9)
            bil.strokeColor = ArtCatalog.neonPink.withAlphaComponent(0.25)
            bil.lineWidth = 0.6
            bil.position = CGPoint(x: -130 + CGFloat(i) * 32, y: -175 + h * 0.5)
            bil.zPosition = 0
            bil.name = "mapSkyline\(i)"
            board.addChild(bil)
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
        wash.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.1, alpha: 0.94)
        wash.strokeColor = .clear
        wash.name = "dailyWash"
        root.addChild(wash)

        let board = SKShapeNode(rectOf: CGSize(width: min(340, size.width * 0.86), height: min(460, size.height * 0.62)), cornerRadius: 18)
        board.fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.97)
        board.strokeColor = ArtCatalog.neonLime
        board.lineWidth = 2.2
        board.glowWidth = 2
        board.name = "dailyBoard"
        board.position = CGPoint(x: 0, y: 8)
        root.addChild(board)

        // Neon corner ticks for identity.
        for (dx, dy) in [(-1, 1), (1, 1), (-1, -1), (1, -1)] as [(CGFloat, CGFloat)] {
            let tick = SKShapeNode(rectOf: CGSize(width: 18, height: 3), cornerRadius: 1)
            tick.fillColor = dx < 0 ? ArtCatalog.neonPink : ArtCatalog.neonCyan
            tick.strokeColor = .clear
            tick.position = CGPoint(x: dx * 145, y: dy * 195)
            board.addChild(tick)
        }

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "DAILY HEIST"
        title.fontSize = 28
        title.fontColor = ArtCatalog.neonLime
        title.position = CGPoint(x: 0, y: 175)
        title.name = "dailyTitle"
        board.addChild(title)

        let day = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        day.text = dayKey
        day.fontSize = 15
        day.fontColor = ArtCatalog.neonCyan
        day.position = CGPoint(x: 0, y: 145)
        day.name = "dailyDay"
        board.addChild(day)

        let blurb = SKLabelNode(fontNamed: "AvenirNext-Medium")
        blurb.text = "Same heist for everyone"
        blurb.fontSize = 13
        blurb.fontColor = SKColor(white: 0.88, alpha: 1)
        blurb.position = CGPoint(x: 0, y: 118)
        blurb.name = "dailyBlurb"
        board.addChild(blurb)

        let seed = ProgressStore.dailySeed(dayKey: dayKey)
        let seedLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        seedLabel.text = String(format: "Seed #%04X", seed & 0xFFFF)
        seedLabel.fontSize = 12
        seedLabel.fontColor = ArtCatalog.neonPink
        seedLabel.position = CGPoint(x: 0, y: 96)
        seedLabel.name = "dailySeed"
        board.addChild(seedLabel)

        let best = progress.bestSecondsByLevel[ProgressStore.dailyLevelID]
        let bestLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bestLabel.text = best.map { String(format: "Your best  %.0fs", $0) } ?? "Your best  —"
        bestLabel.fontSize = 15
        bestLabel.fontColor = ArtCatalog.neonOrange
        bestLabel.position = CGPoint(x: 0, y: 55)
        bestLabel.name = "dailyBest"
        board.addChild(bestLabel)

        let streak = SKLabelNode(fontNamed: "AvenirNext-Bold")
        streak.text = "Streak \(progress.dailyClears)"
        streak.fontSize = 14
        streak.fontColor = ArtCatalog.neonCyan
        streak.position = CGPoint(x: 0, y: 30)
        streak.name = "dailyClears"
        board.addChild(streak)

        let boardStub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        boardStub.text = progress.bestDailyScore > 0
            ? "Best today  \(progress.bestDailyScore) pts"
            : "Game Center board · time + loot + clean"
        boardStub.fontSize = 11
        boardStub.fontColor = SKColor(white: 0.7, alpha: 1)
        boardStub.position = CGPoint(x: 0, y: 8)
        boardStub.name = "dailyLeaderboard"
        board.addChild(boardStub)

        let mascot = ArtCatalog.makeBanditFrontMascot(size: CGSize(width: 56, height: 56))
        mascot.name = "dailyBandit"
        mascot.position = CGPoint(x: 0, y: -42)
        board.addChild(mascot)

        let play = makeChromeButton(title: "RUN HEIST", color: ArtCatalog.neonLime, name: "dailyPlay", wide: true)
        play.position = CGPoint(x: 0, y: -100)
        board.addChild(play)

        let raceBest = makeChromeButton(title: "RACE #1", color: ArtCatalog.neonCyan, name: "dailyRaceBest")
        raceBest.position = CGPoint(x: -70, y: -148)
        board.addChild(raceBest)
        let raceOwn = makeChromeButton(title: "RACE ME", color: ArtCatalog.neonOrange, name: "dailyRaceOwn")
        raceOwn.position = CGPoint(x: 70, y: -148)
        board.addChild(raceOwn)

        let lb = makeChromeButton(title: "BOARD", color: ArtCatalog.neonCyan, name: "dailyLeaderboardBtn")
        lb.position = CGPoint(x: -70, y: -192)
        board.addChild(lb)
        let challenge = makeChromeButton(title: "CHALLENGE", color: ArtCatalog.neonPink, name: "dailyChallenge")
        challenge.position = CGPoint(x: 70, y: -192)
        board.addChild(challenge)

        let back = makeChromeButton(title: "BACK", color: ArtCatalog.neonPink, name: "dailyBack")
        back.position = CGPoint(x: 0, y: -size.height * 0.40)
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

    /// Animate a retention panel in (scale 0.8 ease-out + fade, ~250ms).
    public static func present(_ node: SKNode) {
        node.setScale(0.8)
        node.alpha = 0
        node.isHidden = false
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.24),
            SKAction.scale(to: 1.0, duration: 0.26),
        ])
        appear.timingMode = .easeOut
        node.run(appear)
    }
}
#endif
