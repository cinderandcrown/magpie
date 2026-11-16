// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Graph search from spawn using the derived jump arc.
/// Fails CI when any standable goal (platform tops with shinies / crew / exit) is unreachable.
public enum ReachabilityValidator {
    public struct Report: Equatable, Sendable {
        public var reachableStands: Int
        public var totalStands: Int
        public var unreachable: [String]
        public var arc: JumpArc

        public var ok: Bool { unreachable.isEmpty }
    }

    /// Standable cells: solid (or one-way) with empty above for feet.
    public static func standables(map: TileMap) -> Set<Int> {
        var out: Set<Int> = []
        for y in 0..<map.height {
            for x in 0..<map.width {
                let t = map.tile(atX: x, y: y)
                guard map.isStandable(t) else { continue }
                let above = map.tile(atX: x, y: y + 1)
                // Feet stand on the top of this tile — need non-solid above (or map edge air).
                if map.isSolid(above), above != .oneWay { continue }
                out.insert(y * map.width + x)
            }
        }
        return out
    }

    public static func validate(
        map: TileMap,
        tuning: Tuning = .default,
        arc: JumpArc? = nil
    ) -> Report {
        let jump = arc ?? JumpArc.derive(feel: tuning.feel, tileSize: tuning.tileSize, simHz: tuning.simHz)
        let stands = standables(map: map)
        guard let startXY = map.findFirst(.start) else {
            return Report(reachableStands: 0, totalStands: stands.count, unreachable: ["missing @ start"], arc: jump)
        }
        // Start stands on solid below the marker cell.
        var startStand = startXY.1 * map.width + startXY.0
        if !stands.contains(startStand) {
            let belowY = startXY.1 - 1
            if belowY >= 0 {
                startStand = belowY * map.width + startXY.0
            }
        }
        guard stands.contains(startStand) else {
            return Report(reachableStands: 0, totalStands: stands.count, unreachable: ["start has no standable deck"], arc: jump)
        }

        // Conservative budgets (slightly under derived peaks for safety).
        let maxUp = Int(floor(jump.maxHeightWithPounceTiles + 0.05))
        let maxHoriz = Int(floor(jump.maxDistanceWithPounceTiles + 0.25))
        let maxFallHoriz = max(maxHoriz, Int(floor(jump.maxDistanceTiles + 1)))

        var seen: Set<Int> = []
        var queue: [Int] = [startStand]
        seen.insert(startStand)

        while let cur = queue.first {
            queue.removeFirst()
            let cx = cur % map.width
            let cy = cur / map.width

            // Walk left/right along contiguous standables at same height.
            for dir in [-1, 1] {
                var x = cx + dir
                while x >= 0, x < map.width {
                    let id = cy * map.width + x
                    guard stands.contains(id) else { break }
                    if seen.insert(id).inserted { queue.append(id) }
                    x += dir
                }
            }

            // Jump / fall to other standables within arc.
            for other in stands where !seen.contains(other) {
                let ox = other % map.width
                let oy = other / map.width
                let dx = abs(ox - cx)
                let dy = oy - cy
                if dy > 0 {
                    // Rising jump — need height + horizontal budget.
                    if dy <= maxUp, dx <= maxHoriz {
                        seen.insert(other)
                        queue.append(other)
                    }
                } else if dy == 0 {
                    if dx <= maxHoriz {
                        seen.insert(other)
                        queue.append(other)
                    }
                } else {
                    // Drop down: generous horizontal while falling.
                    if dx <= maxFallHoriz + abs(dy) {
                        seen.insert(other)
                        queue.append(other)
                    }
                }
            }

            // Wall-climb assist: latch/wall pillar within 1 tile horizontally allows +1 extra rise hops.
            for climbY in (cy + 1)...min(map.height - 1, cy + maxUp + 2) {
                for dx in [-1, 0, 1] {
                    let wx = cx + dx
                    guard wx >= 0, wx < map.width else { continue }
                    let wt = map.tile(atX: wx, y: climbY)
                    if wt == .latch || wt == .wall {
                        let standId = climbY * map.width + cx
                        if stands.contains(standId), seen.insert(standId).inserted {
                            queue.append(standId)
                        }
                        let standBeside = climbY * map.width + wx
                        if stands.contains(standBeside), seen.insert(standBeside).inserted {
                            queue.append(standBeside)
                        }
                    }
                }
            }
        }

        var unreachable: [String] = []
        func require(_ kind: Tile, label: String) {
            for (x, y) in map.findAll(kind) {
                // Goal is reachable if its standable deck (same cell or below) is seen.
                var ok = false
                for sy in stride(from: y, through: max(0, y - 2), by: -1) {
                    let id = sy * map.width + x
                    if seen.contains(id) { ok = true; break }
                    if stands.contains(id) { break }
                }
                if !ok {
                    unreachable.append("\(label)@\(x),\(y)")
                }
            }
        }
        require(.shinySpawn, label: "shiny")
        require(.exit, label: "exit")
        require(.crewCage, label: "crew")
        // Every standable platform top should be reachable (exploration mandate).
        for id in stands where !seen.contains(id) {
            let x = id % map.width
            let y = id / map.width
            // Ignore buried solids under other solids (not a "platform the player can see").
            let above = map.tile(atX: x, y: y + 1)
            if map.isSolid(above), above != .oneWay { continue }
            unreachable.append("platform@\(x),\(y)")
        }

        return Report(
            reachableStands: seen.count,
            totalStands: stands.count,
            unreachable: unreachable.sorted(),
            arc: jump
        )
    }
}
