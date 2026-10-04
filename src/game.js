// Santa: movement, stairs, hiding, interactions and the per-step update.
import { CFG } from './config.js';
import { ceilingOf, CHIMNEY, FLOOR, HIDES, HOUSE, MILK, PLATFORMS, roomAt, STAIR_PAD, STAIRS, TREE, wellRange } from './level.js';
import { Sfx } from './audio.js';
import { meta, newGame, S } from './state.js';
import { input } from './input.js';
import { openDoor, updateNpcs, wakeNpc } from './npcs.js';
import { toast, ui, updateHud, updatePrompt, win } from './ui.js';

/* ---------- santa: movement, checkpoints, interactions ---------- */
function setCheckpoint() { S.checkpoint = { floor: S.santa.floor, x: S.santa.x }; S.santa.grace = 0.8; }

// Walk Santa along the floor to x, then run `then` (used to reach the end of a staircase)
function walkTo(x, y, then) {
  const s = S.santa, d = Math.abs(x - s.x);
  if (d < 1.5) { s.x = x; s.y = y; then(); return; }
  s.face = Math.sign(x - s.x);
  s.y = y;
  tweenSanta(x, y, d / 70, then);
}

function tweenSanta(x1, y1, dur, done) {
  const s = S.santa;
  s.tween = { x0: s.x, y0: s.y, x1, y1, t: 0, dur, done };
  s.mode = 'tween'; s.vx = s.vy = 0;
}

/* ---------- interactions ---------- */
function currentInteraction() {
  const s = S.santa;
  if (s.mode === 'hidden') return { kind: 'unhide', label: 'Come out', dir: 'any' };
  if (s.mode !== 'walk' || !s.onGround) return null;

  if (s.floor === 0 && s.x >= CHIMNEY.roofX0 && s.x <= CHIMNEY.roofX1)
    return { kind: 'chimneyDown', label: 'Slide down chimney', dir: 'down' };

  if (s.floor === TREE.floor && s.x >= TREE.x0 && !S.delivered)
    return { kind: 'deliver', label: 'Deliver presents', dir: 'action' };

  if (s.floor === 1 && S.delivered && s.x >= 236 && s.x <= 262)
    return { kind: 'escape', label: 'Escape up chimney', dir: 'up' };

  for (const st of STAIRS) {
    // Anywhere along the flight (downstairs) or over the stairwell opening (upstairs) counts
    const fx0 = Math.min(st.bottom, st.top) - STAIR_PAD, fx1 = Math.max(st.bottom, st.top) + STAIR_PAD;
    if (s.floor === st.lower && s.x >= fx0 && s.x <= fx1) return { kind: 'stairsUp', label: 'Go upstairs', dir: 'up', st };
    const [w0, w1] = wellRange(st);
    if (s.floor === st.lower - 1 && s.x >= Math.min(w0, w1) - STAIR_PAD && s.x <= Math.max(w0, w1) + STAIR_PAD)
      return { kind: 'stairsDown', label: 'Go downstairs', dir: 'down', st };
  }

  const h = HIDES.find(h => h.floor === s.floor && s.x >= h.x0 && s.x <= h.x1);
  if (h) return { kind: 'hide', label: h.label, dir: 'down', hide: h };
  return null;
}

function doInteraction(it) {
  const s = S.santa;
  switch (it.kind) {
    case 'unhide': s.mode = 'walk'; s.hide = null; Sfx.unhide(); break;
    case 'hide': Sfx.hide(); s.mode = 'hidden'; s.hide = it.hide; s.vx = 0; s.x = (it.hide.x0 + it.hide.x1) / 2; break;
    case 'chimneyDown':
      Sfx.chimney();
      tweenSanta(CHIMNEY.x, 14, 0.35, () => {
        s.floor = 1; s.x = CHIMNEY.x; s.y = FLOOR[1] - 30;
        tweenSanta(CHIMNEY.x, FLOOR[1], 0.5, () => { s.mode = 'walk'; s.onGround = true; setCheckpoint(); });
      });
      break;
    case 'escape':
      Sfx.escape();
      tweenSanta(CHIMNEY.x, FLOOR[1] - 30, 0.5, () => {
        s.floor = 0; s.x = CHIMNEY.x; s.y = 14;
        tweenSanta(CHIMNEY.x, FLOOR[0], 0.35, () => { s.mode = 'walk'; win(); });
      });
      break;
    case 'stairsUp': {
      Sfx.creak();
      const st = it.st;
      const climb = () => {
        s.face = Math.sign(st.top - st.bottom);
        tweenSanta(st.top, FLOOR[st.lower - 1], 0.7, () => { s.floor = st.lower - 1; s.mode = 'walk'; s.onGround = true; setCheckpoint(); });
      };
      walkTo(st.bottom, FLOOR[st.lower], climb);
      break;
    }
    case 'stairsDown': {
      Sfx.creak();
      const st = it.st;
      const descend = () => {
        s.floor = st.lower;               // switch floor now so the climb renders inside the lower room
        s.face = Math.sign(st.bottom - st.top);
        tweenSanta(st.bottom, FLOOR[st.lower], 0.7, () => { s.mode = 'walk'; s.onGround = true; setCheckpoint(); });
      };
      walkTo(st.top, FLOOR[st.lower - 1], descend);
      break;
    }
    case 'deliver':
      S.delivered = true; S.score += 1000; Sfx.deliver();
      toast('Presents delivered! Now sneak back up to the chimney');
      const mia = S.npcs.find(n => n.id === 'mia');
      if (mia.state === 'asleep') {
        const run = meta.runId;
        setTimeout(() => { if (meta.runId === run && S.phase === 'play') wakeNpc(mia, 'Uh oh… someone is awake upstairs!'); }, 2600);
      }
      break;
  }
  updateHud();
}

