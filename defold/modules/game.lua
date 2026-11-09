-- Sneaky Santa rules: game state, Santa's movement, stairs, hiding, interactions,
-- doors, the family's patrols and getting spotted, and scoring.
--
-- Plain Lua with no Defold calls, so the rules live in one place and can be tested
-- outside the engine. game.script owns a game, feeds it input, calls update() at a
-- fixed 60 Hz and then mirrors the state onto sprites.
--
-- Sounds are requested through the `sound` callback passed to new(): sound(name, gain).

local level = require "modules.level"

local FLOOR = level.FLOOR

local M = {}

local Game = {}
Game.__index = Game

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function round(v)
	return math.floor(v + 0.5)
end

local function new_santa()
	return {
		floor = 0,
		x = 60, y = FLOOR[0],
		px = 60, py = FLOOR[0],
		vx = 0, vy = 0,
		face = 1,
		on_ground = true,
		mode = "walk",      -- walk | tween | hidden
		anim = 0,
		hide = nil,
		tween = nil,
		grace = 0,          -- short moment after arriving on a floor when nobody can spot Santa
		step_acc = 0,
	}
end

local function new_family()
	return {
		{ id = "mia", name = "Mia", floor = 1, x = 41, dir = 1, lo = 40, hi = 170, speed = 17, pause = 2.4,
		  state = "asleep", room = "kids", wake_x = 46, height = 9 },
		{ id = "leo", name = "Leo", floor = 2, x = 250, dir = -1, lo = 30, hi = 292, speed = 21, pause = 2.6,
		  state = "walk", height = 9 },
		{ id = "dad", name = "Dad", floor = 3, x = 70, dir = 1, lo = 40, hi = 262, speed = 18, pause = 3.2,
		  state = "walk", height = 14 },
	}
end

function M.new(sound)
	local g = setmetatable({}, Game)
	g.sound = sound or function() end
	g.attempt = 1
	g.best = 0
	g:reset_run()
	return g
end

function Game:sfx(name, gain)
	self.sound(name, gain or 1)
end

-- ---------------------------------------------------------------- runs

