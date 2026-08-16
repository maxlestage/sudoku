// Generates the App Store icon (1024x1024, RGB without alpha as Apple
// requires) into the AppIcon asset catalog. Same design as the web icons.
// Run once: node ios/scripts/gen-appicon.mjs
import { deflateSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUT = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'Sudoku',
  'Assets.xcassets',
  'AppIcon.appiconset',
)
mkdirSync(OUT, { recursive: true })

const BG = [0x1a, 0x1a, 0x2e]
const PALETTE = [
  '#e63946', '#f4a261', '#e9c46a',
  '#2a9d8f', '#4895ef', '#7b2cbf',
  '#ff70a6', '#80b918', '#8d6e63',
].map((hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)))

function crc32(buf) {
  let c
  const table = []
  for (let n = 0; n < 256; n++) {
    c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    table[n] = c >>> 0
  }
  let crc = 0xffffffff
  for (const b of buf) crc = table[(crc ^ b) & 0xff] ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([len, body, crc])
}

function png(size, pixels) {
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8 // bit depth
  ihdr[9] = 2 // color type RGB — no alpha channel (App Store requirement)
  const raw = Buffer.alloc(size * (size * 3 + 1))
  for (let y = 0; y < size; y++) {
    raw[y * (size * 3 + 1)] = 0 // filter none
    pixels.copy(raw, y * (size * 3 + 1) + 1, y * size * 3, (y + 1) * size * 3)
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

function drawIcon(size) {
  const px = Buffer.alloc(size * size * 3)
  for (let i = 0; i < size * size; i++) {
    px[i * 3] = BG[0]
    px[i * 3 + 1] = BG[1]
    px[i * 3 + 2] = BG[2]
  }
  const pad = Math.round(size * 0.12)
  const grid = size - pad * 2
  const gap = Math.max(2, Math.round(grid * 0.045))
  const tile = Math.floor((grid - gap * 2) / 3)
  const radius = Math.round(tile * 0.22)
  for (let ty = 0; ty < 3; ty++) {
    for (let tx = 0; tx < 3; tx++) {
      const [r, g, b] = PALETTE[ty * 3 + tx]
      const x0 = pad + tx * (tile + gap)
      const y0 = pad + ty * (tile + gap)
      for (let y = 0; y < tile; y++) {
        for (let x = 0; x < tile; x++) {
          const dx = Math.max(radius - x, x - (tile - 1 - radius), 0)
          const dy = Math.max(radius - y, y - (tile - 1 - radius), 0)
          if (dx * dx + dy * dy > radius * radius) continue
          const i = ((y0 + y) * size + x0 + x) * 3
          px[i] = r
          px[i + 1] = g
          px[i + 2] = b
        }
      }
    }
  }
  return png(size, px)
}

writeFileSync(join(OUT, 'AppIcon-1024.png'), drawIcon(1024))
console.log('wrote AppIcon-1024.png')
