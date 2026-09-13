import Foundation
import Testing
@testable import GlintwakeCore

@Test func profilesProduceDistinctSolvablePuzzles() throws {
    for difficulty in Difficulty.allCases {
        var boards = Set<[Tile]>()
        let started = Date()
        for seed in 0..<20 {
            let level = Levels.puzzle(seed: UInt64(seed * 7919), difficulty: difficulty)
            let solution = try #require(Solver.solve(level))
            #expect(solution.count == level.par)
            #expect(difficulty.moves.contains(level.par))
            #expect(level.gems.count == difficulty.crystals)
            #expect(level.brake == (difficulty != .easy))
            #expect(PuzzleQuality.meanChoices(level, solution: solution) >= difficulty.minimumChoices)
            #expect(solution.reduce(level.initial) { Rules.move($0, in: level, action: $1).position }.won(level))
            boards.insert(level.tiles)
        }
        print("PROFILE \(difficulty): \(boards.count)/20 distinct, \(Date().timeIntervalSince(started))s")
        #expect(boards.count >= 18)
    }
}

@Test func fallbacksMatchDifficultyAndExactMinimum() throws {
    for difficulty in Difficulty.allCases {
        let level = difficulty.fallback
        let solution = try #require(Solver.solve(level))
        #expect(solution.count == level.par)
        #expect(difficulty.moves.contains(level.par))
        #expect(PuzzleQuality.meanChoices(level, solution: solution) >= difficulty.minimumChoices)
    }
}

@Test func fullBoardAndOneTimeCreditSurviveRelaunch() throws {
    var session = PuzzleSession(level: Levels.make(0), difficulty: .easy)
    session.creditCompletion()
    #expect(session.counts.isEmpty)
    session.actions = try #require(Solver.solve(session.level))
    session.creditCompletion()
    #expect(session.counts["easy"] == 1)
    let data = try JSONEncoder().encode(session)
    session = try JSONDecoder().decode(PuzzleSession.self, from: data)
    #expect(session.level == Levels.make(0))
    session.actions.removeLast()
    session.actions.append(Action(direction: .west))
    session.creditCompletion()
    #expect(session.counts["easy"] == 1)
    session.actions = [] // Restart does not clear the credit flag.
    session.actions = try #require(Solver.solve(session.level))
    session.creditCompletion()
    #expect(session.counts["easy"] == 1)
    session.replace(with: Difficulty.hard.fallback, difficulty: .hard)
    session.actions = try #require(Solver.solve(session.level))
    session.creditCompletion()
    #expect(session.counts == ["easy": 1, "hard": 1])
    session.replace(with: Difficulty.medium.fallback, difficulty: .medium)
    #expect(session.counts == ["easy": 1, "hard": 1])
    #expect(session.actions.isEmpty && !session.credited)
}
