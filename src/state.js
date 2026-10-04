// Game state and starting a fresh run.
import { FLOOR, HOUSE, ROOMS } from './level.js';
import { ADULT_PAL, bake, KID_PAL, SPR } from './sprites.js';
import { updateHud } from './ui.js';

/* ---------- state ---------- */
// Whole game state. It is reset in place by newGame() so every module can hold a reference to it.
export const S = {};
// Survives restarts: attempt counter and a run id (lets delayed events notice a restart).
export const meta = { attempt: 1, runId: 0 };

function makeNpc(o) {
  return Object.assign({ dir: 1, speed: 20, state: 'walk', waitT: 0, sus: 0, anim: 0, ht: 9 }, o);
}

export function newGame() {
  for (const k of Object.keys(S)) delete S[k];
  meta.runId++;
  Object.assign(S, {
    phase: 'title',        // title | play | paused | caught | won | over
    time: 0, playTime: 0, score: 0,
    delivered: false, cookies: false, milk: false, escaped: false,
    revealed: new Set(),
    roomId: null,
    toastT: 0,
    santa: { floor: 0, x: 60, y: FLOOR[0], px: 60, py: FLOOR[0], vx: 0, vy: 0, face: 1, onGround: true,
             mode: 'walk', anim: 0, hide: null, tween: null, inv: 0, grace: 0 },
    checkpoint: { floor: 0, x: 60 },
    // A door sits in every doorway between two rooms on the same floor
    doors: ROOMS.filter(r => r.x1 < HOUSE.x1).map(r => ({ floor: r.floor, x: r.x1, open: false, anim: 0, side: 1 })),
    npcs: [
      makeNpc({ id: 'mia', name: 'Mia', floor: 1, x: 41, range: [40, 170], speed: 17, pause: 2.4,
                state: 'asleep', room: 'kids', wakeX: 46, img: SPR.kid.map(m => bake(m, KID_PAL('#e8c25a', '#e58fb1'))), ht: 9 }),
      makeNpc({ id: 'leo', name: 'Leo', floor: 2, x: 250, dir: -1, range: [30, 292], speed: 21, pause: 2.6,
                img: SPR.kid.map(m => bake(m, KID_PAL('#6b4a2e', '#5b8fd9'))), ht: 9 }),
      makeNpc({ id: 'dad', name: 'Dad', floor: 3, x: 70, dir: 1, range: [40, 262], speed: 18, pause: 3.2,
                img: SPR.adult.map(m => bake(m, ADULT_PAL('#3a2a22', '#4f7a5a'))), ht: 14 }),
    ],
  });
  S.santa.mode = 'walk';
  updateHud();
}
