-- Låge 14: Skubbespil (sliding puzzle)
-- Rebuilt from the original loader.swf + slide0-3.swf: the same four puzzles
-- (Gyldengrød 4x4, Pyrus 3x3, numbers 3x3 and 4x4), the same shuffle (100 random
-- moves while the drum plays), mouse or arrow keys, and the time is the score.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local G = {
	scoreType = "time",
	goal = 30,        -- original coolScore 30000 ms
	worst = 600,      -- original badScore 600000 ms
	descKey = "desc_14",
	howKey = "how_14",
}

local STAGE_W, STAGE_H = 800, 600
-- the four puzzles in the order of the thumbnails (top to bottom)
local PUZZLES = {
	{ slide = 1, n = 3 },   -- Pyrus
	{ slide = 0, n = 4 },   -- Gyldengrød
	{ slide = 2, n = 3 },   -- numbers 3x3
	{ slide = 3, n = 4 },   -- numbers 4x4
}
local BOARD = { x = 201.5, y = 103.4, s = 400 }
-- element positions on the original 800 x 600 stage
local P = {
	desk = { 5.6, 242.8, 808 }, paper = { 133.2, 475.2, 146.4 }, branch = { -56.8, 2.4, 378.4 },
	thumbbg = { 282.4, 43.6, 100.8 }, thumbs = { 291.6, 53.2, 84.4 }, start = { 573.2, 480, 171.2 },
	medal = { 286, 176, 228.4 },
}

function G:Status()
	local pz = PUZZLES[self.choice or 2]
	return AN.L("g14_status", pz.n, pz.n, self.moves or 0)
end

function G:Open(args)
	self.state = "menu"
	self.choice = self.choice or 2
	self.tiles = {}
	self.queue = {}
	self.keys = {}
end

local function img(name, p, alpha)
	MG.Img("g14/" .. name, p[1], p[2], p[3], nil, alpha)
end

---------------------------------------------------------------------------
-- Puzzle logic (same as the original)
---------------------------------------------------------------------------
function G:Build()
	local pz = PUZZLES[self.choice]
	self.n = pz.n
	self.slide = pz.slide
	self.grid = {}           -- grid[x][y] = tile index or -1
	self.tiles = {}
	local n = self.n
	for x = 0, n - 1 do self.grid[x] = {} end
	local id = 0
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			if not (x == n - 1 and y == n - 1) then
				id = id + 1
				self.tiles[id] = { home = { x, y }, pos = { x, y }, dx = x, dy = y }
				self.grid[x][y] = id
			end
		end
	end
	self.grid[n - 1][n - 1] = -1
	self.empty = { n - 1, n - 1 }
	self.hist = {}
	self.hintMoves = nil
end

-- tiles that can move into the empty spot: [1] below, [2] left, [3] above, [4] right of it
function G:Movable()
	local ex, ey = self.empty[1], self.empty[2]
	local n = self.n
	return {
		ey < n - 1 and self.grid[ex][ey + 1] or nil,
		ex > 0 and self.grid[ex - 1][ey] or nil,
		ey > 0 and self.grid[ex][ey - 1] or nil,
		ex < n - 1 and self.grid[ex + 1][ey] or nil,
	}
end

function G:CanMove(id)
	local t = self.tiles[id]
	local dx, dy = math.abs(t.pos[1] - self.empty[1]), math.abs(t.pos[2] - self.empty[2])
	return dx + dy == 1
end