function Game:reset_run()
	self.phase = "title"   -- title | play | paused | caught | won
	self.time = 0
	self.play_time = 0
	self.score = 0
	self.delivered = false
	self.cookies = false
	self.milk = false
	self.revealed = {}
	self.room_id = nil
	self.toast_text = nil
	self.toast_t = 0
	self.santa = new_santa()
	self.doors = {}
	for _, spot in ipairs(level.door_spots()) do
		self.doors[#self.doors + 1] = { floor = spot.floor, x = spot.x, open = false, anim = 0, side = 1 }
	end
	self.npcs = new_family()
	for _, n in ipairs(self.npcs) do
		n.wait_t, n.sus, n.anim, n.stir_t, n.stir_phase = 0, 0, 0, 0, "zz"
	end
	self.caught_t = 0
	self.caught_by = nil
	self.mia_wake_in = nil
	self.interaction = nil
	self.input = { axis = 0, jump = false, action = false, up = false, down = false }
	self.result = nil
end

function Game:start()
	self.attempt = 1
	self:reset_run()
	self.phase = "play"
	self:toast("Walk to the chimney, then press ACTION", 2.6)
end

-- Getting caught restarts the whole run: back on the roof, rooms dark again,
-- presents back in the sack and the snacks back where they were.
function Game:respawn()
	self.attempt = self.attempt + 1
	self:reset_run()
	self.phase = "play"
	self:toast("Attempt " .. self.attempt .. " · Walk to the chimney, then press ACTION", 2.4)
end

function Game:set_paused(paused)
	if self.phase ~= "play" and self.phase ~= "paused" then return end
	self.phase = paused and "paused" or "play"
	if paused then
		self:toast("Paused", 999)
	else
		self.toast_text, self.toast_t = nil, 0
	end
end

function Game:toast(msg, secs)
	self.toast_text = msg
	self.toast_t = secs or 2.2
end

function Game:objective()
	local o = "Slide down the chimney"
	if self.santa.floor > 0 or next(self.revealed) ~= nil then
		o = self.delivered and "Get back up the chimney" or "Find the Christmas tree"
	end
	if self.cookies and self.milk then o = o .. " · snack found" end
	return o
end

function Game:npc(id)
	for _, n in ipairs(self.npcs) do
		if n.id == id then return n end
	end
end

function Game:consume_input()
	local i = self.input
	i.jump, i.action, i.up, i.down = false, false, false, false
end

-- ---------------------------------------------------------------- moves

function Game:landed()
	local s = self.santa
	s.mode = "walk"
	s.on_ground = true
	s.grace = 0.8
end

function Game:tween_santa(x1, y1, dur, done)
	local s = self.santa
	s.tween = { x0 = s.x, y0 = s.y, x1 = x1, y1 = y1, t = 0, dur = dur, done = done }
	s.mode = "tween"
	s.vx, s.vy = 0, 0
end

-- Walk Santa along the floor to x, then run `after` (used to reach the end of a staircase).
function Game:walk_to(x, y, after)
	local s = self.santa
	local d = math.abs(x - s.x)
	if d < 1.5 then
		s.x, s.y = x, y
		after()
		return
	end
	s.face = x > s.x and 1 or -1
	s.y = y
	self:tween_santa(x, y, d / 70, after)
end

-- ---------------------------------------------------------------- interactions

-- Returns { kind, label, trigger, stair, hide } or nil.
-- `trigger` is the extra key besides ACTION that fires it: "up", "down", "any" or "action".
function Game:current_interaction()
	local s = self.santa
	if s.mode == "hidden" then
		return { kind = "unhide", label = "Come out", trigger = "any", hide = s.hide }
	end
	if s.mode ~= "walk" or not s.on_ground then return nil end

	if s.floor == 0 and s.x >= level.CHIMNEY_ROOF_X0 and s.x <= level.CHIMNEY_ROOF_X1 then
		return { kind = "chimney_down", label = "Slide down chimney", trigger = "down" }
	end
	if s.floor == level.TREE_FLOOR and s.x >= level.TREE_X0 and not self.delivered then
		return { kind = "deliver", label = "Deliver presents", trigger = "action" }
	end
	if s.floor == 1 and self.delivered and s.x >= 236 and s.x <= 262 then
		return { kind = "escape", label = "Escape up chimney", trigger = "up" }
	end

	local pad = level.STAIR_PAD
	for _, st in ipairs(level.STAIRS) do
		-- Anywhere along the flight (downstairs) or over the stairwell opening (upstairs) counts.
		local fx0 = math.min(st.bottom, st.top) - pad
		local fx1 = math.max(st.bottom, st.top) + pad
		if s.floor == st.lower and s.x >= fx0 and s.x <= fx1 then
			return { kind = "stairs_up", label = "Go upstairs", trigger = "up", stair = st }
		end
		local w0, w1 = level.well_range(st)
		if s.floor == st.lower - 1 and s.x >= math.min(w0, w1) - pad and s.x <= math.max(w0, w1) + pad then
			return { kind = "stairs_down", label = "Go downstairs", trigger = "down", stair = st }
		end
	end

	for _, h in ipairs(level.HIDES) do
		if h.floor == s.floor and s.x >= h.x0 and s.x <= h.x1 then
			return { kind = "hide", label = h.label, trigger = "down", hide = h }
		end
	end
	return nil
end

function Game:do_interaction(it)
	local s = self.santa
	local kind = it.kind

	if kind == "unhide" then
		s.mode = "walk"
		s.hide = nil
		self:sfx("unhide")

	elseif kind == "hide" then
		self:sfx("hide")
		s.mode = "hidden"
		s.hide = it.hide
		s.vx = 0
		s.x = (it.hide.x0 + it.hide.x1) / 2

	elseif kind == "chimney_down" then
		self:sfx("chimney")
		self:tween_santa(level.CHIMNEY_X, 14, 0.35, function()
			s.floor = 1
			s.x, s.y = level.CHIMNEY_X, FLOOR[1] - 30
			s.px, s.py = s.x, s.y
			self:tween_santa(level.CHIMNEY_X, FLOOR[1], 0.5, function() self:landed() end)
		end)

	elseif kind == "escape" then
		self:sfx("escape")
		self:tween_santa(level.CHIMNEY_X, FLOOR[1] - 30, 0.5, function()
			s.floor = 0
			s.x, s.y = level.CHIMNEY_X, 14
			s.px, s.py = s.x, s.y
			self:tween_santa(level.CHIMNEY_X, FLOOR[0], 0.35, function()
				s.mode = "walk"
				self:win()
			end)
		end)

	elseif kind == "stairs_up" then
		local st = it.stair
		self:sfx("creak")
		self:walk_to(st.bottom, FLOOR[st.lower], function()
			s.face = st.top > st.bottom and 1 or -1
			self:tween_santa(st.top, FLOOR[st.lower - 1], 0.7, function()
				s.floor = st.lower - 1
				self:landed()
			end)
		end)

	elseif kind == "stairs_down" then
		local st = it.stair
		self:sfx("creak")
		self:walk_to(st.top, FLOOR[st.lower - 1], function()
			-- Switch floor now so the climb down shows inside the lower room.
			s.floor = st.lower
			s.face = st.bottom > st.top and 1 or -1
			self:tween_santa(st.bottom, FLOOR[st.lower], 0.7, function() self:landed() end)
		end)

	elseif kind == "deliver" then
		self.delivered = true
		self.score = self.score + 1000
		self:sfx("deliver")
		self:toast("Presents delivered! Now sneak back up to the chimney")
		local mia = self:npc("mia")
		if mia and mia.state == "asleep" then
			self.mia_wake_in = 2.6
		end
	end
end

-- ---------------------------------------------------------------- doors and the family

-- Is there a closed door between a and b on this floor?
function Game:door_between(floor, a, b)
	local lo, hi = math.min(a, b), math.max(a, b)
	for _, d in ipairs(self.doors) do
		if not d.open and d.floor == floor and d.x > lo and d.x < hi then return true end
	end
	return false
end

function Game:wake(n, msg)
	if n.state ~= "asleep" then return end
	n.state = "stir"
	n.stir_phase = "zz"
	n.stir_t = level.STIR_ZZ + level.STIR_UP
	n.sus = 0
	self:toast(msg or (n.name .. " is waking up!"), 2.2)
end

-- Opens a door. `npc` is the family member walking through it, or nil for Santa.
function Game:open_door(d, npc)
	d.open = true
	d.anim = 0
	if npc then
		d.side = npc.dir
		if npc.floor == self.santa.floor then self:sfx("door", 0.5) end
		return
	end
	d.side = self.santa.x < d.x and 1 or -1
	self:sfx("door")
	local room = level.room_at(d.floor, d.x + d.side * 4)
	if room then
		self.revealed[room.id] = true
		for _, n in ipairs(self.npcs) do
			if n.state == "asleep" and n.room == room.id then
				self:wake(n, "The door creaked… " .. n.name .. " is waking up!")
			end
		end
	end
end

function Game:caught(n)
	self.phase = "caught"
	self.caught_t = 1.8
	self.caught_by = n
	n.state = "wait"
	n.wait_t = 2
	self:sfx("caught")
	self:toast(n.name .. " spotted Santa! Back to the roof…", 1.8)
end

function Game:update_npcs(dt, detect)
	for _, d in ipairs(self.doors) do
		if d.open and d.anim < 1 then d.anim = math.min(1, d.anim + dt / 0.35) end
	end

	local s = self.santa
	for _, n in ipairs(self.npcs) do
		local active = true
		if n.state == "asleep" then
			active = false
		elseif n.state == "stir" then
			active = false
			n.stir_t = n.stir_t - dt
			if n.stir_phase == "zz" and n.stir_t <= level.STIR_UP then
				n.stir_phase = "up"
				self:sfx("wake")
			end
			if n.stir_t <= 0 then
				n.state = "walk"
				n.x = n.wake_x or n.x
				n.dir = 1
			end
		elseif n.state == "walk" then
			local nx = n.x + n.dir * n.speed * dt
			for _, d in ipairs(self.doors) do
				if not d.open and d.floor == n.floor and (d.x - n.x) * (d.x - nx) <= 0 then
					self:open_door(d, n)
				end
			end
			n.x = nx
			n.anim = n.anim + dt * 5
			if (n.dir > 0 and n.x >= n.hi) or (n.dir < 0 and n.x <= n.lo) then
				n.x = clamp(n.x, n.lo, n.hi)
				n.state = "wait"
				n.wait_t = n.pause
			end
		elseif n.state == "wait" then
			n.wait_t = n.wait_t - dt
			if n.wait_t <= 0 then
				n.dir = -n.dir
				n.state = "walk"
			end
		end

		if active and detect then
			-- Vision: a cone in front, plus anyone standing right on top of Santa.
			local sees = false
			if n.floor == s.floor and s.mode == "walk" and s.grace == 0 then
				local dx = s.x - n.x
				local range = level.in_shadow(s.floor, s.x) and level.SHADOW_SIGHT or level.SIGHT_RANGE
				local in_cone = dx * n.dir > 0 and math.abs(dx) < range
				if (in_cone or math.abs(dx) < 5) and not self:door_between(n.floor, n.x, s.x) then
					sees = true
				end
			end
			local was = n.sus
			if sees then
				n.sus = n.sus + level.SUS_RISE * dt
			else
				n.sus = math.max(0, n.sus - level.SUS_FALL * dt)
			end
			if was == 0 and n.sus > 0 then self:sfx("notice") end
			if n.sus >= 1 then
				self:caught(n)
				return
			end
		end
	end
end

-- ---------------------------------------------------------------- update (fixed 60 Hz step)

function Game:step_tween(dt)
	local s = self.santa
	local tw = s.tween
	if not tw then
		s.mode = "walk"
		return
	end
	tw.t = tw.t + dt
	local k = math.min(1, tw.t / tw.dur)
	s.x = tw.x0 + (tw.x1 - tw.x0) * k
	s.y = tw.y0 + (tw.y1 - tw.y0) * k
	s.anim = s.anim + dt * 8
	if s.floor > 0 and math.abs(tw.x1 - tw.x0) > 4 then
		-- Footsteps while walking to or along a staircase.
		s.step_acc = s.step_acc + dt
		if s.step_acc > 0.1 then
			s.step_acc = 0
			self:sfx("step_floor")
		end
	end
	if k >= 1 then
		s.tween = nil
		if tw.done then tw.done() end
	end
end

function Game:step_walk(dt, ax)
	local s = self.santa
	local input = self.input

	-- Horizontal
	local target = ax * level.WALK
	s.vx = s.vx + (target - s.vx) * math.min(1, level.FRICTION * dt)
	if math.abs(ax) > 0.1 then s.face = ax > 0 and 1 or -1 end
	s.x = s.x + s.vx * dt
	local min_x = s.floor == 0 and 40 or level.HOUSE_X0 + 5
	local max_x = s.floor == 0 and 280 or level.HOUSE_X1 - 5
	s.x = clamp(s.x, min_x, max_x)
	s.anim = s.anim + math.abs(s.vx) * dt * 0.18

	-- Vertical
	local was_ground = s.on_ground
	if (input.jump or input.up) and s.on_ground then
		s.vy = -level.JUMP
		s.on_ground = false
		self:sfx("jump")
	end
	local prev_y = s.y
	s.vy = s.vy + level.GRAVITY * dt
	s.y = s.y + s.vy * dt
	s.on_ground = false
	local vy_before = s.vy
	if s.vy >= 0 then
		for _, p in ipairs(level.LEDGES) do
			if p.floor == s.floor and s.x >= p.x0 and s.x <= p.x1 and prev_y <= p.top and s.y >= p.top then
				s.y = p.top
				s.vy = 0
				s.on_ground = true
			end
		end
	end
	if s.y >= FLOOR[s.floor] then
		s.y = FLOOR[s.floor]
		s.vy = 0
		s.on_ground = true
	end
	local ceil = level.ceiling(s.floor)
	if s.y - 11 < ceil then
		s.y = ceil + 11
		s.vy = math.max(0, s.vy)
	end
	if not was_ground and s.on_ground and vy_before > 60 then self:sfx("land") end
	if s.on_ground and math.abs(s.vx) > 8 then
		s.step_acc = s.step_acc + math.abs(s.vx) * dt
		if s.step_acc > 11 then
			s.step_acc = 0
			self:sfx(s.floor == 0 and "step_roof" or "step_floor")
		end
	end

	-- Doors swing open as Santa reaches them.
	for _, d in ipairs(self.doors) do
		if not d.open and d.floor == s.floor and math.abs(s.x - d.x) < 7 then
			self:open_door(d, nil)
		end
	end

	-- Pickups
	if s.floor == level.COOKIE_FLOOR and not self.cookies and math.abs(s.x - level.COOKIE_X) < 6
		and s.y <= FLOOR[3] - 13 then
		self.cookies = true
		self.score = self.score + 300
		self:toast("Cookies! +300", 1.6)
		self:sfx("cookie")
	end
	if s.floor == level.MILK_FLOOR and not self.milk and math.abs(s.x - level.MILK_X) < 6 then
		self.milk = true
		self.score = self.score + 200
		self:toast("Milk! +200", 1.6)
		self:sfx("milk")
	end
end

function Game:update(dt)
	self.time = self.time + dt
	if self.toast_t > 0 then
		self.toast_t = self.toast_t - dt
		if self.toast_t <= 0 then self.toast_text = nil end
	end

	if self.phase == "caught" then
		self.caught_t = self.caught_t - dt
		if self.caught_t <= 0 then
			self:respawn()
			return
		end
		self:update_npcs(dt, false)
		return
	end
	if self.phase ~= "play" then return end
	self.play_time = self.play_time + dt

	if self.mia_wake_in then
		self.mia_wake_in = self.mia_wake_in - dt
		if self.mia_wake_in <= 0 then
			self.mia_wake_in = nil
			local mia = self:npc("mia")
			if mia then self:wake(mia, "Uh oh… someone is awake upstairs!") end
		end
	end

	local s = self.santa
	local input = self.input
	s.px, s.py = s.x, s.y
	s.grace = math.max(0, s.grace - dt)

	local ax = input.axis
	local it = self:current_interaction()
	if it then
		local fire = input.action
			or (it.trigger == "up" and input.up)
			or (it.trigger == "down" and input.down)
			or (it.kind == "unhide" and (input.jump or input.up or math.abs(ax) > 0.3))
		if fire then
			self:do_interaction(it)
			self:consume_input()
		end
	end

	if s.mode == "tween" then
		self:step_tween(dt)
	elseif s.mode == "walk" then
		self:step_walk(dt, ax)
	end
	self:consume_input()

	-- Entering a room reveals it.
	local room = level.room_at(s.floor, s.x)
	if room then
		if room.id ~= self.room_id then
			self.room_id = room.id
			self.revealed[room.id] = true
		end
	else
		self.room_id = nil
	end

	self:update_npcs(dt, true)
	self.interaction = self:current_interaction()
end

-- ---------------------------------------------------------------- winning

function Game:win()
	self.phase = "won"
	self:sfx("win")
	local time_bonus = math.max(0, round(1500 - self.play_time * 8))
	local first_try = self.attempt == 1
	local rows = {
		{ "Presents delivered", 1000 },
		{ "Back up the chimney", 1000 },
		{ "Cookies", self.cookies and 300 or 0 },
		{ "Milk", self.milk and 200 or 0 },
		{ "Time bonus (" .. round(self.play_time) .. "s)", time_bonus },
		{ first_try and "First try bonus" or ("Attempts: " .. self.attempt), first_try and 750 or 0 },
	}
	local total = 0
	for _, r in ipairs(rows) do total = total + r[2] end
	self.score = total
	local previous = self.best
	local new_best = total > previous and previous > 0
	if total > self.best then self.best = total end
	self.result = {
		title = "Merry Christmas!",
		text = new_best and "New best score!" or "Nobody saw a thing. Ho ho ho.",
		rows = rows,
		total = total,
		best = previous > 0 and math.max(previous, total) or 0,
	}
end

return M
