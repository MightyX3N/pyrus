-- Låge 5: Snup en Switch
-- Rebuilt from the original loader.swf. A maze on a circuit board: click START, then steer the red
-- ring with the mouse and snatch the 8 green gadgets (each one is put at one of 4 places, chosen at
-- random every round). Each gadget gives more time; with all 8 taken, touching START again gives a
-- big time bonus and a new round. Touching any part of the board's pattern, or running out of time,
-- ends the game. The points are the milliseconds you lasted.
-- The whole original timeline is played with the Flash player; the game code is the original's,
-- with the same numbers (and the same quirks: from round 9 on a gadget takes time instead of
-- giving it, and the background goes green -> blue -> red as time runs out).
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g05_fl.lua")
include(DIR .. "g05_mask.lua")

local G = {
	scoreType = "score",
	goal = 50000,     -- the original coolScore
	worst = 0,
	descKey = "desc_05",
	howKey = "how_05",
}

local STAGE_W, STAGE_H = 720, 450
local STEP = 1 / 25
local MS = 40
local LIB = "g05"
local I = { 1, 0, 0, 1, 0, 0 }

local CUR

---------------------------------------------------------------------------
-- the wall mask (shape 113 inside the "map" clip)
---------------------------------------------------------------------------
local MASK
local function mask()
	if MASK then return MASK end
	local M = AN.G05Mask
	local B = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/"
	local val = {}
	for i = 1, 64 do val[string.byte(B, i)] = i - 1 end
	local rows = {}
	local y = 0
	for line in string.gmatch(M.rows .. "\n", "([^\n]*)\n") do
		if y > 0 or line ~= "" or #rows > 0 then
			local runs = {}
			for i = 1, #line - 1, 2 do
				runs[#runs + 1] = val[string.byte(line, i)] * 64 + val[string.byte(line, i + 1)]
			end
			rows[#rows + 1] = runs
			y = y + 1
		end
	end
	MASK = { rows = rows, def = M }
	return MASK
end

-- is the point (in shape 113's own coordinates) on the board's pattern?
local function onWall(x, y)
	local m = mask()
	local d = m.def
	local px = math.floor((x - d.x0) / d.sx)
	local py = math.floor((y - d.y0) / d.sy)
	local r = m.rows[py + 1]
	if not r then return false end
	for i = 1, #r - 1, 2 do
		if px >= r[i] and px < r[i + 1] then return true end
		if px < r[i] then return false end
	end
	return false
end

local function inverse(m)
	local det = m[1] * m[4] - m[2] * m[3]
	if math.abs(det) < 1e-9 then return nil end
	local a, b, c, d = m[4] / det, -m[2] / det, -m[3] / det, m[1] / det
	return { a, b, c, d, -(a * m[5] + c * m[6]), -(b * m[5] + d * m[6]) }
end

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 10, { [1] = stop })                                         -- the points' "hilite"
	FL.SetActions(LIB, 11, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })   -- pointsMC
	-- START (its pop-in sound is a sound stream in the clip, frames 2-10)
	FL.SetActions(LIB, 127, { [2] = function() MG.Sound("g05", "start") end, [10] = stop })
	FL.SetActions(LIB, 133, { [13] = stop })                                       -- the gadget splash
	FL.SetActions(LIB, 138, { [23] = stop })                                       -- a trail piece
	FL.SetActions(LIB, 140, { [1] = stop, [5] = stop, [11] = stop })               -- tick / tock
	FL.SetActions(LIB, 143, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,   -- startNewGame once everything is loaded
		[21] = function(c)
			if CUR then CUR.hideMouse = false end
			AN.Speak("GameOver")
			FL.Play(c)
		end,
		[99] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers for the game clip's children
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Clip(name) return FL.Child(self:Game(), name) end

-- the stage matrix of the game clip
function G:GameM()
	return (FL.ChildMatrix(self.root, "game", I))
end

-- _x / _y of a child of the game clip (keeps its scale and rotation)
function G:SetPos(name, x, y)
	local m, k = FL.ChildMatrix(self:Game(), name, I)
	if not k then return end
	k.mat = { m[1], m[2], m[3], m[4], x, y }
end

function G:SetVisible(name, v)
	local k = self:Clip(name)
	if k then k.visible = v end
end

-- the mouse in the game clip's coordinates (_xmouse / _ymouse)
function G:Mouse()
	local sx, sy = MG.Mouse()
	local inv = inverse(self:GameM())
	if not inv then return sx, sy end
	return TL.Apply(inv, sx, sy)
end

-- map.hitTest(x, y, true): the point (game coordinates) against the board's pattern
function G:MapHit(x, y)
	local m = FL.ChildMatrix(self:Game(), "map", I)
	if not m then return false end
	local inv = inverse(m)          -- shape 113 sits at the map clip's origin
	local lx, ly = TL.Apply(inv, x, y)
	return onWall(lx, ly)
end

-- clip.hitTest(x, y, true) for the small gadgets and the round START button
function G:ClipHit(name, x, y, round)
	local m, k = FL.ChildMatrix(self:Game(), name, I)
	if not k or not k.visible then return false end
	local x0, y0, x1, y1 = FL.Bounds(k, m, true)
	if not x0 then return false end
	if not round then return x >= x0 and x <= x1 and y >= y0 and y <= y1 end
	local cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
	if rx <= 0 or ry <= 0 then return false end
	local dx, dy = (x - cx) / rx, (y - cy) / ry
	return dx * dx + dy * dy <= 1
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
-- the points that pop up (pointsMC). The original made 35 of them but never showed one; with
-- hidden content on, a gadget or START shows the time it gave.
function G:InitPoints()
	self.points = {}
	self.nextPoint = 1
end

function G:SetPoint(val, x, y, hilite)
	local p = self.points[self.nextPoint]
	if not p then
		p = { c = FL.New(LIB, 11) }
		self.points[self.nextPoint] = p
	end
	local s = math.max(55, math.min(140, val * 0.5)) / 100
	p.m = { s, 0, 0, s, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local hl = FL.Child(p.c, "hilite")
	if hl then FL.GotoAndStop(hl, hilite and "on" or "off") end
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
	self.pointVal = val
	self.nextPoint = self.nextPoint % 35 + 1
end

function G:InitTrails()
	self.lastPos = nil
	self.trails = {}
	self.trailId = 1
	local m, org = FL.ChildMatrix(self:Game(), "trail_org", I)
	self.trailM = m
	for t = 1, 20 do
		local c = FL.New(LIB, 138)
		self.trails[t] = { c = c, m = m and { m[1], m[2], m[3], m[4], m[5], m[6] } or I, cx = org and true }
	end
end

function G:AddTrail(x, y)
	if not self.lastPos then
		self.lastPos = { x, y }
		return
	end
	local lx, ly = self.lastPos[1], self.lastPos[2]
	local t = self.trails[self.trailId]
	-- _rotation: the angle from the new point back to the last one; _xscale: the distance + 0.5
	local dx, dy = lx - x, ly - y
	local len = math.sqrt(dx * dx + dy * dy)
	local ang = len > 0 and math.atan2(dy, dx) or 0
	local sx = (len + 0.5) / 100
	local sy = 1
	local co, si = math.cos(ang), math.sin(ang)
	t.m = { co * sx, si * sx, -si * sy, co * sy, x, y }
	FL.GotoAndPlay(t.c, 1)
	self.trailId = self.trailId % 20 + 1
	self.lastPos = { x, y }
end

-- the background colour: green while there are 5 seconds or more left, then towards blue, then red
local GREEN, YELLOW, RED = { 10, 126, 103 }, { 36, 32, 202 }, { 255, 0, 0 }
local function cycleColour(energy)
	local a, b, f
	if energy > 50 then
		a, b, f = YELLOW, GREEN, (energy - 50) / 50
	else
		a, b, f = RED, YELLOW, energy / 50
	end
	return math.floor(a[1] + (b[1] - a[1]) * f), math.floor(a[2] + (b[2] - a[2]) * f), math.floor(a[3] + (b[3] - a[3]) * f)
end

-- mapCol.setRGB: the background clip (a plain rectangle over the whole stage) becomes one colour.
-- It is drawn as a filled rectangle under the game clip (a tinted picture can't turn teal into red).
function G:SetBg(r, g, b)
	self.bgCol = Color(r, g, b)
end

function G:SelectCheese()
	self.active = {}
	for c = 0, 7 do
		local name = "cheese" .. c .. "_" .. math.random(0, 3)
		self.active[#self.active + 1] = name
		self:SetVisible(name, true)
	end
end

function G:Init()
	-- soundplayer.playSound("whistle_1"): that sound was never added to the game's sound module
	self.score = 0
	self:InitPoints()
	self.state = "waitforgo"
	self:SetVisible("cursor", false)
	self:SetVisible("wallhit", false)
	self:SetVisible("cheesehit", false)
	self.numCheese = 8
	self.cheeseLeft = 8
	self.subState = "cheese"
	for c = 0, 7 do
		for t = 0, 3 do self:SetVisible("cheese" .. c .. "_" .. t, false) end
	end
	self:SelectCheese()
	self:InitTrails()
end

function G:GoAreaClicked()
	FL.GotoAndStop(self:Clip("go"), "off")
	self.state = "gameon"
	self.startTime = self.now
	self:SetVisible("cursor", true)
	self.hideMouse = true
	self.lastTick = "tock"
	self.nextTick = 20
	self.totalTime = 15000
	self.level = 0
	self.roundStart = 0
	self.hintPenalty = 0
	self.hintLeft = nil
end

function G:CheeseHit(x, y)
	self:SetVisible("cheesehit", true)
	self:SetPos("cheesehit", x, y)
	FL.GotoAndPlay(self:Clip("cheesehit"), 1)
end

function G:MainLoop()
	local st = self.state
	if st == "gameon" then
		local t = self.now - self.startTime
		if t > self.totalTime then
			MG.Sound("g05", "buzz")
			self.state = "timeout"
			self.sCount = 0   -- (the original never reset this; it was 0 or nil anyway)
		end
		self.score = math.max(0, t - (self.hintPenalty or 0))
		self.vars.score = self.score
		local timeLeft = math.Round(self.totalTime - t)
		self.timeLeft = timeLeft
		local energy = math.max(0, math.min(100, 100 * (timeLeft / 5000)))
		self:SetBg(cycleColour(energy))
		local mx, my = self:Mouse()
		self:SetPos("cursor", mx, my)
		self:AddTrail(mx, my)
		if self:MapHit(mx, my) then
			MG.Sound("g05", "buzz")
			self:SetVisible("cursor", false)
			self:SetVisible("wallhit", true)
			self:SetPos("wallhit", mx, my)
			self.state = "wallhit"
			self.sCount = 0
		end
		self.nextTick = self.nextTick - 1
		if self.nextTick <= 0 then
			self.nextTick = math.ceil(math.max(4, math.min(20, timeLeft / 200)))
			self.lastTick = self.lastTick == "tick" and "tock" or "tick"
			FL.GotoAndPlay(self:Clip("soundmc"), self.lastTick)
		end
		local hidden = AN.Save.Get("hidden") ~= false
		if self.subState == "cheese" then
			for _, name in ipairs(self.active) do
				local k = self:Clip(name)
				if k and k.visible and self:ClipHit(name, mx, my) then
					MG.Sound("ui", "point")
					k.visible = false
					self:CheeseHit(mx, my)
					local bonus = 3800 - self.level * 500
					self.totalTime = self.totalTime + bonus
					if hidden then self:SetPoint(bonus, mx, my, false) end
					self.cheeseLeft = self.cheeseLeft - 1
					if self.cheeseLeft == 0 then
						self.subState = "go"
						FL.GotoAndPlay(self:Clip("go"), "on")
					end
				end
			end
		elseif self.subState == "go" then
			if self:ClipHit("go", mx, my, true) then
				FL.GotoAndStop(self:Clip("go"), "off")
				self:CheeseHit(mx, my)
				local bonus = 6000 - self.level * 500
				self.totalTime = self.totalTime + bonus
				if hidden then self:SetPoint(bonus, mx, my, true) end
				-- a round done: its time into the round's own highscore list (the original kept one
				-- list for the whole game), and the run so far is saved
				local t = math.max(0, math.floor(self.now - self.startTime - (self.hintPenalty or 0)))
				AN.LevelScore(5, self.level + 1, math.max(0, t - (self.roundStart or 0)), { total = t })
				self.roundStart = t
				self.subState = "cheese"
				self.level = self.level + 1
				self.cheeseLeft = self.numCheese
				self:SelectCheese()
			end
		end
	elseif st == "wallhit" or st == "timeout" then
		self.sCount = (self.sCount or 0) + 1
		if self.sCount > 20 then
			self.state = "game over"
			FL.GotoAndStop(self.root, "gameover")
		end
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	local left = (self.state == nil or self.state == "waitforgo") and 15000 or (self.timeLeft or 0)
	return AN.L("g05_status", self.score or 0, math.max(0, left) / 1000)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.score = 0
	self.state = nil
	self.hideMouse = false
	self.vars = { score = 0 }
	self.points, self.trails = {}, {}
	self.root = FL.New(LIB, 0)
	FL.GotoAndStop(self.root, "gameon")
end

function G:Close()
	if CUR == self then CUR = nil end
	self:ShowCursor(true)
end

function G:ShowCursor(show)
	local p = UI.root
	if IsValid(p) and p.SetCursor and self.cursorShown ~= show then
		p:SetCursor(show and "arrow" or "blank")
		self.cursorShown = show
	end
end

function G:Step()
	self.now = self.now + MS
	FL.OnSound = function(c, id)
		if id == 4 then MG.Sound("g05", "tick")
		elseif id == 3 then MG.Sound("g05", "tock")
		elseif id == 1 then MG.Sound("g05", "ticktock")
		elseif id == 2 then MG.Sound("g05", "buzz") end
	end
	FL.Tick(self.root)
	for _, p in ipairs(self.points or {}) do if p.c.visible then FL.Tick(p.c) end end
	for _, t in ipairs(self.trails or {}) do FL.Tick(t.c) end
	FL.OnSound = nil
	self:MainLoop()
	-- the game's own pointer (mousePointerMc) follows the mouse while the mouse is hidden
	if self.hideMouse then
		local mx, my = self:Mouse()
		if mx > 0 and mx < 720 and my > 0 and my < 450 then self:SetPos("mousePointerMc", mx, my) end
	end
end

function G:Think(dt)
	if not self.root then return end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	self:ShowCursor(true)
	AN.FinishGame(5, math.max(0, math.floor(self.score or 0)))
end

-- hint: for 4 seconds the gadgets still to grab are ringed, with an arrow from the ring to the
-- nearest one (or to START once all 8 are taken). Costs time off the score (not off the clock).
function G:CanHint() return self.state == "gameon" end
function G:Hint(cost)
	self.hintPenalty = (self.hintPenalty or 0) + cost
	self.hintLeft = 4
	local mx, my = MG.Mouse()
	MG.Pop("-" .. cost, false, mx, my - 20)
end
function G:HintDraw()
	if not self.hintLeft then return end
	self.hintLeft = self.hintLeft - FrameTime()
	if self.hintLeft <= 0 or self.state ~= "gameon" then self.hintLeft = nil return end
	local a = math.min(1, self.hintLeft * 2)
	local mx, my = MG.Mouse()
	local best, bd
	local targets = {}
	if self.subState == "go" then
		local _, _, x0, y0, x1, y1 = FL.PathClip(self.root, { "game", "go" })
		if x0 then targets[1] = { (x0 + x1) / 2, (y0 + y1) / 2, math.max(x1 - x0, y1 - y0) / 2 } end
	else
		for _, name in ipairs(self.active or {}) do
			local k = self:Clip(name)
			if k and k.visible then
				local _, _, x0, y0, x1, y1 = FL.PathClip(self.root, { "game", name })
				if x0 then targets[#targets + 1] = { (x0 + x1) / 2, (y0 + y1) / 2, math.max(x1 - x0, y1 - y0) / 2 + 4 } end
			end
		end
	end
	for _, t in ipairs(targets) do
		MG.HintRing(t[1], t[2], t[3] + 6, MG.HINT_GOLD, a, 3)
		local d = (t[1] - mx) ^ 2 + (t[2] - my) ^ 2
		if not bd or d < bd then best, bd = t, d end
	end
	if best and bd > (best[3] + 30) ^ 2 then
		local d = math.sqrt(bd)
		local ux, uy = (best[1] - mx) / d, (best[2] - my) / d
		MG.HintArrow(mx + ux * 14, my + uy * 14, best[1] - ux * (best[3] + 10), best[2] - uy * (best[3] + 10), MG.HINT_GOLD, a, 5)
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(5) return end
	local game = self:Game()
	-- the clips the script made: the points (depth 2000+) and the trail (depth 66384+), on top of the game
	if game then
		local extra = {}
		for _, p in ipairs(self.points or {}) do
			if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end
		end
		-- (the copies keep trail_org's colour transform)
		for _, t in ipairs(self.trails or {}) do extra[#extra + 1] = { c = t.c, m = t.m, a = 0.629, col = { 0.512, 0.512, 0.512, 125, 125, 50 } } end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "scoretxt" then return AN.L("g05_v_score", math.floor(st.score or 0)) end
		if name == "timetxt" then
			local left = (st.state == nil or st.state == "waitforgo") and 15000 or (st.timeLeft or 0)
			return AN.L("g05_v_time", string.format("%.1f", math.Round(left / 100) / 10))
		end
		return st.vars[name]
	end
	local bg = game and FL.Child(game, "bg")
	if bg then
		bg.visible = false
		local c = self.bgCol or Color(10, 126, 103)
		surface.SetDrawColor(c.r, c.g, c.b, 255)
		surface.DrawRect(AN.PX(MG.X(0)), AN.SY(MG.Y(0)), AN.SX(MG.S(STAGE_W)), AN.SX(MG.S(STAGE_H)))
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	-- the system mouse is hidden over the board while you play (the original's Mouse.hide)
	local mx, my = MG.Mouse()
	local inside = mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H
	self:ShowCursor(not (self.hideMouse and inside))
	-- START: the button inside the go clip (goAreaClicked) works until the game has started
	if self.state == "waitforgo" and game then
		local m, k = FL.ChildMatrix(game, "go", I)
		local gm = self:GameM()
		local sm = TL.Mul(gm, m)
		local x0, y0, x1, y1 = FL.Bounds(k, sm, true)
		if x0 then
			UI.Button("g05_go", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:GoAreaClicked() end, { silent = true, hit = FL.HitFn(k, sm) })
		end
	end
	-- the game over board: a click anywhere skips to the end
	if self.root.frame >= 21 and self.root.frame < 98 then
		UI.Button("g05_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(5)
end

AN.RegisterGame(5, G)
