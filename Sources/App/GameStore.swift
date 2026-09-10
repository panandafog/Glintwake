import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var level: Level
    @Published private(set) var position: Position
    @Published private(set) var actions: [Action] = []
    @Published private(set) var best: [String: Int] = [:]
    @Published private(set) var completed: Set<Int> = []
    @Published private(set) var availableCount = RouteCatalog.pageSize
    @Published var brakeArmed = false
    @Published var hint: Action?
    @Published var message = ""
    @Published var trail: [Point] = []
    @Published private(set) var isAnimating = false
    private var animationTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let saveKey = "glintwake.session.v1"

    struct Save: Codable {
        var levelID: Int
        var actions: [Action]
        var best: [String: Int]
        var completed: Set<Int>?
        var availableCount: Int?
    }

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        defaults = testing ? UserDefaults(suiteName: "Glintwake.UITests")! : .standard
        if testing && !ProcessInfo.processInfo.arguments.contains("--keep-test-session") {
            defaults.removePersistentDomain(forName: "Glintwake.UITests")
        }
        let saved = defaults.data(forKey: saveKey).flatMap { try? JSONDecoder().decode(Save.self, from: $0) }
        let id = min(max(saved?.levelID ?? 0, 0), 1_000_000)
        let first = Levels.make(id)
        level = first
        position = first.initial
        best = saved?.best ?? [:]
        availableCount = RouteCatalog.upperBound(current: id, best: best, saved: saved?.availableCount)
        if let completed = saved?.completed {
            self.completed = completed
        } else {
            // Keep legacy scores and opened routes, but only certify optimal completions.
            completed = Set(best.compactMap { key, moves in
                guard let id = Int(key), id >= 0, id <= 1_000_000,
                      moves == Levels.make(id).par else { return nil }
                return id
            })
        }
        for action in (saved?.actions ?? []).prefix(1000) {
            let next = Rules.move(position, in: first, action: action)
            guard !next.path.isEmpty else { break }
            actions.append(action)
            position = next.position
        }
    }

    var moves: Int { actions.count }
    var outcome: AttemptOutcome { .evaluate(position, level: level, moves: moves) }
    var won: Bool { outcome == .won }
    var finished: Bool { outcome != .playing }
    var lesson: String {
        switch level.id {
        case 0: "Route.First.Lesson".localized
        case 1: "Route.Second.Lesson".localized
        case 2: "Route.Third.Lesson".localized
        default: "Route.Generated.Lesson".localized
        }
    }

    func move(_ direction: Direction) {
        guard !isAnimating, !finished else { return }
        let action = Action(direction: direction, brake: brakeArmed)
        let next = Rules.move(position, in: level, action: action)
        guard !next.path.isEmpty else { return }
        trail = [position.point] + next.path
        let collected = next.position.collected > position.collected
        position = next.position
        actions.append(action)
        brakeArmed = false
        hint = nil
        message = ""
        isAnimating = true
        if won {
            let key = String(level.id)
            best[key] = min(best[key] ?? Int.max, moves)
            completed.insert(level.id)
        }
        AudioController.shared.play(won ? .win : finished ? .failure : collected ? .crystal : action.brake ? .brake : .slide)
        persist()
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            self?.isAnimating = false
        }
    }

    func undo() {
        guard !actions.isEmpty else { return }
        clearTransient()
        actions.removeLast()
        position = actions.reduce(level.initial) { Rules.move($0, in: level, action: $1).position }
        persist()
        AudioController.shared.play(.undo)
    }

    func restart() {
        clearTransient()
        actions = []
        position = level.initial
        persist()
    }

    func select(_ id: Int) {
        clearTransient()
        level = Levels.make(id)
        availableCount = max(availableCount, id + 1)
        position = level.initial
        actions = []
        persist()
    }

    func next() { select(level.id + 1) }

    @discardableResult
    func revealMore() -> Int {
        let first = availableCount
        availableCount += RouteCatalog.pageSize
        persist()
        return first
    }

    func toggleBrake() {
        guard position.brake, !finished, !isAnimating else { return }
        brakeArmed.toggle()
        hint = nil
        message = ""
        AudioController.shared.play(.brake)
    }

    func showHint() {
        guard !finished, !isAnimating else { return }
        if let solution = Solver.solve(level, from: position), let step = solution.first {
            guard solution.count <= level.par - moves else {
                hint = nil
                message = "Hint.OverBudget".localized
                return
            }
            hint = step
            brakeArmed = step.brake
            message = step.brake ? "Hint.Brake".localized : "Hint.Direction".localized
        } else {
            hint = nil
            message = "Hint.NoRoute".localized
        }
    }

    private func clearTransient() {
        animationTask?.cancel()
        isAnimating = false
        brakeArmed = false
        hint = nil
        message = ""
        trail = []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Save(levelID: level.id, actions: actions, best: best, completed: completed, availableCount: availableCount)) {
            defaults.set(data, forKey: saveKey)
        }
    }
}
