import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var session: PuzzleSession
    @Published private(set) var isGenerating = false
    var level: Level { session.level }
    var actions: [Action] { session.actions }
    var difficulty: Difficulty { session.difficulty }
    @Published private(set) var position: Position
    private var prepared: Task<Level, Never>?
    @Published var hint: Action?
    @Published var message = ""
    @Published var trail: [Point] = []
    @Published private(set) var isAnimating = false
    private var animationTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let saveKey = "glintwake.session.v3"

    struct LegacySave: Codable {
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
        let restored: PuzzleSession
        if let data = defaults.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode(PuzzleSession.self, from: data) {
            restored = saved
        } else if let data = defaults.data(forKey: "glintwake.session.v2"),
                  let old = try? JSONDecoder().decode(PuzzleSession.self, from: data) {
            restored = old.migratingToSlidingOnly()
        } else if let data = defaults.data(forKey: "glintwake.session.v1"),
                  let old = try? JSONDecoder().decode(LegacySave.self, from: data) {
            let level = Levels.make(min(max(old.levelID, 0), 1_000_000))
            let mode: Difficulty = level.par <= 6 ? .easy : level.par <= 10 ? .medium : .hard
            restored = PuzzleSession(level: level, difficulty: mode,
                                     credited: old.best[String(old.levelID)] != nil).migratingToSlidingOnly()
        } else {
            let level = testing ? Levels.make(0) : Levels.puzzle(seed: UInt64.random(in: 0...UInt64.max), difficulty: .easy)
            restored = PuzzleSession(level: level, difficulty: .easy)
        }
        session = restored
        position = restored.position
        persist()
    }

    var moves: Int { actions.count }
    var outcome: AttemptOutcome { .evaluate(position, level: level, moves: moves) }
    var won: Bool { outcome == .won }
    var finished: Bool { outcome != .playing }
    var lesson: String { "Difficulty.\(difficulty.rawValue).Detail".localized }
    func count(_ difficulty: Difficulty) -> Int { session.counts[difficulty.rawValue, default: 0] }

    func move(_ direction: Direction) {
        guard !isAnimating, !isGenerating, !finished else { return }
        let action = Action(direction: direction)
        let next = Rules.move(position, in: level, action: action)
        guard !next.path.isEmpty else { return }
        trail = [position.point] + next.path
        let collected = next.position.collected > position.collected
        position = next.position
        session.actions.append(action)
        hint = nil
        message = ""
        isAnimating = true
        if won {
            session.creditCompletion()
            if prepared == nil { prepared = generate(difficulty) }
        }
        AudioController.shared.play(won ? .win : finished ? .failure : collected ? .crystal : .slide)
        persist()
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            self?.isAnimating = false
        }
    }

    func undo() {
        guard !isGenerating, !actions.isEmpty else { return }
        clearTransient()
        session.actions.removeLast()
        position = actions.reduce(level.initial) { Rules.move($0, in: level, action: $1).position }
        persist()
        AudioController.shared.play(.undo)
    }

    func restart() {
        guard !isGenerating else { return }
        clearTransient()
        session.actions = []
        position = level.initial
        persist()
    }

    private func generate(_ difficulty: Difficulty) -> Task<Level, Never> {
        let seed = UInt64.random(in: 0...UInt64.max)
        return Task.detached(priority: .userInitiated) { Levels.puzzle(seed: seed, difficulty: difficulty) }
    }

    func newPuzzle(_ mode: Difficulty? = nil) {
        guard !isGenerating else { return }
        let target = mode ?? difficulty
        let work = target == difficulty ? (prepared ?? generate(target)) : generate(target)
        prepared = nil
        clearTransient()
        isGenerating = true
        Task { [weak self] in
            let level = await work.value
            guard let self else { return }
            self.session.replace(with: level, difficulty: target)
            self.position = level.initial
            self.isGenerating = false
            self.persist()
        }
    }

    func next() { guard won else { return }; newPuzzle() }

    func showHint() {
        guard !isGenerating, !finished, !isAnimating else { return }
        if let solution = Solver.solve(level, from: position), let step = solution.first {
            guard solution.count <= level.par - moves else {
                hint = nil
                message = "Hint.OverBudget".localized
                return
            }
            hint = step
            message = "Hint.Direction".localized
        } else {
            hint = nil
            message = "Hint.NoRoute".localized
        }
    }

    private func clearTransient() {
        animationTask?.cancel()
        isAnimating = false
        hint = nil
        message = ""
        trail = []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: saveKey)
        }
    }
}
