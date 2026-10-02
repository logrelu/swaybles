// Promo video recorder (optional). Needs ffmpeg and: npm i -D @fontsource/bricolage-grotesque @fontsource/dm-sans
// Run: npx electron tools/promo/record-reel.js marketing/swaybles-reel.mp4
//
// Promo video recorder: runs the real Swaybles overlay offscreen at 720x1280,
// drives a scripted cursor, and pipes frames into ffmpeg (upscaled to 1080x1920).
//   electron --no-sandbox reel.js <out.mp4>
const { app, BrowserWindow, ipcMain } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const OUT = process.argv[process.argv.length - 1];
const SRC = path.join(__dirname, '..', '..', 'src');
const W = 720, H = 1280, FPS = 30; let DURATION = 60;
const FONTS = path.join(__dirname, '..', '..', 'node_modules', '@fontsource');

const settings = {
  charms: [
    { uid: 'a2', id: 'flower-skull', x: 0.15, len: 330 },
    { uid: 'a1', id: 'skeleton', x: 0.37, len: 540 },
    { uid: 'a3', id: 'cauldron', x: 0.58, len: 380 },
    { uid: 'a4', id: 'zombie-hand', x: 0.76, len: 600 },
    { uid: 'a5', id: 'rip-mondays', x: 0.86, len: 280 },
  ],
  custom: [], rope: 'gold-thread', size: 1.3, reduceMotion: false, breeze: false, sound: false, paused: false,
};
const charms = JSON.parse(fs.readFileSync(path.join(SRC, 'charms.json'), 'utf8'));

ipcMain.handle('get-state', () => ({ settings, charms, displays: [], platform: 'darwin', version: '1.0.0', license: { licensed: true }, buyUrl: '' }));
ipcMain.handle('update-settings', (_e, p) => Object.assign(settings, p));
ipcMain.on('set-ignore', () => {});

