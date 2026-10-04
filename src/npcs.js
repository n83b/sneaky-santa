// Doors, sleepers waking up, family patrols and spotting Santa.
import { CFG } from './config.js';
import { inShadow, roomAt } from './level.js';
import { Sfx } from './audio.js';
import { S } from './state.js';
import { toast, updateHud } from './ui.js';

/* ---------- doors & sleepers ---------- */
export const doorBetween = (floor, a, b) =>
  S.doors.some(d => d.floor === floor && !d.open && d.x > Math.min(a, b) && d.x < Math.max(a, b));

export function wakeNpc(n, msg) {
  if (n.state !== 'asleep') return;
  // Wake-up sequence: still snoozing with Z's, then sits up with "!?!?", then gets up
  n.state = 'stir'; n.stirPhase = 'zz'; n.stirT = STIR.zz + STIR.up; n.sus = 0;
  toast(msg || `${n.name} is waking up!`, 2.2);
}

const STIR = { zz: 1.1, up: 1.3 };   // seconds of each wake-up phase

export function openDoor(d, by) {
  d.open = true; d.anim = 0;
  if (by === 'santa') {
    const s = S.santa;
    d.side = s.x < d.x ? 1 : -1;
    Sfx.door(false);
    const room = roomAt(d.floor, d.x + d.side * 4);
    if (room) {
      S.revealed.add(room.id);
      S.npcs.filter(n => n.state === 'asleep' && n.room === room.id)
        .forEach(n => wakeNpc(n, `The door creaked… ${n.name} is waking up!`));
    }
  } else {
    d.side = by.dir;
    if (by.floor === S.santa.floor) Sfx.door(true);
  }
}

export function updateNpcs(dt, detect) {
  const s = S.santa;
  for (const d of S.doors) if (d.open && d.anim < 1) d.anim = Math.min(1, d.anim + dt / 0.35);
  for (const n of S.npcs) {
    if (n.state === 'asleep') continue;
    if (n.state === 'stir') {
      n.stirT -= dt;
      if (n.stirPhase === 'zz' && n.stirT <= STIR.up) { n.stirPhase = 'up'; Sfx.wake(); }
      if (n.stirT <= 0) { n.state = 'walk'; n.x = n.wakeX ?? n.x; n.dir = 1; }
      continue;
    }
    if (n.state === 'walk') {
      const nx = n.x + n.dir * n.speed * dt;
      for (const d of S.doors) if (!d.open && d.floor === n.floor && (d.x - n.x) * (d.x - nx) <= 0) openDoor(d, n);
      n.x = nx; n.anim += dt * 5;
      if ((n.dir > 0 && n.x >= n.range[1]) || (n.dir < 0 && n.x <= n.range[0])) {
        n.x = Math.max(n.range[0], Math.min(n.range[1], n.x)); n.state = 'wait'; n.waitT = n.pause;
      }
    } else if (n.state === 'wait') {
      n.waitT -= dt;
      if (n.waitT <= 0) { n.dir *= -1; n.state = 'walk'; }
    }
    if (!detect) continue;

    // vision
    let sees = false;
    if (n.floor === s.floor && s.mode !== 'hidden' && s.mode !== 'tween' && s.inv === 0 && s.grace === 0) {
      const dx = s.x - n.x;
      const range = inShadow(s.floor, s.x) ? CFG.shadowSight : CFG.sightRange;
      if (((dx * n.dir > 0 && Math.abs(dx) < range) || Math.abs(dx) < 5) && !doorBetween(n.floor, n.x, s.x)) sees = true;
    }
    const wasSus = n.sus;
    n.sus = sees ? n.sus + CFG.susRise * dt : Math.max(0, n.sus - CFG.susFall * dt);
    if (wasSus === 0 && n.sus > 0) Sfx.notice();
    if (n.sus >= 1) { caught(n); return; }
  }
}

export function caught(n) {
  S.phase = 'caught'; S.caughtT = 1.8; S.caughtBy = n;
  n.state = 'wait'; n.waitT = 2;
  Sfx.caught();
  toast(`${n.name} spotted Santa! Back to the roof…`, 1.8);
  updateHud();
}
