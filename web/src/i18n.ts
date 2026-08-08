export type Lang = 'fr' | 'es' | 'en'

export const LANGS: Lang[] = ['fr', 'es', 'en']

type Dict = Record<string, string>

const fr: Dict = {
  title: 'Sudoku',
  newGame: 'Nouvelle partie',
  size: 'Taille',
  difficulty: 'Difficulté',
  easy: 'Facile',
  medium: 'Moyen',
  hard: 'Difficile',
  display: 'Affichage',
  digits: 'Chiffres',
  colors: 'Couleurs',
  erase: 'Effacer',
  language: 'Langue',
  win: 'Bravo, grille terminée ! 🎉',
  playAgain: 'Rejouer',
  loading: 'Génération…',
  conflicts: 'Conflits affichés en rouge',
  resume: 'Partie reprise automatiquement',
  background: 'Fond',
}

const es: Dict = {
  title: 'Sudoku',
  newGame: 'Nueva partida',
  size: 'Tamaño',
  difficulty: 'Dificultad',
  easy: 'Fácil',
  medium: 'Medio',
  hard: 'Difícil',
  display: 'Visualización',
  digits: 'Números',
  colors: 'Colores',
  erase: 'Borrar',
  language: 'Idioma',
  win: '¡Enhorabuena, sudoku completado! 🎉',
  playAgain: 'Jugar otra vez',
  loading: 'Generando…',
  conflicts: 'Conflictos en rojo',
  resume: 'Partida reanudada automáticamente',
  background: 'Fondo',
}

const en: Dict = {
  title: 'Sudoku',
  newGame: 'New game',
  size: 'Size',
  difficulty: 'Difficulty',
  easy: 'Easy',
  medium: 'Medium',
  hard: 'Hard',
  display: 'Display',
  digits: 'Digits',
  colors: 'Colors',
  erase: 'Erase',
  language: 'Language',
  win: 'Well done, puzzle solved! 🎉',
  playAgain: 'Play again',
  loading: 'Generating…',
  conflicts: 'Conflicts shown in red',
  resume: 'Game resumed automatically',
  background: 'Background',
}

const dicts: Record<Lang, Dict> = { fr, es, en }

export function detectLang(): Lang {
  const nav = (navigator.language || 'fr').slice(0, 2).toLowerCase()
  return (LANGS as string[]).includes(nav) ? (nav as Lang) : 'en'
}

export function t(lang: Lang, key: string): string {
  return dicts[lang][key] ?? dicts.en[key] ?? key
}
