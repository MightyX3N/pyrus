-- Låge 13: Brandslukning
-- Rebuilt from the original loader.swf. Fires break out in the windows of the house; click a fire
-- to put it out with the hose. The faster you click it after it starts, the more points (10 to 26).
-- Every burning fire blackens the house a little each frame (the meter in the corner); when the
-- house is completely sooted, the game is over. The fires come faster and faster.
-- The game code is the original's (the same whack-a-mole engine as door 7), quirks included:
--   * the code is written for 26 windows on a 7 x 4 grid, but the house has 16, so a new fire only
--     starts when one of up to 20 random picks hits a window that exists and isn't burning
--   * the keyboard aim is set up but never moved (the key handler is empty)
--   * the "water left" bar and the extra sounds (whistle, tick, tock, buzz) are never used
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g13_fl.lua")

local G = {
	scoreType = "score",
	goal = 700,       -- the original coolScore
	worst = 0,
	descKey = "desc_13",
	howKey = "how_13",
}

local STAGE_W, STAGE_H = 530, 390
local STEP = 1 / 25
local MS = 40
local LIB = "g13"
local I = { 1, 0, 0, 1, 0, 0 }
local NUM_ANIMALS = 26
local BUTTONS = { [129] = true }

local CUR

---------------------------------------------------------------------------
-- the windows' own sound (a sound stream in the hole clip: the fire, the fire going down, the water)
---------------------------------------------------------------------------
local function stopStream(h)
	if h.snd and IsValid(h.snd.ch) then h.snd.ch:Stop() end
	h.snd = nil
end

local function playStream(h, name)
	stopStream(h)
	local v = (AN.Save.Get("vol_fx") or 85) / 100
	if v <= 0 or AN.SoundMode() == 2 then return end
	local token = {}
	h.snd = token
	sound.PlayFile("sound/alletidersnisse/g13/" .. name .. ".mp3", "noplay", function(ch)
		if not IsValid(ch) then return end
		if h.snd ~= token or not CUR then ch:Stop() return end
		ch:SetVolume(v)
		ch:Play()
		token.ch = ch
	end)
