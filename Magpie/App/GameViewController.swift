// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

import SpriteKit
import UIKit

/// Hosts the Mission 0 placeholder `SKScene` in an `SKView`.
///
/// Apple docs checked: SpriteKit `SKView.presentScene(_:)` presents a scene;
/// the view controller’s root view is an `SKView` (UIKit + SpriteKit).
final class GameViewController: UIViewController {
    override loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
}
