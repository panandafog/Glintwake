import Foundation

struct Point: Hashable, Codable, Sendable {
    var x: Int
    var y: Int
    func moved(_ direction: Direction) -> Point {
        Point(x: x + direction.dx, y: y + direction.dy)
    }
}

enum Direction: Int, CaseIterable, Codable, Sendable {
    case north, northEast, east, southEast, south, southWest, west, northWest
    var dx: Int { [0, 1, 1, 1, 0, -1, -1, -1][rawValue] }
    var dy: Int { [-1, -1, 0, 1, 1, 1, 0, -1][rawValue] }
    var symbol: String { ["arrow.up", "arrow.up.right", "arrow.right", "arrow.down.right", "arrow.down", "arrow.down.left", "arrow.left", "arrow.up.left"][rawValue] }
    static func from(dx: Double, dy: Double) -> Direction? {
        guard hypot(dx, dy) >= 16 else { return nil }
        let octant = Int((atan2(dy, dx) / (.pi / 4)).rounded())
        return Direction(rawValue: (octant + 2 + 8) % 8)
    }
}

enum Tile: String, Codable, Sendable { case floor, wall, stop, hazard }

struct Level: Codable, Equatable, Sendable {
    let id: Int
    let size: Int
    var tiles: [Tile]
    let start: Point
    let exit: Point
    let gems: [Point]
    var par: Int

    func tile(at p: Point) -> Tile {
        guard p.x >= 0, p.y >= 0, p.x < size, p.y < size else { return .wall }
        return tiles[p.y * size + p.x]
    }
    var allGems: Int { (1 << gems.count) - 1 }
    var initial: Position { Position(point: start, gems: 0, dead: false) }

    static func map(id: Int, rows: [String]) -> Level {
        precondition(!rows.isEmpty && rows.allSatisfy { $0.count == rows.count })
        var tiles: [Tile] = [], gems: [Point] = []
        var start: Point?, exit: Point?
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                let p = Point(x: x, y: y)
                tiles.append(ch == "#" ? .wall : ch == "O" ? .stop : ch == "X" ? .hazard : .floor)
                if ch == "S" { start = p }
                if ch == "E" { exit = p }
                if ch == "*" { gems.append(p) }
            }
        }
        precondition(start != nil && exit != nil && gems.count < 16)
        return Level(id: id, size: rows.count, tiles: tiles, start: start!, exit: exit!, gems: gems, par: 0)
    }
}

struct Position: Hashable, Codable, Sendable {
    var point: Point
    var gems: Int
    var dead: Bool
    func won(_ level: Level) -> Bool { !dead && gems == level.allGems && point == level.exit }
    var collected: Int { gems.nonzeroBitCount }
}

struct Action: Equatable, Codable, Sendable {
    let direction: Direction
}

struct Transition: Sendable {
    let position: Position
    let path: [Point]
}

enum Rules {
    /// Diagonals cannot squeeze past either of the two orthogonal wall corners.
    /// A locked exit behaves like floor; an unlocked exit catches the traveller.
    static func move(_ state: Position, in level: Level, action: Action) -> Transition {
        guard !state.dead, !state.won(level) else {
            return Transition(position: state, path: [])
        }
        var result = state
        var path: [Point] = []
        let d = action.direction
        while true {
            let next = result.point.moved(d)
            if level.tile(at: next) == .wall { break }
            if d.dx != 0 && d.dy != 0 {
                let sideX = Point(x: result.point.x + d.dx, y: result.point.y)
                let sideY = Point(x: result.point.x, y: result.point.y + d.dy)
                if level.tile(at: sideX) == .wall || level.tile(at: sideY) == .wall { break }
            }
            result.point = next
            path.append(next)
            if let i = level.gems.firstIndex(of: next) { result.gems |= 1 << i }
            if level.tile(at: next) == .hazard { result.dead = true; break }
            if level.tile(at: next) == .stop || result.won(level) { break }
        }
        return Transition(position: result, path: path)
    }
}

enum Solver {
    /// Breadth-first search returns a shortest route, using sliding moves.
    /// With 7x7 boards and at most five gems the state space is small and bounded.
    static func solve(_ level: Level, from initial: Position? = nil) -> [Action]? {
        let start = initial ?? level.initial
        guard !start.dead else { return nil }
        if start.won(level) { return [] }
        var queue = [start], head = 0
        var seen: Set<Position> = [start]
        var parents: [Position: (Position, Action)] = [:]
        while head < queue.count {
            let state = queue[head]
            head += 1
            for direction in Direction.allCases {
                let action = Action(direction: direction)
                let next = Rules.move(state, in: level, action: action).position
                guard !next.dead, seen.insert(next).inserted else { continue }
                parents[next] = (state, action)
                if next.won(level) {
                    var route: [Action] = [], cursor = next
                    while let (previous, step) = parents[cursor] {
                        route.append(step)
                        cursor = previous
                    }
                    return route.reversed()
                }
                queue.append(next)
            }
        }
        return nil
    }
}