end

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.LoadHidden[LIB] = { [111] = true, [139] = true }
	local function hole(c) return c.holeRef end
	FL.SetActions(LIB, 134, {
		[1] = function(c) stop(c) if hole(c) then stopStream(hole(c)) end end,
		[9] = function(c) if hole(c) then playStream(hole(c), "fire") end end,
		[37] = stop,
		[40] = function(c) if hole(c) then playStream(hole(c), "down") end end,
		[46] = stop,
		[47] = function(c)
			local x = FL.Child(c, "cross")
			if x then FL.Play(x) end
			if hole(c) then playStream(hole(c), "hit") end
		end,
		[53] = stop,
	})
	for _, cid in ipairs({ 115, 14, 154, 174, 20, 26, 55, 66, 71, 76 }) do
		FL.SetActions(LIB, cid, { [1] = stop })
	end
	FL.SetActions(LIB, 133, { [35] = stop })
	FL.SetActions(LIB, 166, { [23] = stop })
	FL.SetActions(LIB, 127, { [24] = function(c) FL.GotoAndPlay(c, "loop") end })
	local hide = { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end }
	FL.SetActions(LIB, 9, hide)
	FL.SetActions(LIB, 21, hide)
	FL.SetActions(LIB, 176, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,
		[13] = function(c) if CUR then CUR.hideMouse = true end end,
		[21] = function(c)
			if CUR then
				CUR.hideMouse = false
				for _, h in pairs(CUR.holes or {}) do stopStream(h) end
			end
			AN.Speak("GameOver")
		end,
		[99] = function(c) stop(c) if CUR then CUR:Finish() end end,
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

function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	if not p then p = { c = FL.New(LIB, 9) } self.points[self.nextPoint] = p end
	self.nextPoint = self.nextPoint % 10 + 1
	local s = math.max(55, math.min(140, val * 6.5)) / 100
	p.m = { s, 0, 0, s, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	self.vars.score = 0
	self.level = 1
	self.points = {}
	self.nextPoint = 1
	self.state = "waitforgo"
	self.holes = {}
	self.lastLaunch = self.now
	self.numLaunched = 0
	self.baseAnimInterval = 100
	self.baseUpTime = 7000
	-- initializeAim: the aim is sent to window 16, which doesn't exist (setting _x to undefined does
	-- nothing in Flash), so it stays outside the stage
	self:StartLevel()
	self.initialized = true
end

function G:StartLevel()
	self.state = "gameon"
	for t = 0, NUM_ANIMALS - 1 do
		local mc = self:Clip("hole" .. t)
		if mc then
			local h = { mc = mc, id = t, state = "closed", sCount = 0, upTime = 0 }
			mc.holeRef = h
			self.holes[t] = h
		end
	end
	self.levAnimInterval = self.baseAnimInterval - self.level * 15
	self.levUpTime = self.baseUpTime - self.level * 15
	self.energy = 1000
end

function G:LaunchHole(id)
	local h = self.holes[id]
	FL.GotoAndPlay(h.mc, "open")
	h.state = "up"
	h.upTime = self.now
	self.numLaunched = self.numLaunched + 1
	self.levAnimInterval = self.baseAnimInterval - self.level * 15 - self.numLaunched * 6
	self.levUpTime = self.baseUpTime - self.level * 15 - self.numLaunched * 3
end

function G:CloseHole(id)
	local h = self.holes[id]
	FL.GotoAndPlay(h.mc, "down")
	h.state = "down"
end

function G:EndHole(id)
	local h = self.holes[id]
	FL.GotoAndStop(h.mc, "closed")
	h.state = "closed"
end

-- hint (5 seconds): the window that will catch fire next glows (picked in advance)
function G:CanHint() return self.initialized and self.state == "gameon" end
function G:Hint(cost)
	self.hintT = 5
	self.vars.score = math.max(0, self.vars.score - cost)
	MG.Pop("-" .. cost, false, 300, 60)
end
function G:HintPick()
	if self.hintT then
		self.hintT = self.hintT - STEP
		if self.hintT <= 0 then self.hintT, self.hintNext = nil, nil return end
	else
		self.hintNext = nil
		return
	end
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
	local _, _, x0, y0, x1, y1 = FL.PathClip(self.root, { "game", "hole" .. self.hintNext })
	if not x0 then return end
	-- (a closed window's clip is only its sill: the box covers the window above it)
	local cx = (x0 + x1) / 2
	MG.HintBox(cx - 30, y1 - 58, 60, 62, MG.HINT_GOLD, math.min(1, self.hintT * 2), 3)
end

function G:HoleClicked(id)
	local h = self.holes[id]
	if not h then return end
	FL.GotoAndPlay(h.mc, "hit")
	h.state = "hit"
	h.sCount = 0
	local p = self:Clip("mousePointerMc")
	local anim = p and FL.Child(p, "anim")
	if anim then FL.Play(anim) end
	local dt = self.now - h.upTime
	local pts = math.Round(math.max(0, (1000 - dt) / 60) + 10)
	local m = FL.ChildMatrix(self:Game(), "hole" .. id, I)
	self:SetPoint(pts, m[5], m[6] - 80)
	self.vars.score = self.vars.score + pts
end

function G:MainLoop()
	if not self.initialized or self.state == "waitforgo" then return end
	if self.state == "gameon" then
		local now = self.now
		if now - self.lastLaunch > self.levAnimInterval and math.random() > 0.964 then
			-- (hint: the window shown in advance catches fire next)
			local hn = self.hintNext and self.holes[self.hintNext]
			local tries = 20
			if hn and hn.state == "closed" then
				self:LaunchHole(self.hintNext)
				self.lastLaunch = now
				self.hintNext = nil
				tries = 0
			end
			-- up to 20 tries at a random window out of 26 (only 16 exist)
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
		self:HintPick()
		for t = 0, NUM_ANIMALS - 1 do
			local h = self.holes[t]
			if h and h.state ~= "closed" then
				if h.state == "up" then
					self.energy = self.energy - 1
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
		-- the soot on the house, and the meter
		local bg = FL.Child(self.root, "bg")
		local sod = bg and FL.Child(bg, "sod")
		if sod then FL.GotoAndStop(sod, math.floor((1000 - self.energy) / 150) + 1) end
		if self.energy <= 0 then
			self.energy = 0
			self.state = "gameOver"
			self.stateCount = 0
		end
		self:SetMeter()
	elseif self.state == "gameOver" then
		self.stateCount = self.stateCount + 1
		if self.stateCount > 20 then
			self.state = "over"
			FL.GotoAndPlay(self.root, "gameover")
		end
	end
end

-- tube.daMask._xscale = energy / 10 (the mask is mirrored, so it shrinks towards its right edge)
function G:SetMeter()
	local tube = FL.Child(self.root, "tube")
	local mask = tube and FL.Child(tube, "daMask")
	if mask then mask.mat = { -self.energy / 1000, 0, 0, 1, 80.75, 0 } end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g13_status", self.vars and self.vars.score or 0, math.floor((self.energy or 1000) / 10))
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.initialized = false
	self.energy = 1000
	self.hideMouse = false
	self.vars = { score = 0 }
	self.points = {}
	self.holes = {}
	self.root = FL.New(LIB, 0)
end

function G:Close()
	for _, h in pairs(self.holes or {}) do stopStream(h) end
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
	self:MainLoop()
	-- the hose follows the mouse while the mouse is hidden
	if self.hideMouse and MG.x0 and self:Game() then
		local mx, my = MG.Mouse()
		if mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H then
			local gx, gy = self:Mouse()
			local m, k = FL.ChildMatrix(self:Game(), "mousePointerMc", I)
			if k then k.mat = { m[1], m[2], m[3], m[4], gx, gy } end
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
	AN.FinishGame(13, self.vars.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(13) return end
	local game = self:Game()
	if game then
		local extra = {}
		for _, p in ipairs(self.points) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "scoretxt" then return st.initialized and AN.L("g13_v_score", st.vars.score) or nil end
		return st.vars[name]
	end
	FL.Draw(self.root, I)
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	local mx, my = MG.Mouse()
	local inside = mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H
	self:ShowCursor(not (self.hideMouse and inside))
	-- the buttons in the windows (there while a fire burns, and as it goes down), in depth order
	if game and self.root.frame < 21 then
		local gm = self:GameM()
		for _, it in ipairs(FL.Items(game)) do
			local id = it.nm and tonumber(string.match(it.nm, "^hole(%d+)$"))
			if id then
				local m, hole = FL.ChildMatrix(game, it.nm, gm)
				local btn, bm = FL.CharItem(hole, m, BUTTONS)
				local x0, y0, x1, y1
				if btn then x0, y0, x1, y1 = FL.Bounds(btn, bm, true) end
				if x0 then
					UI.Button("g13_hole" .. id, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:HoleClicked(id) end, { silent = true, hit = FL.HitFn(btn, bm) })
				end
			end
		end
	end
	if self.root.frame >= 21 and self.root.frame < 97 then
		UI.Button("g13_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(13)
end

AN.RegisterGame(13, G)
