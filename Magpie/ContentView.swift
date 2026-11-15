// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameRender
import SpriteKit
import SwiftUI

/// SwiftUI shell hosting the Mission 1 neon heist scene.
struct ContentView: View {
    @State private var scene: HeistScene = {
        let smoke = ProcessInfo.processInfo.arguments.contains("-SmokeAutoplay")
        let s = HeistScene(size: CGSize(width: 390, height: 844), smokeAutoplay: smoke)
        // resizeFill = edge-to-edge on every iPhone; HUD uses safe-area insets.
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: sized(scene, to: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .ignoresSafeArea()
        }
        .background(Color(red: 0.06, green: 0.04, blue: 0.16))
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func sized(_ scene: HeistScene, to size: CGSize) -> HeistScene {
        if scene.size != size {
            scene.size = size
        }
        scene.scaleMode = .resizeFill
        return scene
    }
}

#Preview {
    ContentView()
}
