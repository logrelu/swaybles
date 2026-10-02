(async function () {
  const api = window.swaybles;
  const $ = (id) => document.getElementById(id);
  let st = await api.getState();
  let S = st.settings;
  const MAX = 12;
  const THEMES = [...new Set(st.charms.map(c => c.theme)), 'Your Own'];
  let tab = THEMES[0];
  if (st.platform === 'darwin') document.body.classList.add('mac');
  $('ver').textContent = `Swaybles ${st.version}`;

  const toast = (msg) => { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toast.h); toast.h = setTimeout(() => t.classList.remove('show'), 1800); };
  const def = (id) => st.charms.find(c => c.id === id) || S.custom.find(c => c.id === id);
  const isCustom = (id) => id.startsWith('custom-');
  const customSrc = (c) => 'swaybles://custom/' + encodeURIComponent(c.file);
  const uid = () => Math.random().toString(36).slice(2, 9);
  const save = async (patch) => { S = await api.update(patch); render(); };

  function hang(id) {
    const existing = S.charms.find(c => c.id === id);
    if (existing) { save({ charms: S.charms.filter(c => c !== existing) }); toast('Taken down'); return; }
    if (S.charms.length >= MAX) { toast(`You can hang up to ${MAX} at once`); return; }
    // find the widest gap along the top of the screen
    const xs = [0.02, ...S.charms.map(c => c.x).sort((a, b) => a - b), 0.98];
    let best = 0.85, gap = 0;
    for (let i = 0; i < xs.length - 1; i++) if (xs[i + 1] - xs[i] > gap) { gap = xs[i + 1] - xs[i]; best = (xs[i] + xs[i + 1]) / 2; }
    const len = 80 + Math.round(Math.random() * 90);
    save({ charms: [...S.charms, { uid: uid(), id, x: +best.toFixed(3), len }] });
    toast('Hung on your desktop ✦');
  }

  function renderTabs() {
    $('tabs').innerHTML = '';
    for (const t of THEMES) {
      const b = document.createElement('button');
      b.textContent = t; b.className = t === tab ? 'on' : '';
      b.onclick = () => { tab = t; render(); };
      $('tabs').appendChild(b);
    }
  }

  function card(c, custom) {
    const d = document.createElement('div');
    d.className = 'charm' + (S.charms.some(h => h.id === c.id) ? ' hung' : '');
    d.title = S.charms.some(h => h.id === c.id) ? 'Click to take it down' : 'Click to hang it';
    d.innerHTML = custom
      ? `<img class="medal" src="${customSrc(c)}" alt=""><div class="n"></div><button class="x" title="Delete">✕</button>`
      : `<img src="${c.file}" alt=""><div class="n"></div>`;
    d.querySelector('.n').textContent = c.name;
    d.onclick = () => hang(c.id);
    if (custom) d.querySelector('.x').onclick = (e) => { e.stopPropagation(); api.removeCustom(c.id); };
    return d;
  }

  function renderGrid() {
    const g = $('grid'); g.innerHTML = '';
    if (tab === 'Your Own' || tab === 'All') {
      if (tab === 'Your Own') {
        const add = document.createElement('div');
        add.className = 'charm add'; add.innerHTML = '<b>+</b>Make a charm from<br>a photo or artwork';
        add.onclick = async () => { const r = await api.addCustom(); if (r && r.error) toast(r.error); else if (r) { S = (await api.getState()).settings; hang(r.id); } };
        g.appendChild(add);
      }
      for (const c of S.custom) g.appendChild(card(c, true));
    }
    if (tab !== 'Your Own') for (const c of st.charms) if (tab === 'All' || c.theme === tab) g.appendChild(card(c, false));
  }

  function renderHanging() {
    const h = $('hanging'); h.innerHTML = '';
    if (!S.charms.length) { h.innerHTML = '<div class="empty">Nothing hanging yet — pick a charm on the right.</div>'; return; }
    for (const c of S.charms) {
      const d = def(c.id); if (!d) continue;
      const r = document.createElement('div'); r.className = 'row';
      r.innerHTML = `${isCustom(c.id) ? `<img class="medal-s" src="${customSrc(d)}">` : `<img src="${d.file}">`}
        <div><div class="nm"></div><input type="range" min="40" max="320" step="5" title="Rope length"></div><button title="Take down">✕</button>`;
      r.querySelector('.nm').textContent = d.name;
      const len = r.querySelector('input'); len.value = c.len;
      len.onchange = () => save({ charms: S.charms.map(x => x.uid === c.uid ? { ...x, len: +len.value } : x) });
      r.querySelector('button').onclick = () => save({ charms: S.charms.filter(x => x.uid !== c.uid) });
      h.appendChild(r);
    }
  }

  function renderRopes() {
    const box = $('ropes'); box.innerHTML = '';
    for (const [key, r] of Object.entries(ROPES.STYLES)) {
      const d = document.createElement('div');
      d.className = 'rope' + (S.rope === key ? ' on' : ''); d.title = `${r.name} — ${r.note}`;
      const cv = document.createElement('canvas'); cv.width = 160; cv.height = 68;
      const ctx = cv.getContext('2d'); ctx.scale(2, 2);
      const pts = []; for (let i = 0; i <= 12; i++) { const x = 6 + i * 5.7; pts.push({ x, y: 10 + Math.sin(i / 12 * Math.PI) * 14 }); }
      r.draw(ctx, pts, 0);
      const s = document.createElement('span'); s.textContent = r.name;
      d.append(cv, s); d.onclick = () => save({ rope: key });
      box.appendChild(d);
    }
  }

  function renderControls() {
    $('size').value = S.size;
    for (const k of ['breeze', 'sound', 'reduceMotion', 'paused']) $(k).checked = !!S[k];
    $('login').checked = !!st.openAtLogin;
    $('display').innerHTML = st.displays.map(d => `<option value="${d.id}">${d.label}</option>`).join('');
    $('display').value = S.displayId || st.displays.find(d => d.label.includes('main'))?.id || '';
  }

  function render() { renderTabs(); renderGrid(); renderHanging(); renderRopes(); renderControls(); }

  $('size').oninput = () => api.update({ size: +$('size').value });
  for (const k of ['breeze', 'sound', 'reduceMotion', 'paused']) $(k).onchange = () => save({ [k]: $(k).checked });
  $('login').onchange = async () => { st.openAtLogin = await api.setLogin($('login').checked); };
  $('display').onchange = () => save({ displayId: +$('display').value });

  api.onSettings((s) => { S = s; render(); });
  render();
})();
