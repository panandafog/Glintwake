import Testing
@testable import GlintwakeCore

@Test func firstRouteHasThreeMoveSolution() throws {
    let level = Levels.make(0)
    let solution = try #require(Solver.solve(level))
    #expect(solution.map(\.direction) == [.east, .south, .west])
    let finish = solution.reduce(level.initial) { Rules.move($0, in: level, action: $1).position }
    #expect(finish.won(level))
    #expect(level.par == 3)
}

@Test func completionRequiresOptimalMoveBudget() throws {
    let level = Levels.make(0)
    let solution = try #require(Solver.solve(level))
    let finish = solution.reduce(level.initial) { Rules.move($0, in: level, action: $1).position }
    #expect(AttemptOutcome.evaluate(finish, level: level, moves: level.par) == .won)
    // Old saved wins with detours must not be certified as optimal completions.
    #expect(AttemptOutcome.evaluate(finish, level: level, moves: level.par + 2) == .exhausted)
    var position = level.initial
    for direction in [Direction.east, .west, .east] {
        position = Rules.move(position, in: level, action: Action(direction: direction)).position
    }
    #expect(AttemptOutcome.evaluate(position, level: level, moves: 3) == .exhausted)
    #expect(AttemptOutcome.evaluate(level.initial, level: level, moves: 2) == .playing)
    var dead = finish
    dead.dead = true
    #expect(AttemptOutcome.evaluate(dead, level: level, moves: level.par) == .hazard)
}

@Test func gemsDoNotStopSlidingAndRingsDo() {
    let level = Levels.make(0)
    let next = Rules.move(level.initial, in: level, action: Action(direction: .east))
    #expect(next.path.count == 4)
    #expect(next.position.point == Point(x: 5, y: 1))
    #expect(next.position.collected == 1)
}

@Test func blockedMoveDoesNotSpendBrake() {
    let level = Levels.make(2)
    let next = Rules.move(level.initial, in: level, action: Action(direction: .north, brake: true))
    #expect(next.path.isEmpty)
    #expect(next.position == level.initial)
}

@Test func brakeIsOneCellAndSingleUse() {
    let level = Levels.make(2)
    let next = Rules.move(level.initial, in: level, action: Action(direction: .east, brake: true))
    #expect(next.position.point == Point(x: 2, y: 1))
    #expect(!next.position.brake)
    #expect(Rules.move(next.position, in: level, action: Action(direction: .east, brake: true)).path.isEmpty)
}

@Test func lastCrystalDoesNotProtectFromHazard() {
    let level = Level.map(id: 0, rows: ["#######", "#S.*X.#", "#.....#", "#.....#", "#.....#", "#E....#", "#######"])
    let next = Rules.move(level.initial, in: level, action: Action(direction: .east))
    #expect(next.position.gems == level.allGems)
    #expect(next.position.dead)
    #expect(!next.position.won(level))
    #expect(Solver.solve(level, from: next.position) == nil)
    #expect(Rules.move(next.position, in: level, action: Action(direction: .west)).path.isEmpty)
}

@Test func diagonalCannotCutCorner() {
    let level = Level.map(id: 0, rows: ["#####", "#S#.#", "#.*.#", "#..E#", "#####"])
    #expect(Rules.move(level.initial, in: level, action: Action(direction: .southEast)).path.isEmpty)
}

@Test func lockedExitIsFloorAndUnlockedExitStops() {
    let level = Level.map(id: 0, rows: ["#######", "#S.E.*#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"])
    let outward = Rules.move(level.initial, in: level, action: Action(direction: .east))
    #expect(outward.position.point == Point(x: 5, y: 1))
    let inward = Rules.move(outward.position, in: level, action: Action(direction: .west))
    #expect(inward.position.point == level.exit)
    #expect(inward.position.won(level))
    #expect(Rules.move(inward.position, in: level, action: Action(direction: .east)).path.isEmpty)
}

@Test func directionQuantizationCoversEightWays() {
    for d in Direction.allCases {
        #expect(Direction.from(dx: Double(d.dx * 100), dy: Double(d.dy * 100)) == d)
    }
    #expect(Direction.from(dx: 2, dy: 4) == nil)
}

@Test(arguments: 0..<12) func campaignIsSolvable(id: Int) throws {
    let level = Levels.make(id)
    let route = try #require(Solver.solve(level))
    #expect(!route.isEmpty)
    #expect(route.count == level.par)
    var position = level.initial
    for step in route {
        let next = Rules.move(position, in: level, action: step)
        #expect(!next.path.isEmpty)
        #expect(!next.position.dead)
        position = next.position
    }
    #expect(position.won(level))
}

@Test func generatedBoardsAreDeterministicDiverseAndSolvable() throws {
    var layouts: Set<[Tile]> = []
    for seed in 0..<32 {
        let a = Levels.generate(seed: UInt64(seed), id: seed + 12)
        let b = Levels.generate(seed: UInt64(seed), id: seed + 12)
        #expect(a == b)
        let steps = try #require(Solver.solve(a))
        #expect(steps.reduce(a.initial) { Rules.move($0, in: a, action: $1).position }.won(a))
        layouts.insert(a.tiles)
    }
    #expect(layouts.count >= 28)
}
