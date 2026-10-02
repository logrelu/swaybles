// Swaybles — desktop charms that swing. Main process.
const { app, BrowserWindow, Tray, Menu, ipcMain, screen, nativeImage, dialog, protocol, net, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');

const isMac = process.platform === 'darwin';
const SNAP = process.env.SWAYBLES_SNAPSHOT;          // test hook: render a window offscreen and save a PNG
const SNAP_WIN = process.env.SWAYBLES_SNAP_WIN || 'overlay';
function snapshot(win) {
  win.webContents.once('did-finish-load', () => setTimeout(async () => {
    const img = await win.webContents.capturePage();
    fs.writeFileSync(SNAP, img.toPNG()); app.exit(0);
  }, 2500));
}

if (!app.requestSingleInstanceLock()) { app.quit(); }

protocol.registerSchemesAsPrivileged([{ scheme: 'swaybles', privileges: { standard: true, secure: true, supportFetchAPI: true } }]);

const userDir = () => app.getPath('userData');
const customDir = () => path.join(userDir(), 'custom-charms');
const settingsFile = () => path.join(userDir(), 'settings.json');

const DEFAULTS = {
  charms: [
    { uid: 'a1', id: 'skeleton', x: 0.34, len: 160 },
    { uid: 'a2', id: 'flower-skull', x: 0.47, len: 90 },
    { uid: 'a3', id: 'cauldron', x: 0.60, len: 190 },
    { uid: 'a4', id: 'zombie-hand', x: 0.73, len: 110 },
    { uid: 'a5', id: 'rip-mondays', x: 0.86, len: 150 },
  ],
  custom: [],            // [{ id, name, file }]
  rope: 'gold-thread',
  size: 1,
  displayId: null,
  reduceMotion: false,
  breeze: false,
  sound: false,
  paused: false,
  onboarded: false,
};

let settings = loadSettings();
let overlay = null, studio = null, tray = null;

function loadSettings() {
  try { return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(settingsFile(), 'utf8')) }; }
  catch { return JSON.parse(JSON.stringify(DEFAULTS)); }
}
function saveSettings() {
  fs.mkdirSync(userDir(), { recursive: true });
  fs.writeFileSync(settingsFile(), JSON.stringify(settings, null, 2));
}
function broadcast() {
  for (const w of [overlay, studio]) if (w && !w.isDestroyed()) w.webContents.send('settings', settings);
  buildTrayMenu();
}

function targetDisplay() {
  const all = screen.getAllDisplays();
  return all.find(d => d.id === settings.displayId) || screen.getPrimaryDisplay();
}

// ───────────── Overlay: a transparent, click-through window over the work area ─────────────
function createOverlay() {
  if (overlay && !overlay.isDestroyed()) overlay.destroy();
  const d = targetDisplay();
  const b = SNAP ? { x: 0, y: 0, width: 1280, height: 720 } : d.workArea;
  overlay = new BrowserWindow({
    ...b,
    transparent: true, frame: false, resizable: false, movable: false, hasShadow: false,
    skipTaskbar: true, focusable: false, alwaysOnTop: true, fullscreenable: false,
    show: false, backgroundColor: '#00000000',
    type: isMac ? 'panel' : undefined,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), offscreen: !!SNAP, backgroundThrottling: false },
  });
  overlay.setAlwaysOnTop(true, 'floating');
  if (isMac) overlay.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false });
  overlay.setIgnoreMouseEvents(true, { forward: true });
  overlay.loadFile(path.join(__dirname, 'overlay.html'), SNAP ? { query: process.env.SWAYBLES_SNAP_BARE ? { snapshot: '1', bare: '1' } : { snapshot: '1' } } : undefined);
  overlay.once('ready-to-show', () => { if (!settings.paused && !SNAP) overlay.showInactive(); });
  if (SNAP && SNAP_WIN === 'overlay') snapshot(overlay);
}

// ───────────── Charm Studio ─────────────
function openStudio() {
  if (studio && !studio.isDestroyed()) { studio.show(); studio.focus(); return; }
  studio = new BrowserWindow({
    width: 980, height: 720, minWidth: 760, minHeight: 560, title: 'Swaybles Studio',
    backgroundColor: '#15121c', show: false, autoHideMenuBar: true,
    titleBarStyle: isMac ? 'hiddenInset' : 'default',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), offscreen: !!SNAP },
  });
  if (SNAP) snapshot(studio);
  studio.loadFile(path.join(__dirname, 'studio.html'));
  studio.once('ready-to-show', () => studio.show());
  if (isMac) app.dock.show();
  studio.on('closed', () => { studio = null; if (isMac) app.dock.hide(); });
}

