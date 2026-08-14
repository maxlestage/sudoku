import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { detectLang, t, LANGS, type Lang } from './i18n'
import { generatePuzzle, SIZES, type Difficulty, type Size } from './sudoku'
import {
  archiveGame,
  emptyNotes,
  gameProgress,
  hasProgress,
  loadGame,
  loadSaves,
  loadSettings,
  loadStats,
  recordGameStart,
  recordWin,
  removeSave,
  saveGame,
  saveSettings,
  syncToServer,
  type DisplayMode,
  type GameState,
  type SavedEntry,
  type Settings,
  type Stats,
} from './storage'
import { valueColor, VALUE_COLORS } from './colors'
import { THEMES, themeBg } from './themes'

const DIFFICULTIES: Difficulty[] = ['easy', 'medium', 'hard']

function formatTime(total: number): string {
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const mm = String(m).padStart(2, '0')
  const ss = String(s).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
}

export default function App() {
  const [settings, setSettings] = useState<Settings>(() => loadSettings())
  const [game, setGame] = useState<GameState | null>(() => loadGame())
  const [saves, setSaves] = useState<SavedEntry[]>(() => loadSaves())
  const [stats, setStats] = useState<Stats>(() => loadStats())
  const [selected, setSelected] = useState<[number, number] | null>(null)
  const [notesMode, setNotesMode] = useState(false)
  const [showStats, setShowStats] = useState(false)
  const [showSaves, setShowSaves] = useState(false)
  const [loading, setLoading] = useState(false)
  const newGameRef = useRef(false)
  const syncKeyRef = useRef('')
  const prevFinishedRef = useRef<boolean | null>(null)

  const lang: Lang = settings.lang ?? detectLang()
  const tr = useCallback((key: string) => t(lang, key), [lang])

  useEffect(() => saveSettings(settings), [settings])

  useEffect(() => {
    document.documentElement.lang = lang
  }, [lang])

  useEffect(() => {
    document.documentElement.dataset.theme = settings.theme
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', themeBg(settings.theme))
  }, [settings.theme])

  // Persist every change locally; mirror to the server only when the
  // played content changes (not every timer tick).
  useEffect(() => {
    saveGame(game)
    if (game) {
      const key = JSON.stringify([game.puzzle.puzzle, game.entries, game.notes, game.finished])
      if (key !== syncKeyRef.current) {
        syncKeyRef.current = key
        syncToServer(game, newGameRef.current)
        newGameRef.current = false
      }
    }
  }, [game])

  // Record win statistics exactly once per game.
  useEffect(() => {
    const finished = game?.finished ?? false
    if (prevFinishedRef.current === null) {
      prevFinishedRef.current = finished
      return
    }
    if (finished && !prevFinishedRef.current && game) {
      setStats(recordWin(game))
    }
    prevFinishedRef.current = finished
  }, [game])

  // Timer: tick while a game is running and the tab is visible.
  const running = game !== null && !game.finished
  useEffect(() => {
    if (!running) return
    const id = setInterval(() => {
      if (document.visibilityState !== 'visible') return
      setGame((g) => (g && !g.finished ? { ...g, elapsedSeconds: g.elapsedSeconds + 1 } : g))
    }, 1000)
    return () => clearInterval(id)
  }, [running])

  const startGame = useCallback(
    async (size: Size, difficulty: Difficulty, current: GameState | null) => {
      setLoading(true)
      setSelected(null)
      setNotesMode(false)
      try {
        if (current && !current.finished && hasProgress(current)) {
          setSaves(archiveGame(current))
        }
        const puzzle = await generatePuzzle(size, difficulty)
        newGameRef.current = true
        setStats(recordGameStart())
        setGame({
          puzzle,
          entries: puzzle.puzzle.map((row) => [...row]),
          notes: emptyNotes(puzzle.size),
          hintsUsed: 0,
          startedAt: Date.now(),
          elapsedSeconds: 0,
          finished: false,
        })
      } finally {
        setLoading(false)
      }
    },
    [],
  )

  useEffect(() => {
    if (!game && !loading) {
      void startGame(settings.size, settings.difficulty, null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const applyValue = useCallback(
    (g: GameState, r: number, c: number, value: number): GameState => {
      const entries = g.entries.map((row) => [...row])
      const notes = g.notes.map((row) => row.map((cell) => [...cell]))
      entries[r][c] = value
      notes[r][c] = []
      if (value !== 0) {
        // clear the value from pencil marks in the same row, column and box
        const n = g.puzzle.size
        const { box_rows: br, box_cols: bc } = g.puzzle
        const R = Math.floor(r / br) * br
        const C = Math.floor(c / bc) * bc
        for (let i = 0; i < n; i++) {
          notes[r][i] = notes[r][i].filter((v) => v !== value)
          notes[i][c] = notes[i][c].filter((v) => v !== value)
        }
        for (let i = R; i < R + br; i++) {
          for (let j = C; j < C + bc; j++) {
            notes[i][j] = notes[i][j].filter((v) => v !== value)
          }
        }
      }
      const finished = entries.every((row, ri) =>
        row.every((v, ci) => v === g.puzzle.solution[ri][ci]),
      )
      return { ...g, entries, notes, finished }
    },
    [],
  )

  const setCell = useCallback(
    (value: number) => {
      if (!game || game.finished || !selected) return
      const [r, c] = selected
      if (game.puzzle.puzzle[r][c] !== 0) return // given cell
      if (notesMode) {
        if (game.entries[r][c] !== 0) return
        const notes = game.notes.map((row) => row.map((cell) => [...cell]))
        notes[r][c] = notes[r][c].includes(value)
          ? notes[r][c].filter((v) => v !== value)
          : [...notes[r][c], value].sort((a, b) => a - b)
        setGame({ ...game, notes })
        return
      }
      const next = game.entries[r][c] === value ? 0 : value
      setGame(applyValue(game, r, c, next))
    },
    [game, selected, notesMode, applyValue],
  )

  const eraseCell = useCallback(() => {
    if (!game || game.finished || !selected) return
    const [r, c] = selected
    if (game.puzzle.puzzle[r][c] !== 0) return
    setGame(applyValue(game, r, c, 0))
  }, [game, selected, applyValue])

  const giveHint = useCallback(() => {
    if (!game || game.finished) return
    const n = game.puzzle.size
    let target: [number, number] | null = null
    if (selected) {
      const [r, c] = selected
      if (game.puzzle.puzzle[r][c] === 0 && game.entries[r][c] !== game.puzzle.solution[r][c]) {
        target = [r, c]
      }
    }
    if (!target) {
      const candidates: [number, number][] = []
      for (let r = 0; r < n; r++) {
        for (let c = 0; c < n; c++) {
          if (game.puzzle.puzzle[r][c] === 0 && game.entries[r][c] !== game.puzzle.solution[r][c]) {
            candidates.push([r, c])
          }
        }
      }
      if (candidates.length === 0) return
      target = candidates[Math.floor(Math.random() * candidates.length)]
    }
    const [r, c] = target
    setSelected(target)
    const next = applyValue(game, r, c, game.puzzle.solution[r][c])
    setGame({ ...next, hintsUsed: next.hintsUsed + 1 })
  }, [game, selected, applyValue])

  const resumeSave = useCallback(
    (entry: SavedEntry) => {
      if (game && !game.finished && hasProgress(game)) {
        setSaves(archiveGame(game))
      }
      setSaves(removeSave(entry.id))
      newGameRef.current = true
      setGame(entry.game)
      setSelected(null)
      setNotesMode(false)
      setShowSaves(false)
    },
    [game],
  )

  // Keyboard support (desktop)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!game) return
      const n = Number(e.key)
      if (n >= 1 && n <= game.puzzle.size) setCell(n)
      if (e.key === 'Backspace' || e.key === 'Delete' || e.key === '0') eraseCell()
      if (e.key === 'n' || e.key === 'N') setNotesMode((m) => !m)
      if (selected) {
        const [r, c] = selected
        const max = game.puzzle.size - 1
        if (e.key === 'ArrowUp' && r > 0) setSelected([r - 1, c])
        if (e.key === 'ArrowDown' && r < max) setSelected([r + 1, c])
        if (e.key === 'ArrowLeft' && c > 0) setSelected([r, c - 1])
        if (e.key === 'ArrowRight' && c < max) setSelected([r, c + 1])
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [game, selected, setCell, eraseCell])

  const conflicts = getConflicts(game)

  return (
    <div className="app">
      <header className="topbar">
        <h1>{tr('title')}</h1>
        <div className="top-actions">
          <button className="icon-btn" aria-label={tr('stats')} onClick={() => setShowStats(true)}>
            📊
          </button>
          <button
            className="icon-btn saves-btn"
            aria-label={tr('saves')}
            onClick={() => setShowSaves(true)}
          >
            📂
            {saves.length > 0 && <span className="badge">{saves.length}</span>}
          </button>
          <div className="lang-switch" role="group" aria-label={tr('language')}>
            {LANGS.map((l) => (
              <button
                key={l}
                className={l === lang ? 'chip active' : 'chip'}
                onClick={() => setSettings({ ...settings, lang: l })}
              >
                {l.toUpperCase()}
              </button>
            ))}
          </div>
        </div>
      </header>

      <section className="controls">
        <div className="control-row">
          <span className="label">{tr('size')}</span>
          <div role="group">
            {SIZES.map((s) => (
              <button
                key={s}
                className={s === settings.size ? 'chip active' : 'chip'}
                onClick={() => {
                  setSettings({ ...settings, size: s })
                  void startGame(s, settings.difficulty, game)
                }}
              >
                {s}×{s}
              </button>
            ))}
          </div>
        </div>
        <div className="control-row">
          <span className="label">{tr('difficulty')}</span>
          <div role="group">
            {DIFFICULTIES.map((d) => (
              <button
                key={d}
                className={d === settings.difficulty ? 'chip active' : 'chip'}
                onClick={() => {
                  setSettings({ ...settings, difficulty: d })
                  void startGame(settings.size, d, game)
                }}
              >
                {tr(d)}
              </button>
            ))}
          </div>
        </div>
        <div className="control-row">
          <span className="label">{tr('background')}</span>
          <div role="group" className="theme-row">
            {THEMES.map((th) => (
              <button
                key={th.id}
                className={th.id === settings.theme ? 'swatch active' : 'swatch'}
                style={{ background: th.bg }}
                aria-label={th.id}
                onClick={() => setSettings({ ...settings, theme: th.id })}
              />
            ))}
          </div>
        </div>
        <div className="control-row">
          <span className="label">{tr('display')}</span>
          <div role="group">
            {(['digits', 'colors'] as DisplayMode[]).map((m) => (
              <button
                key={m}
                className={m === settings.displayMode ? 'chip active' : 'chip'}
                onClick={() => setSettings({ ...settings, displayMode: m })}
              >
                {tr(m)}
              </button>
            ))}
          </div>
        </div>
      </section>

      {loading || !game ? (
        <p className="status">{tr('loading')}</p>
      ) : (
        <>
          <div className="game-bar">
            <span className="timer" aria-label={tr('time')}>
              ⏱ {formatTime(game.elapsedSeconds)}
            </span>
            {game.hintsUsed > 0 && <span className="hints-count">💡 {game.hintsUsed}</span>}
          </div>
          <Board
            game={game}
            mode={settings.displayMode}
            selected={selected}
            conflicts={conflicts}
            onSelect={(r, c) => setSelected([r, c])}
          />
          {game.finished ? (
            <>
              <Confetti />
              <div className="win">
                <p className="win-title">{tr('win')}</p>
                <p className="win-detail">
                  ⏱ {formatTime(game.elapsedSeconds)}
                  {game.hintsUsed > 0 ? ` · 💡 ${game.hintsUsed}` : ''}
                </p>
                <button
                  className="primary"
                  onClick={() => void startGame(settings.size, settings.difficulty, game)}
                >
                  {tr('playAgain')}
                </button>
              </div>
            </>
          ) : (
            <>
              <Keypad size={game.puzzle.size} mode={settings.displayMode} onValue={setCell} />
              <div className="actions">
                <button
                  className={notesMode ? 'action active' : 'action'}
                  aria-pressed={notesMode}
                  onClick={() => setNotesMode((m) => !m)}
                >
                  ✏️ {tr('notes')}
                </button>
                <button className="action" onClick={giveHint}>
                  💡 {tr('hint')}
                </button>
                <button className="action" onClick={eraseCell}>
                  ⌫ {tr('erase')}
                </button>
              </div>
            </>
          )}
          <button
            className="secondary new-game"
            onClick={() => void startGame(settings.size, settings.difficulty, game)}
          >
            {tr('newGame')}
          </button>
        </>
      )}

      {showStats && <StatsModal stats={stats} tr={tr} onClose={() => setShowStats(false)} />}
      {showSaves && (
        <SavesModal
          saves={saves}
          tr={tr}
          onResume={resumeSave}
          onDelete={(id) => setSaves(removeSave(id))}
          onClose={() => setShowSaves(false)}
        />
      )}
    </div>
  )
}

function getConflicts(game: GameState | null): boolean[][] {
  if (!game) return []
  const n = game.puzzle.size
  const { box_rows: br, box_cols: bc } = game.puzzle
  const e = game.entries
  const bad = Array.from({ length: n }, () => new Array<boolean>(n).fill(false))
  const mark = (cells: [number, number][]) => {
    const seen = new Map<number, [number, number][]>()
    for (const [r, c] of cells) {
      const v = e[r][c]
      if (v === 0) continue
      if (!seen.has(v)) seen.set(v, [])
      seen.get(v)!.push([r, c])
    }
    for (const list of seen.values()) {
      if (list.length > 1) for (const [r, c] of list) bad[r][c] = true
    }
  }
  for (let r = 0; r < n; r++) mark(Array.from({ length: n }, (_, c) => [r, c]))
  for (let c = 0; c < n; c++) mark(Array.from({ length: n }, (_, r) => [r, c]))
  for (let R = 0; R < n; R += br) {
    for (let C = 0; C < n; C += bc) {
      const cells: [number, number][] = []
      for (let r = R; r < R + br; r++) for (let c = C; c < C + bc; c++) cells.push([r, c])
      mark(cells)
    }
  }
  return bad
}

interface BoardProps {
  game: GameState
  mode: DisplayMode
  selected: [number, number] | null
  conflicts: boolean[][]
  onSelect: (r: number, c: number) => void
}

function Board({ game, mode, selected, conflicts, onSelect }: BoardProps) {
  const n = game.puzzle.size
  const { box_rows: br, box_cols: bc } = game.puzzle
  const selValue = selected ? game.entries[selected[0]][selected[1]] : 0

  return (
    <div
      className={`board size-${n}${game.finished ? ' won' : ''}`}
      style={{ gridTemplateColumns: `repeat(${n}, 1fr)` }}
      role="grid"
    >
      {game.entries.map((row, r) =>
        row.map((v, c) => {
          const given = game.puzzle.puzzle[r][c] !== 0
          const isSel = selected?.[0] === r && selected?.[1] === c
          const sameValue = v !== 0 && v === selValue && !isSel
          const cellNotes = game.notes[r][c]
          const classes = [
            'cell',
            given ? 'given' : '',
            isSel ? 'selected' : '',
            sameValue ? 'same' : '',
            conflicts[r]?.[c] ? 'conflict' : '',
            bc > 1 && c % bc === 0 ? 'box-left' : '',
            br > 1 && r % br === 0 ? 'box-top' : '',
            c === n - 1 ? 'box-right' : '',
            r === n - 1 ? 'box-bottom' : '',
          ]
            .filter(Boolean)
            .join(' ')
          return (
            <button
              key={`${r}-${c}`}
              className={classes}
              style={{ ['--i' as string]: r * n + c }}
              onClick={() => onSelect(r, c)}
              role="gridcell"
              aria-label={`${r + 1},${c + 1}`}
            >
              {v !== 0 ? (
                mode === 'colors' ? (
                  <span className="color-dot" style={{ background: valueColor(v) }} />
                ) : (
                  v
                )
              ) : cellNotes.length > 0 ? (
                <span className="notes-grid">
                  {Array.from({ length: n }, (_, k) => k + 1).map((k) =>
                    cellNotes.includes(k) ? (
                      mode === 'colors' ? (
                        <span
                          key={k}
                          className="note-dot"
                          style={{ background: valueColor(k) }}
                        />
                      ) : (
                        <span key={k} className="note-num">
                          {k}
                        </span>
                      )
                    ) : (
                      <span key={k} />
                    ),
                  )}
                </span>
              ) : null}
            </button>
          )
        }),
      )}
    </div>
  )
}

interface KeypadProps {
  size: number
  mode: DisplayMode
  onValue: (v: number) => void
}

function Keypad({ size, mode, onValue }: KeypadProps) {
  return (
    <div className="keypad">
      {Array.from({ length: size }, (_, i) => i + 1).map((v) => (
        <button key={v} className="key" onClick={() => onValue(v)} aria-label={`${v}`}>
          {mode === 'colors' ? (
            <span className="color-dot" style={{ background: valueColor(v) }} />
          ) : (
            v
          )}
        </button>
      ))}
    </div>
  )
}

function Confetti() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 90 }, (_, i) => ({
        left: Math.random() * 100,
        delay: Math.random() * 1.2,
        duration: 2.2 + Math.random() * 2,
        color: VALUE_COLORS[i % VALUE_COLORS.length],
        size: 6 + Math.random() * 7,
        spin: Math.random() < 0.5 ? 1 : -1,
      })),
    [],
  )
  return (
    <div className="confetti" aria-hidden="true">
      {pieces.map((p, i) => (
        <span
          key={i}
          style={{
            left: `${p.left}%`,
            animationDelay: `${p.delay}s`,
            animationDuration: `${p.duration}s`,
            background: p.color,
            width: p.size,
            height: p.size * 0.5,
            ['--spin' as string]: p.spin,
          }}
        />
      ))}
    </div>
  )
}

