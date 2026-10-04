// Draws the house into a 320×200 buffer and scales it to the screen.
import { CFG, H, W } from './config.js';
import { canvasEl } from './dom.js';
import { ceilingOf, CHIMNEY, FLOOR, HOUSE, roomAt, ROOMS, SHADOWS, STAIR_PAD, STAIR_STEPS, STAIRS, topOf, TREE, wellRange } from './level.js';
import { G, SANTA_IMG } from './sprites.js';
import { S } from './state.js';
import { doorBetween } from './npcs.js';

/* ---------- render ---------- */
const buf = document.createElement('canvas'); buf.width = W; buf.height = H;
const b = buf.getContext('2d');
const out = canvasEl.getContext('2d');
export const view = { w: 0, h: 0, dpr: 1, scale: 1, ox: 0, oy: 0 };

export function resize() {
  view.dpr = Math.min(devicePixelRatio || 1, 2);
  view.w = innerWidth; view.h = innerHeight;
  canvasEl.width = Math.round(view.w * view.dpr); canvasEl.height = Math.round(view.h * view.dpr);
  const fit = Math.min(view.w / W, (view.h - 40) / H);
  view.scale = fit >= 2 ? Math.floor(fit) : fit;    // integer scaling where there is room
  view.ox = Math.round((view.w - W * view.scale) / 2);
  view.oy = Math.round(Math.max(40, (view.h - H * view.scale) / 2));
}
addEventListener('resize', resize);
resize();

const STARS = Array.from({ length: 40 }, (_, i) => ({ x: (i * 73) % W, y: (i * 37) % 30, t: i * 0.7 }));

function rect(x, y, w, h, c) { b.fillStyle = c; b.fillRect(Math.round(x), Math.round(y), w, h); }

function drawSky() {
  rect(0, 0, W, H, '#070a14');
  const g = b.createLinearGradient(0, 0, 0, 40); g.addColorStop(0, '#0b1230'); g.addColorStop(1, '#1a2146');
  b.fillStyle = g; b.fillRect(0, 0, W, 40);
  for (const s of STARS) {
    const on = Math.sin(S.time * 1.5 + s.t) > -0.6;
    if (on) rect(s.x, s.y, 1, 1, '#c9d2ff');
  }
  // moon
  b.fillStyle = '#f2ecd0'; b.beginPath(); b.arc(40, 14, 7, 0, Math.PI * 2); b.fill();
  b.fillStyle = '#0d1434'; b.beginPath(); b.arc(43, 12, 6, 0, Math.PI * 2); b.fill();
  // garden ground
  rect(0, FLOOR[3] + 4, W, H - FLOOR[3], '#121a17');
  rect(0, FLOOR[3] + 4, W, 2, '#1f2d24');
}

function drawHouseShell() {
  // roof slab + tiles edge
  rect(HOUSE.x0 - 6, FLOOR[0], HOUSE.x1 - HOUSE.x0 + 12, 4, '#7a3b2e');
  for (let x = HOUSE.x0 - 6; x < HOUSE.x1 + 6; x += 6) rect(x, FLOOR[0] + 3, 3, 1, '#5a2a22');
  // chimney
  rect(CHIMNEY.x - 9, 16, 18, FLOOR[0] - 16, '#8a4a3a');
  rect(CHIMNEY.x - 11, 14, 22, 3, '#a65a46');
  for (let y = 20; y < FLOOR[0]; y += 5) rect(CHIMNEY.x - 9, y, 18, 1, '#6e3a2e');
  // outer walls
  rect(HOUSE.x0 - 4, FLOOR[0] + 4, 4, FLOOR[3] - FLOOR[0], '#3b3f55');
  rect(HOUSE.x1, FLOOR[0] + 4, 4, FLOOR[3] - FLOOR[0], '#3b3f55');
}

function drawRoom(r) {
  const t0 = ceilingOf(r.floor), bot = FLOOR[r.floor], w = r.x1 - r.x0, h = bot - t0;
  if (!S.revealed.has(r.id)) {
    rect(r.x0, t0, w, h, '#06080f');
    return;
  }
  rect(r.x0, t0, w, h, r.wall);
  // skirting + window moonlight hint
  rect(r.x0, bot - 3, w, 3, 'rgba(0,0,0,.25)');
  drawFurniture(r);
}

