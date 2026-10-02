// Post-build check: run after electron-builder. Verifies the installers exist and that the
// packaged app contains the right code and charms.
//   node tests/build-check.js mac|win
const fs = require('fs');
const path = require('path');
const asar = require('@electron/asar');

const platform = process.argv[2] || (process.platform === 'darwin' ? 'mac' : 'win');
const dist = path.join(__dirname, '..', 'dist');
const pkg = require('../package.json');
const errors = [];
const check = (ok, msg) => { console.log(`${ok ? '✓' : '✗'} ${msg}`); if (!ok) errors.push(msg); };
const walk = (d) => fs.existsSync(d) ? fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? (e.name.endsWith('.app') && e.name !== 'Swaybles.app' ? [] : walk(path.join(d, e.name))) : [path.join(d, e.name)]) : [];

const files = walk(dist);
const MB = (f) => fs.statSync(f).size / 1048576;

// 1. Installers
const installers = platform === 'mac' ? files.filter(f => /\.dmg$/.test(f)) : files.filter(f => /Setup.*\.exe$/.test(f));
check(installers.length > 0, `${platform === 'mac' ? '.dmg' : '.exe'} installer was produced`);
for (const f of installers) check(MB(f) > 50 && MB(f) < 400, `${path.basename(f)} has a sensible size (${MB(f).toFixed(0)} MB)`);
for (const f of installers) check(path.basename(f).includes(pkg.version), `${path.basename(f)} carries version ${pkg.version}`);

// 2. Packaged app contents
const archives = files.filter(f => f.endsWith(path.join('resources', 'app.asar')));
check(archives.length > 0, 'packaged app (app.asar) found');
for (const a of archives) {
  const where = path.relative(dist, a).split(path.sep)[0];
  const list = asar.listPackage(a).map(p => p.replace(/\\/g, '/'));
  for (const f of ['/src/main.js', '/src/overlay.js', '/src/physics.js', '/src/preload.js', '/src/charms.json', '/package.json'])
    check(list.includes(f), `[${where}] contains ${f}`);
  const manifest = JSON.parse(asar.extractFile(a, 'src/charms.json').toString());
  const pngs = list.filter(p => /^\/src\/charms\/.+\.png$/.test(p));
  check(pngs.length === manifest.length && manifest.every(c => list.includes('/src/' + c.file)), `[${where}] has all ${manifest.length} charms in the manifest (found ${pngs.length})`);
  check(!list.some(p => p.endsWith('.svg')), `[${where}] has no SVG charms`);
  check(!list.some(p => /^\/(tests|art|marketing|store)\//.test(p)), `[${where}] doesn't ship tests, raw art or marketing files`);
  check(!list.some(p => /license|config\.json/.test(p)), `[${where}] ships no license machinery — Swaybles is free`);
  const appPkg = JSON.parse(asar.extractFile(a, 'package.json').toString());
  check(appPkg.version === pkg.version, `[${where}] app version is ${pkg.version}`);
}

if (errors.length) { console.error(`\n✗ build check failed (${errors.length} problem${errors.length > 1 ? 's' : ''})`); process.exit(1); }
console.log('\n✓ build check passed');
