import Foundation
import SwiftUI

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case digits, colors
    var id: String { rawValue }
}

struct GameState: Codable {
    var puzzle: Puzzle
    var entries: [[Int]]
    var startedAt: Date
    var finished: Bool
}

@MainActor
final class GameStore: ObservableObject {
    @Published var game: GameState?
    @Published var selected: (row: Int, col: Int)?
    @Published var loading = false

    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.digits.rawValue
    @AppStorage("gridSize") var gridSizeRaw: Int = GridSize.nine.rawValue
    @AppStorage("difficulty") var difficultyRaw: String = Difficulty.medium.rawValue
    @AppStorage("theme") var themeRaw: String = "midnight"

    private let gameKey = "sudoku.game.v1"
    private let api = APIClient()

    // @AppStorage persists to UserDefaults but does not reliably notify views
    // from inside an ObservableObject, so the setters publish explicitly.
    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .digits }
        set {
            objectWillChange.send()
            displayModeRaw = newValue.rawValue
        }
    }

    var gridSize: GridSize {
        get { GridSize(rawValue: gridSizeRaw) ?? .nine }
        set {
            objectWillChange.send()
            gridSizeRaw = newValue.rawValue
        }
    }

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .medium }
        set {
            objectWillChange.send()
            difficultyRaw = newValue.rawValue
        }
    }

    var theme: AppTheme {
        get { AppTheme.named(themeRaw) }
        set {
            objectWillChange.send()
            themeRaw = newValue.id
        }
    }

    init() {
        restore()
        if game == nil {
            newGame()
        }
    }

    func newGame() {
        let size = gridSize
        let difficulty = difficulty
        loading = true
        selected = nil
        Task {
            // Prefer the Rust backend; fall back to on-device generation.
            let puzzle: Puzzle
            if let remote = await api.fetchPuzzle(size: size.rawValue,
                                                  difficulty: difficulty.rawValue) {
                puzzle = remote
            } else {
                puzzle = SudokuGenerator.generate(size: size, difficulty: difficulty)
            }
            self.game = GameState(
                puzzle: puzzle,
                entries: puzzle.puzzle,
                startedAt: Date(),
                finished: false
            )
            self.loading = false
            self.persist(isNewGame: true)
        }
    }

    func select(row: Int, col: Int) {
        selected = (row, col)
    }

    func enter(_ value: Int) {
        guard var g = game, !g.finished, let sel = selected else { return }
        guard g.puzzle.puzzle[sel.row][sel.col] == 0 else { return }
        g.entries[sel.row][sel.col] = g.entries[sel.row][sel.col] == value ? 0 : value
        g.finished = g.entries == g.puzzle.solution
        game = g
        persist(isNewGame: false)
    }

    func erase() {
        guard var g = game, !g.finished, let sel = selected else { return }
        guard g.puzzle.puzzle[sel.row][sel.col] == 0 else { return }
        g.entries[sel.row][sel.col] = 0
        game = g
        persist(isNewGame: false)
    }

    func conflicts() -> [[Bool]] {
        guard let g = game else { return [] }
        let n = g.puzzle.size
        var bad = [[Bool]](repeating: [Bool](repeating: false, count: n), count: n)

        func mark(_ cellsInUnit: [(Int, Int)]) {
            var seen: [Int: [(Int, Int)]] = [:]
            for (r, c) in cellsInUnit {
                let v = g.entries[r][c]
                if v != 0 { seen[v, default: []].append((r, c)) }
            }
            for (_, list) in seen where list.count > 1 {
                for (r, c) in list { bad[r][c] = true }
            }
        }

        for r in 0..<n { mark((0..<n).map { (r, $0) }) }
        for c in 0..<n { mark((0..<n).map { ($0, c) }) }
        let (br, bc) = (g.puzzle.boxRows, g.puzzle.boxCols)
        for R in stride(from: 0, to: n, by: br) {
            for C in stride(from: 0, to: n, by: bc) {
                var cells: [(Int, Int)] = []
                for r in R..<(R + br) { for c in C..<(C + bc) { cells.append((r, c)) } }
                mark(cells)
            }
        }
        return bad
    }

    private func persist(isNewGame: Bool) {
        guard let g = game else { return }
        if let data = try? JSONEncoder().encode(g) {
            UserDefaults.standard.set(data, forKey: gameKey)
        }
        Task { await api.syncGame(g, isNewGame: isNewGame) }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: gameKey),
              let g = try? JSONDecoder().decode(GameState.self, from: data),
              [3, 6, 9].contains(g.puzzle.size) else { return }
        game = g
    }
}