function drawFurniture(r) {
  const f = r.floor, y = FLOOR[f];
  switch (r.id) {
    case 'kids':
      window_(70, f);
      // bed
      rect(24, y - 9, 34, 6, '#c86a8a'); rect(24, y - 12, 6, 9, '#6b4a6a'); rect(24, y - 3, 2, 3, '#4a3448'); rect(56, y - 3, 2, 3, '#4a3448');
      rect(30, y - 11, 8, 3, '#f4f1ea'); // pillow
      // bedside table with a glass of milk for Santa
      rect(61, y - 8, 12, 2, '#8a6a44'); rect(62, y - 6, 2, 6, '#6a5030'); rect(70, y - 6, 2, 6, '#6a5030');
      if (!S.milk) { rect(65, y - 14, 4, 6, '#f4f1ea'); rect(65, y - 14, 4, 1, '#cfd8e0'); }
      wardrobe(94, f, '#6a4a3a');
      break;
    case 'hall3':
      picture(150, f); break;
    case 'attic':
      fireplace(CHIMNEY.x, f, true);
      // boxes
      rect(268, y - 10, 12, 10, '#8a6a44'); rect(278, y - 16, 14, 16, '#9c7a50'); rect(282, y - 12, 6, 1, '#6a5030');
      break;
    case 'bath':
      // bath tub + curtain
      rect(46, y - 9, 40, 9, '#d8e2ea'); rect(48, y - 8, 36, 2, '#9fc4d8');
      rect(22, topOf(f) + 4, 22, y - topOf(f) - 4, '#7aa8c4'); for (let x = 24; x < 44; x += 4) rect(x, topOf(f) + 4, 1, y - topOf(f) - 4, '#5d8aa6');
      break;
    case 'landing':
      wardrobe(100, f, '#5a4a6a');
      window_(126, f);
      break;
    case 'leo':
      // desk
      rect(214, y - 12, 24, 2, '#7a5a3a'); rect(215, y - 10, 2, 10, '#5a4028'); rect(235, y - 10, 2, 10, '#5a4028');
      rect(222, y - 17, 8, 5, '#2a2f44'); rect(223, y - 16, 6, 3, '#4fa3c8'); // monitor glow
      // bed
      rect(262, y - 9, 36, 6, '#4f7ab8'); rect(292, y - 13, 6, 10, '#3a4a6a'); rect(286, y - 11, 6, 3, '#f4f1ea');
      break;
    case 'kitchen':
      rect(20, y - 30, 16, 30, '#6a5a3a'); rect(33, y - 18, 2, 3, '#c8b070'); // pantry
      // table
      rect(58, y - 12, 32, 3, '#8a6a44'); rect(60, y - 9, 2, 9, '#6a5030'); rect(86, y - 9, 2, 9, '#6a5030');
      // bench with cookies & milk
      rect(96, y - 14, 26, 14, '#7a6a52'); rect(96, y - 14, 26, 2, '#bfb39a');
      rect(108, y - 34, 14, 12, '#556070'); // cupboard above
      if (!S.cookies) { rect(98, y - 16, 8, 1, '#e8e2d4'); rect(99, y - 18, 2, 2, '#c08850'); rect(102, y - 18, 2, 2, '#c08850'); rect(100, y - 20, 2, 2, '#c08850'); }
      break;
    case 'hall1':
      // under-stairs shadow area handled by shadows; coat rack
      rect(188, y - 22, 2, 22, '#5a4028'); rect(184, y - 22, 10, 2, '#5a4028'); rect(184, y - 20, 4, 8, '#6a3a3a');
      break;
    case 'lounge':
      fireplace(206, f, false);
      // couch
      rect(216, y - 10, 34, 10, '#7a3a44'); rect(216, y - 14, 34, 5, '#8c4652'); rect(214, y - 12, 4, 12, '#6a2e38'); rect(248, y - 12, 4, 12, '#6a2e38');
      drawTree(f);
      break;
  }
}
function window_(x, f) {
  const t = topOf(f);
  rect(x, t + 8, 18, 16, '#1b2a52'); rect(x + 2, t + 10, 14, 12, '#2c4a8a');
  rect(x + 8, t + 8, 2, 16, '#1b2a52'); rect(x, t + 15, 18, 2, '#1b2a52');
  rect(x + 3, t + 11, 2, 2, '#f2ecd0'); // star / moon glint
}
function picture(x, f) { const t = topOf(f); rect(x, t + 12, 14, 10, '#6a5030'); rect(x + 2, t + 14, 10, 6, '#4f7a8a'); }
function wardrobe(x, f, c) { const y = FLOOR[f]; rect(x, y - 30, 18, 30, c); rect(x + 8, y - 30, 1, 30, 'rgba(0,0,0,.35)'); rect(x + 6, y - 16, 1, 3, '#d8c890'); rect(x + 10, y - 16, 1, 3, '#d8c890'); }
function fireplace(x, f, attic) {
  const y = FLOOR[f];
  rect(x - 12, y - 20, 24, 20, attic ? '#6e3a2e' : '#8a4a3a'); rect(x - 14, y - 22, 28, 3, '#b0a090');
  rect(x - 7, y - 13, 14, 13, '#1a0e0c');
  if (!attic) { // embers
    const fl = Math.sin(S.time * 6) > 0;
    rect(x - 4, y - 3, 8, 3, fl ? '#e86a2a' : '#c84a1a'); rect(x - 2, y - 5, 3, 2, '#f3c35a');
  }
}
function drawTree(f) {
  const y = FLOOR[f], x = TREE.x;
  rect(x - 2, y - 6, 4, 6, '#5a3a22');
  b.fillStyle = '#2f7a4a';
  for (let i = 0; i < 3; i++) {
    const ty = y - 8 - i * 8, half = 13 - i * 3;
    b.beginPath(); b.moveTo(x - half, ty); b.lineTo(x + half, ty); b.lineTo(x, ty - 12); b.closePath(); b.fill();
  }
  const blink = Math.floor(S.time * 2) % 2;
  [['#f3c35a', -6, -12], ['#d8433b', 5, -15], ['#7ab8ff', -3, -21], ['#f3c35a', 3, -26], ['#d8433b', -7, -10]]
    .forEach(([c, dx, dy], i) => rect(x + dx, y + dy, 1, 1, (i + blink) % 2 ? c : '#ffffff'));
  rect(x - 1, y - 40, 3, 3, '#f3c35a');
  if (S.delivered) {
    rect(x - 15, y - 6, 8, 6, '#d8433b'); rect(x - 12, y - 6, 2, 6, '#f3c35a');
    rect(x + 6, y - 5, 7, 5, '#4fa3c8'); rect(x + 9, y - 5, 1, 5, '#f4f1ea');
    rect(x - 6, y - 4, 5, 4, '#9b6ad8');
  }
}