-- move a tile into the empty spot. instant = no animation (shuffle)
function G:Move(id, instant)
	if not self:CanMove(id) then return false end
	local t = self.tiles[id]
	local ox, oy = t.pos[1], t.pos[2]
	self.grid[self.empty[1]][self.empty[2]] = id
	t.pos = { self.empty[1], self.empty[2] }
	self.grid[ox][oy] = -1
	self.empty = { ox, oy }
	-- the way back (for the hint): moving the same tile again undoes it, so the solution is this
	-- list of tiles backwards
	local h = self.hist
	if h then
		if h[#h] == id then
			h[#h] = nil
			if self.hintMoves and self.hintMoves > 0 then self.hintMoves = self.hintMoves - 1 end
		else
			h[#h + 1] = id
		end
	end
	if instant then
		t.dx, t.dy = t.pos[1], t.pos[2]
	else
		self.animating = id
		MG.Sound("g14", "slide")
	end
	return true
end

function G:Press(id)
	if self.state ~= "play" then return end
	if self.animating then
		self.queue[#self.queue + 1] = id
		return
	end
	if self:Move(id, false) then self.moves = (self.moves or 0) + 1 end
end

function G:Solved()
	for _, t in ipairs(self.tiles) do
		if t.pos[1] ~= t.home[1] or t.pos[2] ~= t.home[2] then return false end
	end
	return true
end

-- seed: the shuffle's random numbers (in a Duel split screen both players get the same shuffle)
function G:StartPuzzle(seed)
	seed = seed or math.random(1, 2000000000)
	self.state = "shuffle"
	-- the other player in a Duel split screen starts the same puzzle at the same time
	local other = self.partner
	if other and other.state == "menu" then
		other.choice = self.choice
		other:StartPuzzle(seed)
	end
	math.randomseed(seed)
	self.rolls = {}
	for i = 1, 200 do self.rolls[i] = math.random() end
	self.roll = 0
	self:Build()
	self.state = "shuffle"
	self.shufflesLeft = 100
	self.lastMove = nil
	self.shuffleAcc = 0
	self.queue = {}
	self.animating = nil
	self.moves = 0
	MG.Sound("g14", "drum", 0.8)
end

function G:ShuffleStep()
	local cands = {}
	for _, id in pairs(self:Movable()) do
		if id and id ~= -1 and id ~= self.lastMove then cands[#cands + 1] = id end
	end
	self.roll = self.roll % #self.rolls + 1
	local id = cands[math.floor(self.rolls[self.roll] * #cands) + 1]
	self:Move(id, true)
	self.lastMove = id
end

function G:Think(dt)
	dt = math.min(dt, 0.1)
	if self.state == "shuffle" then
		-- one random move per original frame (25 fps)
		self.shuffleAcc = self.shuffleAcc + dt * 25
		while self.shuffleAcc >= 1 and self.shufflesLeft > 0 do
			self.shuffleAcc = self.shuffleAcc - 1
			self:ShuffleStep()
			self.shufflesLeft = self.shufflesLeft - 1
		end
		if self.shufflesLeft <= 0 then
			-- (very rarely the shuffle ends solved; then shuffle a bit more)
			if self:Solved() then self.shufflesLeft = 10 return end
			self.state = "play"
			self.t0 = RealTime()
		end
	elseif self.state == "play" then
		-- tile slide animation (original: x += (target - x) / 1.5 per frame)
		if self.animating then
			local t = self.tiles[self.animating]
			local f = 1 - (1 / 3) ^ (dt * 25)
			t.dx = t.dx + (t.pos[1] - t.dx) * f
			t.dy = t.dy + (t.pos[2] - t.dy) * f
			if math.abs(t.dx - t.pos[1]) < 0.01 and math.abs(t.dy - t.pos[2]) < 0.01 then
				t.dx, t.dy = t.pos[1], t.pos[2]
				self.animating = nil
				if self:Solved() then
					self:Done()
				elseif #self.queue > 0 then
					local id = table.remove(self.queue, 1)
					if self:Move(id, false) then self.moves = self.moves + 1 end
				end
			end
		end
		-- arrow keys move the tile next to the hole
		local map = { { KEY_UP, 1 }, { KEY_LEFT, 4 }, { KEY_DOWN, 3 }, { KEY_RIGHT, 2 } }
		for _, m in ipairs(map) do
			local down = input.IsKeyDown(m[1])
			if down and not self.keys[m[1]] then
				local id = self:Movable()[m[2]]
				if id and id ~= -1 then self:Press(id) end
			end
			self.keys[m[1]] = down
		end
	end
end

-- hint: arrows on the next 3 tiles to slide (numbered) on the way back to the solution
function G:CanHint() return self.state == "play" and self.hist and #self.hist > 0 and not self.animating end
function G:Hint(cost)
	self.hintMoves = 3
	self.t0 = self.t0 - cost      -- the clock jumps 5 seconds
	MG.Pop("+" .. cost .. " s", false, 110, 70)
end
function G:HintDraw()
	if not self.hintMoves or self.hintMoves <= 0 or self.state ~= "play" or not self.hist then return end
	local n = self.n
	local ts = BOARD.s / n
	-- play the next moves on a copy of the board
	local pos, ex, ey = {}, self.empty[1], self.empty[2]
	for id, t in ipairs(self.tiles) do pos[id] = { t.pos[1], t.pos[2] } end
	for k = 1, math.min(self.hintMoves, #self.hist) do
		local id = self.hist[#self.hist - k + 1]
		local p = pos[id]
		local x0, y0 = BOARD.x + (p[1] + 0.5) * ts, BOARD.y + (p[2] + 0.5) * ts
		local x1, y1 = BOARD.x + (ex + 0.5) * ts, BOARD.y + (ey + 0.5) * ts
		local dx, dy = (x1 - x0) * 0.32, (y1 - y0) * 0.32
		local a = k == 1 and 1 or 0.7
		MG.HintArrow(x0 - dx * 0.4, y0 - dy * 0.4, x0 + dx * 1.2, y0 + dy * 1.2, MG.HINT_GOLD, a, ts * 0.09)
		MG.HintText(tostring(k), x0 - dx * 0.9, y0 - dy * 0.9 - (dx == 0 and 0 or ts * 0.18), MG.HINT_GOLD, ts * 0.18, a)
		pos[id], ex, ey = { ex, ey }, p[1], p[2]
	end
end

function G:Done()
	self.state = "done"
	self.time = RealTime() - self.t0
	self.doneAt = RealTime()
	self.saidDone = false
	MG.Sound("g14", "done")
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function G:DrawBoard(showSolved)
	local n = self.n
	local ts = BOARD.s / n
	-- frame and dark empty board
	AN.Box(MG.X(BOARD.x - 9), MG.Y(BOARD.y - 9), MG.S(BOARD.s + 18), MG.S(BOARD.s + 18), Color(250, 236, 200), MG.S(4))
	AN.Box(MG.X(BOARD.x - 4), MG.Y(BOARD.y - 4), MG.S(BOARD.s + 8), MG.S(BOARD.s + 8), Color(82, 52, 41), MG.S(2))
	local mat = AN.Mat(string.format("g14/slide%d.png", self.slide))
	for id, t in ipairs(self.tiles) do
		local x, y = BOARD.x + t.dx * ts, BOARD.y + t.dy * ts
		local hot = false
		-- (not in a Duel split screen: the two players share the mouse, so the keys only)
		if self.state == "play" and not self.partner then
			hot = UI.Button("tile" .. id, MG.X(x), MG.Y(y), MG.S(ts), MG.S(ts), function() self:Press(id) end, { silent = true })
		end
		local u0, v0 = t.home[1] / n, t.home[2] / n
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(mat)
		local sx, sy, sw = AN.PX(MG.X(x)), AN.SY(MG.Y(y)), AN.SX(MG.S(ts))
		surface.DrawTexturedRectUV(sx, sy, sw, sw, u0, v0, u0 + 1 / n, v0 + 1 / n)
		-- bevel like the original tiles: light top/left, dark bottom/right
		local b = math.max(2, math.floor(sw * 0.035))
		surface.SetDrawColor(255, 255, 255, 110)
		surface.DrawRect(sx, sy, sw, b)
		surface.DrawRect(sx, sy, b, sw)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(sx, sy + sw - b, sw, b)
		surface.DrawRect(sx + sw - b, sy, b, sw)
		if hot and self:CanMove(id) then
			surface.SetDrawColor(255, 215, 106, 60)
			surface.DrawRect(sx, sy, sw, sw)
		end
	end
	-- the missing corner piece appears when solved
	if showSolved then
		local x, y = BOARD.x + (n - 1) * ts, BOARD.y + (n - 1) * ts
		local a = math.Clamp((RealTime() - self.doneAt) / 0.5, 0, 1) * 255
		surface.SetDrawColor(255, 255, 255, a)
		surface.SetMaterial(mat)
		surface.DrawTexturedRectUV(AN.PX(MG.X(x)), AN.SY(MG.Y(y)), AN.SX(MG.S(ts)), AN.SX(MG.S(ts)), (n - 1) / n, (n - 1) / n, 1, 1)
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	-- the wood planks run horizontally, so the background is stretched to fill any width
	AN.Img("g14/wood.jpg", -AN.OX, -AN.OY, AN.VW + AN.OX * 2, AN.VH)

	if self.state == "menu" then
		img("branch.png", P.branch)
		img("desk.png", P.desk)
		img("paper.png", P.paper)
		img("thumbbg.png", P.thumbbg)
		img("thumbs.png", P.thumbs)
		-- thumbnail buttons
		for i = 1, 4 do
			local ty = 53.35 + ({ 0, 91, 181.8, 272.95 })[i]
			local hot = UI.Button("pz" .. i, MG.X(291.7), MG.Y(ty), MG.S(86), MG.S(86.9), function()
				self.choice = i
				if self.partner then self.partner.choice = i end
			end)
			if i == self.choice then
				AN.Outline(MG.X(289), MG.Y(ty - 1), MG.S(90), MG.S(89), C.gold, MG.S(3), MG.S(2.5))
			elseif hot then
				AN.Outline(MG.X(289), MG.Y(ty - 1), MG.S(90), MG.S(89), Color(255, 241, 207, 160), MG.S(3), MG.S(2))
			end
		end
		-- preview of the chosen puzzle
		local pz = PUZZLES[self.choice]
		AN.Box(MG.X(390), MG.Y(45), MG.S(380), MG.S(375), Color(184, 160, 128), MG.S(6))
		AN.Box(MG.X(415), MG.Y(62), MG.S(330), MG.S(330), Color(250, 236, 200), MG.S(2))
		MG.Img(string.format("g14/slide%d.png", pz.slide), 420, 67, 320, 320)
		AN.Text(pz.n .. " x " .. pz.n, "title", math.floor(MG.S(16)), MG.X(580), MG.Y(404), C.brown, 1, 1)
		-- Start sign
		local hot = UI.Button("start", MG.X(P.start[1]), MG.Y(P.start[2]), MG.S(P.start[3]), MG.S(90), function() self:StartPuzzle() end)
		if hot then AN.Glow(MG.X(P.start[1] + 85), MG.Y(P.start[2] + 45), MG.S(130), C.gold, 0.6) end
		MG.Img("g14/start_da.png", P.start[1], P.start[2] - (hot and 3 or 0), P.start[3])
	else
		self:DrawBoard(self.state == "done")
		self:HintDraw()
		MG.DrawPops()
		-- timer (top left, like the original)
		local t = 0
		if self.state == "play" then t = RealTime() - self.t0 elseif self.state == "done" then t = self.time end
		local ms = math.floor((t % 1) * 1000)
		local s = math.floor(t) % 60
		local m = math.floor(t / 60)
		local txt = string.format("%02d:%02d:%03d", m, s, ms)
		AN.Text(txt, "title", math.floor(MG.S(20)), MG.X(57) + 3, MG.Y(50) + 3, Color(60, 20, 4))
		AN.Text(txt, "title", math.floor(MG.S(20)), MG.X(57), MG.Y(50), C.cream)
		AN.Text(AN.L("g14_moves", self.moves or 0), "bold", math.floor(MG.S(11)), MG.X(57), MG.Y(80), C.wheat)

		if self.state == "done" then
			local k = math.Clamp((RealTime() - self.doneAt) / 0.4, 0, 1)
			local w = P.medal[3] * (0.6 + 0.4 * k)
			MG.Img("g14/medal.png", 400 - w / 2, P.medal[2] + (P.medal[3] - w) / 2, w, nil, 255 * k)
			if AN.LangCode() == "da" then
				MG.Img("g14/godt_shadow.png", 318.8, 355.6, 182.8, nil, 255 * k)
				MG.Img("g14/godt_da.png", 316.8, 352.8, 182.8, nil, 255 * k)
			else
				AN.Text(AN.L("g14_welldone"), "title", math.floor(MG.S(30)), MG.X(400) + 3, MG.Y(380) + 3, Color(60, 20, 4), 1, 1, 255 * k)
				AN.Text(AN.L("g14_welldone"), "title", math.floor(MG.S(30)), MG.X(400), MG.Y(380), C.cream, 1, 1, 255 * k)
			end
			if not self.saidDone then
				self.saidDone = true
				AN.Speak("gameover")
			end
			if RealTime() - self.doneAt > 2.5 then
				self.state = "finished"
				AN.FinishGame(14, self.time)
			end
		end
	end

	MG.Chrome(14)
end

AN.RegisterGame(14, G)
