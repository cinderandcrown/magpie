// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// All feel numbers live here. No magic numbers in gameplay code.
public struct Tuning: Equatable, Sendable {
    public var tileSize: Double = 32
    public var simHz: Double = 60
    public var cameraWidthTiles: Double = 12
    public var runSpeed: Double = 5.5
    public var coastSeconds: Double = 0.25
    public var pounceAirtime: Double = 0.45
    public var pounceHeight: Double = 1.15
    public var tailSwingMaxTime: Double = 1.2
    public var tailSwingSpeed: Double = 6.5
    public var bellyFlopBounceAirtime: Double = 0.6
    public var bellyFlopBounceHeight: Double = 1.0
    public var coyoteSeconds: Double = 0.10
    public var inputBufferSeconds: Double = 0.12
    public var tapMaxMs: Double = 180
    public var tapMaxPoints: Double = 10
    public var stompTargetRadiusTiles: Double = 1.5
    public var comboGroundGrace: Double = 0.4
    public var comboCap: Int = 10
    public var maskModeAtCombo: Int = 5
    public var hearts: Int = 3
    public var shiniesToWin: Int = 8
    public var useTailSwing: Bool = true

    public var dt: Double { 1.0 / simHz }

    public static let `default` = Tuning()
}