function drawShadows() {
  for (const z of SHADOWS) {
    const r = roomAt(z.floor, z.x0 + 1);
    if (!r || !S.revealed.has(r.id)) continue;
    rect(z.x0, topOf(z.floor), z.x1 - z.x0, FLOOR[z.floor] - topOf(z.floor), 'rgba(2,4,10,.55)');
  }
}

function drawStairs() {
  const bob = Math.round(Math.sin(S.time * 4));
  for (const st of STAIRS) {
    const lowRoom = roomAt(st.lower, st.bottom);
    const upRoom = roomAt(st.lower - 1, st.top);
    const lowSeen = lowRoom && S.revealed.has(lowRoom.id);
    const upSeen = upRoom && S.revealed.has(upRoom.id);
    const y0 = FLOOR[st.lower], y1 = FLOOR[st.lower - 1];
    const n = STAIR_STEPS, dx = (st.top - st.bottom) / n, dy = (y1 - y0) / n;
    const [w0, w1] = wellRange(st);

    if (lowSeen) {
      // steps, filled down to the floor so the flight reads as solid
      for (let i = 0; i < n; i++) {
        const x = st.bottom + dx * i, y = y0 + dy * (i + 1);
        rect(Math.min(x, x + dx), y, Math.ceil(Math.abs(dx)) + 1, y0 - y, i % 2 ? '#5a4a3a' : '#66543f');
        rect(Math.min(x, x + dx), y, Math.ceil(Math.abs(dx)) + 1, 1, '#8a7258');   // tread edge
      }
      // banister + posts
      b.strokeStyle = '#a0845c'; b.lineWidth = 1;
      b.beginPath(); b.moveTo(st.bottom + .5, y0 - 10.5); b.lineTo(st.top + .5, y1 - 10.5); b.stroke();
      for (let i = 0; i <= n; i += 2) {
        const x = Math.round(st.bottom + dx * i), y = y0 + dy * i;
        rect(x, y - 10, 1, 10, '#7a6448');
      }
      rect(st.bottom, y0 - 12, 2, 12, '#a0845c');   // newel post
      b.drawImage(G.up, st.bottom - 1, y0 - 20 + bob);
    }

    if (upSeen) {
      // the top steps show through the opening; dark gap if the room below is still unexplored
      if (!lowSeen) rect(w0, y1, w1 - w0, 4, '#06080f');
      // railing around the stairwell on the upper floor
      const railX0 = Math.min(w0, w1), railX1 = Math.max(w0, w1);
      rect(railX0, y1 - 9, railX1 - railX0, 1, '#a0845c');
      for (let x = railX0; x <= railX1; x += 3) rect(x, y1 - 8, 1, 8, '#7a6448');
      const far = st.top > st.bottom ? railX0 : railX1;
      rect(far - (st.top > st.bottom ? 1 : 0), y1 - 11, 2, 11, '#a0845c');
      b.drawImage(G.dn, st.top - 1, y1 - 20 + bob);
    }
  }
}

