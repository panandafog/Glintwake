import Foundation

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    mutating func number(_ upper: Int) -> Int { Int(next() % UInt64(upper)) }
}

enum Levels {
    static func make(_ id: Int) -> Level {
        let rows: [String]
        switch id {
        case 0:
            rows = ["#######", "#S.*.O#", "#####.#", "#####*#", "#####.#", "#E...O#", "#######"]
        case 1:
            rows = ["#######", "#S...O#", "#.*...#", "#..*..#", "#...*.#", "#E...O#", "#######"]
        case 2:
            rows = ["#######", "#S.*.O#", "#.X...#", "#..O*.#", "#...X.#", "#E.*.O#", "#######"]
        default:
            return generate(seed: UInt64(max(0, id)) &* 7919 &+ 42, id: id)
        }
        var level = Level.map(id: id, rows: rows, brake: id == 2)
        level.par = Solver.solve(level)?.count ?? 0
        return level
    }

    static func generate(seed: UInt64, id: Int) -> Level {
        var rng = SeededRandom(state: seed)
        for _ in 0..<180 {
            let size = 7
            var tiles = [Tile](repeating: .floor, count: size * size)
            for y in 0..<size {
                for x in 0..<size {
                    let n = rng.number(100)
                    tiles[y * size + x] = (x == 0 || y == 0 || x == size - 1 || y == size - 1) ? .wall : n < 12 ? .wall : n < 21 ? .hazard : n < 32 ? .stop : .floor
                }
            }
            let free = (0..<tiles.count).filter { tiles[$0] == .floor }
            guard free.count >= 10 else { continue }
            let startIndex = free[rng.number(free.count)]
            let start = Point(x: startIndex % size, y: startIndex / size)
            // Walk the directed movement graph first. Gems and exit are then placed
            // on a witnessed safe route, before checking the exact final rules.
            let base = Level(id: id, size: size, tiles: tiles, start: start,
                             exit: Point(x: -1, y: -1), gems: [], brake: false, par: 0)
            var state = base.initial
            var visited: [Point] = []
            for _ in 0..<16 {
                let options = Direction.allCases.map { Rules.move(state, in: base, action: Action(direction: $0)) }
                    .filter { !$0.path.isEmpty && !$0.position.dead }
                guard !options.isEmpty else { break }
                let next = options[rng.number(options.count)]
                for p in next.path where p != start && !visited.contains(p) { visited.append(p) }
                state = next.position
            }
            let exit = state.point
            var choices = visited.filter { $0 != exit }
            guard exit != start, choices.count >= 5 else { continue }
            var gems: [Point] = []
            for _ in 0..<4 { gems.append(choices.remove(at: rng.number(choices.count))) }
            var level = Level(id: id, size: size, tiles: tiles, start: start, exit: exit, gems: gems, brake: true, par: 0)
            guard let solution = Solver.solve(level), solution.count >= 5, solution.count <= 16 else { continue }
            level.par = solution.count
            return level
        }
        // Bounded generation always returns a playable board, even for an unlucky seed.
        let fallback = make(2)
        return Level(id: id, size: fallback.size, tiles: fallback.tiles, start: fallback.start,
                     exit: fallback.exit, gems: fallback.gems, brake: true, par: fallback.par)
    }
}
