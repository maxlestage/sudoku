import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }

    var keepRatio: Double {
        switch self {
        case .easy: return 0.55
        case .medium: return 0.42
        case .hard: return 0.30
        }
    }
}

enum GridSize: Int, Codable, CaseIterable, Identifiable {
    case four = 4, nine = 9
    var id: Int { rawValue }

    /// Box dimensions (rows, cols).
    var boxDims: (rows: Int, cols: Int) {
        switch self {
        case .four: return (2, 2)
        case .nine: return (3, 3)
        }
    }
}

struct Puzzle: Codable, Equatable {
    let size: Int
    let boxRows: Int
    let boxCols: Int
    let difficulty: Difficulty
    /// 0 = empty cell
    let puzzle: [[Int]]
    let solution: [[Int]]

    enum CodingKeys: String, CodingKey {
        case size
        case boxRows = "box_rows"
        case boxCols = "box_cols"
        case difficulty, puzzle, solution
    }
}

/// Same algorithm as the Rust backend: randomized backtracking fill,
/// then clue removal while the solution stays unique.
enum SudokuGenerator {
    static func generate(size: GridSize, difficulty: Difficulty) -> Puzzle {
        let n = size.rawValue
        let (boxRows, boxCols) = size.boxDims
        var cells = [Int](repeating: 0, count: n * n)

        _ = fill(&cells, n: n, boxRows: boxRows, boxCols: boxCols)
        let solution = cells

        let total = n * n
        let minClues = Int((Double(total) * difficulty.keepRatio).rounded())
        var clues = total
        for i in (0..<total).shuffled() {
            if clues <= minClues { break }
            let saved = cells[i]
            cells[i] = 0
            if countSolutions(&cells, n: n, boxRows: boxRows, boxCols: boxCols, limit: 2) == 1 {
                clues -= 1
            } else {
                cells[i] = saved
            }
        }

        func toRows(_ flat: [Int]) -> [[Int]] {
            stride(from: 0, to: flat.count, by: n).map { Array(flat[$0..<$0 + n]) }
        }

        return Puzzle(
            size: n,
            boxRows: boxRows,
            boxCols: boxCols,
            difficulty: difficulty,
            puzzle: toRows(cells),
            solution: toRows(solution)
        )
    }

    private static func isValid(_ cells: [Int], n: Int, boxRows: Int, boxCols: Int,
                                r: Int, c: Int, v: Int) -> Bool {
        for i in 0..<n {
            if cells[r * n + i] == v || cells[i * n + c] == v { return false }
        }
        let br = (r / boxRows) * boxRows
        let bc = (c / boxCols) * boxCols
        for i in br..<(br + boxRows) {
            for j in bc..<(bc + boxCols) {
                if cells[i * n + j] == v { return false }
            }
        }
        return true
    }

    private static func fill(_ cells: inout [Int], n: Int, boxRows: Int, boxCols: Int) -> Bool {
        guard let i = cells.firstIndex(of: 0) else { return true }
        let r = i / n
        let c = i % n
        for v in (1...n).shuffled() {
            if isValid(cells, n: n, boxRows: boxRows, boxCols: boxCols, r: r, c: c, v: v) {
                cells[i] = v
                if fill(&cells, n: n, boxRows: boxRows, boxCols: boxCols) { return true }
                cells[i] = 0
            }
        }
        return false
    }

    private static func countSolutions(_ cells: inout [Int], n: Int, boxRows: Int,
                                       boxCols: Int, limit: Int) -> Int {
        var bestIdx = -1
        var bestCands: [Int]? = nil
        for i in 0..<cells.count where cells[i] == 0 {
            let r = i / n
            let c = i % n
            let cands = (1...n).filter {
                isValid(cells, n: n, boxRows: boxRows, boxCols: boxCols, r: r, c: c, v: $0)
            }
            if cands.isEmpty { return 0 }
            if bestCands == nil || cands.count < bestCands!.count {
                bestIdx = i
                bestCands = cands
                if cands.count == 1 { break }
            }
        }
        guard let cands = bestCands else { return 1 }
        var count = 0
        for v in cands {
            cells[bestIdx] = v
            count += countSolutions(&cells, n: n, boxRows: boxRows, boxCols: boxCols,
                                    limit: limit - count)
            cells[bestIdx] = 0
            if count >= limit { break }
        }
        return count
    }
}