function drawSlabsAndWalls() {
  for (let f = 1; f <= 3; f++) {
    // cut the stairwell openings out of this floor's slab
    const gaps = STAIRS.filter(st => st.lower - 1 === f).map(wellRange).sort((a, b) => a[0] - b[0]);
    let x = HOUSE.x0 - 4;
    for (const [g0, g1] of gaps) { rect(x, FLOOR[f], g0 - x, 4, '#4a4f68'); x = g1; }
    rect(x, FLOOR[f], HOUSE.x1 + 4 - x, 4, '#4a4f68');
  }
  for (const r of ROOMS) {
    if (r.x1 >= HOUSE.x1) continue;
    const t = topOf(r.floor);
    rect(r.x1 - 1, t, 3, FLOOR[r.floor] - t - 20, '#3b3f55');   // wall above doorway
  }
  for (const d of S.doors) drawDoor(d);
}

function drawDoor(d) {
  const y = FLOOR[d.floor], top = y - 20;
  rect(d.x - 2, top - 1, 5, 1, '#2a2d40');                      // lintel
  if (!d.open) {
    rect(d.x - 1, top, 3, 20, '#6e4c30');
    rect(d.x - 1, top + 2, 3, 1, '#4e3420'); rect(d.x - 1, top + 11, 3, 1, '#4e3420');
    rect(d.x + (d.side > 0 ? 1 : -1), y - 10, 1, 1, '#f3c35a');  // knob
    return;
  }
  // swung open into the room it leads to, seen at an angle
  const w = Math.round(2 + 6 * d.anim), hinge = d.side > 0 ? d.x + 1 : d.x - 1;
  const x0 = d.side > 0 ? hinge : hinge - w + 1;
  rect(x0, top + 1, w, 19, '#7c5a3a');
  rect(d.side > 0 ? x0 + w - 1 : x0, top + 1, 1, 19, '#9a7650');  // lit edge
  rect(hinge, top, 1, 20, '#4e3420');
}

/* ---------- action highlight ---------- */
// Height of each hiding spot's drawn object, measured up from the floor
const HIDE_H = { wardrobe: 30, cupboard: 30, pantry: 31, boxes: 17, desk: 18, table: 13, couch: 15, curtain: 0 };

