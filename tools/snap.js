// Usage: electron --no-sandbox tools/snap.js <html-file> <out.png> <width> <height>
// Renders a local HTML file offscreen and saves a PNG (used for charm sheets and store images).
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
const [html, out, w = '1200', h = '900'] = process.argv.slice(-4);
app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const win = new BrowserWindow({ width: +w, height: +h, show: false, useContentSize: true, transparent: true, backgroundColor: '#00000000', webPreferences: { offscreen: true } });
  await win.loadFile(path.resolve(html));
  await new Promise(r => setTimeout(r, 1200));
  const img = await win.webContents.capturePage();
  fs.writeFileSync(out, img.toPNG());
  app.quit();
});
