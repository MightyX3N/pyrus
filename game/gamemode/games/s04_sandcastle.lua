-- Summer: Sandslottet (the sandcastle): a castle is shown for a few seconds, then you build it
-- again from memory on the same patch of beach. Three castles a game; the right piece in the
-- right place gives points, wrong ones cost, and a quick finish gives a bonus.
-- Keys: arrows move, Space builds (or removes), Ctrl changes the piece, E is "done".
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local W, H = 960, 720
local STEP = 1 / 60
local A = "sand/"
local COLS, ROWS, CELL = 10, 6, 72
local GX, GY = (W - COLS * CELL) / 2, 150
local PIECES = {
	{ id = "tower", img = "tower", h = 110, val = 30, cost = 3 },
	{ id = "house", img = "house", h = 100, val = 50, cost = 5 },
	{ id = "wall", img = "wall", h = 72, val = 2, cost = 1 },
	{ id = "moat", img = "moat", h = 72, val = 0, flat = true, cost = -2 },
}
local BYID = {}
for i, p in ipairs(PIECES) do p.i = i BYID[p.id] = p end

-- the waves come at a few columns at a time (shown at the shore 3 s before)
local COPY = {
	{ pieces = { 5, 7 }, look = 8, time = 45 },
	{ pieces = { 8, 11 }, look = 6, time = 45 },
	{ pieces = { 12, 15 }, look = 4, time = 45 },
}

