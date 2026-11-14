// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Single place for product naming. Code identifiers stay MAGPIE / magpie.
/// Do not scatter title string literals.
enum ProductIdentity {
    /// Engineering / repo codename. Never change without an explicit rename mission.
    static let codename = "MAGPIE"

    /// Intended commercial name: Trash Panda (confirm App Store / USPTO availability).
    /// User-facing working title until availability is confirmed.
    static let displayTitle = "Trash Panda Heist"
}
