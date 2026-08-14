export type Difficulty = 'easy' | 'medium' | 'hard'
export type Size = 4 | 6 | 9

export interface Puzzle {
  size: Size
  box_rows: number
  box_cols: number
  difficulty: Difficulty
  puzzle: number[][]
  solution: number[][]
}

export const SIZES: Size[] = [4, 6, 9]

export function boxDims(size: Size): [number, number] {
  switch (size) {
    case 4:
      return [2, 2]
    case 6:
      return [2, 3]
    case 9:
      return [3, 3]
  }
}

function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

class Grid {
  cells: number[]
  constructor(
    readonly size: number,
    readonly boxRows: number,
    readonly boxCols: number,
    cells?: number[],
  ) {
    this.cells = cells ?? new Array(size * size).fill(0)
  }

  isValid(r: number, c: number, v: number): boolean {
    const n = this.size
    for (let i = 0; i < n; i++) {
      if (this.cells[r * n + i] === v || this.cells[i * n + c] === v) return false
    }
    const br = Math.floor(r / this.boxRows) * this.boxRows
    const bc = Math.floor(c / this.boxCols) * this.boxCols
    for (let i = br; i < br + this.boxRows; i++) {
      for (let j = bc; j < bc + this.boxCols; j++) {
        if (this.cells[i * n + j] === v) return false
      }
    }
    return true
  }

  fill(): boolean {
    const n = this.size
    const i = this.cells.indexOf(0)
    if (i === -1) return true
    const r = Math.floor(i / n)
    const c = i % n
    const values = shuffle(Array.from({ length: n }, (_, k) => k + 1))
    for (const v of values) {
      if (this.isValid(r, c, v)) {
        this.cells[i] = v
        if (this.fill()) return true
        this.cells[i] = 0
      }
    }
    return false
  }

  countSolutions(limit: number): number {
    const n = this.size
    let bestIdx = -1
    let bestCands: number[] | null = null
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] !== 0) continue
      const r = Math.floor(i / n)
      const c = i % n
      const cands: number[] = []
      for (let v = 1; v <= n; v++) {
        if (this.isValid(r, c, v)) cands.push(v)
      }
      if (cands.length === 0) return 0
      if (bestCands === null || cands.length < bestCands.length) {
        bestIdx = i
        bestCands = cands
        if (cands.length === 1) break
      }
    }
    if (bestCands === null) return 1
    let count = 0
    for (const v of bestCands) {
      this.cells[bestIdx] = v
      count += this.countSolutions(limit - count)
      this.cells[bestIdx] = 0
      if (count >= limit) break
    }
    return count
  }
}

const KEEP_RATIO: Record<Difficulty, number> = {
  easy: 0.55,
  medium: 0.42,
  hard: 0.3,
}

/** Local generator, used as offline fallback when the API is unreachable. */
export function generateLocal(size: Size, difficulty: Difficulty): Puzzle {
  const [boxRows, boxCols] = boxDims(size)
  const grid = new Grid(size, boxRows, boxCols)
  grid.fill()
  const solution = [...grid.cells]

  const total = size * size
  const minClues = Math.round(total * KEEP_RATIO[difficulty])
  const order = shuffle(Array.from({ length: total }, (_, i) => i))
  let clues = total
  for (const i of order) {
    if (clues <= minClues) break
    const saved = grid.cells[i]
    grid.cells[i] = 0
    if (grid.countSolutions(2) === 1) {
      clues--
    } else {
      grid.cells[i] = saved
    }
  }

  const toRows = (cells: number[]) => {
    const rows: number[][] = []
    for (let r = 0; r < size; r++) rows.push(cells.slice(r * size, (r + 1) * size))
    return rows
  }

  return {
    size,
    box_rows: boxRows,
    box_cols: boxCols,
    difficulty,
    puzzle: toRows(grid.cells),
    solution: toRows(solution),
  }
}

/** Fetch a puzzle from the Rust backend, falling back to local generation. */
export async function generatePuzzle(size: Size, difficulty: Difficulty): Promise<Puzzle> {
  try {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), 4000)
    const res = await fetch(`/api/puzzle?size=${size}&difficulty=${difficulty}`, {
      signal: ctrl.signal,
    })
    clearTimeout(timer)
    if (!res.ok) throw new Error(`http ${res.status}`)
    return (await res.json()) as Puzzle
  } catch {
    return generateLocal(size, difficulty)
  }
}
