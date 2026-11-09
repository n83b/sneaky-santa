-- The house: floors, rooms, stairs, hiding spots, shadows and pickups,
-- plus the tuning numbers. Positions are in the game's 320x200 logical pixels
-- with y pointing DOWN (0 = top of the screen), as in the web version.
-- game.script converts to Defold's y-up world when placing sprites.

local M = {}

M.W = 320
M.H = 200
M.STEP = 1 / 60

M.WALK = 52
M.FRICTION = 12
M.GRAVITY = 520
M.JUMP = 150
M.SIGHT_RANGE = 64
M.SHADOW_SIGHT = 14
M.SUS_RISE = 1.9
M.SUS_FALL = 0.7

-- y of the walking surface on each floor: [0] roof, [1] top floor, [2] middle, [3] ground
M.FLOOR = { [0] = 34, 82, 130, 178 }

function M.ceiling(f)
	if f == 0 then return -99 end
	return M.FLOOR[f - 1] + 4
end

M.HOUSE_X0 = 16
M.HOUSE_X1 = 304

M.ROOMS = {
	{ id = "kids",    name = "Mia's room",    floor = 1, x0 = 16,  x1 = 120 },
	{ id = "hall3",   name = "Upstairs hall", floor = 1, x0 = 120, x1 = 210 },
	{ id = "attic",   name = "Attic",         floor = 1, x0 = 210, x1 = 304 },
	{ id = "bath",    name = "Bathroom",      floor = 2, x0 = 16,  x1 = 96 },
	{ id = "landing", name = "Landing",       floor = 2, x0 = 96,  x1 = 206 },
	{ id = "leo",     name = "Leo's room",    floor = 2, x0 = 206, x1 = 304 },
	{ id = "kitchen", name = "Kitchen",       floor = 3, x0 = 16,  x1 = 124 },
	{ id = "hall1",   name = "Front hall",    floor = 3, x0 = 124, x1 = 196 },
	{ id = "lounge",  name = "Lounge room",   floor = 3, x0 = 196, x1 = 304 },
}

-- A flight of stairs: `bottom` is on the lower floor, `top` on the floor above.
M.STAIRS = {
	{ lower = 2, bottom = 160, top = 204 },  -- landing -> upstairs hall (rises right)
	{ lower = 3, bottom = 176, top = 132 },  -- front hall -> landing (rises left)
}
M.STAIR_STEPS = 8
M.WELL = 18       -- width of the stairwell opening cut into the floor above
M.STAIR_PAD = 6   -- extra reach either side of a staircase

M.CHIMNEY_X = 248
M.CHIMNEY_ROOF_X0 = 238
M.CHIMNEY_ROOF_X1 = 260

M.HIDES = {
	{ floor = 1, x0 = 94,  x1 = 112, kind = "wardrobe", label = "Hide in wardrobe" },
	{ floor = 1, x0 = 268, x1 = 292, kind = "boxes",    label = "Hide behind boxes" },
	{ floor = 2, x0 = 22,  x1 = 42,  kind = "curtain",  label = "Hide behind curtain" },
	{ floor = 2, x0 = 100, x1 = 118, kind = "cupboard", label = "Hide in cupboard" },
	{ floor = 2, x0 = 214, x1 = 238, kind = "desk",     label = "Hide under desk" },
	{ floor = 3, x0 = 20,  x1 = 36,  kind = "pantry",   label = "Hide in pantry" },
	{ floor = 3, x0 = 58,  x1 = 90,  kind = "table",    label = "Hide under table" },
	{ floor = 3, x0 = 216, x1 = 250, kind = "couch",    label = "Hide behind couch" },
}

-- Height of each hiding spot's drawn object, measured up from the floor (for the highlight).
-- The curtain uses the full room height.
M.HIDE_HEIGHT = { wardrobe = 30, cupboard = 30, pantry = 31, boxes = 17, desk = 18, table = 13, couch = 15 }

-- Dark patches where the family can only see Santa up close.
M.SHADOWS = {
	{ floor = 1, x0 = 188, x1 = 210 },
	{ floor = 2, x0 = 162, x1 = 180 },
	{ floor = 3, x0 = 180, x1 = 196 },
}

-- One-way platforms Santa can jump onto: beds and the kitchen bench.
M.LEDGES = {
	{ floor = 1, x0 = 24,  x1 = 58,  top = 82 - 9 },
	{ floor = 2, x0 = 262, x1 = 298, top = 130 - 9 },
	{ floor = 3, x0 = 96,  x1 = 122, top = 178 - 14 },
}

M.TREE_FLOOR = 3
M.TREE_X = 286
M.TREE_X0 = 266

-- Cookies sit on the kitchen bench; the milk is on Mia's bedside table.
M.COOKIE_FLOOR = 3
M.COOKIE_X = 102
M.MILK_FLOOR = 1
M.MILK_X = 67

-- Seconds of each wake-up phase: still snoozing (Z's), then sitting up with "!?!?".
M.STIR_ZZ = 1.1
M.STIR_UP = 1.3

function M.room_at(floor, x)
	for _, r in ipairs(M.ROOMS) do
		if r.floor == floor and x >= r.x0 and x < r.x1 then return r end
	end
	return nil
end

function M.room_by_id(id)
	for _, r in ipairs(M.ROOMS) do
		if r.id == id then return r end
	end
	return nil
end

function M.in_shadow(floor, x)
	for _, z in ipairs(M.SHADOWS) do
		if z.floor == floor and x >= z.x0 and x <= z.x1 then return true end
	end
	return false
end

-- The opening in the upper floor slab where a flight arrives: returns start, finish.
function M.well_range(st)
	if st.top > st.bottom then
		return st.top - M.WELL, st.top
	end
	return st.top, st.top + M.WELL
end

-- Every doorway between two rooms on the same floor has a door.
function M.door_spots()
	local out = {}
	for _, r in ipairs(M.ROOMS) do
		if r.x1 < M.HOUSE_X1 then
			out[#out + 1] = { floor = r.floor, x = r.x1 }
		end
	end
	return out
end

return M
