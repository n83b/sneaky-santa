// Keyboard, touch buttons, drag stick and gamepad.
import { canvasEl } from './dom.js';
import { togglePause } from './ui.js';
import { toggleDebug } from './debug.js';

/* ---------- input: keyboard + touch stick + buttons + gamepad ---------- */
export const input = {
  keys: new Set(),
  stick: { active: false, id: null, ox: 0, oy: 0, x: 0, y: 0, vy: 0 },
  jump: false, action: false, up: false, down: false,   // edge flags, consumed by update
  pad: null,
  held: { left: false, right: false },
  axisX() {
    let x = 0;
    if (this.held.left) x -= 1;
    if (this.held.right) x += 1;
    if (this.keys.has('ArrowLeft') || this.keys.has('KeyA')) x -= 1;
    if (this.keys.has('ArrowRight') || this.keys.has('KeyD')) x += 1;
    if (this.stick.active) x += Math.max(-1, Math.min(1, (this.stick.x - this.stick.ox) / 40));
    if (padState.x) x += padState.x;
    return Math.max(-1, Math.min(1, x));
  },
  consume() { this.jump = this.action = this.up = this.down = false; },
};

window.addEventListener('keydown', e => {
  if (!e.repeat) {
    if (e.code === 'Space' || e.code === 'KeyZ') input.jump = true;
    if (e.code === 'KeyE' || e.code === 'Enter' || e.code === 'KeyX') input.action = true;
    if (e.code === 'ArrowUp' || e.code === 'KeyW') input.up = true;
    if (e.code === 'ArrowDown' || e.code === 'KeyS') input.down = true;
    if (e.code === 'KeyP' || e.code === 'Escape') togglePause();
    if (e.code === 'Backquote') toggleDebug();
  }
  input.keys.add(e.code);
  if (e.code.startsWith('Arrow') || e.code === 'Space') e.preventDefault();
});
window.addEventListener('keyup', e => input.keys.delete(e.code));
window.addEventListener('blur', () => input.keys.clear());

canvasEl.addEventListener('pointerdown', e => {
  if (input.stick.active || e.clientX > innerWidth * 0.55) return;
  canvasEl.setPointerCapture(e.pointerId);
  Object.assign(input.stick, { active: true, id: e.pointerId, ox: e.clientX, oy: e.clientY, x: e.clientX, y: e.clientY, vy: 0 });
});
canvasEl.addEventListener('pointermove', e => {
  const s = input.stick;
  if (e.pointerId !== s.id) return;
  s.x = e.clientX; s.y = e.clientY;
  const dy = s.y - s.oy;
  // Vertical flick on the stick = up / down (stairs, hiding)
  if (dy < -34 && s.vy !== -1) { input.up = true; s.vy = -1; }
  else if (dy > 34 && s.vy !== 1) { input.down = true; s.vy = 1; }
  else if (Math.abs(dy) < 16) s.vy = 0;
});
const endStick = e => { if (e.pointerId === input.stick.id) { input.stick.active = false; input.stick.id = null; } };
canvasEl.addEventListener('pointerup', endStick);
canvasEl.addEventListener('pointercancel', endStick);

function bindButton(el, flag) {
  el.addEventListener('pointerdown', e => { e.preventDefault(); input[flag] = true; el.classList.add('active'); });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach(t => el.addEventListener(t, () => el.classList.remove('active')));
}
bindButton(document.getElementById('btnJump'), 'jump');

// Hold-to-walk arrow buttons
function bindHold(el, dir) {
  const on = e => { e.preventDefault(); try { el.setPointerCapture(e.pointerId); } catch (_) {} input.held[dir] = true; el.classList.add('active'); };
  const off = () => { input.held[dir] = false; el.classList.remove('active'); };
  el.addEventListener('pointerdown', on);
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(t => el.addEventListener(t, off));
  el.addEventListener('contextmenu', e => e.preventDefault());
}
bindHold(document.getElementById('btnLeft'), 'left');
bindHold(document.getElementById('btnRight'), 'right');
window.addEventListener('blur', () => { input.held.left = input.held.right = false; });
bindButton(document.getElementById('btnAction'), 'action');

const padState = { x: 0, held: {} };
export function pollGamepad() {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  const gp = [...pads].find(p => p && p.connected);
  input.pad = gp ? gp.id : null;
  padState.x = 0;
  if (!gp) return;
  const ax = Math.abs(gp.axes[0] || 0) < 0.25 ? 0 : gp.axes[0];
  const ay = Math.abs(gp.axes[1] || 0) < 0.6 ? 0 : gp.axes[1];
  padState.x = ax + (gp.buttons[15]?.pressed ? 1 : 0) - (gp.buttons[14]?.pressed ? 1 : 0);
  const edge = (name, pressed, flag) => { if (pressed && !padState.held[name]) input[flag] = true; padState.held[name] = pressed; };
  edge('a', !!gp.buttons[0]?.pressed, 'jump');
  edge('b', !!(gp.buttons[1]?.pressed || gp.buttons[2]?.pressed), 'action');
  edge('up', !!(gp.buttons[12]?.pressed || ay < 0), 'up');
  edge('down', !!(gp.buttons[13]?.pressed || ay > 0), 'down');
}
