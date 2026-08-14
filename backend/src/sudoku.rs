use rand::seq::SliceRandom;
use rand::Rng;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Difficulty {
    Easy,
    Medium,
    Hard,
}

#[derive(Debug, Clone, Serialize)]
pub struct Puzzle {
    pub size: usize,
    pub box_rows: usize,
    pub box_cols: usize,
    pub difficulty: Difficulty,
    /// 0 = empty cell
    pub puzzle: Vec<Vec<u8>>,
    pub solution: Vec<Vec<u8>>,
}

/// Box dimensions (rows, cols) for a given grid size.
pub fn box_dims(size: usize) -> Option<(usize, usize)> {
    match size {
        4 => Some((2, 2)),
        6 => Some((2, 3)),
        9 => Some((3, 3)),
        _ => None,
    }
}

struct Grid {
    size: usize,
    box_rows: usize,
    box_cols: usize,
    cells: Vec<u8>,
}

impl Grid {
    fn new(size: usize, box_rows: usize, box_cols: usize) -> Self {
        Grid {
            size,
            box_rows,
            box_cols,
            cells: vec![0; size * size],
        }
    }

    fn get(&self, r: usize, c: usize) -> u8 {
        self.cells[r * self.size + c]
    }

    fn set(&mut self, r: usize, c: usize, v: u8) {
        self.cells[r * self.size + c] = v;
    }

    fn is_valid(&self, r: usize, c: usize, v: u8) -> bool {
        for i in 0..self.size {
            if self.get(r, i) == v || self.get(i, c) == v {
                return false;
            }
        }
        let br = (r / self.box_rows) * self.box_rows;
        let bc = (c / self.box_cols) * self.box_cols;
        for i in br..br + self.box_rows {
            for j in bc..bc + self.box_cols {
                if self.get(i, j) == v {
                    return false;
                }
            }
        }
        true
    }

    fn fill<R: Rng>(&mut self, rng: &mut R) -> bool {
        let mut idx = None;
        for i in 0..self.cells.len() {
            if self.cells[i] == 0 {
                idx = Some(i);
                break;
            }
        }
        let Some(i) = idx else { return true };
        let (r, c) = (i / self.size, i % self.size);
        let mut values: Vec<u8> = (1..=self.size as u8).collect();
        values.shuffle(rng);
        for v in values {
            if self.is_valid(r, c, v) {
                self.set(r, c, v);
                if self.fill(rng) {
                    return true;
                }
                self.set(r, c, 0);
            }
        }
        false
    }

    /// Count solutions, stopping early once `limit` is reached.
    fn count_solutions(&mut self, limit: usize) -> usize {
        let mut best: Option<(usize, Vec<u8>)> = None;
        for i in 0..self.cells.len() {
            if self.cells[i] != 0 {
                continue;
            }
            let (r, c) = (i / self.size, i % self.size);
            let cands: Vec<u8> = (1..=self.size as u8)
                .filter(|&v| self.is_valid(r, c, v))
                .collect();
            if cands.is_empty() {
                return 0;
            }
            if best.as_ref().is_none_or(|(_, b)| cands.len() < b.len()) {
                let single = cands.len() == 1;
                best = Some((i, cands));
                if single {
                    break;
                }
            }
        }
        let Some((i, cands)) = best else { return 1 };
        let mut count = 0;
        for v in cands {
            self.cells[i] = v;
            count += self.count_solutions(limit - count);
            self.cells[i] = 0;
            if count >= limit {
                break;
            }
        }
        count
    }
}

pub fn generate(size: usize, difficulty: Difficulty) -> Option<Puzzle> {
    let (box_rows, box_cols) = box_dims(size)?;
    let mut rng = rand::thread_rng();

    let mut grid = Grid::new(size, box_rows, box_cols);
    grid.fill(&mut rng);
    let solution = grid.cells.clone();

    let total = size * size;
    let keep_ratio = match difficulty {
        Difficulty::Easy => 0.55,
        Difficulty::Medium => 0.42,
        Difficulty::Hard => 0.30,
    };
    let min_clues = (total as f64 * keep_ratio).round() as usize;

    let mut order: Vec<usize> = (0..total).collect();
    order.shuffle(&mut rng);
    let mut clues = total;
    for i in order {
        if clues <= min_clues {
            break;
        }
        let saved = grid.cells[i];
        grid.cells[i] = 0;
        if grid.count_solutions(2) == 1 {
            clues -= 1;
        } else {
            grid.cells[i] = saved;
        }
    }

    let to_rows = |cells: &[u8]| -> Vec<Vec<u8>> {
        cells.chunks(size).map(|r| r.to_vec()).collect()
    };

    Some(Puzzle {
        size,
        box_rows,
        box_cols,
        difficulty,
        puzzle: to_rows(&grid.cells),
        solution: to_rows(&solution),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn check_solution(p: &Puzzle) {
        let n = p.size;
        for r in 0..n {
            for c in 0..n {
                let v = p.solution[r][c];
                assert!(v >= 1 && v as usize <= n);
                for i in 0..n {
                    if i != c {
                        assert_ne!(p.solution[r][i], v, "row conflict");
                    }
                    if i != r {
                        assert_ne!(p.solution[i][c], v, "col conflict");
                    }
                }
            }
        }
    }

    #[test]
    fn generates_all_sizes() {
        for &size in &[4usize, 6, 9] {
            for &d in &[Difficulty::Easy, Difficulty::Medium, Difficulty::Hard] {
                let p = generate(size, d).expect("puzzle");
                assert_eq!(p.puzzle.len(), size);
                check_solution(&p);
                // puzzle cells must match solution where given
                for r in 0..size {
                    for c in 0..size {
                        let v = p.puzzle[r][c];
                        assert!(v == 0 || v == p.solution[r][c]);
                    }
                }
                // unique solution
                let (br, bc) = box_dims(size).unwrap();
                let mut g = Grid::new(size, br, bc);
                g.cells = p.puzzle.iter().flatten().copied().collect();
                assert_eq!(g.count_solutions(2), 1, "size {size} not unique");
            }
        }
    }

    #[test]
    fn rejects_bad_size() {
        assert!(generate(3, Difficulty::Easy).is_none());
        assert!(generate(5, Difficulty::Easy).is_none());
    }
}
