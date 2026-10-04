// Entry point: fixed-timestep game loop.
// ui.js and audio.js also wire up their buttons when imported.
import './ui.js';
import './audio.js';
import { STEP } from './config.js';
import { newGame, S } from './state.js';
import { pollGamepad } from './input.js';
import { update } from './game.js';
import { render, resize } from './render.js';
import { drawDebug } from './debug.js';

/* ---------- loop: fixed timestep + interpolation ---------- */
newGame();
resize();
let last = performance.now(), acc = 0;
function frame(now) {
  const dt = Math.min((now - last) / 1000, 0.25); last = now;
  pollGamepad();
  if (S.phase !== 'paused') {
    acc += dt;
    while (acc >= STEP) { update(STEP); acc -= STEP; }
  }
  render(S.phase === 'play' ? acc / STEP : 1);
  drawDebug(dt);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
