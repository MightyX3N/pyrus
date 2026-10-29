-- Låge 21: Nissespor
-- Rebuilt from the original loader.swf. Four tiles with half footprints on every edge; drag them
-- together into a square so the prints and colours match, and turn the last tile you picked up
-- with the space bar. Same rules as the original game clip: a 2 x 2 puzzle, tiles snap to a
-- neighbour within 50 pixels, a join counts when both halves have the same kind of print and
-- are opposite halves, and the game ends when there are 4 joins. The score is the time.
-- The background can be dragged too (it moves the whole table with the tiles, like the original).
local UI, MG, TL = AN.UI, AN.MG, AN.TL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g21_pos.lua")
include(DIR .. "g21_anim.lua")
include(DIR .. "g21_root.lua")
include(DIR .. "g21_sign.lua")
local P, A, ROOT, SIGN = AN.G21Pos, AN.G21Anim, AN.G21Root, AN.G21Sign

local G = {
	scoreType = "time",
	goal = 30,        -- the original coolScore (30000 ms, from the CD's gamelist.txt)
	worst = 600,      -- the original badScore (600000 ms, from the CD's gamelist.txt)
	descKey = "desc_21",
	howKey = "how_21",
}

local STAGE_W, STAGE_H = 600, 400
local STEP = 1 / 25
local X_SIZE, Y_SIZE = 2, 2            -- gameType 1
local SNAP = 50
local ROT_FRAMES = 10
local SIGN_POS = { 272.9, 359.1 }      -- the "Godt klaret!" clip on the stage
local OVER_FRAMES = 78                 -- "game over" (frame 19) to the gameOver call (frame 97)
local TYPES = { [0] = "a", "b", "c", "d" }
-- the four edge clips s0..s3 inside a tile
local SIDE_M = {
	[0] = { 0.98, 0, 0, 0.98, 0, -39.7 },
	[1] = { 0, 0.98, -0.98, 0, 39.2, 0 },
	[2] = { -0.98, 0, 0, -0.98, 0, 39.2 },
	[3] = { 0, -0.98, 0.98, 0, -39.2, 0 },
}
local HALF = 40                        -- the tile's button: a square from -40 to 39.95
local BSIZE = 79.95 + 1                -- bricks[0].mc._width + 1
-- the background button inside the table clip (shape 74 through its matrix)
local BG_HIT = { 349.75 - 452.2 * 1.625, 214.35 - 243.55 * 1.863, 349.75 + 452.2 * 1.625, 214.35 + 243.55 * 1.863 }
-- the 16 wood tiles of the table clip
local TILES = {
	{ 1, 1, -8.55, -15.05 }, { -1, 1, -737.5, -15.05 }, { -1, 1, 721.45, -15.05 }, { 1, -1, -8.55, 442.95 },
	{ -1, -1, -737.5, 442.95 }, { -1, -1, 721.45, 442.95 }, { 1, -1, -8.55, -475.05 }, { -1, -1, -737.5, -475.05 },
	{ -1, -1, 721.45, -475.05 }, { 1, 1, 1445.35, -14.95 }, { 1, -1, 1445.35, 443.05 }, { 1, -1, 1445.35, -474.95 },
	{ 1, 1, -8.55, 901.85 }, { -1, 1, -737.5, 901.85 }, { -1, 1, 721.45, 901.85 }, { 1, 1, 1445.35, 901.75 },
}

local function pic(name, m, alpha)
	local r = P[name]
	if r then TL.Pic("g21/" .. name .. ".png", r[1], r[2], r[3], r[4], m, alpha) end
end

local function rotM(deg, x, y)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { c, s, -s, c, x, y }
end

local function padFix(v)
	return string.format("%02d", v)
end

local function scoreToTime(ms)
	local min = math.floor(ms / 1000 / 60)
	local sek = math.floor(ms / 1000 - min * 60)
	local thous = math.floor(ms - min * 60000 - sek * 1000)
	return string.format("%02d:%02d:%03d", min, sek, thous)
end

function G:Status()
	return AN.L("g21_status", self.connections or 0, self.required or 4)
end

function G:Open(args)
	self.finished = false
	self.acc = 0
	self.state = "brandnew"
	self.connections = 0
	self.required = (X_SIZE - 1) * Y_SIZE + (Y_SIZE - 1) * X_SIZE
	self.rotating = false
	self.rotCount = 1
	self.selected = nil
	self.dragging = false
	self.draggedID = nil
	self.drag = nil
	self.mainX, self.mainY = 0, 0
	self.shadowX, self.shadowY, self.shadowRot = -1000, 0, 0
	self.playingTime = 0
	self.txt = { hourTxt = "00", minTxt = "00", secTxt = "00", mSecTxt = "00" }
	self.bricks = {}
	self.signF = nil         -- the "Godt klaret!" clip (frame 1 = hidden)
	self.overF = nil         -- frames shown of the "Spil Slut!" board
	self.spaceWas = true
end

---------------------------------------------------------------------------
-- the original game controller
---------------------------------------------------------------------------
function G:NewBrick(id, xt, yt)
	local b = { id = id, xID = xt, yID = yt, x = 0, y = 0, rot = 0, mcRot = 0, depth = 200 + id, lineF = 1, sides = {}, mcs = {} }
	for t = 0, 3 do
		b.sides[t] = { type = -1, state = 0, connected = 0, brickID = -1, sideID = -1, mc = t }
		b.mcs[t] = { label = nil, blink = false }
	end
	return b
end

function G:SetLabel(brickID, sideID, type, dir)
	local s = self.bricks[brickID].sides[sideID]
	s.state, s.type, s["end"] = 1, type, dir
	if s.mc then self.bricks[brickID].mcs[s.mc].label = TYPES[type] .. (dir and "1" or "2") end
end

function G:MakeNabo(b1, s1, b2, s2)
	local type = math.random(0, 3)
	local dir = math.random() > 0.5
	self:SetLabel(b1, s1, type, dir)
	self:SetLabel(b2, s2, type, not dir)
end

function G:MakeRandomEdge(b, s)
	local type = math.random(0, 3)
	local dir = math.random() > 0.5
	self:SetLabel(b, s, type, dir)
end

function G:InitGame()
	self.dragging = false
	self.shadowX = -1000
	self.startTime = RealTime()
	local bricks = self.bricks
	local id = 0
	for yt = 0, Y_SIZE - 1 do
		for xt = 0, X_SIZE - 1 do
			bricks[id] = self:NewBrick(id, xt, yt)
			id = id + 1
		end
	end
	self.nb = id
	local t = 0
	for yt = 0, Y_SIZE - 1 do
		for xt = 0, X_SIZE - 1 do
			bricks[t].x = 100 + xt * BSIZE
			bricks[t].y = 100 + yt * BSIZE
			t = t + 1
		end
	end
	t = 0
	for yt = 0, Y_SIZE - 1 do
		for xt = 0, X_SIZE - 1 do
			if xt == 0 then
				self:MakeRandomEdge(t, 3)
				self:MakeNabo(t, 1, t + 1, 3)
			elseif xt == X_SIZE - 1 then
				self:MakeRandomEdge(t, 1)
			else
				self:MakeNabo(t, 1, t + 1, 3)
			end
			if yt == 0 then
				self:MakeRandomEdge(t, 0)
				self:MakeNabo(t, 2, t + X_SIZE, 0)
			elseif yt == Y_SIZE - 1 then
				self:MakeRandomEdge(t, 2)
			else
				self:MakeNabo(t, 2, t + X_SIZE, 0)
			end
			t = t + 1
		end
	end
	-- scatter and turn them (replaceThem / rotateThem)
	t = 0
	for yt = 0, Y_SIZE - 1 do
		for xt = 0, X_SIZE - 1 do
			local b = bricks[t]
			b.x = 70 + math.random() * 450
			b.y = 70 + math.random() * 250
			if math.random() > 0.8 then
				self:RotateBrick(t)
				b.mcRot = b.rot * 90
				if math.random() > 0.65 then
					self:RotateBrick(t)
					b.mcRot = b.rot * 90
					if math.random() > 0.4 then
						self:RotateBrick(t)
						b.mcRot = b.rot * 90
					end
				end
			end
			for s = 0, 3 do b.mcs[s].blink = false end
			t = t + 1
		end
	end
end

function G:Loop()
	local st = self.state
	if st == "brandnew" then
		self.state = "LOADINGGAME"
	elseif st == "LOADINGGAME" then
		self:InitGame()
		self.state = "LOADINGLEVEL"
	elseif st == "LOADINGLEVEL" then
		self.state = "READY"
	elseif st == "READY" then
		self.state = "RUNNING"
	elseif st == "RUNNING" then
		self:Draw()
	end
end

function G:Draw()
	if self.state == "RUNNING" then self:UpdateTimeDisp() end
	if self.dragging then
		local b = self.bricks[self.draggedID]
		self.shadowX, self.shadowY = b.x, b.y
	end
	if self.rotating then
		self.rotCount = self.rotCount + 1
		local b = self.bricks[self.selected]
		if b then
			b.mcRot = b.mcRot + 90 / ROT_FRAMES
			b.lineF = math.min(b.rot * 10 + self.rotCount, 41)
		end
		self.shadowRot = self.shadowRot + 90 / ROT_FRAMES
		if self.rotCount > ROT_FRAMES then
			self.rotating = false
			self.rotCount = 1
			if b then self:RotateBrick(self.selected) end
		end
	end
end

function G:UpdateTimeDisp()
	self.playingTime = RealTime() - self.startTime
	local pt = self.playingTime
	local ms = math.floor(pt % 1 * 100)
	local rest = math.floor(pt)
	local seconds = rest % 60
	rest = math.floor((rest - seconds) / 60)
	local minutes = rest % 60
	rest = math.floor((rest - minutes) / 60)
	local hours = rest % 24
	self.txt.mSecTxt = padFix(ms)
	self.txt.secTxt = padFix(seconds)
	self.txt.minTxt = padFix(minutes)
	self.txt.hourTxt = padFix(hours)
end

-- a tile is pressed (klikket) / let go (sluppet)
function G:Klikket(id, mx, my)
	if self.rotating then return end
	local b = self.bricks[id]
	MG.Sound("g21", "lift")
	-- swapDepths(1000): the tile that was on top takes this one's place
	for _, o in pairs(self.bricks) do
		if o ~= b and o.depth == 1000 then o.depth = b.depth end
	end
	b.depth = 1000
	self:RemoveAllConnections(id)
	self.dragging = true
	self.draggedID = id
	self.selected = id
	self.drag = { kind = "brick", id = id, dx = b.x - mx, dy = b.y - my }
	UI.BeginDrag({ release = function() self:Sluppet(id) end })
end

function G:Sluppet(id)
	self.dragging = false
	self.drag = nil
	self.shadowX = -10000
	MG.Sound("g21", "place")
	self:CheckPlacement(id)
end

function G:CheckPlacement(id)
	local bricks = self.bricks
	local off = { [0] = { 0, -BSIZE }, { BSIZE, 0 }, { 0, BSIZE }, { -BSIZE, 0 } }
	local me = bricks[id]
	local pos = {}
	for t = 0, 3 do pos[t] = { off[t][1] + me.x, off[t][2] + me.y } end
	local closestDist, closestID, closestDir = 1000, -99, -99
	local nabo, naboDir = {}, {}
	for t = 0, self.nb - 1 do
		if t ~= id then
			local o = bricks[t]
			local d = math.abs(me.x - o.x) + math.abs(me.y - o.y)
			if d < 2 * (BSIZE + SNAP) then
				for k = 0, 3 do
					d = math.abs(pos[k][1] - o.x) + math.abs(pos[k][2] - o.y)
					if d < SNAP then
						nabo[#nabo + 1] = t
						naboDir[#naboDir + 1] = k
						if d < closestDist then
							closestDist, closestID, closestDir = d, t, k
						end
					end
				end
			end
		end
	end
	if closestID >= 0 then
		me.x = bricks[closestID].x - off[closestDir][1]
		me.y = bricks[closestID].y - off[closestDir][2]
		for i = 1, #nabo do
			local negDir = naboDir[i] + 2
			if negDir > 3 then negDir = negDir - 4 end
			local dragSide = me.sides[naboDir[i]]
			local snapSide = bricks[nabo[i]].sides[negDir]
			local typeMatch = dragSide.type == snapSide.type
			local endMatch = dragSide["end"] ~= snapSide["end"]
			if dragSide.type < 0 or snapSide.type < 0 then typeMatch = false end
			if typeMatch and endMatch then
				self:SetConnection(id, naboDir[i], nabo[i], negDir)
			end
		end
	end
	if self.connections >= self.required then
		self.timeTotal = math.floor(self.playingTime * 1000 + 0.5)
		self.state = "GAMEOVER"
		self.score = self.timeTotal
		self.signF = 2
		MG.Sound("g21", "sign")
	end
end

function G:StartRotatingBrick()
	self.rotating = true
	MG.Sound("g21", "rotate")
	if self.selected and self.bricks[self.selected] then self:RemoveAllConnections(self.selected) end
end

function G:RotateBrick(id)
	local b = self.bricks[id]
	if not b then return end
	b.rot = b.rot + 1
	if b.rot > 3 then b.rot = b.rot - 4 end
	local s = b.sides
	local tmp = { type = s[3].type, e = s[3]["end"], state = s[3].state }
	for t = 2, 0, -1 do
		s[t + 1].type, s[t + 1]["end"], s[t + 1].state = s[t].type, s[t]["end"], s[t].state
	end
	s[0].type, s[0]["end"], s[0].state = tmp.type, tmp.e, tmp.state
	for t = 0, 3 do
		local mcNum = t - b.rot
		if mcNum < 0 then mcNum = mcNum + 4 end
		s[t].mc = mcNum
	end
	if not self.dragging then self:CheckPlacement(id) end
end

function G:SetConnection(id, mySide, naboID, naboSide)
	local b = self.bricks[id]
	local s = b.sides[mySide]
	if s.connected == 1 then self:RemoveConnection(id, mySide) end
	s.connected, s.brickID, s.sideID = 1, naboID, naboSide
	if s.mc then b.mcs[s.mc].blink = true end
	local o = self.bricks[naboID].sides[naboSide]
	o.connected, o.brickID, o.sideID = 1, id, mySide
	if o.mc then self.bricks[naboID].mcs[o.mc].blink = true end
	self.connections = self.connections + 1
end

function G:RemoveConnection(id, sideID)
	local b = self.bricks[id]
	local s = b.sides[sideID]
	s.connected = 0
	if s.mc then b.mcs[s.mc].blink = false end
	local nb = self.bricks[s.brickID]
	if nb then
		local o = nb.sides[s.sideID]
		if o then
			o.connected = 0
			if o.mc then nb.mcs[o.mc].blink = false end
		end
	end
	self.connections = self.connections - 1
end

function G:RemoveAllConnections(id)
	local b = self.bricks[id]
	for t = 0, 3 do
		if b.sides[t].connected == 1 then self:RemoveConnection(id, t) end
	end
end

---------------------------------------------------------------------------
-- frame loop
---------------------------------------------------------------------------
function G:Step()
	if not self.overF then self:Loop() end
	-- the "Godt klaret!" clip; on its frame 51 the root goes to "game over"
	if self.signF and not self.overF then
		self.signF = self.signF + 1
		if self.signF >= 51 then self:GameOverBoard() end
	end
	if self.overF then
		self.overF = self.overF + 1
		if self.overF >= OVER_FRAMES then self:Finish() end
	end
end

function G:GameOverBoard()
	if self.overF then return end
	self.overF = 0
	self.drag = nil
	UI.drag = nil
	AN.Speak("gameover")
end

-- the mouse in the table clip's coordinates
function G:MainMouse()
	local mx, my = MG.Mouse()
	return mx - self.mainX, (my - self.mainY) / 1.003
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	-- startDrag: the dragged tile / table follows the mouse
	if self.drag and MG.k then
		if self.drag.kind == "brick" then
			local b = self.bricks[self.drag.id]
			local mx, my = self:MainMouse()
			b.x, b.y = mx + self.drag.dx, my + self.drag.dy
		else
			local mx, my = MG.Mouse()
			self.mainX, self.mainY = mx + self.drag.dx, my + self.drag.dy
		end
	end
	-- the space bar turns the selected tile (onClipEvent keyDown)
	local down = input.IsKeyDown(KEY_SPACE)
	if down and not self.spaceWas and not self.overF and self.state ~= "brandnew" and self.state ~= "LOADINGGAME" then
		self:StartRotatingBrick()
	end
	self.spaceWas = down
end

function G:Press(sx, sy)
	if self.overF or not self.bricks[0] then return end
	local mx, my = MG.Mouse()
	local ix, iy = self:MainMouse()
	-- the topmost tile under the mouse
	local order = {}
	for _, b in pairs(self.bricks) do order[#order + 1] = b end
	table.sort(order, function(a, b) return a.depth > b.depth end)
	for _, b in ipairs(order) do
		local a = math.rad(-b.mcRot)
		local dx, dy = ix - b.x, iy - b.y
		local lx, ly = dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)
		if lx >= -HALF and lx <= 39.95 and ly >= -HALF and ly <= 39.95 then
			self:Klikket(b.id, ix, iy)
			return
		end
	end
	-- the table itself
	if ix >= BG_HIT[1] and ix <= BG_HIT[3] and iy >= BG_HIT[2] and iy <= BG_HIT[4] then
		self.drag = { kind = "main", dx = self.mainX - mx, dy = self.mainY - my }
		UI.BeginDrag({ release = function() self.drag = nil end })
	end
end

-- hint (6 seconds): where one tile goes - a box at its place next to the tile that is best joined
-- up so far, an arrow there, and how many times to turn it (space). +5 seconds on the clock.
function G:HintTarget()
	local bricks = self.bricks
	if not bricks[0] then return nil end
	local function conns(b) local n = 0 for k = 0, 3 do if b.sides[k].connected == 1 then n = n + 1 end end return n end
	local anchor
	for t = 0, self.nb - 1 do
		local b = bricks[t]
		if not anchor or conns(b) > conns(anchor) then anchor = b end
	end
	local k = anchor.rot
	local function place(b)
		local dx, dy = b.xID - anchor.xID, b.yID - anchor.yID
		for _ = 1, k do dx, dy = -dy, dx end
		return anchor.x + dx * BSIZE, anchor.y + dy * BSIZE
	end
	local best
	for t = 0, self.nb - 1 do
		local b = bricks[t]
		if b ~= anchor then
			local tx, ty = place(b)
			local done = math.abs(b.x - tx) < 2 and math.abs(b.y - ty) < 2 and b.rot == anchor.rot
			if not done and (not best or conns(b) < conns(best.b)) then best = { b = b, x = tx, y = ty, turns = (anchor.rot - b.rot) % 4 } end
		end
	end
	return best
end
function G:CanHint() return self.state == "RUNNING" and not self.overF and not self.signF and not self.dragging and self:HintTarget() ~= nil end
function G:Hint(cost)
	self.hintT = 6
	self.startTime = self.startTime - cost   -- the clock jumps 5 seconds
	MG.Pop("+" .. cost .. " s", false, 300, 40)
end
function G:HintDraw()
	if not self.hintT or not self.lastMainM then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.state ~= "RUNNING" or self.overF then self.hintT = nil return end
	local h = self:HintTarget()
	if not h then self.hintT = nil return end
	local a = math.min(1, self.hintT * 2)
	local m = self.lastMainM
	local tx, ty = TL.Apply(m, h.x, h.y)
	local bx, by = TL.Apply(m, h.b.x, h.b.y)
	local half = BSIZE / 2 * math.abs(m[1])
	MG.HintBox(tx - half, ty - half, half * 2, half * 2, MG.HINT_GOLD, a, 3)
	local d = math.sqrt((tx - bx) ^ 2 + (ty - by) ^ 2)
	if d > half * 1.2 then
		local ux, uy = (tx - bx) / d, (ty - by) / d
		MG.HintArrow(bx + ux * half * 0.4, by + uy * half * 0.4, tx - ux * half * 0.6, ty - uy * half * 0.6, MG.HINT_GOLD, a, 6)
	end
	if h.turns > 0 then
		MG.HintText(AN.L("g21_hint_turn", h.turns), bx, by - half - 12, MG.HINT_GOLD, 16, a)
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(21, (self.score or 0) / 1000)
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
function G:DrawBrick(b, main)
	local m = TL.Mul(main, rotM(b.mcRot, b.x, b.y))
	pic("brick", m)
	TL.CellM(A.line, A.line.all[b.lineF] or 1, TL.Mul(m, { 0.98, 0, 0, 0.98, 0, 0 }))
	for k = 0, 3 do
		local mc = b.mcs[k]
		if mc.label then pic(mc.label .. (mc.blink and "_on" or "_off"), TL.Mul(m, SIDE_M[k])) end
	end
end

function G:DrawMain(m)
	m = { m[1], m[2], m[3], m[4], m[5] + self.mainX, m[6] + self.mainY }
	self.lastMainM = m
	for _, t in ipairs(TILES) do
		pic("tile", TL.Mul(m, { t[1], 0, 0, t[2], t[3], t[4] }))
	end
	if not self.bricks[0] then return end
	local order = {}
	for _, b in pairs(self.bricks) do order[#order + 1] = b end
	table.sort(order, function(a, b) return a.depth < b.depth end)
	for _, b in ipairs(order) do
		if b.depth == 1000 and self.shadowX > -900 then
			pic("shadow", TL.Mul(m, TL.Mul({ 1, 0, 0, 1, self.shadowX, self.shadowY }, rotM(self.shadowRot, 3.5, 3.55))))
		end
		self:DrawBrick(b, m)
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	local frame = self.overF and 19 or 12
	local scoreStr = scoreToTime(self.score or 0)
	TL.Draw(ROOT, frame, {
		slot = function(name, m)
			if name == "main" then
				self:DrawMain(m)
			elseif name == "endsign" and self.signF and self.signF >= 3 then
				TL.Draw(SIGN, math.min(self.signF, 66), {}, m)
			end
		end,
		value = function(var)
			if var == "scoreString" then return scoreStr end
			return self.txt[var]
		end,
	})

	self:HintDraw()
	MG.DrawPops()

	if self.overF then
		if self.overF > 20 then
			AN.Text(AN.L("g03_click"), "black", math.floor(MG.S(11)), MG.X(300), MG.Y(330), Color(255, 241, 207, 210), 1)
		end
		UI.Button("g21_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:Finish() end, { silent = true })
	else
		UI.Button("g21_table", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), nil,
			{ silent = true, press = function(x, y) self:Press(x, y) end })
	end

	MG.Chrome(21)
end

AN.RegisterGame(21, G)
