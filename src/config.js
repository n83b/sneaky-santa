// Logical resolution, timestep and tuning numbers.

/* ---------- config ---------- */
export const W = 320, H = 200;                 // logical resolution
export const STEP = 1 / 60;
export const CFG = {
  walk: 52, accel: 600, friction: 12,
  gravity: 520, jump: 150,
  sightRange: 64, shadowSight: 14,
  susRise: 1.9, susFall: 0.7,
};
