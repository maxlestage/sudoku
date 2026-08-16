import SwiftUI

/// One color per value 1..9 — same palette as the web app.
let valueColors: [Color] = [
    Color(red: 0.90, green: 0.22, blue: 0.27), // 1 red
    Color(red: 0.96, green: 0.64, blue: 0.38), // 2 orange
    Color(red: 0.91, green: 0.77, blue: 0.42), // 3 yellow
    Color(red: 0.16, green: 0.62, blue: 0.56), // 4 teal
    Color(red: 0.28, green: 0.58, blue: 0.94), // 5 blue
    Color(red: 0.48, green: 0.17, blue: 0.75), // 6 purple
    Color(red: 1.00, green: 0.44, blue: 0.65), // 7 pink
    Color(red: 0.50, green: 0.73, blue: 0.09), // 8 green
    Color(red: 0.55, green: 0.43, blue: 0.39), // 9 brown
]

/// The board is laid out at an explicit `side` computed by ContentView.
/// A GeometryReader here would have no intrinsic size and would collapse to
/// whatever vertical space the surrounding VStack had left over.
struct BoardView: View {
    @EnvironmentObject var store: GameStore
    let game: GameState
    let side: CGFloat

    var body: some View {
        let n = game.puzzle.size
        let cell = side / CGFloat(n)
        let conflicts = store.conflicts()

        VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in
                        CellView(
                            value: game.entries[r][c],
                            notes: game.notes[r][c],
                            given: game.puzzle.puzzle[r][c] != 0,
                            selected: store.selected?.row == r && store.selected?.col == c,
                            conflict: conflicts[r][c],
                            sameAsSelected: isSameAsSelected(r: r, c: c),
                            peer: isPeer(r: r, c: c),
                            mode: store.displayMode,
                            theme: store.theme,
                            size: cell
                        )
                        .overlay(boxBorders(r: r, c: c, cell: cell))
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(row: r, col: c) }
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(store.theme.boxBorder, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    private func isSameAsSelected(r: Int, c: Int) -> Bool {
        guard let sel = store.selected else { return false }
        let selValue = game.entries[sel.row][sel.col]
        return selValue != 0 && game.entries[r][c] == selValue && !(sel.row == r && sel.col == c)
    }

    /// Same row, column or box as the selected cell — the crosshair highlight.
    private func isPeer(r: Int, c: Int) -> Bool {
        guard let sel = store.selected else { return false }
        if sel.row == r && sel.col == c { return false }
        if sel.row == r || sel.col == c { return true }
        let br = game.puzzle.boxRows
        let bc = game.puzzle.boxCols
        return sel.row / br == r / br && sel.col / bc == c / bc
    }

    private func boxBorders(r: Int, c: Int, cell: CGFloat) -> some View {
        let br = game.puzzle.boxRows
        let bc = game.puzzle.boxCols
        return Path { path in
            if bc > 1 && c % bc == 0 {
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: cell))
            }
            if br > 1 && r % br == 0 {
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: cell, y: 0))
            }
        }
        .stroke(store.theme.boxBorder, lineWidth: 2)
        .allowsHitTesting(false)
    }
}

struct CellView: View {
    let value: Int
    let notes: [Int]
    let given: Bool
    let selected: Bool
    let conflict: Bool
    let sameAsSelected: Bool
    let peer: Bool
    let mode: DisplayMode
    let theme: AppTheme
    let size: CGFloat

    var body: some View {
        ZStack {
            background
            if value != 0 {
                if mode == .colors {
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(valueColors[value - 1])
                        .frame(width: size * 0.62, height: size * 0.62)
                        .overlay(
                            RoundedRectangle(cornerRadius: size * 0.18)
                                .stroke(conflict ? Color.red : .clear, lineWidth: 3)
                        )
                } else {
                    Text("\(value)")
                        .font(.system(size: size * 0.5,
                                      weight: given ? .bold : .medium,
                                      design: .rounded))
                        .foregroundColor(conflict ? .red : theme.text)
                }
            } else if !notes.isEmpty {
                notesGrid
            }
        }
        .frame(width: size, height: size)
        .border(theme.bg, width: 0.5)
    }

    /// Pencil marks: a mini 3-column grid inside the cell.
    private var notesGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(notes, id: \.self) { v in
                if mode == .colors {
                    Circle()
                        .fill(valueColors[v - 1])
                        .frame(width: size * 0.14, height: size * 0.14)
                } else {
                    Text("\(v)")
                        .font(.system(size: size * 0.2, weight: .medium, design: .rounded))
                        .foregroundColor(theme.text.opacity(0.6))
                }
            }
        }
        .padding(size * 0.06)
    }

    private var background: some View {
        let base: Color = given ? theme.cellGiven : theme.cell
        return Rectangle()
            .fill(sameAsSelected ? theme.same : base)
            // crosshair: tint the selected cell's row, column and box
            .overlay(peer ? theme.accent.opacity(0.14) : Color.clear)
            .overlay(
                Rectangle().stroke(selected ? theme.accent : .clear, lineWidth: 3)
            )
    }
}
