// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import AVFoundation
import GameRender
import SpriteKit
import SwiftUI
import UIKit

/// SwiftUI shell hosting the Mission 1 neon heist scene.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene: HeistScene = {
        let smoke = ProcessInfo.processInfo.arguments.contains("-SmokeAutoplay")
        let s = HeistScene(size: CGSize(width: 390, height: 844), smokeAutoplay: smoke)
        // resizeFill = edge-to-edge on every iPhone; HUD uses safe-area insets.
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            // Dark plate behind SpriteKit so any clear pixel stays night-sky, never system white.
            SpriteView(scene: sized(scene, to: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .background(Color(red: 0.06, green: 0.04, blue: 0.16))
                .ignoresSafeArea()
        }
        .background(Color(red: 0.06, green: 0.04, blue: 0.16))
        .ignoresSafeArea()
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                scene.pauseFromAppLifecycle()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            scene.pauseFromAppLifecycle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            scene.pauseFromAppLifecycle()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
            guard let info = note.userInfo,
                  let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal),
                  type == .began else { return }
            scene.pauseFromAppLifecycle()
        }
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