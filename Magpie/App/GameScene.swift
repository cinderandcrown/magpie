// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

import GameRules
import SpriteKit

/// Mission 0 placeholder: title, build label, and a bird you tap to hop.
///
/// Apple docs checked: `SKScene` receives touches via `UIResponder`
/// `touchesBegan(_:with:)`; motion uses `SKAction` on `SKSpriteNode`.
final class GameScene: SKScene {
    private var bird: SKSpriteNode?
    private var isHopping = false

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.22, blue: 0.26, alpha: 1)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = BuildLabel.title
        title.fontSize = 44
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        title.name = "title"
        addChild(title)

        let build = SKLabelNode(fontNamed: "AvenirNext-Regular")
        build.text = BuildInfo.buildLine
        build.fontSize = 14
        build.fontColor = SKColor(white: 0.85, alpha: 1)
        build.verticalAlignmentMode = .center
        build.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        build.name = "build"
        addChild(build)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = "Tap the bird to hop"
        hint.fontSize = 16
        hint.fontColor = SKColor(white: 0.75, alpha: 1)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        hint.name = "hint"
        addChild(hint)

        let texture = SKTexture(imageNamed: "Bird")
        let birdNode: SKSpriteNode
        if texture.size().width > 0, texture.size().height > 0 {
            birdNode = SKSpriteNode(texture: texture, size: CGSize(width: 96, height: 96))
        } else {
            // Fallback if the asset catalog is missing at runtime (should not happen in CI).
            birdNode = SKSpriteNode(color: SKColor(red: 0.28, green: 0.55, blue: 0.55, alpha: 1), size: CGSize(width: 72, height: 72))
        }
        birdNode.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        birdNode.name = "bird"
        addChild(birdNode)
        bird = birdNode
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let bird else { return }
        let location = touch.location(in: self)
        let hit = nodes(at: location).contains { $0 === bird || $0.name == "bird" }
        guard hit, HopMotion.canHop(isHopping: isHopping) else { return }
        hop(bird)
    }

    private func hop(_ bird: SKSpriteNode) {
        isHopping = true
        let lift = CGFloat(HopMotion.defaultLift)
        let half = HopMotion.defaultDuration / 2
        let up = SKAction.moveBy(x: 0, y: lift, duration: half)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -lift, duration: half)
        down.timingMode = .easeIn
        bird.run(SKAction.sequence([up, down])) { [weak self] in
            self?.isHopping = false
        }
    }
}
