// On-screen debug overlay (toggle with the Debug button or ` key).
import { S } from './state.js';
import { input } from './input.js';
import { view } from './render.js';
import { escapeHtml } from './ui.js';

/* ---------- debug overlay ---------- */
const debugEl = document.getElementById('debug');
const btnDebug = document.getElementById('btnDebug');
const errors = [];
let debugOn = false;
addEventListener('error', e => errors.push(`${e.message} (:${e.lineno})`));
addEventListener('unhandledrejection', e => errors.push(`Promise: ${e.reason}`));
export function toggleDebug() { debugOn = !debugOn; debugEl.hidden = !debugOn; btnDebug.setAttribute('aria-pressed', String(debugOn)); }
btnDebug.addEventListener('click', toggleDebug);

const fps = { n: 0, acc: 0, v: 0 };
export function drawDebug(dt) {
  fps.n++; fps.acc += dt; if (fps.acc >= .5) { fps.v = Math.round(fps.n / fps.acc); fps.n = fps.acc = 0; }
  if (!debugOn) return;
  const s = S.santa;
  const lines = [
    `fps     ${fps.v}`, `phase   ${S.phase}`, `santa   f${s.floor} x${s.x.toFixed(0)} y${s.y.toFixed(0)} ${s.mode}`,
    `room    ${S.roomId || '—'}`, `scale   ${view.scale.toFixed(2)}x`,
    ...S.npcs.map(n => `${n.id.padEnd(7)} f${n.floor} x${n.x.toFixed(0)} ${n.state} sus ${n.sus.toFixed(2)}`),
    `gamepad ${input.pad ? input.pad.slice(0, 24) : '—'}`,
  ].join('\n');
  debugEl.innerHTML = escapeHtml(lines) + (errors.length ? `\n<span class="err">${errors.slice(-3).map(escapeHtml).join('\n')}</span>` : '');
}
