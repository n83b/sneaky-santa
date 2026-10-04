// Pixel sprites drawn from character maps and baked to small canvases.

/* ---------- sprites ---------- */
const PAL = {
  r: '#d8433b', w: '#f4f1ea', f: '#f0b48c', e: '#1a1420', k: '#1d1a24', g: '#f3c35a',
  s: '#7a4a2c',
};
export const SPR = {
  santa: [[
    '...rrr..',
    '..rrrrrw',
    '.wwwwww.',
    '.ffefef.',
    '.wwwwww.',
    'rrwwwwrr',
    'rrrrrrrr',
    'rkkgkkkr',
    '.rrrrrr.',
    '.kk..kk.',
    '.kk..kk.',
  ], [
    '...rrr..',
    '..rrrrrw',
    '.wwwwww.',
    '.ffefef.',
    '.wwwwww.',
    'rrwwwwrr',
    'rrrrrrrr',
    'rkkgkkkr',
    '.rrrrrr.',
    '..kkkk..',
    '..kkkk..',
  ]],
  kid: [[
    '.hhhh.',
    '.hfff.',
    '.ffef.',
    'pppppp',
    'pppppp',
    '.pppp.',
    '.pppp.',
    '.p..p.',
    '.s..s.',
  ], [
    '.hhhh.',
    '.hfff.',
    '.ffef.',
    'pppppp',
    'pppppp',
    '.pppp.',
    '.pppp.',
    '..pp..',
    '..ss..',
  ]],
  adult: [[
    '..hhh..',
    '.hhhhh.',
    '.fffef.',
    '.fffff.',
    '..fff..',
    '.ggggg.',
    'ggggggg',
    'gggyggg',
    '.ggggg.',
    '.ggggg.',
    '.ggggg.',
    '..f.f..',
    '..f.f..',
    '.ss.ss.',
  ], [
    '..hhh..',
    '.hhhhh.',
    '.fffef.',
    '.fffff.',
    '..fff..',
    '.ggggg.',
    'ggggggg',
    'gggyggg',
    '.ggggg.',
    '.ggggg.',
    '.ggggg.',
    '...f...',
    '..ff...',
    '..sss..',
  ]],
};
const GLYPH = {
  '?': ['ooo', '..o', '.oo', '...', '.o.'],
  'up': ['.o.', 'ooo', 'o.o'],
  'dn': ['o.o', 'ooo', '.o.'],
  '!': ['o', 'o', 'o', '.', 'o'],
  'Z': ['ooo', '.o.', 'ooo'],
};

// Pre-render sprites (both facings) to small canvases.
export function bake(map, pal) {
  const h = map.length, w = map[0].length;
  const make = flip => {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const x = c.getContext('2d');
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const ch = map[j][i]; if (ch === '.') continue;
      x.fillStyle = pal[ch] || '#f0f'; x.fillRect(flip ? w - 1 - i : i, j, 1, 1);
    }
    return c;
  };
  return { r: make(false), l: make(true), w, h };
}
export const SANTA_IMG = SPR.santa.map(m => bake(m, PAL));
export const KID_PAL = (hair, pj) => ({ ...PAL, h: hair, p: pj, s: '#c9c3d6' });
export const ADULT_PAL = (hair, gown) => ({ ...PAL, h: hair, g: gown, y: '#e8d9a8', s: '#5a3a2a' });
function glyphCanvas(map, color) {
  const c = document.createElement('canvas'); c.width = map[0].length; c.height = map.length;
  const x = c.getContext('2d'); x.fillStyle = color;
  map.forEach((row, j) => [...row].forEach((ch, i) => { if (ch === 'o') x.fillRect(i, j, 1, 1); }));
  return c;
}
export const G = {
  q: glyphCanvas(GLYPH['?'], '#f3c35a'),
  ex: glyphCanvas(GLYPH['!'], '#ff6a5c'),
  z: glyphCanvas(GLYPH['Z'], '#a9b8ff'),
  up: glyphCanvas(GLYPH['up'], '#f3c35a'),
  dn: glyphCanvas(GLYPH['dn'], '#f3c35a'),
};
