const test = require('node:test');
const assert = require('node:assert/strict');
const P = require('../src/physics');

const DT = 1 / 120, DAMP = 0.9955;
const run = (rope, anchor, steps, wind = 0) => { for (let i = 0; i < steps; i++) P.stepRope(rope.nodes, rope.seg, anchor, DT, DAMP, wind); };
const ropeLength = (nodes) => nodes.slice(1).reduce((s, n, i) => s + Math.hypot(n.x - nodes[i].x, n.y - nodes[i].y), 0);
const speed = (nodes) => nodes.reduce((s, n) => s + Math.hypot(n.x - n.px, n.y - n.py), 0);

test('the top of the rope stays pinned to the anchor', () => {
  const r = P.makeRope(100, 2, 150, 12);
  r.nodes[12].px -= 20; // give it a shove
  run(r, { x: 100, y: 2 }, 300);
  assert.equal(r.nodes[0].x, 100);
  assert.equal(r.nodes[0].y, 2);
});

test('rope keeps its length while swinging (within 3%)', () => {
  const r = P.makeRope(100, 2, 150, 12);
  r.nodes[12].px -= 25;
  for (let i = 0; i < 20; i++) { run(r, { x: 100, y: 2 }, 30); assert.ok(Math.abs(ropeLength(r.nodes) - 150) < 4.5, `length ${ropeLength(r.nodes)}`); }
});

test('a nudged charm swings and then settles hanging straight down', () => {
  const r = P.makeRope(100, 2, 150, 12);
  r.nodes[12].px -= 25;
  run(r, { x: 100, y: 2 }, 30);
  assert.ok(Math.abs(r.nodes[12].x - 100) > 5, 'it moved sideways');
  run(r, { x: 100, y: 2 }, 120 * 60); // one minute
  assert.ok(Math.abs(r.nodes[12].x - 100) < 1, `end x ${r.nodes[12].x}`);
  assert.ok(r.nodes[12].y > 140, 'hangs below the anchor');
  assert.ok(speed(r.nodes) < 0.05, 'came to rest');
});

test('a pinned (grabbed) charm stays where the cursor holds it', () => {
  const r = P.makeRope(100, 2, 150, 12);
  Object.assign(r.nodes[12], { x: 160, y: 120, px: 160, py: 120, pinned: true });
  run(r, { x: 100, y: 2 }, 240);
  assert.equal(r.nodes[12].x, 160);
  assert.equal(r.nodes[12].y, 120);
});

test('moving the anchor drags the rope along', () => {
  const r = P.makeRope(100, 2, 150, 12);
  run(r, { x: 400, y: 2 }, 120 * 30);
  assert.ok(Math.abs(r.nodes[12].x - 400) < 2, `end x ${r.nodes[12].x}`);
});

test('breeze pushes the charm sideways', () => {
  const r = P.makeRope(100, 2, 150, 12);
  run(r, { x: 100, y: 2 }, 600, 300);
  assert.ok(r.nodes[12].x > 105);
});

test('charm tilt follows the rope and stays level at rest', () => {
  const r = P.makeRope(100, 2, 150, 12);
  let o = { ang: 0, av: 0 };
  Object.assign(r.nodes[12], { x: 160 }); Object.assign(r.nodes[10], { x: 140 });
  for (let i = 0; i < 60; i++) o = P.orient(r.nodes, o.ang, o.av);
  assert.ok(o.ang < -0.3, `tilts toward the swing, ang ${o.ang}`);
  const still = P.makeRope(100, 2, 150, 12); o = { ang: 0, av: 0 };
  for (let i = 0; i < 60; i++) o = P.orient(still.nodes, o.ang, o.av);
  assert.ok(Math.abs(o.ang) < 1e-9);
});
