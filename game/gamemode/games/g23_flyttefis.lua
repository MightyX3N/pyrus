-- Låge 23: Flyttefis
-- Rebuilt from the original loader.swf. Things come down the conveyor belt in the middle - books,
-- lamps, papyrus rolls and pens - and you drag each one over to its box (Bøger, Lamper, Papyrus,
-- Pen). The right box gives points (30-80); the wrong box, missing a box, or letting the thing
-- fall off the belt breaks one of the four little boxes in the corner. When all four are gone, the
-- game is over. The belt runs faster every 10 seconds.
-- The game code is the original's (a Halloween game with bats, pumpkins, snakes and spiders,
-- redrawn), quirks included:
--   * you can only hold a thing for 1.5 seconds - then it is dropped where the mouse is
--   * a thing held still stays put; letting go anywhere outside a box costs a box
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g23_fl.lua")

local G = {
	scoreType = "score",
	goal = 4000,      -- the original coolScore
	worst = 0,
	descKey = "desc_23",
	howKey = "how_23",
}

local STAGE_W, STAGE_H = 480, 290
local STEP = 1 / 25
local LIB = "g23"
local I = { 1, 0, 0, 1, 0, 0 }

-- onClipEvent(load) { _visible = false }: the preloader
FL.LoadHidden[LIB] = { [128] = true }

local CUR

