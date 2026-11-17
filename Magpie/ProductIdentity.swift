// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Single place for product naming.
/// User-facing title: The Neon City Bandit. Do not scatter title string literals.
/// Bundle ID / Xcode target / historical `MAGPIE` code identifiers stay unchanged.
enum ProductIdentity {
    /// Historical engineering codename in code identifiers (bundle ID, target). Not user-facing.
    static let codename = "MAGPIE"

    /// Full user-facing title.
    static let displayTitle = "The Neon City Bandit"

    /// Home-screen label (`CFBundleDisplayName`) — shorter so iOS does not truncate.
    static let homeScreenTitle = "Neon City Bandit"

    /// Publisher splash line (studio ident). Exact wording — ampersand required.
    static let publisherPresents = "Cinder & Crown Creative Presents"
}
