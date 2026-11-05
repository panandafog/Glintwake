import Foundation

/// Exact collection-order analysis. Unlike the full solver, the greedy player
/// plans only as far as the next crystal. All equally near targets and paths are
/// considered, so a direction tie-break cannot make an easy board appear hard.
struct RouteAssessment: Equatable {
    let optimalMoves: Int
    let greedyMoves: Int?
    let minimumOrderDecisions: Int

    var greedyExtraMoves: Int { greedyMoves.map { $0 - optimalMoves } ?? Int.max }

    func meets(_ difficulty: Difficulty) -> Bool {
        switch difficulty {
        case .easy: true
        case .medium: greedyExtraMoves >= 1 && minimumOrderDecisions >= 1
        case .hard: greedyExtraMoves >= 2 && minimumOrderDecisions >= 1
        }
    }

    static func evaluate(_ level: Level) -> Self? {
        CollectionGraph(level).assessment()
    }
}

private final class CollectionGraph {
    struct Edge { let target: Int; let cost: Int }
    let level: Level
    var states: [Position]
    var edges: [[Int]] = []
    var distance: [Int] = []
    var collectionCache: [Int: [Edge]] = [:]
    var greedyCache: [Int: Int] = [:]
    var decisionCache: [Int: Int] = [:]
    let unreachable = 1_000_000

    init(_ level: Level) {
        self.level = level
        states = [level.initial]
        var index = [level.initial: 0]
        var head = 0
        while head < states.count {
            let state = states[head]
            var targets = Set<Int>()
            for direction in Direction.allCases {
                let next = Rules.move(state, in: level, action: Action(direction: direction))
                guard !next.path.isEmpty, !next.position.dead else { continue }
                let target: Int
                if let existing = index[next.position] { target = existing }
                else {
                    target = states.count
                    index[next.position] = target
                    states.append(next.position)
                }
                targets.insert(target)
            }
            edges.append(targets.sorted())
            head += 1
        }
        var reverse = [[Int]](repeating: [], count: states.count)
        for (source, targets) in edges.enumerated() {
            for target in targets { reverse[target].append(source) }
        }
        distance = [Int](repeating: unreachable, count: states.count)
        var queue: [Int] = []
        for i in states.indices where states[i].won(level) {
            distance[i] = 0
            queue.append(i)
        }
        head = 0
        while head < queue.count {
            let target = queue[head]; head += 1
            for source in reverse[target] where distance[source] == unreachable {
                distance[source] = distance[target] + 1
                queue.append(source)
            }
        }
    }

    /// First new collection reached from this state. Stop expansion at collection:
    /// traversing through a different crystal is a different collection order.
    func collections(from start: Int) -> [Edge] {
        if let cached = collectionCache[start] { return cached }
        var depths = [start: 0]
        var queue = [start], head = 0
        var result: [Edge] = []
        while head < queue.count {
            let source = queue[head]; head += 1
            for target in edges[source] where depths[target] == nil {
                let depth = depths[source]! + 1
                depths[target] = depth
                if states[target].gems != states[start].gems {
                    result.append(Edge(target: target, cost: depth))
                } else {
                    queue.append(target)
                }
            }
        }
        collectionCache[start] = result
        return result
    }

    func greedy(from start: Int) -> Int {
        if states[start].gems == level.allGems { return distance[start] }
        if let cached = greedyCache[start] { return cached }
        let options = collections(from: start)
        guard let nearest = options.map(\.cost).min() else { return unreachable }
        let best = options.filter { $0.cost == nearest }.map {
            min(unreachable, $0.cost + greedy(from: $0.target))
        }.min() ?? unreachable
        greedyCache[start] = best
        return best
    }

    /// Lower bound across ALL optimal solutions on collection stages that
    /// pass up the nearest crystals. Forced travel and immediate undo add nothing.
    func decisions(from start: Int) -> Int {
        if states[start].gems == level.allGems { return 0 }
        if let cached = decisionCache[start] { return cached }
        let options = collections(from: start)
        let nearest = options.map(\.cost).min() ?? unreachable
        let optimal = options.filter { $0.cost + distance[$0.target] == distance[start] }
        let result = optimal.map { ($0.cost > nearest ? 1 : 0) + decisions(from: $0.target) }.min() ?? 0
        decisionCache[start] = result
        return result
    }

    func assessment() -> RouteAssessment? {
        guard distance[0] < unreachable else { return nil }
        let greedyMoves = greedy(from: 0)
        return RouteAssessment(optimalMoves: distance[0],
                               greedyMoves: greedyMoves < unreachable ? greedyMoves : nil,
                               minimumOrderDecisions: decisions(from: 0))
    }
}
