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
  { id: 'light', bg: '#f2f2f7' },
]

export const DEFAULT_THEME = 'midnight'

export function themeBg(id: string): string {
  return THEMES.find((t) => t.id === id)?.bg ?? THEMES[0].bg
}