/* ---------- update ---------- */
export function update(dt) {
  S.time += dt;
  if (S.toastT > 0 && (S.toastT -= dt) <= 0) ui.toast.hidden = true;
  if (S.phase === 'caught') { S.caughtT -= dt; if (S.caughtT <= 0) respawn(); updateNpcs(dt, false); return; }
  if (S.phase !== 'play') return;
  S.playTime += dt;

  const s = S.santa;
  s.px = s.x; s.py = s.y;
  s.inv = Math.max(0, s.inv - dt);
  s.grace = Math.max(0, s.grace - dt);

  const it = currentInteraction();
  const wantsMove = Math.abs(input.axisX()) > 0.3;

  if (it) {
    const fire = input.action || (it.dir === 'up' && input.up) || (it.dir === 'down' && input.down)
      || (it.kind === 'unhide' && (input.jump || input.up || wantsMove));
    if (fire) { doInteraction(it); input.consume(); }
  }

  if (s.mode === 'tween') {
    const tw = s.tween; tw.t += dt;
    const k = Math.min(1, tw.t / tw.dur);
    s.x = tw.x0 + (tw.x1 - tw.x0) * k; s.y = tw.y0 + (tw.y1 - tw.y0) * k;
    s.anim += dt * 8;
    if (s.floor > 0 && Math.abs(tw.x1 - tw.x0) > 4) {       // walking to or along a staircase
      s.stepAcc = (s.stepAcc || 0) + dt;
      if (s.stepAcc > 0.1) { s.stepAcc = 0; Sfx.step('floor'); }
    }
    if (k >= 1) { s.tween = null; tw.done && tw.done(); }
  } else if (s.mode === 'walk') {
    // horizontal
    const ax = input.axisX();
    const target = ax * CFG.walk;
    s.vx += (target - s.vx) * Math.min(1, CFG.friction * dt);
    if (Math.abs(ax) > 0.1) s.face = Math.sign(ax);
    s.x += s.vx * dt;
    const minX = s.floor === 0 ? 40 : HOUSE.x0 + 5, maxX = s.floor === 0 ? 280 : HOUSE.x1 - 5;
    s.x = Math.max(minX, Math.min(maxX, s.x));
    s.anim += Math.abs(s.vx) * dt * 0.18;

    // vertical
    const wasGround = s.onGround;
    if ((input.jump || input.up) && s.onGround) { s.vy = -CFG.jump; s.onGround = false; Sfx.jump(); }
    const prevY = s.y;
    s.vy += CFG.gravity * dt;
    s.y += s.vy * dt;
    s.onGround = false;
    const vyBefore = s.vy;
    if (s.vy >= 0) {
      for (const p of PLATFORMS) {
        if (p.floor === s.floor && s.x >= p.x0 && s.x <= p.x1 && prevY <= p.top && s.y >= p.top) { s.y = p.top; s.vy = 0; s.onGround = true; }
      }
    }
    if (s.y >= FLOOR[s.floor]) { s.y = FLOOR[s.floor]; s.vy = 0; s.onGround = true; }
    const ceil = ceilingOf(s.floor);
    if (s.y - 11 < ceil) { s.y = ceil + 11; s.vy = Math.max(0, s.vy); }
    if (!wasGround && s.onGround && vyBefore > 60) Sfx.land();
    if (s.onGround && Math.abs(s.vx) > 8) {
      s.stepAcc = (s.stepAcc || 0) + Math.abs(s.vx) * dt;
      if (s.stepAcc > 11) { s.stepAcc = 0; Sfx.step(s.floor === 0 ? 'roof' : 'floor'); }
    }

    // doors swing open as Santa reaches them
    for (const d of S.doors) if (!d.open && d.floor === s.floor && Math.abs(s.x - d.x) < 7) openDoor(d, 'santa');

    // pickups
    if (s.floor === 3 && !S.cookies && Math.abs(s.x - 102) < 6 && s.y <= FLOOR[3] - 13) { S.cookies = true; S.score += 300; toast('Cookies! +300', 1.6); Sfx.cookie(); updateHud(); }
    if (s.floor === MILK.floor && !S.milk && Math.abs(s.x - MILK.x) < 6) { S.milk = true; S.score += 200; toast('Milk! +200', 1.6); Sfx.milk(); updateHud(); }
  }
  input.consume();

  // reveal rooms
  const room = roomAt(s.floor, s.x);
  if (room && room.id !== S.roomId) {
    S.roomId = room.id;
    if (!S.revealed.has(room.id)) { S.revealed.add(room.id); }
  } else if (!room) S.roomId = null;

  updateNpcs(dt, true);
  S.interaction = currentInteraction();
  updatePrompt(S.interaction);
}


// Getting caught restarts the whole run: back on the roof, rooms dark again,
// presents back in the sack and the snack back on the bench.
function respawn() {
  meta.attempt++;
  newGame();
  S.phase = 'play';
  toast(`Attempt ${meta.attempt} · Walk to the chimney and press ↓`, 2.4);
}
