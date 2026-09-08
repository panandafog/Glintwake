import SwiftUI

@main
struct GlintwakeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 340, minHeight: 500)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 640)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}

enum Palette {
    static let background = Color(red: 0.035, green: 0.065, blue: 0.095)
    static let panel = Color(red: 0.065, green: 0.105, blue: 0.14)
    static let tile = Color(red: 0.09, green: 0.145, blue: 0.18)
    static let mint = Color(red: 0.46, green: 0.94, blue: 0.79)
    static let gold = Color(red: 1, green: 0.79, blue: 0.43)
    static let coral = Color(red: 1, green: 0.43, blue: 0.40)
    static let secondary = Color(red: 0.55, green: 0.66, blue: 0.71)
}

struct SoftButton: ButtonStyle {
    var highlighted = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(highlighted ? Palette.background : Color.white)
            .padding(.horizontal, 15).padding(.vertical, 13)
            .background(highlighted ? Palette.mint : Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
