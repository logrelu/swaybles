// Imports Imagine Art charm PNGs into the app, pack by pack.
//   node tools/import-art.js            (all packs in tools/packs.json)
//   node tools/import-art.js cat-crew   (just one pack)
// Reads art/raw/<pack>/<id>.png, drops the faint glow, trims, scales to ≤600 px, finds the gold ring
// (the rope attaches there) and writes src/charms/<pack>/<id>.png + src/charms.json,
// then mirrors both into mac/Resources/Charms for the native app.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const PACKS = JSON.parse(fs.readFileSync(path.join(__dirname, 'packs.json'), 'utf8'));
const only = process.argv[2];

async function importCharm(pack, c) {
  const RAW = path.join(root, 'art', 'raw', pack.id);
  const src = ['png', 'webp', 'jpg', 'jpeg'].map(e => path.join(RAW, `${c.id}.${e}`)).find(fs.existsSync);
  if (!src) throw new Error(`missing art/raw/${pack.id}/${c.id}.png`);
  const rawIn = await sharp(src).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const px = rawIn.data;
  for (let i = 3; i < px.length; i += 4) px[i] = px[i] < 70 ? 0 : Math.min(255, Math.round((px[i] - 70) * 255 / 185));
  const cleaned = await sharp(px, { raw: rawIn.info }).png().toBuffer();
  const trimmed = await sharp(cleaned).trim({ threshold: 1 }).png().toBuffer();
  const img = sharp(trimmed).resize({ height: 600, width: 600, fit: 'inside', withoutEnlargement: true });
  const { data, info } = await img.clone().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h, channels } = info;
  const alpha = (x, y) => data[(y * w + x) * channels + 3];
  const opaqueCorners = [alpha(0, 0), alpha(w - 1, 0), alpha(0, h - 1), alpha(w - 1, h - 1)].filter(a => a > 20).length;
  let ay = 0, ax = w / 2;
  for (let y = 0; y < h; y++) {
    const xs = [];
    for (let x = Math.floor(w * 0.2); x < Math.ceil(w * 0.8); x++) if (alpha(x, y) > 160) xs.push(x);
    if (xs.length) { ay = y; ax = (xs[0] + xs[xs.length - 1]) / 2; break; }
  }
  const outDir = path.join(root, 'src', 'charms', pack.id);
  fs.mkdirSync(outDir, { recursive: true });
  await img.png({ compressionLevel: 9 }).toFile(path.join(outDir, `${c.id}.png`));
  const entry = { id: c.id, name: c.name, pack: pack.id, theme: pack.name, file: `charms/${pack.id}/${c.id}.png`, w, h, ax: +(ax / w).toFixed(4), ay: +(ay / h).toFixed(4) };
  if (c.role) entry.role = c.role;     // timer | quote | banner | task | break (Focus Crew)
  if (c.label) entry.label = c.label;  // blank surface the app writes on, fractions of the image
  const warn = [];
  if (opaqueCorners) warn.push('background not transparent');
  if (entry.ax < 0.35 || entry.ax > 0.65) warn.push(`ring off-centre (x ${Math.round(entry.ax * 100)}%)`);
  if (entry.ay > 0.1) warn.push('ring not at the top');
  console.log(`${pack.id}/${c.id}: ${w}x${h}, rope at (${Math.round(entry.ax * 100)}%, ${(entry.ay * 100).toFixed(1)}%)${warn.length ? '  ⚠ ' + warn.join('; ') : '  ✓'}`);
  if (warn.length) process.exitCode = 1;
  return entry;
}

(async () => {
  const manifestFile = path.join(root, 'src', 'charms.json');
  const existing = fs.existsSync(manifestFile) ? JSON.parse(fs.readFileSync(manifestFile, 'utf8')) : [];
  const out = [];
  for (const pack of PACKS) {
    if (only && pack.id !== only) { out.push(...existing.filter(e => e.pack === pack.id)); continue; }
    const dir = path.join(root, 'src', 'charms', pack.id);
    fs.rmSync(dir, { recursive: true, force: true });
    for (const c of pack.charms) out.push(await importCharm(pack, c));
  }
  fs.writeFileSync(manifestFile, JSON.stringify(out, null, 2) + '\n');
  // Mirror into the native app's resources (mac/Resources/Charms).
  const macDir = path.join(root, 'mac', 'Resources', 'Charms');
  fs.rmSync(macDir, { recursive: true, force: true });
  fs.cpSync(path.join(root, 'src', 'charms'), macDir, { recursive: true });
  fs.copyFileSync(manifestFile, path.join(macDir, 'charms.json'));
  console.log(`\n${out.length} charms in ${new Set(out.map(e => e.pack)).size} pack(s) → src/charms.json`);
})().catch(e => { console.error('✗', e.message); process.exit(1); });
