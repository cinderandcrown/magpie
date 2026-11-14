// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit)
import SpriteKit
import UIKit

/// Mission 0 placeholder scene: one square that follows the finger.
///
/// Apple docs checked before use:
/// - [SKScene](https://developer.apple.com/documentation/spritekit/skscene)
/// - [SpriteView](https://developer.apple.com/documentation/spritekit/spriteview) (hosted by GameApp)
/// - Touch delivery via `UIResponder` `touchesMoved` / `touchesBegan` on `SKScene`
public final class FollowSquareScene: SKScene {
    private let square = SKSpriteNode(color: SKColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 1), size: CGSize(width: 56, height: 56))
    private let fpsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var lastFrameTime: TimeInterval = 0
    private var fpsUpdateAccumulator: TimeInterval = 0
    private var displayedFPS: Int = 0

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1)
        square.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        square.name = "followSquare"
        addChild(square)

        #if DEBUG
        fpsLabel.fontSize = 14
        fpsLabel.fontColor = .white
        fpsLabel.horizontalAlignmentMode = .left
        fpsLabel.verticalAlignmentMode = .top
        fpsLabel.position = CGPoint(x: 16, y: size.height - 16)
        fpsLabel.text = "FPS --"
        fpsLabel.name = "fps"
        addChild(fpsLabel)
        #endif
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        square.position = CGPoint(
            x: min(max(square.position.x, 0), size.width),
            y: min(max(square.position.y, 0), size.height)
        )
        #if DEBUG
        fpsLabel.position = CGPoint(x: 16, y: size.height - 16)
        #endif
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        moveSquare(with: touches)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        moveSquare(with: touches)
    }

    private func moveSquare(with touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        square.position = touch.location(in: self)
    }

    public override func update(_ currentTime: TimeInterval) {
        #if DEBUG
        if lastFrameTime > 0 {
            let dt = currentTime - lastFrameTime
            if dt > 0 {
                let instant = 1.0 / dt
                fpsUpdateAccumulator += dt
                if fpsUpdateAccumulator >= 0.25 {
                    displayedFPS = Int(instant.rounded())
                    fpsLabel.text = "FPS \(displayedFPS)"
                    fpsUpdateAccumulator = 0
                }
            }
        }
        lastFrameTime = currentTime
        #endif
    }
}
#endif
