// Palette for "colors" display mode — one color per value 1..9.
// Chosen to stay distinguishable on small screens.
export const VALUE_COLORS: string[] = [
  '#e63946', // 1 red
  '#f4a261', // 2 orange
  '#e9c46a', // 3 yellow
  '#2a9d8f', // 4 teal
  '#4895ef', // 5 blue
  '#7b2cbf', // 6 purple
  '#ff70a6', // 7 pink
  '#80b918', // 8 green
  '#8d6e63', // 9 brown
]

export function valueColor(v: number): string {
  return VALUE_COLORS[v - 1] ?? '#999'
}