interface StatsModalProps {
  stats: Stats
  tr: (k: string) => string
  onClose: () => void
}

function StatsModal({ stats, tr, onClose }: StatsModalProps) {
  const bestEntries = Object.entries(stats.best).sort(([a], [b]) => a.localeCompare(b))
  const rate = stats.played > 0 ? Math.round((stats.won / stats.played) * 100) : 0
  return (
    <Modal title={`📊 ${tr('stats')}`} tr={tr} onClose={onClose}>
      <div className="stats-grid">
        <div className="stat">
          <span className="stat-value">{stats.played}</span>
          <span className="stat-label">{tr('played')}</span>
        </div>
        <div className="stat">
          <span className="stat-value">{stats.won}</span>
          <span className="stat-label">{tr('won')}</span>
        </div>
        <div className="stat">
          <span className="stat-value">{rate}%</span>
          <span className="stat-label">{tr('winRate')}</span>
        </div>
        <div className="stat">
          <span className="stat-value">{formatTime(stats.totalSeconds)}</span>
          <span className="stat-label">{tr('totalTime')}</span>
        </div>
        <div className="stat">
          <span className="stat-value">{stats.hints}</span>
          <span className="stat-label">{tr('hintsUsed')}</span>
        </div>
      </div>
      {bestEntries.length > 0 && (
        <>
          <h3 className="modal-subtitle">{tr('best')}</h3>
          <ul className="best-list">
            {bestEntries.map(([key, secs]) => {
              const [size, diff] = key.split('-')
              return (
                <li key={key}>
                  <span>
                    {size}×{size} · {tr(diff)}
                  </span>
                  <strong>{formatTime(secs)}</strong>
                </li>
              )
            })}
          </ul>
        </>
      )}
    </Modal>
  )
}

