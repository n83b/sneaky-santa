// The house: floors, rooms, stairs, hiding spots, shadows and pickups.

/* ---------- level data ----------
   Floors: 0 = roof, 1 = top floor, 2 = middle, 3 = ground.
   FLOOR[i] is the y of the walking surface on that floor. */
export const FLOOR = [34, 82, 130, 178];
export const ceilingOf = f => f === 0 ? -99 : FLOOR[f - 1] + 4;
export const HOUSE = { x0: 16, x1: 304 };

export const ROOMS = [
  { id: 'kids',    name: "Mia's room",     floor: 1, x0: 16,  x1: 120, wall: '#2e2a4a' },
  { id: 'hall3',   name: 'Upstairs hall',  floor: 1, x0: 120, x1: 210, wall: '#283350' },
  { id: 'attic',   name: 'Attic',          floor: 1, x0: 210, x1: 304, wall: '#33293a' },
  { id: 'bath',    name: 'Bathroom',       floor: 2, x0: 16,  x1: 96,  wall: '#24404a' },
  { id: 'landing', name: 'Landing',        floor: 2, x0: 96,  x1: 206, wall: '#283350' },
  { id: 'leo',     name: "Leo's room",     floor: 2, x0: 206, x1: 304, wall: '#253a35' },
  { id: 'kitchen', name: 'Kitchen',        floor: 3, x0: 16,  x1: 124, wall: '#3a3528' },
  { id: 'hall1',   name: 'Front hall',     floor: 3, x0: 124, x1: 196, wall: '#283350' },
  { id: 'lounge',  name: 'Lounge room',    floor: 3, x0: 196, x1: 304, wall: '#3a2a2e' },
];

// Stairs: bottom point on the lower floor, top point on the floor above.
export const STAIRS = [
  { lower: 2, bottom: 160, top: 204 },   // landing → upstairs hall (rises right)
  { lower: 3, bottom: 176, top: 132 },   // front hall → landing (rises left)
];
export const STAIR_STEPS = 8;
const WELL = 18;         // width of the stairwell opening cut into the floor above
export const STAIR_PAD = 6;     // extra reach either side of a staircase

export const CHIMNEY = { x: 248, roofX0: 238, roofX1: 260 };

export const HIDES = [
  { floor: 1, x0: 94,  x1: 112, kind: 'wardrobe', label: 'Hide in wardrobe' },
  { floor: 1, x0: 268, x1: 292, kind: 'boxes',    label: 'Hide behind boxes' },
  { floor: 2, x0: 22,  x1: 42,  kind: 'curtain',  label: 'Hide behind curtain' },
  { floor: 2, x0: 100, x1: 118, kind: 'cupboard', label: 'Hide in cupboard' },
  { floor: 2, x0: 214, x1: 238, kind: 'desk',     label: 'Hide under desk' },
  { floor: 3, x0: 20,  x1: 36,  kind: 'pantry',   label: 'Hide in pantry' },
  { floor: 3, x0: 58,  x1: 90,  kind: 'table',    label: 'Hide under table' },
  { floor: 3, x0: 216, x1: 250, kind: 'couch',    label: 'Hide behind couch' },
];

export const SHADOWS = [
  { floor: 1, x0: 188, x1: 210 },
  { floor: 2, x0: 162, x1: 180 },
  { floor: 3, x0: 180, x1: 196 },
];

// One-way platforms (stand on top)
export const PLATFORMS = [
  { floor: 1, x0: 24, x1: 58,  top: FLOOR[1] - 9 },   // Mia's bed
  { floor: 2, x0: 262, x1: 298, top: FLOOR[2] - 9 },  // Leo's bed
  { floor: 3, x0: 96, x1: 122, top: FLOOR[3] - 14 },  // kitchen bench
];

export const TREE = { floor: 3, x: 286, x0: 266, x1: 304 };
export const MILK = { floor: 1, x: 67 };      // on Mia's bedside table (cookies are on the kitchen bench)

/* ---------- level helpers ---------- */
export const roomAt = (floor, x) => ROOMS.find(r => r.floor === floor && x >= r.x0 && x < r.x1) || null;
export const inShadow = (floor, x) => SHADOWS.some(z => z.floor === floor && x >= z.x0 && x <= z.x1);
export const topOf = f => ceilingOf(f);

// Opening in the upper floor slab where a flight arrives
export function wellRange(st) {
  const dir = Math.sign(st.top - st.bottom);
  return dir > 0 ? [st.top - WELL, st.top] : [st.top, st.top + WELL];
}
