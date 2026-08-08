import { useCallback, useEffect, useRef, useState } from 'react'
import { detectLang, t, LANGS, type Lang } from './i18n'
import { generatePuzzle, SIZES, type Difficulty, type Size } from './sudoku'
import {
  loadGame,
  loadSettings,
  saveGame,
  saveSettings,
  syncToServer,
  type DisplayMode,
  type GameState,
  type Settings,
} from './storage'
import { valueColor } from './colors'

const DIFFICULTIES: Difficulty[] = ['easy', 'medium', 'hard']

export default function App() {
  const [settings, setSettings] = useState<Settings>(() => loadSettings())
  const [game, setGame] = useState<GameState | null>(() => loadGame())
  const [selected, setSelected] = useState<[number, number] | null>(null)
  const [loading, setLoading] = useState(false)
  const newGameRef = useRef(false)

  const lang: Lang = settings.lang ?? detectLang()
  const tr = useCallback((key: string) => t(lang, key), [lang])

  useEffect(() => saveSettings(settings), [settings])

  useEffect(() => {
    saveGame(game)
    if (game) {
      syncToServer(game, newGameRef.current)
      newGameRef.current = false
    }
  }, [game])

  const startGame = useCallback(
    async (size: Size, difficulty: Difficulty) => {
      setLoading(true)
      setSelected(null)
      try {
        const puzzle = await generatePuzzle(size, difficulty)
        newGameRef.current = true
        setGame({
          puzzle,
          entries: puzzle.puzzle.map((row) => [...row]),
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
      void startGame(settings.size, settings.difficulty)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const setCell = useCallback(
    (value: number) => {
      if (!game || game.finished || !selected) return
      const [r, c] = selected
      if (game.puzzle.puzzle[r][c] !== 0) return // given cell
      const entries = game.entries.map((row) => [...row])
      entries[r][c] = entries[r][c] === value ? 0 : value
      const finished = entries.every((row, ri) =>
        row.every((v, ci) => v === game.puzzle.solution[ri][ci]),
      )
      setGame({ ...game, entries, finished })
    },
    [game, selected],
  )

  const eraseCell = useCallback(() => {
    if (!game || game.finished || !selected) return
    const [r, c] = selected
    if (game.puzzle.puzzle[r][c] !== 0) return
    const entries = game.entries.map((row) => [...row])
    entries[r][c] = 0
    setGame({ ...game, entries })
  }, [game, selected])

  // Keyboard support (desktop)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!game) return
      const n = Number(e.key)
      if (n >= 1 && n <= game.puzzle.size) setCell(n)
      if (e.key === 'Backspace' || e.key === 'Delete' || e.key === '0') eraseCell()
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
                  void startGame(s, settings.difficulty)
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
                  void startGame(settings.size, d)
                }}
              >
                {tr(d)}
              </button>
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
          <Board
            game={game}
            mode={settings.displayMode}
            selected={selected}
            conflicts={conflicts}
            onSelect={(r, c) => setSelected([r, c])}
          />
          {game.finished ? (
            <div className="win">
              <p>{tr('win')}</p>
              <button
                className="primary"
                onClick={() => void startGame(settings.size, settings.difficulty)}
              >
                {tr('playAgain')}
              </button>
            </div>
          ) : (
            <Keypad
              size={game.puzzle.size}
              mode={settings.displayMode}
              onValue={setCell}
              onErase={eraseCell}
              eraseLabel={tr('erase')}
            />
          )}
          <button
            className="secondary new-game"
            onClick={() => void startGame(settings.size, settings.difficulty)}
          >
            {tr('newGame')}
          </button>
        </>
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
      className={`board size-${n}`}
      style={{ gridTemplateColumns: `repeat(${n}, 1fr)` }}
      role="grid"
    >
      {game.entries.map((row, r) =>
        row.map((v, c) => {
          const given = game.puzzle.puzzle[r][c] !== 0
          const isSel = selected?.[0] === r && selected?.[1] === c
          const sameValue = v !== 0 && v === selValue && !isSel
          const classes = [
            'cell',
            given ? 'given' : '',
            isSel ? 'selected' : '',
            sameValue ? 'same' : '',
            conflicts[r]?.[c] ? 'conflict' : '',
            c % bc === 0 ? 'box-left' : '',
            r % br === 0 ? 'box-top' : '',
            c === n - 1 ? 'box-right' : '',
            r === n - 1 ? 'box-bottom' : '',
          ]
            .filter(Boolean)
            .join(' ')
          return (
            <button
              key={`${r}-${c}`}
              className={classes}
              onClick={() => onSelect(r, c)}
              role="gridcell"
              aria-label={`${r + 1},${c + 1}`}
            >
              {v !== 0 &&
                (mode === 'colors' ? (
                  <span className="color-dot" style={{ background: valueColor(v) }} />
                ) : (
                  v
                ))}
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
  onErase: () => void
  eraseLabel: string
}

function Keypad({ size, mode, onValue, onErase, eraseLabel }: KeypadProps) {
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
      <button className="key erase" onClick={onErase}>
        {eraseLabel}
      </button>
    </div>
  )
}
