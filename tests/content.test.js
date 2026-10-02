// Checks the charms, config and pages the app ships with.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..', 'src');
const charms = JSON.parse(fs.readFileSync(path.join(SRC, 'charms.json'), 'utf8'));
const packs = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'tools', 'packs.json'), 'utf8'));
const pngSize = (f) => { const b = fs.readFileSync(f); assert.equal(b.toString('ascii', 1, 4), 'PNG', `${f} is a PNG`); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20), colorType: b[25] }; };

for (const pack of packs) {
  // A pack with no raw art and no imported charms is still in planning — nothing to check yet.
  const raw = path.join(__dirname, '..', 'art', 'raw', pack.id);
  if (!fs.existsSync(raw) && !charms.some(c => c.pack === pack.id)) continue;
  test(`pack "${pack.name}" is fully imported`, () => {
    const got = charms.filter(c => c.pack === pack.id).map(c => c.id).sort();
    assert.deepEqual(got, pack.charms.map(c => c.id).sort(), 'every charm in tools/packs.json is in src/charms.json (run npm run charms)');
    for (const c of charms.filter(c => c.pack === pack.id)) assert.equal(c.theme, pack.name);
  });
}

test('charm ids are unique across all packs', () => {
  assert.equal(new Set(charms.map(c => c.id)).size, charms.length);
});

test('Spooky Crew is still there', () => {
  assert.deepEqual(charms.filter(c => c.pack === 'spooky-crew').map(c => c.id).sort(), ['cauldron', 'flower-skull', 'rip-mondays', 'skeleton', 'zombie-hand']);
});

for (const c of charms) {
  test(`charm "${c.name}" image is valid and matches the manifest`, () => {
    const f = path.join(SRC, c.file);
    assert.ok(fs.existsSync(f), `${c.file} exists`);
    const s = pngSize(f);
    assert.equal(s.w, c.w); assert.equal(s.h, c.h);
    assert.equal(s.colorType, 6, 'has a transparency channel (RGBA)');
    assert.ok(c.ax > 0.3 && c.ax < 0.7, 'rope attaches near the middle');
    assert.ok(c.ay >= 0 && c.ay < 0.1, 'rope attaches at the top');
    assert.ok(c.name.length > 2);
  });
}

test('charm folders hold only PNGs listed in the manifest (no strays, no SVG)', () => {
  const files = fs.readdirSync(path.join(SRC, 'charms'), { recursive: true }).filter(f => fs.statSync(path.join(SRC, 'charms', f)).isFile()).map(f => 'charms/' + f.split(path.sep).join('/'));
  assert.deepEqual(files.sort(), charms.map(c => c.file).sort());
});

test('nothing licensey or networky ships with the app', () => {
  for (const f of fs.readdirSync(SRC)) {
    assert.ok(!/license|config\.json/.test(f), `${f} should not exist — Swaybles is free, no keys`);
  }
  const main = fs.readFileSync(path.join(SRC, 'main.js'), 'utf8');
  assert.ok(!/gumroad/i.test(main), 'main.js mentions Gumroad');
});

test('default charms in main.js all exist', () => {
  const main = fs.readFileSync(path.join(SRC, 'main.js'), 'utf8');
  const defaults = main.slice(main.indexOf('const DEFAULTS'), main.indexOf('custom: []'));
  const ids = [...defaults.matchAll(/id: '([a-z-]+)'/g)].map(m => m[1]);
  assert.ok(ids.length >= 1);
  for (const id of ids) assert.ok(charms.some(c => c.id === id), `default charm ${id}`);
});

test('every page only loads files that exist', () => {
  for (const page of ['overlay.html', 'studio.html']) {
    const html = fs.readFileSync(path.join(SRC, page), 'utf8');
    for (const [, ref] of html.matchAll(/(?:src|href)="([^":#]+)"/g)) assert.ok(fs.existsSync(path.join(SRC, ref)), `${page} → ${ref}`);
  }
});

test('overlay loads physics before the code that uses it', () => {
  const html = fs.readFileSync(path.join(SRC, 'overlay.html'), 'utf8');
  assert.ok(html.indexOf('physics.js') < html.indexOf('overlay.js'));
});

test('package.json builds the right app', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
  assert.equal(pkg.main, 'src/main.js');
  assert.equal(pkg.build.appId, 'com.swaybles.app');
  assert.ok(pkg.build.mac && pkg.build.win);
});
