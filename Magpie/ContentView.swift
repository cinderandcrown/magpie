// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameRender
import SpriteKit
import SwiftUI

/// SwiftUI shell hosting the Mission 0 SpriteKit scene.
///
/// Apple docs checked:
/// - [SpriteView](https://developer.apple.com/documentation/spritekit/spriteview)
/// - [SwiftUI App](https://developer.apple.com/documentation/swiftui/app)
struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size), options: [.allowsTransparency])
                .ignoresSafeArea()
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = FollowSquareScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }
}

#Preview {
    ContentView()
}
