// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Graph search from spawn using the derived jump arc.
/// Fails CI when any standable goal is unreachable from spawn, OR when any reachable
/// standable cannot path to EXIT (soft-lock / no way down).
public enum ReachabilityValidator {
    public struct Report: Equatable, Sendable {
        public var reachableStands: Int
        public var totalStands: Int
        public var unreachable: [String]
        public var softlocks: [String]
        public var arc: JumpArc

        public var ok: Bool { unreachable.isEmpty && softlocks.isEmpty }
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
            return Report(
                reachableStands: 0,
                totalStands: stands.count,
                unreachable: ["missing @ start"],
                softlocks: [],
                arc: jump
            )
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
            return Report(
                reachableStands: 0,
                totalStands: stands.count,
                unreachable: ["start has no standable deck"],
                softlocks: [],
                arc: jump
            )
        }

        let seen = reachable(from: startStand, stands: stands, map: map, jump: jump)

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

        // Soft-lock gate: every spawn-reachable stand must still be able to reach EXIT.
        let exitStands = exitStandables(map: map, stands: stands)
        var softlocks: [String] = []
        if exitStands.isEmpty {
            softlocks.append("exit has no standable deck")
        } else {
            for id in seen {
                let fromExit = reachable(from: id, stands: stands, map: map, jump: jump)
                if fromExit.isDisjoint(with: exitStands) {
                    let x = id % map.width
                    let y = id / map.width
                    softlocks.append("softlock@\(x),\(y)")
                }
            }
        }

        // One-ways must offer a clear walk-off (not a latch/solid cage that only drops via hold-down).
        // Players and the smoke bot both need an obvious ledge end — drop-through alone is not enough.
        // Exception: hazard lips (canal bridge over water/spikes) are intentional hold-down drops.
        var checkedOneWayRows: Set<Int> = []
        for id in stands {
            let x = id % map.width
            let y = id / map.width
            guard map.tile(atX: x, y: y) == .oneWay else { continue }
            // Latch/wall sealed against a one-way (L----) pins hunters that path into the wall.
            for nx in [x - 1, x + 1] {
                let neighbor = map.tile(atX: nx, y: y)
                if neighbor == .latch || neighbor == .wall {
                    softlocks.append("latch-seal@\(x),\(y)")
                    break
                }
            }
            if oneWayIsHazardLip(map: map, x: x, y: y) {
                // Open gaps preferred: a one-way lip beside a solid street stand soft-locks
                // hold-down / death-seek (dropThrough neighbor stutter on the solid).
                for nx in [x - 1, x + 1] {
                    let n = map.tile(atX: nx, y: y)
                    if map.isSolid(n), n != .oneWay {
                        softlocks.append("hazard-lip-adjacent@\(nx),\(y)")
                    }
                }
                continue
            }
            let rowKey = y * map.width + x
            if checkedOneWayRows.contains(rowKey) { continue }
            let strip = oneWayStrip(map: map, stands: stands, x: x, y: y)
            for sid in strip { checkedOneWayRows.insert(sid) }
            if !oneWayStripHasWalkOff(map: map, strip: strip) {
                softlocks.append("no-descent@\(x),\(y)")
            }
        }

        return Report(
            reachableStands: seen.count,
            totalStands: stands.count,
            unreachable: unreachable.sorted(),
            softlocks: softlocks.sorted(),
            arc: jump
        )
    }

    // MARK: - Graph

    private static func exitStandables(map: TileMap, stands: Set<Int>) -> Set<Int> {
        var out: Set<Int> = []
        for (x, y) in map.findAll(.exit) {
            for sy in stride(from: y, through: max(0, y - 2), by: -1) {
                let id = sy * map.width + x
                if stands.contains(id) {
                    out.insert(id)
                    break
                }
            }
        }
        return out
    }

    /// Canal / spike lip: dropping through this one-way lands in a hazard (not a soft-lock cage).
    private static func oneWayIsHazardLip(map: TileMap, x: Int, y: Int) -> Bool {
        for dy in 1...3 {
            let ty = y - dy
            guard ty >= 0 else { break }
            let t = map.tile(atX: x, y: ty)
            if t == .water || t == .spike { return true }
            if map.isSolid(t), t != .oneWay { break }
        }
        return false
    }

    /// Contiguous one-way standables on the same row (walkable strip).
    private static func oneWayStrip(map: TileMap, stands: Set<Int>, x: Int, y: Int) -> Set<Int> {
        var strip: Set<Int> = []
        var lx = x
        while lx >= 0, stands.contains(y * map.width + lx), map.tile(atX: lx, y: y) == .oneWay {
            strip.insert(y * map.width + lx)
            lx -= 1
        }
        var rx = x + 1
        while rx < map.width, stands.contains(y * map.width + rx), map.tile(atX: rx, y: y) == .oneWay {
            strip.insert(y * map.width + rx)
            rx += 1
        }
        return strip
    }

    /// True when either end of the strip opens to non-standable air (walk-off ledge).
    private static func oneWayStripHasWalkOff(map: TileMap, strip: Set<Int>) -> Bool {
        guard !strip.isEmpty else { return true }
        let ys = strip.map { $0 / map.width }
        let xs = strip.map { $0 % map.width }
        guard let y = ys.first, let minX = xs.min(), let maxX = xs.max() else { return true }
        for edgeX in [minX - 1, maxX + 1] {
            if edgeX < 0 || edgeX >= map.width { return true }
            if !map.isStandable(map.tile(atX: edgeX, y: y)) { return true }
        }
        return false
    }

    private static func reachable(
        from startStand: Int,
        stands: Set<Int>,
        map: TileMap,
        jump: JumpArc
    ) -> Set<Int> {
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
                    // Drop / drop-through one-ways: generous horizontal while falling.
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
        return seen
    }
}
