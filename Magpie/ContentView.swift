// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameRender
import SpriteKit
import SwiftUI

/// SwiftUI shell hosting the Mission 1 neon heist scene.
struct ContentView: View {
    @State private var scene: HeistScene = {
        let smoke = ProcessInfo.processInfo.arguments.contains("-SmokeAutoplay")
        let s = HeistScene(size: CGSize(width: 390, height: 844), smokeAutoplay: smoke)
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: sized(scene, to: geo.size))
                .ignoresSafeArea()
        }
        .statusBarHidden()
    }

    private func sized(_ scene: HeistScene, to size: CGSize) -> HeistScene {
        if scene.size != size {
            scene.size = size
        }
        return scene
    }
}

#Preview {
    ContentView()
}
