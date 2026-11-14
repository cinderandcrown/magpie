// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

/// Formats the on-screen build number label for Mission 0.
public enum BuildLabel: Sendable {
    /// Title shown on the placeholder scene.
    public static let title = "MAGPIE"

    /// Human-readable build line: `v1.0.0 (42.1)`.
    public static func text(version: String, build: String) -> String {
        "v\(version) (\(build))"
    }
}
