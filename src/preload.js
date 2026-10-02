const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('swaybles', {
  getState: () => ipcRenderer.invoke('get-state'),
  update: (patch) => ipcRenderer.invoke('update-settings', patch),
  setIgnore: (v) => ipcRenderer.send('set-ignore', v),
  setLogin: (v) => ipcRenderer.invoke('set-login', v),
  addCustom: () => ipcRenderer.invoke('add-custom'),
  removeCustom: (id) => ipcRenderer.invoke('remove-custom', id),
  openExternal: (url) => ipcRenderer.send('open-external', url),
  onSettings: (fn) => ipcRenderer.on('settings', (_e, s) => fn(s)),
  onNudgeAll: (fn) => ipcRenderer.on('nudge-all', fn),
});
