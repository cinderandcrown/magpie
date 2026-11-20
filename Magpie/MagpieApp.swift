// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Services
import SwiftUI

@main
struct MagpieApp: App {
    init() {
        // Skip GameKit under XCTest / smoke — unsigned simulator hosts can fault when
        // gamed rejects a missing Game Center entitlement.
        guard !ProcessInfo.processInfo.underAutomatedHarness else { return }
        // Defer auth until a window exists. Auth is fully optional — play works signed out.
        // Never force-unwrap; GameCenterService swallows GameKit errors.
        DispatchQueue.main.async {
            GameCenterService.shared.authenticate { ok in
                GameCenterService.shared.setAccessPointVisible(ok, showHighlights: true)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onAppear {
                    guard !ProcessInfo.processInfo.underAutomatedHarness else { return }
                    // Access point only when already authenticated — never fatal.
                    if GameCenterService.shared.isAuthenticated {
                        GameCenterService.shared.setAccessPointVisible(true, showHighlights: true)
                    }
                }
        }
    }
}
