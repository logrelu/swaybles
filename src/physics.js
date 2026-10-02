// Rope physics (Verlet), shared by the overlay (browser) and the unit tests (Node).
(function (root) {
  const GRAVITY = 2400, ITERATIONS = 14;

  function makeRope(x, y, length, segments) {
    const seg = length / segments, nodes = [];
    for (let i = 0; i <= segments; i++) nodes.push({ x, y: y + i * seg, px: x, py: y + i * seg, w: i === 0 ? 0 : i === segments ? 0.3 : 1 });
    return { nodes, seg };
  }

  // One fixed time step. anchor = where the top of the rope is pinned; wind = sideways push.
  function stepRope(nodes, seg, anchor, dt, damping, wind) {
    const N = nodes, last = N.length - 1;
    N[0].x = N[0].px = anchor.x; N[0].y = N[0].py = anchor.y;
    for (let i = 1; i <= last; i++) {
      const n = N[i];
      if (n.pinned) continue;
      const vx = (n.x - n.px) * damping, vy = (n.y - n.py) * damping;
      n.px = n.x; n.py = n.y;
      n.x += vx + (wind || 0) * dt * dt; n.y += vy + GRAVITY * dt * dt;
    }
    for (let k = 0; k < ITERATIONS; k++) {
      for (let i = 0; i < last; i++) {
        const a = N[i], b = N[i + 1];
        const wa = a.pinned ? 0 : a.w, wb = b.pinned ? 0 : b.w, ws = wa + wb;
        if (!ws) continue;
        const dx = b.x - a.x, dy = b.y - a.y, dist = Math.hypot(dx, dy) || 0.0001;
        const diff = (dist - seg) / dist / ws;
        a.x += dx * diff * wa; a.y += dy * diff * wa;
        b.x -= dx * diff * wb; b.y -= dy * diff * wb;
      }
    }
  }

  // The charm's tilt follows the last stretch of rope, with a little inertia.
  function orient(nodes, ang, av) {
    const L = nodes.length - 1, a = nodes[L - 2], b = nodes[L];
    const target = Math.atan2(-(b.x - a.x), b.y - a.y);
    av = av * 0.86 + (target - ang) * 0.22;
    return { ang: ang + av, av };
  }

  const api = { GRAVITY, ITERATIONS, makeRope, stepRope, orient };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.SwayPhysics = api;
})(this);
