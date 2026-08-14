import type { Difficulty, Puzzle, Size } from './sudoku'
import type { Lang } from './i18n'

// Heroku dynos have an ephemeral filesystem, so the web app persists
// everything in localStorage — the server's SQLite is best-effort only.

export type DisplayMode = 'digits' | 'colors'

export interface Settings {
  lang: Lang | null
  displayMode: DisplayMode
  size: Size
  difficulty: Difficulty
  theme: string
}

export interface GameState {
  puzzle: Puzzle
  entries: number[][]
  /** Pencil marks: per cell, the list of noted candidate values. */
  notes: number[][][]
  hintsUsed: number
  startedAt: number
  elapsedSeconds: number
  finished: boolean
}

export interface SavedEntry {
  id: string
  game: GameState
  savedAt: number
}

export interface Stats {
  played: number
  won: number
  totalSeconds: number
  hints: number
  /** Best time in seconds, keyed by `${size}-${difficulty}`. */
  best: Record<string, number>
}

const SETTINGS_KEY = 'sudoku.settings.v1'
const GAME_KEY = 'sudoku.game.v1'
const DEVICE_KEY = 'sudoku.device.v1'
const SAVES_KEY = 'sudoku.saves.v1'
const STATS_KEY = 'sudoku.stats.v1'
const MAX_SAVES = 20

export function emptyNotes(size: number): number[][][] {
  return Array.from({ length: size }, () =>
    Array.from({ length: size }, () => [] as number[]),
  )
}

export function loadSettings(): Settings {
  const fallback: Settings = {
    lang: null,
    displayMode: 'digits',
    size: 9,
    difficulty: 'medium',
    theme: 'auto',
  }
  try {
    const raw = localStorage.getItem(SETTINGS_KEY)
    if (!raw) return fallback
    const s: Settings = { ...fallback, ...JSON.parse(raw) }
    // migration: only 4/9 are valid sizes (3×3 and 6×6 existed briefly)
    if (![4, 9].includes(s.size)) s.size = 9
    return s
  } catch {
    return fallback
  }
}

export function saveSettings(s: Settings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(s))
  } catch {
    // storage full or unavailable — ignore
  }
}

/** Backfill fields added after the first release so old saves keep working. */
function migrateGame(g: GameState): GameState | null {
  if (!g.puzzle || !g.entries) return null
  if (![4, 9].includes(g.puzzle.size)) return null
  if (!g.notes) g.notes = emptyNotes(g.puzzle.size)
  if (typeof g.hintsUsed !== 'number') g.hintsUsed = 0
  if (typeof g.elapsedSeconds !== 'number') g.elapsedSeconds = 0
  return g
}

export function loadGame(): GameState | null {
  try {
    const raw = localStorage.getItem(GAME_KEY)
    if (!raw) return null
    return migrateGame(JSON.parse(raw) as GameState)
  } catch {
    return null
  }
}

export function saveGame(g: GameState | null): void {
  try {
    if (g === null) localStorage.removeItem(GAME_KEY)
    else localStorage.setItem(GAME_KEY, JSON.stringify(g))
  } catch {
    // ignore
  }
}

// --- Multi-save list ("resume a game" screen) ---

export function loadSaves(): SavedEntry[] {
  try {
    const raw = localStorage.getItem(SAVES_KEY)
    if (!raw) return []
    const list = JSON.parse(raw) as SavedEntry[]
    return list
      .map((e) => ({ ...e, game: migrateGame(e.game)! }))
      .filter((e) => e.game !== null)
  } catch {
    return []
  }
}

function persistSaves(list: SavedEntry[]): SavedEntry[] {
  try {
    localStorage.setItem(SAVES_KEY, JSON.stringify(list))
  } catch {
    // ignore
  }
  return list
}

/** Archive a game at the top of the saves list (newest first, capped). */
export function archiveGame(game: GameState): SavedEntry[] {
  const entry: SavedEntry = {
    id: `${game.startedAt}-${Math.random().toString(36).slice(2, 8)}`,
    game,
    savedAt: Date.now(),
  }
  return persistSaves([entry, ...loadSaves()].slice(0, MAX_SAVES))
}

export function removeSave(id: string): SavedEntry[] {
  return persistSaves(loadSaves().filter((e) => e.id !== id))
}

/** Fraction of initially-empty cells that have been filled in. */
export function gameProgress(g: GameState): number {
  let empty = 0
  let filled = 0
  const n = g.puzzle.size
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (g.puzzle.puzzle[r][c] !== 0) continue
      empty++
      if (g.entries[r][c] !== 0) filled++
    }
  }
  return empty === 0 ? 1 : filled / empty
}

export function hasProgress(g: GameState): boolean {
  return gameProgress(g) > 0 || g.notes.some((row) => row.some((cell) => cell.length > 0))
}

// --- Statistics ---

export function loadStats(): Stats {
  const fallback: Stats = { played: 0, won: 0, totalSeconds: 0, hints: 0, best: {} }
  try {
    const raw = localStorage.getItem(STATS_KEY)
    if (!raw) return fallback
    return { ...fallback, ...JSON.parse(raw) }
  } catch {
    return fallback
  }
}

function persistStats(s: Stats): Stats {
  try {
    localStorage.setItem(STATS_KEY, JSON.stringify(s))
  } catch {
    // ignore
  }
  return s
}

export function recordGameStart(): Stats {
  const s = loadStats()
  return persistStats({ ...s, played: s.played + 1 })
}

export function recordWin(game: GameState): Stats {
  const s = loadStats()
  const key = `${game.puzzle.size}-${game.puzzle.difficulty}`
  const best = { ...s.best }
  if (best[key] === undefined || game.elapsedSeconds < best[key]) {
    best[key] = game.elapsedSeconds
  }
  return persistStats({
    ...s,
    won: s.won + 1,
    totalSeconds: s.totalSeconds + game.elapsedSeconds,
    hints: s.hints + game.hintsUsed,
    best,
  })
}

// --- Anonymous device id + best-effort server mirror ---

/** Stable anonymous id, used for optional server-side saves. */
export function deviceId(): string {
  try {
    let id = localStorage.getItem(DEVICE_KEY)
    if (!id) {
      id = crypto.randomUUID()
      localStorage.setItem(DEVICE_KEY, id)
    }
    return id
  } catch {
    return 'anonymous'
  }
}

const SERVER_ID_KEY = 'sudoku.serverGameId.v1'

/** Best-effort mirror of the current game into the backend's SQLite. */
export function syncToServer(g: GameState, isNewGame: boolean): void {
  try {
    const storedId = isNewGame ? null : localStorage.getItem(SERVER_ID_KEY)
    fetch('/api/games', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: storedId ? Number(storedId) : null,
        device_id: deviceId(),
        size: g.puzzle.size,
        difficulty: g.puzzle.difficulty,
        state: g,
      }),
    })
      .then((res) => {
        if (res.status === 404 && storedId) {
          // Dyno restarted and wiped SQLite: forget the stale id and re-create.
          localStorage.removeItem(SERVER_ID_KEY)
          syncToServer(g, true)
          return null
        }
        return res.ok ? res.json() : null
      })
      .then((data) => {
        if (data && typeof data.id === 'number') {
          localStorage.setItem(SERVER_ID_KEY, String(data.id))
        }
      })
      .catch(() => {})
  } catch {
    // offline — localStorage already has the state
  }
}
