-- Låge 10: Gåseflyvning
-- Rebuilt from the original loader.swf. Pyrus and Kandis ride a goose: the mouse moves it back and
-- forth, a click makes it flap up, and it sinks when you don't. Christmas ornaments float in from
-- the right (30, 40, 50 or 80 points); a thunder cloud ends the flight. Every 10 seconds they come
-- faster and more often.
-- The game is a Halloween game dressed up for Christmas: in the code the goose is the "witch", the
-- ornaments are a bat, a spider, a snake and a pumpkin, and the thunder cloud is a skull.
-- The whole original timeline is played with the Flash player; the game code is the original's,
-- with its quirks: an ornament is only caught when its left edge is inside the goose's box (the
-- other half of the test used a variable that did not exist), and each of the 35 ornaments gets
-- its kind and height once, so the same ones come round again.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g10_fl.lua")

local G = {
	scoreType = "score",
	goal = 8000,      -- the original coolScore
	worst = 0,
	descKey = "desc_10",
	howKey = "how_10",
}

local STAGE_W, STAGE_H = 480, 290
local STEP = 1 / 25
local MS = 40
local LIB = "g10"
local I = { 1, 0, 0, 1, 0, 0 }

local KINDS = {
	{ cid = 65, points = 30 },                  -- "bat"
	{ cid = 71, points = 50 },                  -- "spider"
	{ cid = 61, points = 40 },                  -- "snake"
	{ cid = 63, points = 80 },                  -- "pumpkin"
	{ cid = 69, points = 0, lethal = true },    -- "skull": the thunder cloud
}

local CUR

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end
local function idle(c) FL.GotoAndPlay(c, "idle") end

