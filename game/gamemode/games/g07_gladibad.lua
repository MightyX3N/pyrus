-- Låge 7: Glad i bad
-- Rebuilt from the original loader.swf. Whack-a-mole in the bath: 30 times something pops up out
-- of the water; click it before it dives again. The faster you click, the more points (10 to 26).
-- Every third hit makes them come faster and stay up for a shorter time.
-- The whole original timeline is played with the Flash player; the game code is the original's.
-- The code was written for 26 holes (and a keyboard aim on a 7 x 4 grid), but the bath only has 5:
-- the other 21 never exist, so only those 5 are used, as in the original.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g07_fl.lua")

local G = {
	scoreType = "score",
	goal = 600,       -- the original coolScore
	worst = 0,
	descKey = "desc_07",
	howKey = "how_07",
}

local STAGE_W, STAGE_H = 530, 390
local STEP = 1 / 25
local MS = 40
local LIB = "g07"
local I = { 1, 0, 0, 1, 0, 0 }
local NUM_ANIMALS = 26
local BUTTONS = { [124] = true, [139] = true }

local CUR

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end
local function snd(name) return function() MG.Sound("g07", name) end end

local function setupActions()
	FL.LoadHidden[LIB] = { [116] = true }   -- the figure standing in a closed hole hides itself
	FL.SetActions(LIB, 142, {
		[1] = stop, [20] = stop, [31] = stop, [53] = stop, [56] = stop, [75] = stop, [86] = stop, [108] = stop,
		[7] = snd("bag"), [62] = snd("bag"),
		[23] = snd("splash-long"), [78] = snd("splash-long"),
		[33] = function(c) local x = FL.Child(c, "cross") if x then FL.Play(x) end MG.Sound("g07", "splash-short") end,
		[88] = function(c) local x = FL.Child(c, "cross") if x then FL.Play(x) end MG.Sound("g07", "splash-short") end,
	})
	FL.SetActions(LIB, 120, { [1] = stop })
	FL.SetActions(LIB, 13, { [1] = stop })
	FL.SetActions(LIB, 158, { [23] = stop })
	local hide = { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end }
	FL.SetActions(LIB, 14, hide)
	FL.SetActions(LIB, 18, hide)
	FL.SetActions(LIB, 169, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,
		[13] = function(c) if CUR then CUR.hideMouse = true end end,
		[21] = function(c)
			if CUR then
				CUR.hideMouse = false
				local p = CUR:Clip("mousePointerMc")
				if p then p.visible = false end
			end
			AN.Speak("GameOver")
			FL.Play(c)
		end,
		[97] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Clip(name) return FL.Child(self:Game(), name) end
function G:GameM() return (FL.ChildMatrix(self.root, "game", I)) end

function G:Mouse()
	local sx, sy = MG.Mouse()
	local m = self:GameM()
	local det = m[1] * m[4] - m[2] * m[3]
	local x, y = sx - m[5], sy - m[6]
	return (m[4] * x - m[3] * y) / det, (-m[2] * x + m[1] * y) / det
end

-- the points that pop up over a hit (pointsMC / pointsMCneg, 10 of each)
function G:InitPoints()
	self.points, self.negPoints = {}, {}
	self.nextPoint, self.nextNegPoint = 1, 1
end

function G:SetPoint(val, x, y, hilite)
	local p, s
	if val > 0 then
		p = self.points[self.nextPoint]
		if not p then p = { c = FL.New(LIB, 18) } self.points[self.nextPoint] = p end
		self.nextPoint = self.nextPoint % 10 + 1
		s = math.max(55, math.min(140, val * 6.5)) / 100
	else
		p = self.negPoints[self.nextNegPoint]
		if not p then p = { c = FL.New(LIB, 14) } self.negPoints[self.nextNegPoint] = p end
		self.nextNegPoint = self.nextNegPoint % 10 + 1
		s = 1
	end
	p.m = { s, 0, 0, s, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local hl = FL.Child(p.c, "hilite")
	if hl then FL.GotoAndStop(hl, hilite and "on" or "off") end
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	self.vars.score = 0
	self.level = 1
	self:InitPoints()
	self.state = "waitforgo"
	self.holes = {}
	self.lastLaunch = self.now
	self.numLaunched = 0
	self.numToLaunch = 30
	self.baseAnimInterval = 1150
	self.baseUpTime = 1300
	self.hitCount = 0
	self.hintLeft, self.hintNext = nil, nil
	self:StartLevel()
	self.initialized = true
end

function G:StartLevel()
	self.state = "gameon"
	for t = 0, NUM_ANIMALS - 1 do
		local mc = self:Clip("hole" .. t)
		if mc then
			-- holes 5..25 do not exist in the bath; the original set these fields on nothing
			self.holes[t] = { mc = mc, id = t, state = "closed", sCount = 0, upTime = 0 }
		end
	end
	self.levAnimInterval = self.baseAnimInterval - self.level * 15
	self.levUpTime = self.baseUpTime - self.level * 15
end

function G:LaunchHole(id)
	local h = self.holes[id]
	h.type = math.random(0, 1)
	FL.GotoAndPlay(h.mc, "open" .. h.type)
	h.state = "up"
	h.upTime = self.now
	self.numLaunched = self.numLaunched + 1
end

function G:CloseHole(id)
	local h = self.holes[id]
	FL.GotoAndPlay(h.mc, "down" .. h.type)
	h.state = "down"
end

function G:EndHole(id)
	local h = self.holes[id]
	FL.GotoAndStop(h.mc, "closed")
	h.state = "closed"
	if self.numLaunched >= self.numToLaunch then
		self.state = "gameOver"
		self.stateCount = 0
	end
end

function G:HoleClicked(id)
	local h = self.holes[id]
	if not h then return end
	FL.GotoAndPlay(h.mc, "hit" .. h.type)
	h.state = "hit"
	h.sCount = 0
	local dt = self.now - h.upTime
	local pts = math.Round(math.max(0, (1000 - dt) / 60) + 10)
	local hilite = false
	if pts > 22 then
		hilite = true
		if not AN.IsSpeaking("megetGodt") then AN.Speak("megetGodt") end
	elseif pts > 16 then
		hilite = true
		if not AN.IsSpeaking("Godt") then AN.Speak("Godt") end
	end
	local m = FL.ChildMatrix(self:Game(), "hole" .. id, I)
	self:SetPoint(pts, m[5], m[6] - 80, hilite)
	self.vars.score = self.vars.score + pts
	self.hitCount = self.hitCount + 1
	if self.hitCount > 2 then
		self.level = self.level + 1
		self.levAnimInterval = math.max(50, self.baseAnimInterval - self.level * 130)
		self.levUpTime = math.max(290, self.baseUpTime - self.level * 110)
		self.hitCount = 0
	end
end

function G:MainLoop()
	if not self.initialized or self.state == "waitforgo" then return end
	if self.state == "gameon" then
		local now = self.now
		if self.numLaunched < self.numToLaunch then
			if now - self.lastLaunch > self.levAnimInterval and math.random() > 0.964 then
				-- (hint: the hole shown in advance comes up next)
				local hn = self.hintNext and self.holes[self.hintNext]
				local tries = 20
				if hn and hn.state == "closed" then
					self:LaunchHole(self.hintNext)
					self.lastLaunch = now
					self.hintNext = nil
					self.hintLeft = self.hintLeft - 1
					tries = 0
				end
				-- up to 20 tries at a random hole out of 26 (only 5 exist)
				for _ = 1, tries do
					local r = math.random(0, NUM_ANIMALS - 1)
					local h = self.holes[r]
					if h and h.state == "closed" then
						self:LaunchHole(r)
						self.lastLaunch = now
						break
					end
				end
			end
		end
		self:HintPick()
		for t = 0, NUM_ANIMALS - 1 do
			local h = self.holes[t]
			if h and h.state ~= "closed" then
				if h.state == "up" then
					h.sCount = h.sCount + 1
					if now - h.upTime > self.levUpTime and math.random() > 0.9 then
						self:CloseHole(t)
						h.sCount = 0
					end
				elseif h.state == "down" then
					h.sCount = h.sCount + 1
					if h.sCount > 4 then self:EndHole(t) h.sCount = 0 end
				elseif h.state == "hit" then
					h.sCount = h.sCount + 1
					if h.sCount > 34 then self:EndHole(t) h.sCount = 0 end
				end
			end
		end
	elseif self.state == "gameOver" then
		self.stateCount = self.stateCount + 1
		if self.stateCount == 20 then FL.GotoAndPlay(self.root, "gameover") end
	end
end

---------------------------------------------------------------------------
-- hint: the next 3 holes to pop up glow a moment before they do (the next one is picked in advance)
---------------------------------------------------------------------------
function G:CanHint() return self.initialized and self.state == "gameon" and self.numLaunched < self.numToLaunch end
function G:Hint(cost)
	self.hintLeft = (self.hintLeft or 0) + 3
	self.vars.score = math.max(0, self.vars.score - cost)
	MG.Pop("-" .. cost, false, 265, 60)
end
function G:HintPick()
	if not self.hintLeft or self.hintLeft <= 0 or self.numLaunched >= self.numToLaunch then self.hintNext = nil return end
	local cur = self.hintNext and self.holes[self.hintNext]
	if cur and cur.state == "closed" then return end
	local free = {}
	for t = 0, NUM_ANIMALS - 1 do
		local h = self.holes[t]
		if h and h.state == "closed" then free[#free + 1] = t end
	end
	self.hintNext = #free > 0 and free[math.random(#free)] or nil
end
function G:HintDraw()
	if not self.hintNext or self.state ~= "gameon" then return end
	local m = FL.PathClip(self.root, { "game", "hole" .. self.hintNext })
	if not m then return end
	MG.HintRing(m[5], m[6] - 30, 46, MG.HINT_GOLD)
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g07_status", self.vars and self.vars.score or 0, self.numLaunched or 0, 30)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.initialized = false
	self.numLaunched = 0
	self.hideMouse = false
	self.vars = { score = 0 }
	self.points, self.negPoints = {}, {}
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
	FL.Tick(self.root)
	for _, p in ipairs(self.points) do if p.c.visible then FL.Tick(p.c) end end
	for _, p in ipairs(self.negPoints) do if p.c.visible then FL.Tick(p.c) end end
	self:MainLoop()
	-- the game's own pointer follows the mouse while the mouse is hidden
	if self.hideMouse and MG.x0 and self:Game() then
		local mx, my = self:Mouse()
		if mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H then
			local m, k = FL.ChildMatrix(self:Game(), "mousePointerMc", I)
			if k then k.mat = { m[1], m[2], m[3], m[4], mx, my } end
		end
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
	AN.FinishGame(7, self.vars.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(7) return end
	local game = self:Game()
	if game then
		local extra = {}
		for _, p in ipairs(self.points) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		for _, p in ipairs(self.negPoints) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "totaltxt" then return AN.L("g07_v_total", st.numLaunched or 0, 30) end
		if name == "scoretxt" then return st.initialized and st.vars.score or nil end
		if name == "fps" then return "" end
		return st.vars[name]
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	local mx, my = MG.Mouse()
	local inside = mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H
	self:ShowCursor(not (self.hideMouse and inside))
	-- the buttons inside the holes (there while something is up or diving)
	if game and self.root.frame < 21 then
		local gm = self:GameM()
		for t = 0, 4 do
			local m, hole = FL.ChildMatrix(game, "hole" .. t, gm)
			if hole then
				local btn, bm = FL.CharItem(hole, m, BUTTONS)
				local x0, y0, x1, y1
				if btn then x0, y0, x1, y1 = FL.Bounds(btn, bm, true) end
				if x0 then
					UI.Button("g07_hole" .. t, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:HoleClicked(t) end, { silent = true, hit = FL.HitFn(btn, bm) })
				end
			end
		end
	end
	if self.root.frame >= 21 and self.root.frame < 96 then
		UI.Button("g07_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(7)
end

AN.RegisterGame(7, G)