function interactionBounds(it) {
  const s = S.santa;
  switch (it.kind) {
    case 'hide': case 'unhide': {
      const h = it.hide || s.hide, y = FLOOR[h.floor];
      const ht = HIDE_H[h.kind] || (y - topOf(h.floor) - 4);
      return { x0: h.x0, x1: h.x1, y0: y - ht, y1: y };
    }
    case 'stairsUp': {
      const st = it.st, y0 = FLOOR[st.lower], y1 = FLOOR[st.lower - 1];
      return { x0: Math.min(st.bottom, st.top) - STAIR_PAD, x1: Math.max(st.bottom, st.top) + STAIR_PAD, y0: y1 - 2, y1: y0 };
    }
    case 'stairsDown': {
      const [w0, w1] = wellRange(it.st), y = FLOOR[it.st.lower - 1];
      return { x0: Math.min(w0, w1) - STAIR_PAD, x1: Math.max(w0, w1) + STAIR_PAD, y0: y - 12, y1: y + 4 };
    }
    case 'chimneyDown': return { x0: CHIMNEY.x - 12, x1: CHIMNEY.x + 12, y0: 13, y1: FLOOR[0] };
    case 'escape': return { x0: CHIMNEY.x - 15, x1: CHIMNEY.x + 15, y0: FLOOR[1] - 23, y1: FLOOR[1] };
    case 'deliver': { const y = FLOOR[TREE.floor]; return { x0: TREE.x - 16, x1: TREE.x + 16, y0: y - 42, y1: y }; }
  }
  return null;
}

function drawHighlight(it) {
  if (!it) return;
  const r = interactionBounds(it);
  if (!r) return;
  const pulse = 0.55 + 0.35 * Math.sin(S.time * 6);
  const x0 = Math.round(r.x0) - 1, y0 = Math.round(r.y0) - 1, x1 = Math.round(r.x1) + 1, y1 = Math.round(r.y1);
  const w = x1 - x0, h = y1 - y0, L = Math.min(5, Math.floor(w / 3), Math.floor(h / 3));
  // soft glow over the object
  b.fillStyle = `rgba(243, 195, 90, ${it.kind === 'unhide' ? 0.04 : 0.09 * pulse})`;
  b.fillRect(x0, y0, w, h);
  // pixel corner brackets
  b.globalAlpha = it.kind === 'unhide' ? 0.35 : pulse;
  const c = '#f3c35a';
  rect(x0, y0, L, 1, c); rect(x0, y0, 1, L, c);
  rect(x1 - L, y0, L, 1, c); rect(x1 - 1, y0, 1, L, c);
  rect(x0, y1 - 1, L, 1, c); rect(x0, y1 - L, 1, L, c);
  rect(x1 - L, y1 - 1, L, 1, c); rect(x1 - 1, y1 - L, 1, L, c);
  b.globalAlpha = 1;
}

function drawHidden(hide) {
  // two peeking eyes where Santa is hiding
  const cx = (hide.x0 + hide.x1) / 2, y = FLOOR[hide.floor];
  const blink = Math.floor(S.time * 1.3) % 4 === 0;
  if (!blink) { rect(cx - 2, y - 7, 1, 1, '#f4f1ea'); rect(cx + 1, y - 7, 1, 1, '#f4f1ea'); }
}

function drawSanta(alpha) {
  const s = S.santa;
  if (s.mode === 'hidden') { drawHidden(s.hide); return; }
  if (s.inv > 0 && Math.floor(S.time * 12) % 2) return;
  const x = s.px + (s.x - s.px) * alpha, y = s.py + (s.y - s.py) * alpha;
  const moving = Math.abs(s.vx) > 4 || s.mode === 'tween';
  const img = SANTA_IMG[moving ? Math.floor(s.anim) % 2 : 0];
  // hide inside the chimney stack while sliding
  if (s.mode === 'tween' && s.floor === 0 && y < FLOOR[0] - 8) return;
  if (!S.delivered) rect(Math.round(x) - s.face * 5 - 2, Math.round(y) - 9, 4, 6, '#8a5a32');   // sack
  b.drawImage(s.face > 0 ? img.r : img.l, Math.round(x - img.w / 2), Math.round(y - img.h));
}

