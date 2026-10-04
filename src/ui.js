// HUD, prompts, toasts, start/end screens, pause and fullscreen.
import { Sfx } from './audio.js';
import { meta, newGame, S } from './state.js';
import { resize } from './render.js';

/* ---------- ui ---------- */
export const ui = {
  score: document.getElementById('score'),
  objective: document.getElementById('objective'),
  chances: document.getElementById('chances'),
  prompt: document.getElementById('prompt'),
  toast: document.getElementById('toast'),
  actionLbl: document.getElementById('actionLbl'),
  start: document.getElementById('startScreen'),
  end: document.getElementById('endScreen'),
};

export function toast(msg, secs = 2.2) { S.toast = msg; S.toastT = secs; ui.toast.textContent = msg; ui.toast.hidden = false; }

export function updateHud() {
  ui.score.textContent = S.score.toLocaleString('en-AU');
  ui.chances.textContent = `ATTEMPT ${meta.attempt}`;
  let obj = 'Slide down the chimney';
  if (S.santa.floor > 0 || S.revealed.size) obj = S.delivered ? 'Get back up the chimney' : 'Find the Christmas tree';
  ui.objective.textContent = obj + (S.cookies && S.milk ? ' · snack found' : '');
}

let lastPrompt = '';
export function updatePrompt(it) {
  const label = it ? it.label : '';
  if (label === lastPrompt) return;
  lastPrompt = label;
  ui.prompt.hidden = !it;
  if (it) {
    const key = it.dir === 'up' ? '↑ / E' : it.dir === 'down' ? '↓ / E' : 'E';
    ui.prompt.innerHTML = `${escapeHtml(label)}<kbd>${key}</kbd>`;
  }
  ui.actionLbl.textContent = it ? label.split(' ')[0].toUpperCase() : 'ACTION';
}

export function win() {
  S.phase = 'won';
  Sfx.win();
  const timeBonus = Math.max(0, Math.round(1500 - S.playTime * 8));
  const rows = [
    ['Presents delivered', 1000],
    ['Back up the chimney', 1000],
    ['Cookies', S.cookies ? 300 : 0],
    ['Milk', S.milk ? 200 : 0],
    [`Time bonus (${Math.round(S.playTime)}s)`, timeBonus],
    [meta.attempt === 1 ? 'First try bonus' : `Attempts: ${meta.attempt}`, meta.attempt === 1 ? 750 : 0],
  ];
  const total = rows.reduce((a, r) => a + r[1], 0);
  S.score = total;
  let best = 0;
  try { best = +localStorage.getItem('sns-best') || 0; if (total > best) localStorage.setItem('sns-best', total); } catch (e) {}
  document.getElementById('endTitle').textContent = 'Merry Christmas!';
  document.getElementById('endText').textContent = total > best && best > 0 ? 'New best score!' : 'Nobody saw a thing. Ho ho ho.';
  document.getElementById('endTable').innerHTML =
    rows.map(r => `<tr><td>${escapeHtml(r[0])}</td><td>${r[1].toLocaleString('en-AU')}</td></tr>`).join('') +
    `<tr class="total"><td>Total</td><td>${total.toLocaleString('en-AU')}</td></tr>` +
    (best ? `<tr><td>Best</td><td>${Math.max(best, total).toLocaleString('en-AU')}</td></tr>` : '');
  ui.end.hidden = false; ui.prompt.hidden = true; lastPrompt = '';
  updateHud();
}

function gameOver() {
  S.phase = 'over';
  Sfx.lose();
  document.getElementById('endTitle').textContent = 'Caught on Christmas Eve!';
  document.getElementById('endText').textContent = S.delivered
    ? 'The presents made it under the tree, but Santa got spotted on the way out.'
    : 'The family spotted Santa too many times. Try hiding and waiting for them to pass.';
  document.getElementById('endTable').innerHTML = `<tr><td>Score</td><td>${S.score.toLocaleString('en-AU')}</td></tr>`;
  ui.end.hidden = false; ui.prompt.hidden = true; lastPrompt = '';
}

function startGame() {
  Sfx.unlock();
  meta.attempt = 1;
  newGame();
  S.phase = 'play';
  ui.start.hidden = true; ui.end.hidden = true;
  toast('Walk to the chimney and press ↓', 2.6);
}
document.getElementById('btnStart').addEventListener('click', startGame);
document.getElementById('btnAgain').addEventListener('click', startGame);

const btnPause = document.getElementById('btnPause');
export function togglePause(force) {
  if (!S.phase || (S.phase !== 'play' && S.phase !== 'paused')) return;
  const p = typeof force === 'boolean' ? force : S.phase !== 'paused';
  S.phase = p ? 'paused' : 'play';
  btnPause.textContent = p ? 'Resume' : 'Pause';
  btnPause.setAttribute('aria-pressed', String(p));
  if (p) toast('Paused', 999); else ui.toast.hidden = true;
}
btnPause.addEventListener('click', () => togglePause());
document.addEventListener('visibilitychange', () => { if (document.hidden) togglePause(true); });

/* ---------- fullscreen (iPad Safari + desktop; hidden where unsupported) ---------- */
const btnFull = document.getElementById('btnFull');
const fsEl = () => document.fullscreenElement || document.webkitFullscreenElement;
const fsOn = !!(document.fullscreenEnabled || document.webkitFullscreenEnabled)
  && !(navigator.standalone || matchMedia('(display-mode: standalone)').matches);
btnFull.hidden = !fsOn;
btnFull.addEventListener('click', () => {
  const root = document.documentElement;
  try {
    if (fsEl()) (document.exitFullscreen || document.webkitExitFullscreen).call(document);
    else {
      const req = root.requestFullscreen || root.webkitRequestFullscreen;
      const r = req && req.call(root);
      if (r && r.catch) r.catch(() => toast('Fullscreen isn’t available here', 1.8));
    }
  } catch (e) { toast('Fullscreen isn’t available here', 1.8); }
});
['fullscreenchange', 'webkitfullscreenchange'].forEach(ev => document.addEventListener(ev, () => {
  btnFull.textContent = fsEl() ? 'Exit full' : 'Fullscreen';
  resize();
}));

export function escapeHtml(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
