// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Services
import SwiftUI

@main
struct MagpieApp: App {
    init() {
        // Game Center auth is non-blocking — play works fully while signed out.
        GameCenterService.shared.authenticate { ok in
            GameCenterService.shared.setAccessPointVisible(ok, showHighlights: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onAppear {
                    GameCenterService.shared.setAccessPointVisible(true, showHighlights: true)
                }
        }
    }
}