interface SavesModalProps {
  saves: SavedEntry[]
  tr: (k: string) => string
  onResume: (entry: SavedEntry) => void
  onDelete: (id: string) => void
  onClose: () => void
}

function SavesModal({ saves, tr, onResume, onDelete, onClose }: SavesModalProps) {
  return (
    <Modal title={`📂 ${tr('saves')}`} tr={tr} onClose={onClose}>
      {saves.length === 0 ? (
        <p className="modal-empty">{tr('noSaves')}</p>
      ) : (
        <>
          <p className="modal-note">{tr('savedAuto')}</p>
          <ul className="saves-list">
            {saves.map((entry) => {
              const g = entry.game
              const pct = Math.round(gameProgress(g) * 100)
              return (
                <li key={entry.id} className="save-row">
                  <div className="save-info">
                    <strong>
                      {g.puzzle.size}×{g.puzzle.size} · {tr(g.puzzle.difficulty)}
                    </strong>
                    <span className="save-meta">
                      ⏱ {formatTime(g.elapsedSeconds)} · {tr('progress')} {pct}%
                    </span>
                  </div>
                  <div className="save-actions">
                    <button className="primary small" onClick={() => onResume(entry)}>
                      {tr('resumeGame')}
                    </button>
                    <button
                      className="secondary small"
                      aria-label={tr('delete')}
                      onClick={() => onDelete(entry.id)}
                    >
                      🗑
                    </button>
                  </div>
                </li>
              )
            })}
          </ul>
        </>
      )}
    </Modal>
  )
}

interface ModalProps {
  title: string
  tr: (k: string) => string
  onClose: () => void
  children: React.ReactNode
}

function Modal({ title, tr, onClose, children }: ModalProps) {
  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal" role="dialog" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h2>{title}</h2>
          <button className="icon-btn" aria-label={tr('close')} onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  )
}
