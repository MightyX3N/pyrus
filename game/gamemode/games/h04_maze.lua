-- Halloween: Spøgelseslabyrinten (the haunted maze). A dark maze, seen by the light of Pyrus'
-- lantern. Collect the keys and get out through the door before the ghost catches you; candy on
-- the way scores extra. Every maze is a bit bigger and the ghost a bit quicker; from the third
-- maze there are two ghosts. Three lives.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local N = 204
local W, H = 960, 720
local STEP = 1 / 60
local A = "maze/"
local TOP = 76                  -- the maze is drawn below the top bar

local DIFF = {
	{ cols = 9, rows = 6, light = 3.3, ghost = 1.7, more = 0.15, keys = 2, rnd = 0.2, sense = 4 },
	{ cols = 11, rows = 7, light = 2.7, ghost = 2.1, more = 0.2, keys = 3, rnd = 0.1, sense = 5 },
	{ cols = 13, rows = 8, light = 2.1, ghost = 2.5, more = 0.25, keys = 3, rnd = 0.05, sense = 6 },
}
local SPEED = 4.6               -- Pyrus: cells a second
local PTS_KEY, PTS_CANDY, PTS_EXIT = 50, 20, 300
local DIRS = { { 0, -1, "N" }, { 1, 0, "E" }, { 0, 1, "S" }, { -1, 0, "W" } }
local OPP = { N = "S", S = "N", E = "W", W = "E" }
local DARK = Color(6, 2, 12)

local G = {
	scoreType = "score",
	goal = 2000,
	worst = 0,
	descKey = "su_maze",
}

function G:Status()
	return AN.L("hw_maze_status", self.level or 1, self.score or 0)
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.acc, self.t = 0, 0
	self.score = 0
	self.lives = 3
	self.level = 0
	self.finished, self.overAt = false, nil
	self.pops = {}
	self.kprev = {}
	self:NewMaze()
end
function G:Close() end

local function cid(x, y) return y * 1000 + x end

