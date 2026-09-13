import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameStore()
    @ObservedObject private var audio = AudioController.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAudio = false
    @State private var showLevels = false
    @State private var showHelp = false
    @State private var confirmRestart = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                header
                if geo.size.width >= 640 || (geo.size.height < 480 && geo.size.width >= 520) {
                    HStack(spacing: 24) {
                        VStack(spacing: 10) {
                            routeStatus
                            fittedBoard
                        }
                        controls.frame(width: 330)
                    }
                } else {
                    routeStatus
                    fittedBoard
                    controls
                }
            }
            .padding(16)
            .frame(maxWidth: 1000, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Palette.background
                    RadialGradient(colors: [Palette.mint.opacity(0.07), .clear], center: .topLeading, startRadius: 0, endRadius: 600)
                }.ignoresSafeArea()
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showLevels) { levelPicker }
        .sheet(isPresented: $showHelp) { help }
        .sheet(isPresented: $showAudio) { audioSettings }
        .onChange(of: scenePhase, initial: true) { _, phase in audio.setActive(phase == .active) }
        .confirmationDialog("Restart.Confirm".localized, isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Button.Restart".localized, role: .destructive) { game.restart() }
        }
        #if os(macOS)
        .background(keyboardShortcuts)
        #endif
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("App.Name".localized.uppercased()).font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3).foregroundStyle(Palette.mint)
            Spacer(minLength: 8)
            Button { showLevels = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                    Text(String(format: "%02d", game.level.id + 1)).monospacedDigit()
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.mint)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Palette.mint.opacity(0.08), in: Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("levels")
            Button { showHelp = true } label: {
                Image(systemName: "questionmark").font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44).background(Palette.panel, in: Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Help.Title".localized)
            .accessibilityIdentifier("help")
        }
    }

    /// The board receives only the space left after the controls have been measured.
    /// There is no scroll container on the play screen to compete with board swipes.
    private var fittedBoard: some View {
        GeometryReader { geometry in
            let side = max(1, min(geometry.size.width, geometry.size.height))
            BoardView(game: game)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var routeStatus: some View {
        HStack(spacing: 6) {
            Text("Game.Limit".localized(game.level.par))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            stat("diamond.fill", "\(game.position.collected)/\(game.level.gems.count)", color: Palette.gold)
                .accessibilityIdentifier("crystals")
            stat("arrow.triangle.turn.up.right.diamond", "\(game.moves)/\(game.level.par)", color: game.outcome == .exhausted ? Palette.coral : Palette.secondary)
                .accessibilityIdentifier("moves")
        }.frame(height: 24)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if game.finished && !game.isAnimating {
                resultCard
            } else {
                HStack(alignment: .center, spacing: 14) {
                    directionPad
                    VStack(alignment: .leading, spacing: 8) {
                        Button { showAudio = true } label: {
                            Label("Audio.Title".localized, systemImage: audio.effectsEnabled || audio.ambienceEnabled ? "speaker.wave.2" : "speaker.slash")
                                .font(.system(size: 12, weight: .medium))
                        }.buttonStyle(SoftButton()).accessibilityIdentifier("audio-settings")
                        if game.level.brake {
                            Button {
                                game.toggleBrake()
                            } label: {
                                Label(game.brakeArmed ? "Brake.Armed".localized : "Brake.Title".localized, systemImage: "pause.circle")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(SoftButton(highlighted: game.brakeArmed))
                            .disabled(!game.position.brake || game.isAnimating)
                            .opacity(game.position.brake ? 1 : 0.35)
                            .accessibilityIdentifier("brake")
                        }
                        if !game.message.isEmpty {
                            Text(game.message)
                                .font(.system(size: 11)).foregroundStyle(Palette.gold)
                                .lineLimit(4).minimumScaleFactor(0.8)
                                .accessibilityIdentifier("guidance")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: directionSize * 3 + 12)
            }
            HStack(spacing: 10) {
                Button { game.undo() } label: {
                    Label("Button.Undo".localized, systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }.disabled(game.actions.isEmpty).opacity(game.actions.isEmpty ? 0.4 : 1).accessibilityIdentifier("undo")
                Button { if game.moves == 0 { game.restart() } else { confirmRestart = true } } label: {
                    Image(systemName: "arrow.counterclockwise")
                }.accessibilityLabel("Button.Restart".localized).accessibilityIdentifier("restart")
                Button { game.showHint() } label: {
                    Label("Button.Hint".localized, systemImage: "lightbulb").frame(maxWidth: .infinity)
                }.disabled(game.finished || game.isAnimating).accessibilityIdentifier("hint")
            }
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .buttonStyle(SoftButton())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var directionSize: CGFloat {
        #if os(iOS)
        56
        #else
        44
        #endif
    }

    private var directionPad: some View {
        let grid: [[Direction?]] = [[.northWest, .north, .northEast], [.west, nil, .east], [.southWest, .south, .southEast]]
        return VStack(spacing: 6) {
            ForEach(0..<3) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3) { column in
                        if let direction = grid[row][column] {
                            let suggested = game.hint?.direction == direction
                            Button { game.move(direction) } label: {
                                Image(systemName: direction.symbol)
                                    .font(.system(size: directionSize * 0.4, weight: .medium))
                                    .foregroundStyle(suggested ? Palette.background : Palette.mint)
                                    .frame(width: directionSize, height: directionSize)
                                    .background(suggested ? Palette.gold : Palette.panel, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain).disabled(game.isAnimating)
                            .accessibilityLabel(directionName(direction))
                            .accessibilityIdentifier("direction-\(direction.rawValue)")
                        } else {
                            Image(systemName: "sparkle").foregroundStyle(Palette.mint.opacity(0.45))
                                .frame(width: directionSize, height: directionSize).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 12) {
            Label(game.won ? "Result.Victory".localized : game.outcome == .exhausted ? "Result.Exhausted".localized : "Result.Defeat".localized, systemImage: game.won ? "checkmark.seal.fill" : "burst.fill")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(game.won ? Palette.mint : Palette.coral)
                .accessibilityIdentifier(game.won ? "victory" : game.outcome == .exhausted ? "exhausted" : "defeat")
            Text(game.won ? "Result.Perfect".localized(game.moves) : game.outcome == .exhausted ? "Result.Budget".localized(game.level.par) : "Result.Undo".localized)
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            Button { game.won ? game.next() : game.restart() } label: {
                Label(game.won ? "Button.NextRoute".localized : "Button.TryAgain".localized, systemImage: game.won ? "arrow.right" : "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(SoftButton(highlighted: true)).accessibilityIdentifier("result-action")
        }
        .padding(18).frame(maxWidth: .infinity)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ icon: String, _ text: String, color: Color) -> some View {
        Label(text, systemImage: icon).font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(color).padding(.leading, 12)
    }
    private func directionName(_ d: Direction) -> String {
        let keys = ["Direction.North", "Direction.NorthEast", "Direction.East", "Direction.SouthEast", "Direction.South", "Direction.SouthWest", "Direction.West", "Direction.NorthWest"]
        return keys[d.rawValue].localized
    }

    private var levelPicker: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Routes.Description".localized)
                            .foregroundStyle(Palette.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                            ForEach(0..<game.availableCount, id: \.self) { id in
                                Button {
                                    game.select(id)
                                    showLevels = false
                                } label: {
                                    VStack(spacing: 9) {
                                        Text(String(format: "%02d", id + 1)).font(.system(size: 27, weight: .medium, design: .rounded))
                                        Image(systemName: game.completed.contains(id) ? "checkmark.circle.fill" : id < 3 ? "sparkle" : "circle.dotted")
                                            .foregroundStyle(Palette.mint)
                                    }.frame(maxWidth: .infinity).frame(height: 90)
                                }
                                .buttonStyle(SoftButton(highlighted: game.level.id == id))
                                .accessibilityIdentifier("level-\(id)")
                                .accessibilityLabel((game.completed.contains(id) ? "Routes.CompletedLevel" : "Routes.Level").localized(id + 1))
                                .id(id)
                            }
                        }
                        Button {
                            game.revealMore()
                        } label: {
                            Label("Button.MoreLevels".localized(RouteCatalog.pageSize), systemImage: "sparkles").frame(maxWidth: .infinity)
                        }.buttonStyle(SoftButton(highlighted: true)).accessibilityIdentifier("explore")
                    }.padding(22)
                }
                .background(Palette.background)
                .onAppear { proxy.scrollTo(game.level.id, anchor: .center) }
                .onChange(of: game.availableCount) { old, _ in proxy.scrollTo(old, anchor: .top) }
            }
            .navigationTitle("Routes.Title".localized)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Button.Done".localized) { showLevels = false } } }
        }
        .frame(minWidth: 300, idealWidth: 420, minHeight: 340, idealHeight: 450)
    }

    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(game.lesson).font(.callout).foregroundStyle(Palette.mint)
                    Text("Help.Intro".localized)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    helpRow("arrow.up.right", "Help.Direction.Title".localized, "Help.Direction.Body".localized, Palette.mint)
                    helpRow("diamond.fill", "Help.Crystals.Title".localized, "Help.Crystals.Body".localized, Palette.gold)
                    helpRow("burst.fill", "Help.Hazards.Title".localized, "Help.Hazards.Body".localized, Palette.coral)
                    helpRow("pause.circle", "Help.Brake.Title".localized, "Help.Brake.Body".localized, Palette.mint)
                    Text("Help.Par.Body".localized)
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    #if os(macOS)
                    Text("Help.Keyboard".localized)
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    #endif
                }.padding(24)
            }
            .background(Palette.background)
            .navigationTitle("Help.Title".localized)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Button.Play".localized) { showHelp = false } } }
        }.frame(minWidth: 300, idealWidth: 420, minHeight: 340, idealHeight: 450)
    }

    private var audioSettings: some View {
        NavigationStack {
            Form {
                Toggle("Audio.Effects".localized, isOn: $audio.effectsEnabled)
                    .accessibilityIdentifier("audio-effects")
                Toggle("Audio.Ambience".localized, isOn: $audio.ambienceEnabled)
                    .accessibilityIdentifier("audio-ambience")
                Text("Audio.Description".localized).font(.footnote).foregroundStyle(Palette.secondary)
            }
            .navigationTitle("Audio.Title".localized)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Button.Done".localized) { showAudio = false } } }
        }.frame(minWidth: 300, idealWidth: 380, minHeight: 260, idealHeight: 300)
    }

    private func helpRow(_ icon: String, _ title: String, _ detail: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.system(size: 14)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    #if os(macOS)
    private var keyboardShortcuts: some View {
        Group {
            ForEach(Array(zip(Direction.allCases, ["w", "e", "d", "c", "x", "z", "a", "q"])), id: \.0) { direction, key in
                Button("") { game.move(direction) }.keyboardShortcut(KeyEquivalent(Character(key)), modifiers: [])
            }
            Button("") { game.move(.north) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { game.move(.east) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { game.move(.south) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { game.move(.west) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { game.toggleBrake() }.keyboardShortcut("b", modifiers: [])
        }.hidden().disabled(showHelp || showLevels || showAudio || confirmRestart)
    }
    #endif
}