local function setupActions()
	for _, cid in ipairs({ 111, 122, 127, 132, 76, 82 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
	FL.SetActions(LIB, 192, { [23] = stop })
	FL.SetActions(LIB, 59, { [29] = idle, [87] = idle })
	FL.SetActions(LIB, 69, { [55] = idle, [137] = idle })
	FL.SetActions(LIB, 77, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	FL.SetActions(LIB, 195, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,
		[14] = function(c) if CUR then CUR.hideMouse = true end end,
		[22] = function(c)
			if CUR then CUR.hideMouse = false end
			AN.Speak("GameOver")
			FL.Play(c)
		end,
		[104] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:GameM() return (FL.ChildMatrix(self.root, "game", I)) end

function G:Mouse()
	local sx, sy = MG.Mouse()
	local m = self:GameM()
	local det = m[1] * m[4] - m[2] * m[3]
	local x, y = sx - m[5], sy - m[6]
	return (m[4] * x - m[3] * y) / det, (-m[2] * x + m[1] * y) / det
end

-- the original's boxesIntersect, quirks and all
local function boxesIntersect(b1x, b1y, b1w, b1h, b2x, b2y, b2w, b2h)
	if b2x >= b1x and b2x <= b1x + b1w then
		if b2y >= b1y and b2y <= b1y + b1h then return true end
		if b2y + b2h >= b1y and b2y + b1h <= b1y + b1h then return true end
	end
	-- (the "else if" half tested b2_x + w, and w did not exist: never true)
	return false
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:InitPoints()
	self.points = {}
	self.nextPoint = 1
end

function G:SetPoint(val, x, y, hilite)
	local p = self.points[self.nextPoint]
	if not p then p = { c = FL.New(LIB, 77) } self.points[self.nextPoint] = p end
	p.m = { 1, 0, 0, 1, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local hl = FL.Child(p.c, "hilite")
	if hl then FL.GotoAndStop(hl, hilite and "on" or "off") end
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
	self.nextPoint = self.nextPoint % 35 + 1
end

function G:InitEnemies()
	self.maxVisible = 6
	self.inPlay = 0
	self.nbEnemies = 35
	self.nextEnemy = 1
	self.minX = 10
	self.updateCount = 0
	self.scrollSpeed = 1
	self.spawnFrames = 60
	self.enemies = {}
	for t = 1, self.nbEnemies do
		local kind = KINDS[math.Round(math.random() * 4) + 1]
		local y = math.Round(math.random() * 220) + 30
		self.enemies[t] = {
			c = FL.New(LIB, kind.cid), kind = kind, pos = { x = 1000, y = y }, visible = false,
			box = { x = -19, y = -19, xabs = 0, yabs = 0, w = 38, h = 38 },
		}
	end
end

function G:UpdateEnemies()
	self.updateCount = self.updateCount + 1
	if self.updateCount >= self.spawnFrames then
		self.updateCount = 0
		if self.inPlay < self.maxVisible then
			local e = self.enemies[self.nextEnemy]
			e.pos.x = 500
			e.visible = true
			self.nextEnemy = self.nextEnemy % self.nbEnemies + 1
			self.inPlay = self.inPlay + 1
		end
	end
	for _, e in ipairs(self.enemies) do
		if e.visible then
			e.pos.x = e.pos.x - self.scrollSpeed
			e.box.xabs = e.pos.x + e.box.x
			e.box.yabs = e.pos.y + e.box.y
			if e.pos.x <= self.minX then
				e.pos.x = -1000
				e.visible = false
				self.inPlay = self.inPlay - 1
			end
		end
	end
end

function G:KillEnemy(e)
	e.pos.x = -1000
	e.visible = false
	self.inPlay = self.inPlay - 1
end

function G:InitWitch()
	self.witch = {
		c = FL.New(LIB, 59), pos = { x = 300, y = 100 }, vy = 0, cycle = 0, top = 45, bottom = 250,
		box = { x = -20, y = -20, w = 50, h = 50 },
	}
	self.lastPump = -10000
	local anim = FL.Child(self.witch.c, "anim")
	if anim then FL.Stop(anim) end
end

function G:BelowCeilingVal(v)
	if v >= self.witch.top then return true end
	self.witch.vy = 0
	return false
end

function G:UpdateWitch()
	local w = self.witch
	w.cycle = w.cycle + 1
	if w.cycle == 10 then
		local nv = w.vy - 1
		local ny = w.pos.y - w.vy
		if self:BelowCeilingVal(ny) and ny <= w.bottom then w.vy = nv end
		w.cycle = 0
	end
	local ny = w.pos.y - w.vy
	if self:BelowCeilingVal(ny) and ny <= w.bottom then w.pos.y = ny end
	local anim = FL.Child(w.c, "anim")
	if anim then
		if self.now - self.lastPump > 100 and anim.frame == 1 then FL.Stop(anim) else FL.Play(anim) end
	end
end

function G:PumpWitch()
	local w = self.witch
	if w and w.pos.y - 1 >= w.top then
		w.cycle = 9
		w.vy = w.vy + 2
		self.lastPump = self.now
	end
end

function G:CheckWitchCollision(b)
	local w = self.witch
	return boxesIntersect(w.pos.x + w.box.x, w.pos.y + w.box.y, w.box.w, w.box.h, b.xabs, b.yabs, b.w, b.h)
end

function G:Init()
	self:StartAmbient()
	self.vars.score = 0
	self:InitPoints()
	self:InitEnemies()
	self:InitWitch()
	if MG.x0 then self.witch.pos.x = (self:Mouse()) end
	self.state = "gameon"
	self.startTime = self.now
	self.totalTime = 10000
	self.dieCount = 0
end

function G:MainLoop()
	if self.state == "gameon" then
		self:UpdateEnemies()
		self:UpdateWitch()
		for _, e in ipairs(self.enemies) do
			if e.visible and self:CheckWitchCollision(e.box) then
				self:KillEnemy(e)
				if e.kind.lethal then
					self.state = "diecutscene"
				else
					self:SetPoint(e.kind.points, e.box.xabs, e.box.yabs, true)
					self.vars.score = self.vars.score + e.kind.points
					MG.Sound("g10", "boing")
				end
			end
		end
		if self.now - self.startTime > self.totalTime then
			-- every 10 seconds: faster, and more often
			self.scrollSpeed = self.scrollSpeed + 1
			self.spawnFrames = self.spawnFrames - 10
			self.startTime = self.now
		end
	elseif self.state == "diecutscene" then
		self:StopAmbient()
		MG.Sound("g10", "witchdie")
		FL.GotoAndPlay(self.witch.c, "badhit")
		self.state = "diecutscenerunning"
	elseif self.state == "diecutscenerunning" then
		self.dieCount = self.dieCount + 1
		if self.dieCount > 54 then
			self.state = "showing game over"
			FL.GotoAndStop(self.root, "gameover")
		end
	end
end

-- hint (12 seconds): a red arrow at the right edge shows the height where the next thunder cloud
-- will come in, and the clouds already on their way are ringed
function G:CanHint() return self.state == "gameon" end
function G:Hint(cost)
	self.hintT = 12
	self.vars.score = math.max(0, self.vars.score - cost)
	MG.Pop("-" .. cost, false, 240, 60)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.state ~= "gameon" then self.hintT = nil return end
	local a = math.min(1, self.hintT * 2)
	local gm = self:GameM() or I
	for _, e in ipairs(self.enemies) do
		if e.visible and e.kind.lethal then
			local x, y = TL.Apply(gm, e.pos.x, e.pos.y)
			MG.HintRing(x, y, 30, MG.HINT_BAD, a, 4)
		end
	end
	-- the next one to come in (the enemies come in a fixed order)
	local n = self.nbEnemies
	for k = 0, n - 1 do
		local e = self.enemies[(self.nextEnemy - 1 + k) % n + 1]
		if not e.visible and e.kind.lethal then
			local x, y = TL.Apply(gm, 470, e.pos.y)
			local ex = math.min(x, STAGE_W - 8)
			MG.HintArrow(ex, y, ex - 50, y, MG.HINT_BAD, a, 10)
			MG.HintText("!", ex - 70, y, MG.HINT_BAD, 26, a)
			break
		end
	end
end

-- the background sound (a loop)
function G:StartAmbient()
	if self.ambOn or AN.SoundMode() == 2 then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100 * 0.7
	if v <= 0 then return end
	self.ambOn = true
	local me = self
	sound.PlayFile("sound/alletidersnisse/g10/ambient.mp3", "noplay noblock", function(ch)
		if not IsValid(ch) then return end
		if CUR ~= me or not me.ambOn then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		me.ambCh = ch
	end)
end

function G:StopAmbient()
	self.ambOn = false
	if self.ambCh and IsValid(self.ambCh) then self.ambCh:Stop() end
	self.ambCh = nil
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g10_status", self.vars and self.vars.score or 0)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.state = nil
	self.hideMouse = false
	self.wasDown = false
	self.vars = { score = 0 }
	self.points, self.enemies = {}, {}
	self.root = FL.New(LIB, 0)
	FL.GotoAndStop(self.root, "gameon")
end

function G:Close()
	self:StopAmbient()
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
	for _, e in ipairs(self.enemies) do FL.Tick(e.c) end
	if self.witch then FL.Tick(self.witch.c) end
	for _, p in ipairs(self.points) do if p.c.visible then FL.Tick(p.c) end end
	if MG.x0 and self:Game() then
		local mx, my = self:Mouse()
		-- onClipEvent(mouseMove): the goose follows the mouse sideways
		if self.witch and self.state == "gameon" and mx ~= self.lastMX then self.witch.pos.x = mx end
		self.lastMX = mx
		-- onClipEvent(mouseUp): a flap
		local down = input.IsMouseDown(MOUSE_LEFT)
		if self.wasDown and not down and self.state == "gameon" then self:PumpWitch() end
		self.wasDown = down
		-- the game's own pointer follows the mouse while the mouse is hidden
		if self.hideMouse and mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H then
			local m, k = FL.ChildMatrix(self:Game(), "mousePointerMc", I)
			if k then k.mat = { m[1], m[2], m[3], m[4], mx, my } end
		end
	end
	self:MainLoop()
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
	self:StopAmbient()
	self:ShowCursor(true)
	AN.FinishGame(10, self.vars.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(10) return end
	local game = self:Game()
	if game then
		local extra = {}
		for _, p in ipairs(self.points) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		for _, e in ipairs(self.enemies) do
			if e.visible then extra[#extra + 1] = { c = e.c, m = { 1, 0, 0, 1, e.pos.x, e.pos.y } } end
		end
		if self.witch then
			extra[#extra + 1] = { c = self.witch.c, m = { 1, 0, 0, 1, self.witch.pos.x, self.witch.pos.y } }
		end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		-- the label was meant to come from the main menu (_level0.txt_statusbarScore), which never set it
		if name == "scoretxt" then return st.state and AN.L("g10_v_score", st.vars.score) or nil end
		return st.vars[name]
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	local mx, my = MG.Mouse()
	local inside = mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H
	self:ShowCursor(not (self.hideMouse and inside))
	if self.root.frame >= 22 and self.root.frame < 103 then
		UI.Button("g10_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(10)
end

AN.RegisterGame(10, G)