local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 0, {
		[2] = function(c) stop(c) FL.GotoAndStop(c, "gameon") end,   -- the preloader: everything is loaded
		[20] = function(c) AN.Speak("GameOverIngenLiv") FL.Play(c) end,
		[98] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	FL.SetActions(LIB, 160, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 10, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	FL.SetActions(LIB, 153, { [6] = stop, [21] = stop })
	FL.SetActions(LIB, 159, { [23] = stop })
	FL.SetActions(LIB, 162, { [6] = stop })
	for _, cid in ipairs({ 9, 15, 44, 55, 60, 65 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
end

function G:Game() return FL.Child(self.root, "game") end

function G:Status()
	return AN.L("g23_status", self.score or 0, 4 - (self.nextMinipot or 0))
end

-- the game clip's matrix, and the mouse in its coordinates (_xmouse / _ymouse)
function G:GameM() return FL.ChildMatrix(self.root, "game", I) or I end
function G:GameMouse()
	local mx, my = MG.Mouse()
	local m = self:GameM()
	return mx - m[5], my - m[6]
end

---------------------------------------------------------------------------
-- sounds: the game's sound module ("background" sounds loop until stopped)
---------------------------------------------------------------------------
function G:PlayAmbient()
	if self.ambient then return end
	self.ambient = "loading"
	if AN.SoundMode() == 2 then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100
	if v <= 0 then return end
	local me = self
	sound.PlayFile("sound/alletidersnisse/g23/ambient_sound.mp3", "noplay noblock", function(ch)
		if not IsValid(ch) then return end
		if CUR ~= me or me.ambient ~= "loading" then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		me.ambient = ch
	end)
end
function G:StopAmbient()
	local ch = self.ambient
	if ch and ch ~= "loading" and IsValid(ch) then ch:Stop() end
	self.ambient = nil
end

---------------------------------------------------------------------------
-- the original game code (the "game" clip)
---------------------------------------------------------------------------
local POTS = {
	[0] = { kind = "snake", x = 88, y = 43, radius = 70 },
	{ kind = "spider", x = 61, y = 167, radius = 70 },
	{ kind = "pumpkin", x = 385, y = 42, radius = 70 },
	{ kind = "bat", x = 428, y = 153, radius = 70 },
}
local ENEMIES = {
	[0] = { kind = "bat", points = 30, cid = 117 },
	{ kind = "pumpkin", points = 80, cid = 123 },
	{ kind = "snake", points = 40, cid = 126 },
	{ kind = "spider", points = 50, cid = 120 },
}

local function dist(x1, y1, x2, y2) return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) end

function G:Init()
	self:PlayAmbient()
	self.score = 0
	self.root.vars.score = 0
	self:SetScoreTxt()
	self.points = {}
	for t = 1, 35 do
		local p = FL.New(LIB, 10)
		p.x, p.y, p.s = -200, -200, 1
		self.points[t] = p
	end
	self.nextPoint = 1
	self.enemies = {}
	for i = 0, 3 do
		local E = ENEMIES[i]
		self.enemies[i] = { kind = E.kind, points = E.points, radius = 30, x = 1000, y = 1000, mc = FL.New(LIB, E.cid), mx = 0, my = 0, depth = 4000 + i }
	end
	self.state = "gameon"
	self.enemyInPlay = false
	self.currentEnemy = nil
	self.mouseIsDown = false
	self.startTime = self.ms
	self.totalTime = 1500
	self.velocity = 1
	self.velocityIncTime = self.ms
	self.velocityIncTimeout = 10000
	self.nextMinipot = 0
end

function G:SetScoreTxt()
	-- _level0.txt_statusbarScore is never loaded: undefined + score is just the score
	local g = self:Game()
	if g then g.vars.scoreTxt = tostring(self.score) end
end

function G:PointWithinPot(i, x, y)
	local p = POTS[i]
	return dist(p.x, p.y, x, y) < p.radius
end

function G:SetPoint(val, x, y, hilite)
	local p = self.points[self.nextPoint]
	p.x, p.y = x, y
	local h = FL.Child(p, "hilite")
	if h then FL.GotoAndStop(h, hilite and "on" or "off") end
	p.visible = true
	local ani = FL.Child(p, "ani")
	if ani then ani.vars.txt = val end
	FL.Play(p)
	self.nextPoint = self.nextPoint % 35 + 1
	if not AN.IsSpeaking() then AN.Speak("Godt") end
end

function G:LoseBox()
	self.nextMinipot = self.nextMinipot + 1
	MG.Sound("g23", "Xylophone")
	local mp = FL.Child(self.root, "minipot_" .. self.nextMinipot)
	if mp then FL.GotoAndPlay(mp, "killed") end
	if self.nextMinipot == 4 then
		self.state = "no_more_pots"
	else
		AN.Speak("Skidt")
	end
end

function G:SetEnemyPos(e, x, y)
	e.x, e.y = x, y
	e.mx, e.my = x, y
end

function G:MainLoop()
	local st = self.state
	if st == "gameon" then
		if self.ms - self.velocityIncTime > self.velocityIncTimeout then
			self.velocityIncTime = self.ms
			self.velocity = math.min(10, self.velocity + 1)
		end
		local e = self.currentEnemy
		if self.enemyInPlay then
			if not self.mouseIsDown then
				e.y = e.y + self.velocity
				e.my = e.y
				if e.y > 300 then
					self.enemyInPlay = false
					e.y, e.my = 1000, 1000
					self:LoseBox()
				end
			end
		else
			e = self.enemies[math.Round(math.random() * 3)]
			self.currentEnemy = e
			self:SetEnemyPos(e, 240, 0)
			self.enemyInPlay = true
		end
		if self.mouseIsDown and self.ms - self.startTime > self.totalTime then self:DropItem() end
	elseif st == "no_more_pots" then
		self:StopAmbient()
		self.state = "game over"
		FL.GotoAndPlay(self.root, "gameover")
	end
end

function G:DropItem()
	if not self.mouseIsDown then return end
	self.mouseIsDown = false
	local e = self.currentEnemy
	self:SetEnemyPos(e, 1000, 1000)
	local mx, my = self:GameMouse()
	local target = -1
	for i = 0, 3 do if self:PointWithinPot(i, mx, my) then target = i end end
	if target > -1 and e.kind == POTS[target].kind then
		self.score = self.score + e.points
		self.root.vars.score = self.score
		MG.Sound("g23", "splash")
		self:SetPoint(e.points, mx, my, true)
	else
		self:LoseBox()
	end
	self:SetScoreTxt()
	self.enemyInPlay = false
end

-- hint (10 seconds): the right box for the thing on the belt (or in your hand) lights up, with an
-- arrow from the thing to it
function G:CanHint() return self.state == "gameon" end
function G:Hint(cost)
	self.hintT = 10
	self.score = math.max(0, self.score - cost)
	self.root.vars.score = self.score
	self:SetScoreTxt()
	MG.Pop("-" .. cost, false, 240, 60)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.state ~= "gameon" then self.hintT = nil return end
	local e = self.currentEnemy
	if not e or not self.enemyInPlay then return end
	local gm = self:GameM()
	local a = math.min(1, self.hintT * 2)
	for i = 0, 3 do
		local p = POTS[i]
		if p.kind == e.kind then
			local px, py = TL.Apply(gm, p.x, p.y)
			MG.HintRing(px, py, 52, MG.HINT_GOOD, a, 5)
			local ex, ey = TL.Apply(gm, e.mx, e.my)
			local d = math.sqrt((px - ex) ^ 2 + (py - ey) ^ 2)
			if d > 90 then
				local ux, uy = (px - ex) / d, (py - ey) / d
				MG.HintArrow(ex + ux * 34, ey + uy * 34, px - ux * 58, py - uy * 58, MG.HINT_GOOD, a * 0.85, 6)
			end
		end
	end
end

-- onClipEvent(mouseDown) / (mouseMove) / (mouseUp)
function G:MouseDown()
	local e = self.currentEnemy
	if not e then return end
	local mx, my = self:GameMouse()
	if dist(e.x, e.y, mx, my) < e.radius then
		self.mouseIsDown = true
		self.startTime = self.ms
	end
end
function G:MouseMove()
	if not self.mouseIsDown then return end
	local mx, my = self:GameMouse()
	self:SetEnemyPos(self.currentEnemy, mx, my)
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
	self.points = {}
	self.enemies = {}
	self.state = nil
	self.score = 0
	self.nextMinipot = 0
	self.ambient = nil
	self.root = FL.New(LIB, 0)
end

function G:Close()
	self:StopAmbient()
	if CUR == self then CUR = nil end
end

function G:Step()
	self.ms = self.ms + 40
	FL.Tick(self.root)
	for _, p in ipairs(self.points) do if p.visible then FL.Tick(p) end end
	for _, e in pairs(self.enemies) do FL.Tick(e.mc) end
	if self.mouseIsDown then self:MouseMove() end
	if self:Game() and self.state then self:MainLoop() end
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
	AN.FinishGame(23, self.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(23) return end
	local game = self:Game()
	if game then
		local ex = {}
		for i = 0, 3 do
			local e = self.enemies[i]
			if e then ex[#ex + 1] = { c = e.mc, m = { 1, 0, 0, 1, e.mx, e.my }, d = e.depth } end
		end
		for i, p in ipairs(self.points) do
			if p.visible and p.x > -150 then ex[#ex + 1] = { c = p, m = { 1, 0, 0, 1, p.x, p.y }, d = 10000 + i } end
		end
		table.sort(ex, function(a, b) return a.d < b.d end)
		game.extra = ex
		if self.state == "gameon" then
			UI.Button("g23_stage", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), nil, { silent = true, press = function()
				self:MouseDown()
				UI.drag = { release = function() self:DropItem() end }
			end })
		end
	end
	FL.Draw(self.root, I)
	self:HintDraw()
	MG.DrawPops()
	local f = self.root.frame
	if f >= 20 and f < 97 then
		UI.Button("g23_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(23)
end

AN.RegisterGame(23, G)
