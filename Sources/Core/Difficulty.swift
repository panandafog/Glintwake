import Foundation

enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard
    var titleKey: String { "Difficulty.\(rawValue)" }
    var crystals: Int { switch self { case .easy: 2; case .medium: 4; case .hard: 5 } }
    var moves: ClosedRange<Int> { switch self { case .easy: 3...6; case .medium: 7...10; case .hard: 11...16 } }
    var minimumChoices: Double { switch self { case .easy: 1; case .medium: 2; case .hard: 2.8 } }
    /// Fixed, solver-verified boards keep bounded generation within the selected profile.
    var fallback: Level {
        let rows: [String]
        let start: Point, exit: Point
        let gems: [Point]
        let par: Int
        switch self {
        case .easy:
            rows = ["#######", "#...#.#", "#OO..O#", "#X....#", "#.....#", "#.....#", "#######"]
            start = Point(x: 2, y: 1); exit = Point(x: 5, y: 1)
            gems = [Point(x: 5, y: 5), Point(x: 5, y: 3)]; par = 4
        case .medium:
            rows = ["#######", "#..#O.#", "##O#..#", "#X....#", "#.....#", "##....#", "#######"]
            start = Point(x: 2, y: 4); exit = Point(x: 2, y: 5)
            gems = [Point(x: 2, y: 1), Point(x: 2, y: 3), Point(x: 4, y: 4), Point(x: 2, y: 2)]; par = 7
        case .hard:
            rows = ["#######", "#X....#", "#.#.O##", "#..O..#", "#..O###", "#.....#", "#######"]
            start = Point(x: 1, y: 2); exit = Point(x: 1, y: 5)
            gems = [Point(x: 4, y: 1), Point(x: 3, y: 5), Point(x: 1, y: 3), Point(x: 5, y: 3), Point(x: 3, y: 4)]; par = 11
        }
        return Level(id: 0, size: 7, tiles: rows.flatMap { $0.map { $0 == "#" ? .wall : $0 == "O" ? .stop : $0 == "X" ? .hazard : .floor } },
                     start: start, exit: exit, gems: gems, par: par)
    }
}

enum PuzzleQuality {
    /// Distinct safe continuations along an optimal route, using sliding moves.
    /// This measures branching, not human difficulty; profiles also constrain gems and route length.
    static func meanChoices(_ level: Level, solution: [Action]) -> Double {
        var state = level.initial
        var count = 0
        for step in solution {
            var destinations = Set<Position>()
            for direction in Direction.allCases {
                let next = Rules.move(state, in: level, action: Action(direction: direction))
                if !next.path.isEmpty && !next.position.dead { destinations.insert(next.position) }
            }
            count += destinations.count
            state = Rules.move(state, in: level, action: step).position
        }
        return Double(count) / Double(max(1, solution.count))
    }
}

struct PuzzleSession: Codable {
    var level: Level
    var difficulty: Difficulty
    var actions: [Action] = []
    var counts: [Difficulty.RawValue: Int] = [:]
    var credited = false

    /// Old moves may have used a removed rule. Restart the field with a new exact limit,
    /// or replace it if sliding alone cannot solve it. Preserve aggregate progress.
    func migratingToSlidingOnly() -> Self {
        var migrated = self
        migrated.actions = []
        if let solution = Solver.solve(level) {
            migrated.level.par = solution.count
        } else {
            migrated.level = difficulty.fallback
            migrated.credited = false
        }
        return migrated
    }

    var position: Position { actions.reduce(level.initial) { Rules.move($0, in: level, action: $1).position } }
    mutating func creditCompletion() {
        guard !credited, AttemptOutcome.evaluate(position, level: level, moves: actions.count) == .won else { return }
        counts[difficulty.rawValue, default: 0] += 1
        credited = true
    }
    mutating func replace(with level: Level, difficulty: Difficulty) {
        self.level = level
        self.difficulty = difficulty
        actions = []
        credited = false
    }
}
