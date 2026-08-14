import Foundation
import SwiftUI

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case digits, colors
    var id: String { rawValue }
}

struct GameState: Codable {
    var puzzle: Puzzle
    var entries: [[Int]]
    /// Pencil marks: per cell, the list of noted candidate values.
    var notes: [[[Int]]]
    var hintsUsed: Int
    var startedAt: Date
    var elapsedSeconds: Int
    var finished: Bool

    init(puzzle: Puzzle, entries: [[Int]], notes: [[[Int]]], hintsUsed: Int,
         startedAt: Date, elapsedSeconds: Int, finished: Bool) {
        self.puzzle = puzzle
        self.entries = entries
        self.notes = notes
        self.hintsUsed = hintsUsed
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.finished = finished
    }

    // Backfill fields added after the first release so old saves keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try c.decode(Puzzle.self, forKey: .puzzle)
        entries = try c.decode([[Int]].self, forKey: .entries)
        let n = puzzle.size
        notes = try c.decodeIfPresent([[[Int]]].self, forKey: .notes)
            ?? Array(repeating: Array(repeating: [], count: n), count: n)
        hintsUsed = try c.decodeIfPresent(Int.self, forKey: .hintsUsed) ?? 0
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        elapsedSeconds = try c.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
    }

    /// Fraction of initially-empty cells that have been filled in.
    var progress: Double {
        var empty = 0
        var filled = 0
        let n = puzzle.size
        for r in 0..<n {
            for c in 0..<n where puzzle.puzzle[r][c] == 0 {
                empty += 1
                if entries[r][c] != 0 { filled += 1 }
            }
        }
        return empty == 0 ? 1 : Double(filled) / Double(empty)
    }

    var hasProgress: Bool {
        progress > 0 || notes.contains { row in row.contains { !$0.isEmpty } }
    }
}

struct SavedEntry: Codable, Identifiable {
    let id: String
    var game: GameState
    let savedAt: Date
}

struct GameStats: Codable {
    var played = 0
    var won = 0
    var totalSeconds = 0
    var hints = 0
    /// Best time in seconds, keyed by "size-difficulty".
    var best: [String: Int] = [:]
}

func formatTime(_ total: Int) -> String {
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%02d:%02d", m, s)
}

@MainActor
final class GameStore: ObservableObject {
    @Published var game: GameState?
    @Published var selected: (row: Int, col: Int)?
    @Published var loading = false
    @Published var notesMode = false
    @Published var stats = GameStats()
    @Published var saves: [SavedEntry] = []

    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.digits.rawValue
    @AppStorage("gridSize") var gridSizeRaw: Int = GridSize.nine.rawValue
    @AppStorage("difficulty") var difficultyRaw: String = Difficulty.medium.rawValue
    @AppStorage("theme") var themeRaw: String = "midnight"

