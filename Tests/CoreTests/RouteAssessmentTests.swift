import Testing
@testable import GlintwakeCore

@Test func obviousRouteIsRejectedForHigherDifficulties() throws {
    let level = Levels.make(0)
    let report = try #require(RouteAssessment.evaluate(level))
    #expect(report.optimalMoves == 3)
    #expect(report.greedyMoves == 3)
    #expect(report.minimumOrderDecisions == 0)
    #expect(!report.meets(.medium) && !report.meets(.hard))
    #expect(report.meets(.easy))
}

@Test func unsolvableBoardHasNoAssessment() {
    let level = Level.map(id: 0, rows: ["#####", "#S#E#", "#####", "#.*.#", "#####"])
    #expect(RouteAssessment.evaluate(level) == nil)
}

@Test func collectionAnalysisDoesNotDependOnGemOrDirectionOrder() throws {
    // Rotating the board changes which direction is enumerated first by BFS.
    // Reversing gem indices changes bit masks, but neither changes the puzzle.
    for mode in Difficulty.allCases {
        let level = mode.fallback
        let report = try #require(RouteAssessment.evaluate(level))
        func rotate(_ p: Point) -> Point { Point(x: level.size - 1 - p.y, y: p.x) }
        var tiles = level.tiles
        for y in 0..<level.size {
            for x in 0..<level.size {
                let target = rotate(Point(x: x, y: y))
                tiles[target.y * level.size + target.x] = level.tiles[y * level.size + x]
            }
        }
        let rotated = Level(id: level.id, size: level.size, tiles: tiles,
                            start: rotate(level.start), exit: rotate(level.exit),
                            gems: level.gems.reversed().map(rotate), par: level.par)
        #expect(RouteAssessment.evaluate(rotated) == report)
        #expect(report.optimalMoves == Solver.solve(level)?.count)
    }
}

@Test func nearestCrystalOrderCanBeStrictlyWorse() throws {
    let medium = try #require(RouteAssessment.evaluate(Difficulty.medium.fallback))
    #expect(medium.optimalMoves == 7)
    #expect(medium.greedyMoves == 8)
    #expect(medium.minimumOrderDecisions == 1)
    #expect(medium.meets(.medium) && !medium.meets(.hard))
    let hard = try #require(RouteAssessment.evaluate(Difficulty.hard.fallback))
    #expect(hard.optimalMoves == 11)
    #expect(hard.greedyMoves == 13)
    #expect(hard.minimumOrderDecisions >= 1)
    #expect(hard.meets(.hard))
}
