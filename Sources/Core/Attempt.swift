import Foundation

enum AttemptOutcome: Equatable {
    case playing, won, hazard, exhausted

    static func evaluate(_ position: Position, level: Level, moves: Int) -> Self {
        if position.dead { return .hazard }
        if position.won(level) && moves <= level.par { return .won }
        if moves >= level.par { return .exhausted }
        return .playing
    }
}

enum RouteCatalog {
    static let pageSize = 12

    static func upperBound(current: Int, best: [String: Int], saved: Int?) -> Int {
        max(pageSize, current + 1, (best.keys.compactMap(Int.init).max() ?? -1) + 1, saved ?? 0)
    }
}
