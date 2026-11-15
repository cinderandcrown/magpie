// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Visuals keyed for Fire Fox swap. Prefers named textures; otherwise draws rich placeholders
/// (not gray boxes — neon city characters with silhouette detail).
public enum ArtCatalog {
    public static let nightSky = SKColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 1)
    public static let neonPink = SKColor(red: 1.0, green: 0.28, blue: 0.62, alpha: 1)
    public static let neonCyan = SKColor(red: 0.15, green: 0.92, blue: 0.95, alpha: 1)
    public static let neonLime = SKColor(red: 0.55, green: 0.98, blue: 0.35, alpha: 1)
    public static let neonOrange = SKColor(red: 1.0, green: 0.55, blue: 0.18, alpha: 1)
    public static let asphalt = SKColor(red: 0.14, green: 0.12, blue: 0.22, alpha: 1)
    public static let raccoonFur = SKColor(red: 0.45, green: 0.36, blue: 0.30, alpha: 1)
    public static let raccoonBelly = SKColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1)
    public static let maskBlack = SKColor(red: 0.06, green: 0.05, blue: 0.07, alpha: 1)

    public static func texture(for key: AssetKey) -> SKTexture? {
        let name = AssetManifest.shared.imageName(for: key)
        if UIImage(named: name) != nil {
            return SKTexture(imageNamed: name)
        }
        for ext in ["png", "jpg", "jpeg", "webp"] {
            if let url = AssetManifest.shared.url(for: key, ext: ext),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                return SKTexture(image: img)
            }
        }
        return nil
    }

    public static func makeBandit(anim: String = "idle") -> SKNode {
        let root = SKNode()
        root.name = "bandit"

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 30, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.4)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        shadow.name = "shadow"
        root.addChild(shadow)

        let body = SKNode()
        body.name = "body"
        root.addChild(body)

        let keys: [AssetKey] = [.raccoonIdle0, .raccoonRun0, .raccoonJump0, .raccoonPounce0]
        if let tex = keys.compactMap({ texture(for: $0) }).first {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 48, height: 48))
            sprite.name = "sprite"
            body.addChild(sprite)
            return root
        }

        // Detailed drawn raccoon (scruffy, magnet glove — not Sly)
        let torso = SKShapeNode(path: roundedBody())
        torso.fillColor = raccoonFur
        torso.strokeColor = SKColor(white: 0, alpha: 0.3)
        torso.lineWidth = 1.2
        body.addChild(torso)

        let belly = SKShapeNode(ellipseOf: CGSize(width: 14, height: 18))
        belly.fillColor = raccoonBelly
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 1, y: -2)
        body.addChild(belly)

        let head = SKShapeNode(ellipseOf: CGSize(width: 26, height: 22))
        head.fillColor = raccoonFur
        head.strokeColor = SKColor(white: 0, alpha: 0.25)
        head.position = CGPoint(x: 0, y: 18)
        body.addChild(head)

        let mask = SKShapeNode(rectOf: CGSize(width: 24, height: 9), cornerRadius: 3)
        mask.fillColor = maskBlack
        mask.strokeColor = .clear
        mask.position = CGPoint(x: 0, y: 18)
        mask.name = "mask"
        body.addChild(mask)

        for dx in [-6.0, 6.0] {
            let eye = SKShapeNode(circleOfRadius: 2.4)
            eye.fillColor = .white
            eye.strokeColor = .clear
            eye.position = CGPoint(x: dx, y: 18)
            body.addChild(eye)
            let pupil = SKShapeNode(circleOfRadius: 1.2)
            pupil.fillColor = neonLime
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: dx, y: 18)
            body.addChild(pupil)
        }

        for dx in [-9.0, 9.0] {
            let ear = SKShapeNode(ellipseOf: CGSize(width: 8, height: 11))
            ear.fillColor = raccoonFur
            ear.strokeColor = .clear
            ear.position = CGPoint(x: dx, y: 28)
            body.addChild(ear)
        }

        let snout = SKShapeNode(ellipseOf: CGSize(width: 10, height: 7))
        snout.fillColor = raccoonBelly
        snout.strokeColor = .clear
        snout.position = CGPoint(x: 8, y: 14)
        body.addChild(snout)
        let nose = SKShapeNode(circleOfRadius: 2)
        nose.fillColor = maskBlack
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 12, y: 14)
        body.addChild(nose)

        let tail = SKNode()
        tail.name = "tail"
        tail.position = CGPoint(x: -16, y: -4)
        for i in 0..<6 {
            let ring = SKShapeNode(circleOfRadius: 5 - CGFloat(i) * 0.4)
            ring.fillColor = i % 2 == 0 ? raccoonFur : maskBlack
            ring.strokeColor = .clear
            ring.position = CGPoint(x: -CGFloat(i) * 5.5, y: CGFloat(i) * 2.2)
            tail.addChild(ring)
        }
        body.addChild(tail)

        let glove = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        glove.fillColor = neonCyan
        glove.strokeColor = .white
        glove.lineWidth = 0.5
        glove.position = CGPoint(x: 16, y: -6)
        glove.glowWidth = 2
        glove.name = "glove"
        body.addChild(glove)

        let legL = SKShapeNode(rectOf: CGSize(width: 6, height: 10), cornerRadius: 2)
        legL.fillColor = raccoonFur
        legL.strokeColor = .clear
        legL.position = CGPoint(x: -5, y: -18)
        legL.name = "legL"
        body.addChild(legL)
        let legR = SKShapeNode(rectOf: CGSize(width: 6, height: 10), cornerRadius: 2)
        legR.fillColor = raccoonFur
        legR.strokeColor = .clear
        legR.position = CGPoint(x: 5, y: -18)
        legR.name = "legR"
        body.addChild(legR)

        return root
    }

    private static func roundedBody() -> CGPath {
        CGPath(roundedRect: CGRect(x: -11, y: -14, width: 22, height: 28), cornerWidth: 8, cornerHeight: 8, transform: nil)
    }

    public static func makeMop() -> SKNode {
        if let tex = texture(for: .mopIdle0) ?? texture(for: .mopPatrol0) {
            let s = SKSpriteNode(texture: tex, size: CGSize(width: 40, height: 40))
            s.name = "mop"
            return s
        }
        let n = SKNode()
        n.name = "mop"
        let body = SKShapeNode(rectOf: CGSize(width: 26, height: 28), cornerRadius: 4)
        body.fillColor = SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        body.strokeColor = neonCyan
        body.lineWidth = 2
        body.glowWidth = 1
        n.addChild(body)
        let eye = SKShapeNode(circleOfRadius: 5)
        eye.fillColor = neonCyan
        eye.strokeColor = .white
        eye.lineWidth = 1
        eye.glowWidth = 4
        eye.position = CGPoint(x: 0, y: 4)
        n.addChild(eye)
        let brush = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 2)
        brush.fillColor = neonPink
        brush.strokeColor = .clear
        brush.position = CGPoint(x: 0, y: -18)
        n.addChild(brush)
        let tread = SKShapeNode(rectOf: CGSize(width: 28, height: 6), cornerRadius: 2)
        tread.fillColor = maskBlack
        tread.strokeColor = .clear
        tread.position = CGPoint(x: 0, y: -22)
        n.addChild(tread)
        return n
    }

    public static func makeShiny() -> SKNode {
        if let tex = texture(for: .shiny0) {
            return SKSpriteNode(texture: tex, size: CGSize(width: 22, height: 22))
        }
        let n = SKShapeNode(circleOfRadius: 8)
        n.fillColor = SKColor(red: 1, green: 0.86, blue: 0.25, alpha: 1)
        n.strokeColor = neonOrange
        n.lineWidth = 2
        n.glowWidth = 4
        n.name = "shiny"
        let spark = SKShapeNode(rectOf: CGSize(width: 3, height: 12), cornerRadius: 1)
        spark.fillColor = .white
        spark.strokeColor = .clear
        spark.zRotation = .pi / 5
        n.addChild(spark)
        return n
    }
}
#endif
