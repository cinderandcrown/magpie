// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Single place for product naming. Code identifiers stay MAGPIE / magpie.
/// Do not scatter title string literals.
enum ProductIdentity {
    /// Engineering / repo codename. Never change without an explicit rename mission.
    static let codename = "MAGPIE"

    /// Full user-facing title.
    static let displayTitle = "The Neon City Bandit"

    /// Home-screen label (`CFBundleDisplayName`) — shorter so iOS does not truncate.
    static let homeScreenTitle = "Neon City Bandit"
}