// ───────────── Tray ─────────────
function trayIcon() {
  const f = path.join(__dirname, 'assets', isMac ? 'trayTemplate.png' : 'tray.png');
  const img = nativeImage.createFromPath(f);
  if (isMac) img.setTemplateImage(true);
  return img;
}
function buildTrayMenu() {
  if (!tray) return;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Open Swaybles Studio…', click: openStudio },
    { label: settings.paused ? 'Show charms' : 'Hide charms', click: () => setPaused(!settings.paused) },
    { label: 'Give them a nudge', click: () => overlay && overlay.webContents.send('nudge-all') },
    { type: 'separator' },
    { label: 'Launch at login', type: 'checkbox', checked: app.getLoginItemSettings().openAtLogin,
      click: (i) => app.setLoginItemSettings({ openAtLogin: i.checked, openAsHidden: true }) },
    { type: 'separator' },
    { label: 'Quit Swaybles', role: 'quit' },
  ]));
}
function setPaused(p) {
  settings.paused = p; saveSettings();
  if (overlay) p ? overlay.hide() : overlay.showInactive();
  broadcast();
}

// ───────────── IPC ─────────────
ipcMain.handle('get-state', () => ({
  settings,
  charms: require('./charms.json'),
  displays: screen.getAllDisplays().map((d, i) => ({ id: d.id, label: `Display ${i + 1} (${d.size.width}×${d.size.height})${d.id === screen.getPrimaryDisplay().id ? ' · main' : ''}` })),
  platform: process.platform,
  version: app.getVersion(),
  openAtLogin: app.getLoginItemSettings().openAtLogin,
}));

ipcMain.on('set-ignore', (_e, ignore) => {
  if (overlay && !overlay.isDestroyed()) overlay.setIgnoreMouseEvents(ignore, { forward: true });
});

ipcMain.handle('update-settings', (_e, patch) => {
  const displayChanged = 'displayId' in patch && patch.displayId !== settings.displayId;
  settings = { ...settings, ...patch };
  saveSettings();
  if ('paused' in patch) setPaused(settings.paused);
  if (displayChanged) createOverlay();
  broadcast();
  return settings;
});

ipcMain.handle('set-login', (_e, on) => { app.setLoginItemSettings({ openAtLogin: on, openAsHidden: true }); buildTrayMenu(); return on; });

ipcMain.handle('add-custom', async () => {
  const r = await dialog.showOpenDialog(studio, {
    title: 'Choose a photo or artwork', properties: ['openFile'],
    filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'svg', 'gif'] }],
  });
  if (r.canceled || !r.filePaths[0]) return null;
  const src = r.filePaths[0];
  const stat = fs.statSync(src);
  if (stat.size > 15 * 1024 * 1024) return { error: 'That image is over 15 MB — try a smaller one.' };
  fs.mkdirSync(customDir(), { recursive: true });
  const id = 'custom-' + Date.now().toString(36);
  const file = id + path.extname(src).toLowerCase();
  fs.copyFileSync(src, path.join(customDir(), file));
  const name = path.basename(src, path.extname(src)).slice(0, 28);
  settings.custom = [...settings.custom, { id, name, file }];
  saveSettings(); broadcast();
  return { id, name, file };
});

ipcMain.handle('remove-custom', (_e, id) => {
  const c = settings.custom.find(x => x.id === id);
  if (c) try { fs.unlinkSync(path.join(customDir(), c.file)); } catch {}
  settings.custom = settings.custom.filter(x => x.id !== id);
  settings.charms = settings.charms.filter(x => x.id !== id);
  saveSettings(); broadcast();
});

ipcMain.on('open-external', (_e, url) => { if (/^https:\/\//.test(url)) shell.openExternal(url); });

// ───────────── Startup ─────────────
function startCharms() {
  if (!overlay || overlay.isDestroyed()) createOverlay();
}

app.whenReady().then(async () => {
  protocol.handle('swaybles', (req) => {
    const u = new URL(req.url);
    const file = path.basename(decodeURIComponent(u.pathname));
    return net.fetch(pathToFileURL(path.join(customDir(), file)).toString());
  });

  if (SNAP) { ({ overlay: createOverlay, studio: openStudio })[SNAP_WIN](); return; }
  if (isMac) app.dock.hide();

  tray = new Tray(trayIcon());
  tray.setToolTip('Swaybles');
  if (!isMac) tray.on('click', openStudio);
  buildTrayMenu();

  screen.on('display-removed', () => createOverlay());
  screen.on('display-metrics-changed', () => createOverlay());

  startCharms();
  if (!settings.onboarded) { openStudio(); settings.onboarded = true; saveSettings(); }
});

app.on('second-instance', openStudio);
app.on('activate', openStudio);
app.on('window-all-closed', (e) => { /* stay alive in the tray */ });
