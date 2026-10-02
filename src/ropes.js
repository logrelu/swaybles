// Rope styles, shared by the overlay and the Studio previews.
(function () {
  function smooth(ctx, pts) {
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length - 1; i++) {
      const mx = (pts[i].x + pts[i + 1].x) / 2, my = (pts[i].y + pts[i + 1].y) / 2;
      ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
    }
    const l = pts[pts.length - 1];
    ctx.lineTo(l.x, l.y);
  }
  function sample(pts, step) {
    const out = [];
    let carry = 0;
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i], b = pts[i + 1];
      const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy) || 0.0001;
      const ang = Math.atan2(dy, dx);
      let d = carry;
      while (d < len) { out.push({ x: a.x + dx * d / len, y: a.y + dy * d / len, a: ang }); d += step; }
      carry = d - len;
    }
    return out;
  }
  const line = (ctx, pts, color, w, dash) => {
    ctx.save(); smooth(ctx, pts); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    if (dash) ctx.setLineDash(dash); ctx.stroke(); ctx.restore();
  };
  function chain(ctx, pts, fill, edge, hi) {
    const links = sample(pts, 6.5);
    links.forEach((p, i) => {
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a);
      if (i % 2 === 0) {
        ctx.beginPath(); ctx.ellipse(0, 0, 4.8, 2.9, 0, 0, Math.PI * 2);
        ctx.lineWidth = 3.2; ctx.strokeStyle = edge; ctx.stroke();
        ctx.lineWidth = 1.8; ctx.strokeStyle = fill; ctx.stroke();
        ctx.beginPath(); ctx.ellipse(-1, -1.4, 2.4, 0.8, 0, 0, Math.PI * 2); ctx.fillStyle = hi; ctx.fill();
      } else {
        ctx.beginPath(); ctx.moveTo(-4.6, 0); ctx.lineTo(4.6, 0);
        ctx.lineCap = 'round'; ctx.lineWidth = 3.4; ctx.strokeStyle = edge; ctx.stroke();
        ctx.lineWidth = 1.8; ctx.strokeStyle = fill; ctx.stroke();
      }
      ctx.restore();
    });
  }

  const STYLES = {
    'gold-thread': { name: 'Golden Thread', note: 'Warm & classic', draw(ctx, p) { line(ctx, p, 'rgba(90,60,10,.55)', 3.4); line(ctx, p, '#e0ae2e', 2.2); line(ctx, p, 'rgba(255,245,190,.9)', 0.8, [6, 5]); } },
    'silver-chain': { name: 'Silver Chain', note: 'Crisp & modern', draw(ctx, p) { chain(ctx, p, '#e6ebf2', '#5d6673', 'rgba(255,255,255,.9)'); } },
    'gold-chain': { name: 'Gold Chain', note: 'Bold & collectible', draw(ctx, p) { chain(ctx, p, '#f2c443', '#7a5410', 'rgba(255,248,200,.95)'); } },
    'leather': { name: 'Leather Cord', note: 'Grounded & tactile', draw(ctx, p) { line(ctx, p, '#3a2210', 6); line(ctx, p, '#8a5530', 4.2); line(ctx, p, 'rgba(255,220,180,.35)', 1, [2, 6]); } },
    'neon': { name: 'Neon', note: 'Playful after dark', draw(ctx, p, t) {
      const hue = 300 + Math.sin(t / 1400) * 30;
      ctx.save(); ctx.shadowColor = `hsl(${hue} 100% 60%)`; ctx.shadowBlur = 14;
      line(ctx, p, `hsl(${hue} 100% 62%)`, 3.4); ctx.restore(); line(ctx, p, '#fff', 1.2); } },
    'velvet': { name: 'Velvet Braid', note: 'Quiet & rich', draw(ctx, p) { line(ctx, p, '#3d0c1e', 6); line(ctx, p, '#8e2447', 4.4); line(ctx, p, '#c2466e', 2, [4, 4]); } },
    'twine': { name: 'Garden Twine', note: 'Easy & everyday', draw(ctx, p) { line(ctx, p, '#8c7045', 3.8); line(ctx, p, '#d9c08f', 2.6); line(ctx, p, '#8c7045', 1.2, [3, 3]); } },
    'pearls': { name: 'Pearl Strand', note: 'Soft & elegant', draw(ctx, p) {
      line(ctx, p, 'rgba(120,110,100,.5)', 1);
      for (const q of sample(p, 7.2)) {
        const g = ctx.createRadialGradient(q.x - 1.2, q.y - 1.2, 0.4, q.x, q.y, 3.6);
        g.addColorStop(0, '#fff'); g.addColorStop(0.6, '#f1e9df'); g.addColorStop(1, '#b8aa9b');
        ctx.beginPath(); ctx.arc(q.x, q.y, 3.3, 0, Math.PI * 2); ctx.fillStyle = g; ctx.fill();
      } } },
    'rainbow': { name: 'Rainbow Cord', note: 'Bright & happy', draw(ctx, p, t) {
      line(ctx, p, 'rgba(0,0,0,.35)', 4.6);
      for (let i = 0; i < p.length - 1; i++) {
        ctx.beginPath(); ctx.moveTo(p[i].x, p[i].y); ctx.lineTo(p[i + 1].x, p[i + 1].y);
        ctx.strokeStyle = `hsl(${(i * 32 + t / 20) % 360} 90% 60%)`; ctx.lineWidth = 3; ctx.lineCap = 'round'; ctx.stroke();
      } } },
  };

  function drawPin(ctx, x, y, hot) {
    ctx.save();
    ctx.beginPath(); ctx.arc(x, y + 1, hot ? 7 : 5, 0, Math.PI * 2);
    const g = ctx.createRadialGradient(x - 2, y - 1, 1, x, y + 1, hot ? 7 : 5);
    g.addColorStop(0, '#fff6c8'); g.addColorStop(1, '#b8841c');
    ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(60,40,10,.7)'; ctx.stroke();
    ctx.restore();
  }

  window.ROPES = { STYLES, drawPin };
})();
