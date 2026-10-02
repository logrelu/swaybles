// Contact sheet for reviewing a pack against docs/ART.md.
//   node tools/contact-sheet.js cat-crew   → art/review/cat-crew.png
// Row 1: each charm at app size (170 px) on a dark wallpaper. Row 2: the same on a light wallpaper.
// Row 3: one charm from the reference pack (spooky-crew) for a style comparison.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const packId = process.argv[2];
const charms = JSON.parse(fs.readFileSync(path.join(root, 'src', 'charms.json'), 'utf8'));
const mine = charms.filter(c => c.pack === packId);
if (!mine.length) { console.error(`No imported charms for pack "${packId}". Run: npm run charms ${packId}`); process.exit(1); }
const ref = charms.find(c => c.pack === 'spooky-crew' && c.pack !== packId);

const H = 170, CELL = 200, PAD = 20;
const cols = Math.max(mine.length, 1);
const W = PAD + cols * (CELL + PAD), ROW = H + PAD * 2;
const rows = [['#1c2230', mine], ['#e9eef5', mine], ...(ref ? [['#1c2230', [ref]]] : [])];

(async () => {
  const layers = [];
  for (const [r, [bg, list]] of rows.entries()) {
    layers.push({ input: { create: { width: W, height: ROW, channels: 4, background: bg } }, left: 0, top: r * ROW });
    for (const [i, c] of list.entries()) {
      const buf = await sharp(path.join(root, 'src', c.file)).resize({ height: H, width: CELL, fit: 'inside' }).png().toBuffer();
      const meta = await sharp(buf).metadata();
      layers.push({ input: buf, left: PAD + i * (CELL + PAD) + Math.round((CELL - meta.width) / 2), top: r * ROW + PAD });
    }
  }
  const out = path.join(root, 'art', 'review', `${packId}.png`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  await sharp({ create: { width: W, height: ROW * rows.length, channels: 4, background: '#000' } }).composite(layers).png().toFile(out);
  console.log(`→ ${path.relative(root, out)}  (${mine.map(c => c.name).join(', ')})`);
})();
