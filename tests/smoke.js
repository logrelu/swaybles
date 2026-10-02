// App-launch smoke test: starts the real app, renders the overlay offscreen with a
// transparent background, and checks that every default charm actually drew on screen.
//   node tests/smoke.js            (Linux CI: xvfb-run node tests/smoke.js)
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const sharp = require('sharp');
const electron = require('electron'); // path to the Electron binary

(async () => {
  const root = path.join(__dirname, '..');
  const out = path.join(os.tmpdir(), `swaybles-smoke-${Date.now()}.png`);
  const userData = fs.mkdtempSync(path.join(os.tmpdir(), 'swaybles-ud-'));
  const r = spawnSync(electron, ['--no-sandbox', `--user-data-dir=${userData}`, root], {
    env: { ...process.env, SWAYBLES_SNAPSHOT: out, SWAYBLES_SNAP_BARE: '1', ELECTRON_ENABLE_LOGGING: '1' },
    timeout: 60000, encoding: 'utf8',
  });
  const fail = (msg) => { console.error('✗ smoke test failed:', msg); if (r.stderr) console.error(r.stderr.split('\n').filter(l => !/dbus|SharedImage|gpu/i.test(l)).slice(-15).join('\n')); process.exit(1); };
  if (r.error) fail(r.error.message);
  if (!fs.existsSync(out)) fail(`the app exited (code ${r.status}) without rendering`);

  const { data, info } = await sharp(out).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: W, height: H } = info;
  // Count solid pixels in each fifth of the screen width, in the top 60% (where charms hang).
  const cols = [0, 0, 0, 0, 0]; let solid = 0;
  for (let y = 0; y < H * 0.6; y++) for (let x = 0; x < W; x++) {
    if (data[(y * W + x) * 4 + 3] > 200) { solid++; cols[Math.min(4, Math.floor(x / W * 5))]++; }
  }
  const main = fs.readFileSync(path.join(root, 'src', 'main.js'), 'utf8');
  const nDefaults = [...main.slice(main.indexOf('const DEFAULTS'), main.indexOf('custom: []')).matchAll(/\bid: '/g)].length;
  console.log(`rendered ${W}x${H}, ${solid} solid pixels, per column: ${cols.join(' ')}, default charms: ${nDefaults}`);
  if (solid < 5000 * nDefaults * 0.6) fail(`too little drawn (${solid} solid pixels) — charms are missing`);
  const busy = cols.filter(c => c > 2000).length;
  if (busy < Math.min(3, nDefaults)) fail(`charms only drew in ${busy} parts of the screen`);
  fs.rmSync(out, { force: true }); fs.rmSync(userData, { recursive: true, force: true });
  console.log('✓ smoke test passed: the app launched and drew its charms');
})().catch((e) => { console.error('✗ smoke test failed:', e); process.exit(1); });
