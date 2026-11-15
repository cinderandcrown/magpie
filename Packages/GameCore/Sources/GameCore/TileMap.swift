// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

public enum Tile: UInt8, Equatable, Sendable {
    case empty = 0
    case ground = 1
    case wall = 2
    case water = 3
    case crate = 4
    case ramp = 5
    case latch = 6
    case stash = 7
    case shinySpawn = 8
    case dummySpawn = 9
    case start = 10
}

public struct TileMap: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let tiles: [Tile]

    public init(width: Int, height: Int, tiles: [Tile]) {
        precondition(tiles.count == width * height)
        self.width = width
        self.height = height
        self.tiles = tiles
    }

    public func tile(atX x: Int, y: Int) -> Tile {
        guard x >= 0, y >= 0, x < width, y < height else { return .wall }
        return tiles[y * width + x]
    }

    public func tile(atWorld world: Vec2, tileSize: Double) -> Tile {
        let x = Int(floor(world.x / tileSize))
        let y = Int(floor(world.y / tileSize))
        return tile(atX: x, y: y)
    }

    public func worldCenter(ofX x: Int, y: Int, tileSize: Double) -> Vec2 {
        Vec2((Double(x) + 0.5) * tileSize, (Double(y) + 0.5) * tileSize)
    }

    public func isSolid(_ tile: Tile) -> Bool {
        tile == .wall || tile == .crate
    }

    public func isWalkable(_ tile: Tile) -> Bool {
        switch tile {
        case .ground, .ramp, .latch, .stash, .shinySpawn, .dummySpawn, .start:
            return true
        default:
            return false
        }
    }

    public func findFirst(_ kind: Tile) -> (Int, Int)? {
        for y in 0..<height {
            for x in 0..<width where tile(atX: x, y: y) == kind {
                return (x, y)
            }
        }
        return nil
    }

    public func findAll(_ kind: Tile) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width where tile(atX: x, y: y) == kind {
                out.append((x, y))
            }
        }
        return out
    }

    /// Legend: `#` wall `.` ground `~` water `C` crate `/` ramp `L` latch `S` stash `*` shiny `D` dummy `@` start ` ` empty
    public static func parse(_ ascii: String) throws -> TileMap {
        let rows = ascii.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard let width = rows.first?.count, width > 0 else {
            throw MapError.empty
        }
        guard rows.allSatisfy({ $0.count == width }) else {
            throw MapError.ragged
        }
        var tiles: [Tile] = []
        tiles.reserveCapacity(width * rows.count)
        for row in rows.reversed() { // row 0 is bottom (south)
            for ch in row {
                tiles.append(try tile(from: ch))
            }
        }
        return TileMap(width: width, height: rows.count, tiles: tiles)
    }

    private static func tile(from ch: Character) throws -> Tile {
        switch ch {
        case " ": return .empty
        case ".": return .ground
        case "#": return .wall
        case "~": return .water
        case "C": return .crate
        case "/": return .ramp
        case "L": return .latch
        case "S": return .stash
        case "*": return .shinySpawn
        case "D": return .dummySpawn
        case "@": return .start
        default: throw MapError.unknown(ch)
        }
    }

    public enum MapError: Error, Equatable {
        case empty
        case ragged
        case unknown(Character)
    }
}

/// Neon alley test block (~40×24 playable tiles; compact for Mission 1 feel).
public enum NeonAlleyMap {
    public static let ascii = """
    ########################################
    #......*.....#......*......#....*......#
    #..D.........#...D.........#.....D.....#
    #............#.............#...........#
    #....####....#....####.....#....####...#
    #............L............L............#
    #..*.........#.....*.......#......*....#
    #............#.............#...........#
    #~~~~~.......#.......~~~~~.#.......~~~~#
    #~~~~~...C...#...C...~~~~~.#...C...~~~~#
    #............#.............#...........#
    #..D....*....#..D....*.....#..D....*...#
    #............#.............#...........#
    #..../.......#...../.......#...../.....#
    #............L............L............#
    #.*..........#.*...........#.*.........#
    #......D.....#......D......#......D....#
    #............#.............#...........#
    #....####....#....####.....#....####...#
    #............#.............#...........#
    #..*.........#.....*.......#......*....#
    #......@.....S.............#...........#
    #............#.............#...........#
    ########################################
    """

    public static func load() throws -> TileMap {
        try TileMap.parse(ascii)
    }
}
