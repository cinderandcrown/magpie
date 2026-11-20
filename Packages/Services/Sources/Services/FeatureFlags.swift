// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Runtime feature gates. Defaults are ship-safe until backend/capabilities are verified.
public enum FeatureFlags {
    private static let cloudKitGhostsKey = "ncb.cloudKitGhosts"

    /// CloudKit Daily Ghost sync. **Default OFF** until the iCloud container exists on the
    /// App ID and a signed build carries matching entitlements. Override with
    /// `NCB_CLOUDKIT_GHOSTS=1` or `UserDefaults` key `ncb.cloudKitGhosts`.
    public static var cloudKitGhostsEnabled: Bool {
        get {
            if let env = ProcessInfo.processInfo.environment["NCB_CLOUDKIT_GHOSTS"] {
                let v = env.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return v == "1" || v == "true" || v == "yes"
            }
            return UserDefaults.standard.bool(forKey: cloudKitGhostsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cloudKitGhostsKey)
        }
    }
}
