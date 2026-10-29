-- Låge 22: Gok i Nødden
-- Rebuilt from the original loader.swf. Andersen sits in the middle; now and then a club comes
-- up on one side of him, and you have to click it before it hits him on the head. The faster you
-- click, the more points (800 minus the frames waited, squared). Every hit makes him 10 years
-- "younger" - he starts at 40, and under 10 the game is over. The game also ends when the time bar
-- is full (50 seconds), which gives up to 1000 points more. The clubs come faster and faster.
-- The game code is the original's, quirks included:
--   * clicking when no club is up is meant to cost 100, 200, 300 ... points, but the sign is wrong,
--     so it ADDS them (the number that pops up still says minus) - and the 7th click in a row
--     knocks Andersen out
--   * the speed meter is placed above the stage, out of sight
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g22_fl.lua")

local G = {
	scoreType = "score",
	goal = 15000,     -- the original coolScore
	worst = 0,
	descKey = "desc_22",
	howKey = "how_22",
}

local STAGE_W, STAGE_H = 520, 420
local STEP = 1 / 25
local LIB = "g22"
local I = { 1, 0, 0, 1, 0, 0 }

-- onClipEvent(load) { _visible = false }: the preloader
FL.LoadHidden[LIB] = { [108] = true }

local CUR

local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 0, {
		[2] = function(c) stop(c) FL.GotoAndStop(c, "gameon") end,    -- the preloader: everything is loaded
		[12] = function(c)
			stop(c)
			if CUR then
				CUR:MainLoad()      -- the main clip's onClipEvent(load)
				CUR:StartNewGame()
			end
		end,
		[23] = function(c) AN.Speak("GameOver") FL.Play(c) end,
		[100] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	FL.SetActions(LIB, 202, {   -- Andersen
		[1] = function(c) FL.GotoAndPlay(c, "idle") end,
		[34] = stop,
		[44] = function(c) FL.Play(c) end,
		[80] = function(c) if CUR then CUR.allowNewHits = true end FL.GotoAndStop(c, "idle") end,
		[126] = function(c) if CUR then CUR.allowNewHits = true end FL.GotoAndStop(c, "idle") end,
		[152] = stop,
	})
	FL.SetActions(LIB, 219, {   -- a club
		[1] = stop,
		[2] = function(c) FL.Play(c) end,
		[11] = stop,
		[38] = function()
			MG.Sound("g22", "miss")   -- the club's own sound (a sound stream from here to frame 55)
			if not AN.IsSpeaking() then AN.Speak("Skidt") end
		end,
		[55] = stop,
		[66] = stop,
	})
	FL.SetActions(LIB, 106, {   -- a points number
		[25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end,
		[50] = function(c) c.visible = false FL.GotoAndStop(c, 1) end,
	})
	FL.SetActions(LIB, 244, { [1] = function(c) if CUR then c.vars.scoretxt = CUR.score end end })
	for cid, f in pairs({ [15] = 1, [44] = 1, [55] = 1, [60] = 1, [65] = 1, [131] = 1, [191] = 24, [197] = 11, [200] = 24, [201] = 24, [227] = 5 }) do
		FL.SetActions(LIB, cid, { [f] = stop })
	end
end

function G:Main() return FL.Child(self.root, "main") end
function G:Ob(i) return FL.Child(self.root, "ob" .. i) end

function G:Status()
	return AN.L("g22_status", self.score or 0, self.curAge or 40)
end

---------------------------------------------------------------------------
-- the original game code (the "main" clip)
---------------------------------------------------------------------------
function G:MainLoad()
	self.points = {}
	for t = 1, 35 do
		local p = FL.New(LIB, 106)
		p.x, p.y = -300, 0
		self.points[t] = p
	end
	self.nextPoint = 1
	self.objs = {}
	self.numObjs = 2
	self.gameState = "none"
	self.mainCount = 0
	self.score = 0
	self.gameStartTime = self.ms
	self.gameTimeMax = 50000
	self.gameTimeCur = 0
	self.timeToDrop = 0
	self.gtFraction = 0
	self.lastSpawnTime = 0
	self.bonusScore = 0
	self.blindClicks = 0
	self.numActObjs = 0
	self.allowNewHits = true
	self.curAge = 40
	self.vars.ageTxt = AN.L("g22_age", self.curAge)
	if not self.speedArr then
		self.avSpeed = 20
		self.speedArr = { 30, 30, 30, 30, 30 }
	end
	for t = 0, self.numObjs - 1 do
		self.objs[t] = { anim = 0, obType = 0, wasSeen = false, startTime = 0, aCount = 0, waitFrames = 0, mc = self:Ob(t),
			timerActive = false, timerCount = 0 }
	end
end

function G:StartNewGame()
	self.score = 0
	self.bonusScore = 0
	self.hintLeft, self.hintNext = nil, nil
	self.gameState = "game"
	local ch = FL.Child(self.root, "char")
	if ch then FL.GotoAndPlay(ch, 1) end
end

-- the clubs' own timers (their onClipEvent(enterFrame))
function G:StartTimer(o) o.timerActive = true o.timerCount = 0 end
function G:EndTimer(o)
	if not o.timerActive then return end
	o.timerActive = false
	self:AddSpeedVal(o.timerCount)
end
function G:TimerLoop(o)
	if o.timerActive then o.timerCount = o.timerCount + 1 end
end

function G:AddSpeedVal(v)
	if #self.speedArr >= 10 then table.remove(self.speedArr, 1) end
	table.insert(self.speedArr, v)
	local s = 0
	for _, x in ipairs(self.speedArr) do s = s + x end
	self.avSpeed = s / #self.speedArr
end

local function an(o) return o.mc and FL.Child(o.mc, "an") end

function G:EndAllObAnims()
	for t = 0, self.numObjs - 1 do
		local o = self.objs[t]
		if o.anim == 1 then
			o.anim = 0
			local a = an(o)
			if a then FL.GotoAndPlay(a, "exit") end
		end
	end
end

-- hint: a "!" shows where each of the next 3 clubs will come up, just before it does
function G:CanHint() return self.gameState == "game" and self.allowNewHits ~= false end
function G:Hint(cost)
	self.hintLeft = (self.hintLeft or 0) + 3
	self.bonusScore = self.bonusScore - cost
	self:SetScore()
	MG.Pop("-" .. cost, false, 260, 80)
end
function G:HintPick()
	if not self.hintLeft or self.hintLeft <= 0 or self.gameState ~= "game" then self.hintNext = nil return end
	local cur = self.hintNext and self.objs[self.hintNext]
	if cur and cur.anim == 0 then return end
	local free = {}
	for t = 0, self.numObjs - 1 do if self.objs[t].anim == 0 then free[#free + 1] = t end end
	self.hintNext = #free > 0 and free[math.random(#free)] or nil
end
function G:HintDraw()
	if not self.hintNext or self.gameState ~= "game" then return end
	local m = FL.PathClip(self.root, { "ob" .. self.hintNext })
	if not m then return end
	-- (the clubs come in from outside the stage: the mark sits at that edge)
	local x = math.Clamp(m[5], 50, STAGE_W - 50)
	MG.HintRing(x, m[6], 34, MG.HINT_BAD, 1, 5)
	MG.HintText("!", x, m[6], MG.HINT_BAD, 40)
end

function G:ObClicked(id, mx, my)
	local o = self.objs[id]
	self:EndTimer(o)
	local a = an(o)
	if a then FL.GotoAndPlay(a, "vanish") end
	o.anim = 0
	local t = o.timerCount * o.timerCount
	local pts = math.max(0, math.Round(800 - t))
	self:SetPoint(pts, mx, my)
	self.bonusScore = self.bonusScore + pts
	local ch = FL.Child(self.root, "char")
	if ch then FL.GotoAndStop(ch, "idle") end
end

function G:ObFired(id)
	if self.gameState ~= "game" then return end
	local o = self.objs[id]
	o.anim = 0
	local a = an(o)
	if a then FL.GotoAndPlay(a, "shoot") end
	local ch = FL.Child(self.root, "char")
	if ch then FL.GotoAndPlay(ch, "d" .. o.obType .. "_" .. id) end
	o.timerCount = o.timerCount + 10
	self:EndTimer(o)
	self.curAge = self.curAge - 10
	self.vars.ageTxt = AN.L("g22_age", self.curAge)
	if self.curAge < 10 then
		self.gameState = "gameover"
		self.mainCount = 0
		self.allowNewHits = false
		self:EndAllObAnims()
	end
end

function G:RestartOb(id)
	local o = self.objs[id]
	o.waitFrames = math.Round(self.avSpeed + 5 + math.random() * 8)
	o.anim = 1
	o.wasSeen = false
	o.startTime = self.gameTimeCur
	o.obType = 0
	if o.mc then FL.GotoAndStop(o.mc, "club") end
end

function G:GameLoop()
	self.gameTimeCur = self.ms - self.gameStartTime
	self.gtFraction = self.gameTimeCur / self.gameTimeMax
	if self.gtFraction == 0 then self.gtFraction = 0.000001 end
	local bar = FL.Child(self.root, "bar")
	if bar then
		for _, it in ipairs(FL.Items(self.root)) do
			if it.nm == "bar" then bar.mat = { self.gtFraction, it[5], it[6], it[7], it[8], it[9] } end
		end
	end
	self.timeToDrop = (1 / (0.45 + self.gtFraction * 0.7)) * 2250 - 1500
	if self.gameTimeCur >= self.gameTimeMax then
		self.gameState = "gameover"
		self.mainCount = 0
		self.allowNewHits = false
		self:EndAllObAnims()
	end
	local n = 0
	for t = 0, self.numObjs - 1 do
		local o = self.objs[t]
		if o.anim == 0 then
			if self.allowNewHits then
				o.aCount = o.aCount + 1
				if o.aCount > 10 and self.gameTimeCur - self.lastSpawnTime > 300 then
					local extra = (self.gameTimeCur - self.lastSpawnTime) / 500000
					if math.random() > 0.985 - extra then
						-- (hint: the club shown in advance is the one that comes)
						local tt = t
						local hn = self.hintNext and self.objs[self.hintNext]
						if hn and hn.anim == 0 then
							tt = self.hintNext
							self.hintNext = nil
							self.hintLeft = self.hintLeft - 1
						end
						self:RestartOb(tt)
						self.objs[tt].anim = 1
					end
				end
			end
		elseif o.anim == 1 then
			n = n + 1
			local a = an(o)
			if a then FL.GotoAndPlay(a, "enter") end
			o.anim = 2
			o.aCount = 0
			self:StartTimer(o)
			self.lastSpawnTime = self.gameTimeCur
		elseif o.anim == 2 then
			n = n + 1
			o.aCount = o.aCount + 1
			if not o.wasSeen and math.random() > 0.65 then
				o.wasSeen = true
				local ch = FL.Child(self.root, "char")
				if ch then FL.GotoAndStop(ch, "look" .. math.random(1, 2) .. "_" .. t) end
			end
			if self.gameTimeCur - o.startTime > self.timeToDrop then self:ObFired(t) end
		else
			o.aCount = 0
		end
	end
	self.numActObjs = n
end

function G:SetScore()
	self.score = math.max(0, math.Round(self.gtFraction * 1000) + math.Round(self.bonusScore))
	self.vars.scoreTxt = "score: " .. self.score
end

-- onClipEvent(mouseDown) of the main clip
function G:MouseDown(mx, my)
	if self.gameState ~= "game" then return end
	if self.numActObjs == 0 then
		self.blindClicks = self.blindClicks + 1
		local tmp = -100 * self.blindClicks
		self:SetPoint(tmp, mx, my)
		self.bonusScore = self.bonusScore - tmp     -- (minus a minus: the penalty is added)
		if self.blindClicks > 6 then
			local ch = FL.Child(self.root, "char")
			if ch then FL.GotoAndPlay(ch, "blindclickdeath") end
			self.gameState = "gameover"
			self.mainCount = 0
			self:EndAllObAnims()
			self.blindClicks = 0
		end
	else
		self.blindClicks = 0
	end
end

function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	-- (_xmouse / _ymouse of the main clip)
	local mm = FL.ChildMatrix(self.root, "main", I) or I
	p.x, p.y = x - mm[5], y - mm[6]
	p.visible = true
	FL.GotoAndPlay(p, val >= 0 and "pos" or "neg")
	local ani = FL.Child(p, "ani")
	if ani then ani.vars.txt = tostring(val) end
	self.nextPoint = self.nextPoint % 35 + 1
end

function G:MainEnterFrame()
	self.mainCount = self.mainCount + 1
	if self.gameState == "game" then
		self:HintPick()
		self:GameLoop()
		self:SetScore()
	elseif self.gameState == "gameover" then
		if self.mainCount > 25 then
			self.mainCount = 0
			self.gameState = "done"
			self.root.vars.score = self.score
			FL.GotoAndStop(self.root, "gameover")
		end
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.ms = 0
	self.vars = {}
	self.points = {}
	self.objs = {}
	self.gameState = nil
	self.score = 0
	self.curAge = 40
	self.speedArr = nil
	self.root = FL.New(LIB, 0)
	self.root.vars = self.vars
end

function G:Close()
	if CUR == self then CUR = nil end
end

function G:Step()
	self.ms = self.ms + 40
	FL.OnSound = function(c, id) MG.Sound("g22", "s" .. id) end
	FL.Tick(self.root)
	for _, p in ipairs(self.points) do if p.visible then FL.Tick(p) end end
	FL.OnSound = nil
	if self:Main() and self.objs[0] then
		for t = 0, self.numObjs - 1 do self:TimerLoop(self.objs[t]) end
		self:MainEnterFrame()
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
	AN.FinishGame(22, math.max(0, self.score or 0))
end

-- the club buttons (in "an" of ob0 / ob1) and their stage matrices
function G:ClubButtons()
	local out = {}
	for t = 0, 1 do
		local ob = self:Ob(t)
		local om = ob and FL.ChildMatrix(self.root, "ob" .. t, I)
		local a = ob and FL.Child(ob, "an")
		local am = a and FL.ChildMatrix(ob, "an", om)
		if a and am then
			local k, m = FL.CharItem(a, am, { [211] = true })
			if k then out[#out + 1] = { id = t, k = k, m = m } end
		end
	end
	return out
end

function G:Press()
	local mx, my = MG.Mouse()
	-- onClipEvent(mouseDown) first, then the button under the mouse
	self:MouseDown(mx, my)
	if self.gameState ~= "game" then return end
	for _, b in ipairs(self:ClubButtons()) do
		if FL.HitPoint(b.k, b.m, mx, my) then
			self:ObClicked(b.id, mx, my)
			if not AN.IsSpeaking() and math.random() < 0.3 then AN.Speak("Godt") end
			return
		end
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(22) return end
	local main = self:Main()
	if main then
		local ex = {}
		for _, p in ipairs(self.points) do
			if p.visible and p.x > -200 then ex[#ex + 1] = { c = p, m = { 1, 0, 0, 1, p.x, p.y } } end
		end
		main.extra = ex
	end
	FL.Draw(self.root, I)
	self:HintDraw()
	MG.DrawPops()
	local f = self.root.frame
	if main and self.gameState == "game" then
		UI.Button("g22_stage", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), nil, { silent = true, press = function() self:Press() end })
	end
	if f >= 23 and f < 100 then
		-- "Videre" on the game over sign
		local k, m = FL.CharItem(self.root, I, { [242] = true })
		if not k then
			for _, it in ipairs(FL.Items(self.root)) do
				local kid = self.root.kids[it[3]]
				if kid and kid.kind == "spr" then
					k, m = FL.CharItem(kid, TL.Mul(I, kid.mat or { it[4], it[5], it[6], it[7], it[8], it[9] }), { [242] = true })
					if k then break end
				end
			end
		end
		if k then
			local x0, y0, x1, y1 = FL.Bounds(k, m, true)
			if x0 then
				UI.Button("g22_next", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:Finish() end, { hit = FL.HitFn(k, m) })
			end
		end
	end
	MG.Chrome(22)
end

AN.RegisterGame(22, G)