    private let gameKey = "sudoku.game.v1"
    private let savesKey = "sudoku.saves.v1"
    private let statsKey = "sudoku.stats.v1"
    private let maxSaves = 20
    private let api = APIClient()
    private var ticker: Timer?
    private var lastSyncKey = ""

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
        stats = Self.load(GameStats.self, key: statsKey) ?? GameStats()
        saves = Self.load([SavedEntry].self, key: savesKey) ?? []
        if let g = Self.load(GameState.self, key: gameKey),
           [4, 9].contains(g.puzzle.size) {
            game = g
        }
        if game == nil {
            newGame()
        } else {
            startTicker()
        }
    }

    // MARK: - Game lifecycle

    func newGame() {
        archiveCurrentIfNeeded()
        let size = gridSize
        let difficulty = difficulty
        loading = true
        selected = nil
        notesMode = false
        stats.played += 1
        persistStats()
        Task {
            // Prefer the Rust backend; fall back to on-device generation.
            let puzzle: Puzzle
            if let remote = await api.fetchPuzzle(size: size.rawValue,
                                                  difficulty: difficulty.rawValue) {
                puzzle = remote
            } else {
                puzzle = SudokuGenerator.generate(size: size, difficulty: difficulty)
            }
            let n = puzzle.size
            self.game = GameState(
                puzzle: puzzle,
                entries: puzzle.puzzle,
                notes: Array(repeating: Array(repeating: [], count: n), count: n),
                hintsUsed: 0,
                startedAt: Date(),
                elapsedSeconds: 0,
                finished: false
            )
            self.loading = false
            self.persist(isNewGame: true)
            self.startTicker()
        }
    }

    func resume(_ entry: SavedEntry) {
        archiveCurrentIfNeeded()
        saves.removeAll { $0.id == entry.id }
        persistSaves()
        selected = nil
        notesMode = false
        game = entry.game
        persist(isNewGame: true)
        startTicker()
    }

    func deleteSave(_ entry: SavedEntry) {
        saves.removeAll { $0.id == entry.id }
        persistSaves()
    }

    private func archiveCurrentIfNeeded() {
        guard let g = game, !g.finished, g.hasProgress else { return }
        let entry = SavedEntry(
            id: "\(g.startedAt.timeIntervalSince1970)-\(UUID().uuidString.prefix(6))",
            game: g,
            savedAt: Date()
        )
        saves.insert(entry, at: 0)
        if saves.count > maxSaves { saves = Array(saves.prefix(maxSaves)) }
        persistSaves()
    }

    // MARK: - Moves

    func select(row: Int, col: Int) {
        selected = (row, col)
    }

    func enter(_ value: Int) {
        guard var g = game, !g.finished, let sel = selected else { return }
        guard g.puzzle.puzzle[sel.row][sel.col] == 0 else { return }
        if notesMode {
            guard g.entries[sel.row][sel.col] == 0 else { return }
            var cell = g.notes[sel.row][sel.col]
            if let i = cell.firstIndex(of: value) {
                cell.remove(at: i)
            } else {
                cell.append(value)
                cell.sort()
            }
            g.notes[sel.row][sel.col] = cell
            commit(g)
            return
        }
        let next = g.entries[sel.row][sel.col] == value ? 0 : value
        applyValue(&g, row: sel.row, col: sel.col, value: next)
        commit(g)
    }

    func erase() {
        guard var g = game, !g.finished, let sel = selected else { return }
        guard g.puzzle.puzzle[sel.row][sel.col] == 0 else { return }
        applyValue(&g, row: sel.row, col: sel.col, value: 0)
        commit(g)
    }

    func hint() {
        guard var g = game, !g.finished else { return }
        let n = g.puzzle.size
        var target: (Int, Int)? = nil
        if let sel = selected,
           g.puzzle.puzzle[sel.row][sel.col] == 0,
           g.entries[sel.row][sel.col] != g.puzzle.solution[sel.row][sel.col] {
            target = (sel.row, sel.col)
        }
        if target == nil {
            var candidates: [(Int, Int)] = []
            for r in 0..<n {
                for c in 0..<n
                where g.puzzle.puzzle[r][c] == 0 && g.entries[r][c] != g.puzzle.solution[r][c] {
                    candidates.append((r, c))
                }
            }
            target = candidates.randomElement()
        }
        guard let (r, c) = target else { return }
        selected = (r, c)
        applyValue(&g, row: r, col: c, value: g.puzzle.solution[r][c])
        g.hintsUsed += 1
        commit(g)
    }

    /// Sets a value, clears the cell's notes and removes the value from
    /// pencil marks in the same row, column and box.
    private func applyValue(_ g: inout GameState, row: Int, col: Int, value: Int) {
        g.entries[row][col] = value
        g.notes[row][col] = []
        if value != 0 {
            let n = g.puzzle.size
            let br = g.puzzle.boxRows
            let bc = g.puzzle.boxCols
            let R = (row / br) * br
            let C = (col / bc) * bc
            for i in 0..<n {
                g.notes[row][i].removeAll { $0 == value }
                g.notes[i][col].removeAll { $0 == value }
            }
            for i in R..<(R + br) {
                for j in C..<(C + bc) {
                    g.notes[i][j].removeAll { $0 == value }
                }
            }
        }
        g.finished = g.entries == g.puzzle.solution
    }

    /// Publishes the new state, records a win exactly once, persists.
    private func commit(_ g: GameState) {
        let wasFinished = game?.finished ?? false
        game = g
        if g.finished && !wasFinished {
            stats.won += 1
            stats.totalSeconds += g.elapsedSeconds
            stats.hints += g.hintsUsed
            let key = "\(g.puzzle.size)-\(g.puzzle.difficulty.rawValue)"
            if let best = stats.best[key] {
                stats.best[key] = min(best, g.elapsedSeconds)
            } else {
                stats.best[key] = g.elapsedSeconds
            }
            persistStats()
            ticker?.invalidate()
        }
        persist(isNewGame: false)
    }

    // MARK: - Conflicts

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

    // MARK: - Timer

    private func startTicker() {
        ticker?.invalidate()
        guard let g = game, !g.finished else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard var g = game, !g.finished else {
            ticker?.invalidate()
            return
        }
        g.elapsedSeconds += 1
        game = g
        persistLocal()
    }

    // MARK: - Persistence

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func store<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persistLocal() {
        guard let g = game else { return }
        Self.store(g, key: gameKey)
    }

    private func persistSaves() {
        Self.store(saves, key: savesKey)
    }

    private func persistStats() {
        Self.store(stats, key: statsKey)
    }

    /// Local persist always; server sync only when played content changed
    /// (not on every timer tick).
    private func persist(isNewGame: Bool) {
        guard let g = game else { return }
        Self.store(g, key: gameKey)
        let key = "\(g.entries)|\(g.notes)|\(g.finished)|\(g.puzzle.puzzle)"
        if isNewGame || key != lastSyncKey {
            lastSyncKey = key
            Task { await api.syncGame(g, isNewGame: isNewGame) }
        }
    }
}
