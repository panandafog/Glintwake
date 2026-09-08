import SwiftUI

struct BoardView: View {
    @ObservedObject var game: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / CGFloat(game.level.size)
            ZStack(alignment: .topLeading) {
                ForEach(0..<(game.level.size * game.level.size), id: \.self) { index in
                    let p = Point(x: index % game.level.size, y: index / game.level.size)
                    tile(p, cell: cell)
                        .frame(width: cell - 4, height: cell - 4)
                        .position(center(p, cell: cell))
                }
                if game.trail.count > 1 && !reduceMotion {
                    route(game.trail, cell: cell)
                        .stroke(Palette.mint.opacity(0.18), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 6]))
                        .allowsHitTesting(false)
                }
                if let hint = game.hint {
                    let path = Rules.move(game.position, in: game.level, action: hint).path
                    route([game.position.point] + path, cell: cell)
                        .stroke(Palette.gold.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5]))
                        .allowsHitTesting(false)
                }
                traveller
                    .frame(width: cell * 0.53, height: cell * 0.53)
                    .position(center(game.position.point, cell: cell))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: game.position.point)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 16).onEnded { value in
                if let direction = Direction.from(dx: value.translation.width, dy: value.translation.height) {
                    game.move(direction)
                }
            })
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(9)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .accessibilityIdentifier("board")
    }

    private func center(_ p: Point, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.x) + 0.5) * cell, y: (CGFloat(p.y) + 0.5) * cell)
    }

    private func route(_ points: [Point], cell: CGFloat) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: center(first, cell: cell))
            for point in points.dropFirst() { path.addLine(to: center(point, cell: cell)) }
        }
    }

    private var traveller: some View {
        ZStack {
            Circle().fill(game.position.dead ? Palette.coral : Palette.mint)
                .shadow(color: Palette.mint.opacity(0.35), radius: 12)
            Image(systemName: game.position.dead ? "xmark" : "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.background)
        }
    }

    private func tile(_ p: Point, cell: CGFloat) -> some View {
        let kind = game.level.tile(at: p)
        let gem = game.level.gems.firstIndex(of: p).map { game.position.gems & (1 << $0) == 0 } ?? false
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(kind == .wall ? Palette.background.opacity(0.8) : Palette.tile)
            if kind == .wall {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                    .frame(width: cell * 0.28, height: 3)
            }
            if kind == .stop {
                Circle().stroke(Palette.mint.opacity(0.75), lineWidth: 2)
                    .padding(cell * 0.23)
                Circle().fill(Palette.mint.opacity(0.12)).padding(cell * 0.33)
            }
            if kind == .hazard {
                Image(systemName: "burst.fill")
                    .font(.system(size: cell * 0.40))
                    .foregroundStyle(Palette.coral)
            }
            if p == game.level.exit {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: cell * 0.36, weight: .medium))
                    .foregroundStyle(game.position.gems == game.level.allGems ? Palette.mint : Palette.secondary)
                RoundedRectangle(cornerRadius: 7)
                    .stroke(game.position.gems == game.level.allGems ? Palette.mint : Palette.secondary.opacity(0.4), lineWidth: 1.5)
                    .padding(5)
            }
            if gem {
                Image(systemName: "diamond.fill")
                    .font(.system(size: cell * 0.31))
                    .foregroundStyle(Palette.gold)
                    .shadow(color: Palette.gold.opacity(0.22), radius: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellLabel(p, kind: kind, gem: gem))
    }

    private func cellLabel(_ p: Point, kind: Tile, gem: Bool) -> String {
        var parts = ["Cell.Coordinates".localized(p.y + 1, p.x + 1)]
        if p == game.position.point { parts.append("Cell.Traveller".localized) }
        if p == game.level.exit { parts.append("Cell.Exit".localized) }
        if gem { parts.append("Cell.Crystal".localized) }
        switch kind {
        case .wall: parts.append("Cell.Wall".localized)
        case .stop: parts.append("Cell.Stop".localized)
        case .hazard: parts.append("Cell.Hazard".localized)
        case .floor: break
        }
        return parts.joined(separator: ", ")
    }
}