app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const win = new BrowserWindow({
    width: W, height: H, show: false, useContentSize: true,
    webPreferences: { offscreen: true, preload: path.join(SRC, 'preload.js'), backgroundThrottling: false },
  });
  win.webContents.setFrameRate(FPS);
  await win.loadFile(path.join(SRC, 'overlay.html'));
  const woff = (f, file) => `@font-face{font-family:'${f}';src:url('file://${FONTS}/${file}') format('woff2');font-weight:${file.match(/-(\d{3})-/)[1]};}`;
  await win.webContents.insertCSS(`
    ${woff('Bricolage', 'bricolage-grotesque/files/bricolage-grotesque-latin-800-normal.woff2')}
    ${woff('Bricolage', 'bricolage-grotesque/files/bricolage-grotesque-latin-700-normal.woff2')}
    ${woff('DM', 'dm-sans/files/dm-sans-latin-500-normal.woff2')}
    ${woff('DM', 'dm-sans/files/dm-sans-latin-700-normal.woff2')}
    body { background: radial-gradient(ellipse at 50% 108%, #ff8a2a55 0, transparent 45%), radial-gradient(circle at 22% 62%, #fff3d8 0 30px, #ffe7b422 31px, transparent 120px), linear-gradient(180deg, #120a24 0%, #2a1352 55%, #4a1f5e 100%) !important; }
    canvas { z-index: 2; }
    #mb { position: fixed; left: 0; right: 0; top: 0; height: 30px; background: #0b0614cc; z-index: 1; font: 500 14px 'DM', sans-serif; color: #f1e8ff; display: flex; align-items: center; gap: 18px; padding: 0 16px; }
    #mb b { font-weight: 700; } #mb .r { margin-left: auto; opacity: .9; }
    .stars i { position: fixed; width: 2px; height: 2px; border-radius: 50%; background: #fff; z-index: 0; }
    #cap { position: fixed; left: 40px; right: 40px; bottom: 150px; z-index: 3; text-align: center; font: 800 58px/1.02 'Bricolage', sans-serif; color: #fff8ee; letter-spacing: -.02em; text-shadow: 0 4px 24px #0009; transition: opacity .35s, transform .35s; }
    #cap small { display: block; font: 700 26px 'DM', sans-serif; color: #ffb35c; letter-spacing: .02em; margin-top: 14px; }
    #cap.hide { opacity: 0; transform: translateY(14px); }
    #end { position: fixed; left: 36px; right: 36px; bottom: 90px; z-index: 3; padding: 34px 28px 30px; border-radius: 30px; background: #0f0820e6; border: 1px solid #ffffff1f; text-align: center; color: #fff8ee; opacity: 0; transform: translateY(30px); transition: opacity .5s, transform .5s; }
    #end.show { opacity: 1; transform: none; }
    #end h1 { font: 800 60px/1 'Bricolage', sans-serif; margin: 0 0 10px; letter-spacing: -.02em; }
    #end p { font: 500 26px/1.35 'DM', sans-serif; margin: 0 0 22px; color: #eadcff; }
    #end .price { display: inline-block; font: 700 28px 'DM', sans-serif; background: #ff8a2a; color: #1a0f2e; padding: 12px 26px; border-radius: 99px; }
    #cur { position: fixed; z-index: 4; width: 34px; height: 34px; left: -60px; top: -60px; pointer-events: none; filter: drop-shadow(0 2px 3px #0008); transition: transform .12s; transform-origin: 4px 2px; }
    #cur.down { transform: scale(.88); }
  `);
  await win.webContents.executeJavaScript(`
    document.body.insertAdjacentHTML('beforeend', \`
      <div id="mb"><b>Finder</b><span>File</span><span>Edit</span><span>View</span><span class="r">Fri 31 Oct 9:41 PM</span></div>
      <div class="stars">\${Array.from({length: 70}, (_, i) => '<i style="left:' + ((i * 137) % 720) + 'px;top:' + (40 + (i * 89) % 1150) + 'px;opacity:' + (0.15 + (i % 6) / 10) + '"></i>').join('')}</div>
      <div id="cap" class="hide"></div>
      <div id="end"><h1>Spooky Crew</h1><p>5 Halloween charms that swing<br>on your Mac</p><span class="price">$2.99 · link in bio</span></div>
      <svg id="cur" viewBox="0 0 24 24"><path d="M3 2 L3 19 L7.5 14.8 L10.6 21.6 L13.6 20.3 L10.6 13.6 L16.8 13.6 Z" fill="#fff" stroke="#000" stroke-width="1.4" stroke-linejoin="round"/></svg>\`);
    window.__cap = (html) => { const c = document.getElementById('cap'); if (!html) { c.classList.add('hide'); return; } c.classList.add('hide'); setTimeout(() => { c.innerHTML = html; c.classList.remove('hide'); }, 180); };
    window.__cur = (x, y, down) => { const c = document.getElementById('cur'); c.style.left = x - 4 + 'px'; c.style.top = y - 2 + 'px'; c.classList.toggle('down', !!down); };
    window.__end = () => document.getElementById('end').classList.add('show');
    true;
  `);

  // ── frame pipe ──
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgra', '-s', `${W}x${H}`, '-r', String(FPS), '-i', '-',
    '-vf', 'scale=1080:1920:flags=lanczos', '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', OUT]);
  let last = null, frames = 0;
  win.webContents.on('paint', (_e, _d, img) => { const s = img.getSize(); if (s.width === W && s.height === H) last = img.getBitmap(); });
  win.webContents.startPainting();

  const js = (code) => win.webContents.executeJavaScript(code);
  const pos = () => js('window.__swayblesPositions()');
  const mouse = (type, x, y) => { win.webContents.sendInputEvent({ type, x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 }); };
  let cx = 760, cy = 900;
  const move = async (x, y, down) => { cx = x; cy = y; mouse('mouseMove', x, y); await js(`__cur(${x},${y},${!!down})`); };
  const glide = async (tx, ty, ms, down) => { const sx = cx, sy = cy, n = Math.max(1, Math.round(ms / 45)); for (let i = 1; i <= n; i++) { const t = i / n, e = t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; await move(sx + (tx - sx) * e, sy + (ty - sy) * e, down); } };
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));

  const start = Date.now();
  const timer = setInterval(() => {
    const want = Math.floor((Date.now() - start) / (1000 / FPS));
    while (frames < want && frames < DURATION * FPS) { if (last) ff.stdin.write(last); frames++; }
    if (frames >= DURATION * FPS) { clearInterval(timer); ff.stdin.end(); }
  }, 10);
  ff.on('close', (code) => { console.log('ffmpeg exit', code, 'frames', frames); app.exit(0); });

  // ── script ──
  await sleep(500);
  await js(`__cap('POV: your Mac<br>got haunted')`);
  await move(700, 760);
  await sleep(900);
  // flick across the whole crew, right to left through each charm
  const p1 = await pos();
  for (const c of [...p1].reverse()) await glide(c.x, c.y, 150);
  await glide(-20, 700, 150);
  await sleep(1100);
  await js(`__cap('Grab one and<br>let it swing')`);
  // grab the skeleton
  await glide(360, 820, 350);
  const sk = (await pos()).find(c => c.id === 'skeleton');
  await glide(sk.x, sk.y, 300);
  const sk2 = (await pos()).find(c => c.id === 'skeleton');
  await move(sk2.x, sk2.y, true); mouse('mouseDown', sk2.x, sk2.y);
  await glide(sk2.x + 170, sk2.y - 40, 380, true);
  await glide(sk2.x + 20, sk2.y + 30, 300, true);
  await glide(sk2.x + 230, sk2.y - 70, 260, true);
  mouse('mouseUp', cx, cy); await js(`__cur(${cx},${cy},false)`);
  await glide(520, 1000, 500);
  await sleep(700);
  await js(`__cap('Pick your rope<small>8 styles</small>')`);
  for (const rope of ['gold-chain', 'neon', 'pearls', 'rainbow']) {
    settings.rope = rope; win.webContents.send('settings', settings);
    await sleep(650);
  }
  settings.rope = 'gold-chain'; win.webContents.send('settings', settings);
  await js(`__cap('')`);
  await glide(760, 1200, 300);
  win.webContents.send('nudge-all');
  await sleep(200);
  await js('__end()');
  DURATION = Math.ceil((Date.now() - start) / 1000) + 3.5;
});
