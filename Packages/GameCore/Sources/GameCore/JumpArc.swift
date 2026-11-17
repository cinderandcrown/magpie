// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Derived platformer jump budget from `GameFeel` (sim-faithful integration).
/// Used by level design + CI reachability validation.
public struct JumpArc: Equatable, Sendable {
    /// Full JUMP hold peak height in tiles.
    public var maxHeightTiles: Double
    /// Full hold + run horizontal distance while airborne (tiles).
    public var maxDistanceTiles: Double
    /// Full hold + mid-air pounce peak height (tiles).
    public var maxHeightWithPounceTiles: Double
    /// Full hold + mid-air pounce horizontal distance (tiles).
    public var maxDistanceWithPounceTiles: Double
    /// Early-release (next-frame cut) peak height (tiles).
    public var cutHeightTiles: Double

    public init(
        maxHeightTiles: Double,
        maxDistanceTiles: Double,
        maxHeightWithPounceTiles: Double,
        maxDistanceWithPounceTiles: Double,
        cutHeightTiles: Double
    ) {
        self.maxHeightTiles = maxHeightTiles
        self.maxDistanceTiles = maxDistanceTiles
        self.maxHeightWithPounceTiles = maxHeightWithPounceTiles
        self.maxDistanceWithPounceTiles = maxDistanceWithPounceTiles
        self.cutHeightTiles = cutHeightTiles
    }

    /// Integrate the same gravity / apex hang / pounce impulses as `Sim`.
    public static func derive(
        feel: GameFeel = .default,
        tileSize: Double = 32,
        simHz: Double = 60
    ) -> JumpArc {
        let dt = 1.0 / simHz
        let scale = tileSize / 2.2
        let runPx = feel.runSpeed * tileSize

        func peak(
            jumpV: Double,
            cutFrame: Int?,
            pounceFrame: Int?
        ) -> (heightTiles: Double, distTiles: Double) {
            var vy = jumpV * scale
            var vx = runPx
            var y = 0.0
            var peakY = 0.0
            var t = 0.0
            var cut = false
            var pounced = false
            for i in 0..<360 {
                if let cutFrame, i == cutFrame, !cut, vy > 0 {
                    vy *= feel.jumpCutFraction
                    cut = true
                }
                if let pounceFrame, i == pounceFrame, !pounced {
                    vx += feel.pounceBoostX * tileSize / 2
                    vy += feel.pounceBoostY * tileSize / 3
                    pounced = true
                }
                let riseG = feel.gravity * scale
                let fallG = feel.gravity * feel.fallGravityMul * scale
                let apex = feel.apexHangSpeed * scale
                let g: Double
                if abs(vy) <= apex {
                    g = riseG * feel.apexHangMul
                } else if vy > 0 {
                    g = riseG
                } else {
                    g = fallG
                }
                vy -= g * dt
                y += vy * dt
                t += dt
                peakY = max(peakY, y)
                if i > 2, y <= 0, vy <= 0 {
                    return (peakY / tileSize, (vx * t) / tileSize)
                }
            }
            return (peakY / tileSize, (vx * t) / tileSize)
        }

        let full = peak(jumpV: feel.jumpVelocity, cutFrame: nil, pounceFrame: nil)
        let cut = peak(jumpV: feel.jumpVelocity, cutFrame: 1, pounceFrame: nil)
        let pounce = peak(jumpV: feel.jumpVelocity, cutFrame: nil, pounceFrame: 10)
        return JumpArc(
            maxHeightTiles: full.heightTiles,
            maxDistanceTiles: full.distTiles,
            maxHeightWithPounceTiles: pounce.heightTiles,
            maxDistanceWithPounceTiles: pounce.distTiles,
            cutHeightTiles: cut.heightTiles
        )
    }
}
