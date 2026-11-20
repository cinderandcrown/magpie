// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public extension ProcessInfo {
    /// XCTest host or `-SmokeAutoplay` / UI-test harness — skip GameKit / CloudKit side effects
    /// that crash unsigned simulator processes (missing Game Center / iCloud entitlements).
    var underAutomatedHarness: Bool {
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if arguments.contains("-SmokeAutoplay") { return true }
        if arguments.contains("-uiTesting") { return true }
        return false
    }
}
