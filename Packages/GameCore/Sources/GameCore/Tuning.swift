// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// All feel numbers live here. Tuned toward Celeste / Meat Boy snappiness.
public struct Tuning: Equatable, Sendable {
    public var tileSize: Double = 32
    public var simHz: Double = 60

    // Run / air
    public var runSpeed: Double = 7.2
    public var accelGround: Double = 90
    public var accelAir: Double = 42
    public var frictionGround: Double = 70
    public var maxFall: Double = 22
    public var gravity: Double = 78
    public var jumpCutGravity: Double = 140

    // Jump
    public var jumpVelocity: Double = 15.2
    public var coyoteSeconds: Double = 0.10
    public var jumpBufferSeconds: Double = 0.12
    public var variableJumpHoldBoost: Double = 0.35

    // Wall
    public var wallSlideSpeed: Double = 3.2
    public var wallJumpVelocityX: Double = 8.5
    public var wallJumpVelocityY: Double = 14.0
    public var wallClingSeconds: Double = 0.12

    // Pounce / Belly Flop (air attack)
    public var pounceBoostX: Double = 3.5
    public var pounceBoostY: Double = 4.0
    public var bellyFlopFallBoost: Double = 18
    public var stompBounceVelocity: Double = 12
    public var stompHitRadius: Double = 22

    // Combat / meta
    public var comboGroundGrace: Double = 1.2
    public var comboCap: Int = 10
    public var maskModeAtCombo: Int = 5
    public var hearts: Int = 3
    public var invulnSeconds: Double = 1.0
    public var shiniesToHint: Int = 12

    // Camera (consumed by render; mirrored here for tests)
    public var cameraLeadTiles: Double = 2.2
    public var cameraSmooth: Double = 0.14

    public var dt: Double { 1.0 / simHz }

    public static let `default` = Tuning()
}
