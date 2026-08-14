// Background themes — applied via <html data-theme="…">, switchable anytime.
export interface Theme {
  id: string
  /** Swatch + PWA theme-color for the browser/OS chrome. */
  bg: string
}

export const THEMES: Theme[] = [
  { id: 'midnight', bg: '#1a1a2e' },
  { id: 'noir', bg: '#0e0e12' },
  { id: 'ocean', bg: '#04263b' },
  { id: 'forest', bg: '#0f2417' },
  { id: 'plum', bg: '#24122e' },
  { id: 'crimson', bg: '#2b0f14' },
  { id: 'slate', bg: '#1c2530' },
  { id: 'sunset', bg: '#2a1a0a' },
  { id: 'espresso', bg: '#211712' },
  { id: 'light', bg: '#f2f2f7' },
  { id: 'mint', bg: '#eaf6ef' },
  { id: 'rose', bg: '#fdf0f4' },
]

/** 'auto' follows the system color scheme (dark ↔ light). */
export const AUTO_THEME = 'auto'
export const DEFAULT_THEME = AUTO_THEME

const AUTO_DARK = 'midnight'
const AUTO_LIGHT = 'light'

/** Resolve the stored theme choice to a concrete theme id. */
export function resolveTheme(choice: string, prefersDark: boolean): string {
  if (choice === AUTO_THEME) return prefersDark ? AUTO_DARK : AUTO_LIGHT
  return THEMES.some((t) => t.id === choice) ? choice : AUTO_DARK
}

export function themeBg(id: string): string {
  return THEMES.find((t) => t.id === id)?.bg ?? THEMES[0].bg
}
