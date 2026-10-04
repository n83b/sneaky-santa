// Sound effects synthesised live with the Web Audio API (no audio files).

/* ---------- sound: Web Audio synth effects (no audio files) ---------- */
export const Sfx = (() => {
  let ctx = null, master = null, noiseBuf = null, muted = false, stepFlip = false;
  try { muted = localStorage.getItem('sns-muted') === '1'; } catch (e) {}

  function unlock() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    if (!ctx) {
      ctx = new AC();
      master = ctx.createGain(); master.gain.value = muted ? 0 : 0.6; master.connect(ctx.destination);
      noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
      const d = noiseBuf.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    if (ctx.state !== 'running') ctx.resume().catch(() => {});
  }
  const ready = () => ctx && ctx.state === 'running' && !muted;

  function env(g, t, vol, attack, dur) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  }
  function tone({ type = 'sine', f0, f1 = f0, dur = 0.1, vol = 0.2, at = 0, attack = 0.005 }) {
    if (!ready()) return;
    const t = ctx.currentTime + at, o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(f0, t);
    if (f1 !== f0) o.frequency.exponentialRampToValueAtTime(f1, t + dur);
    env(g, t, vol, attack, dur);
    o.connect(g).connect(master); o.start(t); o.stop(t + dur + 0.02);
  }
  function noise({ dur = 0.1, vol = 0.2, f0 = 1000, f1 = f0, q = 1, filter = 'bandpass', at = 0, attack = 0.004 }) {
    if (!ready()) return;
    const t = ctx.currentTime + at, src = ctx.createBufferSource(), bq = ctx.createBiquadFilter(), g = ctx.createGain();
    src.buffer = noiseBuf; src.loop = true;
    bq.type = filter; bq.Q.value = q;
    bq.frequency.setValueAtTime(f0, t);
    if (f1 !== f0) bq.frequency.exponentialRampToValueAtTime(f1, t + dur);
    env(g, t, vol, attack, dur);
    src.connect(bq).connect(g).connect(master);
    src.start(t, Math.random() * 0.8); src.stop(t + dur + 0.02);
  }
  const note = n => 440 * Math.pow(2, (n - 69) / 12);   // MIDI note → Hz
  function bell(n, at, vol = 0.12, dur = 0.5) {
    tone({ type: 'sine', f0: note(n), dur, vol, at });
    tone({ type: 'sine', f0: note(n) * 2.01, dur: dur * 0.5, vol: vol * 0.3, at });
  }

  return {
    unlock,
    get muted() { return muted; },
    setMuted(m) {
      muted = m;
      try { localStorage.setItem('sns-muted', m ? '1' : '0'); } catch (e) {}
      if (master) master.gain.value = m ? 0 : 0.6;
    },
    step(surface) {
      stepFlip = !stepFlip;
      const p = stepFlip ? 1 : 0.85;
      if (surface === 'roof') noise({ dur: 0.05, vol: 0.10, f0: 2400 * p, q: 2 });           // tiles: clicky
      else noise({ dur: 0.06, vol: 0.13, f0: 420 * p, f1: 260 * p, q: 1.2 });                // carpet/boards: soft
      tone({ type: 'triangle', f0: 95 * p, f1: 60, dur: 0.05, vol: 0.06 });
    },
    jump() { tone({ type: 'triangle', f0: 300, f1: 620, dur: 0.13, vol: 0.10 }); noise({ dur: 0.08, vol: 0.05, f0: 1500, q: 0.8 }); },
    land() { noise({ dur: 0.08, vol: 0.16, f0: 500, f1: 200, filter: 'lowpass' }); tone({ type: 'sine', f0: 130, f1: 55, dur: 0.09, vol: 0.14 }); },
    hide() {
      noise({ dur: 0.28, vol: 0.12, f0: 2200, f1: 600, q: 0.9, attack: 0.03 });              // rustle in
      tone({ type: 'square', f0: 220, dur: 0.03, vol: 0.04, at: 0.22 });                       // little click shut
    },
    unhide() { noise({ dur: 0.22, vol: 0.11, f0: 600, f1: 2200, q: 0.9, attack: 0.02 }); },
    creak() { tone({ type: 'sawtooth', f0: 190, f1: 150, dur: 0.18, vol: 0.025, attack: 0.04 }); },
    door(soft) {
      const v = soft ? 0.5 : 1;
      tone({ type: 'square', f0: 900, f1: 600, dur: 0.03, vol: 0.05 * v });                          // latch
      tone({ type: 'sawtooth', f0: 150, f1: 260, dur: 0.42, vol: 0.03 * v, attack: 0.08, at: 0.04 }); // creak open
      tone({ type: 'sawtooth', f0: 230, f1: 200, dur: 0.18, vol: 0.02 * v, attack: 0.03, at: 0.4 });
    },
    chimney() {
      noise({ dur: 0.85, vol: 0.16, f0: 1600, f1: 180, q: 0.7, attack: 0.05 });
      tone({ type: 'triangle', f0: 700, f1: 140, dur: 0.75, vol: 0.06 });
      noise({ dur: 0.12, vol: 0.18, f0: 300, f1: 120, filter: 'lowpass', at: 0.82 });       // soot-puff landing
    },
    escape() {
      noise({ dur: 0.8, vol: 0.15, f0: 180, f1: 1800, q: 0.7, attack: 0.05 });
      tone({ type: 'triangle', f0: 160, f1: 820, dur: 0.75, vol: 0.06 });
    },
    deliver() {
      [84, 88, 91, 96].forEach((n, i) => bell(n, i * 0.09, 0.11, 0.6));
      for (let i = 0; i < 4; i++) noise({ dur: 0.06, vol: 0.05, f0: 7000, filter: 'highpass', at: 0.05 + i * 0.1 }); // sleigh-bell shimmer
    },
    cookie() { for (let i = 0; i < 3; i++) noise({ dur: 0.05, vol: 0.14, f0: 2600 - i * 300, q: 1.5, at: i * 0.09 }); },
    milk() { [0, 0.16].forEach(at => tone({ type: 'sine', f0: 320, f1: 190, dur: 0.12, vol: 0.12, at })); },
    notice() { tone({ type: 'sine', f0: 720, f1: 960, dur: 0.09, vol: 0.06 }); },
    caught() {
      tone({ type: 'triangle', f0: note(72), dur: 0.16, vol: 0.14 });
      tone({ type: 'triangle', f0: note(67), dur: 0.3, vol: 0.14, at: 0.18 });
    },
    wake() { tone({ type: 'sine', f0: 260, f1: 420, dur: 0.35, vol: 0.06, attack: 0.08 }); tone({ type: 'sine', f0: 420, f1: 240, dur: 0.4, vol: 0.05, at: 0.35 }); },
    win() {
      // Jingle Bells opening phrase (public domain)
      const seq = [[76, 1], [76, 1], [76, 2], [76, 1], [76, 1], [76, 2], [76, 1], [79, 1], [72, 1.5], [74, 0.5], [76, 4]];
      let t = 0.1; for (const [n, len] of seq) { bell(n, t, 0.12, Math.min(0.6, len * 0.22)); t += len * 0.16; }
    },
    lose() { [67, 63, 60].forEach((n, i) => tone({ type: 'triangle', f0: note(n), dur: 0.3, vol: 0.12, at: i * 0.22 })); },
  };
})();

const btnSound = document.getElementById('btnSound');
function syncSoundBtn() { btnSound.setAttribute('aria-pressed', String(!Sfx.muted)); btnSound.textContent = Sfx.muted ? 'Muted' : 'Sound'; }
btnSound.addEventListener('click', () => { Sfx.unlock(); Sfx.setMuted(!Sfx.muted); syncSoundBtn(); });
syncSoundBtn();
// iPadOS can suspend audio when the app is backgrounded; resume on the next touch.
addEventListener('pointerdown', () => Sfx.unlock(), { passive: true });