local function make(n, mode)
	local G = {
		scoreType = "score",
		goal = 900,
		worst = 0,
		descKey = "su_copycastle",
	}

	function G:Status()
		return AN.L("su_copy_status", math.min(3, self.castleNo or 1), self.score or 0)
	end

	function G:Open(args)
		self.diff = SU.Diff()
		self.kprev = {}
		self.acc, self.t, self.time = 0, 0, 0
		self.cx, self.cy = math.floor(COLS / 2), ROWS - 1
		self.piece = 1
		self.grid = {}
		self.hp = {}
		self.cool = 0
		self.repeatT = {}
		self.finished, self.overAt = false, nil
		self.msg = nil
		self.score = 0
		self.P = COPY[self.diff]
		self.castleNo = 0
		self:NextCastle()
	end
	function G:Close() end

	local function key(x, y) return y * COLS + x end

	function G:Pressed(k)
		local down = input.IsKeyDown(k)
		local was = self.kprev[k]
		self.kprev[k] = down
		return down and not was
	end
	-- arrows: a press moves once, holding moves again every 0.12 s
	function G:Arrow(k)
		local down = input.IsKeyDown(k)
		local was = self.kprev[k]
		self.kprev[k] = down
		if down and not was then self.repeatT[k] = self.t + 0.3 return true end
		if down and self.repeatT[k] and self.t >= self.repeatT[k] then self.repeatT[k] = self.t + 0.12 return true end
		return false
	end

	-- the castle standing now, in points
	function G:Castle(grid)
		local s = 0
		for _, id in pairs(grid or self.grid) do s = s + BYID[id].val end
		return s
	end

	function G:Build(x, y)
		if self.cool > 0 then return end
		local k = key(x, y)
		if self.grid[k] then
			self.grid[k] = nil
			MG.Sound("g11", "lift", 0.6)
			self.hp[k] = nil
		else
			local p = PIECES[self.piece]
			self.grid[k] = p.id
			self.built = { k = k, t = self.t }
			MG.Sound("g21", "place", 0.7)
		end
		self.cool = 0.12
	end

	---------------------------------------------------------------------------
	-- copying
	---------------------------------------------------------------------------
	function G:NextCastle()
		self.castleNo = self.castleNo + 1
		if self.castleNo > 3 then return self:Over() end
		local P = self.P
		local n = math.random(P.pieces[1], P.pieces[2])
		local target = {}
		local count = 0
		-- a castle-like layout: houses in the middle, towers round them, walls between, a moat in front
		local cx = math.random(3, COLS - 4)
		local cy = math.random(2, ROWS - 2)
		local function put(x, y, id)
			if x < 0 or x >= COLS or y < 0 or y >= ROWS or count >= n then return end
			local k = key(x, y)
			if not target[k] then target[k] = id count = count + 1 end
		end
		put(cx, cy, "house")
		if math.random() < 0.5 then put(cx + 1, cy, "house") end
		local ring = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }
		for i, d in ipairs(ring) do put(cx + d[1] * (i <= 4 and 1 or 1), cy + d[2], i <= 4 and "tower" or "wall") end
		for x = cx - 2, cx + 3 do put(x, cy - 2, "moat") end
		while count < n do
			put(math.random(0, COLS - 1), math.random(0, ROWS - 1), PIECES[math.random(#PIECES)].id)
		end
		self.target = target
		self.targetN = count
		self.grid, self.hp = {}, {}
		self.phase = "look"
		self.phaseT = 0
		MG.Sound("g08", "ding")
	end

	function G:Done()
		if self.phase ~= "build" then return end
		-- right piece in the right place +25, anything extra or wrong -10, quick +2 per second left
		local right, wrong = 0, 0
		for k, id in pairs(self.grid) do
			if self.target[k] == id then right = right + 1 else wrong = wrong + 1 end
		end
		local pts = right * 25 - wrong * 10
		if right >= self.targetN / 2 then pts = pts + math.floor(math.max(0, self.P.time - self.phaseT)) * 2 end
		pts = math.max(0, pts)
		self.score = self.score + pts
		self.lastRound = { right = right, of = self.targetN, wrong = wrong, pts = pts }
		self.phase = "check"
		self.phaseT = 0
		local perfect = right == self.targetN and wrong == 0
		MG.Sound(perfect and "ui" or "g04", perfect and "triangel" or (right >= self.targetN / 2 and "match" or "nomatch"))
		if right == self.targetN and wrong == 0 then AN.Speak("megetgodt") end
	end

	function G:Over()
		if self.overAt then return end
		self.overAt = self.t
		MG.Sound("g14", "done")
	end

	---------------------------------------------------------------------------
	function G:Step()
		self.t = self.t + STEP
		if self.overAt then
			if self.t - self.overAt > 2.4 and not self.finished then
				self.finished = true
				AN.FinishGame(n, self.score)
			end
			return
		end
		self.time = self.time + STEP
		self.cool = math.max(0, self.cool - STEP)
		local canBuild = self.phase == "build"
		-- moving, building, changing piece
		if self:Arrow(KEY_LEFT) then self.cx = math.max(0, self.cx - 1) end
		if self:Arrow(KEY_RIGHT) then self.cx = math.min(COLS - 1, self.cx + 1) end
		if self:Arrow(KEY_UP) then self.cy = math.max(0, self.cy - 1) end
		if self:Arrow(KEY_DOWN) then self.cy = math.min(ROWS - 1, self.cy + 1) end
		if self:Pressed(KEY_SPACE) and canBuild then self:Build(self.cx, self.cy) end
		local ctrl = self:Pressed(KEY_LCONTROL)
		if self:Pressed(KEY_RCONTROL) then ctrl = true end
		if ctrl then self.piece = self.piece % #PIECES + 1 MG.Sound("g21", "rotate", 0.6) end
		self.phaseT = self.phaseT + STEP
		if self:Pressed(KEY_E) then self:Done() end
		if self.phase == "look" and self.phaseT >= self.P.look then
			self.phase = "build"
			MG.Sound("g04", "turn")
			self.phaseT = 0
		elseif self.phase == "build" and self.phaseT >= self.P.time then
			self:Done()
		elseif self.phase == "check" and self.phaseT >= 3 then
			self:NextCastle()
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
	local function pic(name, x, y, w, h, alpha)
		AN.Img(A .. name .. ".png", MG.X(x), MG.Y(y), MG.S(w), MG.S(h), alpha)
	end
	local WHITE = Color(255, 255, 255)
	local INK = Color(26, 58, 84)

	-- one piece in its cell (tall ones stick up)
	local function piece(id, x, y, alpha, s)
		local p = BYID[id]
		s = s or 1
		local px, py = GX + x * CELL, GY + y * CELL
		if p.flat then
			pic(p.img, px, py, CELL, CELL, alpha)
		else
			local w, h = CELL * s, p.h * s
			pic(p.img, px + (CELL - w) / 2, py + CELL - h + 4, w, h, alpha)
			if id == "tower" then pic("flag", px + 30, py + CELL - h - 30, 26, 34, alpha) end
		end
	end

	local function drawGrid(grid, alpha, bump)
		-- moats first (flat), then the rest row by row
		for k, id in pairs(grid) do
			if id == "moat" then piece(id, k % COLS, math.floor(k / COLS), alpha) end
		end
		for y = 0, ROWS - 1 do
			for x = 0, COLS - 1 do
				local id = grid[key(x, y)]
				if id and id ~= "moat" then
					local s = 1
					if bump and bump.k == key(x, y) then s = 1 + 0.15 * math.max(0, 1 - (bump.t2) / 0.2) end
					piece(id, x, y, alpha, s)
				end
			end
		end
	end

	function G:Paint()
		MG.Stage(W, H)
		local vx0 = (0 - MG.x0) / MG.k
		local vx1 = (AN.VW - MG.x0) / MG.k
		local vy0 = (-AN.OY - MG.y0) / MG.k
		local vy1 = (AN.VH - AN.OY - MG.y0) / MG.k
		-- the sea at the top, the beach below
		AN.Box(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(GY - 30 - vy0), Color(46, 168, 214))
		AN.VGrad(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(GY - 30 - vy0), Color(20, 110, 170), 200, 0)
		AN.Box(MG.X(vx0), MG.Y(GY - 30), MG.S(vx1 - vx0), MG.S(vy1 - GY + 30), Color(242, 215, 154))
		AN.Box(MG.X(vx0), MG.Y(GY - 36), MG.S(vx1 - vx0), MG.S(10), Color(255, 255, 255, 200))
		AN.Box(MG.X(vx0), MG.Y(GY - 26), MG.S(vx1 - vx0), MG.S(30), Color(217, 183, 122))
		-- the building ground
		for y = 0, ROWS - 1 do
			for x = 0, COLS - 1 do pic("sandtile", GX + x * CELL, GY + y * CELL, CELL, CELL) end
		end
		AN.Outline(MG.X(GX - 4), MG.Y(GY - 4), MG.S(COLS * CELL + 8), MG.S(ROWS * CELL + 8), Color(201, 151, 78), MG.S(8), MG.S(3))
		-- Pyrus with his spade beside the patch
		local ph = 240
		AN.Img("sommer/pyrus_swim.png", MG.X(GX + COLS * CELL + 4), MG.Y(GY + ROWS * CELL - ph + 20), MG.S(ph * 440 / 640), MG.S(ph))
		-- the castle (or the one to copy)
		local bump = self.built and { k = self.built.k, t2 = self.t - self.built.t } or nil
		if self.phase == "look" then
			drawGrid(self.target, 255)
		elseif self.phase == "check" then
			drawGrid(self.target, 90)
			drawGrid(self.grid, 255)
			for k, id in pairs(self.grid) do
				local x, y = k % COLS, math.floor(k / COLS)
				local ok = self.target[k] == id
				AN.Text(ok and "V" or "X", "title", math.floor(MG.S(30)), MG.X(GX + x * CELL + CELL - 14), MG.Y(GY + y * CELL + 16), ok and Color(60, 190, 80) or Color(220, 50, 40), 1, 1)
			end
			for k, id in pairs(self.target) do
				if not self.grid[k] then
					local x, y = k % COLS, math.floor(k / COLS)
					AN.Outline(MG.X(GX + x * CELL + 4), MG.Y(GY + y * CELL + 4), MG.S(CELL - 8), MG.S(CELL - 8), Color(220, 50, 40), MG.S(6), MG.S(2))
				end
			end
		else
			drawGrid(self.grid, 255, bump)
		end
		-- the cursor with the piece it builds
		local canBuild = self.phase == "build"
		if canBuild and not self.overAt then
			local px, py = GX + self.cx * CELL, GY + self.cy * CELL
			local a = 0.6 + 0.4 * math.sin(self.t * 8)
			if not self.grid[key(self.cx, self.cy)] then piece(PIECES[self.piece].id, self.cx, self.cy, 110) end
			AN.Outline(MG.X(px), MG.Y(py), MG.S(CELL), MG.S(CELL), Color(255, 214, 64, 255 * a), MG.S(8), MG.S(4))
		end
		-- mouse: click a cell to build there
		if canBuild and not self.overAt then
			for y = 0, ROWS - 1 do
				for x = 0, COLS - 1 do
					UI.Button("sand_c" .. key(x, y), MG.X(GX + x * CELL), MG.Y(GY + y * CELL), MG.S(CELL), MG.S(CELL), function()
						self.cx, self.cy = x, y
						self:Build(x, y)
					end, { silent = true })
				end
			end
		end
		-- the piece palette (Ctrl changes)
		local py0 = GY + ROWS * CELL + 22
		for i, p in ipairs(PIECES) do
			local x = W / 2 - 2 * 104 + (i - 1) * 104
			local sel = i == self.piece
			local hot = UI.Button("sand_p" .. i, MG.X(x), MG.Y(py0), MG.S(96), MG.S(70), function() self.piece = i end)
			AN.Box(MG.X(x), MG.Y(py0), MG.S(96), MG.S(70), sel and Color(255, 214, 64) or (hot and Color(255, 255, 255, 230) or Color(255, 255, 255, 170)), MG.S(14))
			local s = math.min(1, 52 / p.h)
			pic(p.img, x + 48 - 30 * s * (CELL / 60), py0 + 4, CELL * s * 0.8 * (60 / 60), p.h * s * 0.8, 255)
			local lbl = AN.L("su_sand_" .. p.id)
			AN.Text(lbl, "bold", math.floor(MG.S(13)), MG.X(x + 48), MG.Y(py0 + 60), INK, 1, 1)
		end
		local hintKey = "su_copy_keys"
		AN.Text(AN.L(hintKey), "bold", math.floor(MG.S(15)), MG.X(W / 2), MG.Y(py0 + 92), INK, 1, 1)
		if self.phase == "build" and not self.overAt then
			local hot = UI.Button("sand_done", MG.X(W - 170), MG.Y(py0 + 8), MG.S(140), MG.S(54), function() self:Done() end)
			AN.Box(MG.X(W - 170), MG.Y(py0 + 12), MG.S(140), MG.S(54), Color(16, 60, 96), MG.S(26))
			AN.Box(MG.X(W - 170), MG.Y(py0 + 8), MG.S(140), MG.S(54), hot and Color(44, 140, 200) or Color(31, 111, 168), MG.S(26))
			AN.Text(AN.L("su_copy_done"), "title", math.floor(MG.S(26)), MG.X(W - 100), MG.Y(py0 + 35), WHITE, 1, 1)
		end
		-- the top bar
		AN.Box(MG.X(W / 2 - 220), MG.Y(14), MG.S(440), MG.S(48), Color(10, 50, 80, 190), MG.S(24))
		local txt
		if self.phase == "look" then txt = AN.L("su_copy_look", math.max(0, math.ceil(self.P.look - self.phaseT)))
		elseif self.phase == "build" then txt = AN.L("su_copy_build", math.max(0, math.ceil(self.P.time - self.phaseT)))
		else txt = AN.L("su_copy_round", self.lastRound and self.lastRound.right or 0, self.lastRound and self.lastRound.of or 0) end
		AN.Text(AN.L("su_copy_no", math.min(3, self.castleNo)), "title", math.floor(MG.S(24)), MG.X(W / 2 - 150), MG.Y(38), WHITE, 1, 1)
		AN.Text(txt, "title", math.floor(MG.S(24)), MG.X(W / 2 + 50), MG.Y(38), Color(255, 214, 64), 1, 1)
		if self.phase == "check" and self.lastRound then
			AN.Text("+" .. self.lastRound.pts, "title", math.floor(MG.S(54)), MG.X(W / 2), MG.Y(GY - 70), Color(255, 214, 64), 1, 1)
		end
		if self.msg and self.t - self.msg.t < 2 then
			local a = math.Clamp((2 - (self.t - self.msg.t)) * 2, 0, 1)
			AN.Text(self.msg.text, "title", math.floor(MG.S(32)), MG.X(W / 2), MG.Y(GY - 70), Color(255, 255, 255, 255 * a), 1, 1)
		end
		if self.overAt then
			local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
			AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(10, 50, 80, 210 * a), MG.S(30))
			AN.Text(AN.L("su_copy_over"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
			AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
		end
		MG.Chrome(n)
	end

	return G
end

AN.RegisterGame(105, make(105, "copy"))