function G:NewMaze()
	self.level = self.level + 1
	local D = self.D
	local grow = math.min(4, math.floor((self.level - 1) / 2))
	local cols, rows = D.cols + grow, D.rows + math.floor(grow / 2)
	self.cols, self.rows = cols, rows
	-- the maze: a random walk that knocks down walls (every cell can be reached)
	local walls = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do walls[cid(x, y)] = { N = true, E = true, S = true, W = true } end
	end
	local seen, stack = { [cid(0, 0)] = true }, { { 0, 0 } }
	while #stack > 0 do
		local c = stack[#stack]
		local opts = {}
		for _, d in ipairs(DIRS) do
			local nx, ny = c[1] + d[1], c[2] + d[2]
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows and not seen[cid(nx, ny)] then opts[#opts + 1] = d end
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local d = opts[math.random(#opts)]
			local nx, ny = c[1] + d[1], c[2] + d[2]
			walls[cid(c[1], c[2])][d[3]] = false
			walls[cid(nx, ny)][OPP[d[3]]] = false
			seen[cid(nx, ny)] = true
			stack[#stack + 1] = { nx, ny }
		end
	end
	-- a few extra openings, so there is more than one way round the ghost
	for _ = 1, math.floor(cols * rows * 0.14) do
		local x, y = math.random(0, cols - 2), math.random(0, rows - 1)
		walls[cid(x, y)].E = false
		walls[cid(x + 1, y)].W = false
	end
	self.walls = walls
	-- where things are: Pyrus top left, the door bottom right, keys in far dead ends
	self.start = { 0, 0 }
	self.exit = { cols - 1, rows - 1 }
	local dist = self:Dist(0, 0)
	local cells = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			local w = walls[cid(x, y)]
			local open = (w.N and 0 or 1) + (w.E and 0 or 1) + (w.S and 0 or 1) + (w.W and 0 or 1)
			if not (x == 0 and y == 0) and not (x == cols - 1 and y == rows - 1) then
				cells[#cells + 1] = { x, y, d = dist[cid(x, y)] or 0, dead = open == 1, r = math.random() }
			end
		end
	end
	table.sort(cells, function(a, b)
		local sa = a.d + (a.dead and 6 or 0) + a.r * 4
		local sb = b.d + (b.dead and 6 or 0) + b.r * 4
		return sa > sb
	end)
	self.keys = {}
	local used = {}
	local quarter = {}
	for _, c in ipairs(cells) do
		if #self.keys >= D.keys then break end
		-- spread the keys: not two in the same part of the maze
		local q = (c[1] < cols / 2 and 0 or 1) + (c[2] < rows / 2 and 0 or 2)
		if not quarter[q] then
			quarter[q] = true
			self.keys[#self.keys + 1] = { x = c[1], y = c[2] }
			used[cid(c[1], c[2])] = true
		end
	end
	self.candy = {}
	for i = 1, math.floor(cols * rows / 9) do
		local c = cells[math.random(#cells)]
		if not used[cid(c[1], c[2])] then
			used[cid(c[1], c[2])] = true
			self.candy[#self.candy + 1] = { x = c[1], y = c[2], img = "trick/candy" .. math.random(3) .. ".png" }
		end
	end
	self.got = 0
	self.flashes = 1
	-- the drawing size
	self.cell = math.floor(math.min((W - 40) / cols, (H - TOP - 20) / rows))
	self.ox = (W - cols * self.cell) / 2
	self.oy = TOP + (H - TOP - 10 - rows * self.cell) / 2
	self:Reset()
	self.banner = self.t
	MG.Sound("g16", "level_intro", 0.6)
end

-- Pyrus and the ghosts back to their places
function G:Reset()
	local D = self.D
	self.p = { x = self.start[1], y = self.start[2], fx = self.start[1], fy = self.start[2], tx = nil, k = 0, face = 1 }
	self.ghosts = {}
	local n = self.level >= 3 and 2 or 1
	local corners = { { self.cols - 1, self.rows - 1 }, { self.cols - 1, 0 }, { 0, self.rows - 1 } }
	for i = 1, n do
		local c = corners[i]
		self.ghosts[i] = { x = c[1], y = c[2], fx = c[1], fy = c[2], k = 0, wait = 2.5 + i, speed = D.ghost + D.more * (self.level - 1) - (i - 1) * 0.3 }
	end
	self.safe = 1.5
end

-- how many steps from a cell to every other one
function G:Dist(x0, y0)
	local dist = { [cid(x0, y0)] = 0 }
	local q, h = { { x0, y0 } }, 1
	while q[h] do
		local c = q[h]
		h = h + 1
		local w = self.walls[cid(c[1], c[2])]
		for _, d in ipairs(DIRS) do
			if not w[d[3]] then
				local nx, ny = c[1] + d[1], c[2] + d[2]
				local id = cid(nx, ny)
				if not dist[id] then
					dist[id] = dist[cid(c[1], c[2])] + 1
					q[#q + 1] = { nx, ny }
				end
			end
		end
	end
	return dist
end

function G:Open_(x, y, dname) return not self.walls[cid(x, y)][dname] end

function G:Pop(text, x, y, col)
	self.pops[#self.pops + 1] = { text = text, x = x, y = y, t = self.t, col = col or Color(255, 220, 90) }
end

function G:Over()
	if self.overAt then return end
	self.overAt = self.t
	MG.Sound("g14", "done")
end

function G:Step()
	self.t = self.t + STEP
	if self.overAt then
		if self.t - self.overAt > 2.4 and not self.finished then
			self.finished = true
			AN.FinishGame(N, self.score)
		end
		return
	end
	-- caught: a short pause, then back to the start
	if self.caughtAt then
		if self.t - self.caughtAt > 1.4 then
			self.caughtAt = nil
			if self.lives <= 0 then self:Over() return end
			self:Reset()
		end
		return
	end
	if self.doneAt then
		if self.t - self.doneAt > 1.6 then
			self.doneAt = nil
			self:NewMaze()
		end
		return
	end
	local D = self.D
	self.safe = math.max(0, self.safe - STEP)
	-- Space: the lantern flares up once a maze, and the ghosts flee for a while
	local sp = input.IsKeyDown(KEY_SPACE)
	if sp and not self.kprev.sp and self.flashes > 0 then
		self.flashes = self.flashes - 1
		self.flashAt = self.t
		for _, g in ipairs(self.ghosts) do g.scared = 3.5 end
		MG.Sound("g19", "lightswitch", 0.8)
		MG.Sound("g16", "scared_loop", 0.5)
	end
	self.kprev.sp = sp
	-- Pyrus: from cell to cell
	local p = self.p
	local want
	if input.IsKeyDown(KEY_UP) then want = DIRS[1] end
	if input.IsKeyDown(KEY_DOWN) then want = DIRS[3] end
	if input.IsKeyDown(KEY_LEFT) then want = DIRS[4] end
	if input.IsKeyDown(KEY_RIGHT) then want = DIRS[2] end
	-- (a key held, or a tap not yet used: the tap is kept a moment, so a turn can be pressed early)
	if want then p.want = want p.wantT = self.t end
	if p.want and self.t - (p.wantT or 0) > 0.2 then p.want = nil end
	if p.tx then
		p.k = p.k + SPEED * STEP
		-- turning back halfway
		if p.want and p.want[1] == p.x - p.tx and p.want[2] == p.y - p.ty then
			p.x, p.tx, p.y, p.ty = p.tx, p.x, p.ty, p.y
			p.k = 1 - p.k
		end
		if p.k >= 1 then
			p.x, p.y, p.tx, p.ty, p.k = p.tx, p.ty, nil, nil, 0
			self:Arrive()
		end
	end
	if not p.tx and p.want then
		local d = p.want
		if self:Open_(p.x, p.y, d[3]) then
			p.tx, p.ty, p.k = p.x + d[1], p.y + d[2], 0
			if d[1] ~= 0 then p.face = d[1] end
			p.want = nil
		end
	end
	if p.tx then
		p.fx, p.fy = p.x + (p.tx - p.x) * p.k, p.y + (p.ty - p.y) * p.k
	else
		p.fx, p.fy = p.x, p.y
	end
	-- the ghosts: along the corridors towards Pyrus
	local dist
	for _, g in ipairs(self.ghosts) do
		if g.wait > 0 then
			g.wait = g.wait - STEP
		else
			if not g.tx then
				dist = dist or self:Dist(p.x, p.y)
				local best, bd = nil, math.huge
				local w = self.walls[cid(g.x, g.y)]
				local opts = {}
				for _, d in ipairs(DIRS) do
					if not w[d[3]] then
						local nd = dist[cid(g.x + d[1], g.y + d[2])] or 999
						opts[#opts + 1] = d
						if nd < bd then best, bd = d, nd end
					end
				end
				-- too far away to sense Pyrus: it floats about (not straight back the way it came)
				local here = dist[cid(g.x, g.y)] or 999
				if g.scared and g.scared > 0 then
					-- fleeing: the way that leads furthest from Pyrus
					local bv = -1
					for _, d in ipairs(opts) do
						local nd = dist[cid(g.x + d[1], g.y + d[2])] or 0
						if nd > bv then best, bv = d, nd end
					end
				elseif here > D.sense or math.random() < D.rnd then
					local fwd = {}
					for _, d in ipairs(opts) do
						if not (g.lx and g.lx == g.x + d[1] and g.ly == g.y + d[2]) then fwd[#fwd + 1] = d end
					end
					if #fwd == 0 then fwd = opts end
					best = fwd[math.random(#fwd)]
				end
				g.lx, g.ly = g.x, g.y
				if best then g.tx, g.ty, g.k = g.x + best[1], g.y + best[2], 0 end
			end
			if g.scared then g.scared = g.scared - STEP if g.scared <= 0 then g.scared = nil end end
			if g.tx then
				g.k = g.k + g.speed * (g.scared and 0.8 or 1) * STEP
				if g.k >= 1 then g.x, g.y, g.tx, g.ty, g.k = g.tx, g.ty, nil, nil, 0 end
			end
		end
		if g.tx then g.fx, g.fy = g.x + (g.tx - g.x) * g.k, g.y + (g.ty - g.y) * g.k else g.fx, g.fy = g.x, g.y end
		if self.safe <= 0 and not g.scared and (g.fx - p.fx) ^ 2 + (g.fy - p.fy) ^ 2 < 0.45 then
			self.lives = self.lives - 1
			self.caughtAt = self.t
			MG.Sound("g16", "pac_die", 0.8)
			return
		end
	end
end

-- Pyrus has come to a cell: keys, candy, the door
function G:Arrive()
	local p = self.p
	for i = #self.keys, 1, -1 do
		local k = self.keys[i]
		if k.x == p.x and k.y == p.y then
			table.remove(self.keys, i)
			self.got = self.got + 1
			self.score = self.score + PTS_KEY
			self:Pop("+" .. PTS_KEY, p.x, p.y)
			MG.Sound("g19", "pickup", 0.8)
			if #self.keys == 0 then MG.Sound("g04", "level", 0.7) end
		end
	end
	for i = #self.candy, 1, -1 do
		local c = self.candy[i]
		if c.x == p.x and c.y == p.y then
			table.remove(self.candy, i)
			self.score = self.score + PTS_CANDY
			self:Pop("+" .. PTS_CANDY, p.x, p.y)
			MG.Sound("g01", "pickup", 0.6)
		end
	end
	if #self.keys == 0 and p.x == self.exit[1] and p.y == self.exit[2] then
		self.score = self.score + PTS_EXIT
		self:Pop("+" .. PTS_EXIT, p.x, p.y, Color(160, 255, 140))
		self.doneAt = self.t
		MG.Sound("g01", "levelcomplete", 0.8)
		if self.level % 2 == 0 then AN.Speak("megetgodt") end
	end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local WHITE = Color(255, 255, 255)
local GOLD = Color(255, 214, 90)
local WALL = Color(92, 70, 110)
local WALL_D = Color(60, 44, 74)

function G:Paint()
	MG.Stage(W, H)
	local D = self.D
	local cs, ox, oy = self.cell, self.ox, self.oy
	local function CX(x) return ox + (x + 0.5) * cs end
	local function CY(y) return oy + (y + 0.5) * cs end
	AN.Box(MG.X(-600), MG.Y(-600), MG.S(W + 1200), MG.S(H + 1200), Color(24, 16, 30))
	-- the floor
	for y = 0, self.rows - 1 do
		for x = 0, self.cols - 1 do
			AN.Img(A .. "floor.png", MG.X(ox + x * cs), MG.Y(oy + y * cs), MG.S(cs), MG.S(cs))
		end
	end
	-- the walls
	local t = math.max(4, cs * 0.12)
	for y = 0, self.rows - 1 do
		for x = 0, self.cols - 1 do
			local w = self.walls[cid(x, y)]
			local x0, y0 = ox + x * cs, oy + y * cs
			if w.N then AN.Box(MG.X(x0 - t / 2), MG.Y(y0 - t / 2), MG.S(cs + t), MG.S(t), WALL) end
			if w.W then AN.Box(MG.X(x0 - t / 2), MG.Y(y0 - t / 2), MG.S(t), MG.S(cs + t), WALL) end
			if y == self.rows - 1 and w.S then AN.Box(MG.X(x0 - t / 2), MG.Y(y0 + cs - t / 2), MG.S(cs + t), MG.S(t), WALL) end
			if x == self.cols - 1 and w.E then AN.Box(MG.X(x0 + cs - t / 2), MG.Y(y0 - t / 2), MG.S(t), MG.S(cs + t), WALL) end
		end
	end
	-- the door out, the keys, the candy
	local open = #self.keys == 0
	local ew = cs * 0.7
	AN.Img(A .. (open and "exit_open.png" or "exit_locked.png"), MG.X(CX(self.exit[1]) - ew / 2), MG.Y(CY(self.exit[2]) - ew * 1.25 / 2), MG.S(ew), MG.S(ew * 1.25))
	local bob = math.sin(self.t * 4) * cs * 0.04
	for _, k in ipairs(self.keys) do
		AN.Img(A .. "key.png", MG.X(CX(k.x) - cs * 0.32), MG.Y(CY(k.y) - cs * 0.16 + bob), MG.S(cs * 0.64), MG.S(cs * 0.32))
	end
	for _, c in ipairs(self.candy) do
		AN.Img(c.img, MG.X(CX(c.x) - cs * 0.25), MG.Y(CY(c.y) - cs * 0.17), MG.S(cs * 0.5), MG.S(cs * 0.33))
	end
	-- Pyrus
	local p = self.p
	local ph = cs * 0.95
	local pw = ph * 514 / 768
	local blink = self.safe > 0 and math.floor(self.t * 10) % 2 == 0
	if not blink then
		local hop = p.tx and math.abs(math.sin(p.k * math.pi)) * cs * 0.06 or 0
		SU.Img("halloween/pyrus_cape.png", MG.X(CX(p.fx) - pw / 2), MG.Y(CY(p.fy) - ph / 2 - hop), MG.S(pw), MG.S(ph), p.face < 0)
	end
	-- the ghosts
	for _, g in ipairs(self.ghosts) do
		local gh = cs * 0.95
		local gw = gh * 120 / 140
		local a = g.wait > 0 and 120 or 235
		AN.Img(g.scared and "ghost/ghost_scared.png" or "ghost/ghost.png", MG.X(CX(g.fx) - gw / 2), MG.Y(CY(g.fy) - gh / 2 + math.sin(self.t * 3) * cs * 0.05), MG.S(gw), MG.S(gh), a)
	end
	-- the darkness round the lantern
	local R = D.light * cs
	local size = 4 * R
	local lx, ly = CX(p.fx), CY(p.fy)
	local x0, y0 = MG.X(lx - size / 2), MG.Y(ly - size / 2)
	local S = MG.S(size)
	local flick = 1 + math.sin(self.t * 11) * 0.02
	S = S * flick
	x0, y0 = MG.X(lx) - S / 2, MG.Y(ly) - S / 2
	AN.Img("ghost/dark.png", x0, y0, S, S, 246)
	local dk = Color(DARK.r, DARK.g, DARK.b, 246)
	local L, T = MG.X(-600), MG.Y(-600)
	local Rr, B = MG.X(W + 600), MG.Y(H + 600)
	AN.Box(L, T, Rr - L, y0 - T, dk)
	AN.Box(L, y0 + S, Rr - L, B - y0 - S, dk)
	AN.Box(L, y0, x0 - L, S, dk)
	AN.Box(x0 + S, y0, Rr - x0 - S, S, dk)
	AN.Glow(MG.X(lx), MG.Y(ly), MG.S(R * 0.8), Color(255, 200, 110), 0.12)
	if self.flashAt and self.t - self.flashAt < 0.8 then
		local k = (self.t - self.flashAt) / 0.8
		AN.Glow(MG.X(lx), MG.Y(ly), MG.S(R * (1 + 2 * k)), Color(255, 240, 180), 0.9 * (1 - k))
	end
	-- in the dark: the ghosts' eyes, the keys glint, the door when it's open
	for _, g in ipairs(self.ghosts) do
		AN.Img("ghost/eyes.png", MG.X(CX(g.fx) - cs * 0.22), MG.Y(CY(g.fy) - cs * 0.2), MG.S(cs * 0.44), MG.S(cs * 0.18), 120 + 60 * math.sin(self.t * 5))
	end
	for i, k in ipairs(self.keys) do
		local a = math.max(0, math.sin(self.t * 2.5 + i * 2)) ^ 4
		if a > 0.05 then AN.Glow(MG.X(CX(k.x)), MG.Y(CY(k.y)), MG.S(cs * 0.3), Color(255, 220, 90), 0.6 * a) end
	end
	if open then AN.Glow(MG.X(CX(self.exit[1])), MG.Y(CY(self.exit[2])), MG.S(cs * 0.6), Color(255, 220, 120), 0.5) end
	-- the points
	for i = #self.pops, 1, -1 do
		local q = self.pops[i]
		local age = self.t - q.t
		if age > 1 then table.remove(self.pops, i) else
			local c = q.col
			AN.Text(q.text, "title", math.floor(MG.S(28)), MG.X(CX(q.x)), MG.Y(CY(q.y) - cs * 0.6 - age * 40), Color(c.r, c.g, c.b, 255 * (1 - age)), 1, 1)
		end
	end
	-- the top bar: the maze, keys, lives, points
	AN.Box(MG.X(W / 2 - 360), MG.Y(14), MG.S(720), MG.S(48), Color(30, 10, 40, 220), MG.S(24))
	AN.Text(AN.L("hw_maze_level", self.level), "title", math.floor(MG.S(24)), MG.X(W / 2 - 270), MG.Y(38), WHITE, 1, 1)
	local total = self.got + #self.keys
	for i = 1, total do
		AN.Img(A .. "key.png", MG.X(W / 2 - 170 + (i - 1) * 46), MG.Y(28), MG.S(40), MG.S(20), i <= self.got and 255 or 70)
	end
	for i = 1, 3 do
		AN.Img("trick/jack.png", MG.X(W / 2 + 36 + (i - 1) * 40), MG.Y(22), MG.S(35), MG.S(30), i <= self.lives and 255 or 50)
	end
	AN.Text(AN.L("hw_points", self.score), "title", math.floor(MG.S(24)), MG.X(W / 2 + 260), MG.Y(38), GOLD, 1, 1)
	if not (AN.VS and AN.VS.Split and AN.VS.Split.on) then
		AN.Text(AN.L(self.flashes > 0 and "hw_maze_keys" or "hw_maze_keys2"), "bold", math.floor(MG.S(16)), MG.X(W / 2), MG.Y(H - 14), Color(255, 240, 210, 170), 1, 1)
	end
	-- messages
	local msg
	if self.caughtAt then msg = AN.L(self.lives > 0 and "hw_maze_caught" or "hw_maze_over")
	elseif self.doneAt then msg = AN.L("hw_maze_out")
	elseif self.banner and self.t - self.banner < 1.8 then msg = AN.L("hw_maze_level", self.level) .. (#self.keys > 0 and ("  ·  " .. AN.L("hw_maze_find", #self.keys)) or "") end
	if msg then
		AN.Box(MG.X(W / 2 - 320), MG.Y(H / 2 - 40), MG.S(640), MG.S(80), Color(30, 10, 40, 220), MG.S(30))
		AN.Text(msg, "title", math.floor(MG.S(34)), MG.X(W / 2), MG.Y(H / 2), WHITE, 1, 1)
	end
	if self.overAt then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(30, 10, 40, 220 * a), MG.S(30))
		AN.Text(AN.L("hw_maze_over"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(N)
end

AN.RegisterGame(N, G)
