// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Single source of truth for movement, stomp, stick, and button feel.
/// Keep numbers here — `Tuning` embeds this so gameplay + UI share one config.
public struct GameFeel: Equatable, Sendable {
    // MARK: Run / stick

    /// Slight stick deflection → walk; full deflection → run.
    public var walkSpeed: Double = 3.6
    public var runSpeed: Double = 7.4
    /// Stick magnitude at/above this uses runSpeed; below blends toward walkSpeed.
    public var walkRunStickThreshold: Double = 0.55
    /// Seconds from rest → top run speed on ground (≈0.1 s).
    public var groundAccelTime: Double = 0.09
    /// Seconds from top speed → stop on ground with stick released (≈0.08 s).
    public var groundStopTime: Double = 0.075
    /// Extra accel multiplier when reversing against current velocity.
    public var turnAccelMul: Double = 1.9
    /// Air horizontal accel as a fraction of ground accel (≈65%).
    public var airControlMul: Double = 0.65
    /// Radial stick dead zone (normalized 0…1).
    public var stickDeadZone: Double = 0.15
    /// Virtual stick max travel in points.
    public var stickMaxRadius: Double = 52
    /// JUMP / POUNCE button minimum edge length in points.
    public var faceButtonMinPt: Double = 88
    /// Extra invisible hit padding around face buttons (points).
    public var faceButtonHitPad: Double = 12

    // MARK: Gravity / jump

    public var maxFall: Double = 26
    public var gravity: Double = 84
    /// Fall gravity = rise gravity × this (≈1.8×). Keep ≤1.85 so stomp timing stays readable.
    public var fallGravityMul: Double = 1.72
    /// Near apex (|vy| below threshold), gravity × this for hang time.
    public var apexHangMul: Double = 0.42
    /// |vy| (tiles/s scaled later) under which apex hang applies.
    public var apexHangSpeed: Double = 2.2
    /// Peak jump impulse — scaled in Sim by `tileSize/2.2`.
    /// 30 ≈ 2.3 tile full-hold height so Neon Docks rooftops stay reachable
    /// (15.6 only cleared ~0.6 tiles and made upper decks pointless).
    public var jumpVelocity: Double = 30.0
    /// Early JUMP release multiplies upward velocity by this (50% cut → 0.5).
    public var jumpCutFraction: Double = 0.5
    public var coyoteSeconds: Double = 0.12
    public var jumpBufferSeconds: Double = 0.14
    /// Max horizontal nudge (px) around ledge corners on head bump / near-miss land.
    public var cornerCorrectPx: Double = 6

    // MARK: Wall

    public var wallSlideSpeed: Double = 3.2
    public var wallJumpVelocityX: Double = 8.5
    public var wallJumpVelocityY: Double = 26.0
    public var wallClingSeconds: Double = 0.12

    // MARK: Pounce / stomp

    public var pounceBoostX: Double = 3.5
    public var pounceBoostY: Double = 4.0
    public var bellyFlopFallBoost: Double = 18
    public var stompBounceVelocity: Double = 15.0
    /// Holding JUMP on stomp multiplies bounce by this (chain assist).
    public var stompBounceHoldMul: Double = 1.45
    /// MOP sprite width in tiles — stomp box is `stompWidthMul` × this.
    public var mopSpriteWidthTiles: Double = 1.0
    /// Horizontal stomp hurtbox vs MOP sprite width (≈1.3×).
    public var stompWidthMul: Double = 1.3
    /// Side-contact damage box vs MOP sprite width (must stay smaller than sprite).
    public var hurtWidthMul: Double = 0.55
    /// Count as stomp-capable for this many frames while |vy| is near apex.
    public var stompApexFrames: Int = 2
    /// Pounce magnet search radius in tiles (ahead + below).
    public var pounceMagnetTiles: Double = 2.0
    /// How hard the magnet pulls (tiles/s² scale via tileSize).
    public var pounceMagnetAccel: Double = 28
    /// Hit-stop on stomp (seconds) — ~55 ms punch; combo bumps in the render layer.
    public var stompHitstop: Double = 0.055
    public var invulnSeconds: Double = 1.0
    /// Minimum bandit alpha while blinking during i-frames (≥ 50%).
    public var invulnMinAlpha: Double = 0.55

    public static let `default` = GameFeel()
}
