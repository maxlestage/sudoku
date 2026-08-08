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
  startedAt: number
  elapsedSeconds: number
  finished: boolean
}

const SETTINGS_KEY = 'sudoku.settings.v1'
const GAME_KEY = 'sudoku.game.v1'
const DEVICE_KEY = 'sudoku.device.v1'

export function loadSettings(): Settings {
  const fallback: Settings = {
    lang: null,
    displayMode: 'digits',
    size: 9,
    difficulty: 'medium',
    theme: 'midnight',
  }
  try {
    const raw = localStorage.getItem(SETTINGS_KEY)
    if (!raw) return fallback
    return { ...fallback, ...JSON.parse(raw) }
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

export function loadGame(): GameState | null {
  try {
    const raw = localStorage.getItem(GAME_KEY)
    if (!raw) return null
    const g = JSON.parse(raw) as GameState
    if (!g.puzzle || !g.entries) return null
    return g
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
