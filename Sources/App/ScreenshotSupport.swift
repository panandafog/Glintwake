#if DEBUG
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Offline capture fixtures; the entire implementation is excluded from Release.
@MainActor
enum ScreenshotSupport {
    enum Scene: String, CaseIterable { case gameplay, planning, difficulty, victory }
    static let argument = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--screenshot-scene=") }
    static var isRequested: Bool { argument != nil }
    static var scene: Scene? { argument.flatMap { Scene(rawValue: String($0.dropFirst("--screenshot-scene=".count))) } }

    static func fixture() -> PuzzleSession {
        let mode: Difficulty = scene == .planning ? .hard : .medium
        let level = mode.fallback
        let route = Solver.solve(level)!
        let actions: [Action]
        switch scene {
        case .gameplay: actions = Array(route.prefix(2))
        case .planning, .difficulty, .none: actions = []
        case .victory: actions = route
        }
        return PuzzleSession(level: level, difficulty: mode, actions: actions,
                             counts: ["easy": 24, "medium": 12, "hard": 5], credited: scene == .victory)
    }

    #if os(macOS)
    static func configure(_ window: NSWindow) {
        guard isRequested else { return }
        window.isRestorable = false
        window.setFrameAutosaveName("")
        window.setFrame(NSRect(x: 0, y: 0, width: 1280, height: 800), display: true)
        window.center()
    }
    #endif
}

struct ScreenshotPresentation: ViewModifier {
    @Binding var showDifficulty: Bool
    func body(content: Content) -> some View {
        content
            .task {
                if ScreenshotSupport.scene == .difficulty {
                    await Task.yield()
                    showDifficulty = true
                }
            }
            .overlay {
                if ScreenshotSupport.isRequested && ScreenshotSupport.scene == nil {
                    Text("Unknown Glintwake screenshot scene").padding().background(.black)
                }
            }
            .background {
                #if os(macOS)
                ScreenshotWindowSetup()
                #endif
            }
    }
}

struct ScreenshotReadiness: ViewModifier {
    let sheet: Bool
    func body(content: Content) -> some View {
        if let scene = ScreenshotSupport.scene, sheet == (scene == .difficulty) {
            content.accessibilityIdentifier("screen." + scene.rawValue)
        } else { content }
    }
}

#if os(macOS)
private struct ScreenshotWindowSetup: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowView { WindowView() }
    func updateNSView(_ view: WindowView, context: Context) {}
    final class WindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { ScreenshotSupport.configure(window) }
        }
    }
}
#endif
#endif
