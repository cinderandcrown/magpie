// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Drawn-in-code art. No Sly Cooper look: no cane, no top-hat, no blue/gold.
public enum ArtCatalog {
    public static let nightSky = SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 1)
    public static let asphalt = SKColor(red: 0.12, green: 0.11, blue: 0.18, alpha: 1)
    public static let sidewalk = SKColor(red: 0.18, green: 0.17, blue: 0.26, alpha: 1)
    public static let neonPink = SKColor(red: 1.0, green: 0.28, blue: 0.62, alpha: 1)
    public static let neonCyan = SKColor(red: 0.15, green: 0.92, blue: 0.95, alpha: 1)
    public static let neonLime = SKColor(red: 0.55, green: 0.98, blue: 0.35, alpha: 1)
    public static let neonOrange = SKColor(red: 1.0, green: 0.55, blue: 0.18, alpha: 1)
    public static let water = SKColor(red: 0.08, green: 0.28, blue: 0.48, alpha: 1)
    public static let wall = SKColor(red: 0.22, green: 0.16, blue: 0.32, alpha: 1)
    public static let crate = SKColor(red: 0.55, green: 0.32, blue: 0.18, alpha: 1)
    public static let raccoonFur = SKColor(red: 0.42, green: 0.34, blue: 0.30, alpha: 1)
    public static let raccoonBelly = SKColor(red: 0.72, green: 0.66, blue: 0.58, alpha: 1)
    public static let maskBlack = SKColor(red: 0.08, green: 0.07, blue: 0.09, alpha: 1)
    public static let shinyGold = SKColor(red: 1.0, green: 0.86, blue: 0.25, alpha: 1)
    public static let mopGray = SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)

    /// Scruffy masked raccoon — junk-gadget chaos, not gentleman thief.
    public static func makeBanditNode() -> SKNode {
        let root = SKNode()
        root.name = "bandit"

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 28, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        shadow.name = "shadow"
        root.addChild(shadow)

        let body = SKNode()
        body.name = "body"
        root.addChild(body)

        let torso = SKShapeNode(rectOf: CGSize(width: 22, height: 26), cornerRadius: 8)
        torso.fillColor = raccoonFur
        torso.strokeColor = SKColor(white: 0, alpha: 0.25)
        torso.lineWidth = 1
        body.addChild(torso)

        let belly = SKShapeNode(ellipseOf: CGSize(width: 14, height: 16))
        belly.fillColor = raccoonBelly
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 0, y: -2)
        body.addChild(belly)

        let head = SKShapeNode(ellipseOf: CGSize(width: 24, height: 20))
        head.fillColor = raccoonFur
        head.strokeColor = SKColor(white: 0, alpha: 0.25)
        head.position = CGPoint(x: 0, y: 18)
        body.addChild(head)

        let mask = SKShapeNode(rectOf: CGSize(width: 22, height: 8), cornerRadius: 3)
        mask.fillColor = maskBlack
        mask.strokeColor = .clear
        mask.position = CGPoint(x: 0, y: 18)
        mask.name = "mask"
        body.addChild(mask)

        let eyeL = SKShapeNode(circleOfRadius: 2.2)
        eyeL.fillColor = .white
        eyeL.strokeColor = .clear
        eyeL.position = CGPoint(x: -5, y: 18)
        body.addChild(eyeL)
        let pupilL = SKShapeNode(circleOfRadius: 1.1)
        pupilL.fillColor = neonLime
        pupilL.strokeColor = .clear
        pupilL.position = eyeL.position
        body.addChild(pupilL)

        let eyeR = SKShapeNode(circleOfRadius: 2.2)
        eyeR.fillColor = .white
        eyeR.strokeColor = .clear
        eyeR.position = CGPoint(x: 5, y: 18)
        body.addChild(eyeR)
        let pupilR = SKShapeNode(circleOfRadius: 1.1)
        pupilR.fillColor = neonLime
        pupilR.strokeColor = .clear
        pupilR.position = eyeR.position
        body.addChild(pupilR)

        // Ringed tail (scruffy, not sleek)
        let tail = SKNode()
        tail.name = "tail"
        tail.position = CGPoint(x: -14, y: -6)
        for i in 0..<5 {
            let ring = SKShapeNode(circleOfRadius: 4.5 - Double(i) * 0.35)
            ring.fillColor = i % 2 == 0 ? raccoonFur : maskBlack
            ring.strokeColor = .clear
            ring.position = CGPoint(x: -CGFloat(i) * 5, y: CGFloat(i) * 2)
            tail.addChild(ring)
        }
        body.addChild(tail)

        // Ears
        for dx in [-8.0, 8.0] {
            let ear = SKShapeNode(ellipseOf: CGSize(width: 7, height: 10))
            ear.fillColor = raccoonFur
            ear.strokeColor = .clear
            ear.position = CGPoint(x: dx, y: 28)
            body.addChild(ear)
        }

        // Tiny junk magnet glove (not a cane)
        let glove = SKShapeNode(rectOf: CGSize(width: 8, height: 6), cornerRadius: 2)
        glove.fillColor = neonCyan
        glove.strokeColor = .clear
        glove.position = CGPoint(x: 14, y: -4)
        glove.name = "glove"
        body.addChild(glove)

        return root
    }

    public static func makeShinyNode() -> SKNode {
        let n = SKShapeNode(circleOfRadius: 7)
        n.fillColor = shinyGold
        n.strokeColor = neonOrange
        n.lineWidth = 2
        n.glowWidth = 2
        let spark = SKShapeNode(rectOf: CGSize(width: 3, height: 10), cornerRadius: 1)
        spark.fillColor = .white
        spark.strokeColor = .clear
        spark.zRotation = .pi / 5
        n.addChild(spark)
        n.name = "shiny"
        return n
    }

    public static func makeDummyNode() -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: 20, height: 24), cornerRadius: 4)
        body.fillColor = mopGray
        body.strokeColor = neonCyan
        body.lineWidth = 1.5
        n.addChild(body)
        let eye = SKShapeNode(circleOfRadius: 3)
        eye.fillColor = neonPink
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 0, y: 4)
        n.addChild(eye)
        let brush = SKShapeNode(rectOf: CGSize(width: 26, height: 6), cornerRadius: 2)
        brush.fillColor = neonCyan
        brush.strokeColor = .clear
        brush.position = CGPoint(x: 0, y: -14)
        n.addChild(brush)
        n.name = "dummy"
        return n
    }

    public static func makeStashNode() -> SKNode {
        let n = SKShapeNode(ellipseOf: CGSize(width: 36, height: 18))
        n.fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.35, alpha: 0.85)
        n.strokeColor = neonLime
        n.lineWidth = 2
        n.glowWidth = 3
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "STASH"
        label.fontSize = 9
        label.fontColor = neonLime
        label.verticalAlignmentMode = .center
        n.addChild(label)
        n.name = "stash"
        return n
    }
}
#endif
