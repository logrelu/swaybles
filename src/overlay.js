// Overlay: rope physics + drawing + mouse interaction.
(async function () {
  const api = window.swaybles;
  const cv = document.getElementById('c');
  const ctx = cv.getContext('2d');
  const SNAPSHOT = new URLSearchParams(location.search).has('snapshot');
  const BARE = new URLSearchParams(location.search).has('bare'); // test mode: transparent background
  if (SNAPSHOT && !BARE) document.body.classList.add('snapshot');

  const SEGS = 12, SUB = 1 / 120, BASE_H = 170;
  let W = 0, H = 0, dpr = 1;
  let state = await api.getState();
  let S = state.settings;
  const defs = new Map(state.charms.map(c => [c.id, c]));
  const images = new Map();   // id -> drawable
  let items = [];             // live hanging charms
  const reduceOS = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ── images ──
  function loadImg(src) {
    return new Promise((res) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => res(null); i.src = src; });
  }
  async function medallion(file) {
    const img = await loadImg('swaybles://custom/' + encodeURIComponent(file));
    const c = document.createElement('canvas'); c.width = 300; c.height = 360;
    const g = c.getContext('2d'); g.scale(3, 3);
    g.save(); g.beginPath(); g.arc(50, 68, 40, 0, Math.PI * 2); g.closePath();
    g.fillStyle = '#fff'; g.fill(); g.clip();
    if (img) {
      const s = Math.max(80 / img.width, 80 / img.height);
      g.drawImage(img, 50 - img.width * s / 2, 68 - img.height * s / 2, img.width * s, img.height * s);
    }
    g.restore();
    const grad = g.createLinearGradient(10, 28, 90, 108); grad.addColorStop(0, '#fff0a8'); grad.addColorStop(0.45, '#f5c542'); grad.addColorStop(1, '#c9891a');
    g.beginPath(); g.arc(50, 68, 40, 0, Math.PI * 2); g.lineWidth = 7; g.strokeStyle = '#2b1d16'; g.stroke(); g.lineWidth = 4; g.strokeStyle = grad; g.stroke();
    g.beginPath(); g.moveTo(50, 12); g.lineTo(50, 28); g.lineWidth = 3; g.strokeStyle = '#2b1d16'; g.stroke();
    g.beginPath(); g.arc(50, 8, 5.5, 0, Math.PI * 2); g.lineWidth = 5; g.stroke(); g.lineWidth = 2.5; g.strokeStyle = '#f5c542'; g.stroke();
    return c;
  }
  async function imageFor(id) {
    if (images.has(id)) return images.get(id);
    let im = null;
    const custom = S.custom.find(c => c.id === id);
    if (custom) im = await medallion(custom.file);
    else if (defs.has(id)) im = await loadImg(defs.get(id).file);
    images.set(id, im); return im;
  }
  // Size and rope-attach point of a charm, in px at size 1.
  function geoFor(id) {
    const d = defs.get(id);
    if (d && d.w) { const h = BASE_H, w = h * d.w / d.h; return { w, h, ax: d.ax, ay: d.ay }; }
    return { w: 125, h: 150, ax: 0.5, ay: 3 / 120 }; // photo medallion
  }

  // ── physics ──
  function makeItem(cfg, old) {
    const ax = cfg.x * W, ay = 2, seg = cfg.len / SEGS;
    const nodes = [];
    for (let i = 0; i <= SEGS; i++) {
      const p = old && old.nodes[i] && old.len === cfg.len
        ? { ...old.nodes[i] }
        : { x: ax, y: ay + i * seg, px: ax, py: ay + i * seg };
      p.w = i === 0 ? 0 : i === SEGS ? 0.3 : 1;
      nodes.push(p);
    }
    nodes[0].x = nodes[0].px = ax; nodes[0].y = nodes[0].py = ay;
    return { uid: cfg.uid, id: cfg.id, x: cfg.x, len: cfg.len, seg, nodes, ang: old ? old.ang : 0, av: old ? old.av : 0, img: null, geo: geoFor(cfg.id), phase: Math.random() * 10 };
  }
  async function rebuild() {
    const prev = new Map(items.map(i => [i.uid, i]));
    const next = [];
    for (const c of S.charms) {
      const it = makeItem(c, prev.get(c.uid));
      it.img = await imageFor(c.id);
      next.push(it);
    }
    items = next; wake();
  }

  const damp = () => (S.reduceMotion || reduceOS) ? 0.975 : 0.9955;
  function step(dt, t) {
    const d = damp();
    for (const it of items) {
      const wind = S.breeze ? Math.sin(t / 1300 + it.phase) * 70 + Math.sin(t / 470 + it.phase * 2) * 25 : 0;
      SwayPhysics.stepRope(it.nodes, it.seg, { x: it.x * W, y: 2 }, dt, d, wind);
      const o = SwayPhysics.orient(it.nodes, it.ang, it.av);
      it.ang = o.ang; it.av = o.av;
    }
  }

  // ── geometry helpers ──
  const size = () => S.size || 1;
  function charmCenter(it) {
    const g = it.geo, k = size();
    const ox = (0.5 - g.ax) * g.w * k, oy = (0.5 - g.ay) * g.h * k; // centre relative to the ring
    const c = Math.cos(it.ang), sn = Math.sin(it.ang), e = it.nodes[SEGS];
    return { x: e.x + ox * c - oy * sn, y: e.y + ox * sn + oy * c };
  }
  function hit(x, y) {
    for (let i = items.length - 1; i >= 0; i--) {
      const it = items[i], c = charmCenter(it);
      if (Math.hypot(x - c.x, y - c.y) < Math.min(it.geo.w, it.geo.h) * size() * 0.5) return { it, kind: 'charm' };
      const a = it.nodes[0];
      if (Math.hypot(x - a.x, y - a.y) < 14) return { it, kind: 'pin' };
    }
    return null;
  }

  // ── drawing ──
  function draw(t) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    const rope = ROPES.STYLES[S.rope] || ROPES.STYLES['gold-thread'];
    for (const it of items) {
      rope.draw(ctx, it.nodes, t);
      ROPES.drawPin(ctx, it.nodes[0].x, it.nodes[0].y + 2, hover && hover.it === it);
      if (!it.img) continue;
      const e = it.nodes[SEGS], g = it.geo, w = g.w * size(), h = g.h * size();
      ctx.save();
      ctx.translate(e.x, e.y); ctx.rotate(it.ang);
      ctx.shadowColor = 'rgba(0,0,0,.28)'; ctx.shadowBlur = 10 * size(); ctx.shadowOffsetY = 5 * size();
      ctx.drawImage(it.img, -w * g.ax, -h * g.ay, w, h);
      ctx.restore();
    }
  }

  // ── loop with idle sleep ──
  let running = false, last = 0, acc = 0, still = 0;
  function energy() {
    let e = 0;
    for (const it of items) for (const n of it.nodes) e += Math.abs(n.x - n.px) + Math.abs(n.y - n.py);
    return e + Math.abs(it_av());
  }
  const it_av = () => items.reduce((s, i) => s + Math.abs(i.av), 0);
  function frame(t) {
    if (!last) last = t;
    acc += Math.min(0.05, (t - last) / 1000); last = t;
    while (acc >= SUB) { step(SUB, t); acc -= SUB; }
    draw(t);
    still = energy() < 0.05 && !drag && !S.breeze && S.rope !== 'neon' && S.rope !== 'rainbow' ? still + 1 : 0;
    if (still > 90) { running = false; last = 0; return; }
    requestAnimationFrame(frame);
  }
  function wake() { still = 0; if (!running) { running = true; last = 0; requestAnimationFrame(frame); } }

  // ── interaction ──
  let hover = null, drag = null, ignoring = true, mouse = { x: 0, y: 0, vx: 0, vy: 0, t: 0 };
  const nudged = new Map();
  let audio = null;
  function chime() {
    if (!S.sound) return;
    audio = audio || new AudioContext();
    const o = audio.createOscillator(), g = audio.createGain();
    o.type = 'sine'; o.frequency.value = 1760 + Math.random() * 400;
    g.gain.setValueAtTime(0.0001, audio.currentTime);
    g.gain.exponentialRampToValueAtTime(0.05, audio.currentTime + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + 0.6);
    o.connect(g).connect(audio.destination); o.start(); o.stop(audio.currentTime + 0.65);
  }
  function setIgnore(v) { if (v !== ignoring) { ignoring = v; api.setIgnore(v); } }
  function cursor() {
    document.body.className = SNAPSHOT && !BARE ? 'snapshot' : '';
    if (drag) document.body.classList.add(drag.kind === 'pin' ? 'slide' : 'grabbing');
    else if (hover) document.body.classList.add(hover.kind === 'pin' ? 'slide' : 'grab');
  }

  window.addEventListener('mousemove', (e) => {
    const now = performance.now(), dt = Math.max(1, now - mouse.t);
    mouse.vx = (e.clientX - mouse.x) / dt * 16; mouse.vy = (e.clientY - mouse.y) / dt * 16;
    mouse.x = e.clientX; mouse.y = e.clientY; mouse.t = now;

    if (drag) {
      if (drag.kind === 'pin') {
        drag.it.x = Math.min(0.99, Math.max(0.01, e.clientX / W));
      } else {
        const a = drag.it.nodes[0], end = drag.it.nodes[SEGS];
        let tx = e.clientX - drag.ox, ty = e.clientY - drag.oy;
        const dx = tx - a.x, dy = ty - a.y, d = Math.hypot(dx, dy), max = drag.it.len * 1.02;
        if (d > max) { tx = a.x + dx / d * max; ty = a.y + dy / d * max; }
        end.px = end.x; end.py = end.y; end.x = tx; end.y = ty;
      }
      wake(); return;
    }
    const h = hit(e.clientX, e.clientY);
    if (h && h.kind === 'charm') {
      const since = now - (nudged.get(h.it.uid) || 0);
      const speed = Math.hypot(mouse.vx, mouse.vy);
      if (since > 350 && speed > 4) {
        const end = h.it.nodes[SEGS];
        end.px -= mouse.vx * 0.9; end.py -= mouse.vy * 0.4;
        nudged.set(h.it.uid, now); chime(); wake();
      }
    }
    if ((h && h.it) !== (hover && hover.it) || (h && h.kind) !== (hover && hover.kind)) { hover = h; draw(now); }
    setIgnore(!h); cursor();
  });

  window.addEventListener('mousedown', (e) => {
    const h = hit(e.clientX, e.clientY);
    if (!h) return;
    if (h.kind === 'pin') drag = { it: h.it, kind: 'pin' };
    else {
      const end = h.it.nodes[SEGS];
      drag = { it: h.it, kind: 'charm', ox: e.clientX - end.x, oy: e.clientY - end.y };
      end.pinned = true;
    }
    cursor(); wake();
  });
  window.addEventListener('mouseup', () => {
    if (!drag) return;
    const d = drag; drag = null;
    if (d.kind === 'charm') { d.it.nodes[SEGS].pinned = false; chime(); }
    else {
      const charms = S.charms.map(c => c.uid === d.it.uid ? { ...c, x: +d.it.x.toFixed(4) } : c);
      api.update({ charms });
    }
    cursor(); wake();
  });
  window.addEventListener('mouseleave', () => { if (!drag) { hover = null; setIgnore(true); cursor(); } });

  api.onNudgeAll(() => { for (const it of items) { const e = it.nodes[SEGS]; e.px -= (Math.random() < 0.5 ? -1 : 1) * (14 + Math.random() * 10); } chime(); wake(); });
  api.onSettings(async (s) => {
    const customChanged = JSON.stringify(s.custom) !== JSON.stringify(S.custom);
    S = s; if (customChanged) for (const k of [...images.keys()]) if (k.startsWith('custom-') && !S.custom.find(c => c.id === k)) images.delete(k);
    await rebuild();
  });

  function resize() {
    dpr = window.devicePixelRatio || 1; W = innerWidth; H = innerHeight;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    wake();
  }
  // Read-only positions of the charms (used by the promo-video recorder).
  window.__swayblesPositions = () => items.map(it => ({ id: it.id, ...charmCenter(it) }));
  window.addEventListener('resize', resize);
  resize();
  await rebuild();

  // Snapshot (test) mode: start the charms mid-swing so the still shows motion.
  if (SNAPSHOT) items.forEach((it, i) => { const e = it.nodes[SEGS]; e.px -= (i % 2 ? 3 : -4); });
  // First launch: a friendly little swing hello.
  else setTimeout(() => items.forEach((it, i) => { const e = it.nodes[SEGS]; e.px -= (i % 2 ? 10 : -10); wake(); }), 400);
})();