// "!?!?" above a startled character, centred on cx; each mark bobs on its own beat
function drawAlarm(cx, top) {
  const marks = [G.ex, G.q, G.ex, G.q];
  const w = marks.reduce((a, m) => a + m.width + 1, -1);
  let x = Math.round(cx - w / 2);
  marks.forEach((m, i) => {
    const bob = Math.round(Math.sin(S.time * 14 + i * 1.3) * 1.2);
    b.drawImage(m, x, top + bob);
    x += m.width + 1;
  });
}

function npcVisible(n) {
  const r = roomAt(n.floor, n.x);
  if (r && S.revealed.has(r.id)) return true;
  return n.floor === S.santa.floor && Math.abs(n.x - S.santa.x) < 80 && !doorBetween(n.floor, n.x, S.santa.x);
}

function drawNpc(n) {
  if (!npcVisible(n)) return;
  const y = FLOOR[n.floor];
  if (n.state === 'asleep' || (n.state === 'stir' && n.stirPhase === 'zz')) {
    // head on the pillow + rising Z's (two of them, quicker, once the door has disturbed her)
    rect(31, y - 13, 5, 4, '#e8c25a'); rect(32, y - 12, 3, 2, '#f0b48c');
    const fast = n.state === 'stir', speed = fast ? 9 : 4;
    for (let i = 0; i < (fast ? 2 : 1); i++) {
      const t = (S.time * speed + i * 4) % 8;
      b.globalAlpha = 0.85 * (1 - t / 8);
      b.drawImage(G.z, 38 + Math.round(t / 3), Math.round(y - 17 - t));
    }
    b.globalAlpha = 1;
    return;
  }
  if (n.state === 'stir') {
    // sitting bolt upright in bed with "!?!?" bouncing above her head
    rect(30, y - 18, 6, 4, '#e8c25a'); rect(31, y - 16, 4, 3, '#f0b48c'); rect(30, y - 13, 6, 4, '#e58fb1');
    rect(32, y - 15, 1, 1, '#1a1420'); rect(34, y - 15, 1, 1, '#1a1420');   // wide-open eyes
    drawAlarm(33, y - 27);
    return;
  }
  // vision cone
  const eyeY = y - n.ht + 3;
  let R = CFG.sightRange;
  for (const d of S.doors)   // a closed door cuts the sight cone short
    if (!d.open && d.floor === n.floor && (d.x - n.x) * n.dir > 0) R = Math.min(R, Math.abs(d.x - n.x));
  b.fillStyle = `rgba(255, 226, 150, ${0.10 + n.sus * 0.22})`;
  b.beginPath(); b.moveTo(n.x, eyeY);
  b.lineTo(n.x + n.dir * R, Math.max(topOf(n.floor), eyeY - 12)); b.lineTo(n.x + n.dir * R, y); b.closePath(); b.fill();

  const img = n.img[n.state === 'walk' ? Math.floor(n.anim) % 2 : 0];
  b.drawImage(n.dir > 0 ? img.r : img.l, Math.round(n.x - img.w / 2), y - img.h);
  if (S.phase === 'caught' && S.caughtBy === n) b.drawImage(G.ex, Math.round(n.x), y - n.ht - 8);
  else if (n.sus > 0.05) b.drawImage(G.q, Math.round(n.x - 1), y - n.ht - 8);
}

export function render(alpha) {
  drawSky();
  drawHouseShell();
  for (const r of ROOMS) drawRoom(r);
  drawStairs();
  drawShadows();
  drawSlabsAndWalls();
  // current room highlight: dim every revealed room except the one Santa is in
  for (const r of ROOMS) {
    if (r.id !== S.roomId && S.revealed.has(r.id)) rect(r.x0, topOf(r.floor), r.x1 - r.x0, FLOOR[r.floor] - topOf(r.floor), 'rgba(4,6,14,.35)');
  }
  if (S.phase === 'play') drawHighlight(S.interaction);
  for (const n of S.npcs) drawNpc(n);
  drawSanta(alpha);

  // blit to screen
  out.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  out.imageSmoothingEnabled = false;
  out.fillStyle = '#0b0f1c'; out.fillRect(0, 0, view.w, view.h);
  out.drawImage(buf, view.ox, view.oy, W * view.scale, H * view.scale);
}
