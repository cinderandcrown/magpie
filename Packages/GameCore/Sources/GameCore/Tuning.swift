// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// All feel numbers live here. Tuned toward Celeste / Meat Boy snappiness.
public struct Tuning: Equatable, Sendable {
    public var tileSize: Double = 32
    public var simHz: Double = 60

    // Run / air — snappier fall so jumps stop feeling floaty.
    /// Slight stick deflection → walk; full deflection → run (Chong-U / Vibe v2).
    public var walkSpeed: Double = 3.6
    public var runSpeed: Double = 7.4
    /// Stick magnitude at/above this uses runSpeed; below blends toward walkSpeed.
    public var walkRunStickThreshold: Double = 0.55
    public var accelGround: Double = 95
    public var accelAir: Double = 48
    public var frictionGround: Double = 78
    public var maxFall: Double = 26
    public var gravity: Double = 84
    /// Extra gravity while falling (Celeste-style fast drop).
    public var fallGravity: Double = 122
    public var jumpCutGravity: Double = 155
    /// Stomp hitbox while falling at least this fast (tiles/s), or while flopping.
    /// Keep low so hop-stomps still connect; “contact frame” = any committed downward hit.
    public var stompMinFallSpeed: Double = 0.2

    // Jump
    public var jumpVelocity: Double = 15.6
    public var coyoteSeconds: Double = 0.12
    public var jumpBufferSeconds: Double = 0.14
    /// While rising with jump held, gravity is scaled by (1 − boost×0.4).
    public var variableJumpHoldBoost: Double = 0.45

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
    /// Contact-tight stomp radius (world px). Must clear halfH (~14) plus patrol jitter.
    /// Was 22 (wide aura / visual overlap); 18 reads as contact.
    public var stompHitRadius: Double = 18
    /// Separate hurt radius — slightly under stomp so stomps win on contact frames.
    public var hurtHitRadius: Double = 16

    // Combat / meta
    /// Window to chain stomps into Mask (must span adjacent MOP patrols on a deck).
    public var comboGroundGrace: Double = 4.5
    public var comboCap: Int = 10
    public var maskModeAtCombo: Int = 5
    /// How long Mask Mode stays on after it's earned (screenshot + power fantasy window).
    public var maskDuration: Double = 14
    public var hearts: Int = 3
    public var invulnSeconds: Double = 1.0
    public var shiniesToHint: Int = 12

    // Camera (consumed by render; mirrored here for tests)
    public var cameraLeadTiles: Double = 2.2
    public var cameraSmooth: Double = 0.14

    public var dt: Double { 1.0 / simHz }

    public static let `default` = Tuning()
}
