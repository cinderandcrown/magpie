// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import GameCore

/// Pure metadata so GameRender has a Linux-safe symbol for package tests.
public enum RenderInfo: Sendable {
    public static let name = "GameRender"
    public static var dependsOnCore: String { ModuleInfo.name }
}
