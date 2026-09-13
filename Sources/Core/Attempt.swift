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
