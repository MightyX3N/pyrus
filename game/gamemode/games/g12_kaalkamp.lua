-- Låge 12: Kæmpe Kålkamp
-- Rebuilt from the original loader.swf. Pyrus walks along the floor and shoots straight up at the big
-- bouncing cabbages; every hit cabbage splits into two smaller ones (the smallest just pop). Clear
-- all cabbages to finish the level - you get a bonus for your accuracy (2500 for 100 %). A cabbage
-- that touches Pyrus costs a life; 3 lives. The game code is the original's (an "asteroids" engine
-- turned into a Pang game), quirks included:
--   * only one gun of the three is mounted, and it fires once per key press
--   * the shield, the thrust and the black hole are still in the code but never used
--   * a cabbage that bounces off a wall is only drawn at the wall for that one frame; its real
--     position stays where it was (so it can wobble in a corner)
--   * the level screen continues by itself after a moment, even if you don't press anything
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g12_fl.lua")

local G = {
	scoreType = "score",
	goal = 6000,      -- the original coolScore
	worst = 0,
	descKey = "desc_12",
	howKey = "how_12",
}

local STAGE_W, STAGE_H = 480, 290
local STEP = 1 / 25
local LIB = "g12"
local I = { 1, 0, 0, 1, 0, 0 }
local ASTROID_CID = { [0] = 29, 27, 23, 19, nil, 24, 20, 16 }
local DYING_END = { [29] = 59, [27] = 57, [23] = 56, [19] = 55, [24] = 57, [20] = 56, [16] = 55 }
local BULLET_CID = { 49, 44, 39, 34 }

-- onClipEvent(load) { _visible = false }: the arena's markers, the preloader, the shield, astroid7's hit shape
FL.LoadHidden[LIB] = { [190] = true, [185] = true, [54] = true, [6] = true }

local CUR

-- the original's tables
local TURRET = { [1] = { angle = 6, fireRate = 2, vel = 8, power = 1 } }
local ENGINE = { [0] = { vel = 8 } }
local SHIELD = { [0] = { max = 100 } }
local ASTROID = {
	[0] = { energy = 1, weight = 1, minVel = 2, maxVel = 2, minRotVel = 2, maxRotVel = 4, spawn = { 1, 2 }, radius = 50, points = 250 },
	[1] = { energy = 1, weight = 1, minVel = 2, maxVel = 2, minRotVel = 1, maxRotVel = 2, spawn = { 2, 2 }, radius = 25, points = 100 },
	[2] = { energy = 1, weight = 1, minVel = 2, maxVel = 2, minRotVel = 2, maxRotVel = 4, spawn = { 3, 3 }, radius = 12.5, points = 25 },
	[3] = { energy = 1, weight = 1, minVel = 2, maxVel = 2, minRotVel = 3, maxRotVel = 6, spawn = {}, radius = 6.25, points = 10 },
	[5] = { energy = 2, weight = 1.4, minVel = 2, maxVel = 2, minRotVel = 1, maxRotVel = 2, spawn = { 6, 6 }, radius = 25, points = 100 },
	[6] = { energy = 2, weight = 1.4, minVel = 2, maxVel = 2, minRotVel = 2, maxRotVel = 4, spawn = { 7, 7 }, radius = 12.5, points = 25 },
	[7] = { energy = 2, weight = 1.4, minVel = 2, maxVel = 2, minRotVel = 3, maxRotVel = 6, spawn = {}, radius = 6.25, points = 10 },
}

local function levelList(l)
	local L = {
		{ 2 }, { 2, 2 }, { 1 }, { 1, 2 }, { 2, 1, 2 }, { 1, 1 }, { 6 }, { 6, 6 }, { 5 }, { 5, 6 },
		{ 6, 5, 6 }, { 5, 5 }, { 1, 1, 1 }, { 1, 5, 1 }, { 5, 1, 5 }, { 2, 2, 2, 2 }, { 2, 1, 1, 2 },
		{ 1, 1, 1, 1 }, { 1, 1, 1, 5 }, { 1, 5, 5, 1 }, { 1, 5, 5, 5 }, { 5, 5, 5, 5 }, { 3, 2, 1, 2, 3 },
		{ 1, 1, 1, 1, 1 }, { 5, 1, 5, 1, 5 }, { 7, 6, 5, 6, 7 },
	}
	if L[l] then return L[l] end
	if l < 999 then return { 5, 5, 5, 5, 5 } end
	return {}
end

local function rotM(deg, x, y, sx, sy)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	sx, sy = sx or 1, sy or sx or 1
	return { c * sx, s * sx, -s * sy, c * sy, x, y }
end

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,   -- the preloader: everything is loaded
		[19] = function(c) AN.Speak("GameOverIngenLiv") FL.Play(c) end,
		[93] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	FL.SetActions(LIB, 234, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	for _, cid in pairs(ASTROID_CID) do
		FL.SetActions(LIB, cid, {
			[1] = stop,
			[DYING_END[cid]] = function(c) if c.astroidRef then c.astroidRef.state = 3 end stop(c) end,
		})
	end
	for _, cid in ipairs(BULLET_CID) do
		FL.SetActions(LIB, cid, {
			[1] = stop,
			[10] = function(c) FL.Play(c) end,
			[13] = function(c) if c.ref then c.ref.state = 3 end stop(c) end,
		})
	end
	FL.SetActions(LIB, 82, {
		[1] = stop,
		[9] = function(c)
			MG.Sound("g12", "shipexplode")
			AN.Speak("MisterLiv")
			FL.Play(c)
		end,
		[54] = function(c) stop(c) if CUR then CUR:ShipExplodeAniDone() end end,
	})
	FL.SetActions(LIB, 68, { [1] = function(c) FL.GotoAndStop(c, "standing") end })
	FL.SetActions(LIB, 89, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	for _, cid in ipairs({ 88, 94, 123, 134, 139, 144, 181 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
	FL.SetActions(LIB, 233, {
		[1] = function(c) stop(c) c.vars.continueOk = false end,
		[23] = function(c) if CUR then CUR:LevelScreenStats(c) end end,
		[63] = function(c) c.vars.continueOk = false end,
		[79] = function(c) if CUR then CUR:StartLevel(CUR.level + 1) end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Arena() return FL.Child(self:Game(), "arena") end
function G:Marker(name)
	for _, it in ipairs(FL.Items(self:Arena())) do
		if it.nm == name then return it[8], it[9] end
	end
	return 0, 0
end
function G:Screen() return FL.Child(self:Game(), "levelcompletedscreen") end
function G:SetStatus()
	local sb = FL.Child(self:Game(), "statusbar")
	if sb then sb.vars.score = self.score sb.vars.lives = self.lives end
end

-- a cabbage's shape: the circle its picture fills (hitTest(x, y, true) on the picture)
function G:AstroidRadius(a)
	local key = a.type
	self.radii = self.radii or {}
	if not self.radii[key] then
		local x0, y0, x1, y1 = FL.Bounds(a.mc, I, true)
		self.radii[key] = x0 and ((x1 - x0) + (y1 - y0)) / 4 or ASTROID[key].radius
	end
	return self.radii[key]
end

function G:AstroidHitPoint(a, x, y)
	local r = self:AstroidRadius(a)
	local dx, dy = x - a.mx, y - a.my
	return dx * dx + dy * dy <= r * r
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	self.gameState = 0
	self.score = 0
	self.points = {}
	self.nextPoint = 1
	for t = 1, 35 do
		local p = FL.New(LIB, 89)
		p.x, p.y, p.s = -200, 0, 1
		self.points[t] = p
	end
	self.boundXmin, self.boundYmin = self:Marker("screen0")
	self.boundXmax, self.boundYmax = self:Marker("screen1")
	self.boundWidth = self.boundXmax - self.boundXmin
	self.shotAccuracyBonus = 1000
	self.shotAccuracyBonusPerfect = 2500
	self:InitShip()
	self:StartNewGame()
end

function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	p.x, p.y = x, y
	p.s = math.max(55, math.min(140, val * 0.5)) / 100
	local h = FL.Child(p, "hilite")
	if h then FL.GotoAndStop(h, "off") end
	p.visible = true
	local ani = FL.Child(p, "ani")
	if ani then ani.vars.txt = val end
	FL.Play(p)
	self.nextPoint = self.nextPoint % 35 + 1
end

function G:InitShip()
	local ship = {
		mc = FL.New(LIB, 82),
		x = 0, y = 0, rot = 0, sx = 1, visible = true,
		vel = { x = 0, y = 0 }, acc = 0,
		hitpoints = { {}, {}, {}, {} },
		safeFrames = 0, state = 0,
		shield = { amount = SHIELD[0].max, max = SHIELD[0].max, engaged = false },
		engineVel = ENGINE[0].vel,
		turret = { type = 1, fireRate = TURRET[1].fireRate, vel = TURRET[1].vel, power = TURRET[1].power, lastShot = 0, bullets = {}, x = 0, y = 0 },
	}
	self.ship = ship
end

function G:ShipM(ship)
	return rotM(ship.rot, ship.x, ship.y, ship.sx)
end

function G:UpdateShip()
	local ship = self.ship
	if ship.state == 1 then
		local rad = math.rad(ship.rot)
		self.heroCos, self.heroSin = math.cos(rad), math.sin(rad)
		ship.acc = ship.acc * 0.985
		ship.vel.x = ship.vel.x * 0.98
		ship.vel.y = ship.vel.y * 0.98
		ship.vel.x = ship.vel.x + ship.acc * self.heroCos
		ship.vel.y = ship.vel.y + ship.acc * self.heroSin
		ship.px = (ship.px or ship.x) + ship.vel.x
		ship.py = (ship.py or ship.y) + ship.vel.y
		local x0 = self:Marker("ship0")
		local x1 = self:Marker("ship1")
		if ship.px < x0 then ship.px = x0 elseif ship.px > x1 then ship.px = x1 end
		ship.x, ship.y = ship.px, ship.py
		local M = self:ShipM(ship)
		for t = 0, 3 do
			local m = FL.ChildMatrix(ship.mc, "hitpoint" .. t, M)
			if m then ship.hitpoints[t + 1].x, ship.hitpoints[t + 1].y = m[5], m[6] end
		end
		local _, tk = FL.ChildMatrix(ship.mc, "turret0", I)
		local tx = 20.25
		for _, it in ipairs(FL.Items(ship.mc)) do if it.nm == "turret0" then tx = it[8] end end
		ship.turret.x, ship.turret.y = ship.x, ship.y - tx
		if self.shootRequest then
			self.shootRequest = false
			self:FireBullets()
		end
		ship.turret.lastShot = ship.turret.lastShot + 1
		-- shieldRequest is never set: the shield stays off
		ship.shield.engaged = false
		if ship.safeFrames > 0 then
			ship.safeFrames = ship.safeFrames - 1
			if ship.safeFrames % 2 == 0 then
				ship.visible = ship.safeFrames % 4 == 0
			end
		end
	end
	local body = FL.Child(ship.mc, "body")
	if body then
		if ship.vel.x == 0 and ship.vel.y == 0 then FL.GotoAndStop(body, "standing") else FL.GotoAndStop(body, "walking") end
	end
end

function G:RespawnShip()
	local ship = self.ship
	ship.vel.x, ship.vel.y, ship.acc = 0, 0, 0
	local _, y1 = self:Marker("ship1")
	ship.px, ship.py = 150, y1
	ship.x, ship.y = ship.px, ship.py
	ship.rot = -90
	ship.sx = 1
	FL.GotoAndStop(ship.mc, "normal")
	local body = FL.Child(ship.mc, "body")
	if body then FL.GotoAndStop(body, "standing") end
	ship.safeFrames = 50
	ship.state = 1
end

function G:ShipExplodeAniDone()
	local ship = self.ship
	ship.turret.type = 1
	ship.shield.amount = ship.shield.max
	self.lives = self.lives - 1
	if self.lives == 0 then
		self:GameOver()
	else
		self:RespawnShip()
	end
	self:SetStatus()
end

function G:IsOnScreen(x, y)
	return x > self.boundXmin and x < self.boundXmax and y > self.boundYmin and y < self.boundYmax
end

function G:UpdateBullets()
	local tur = self.ship.turret
	for b = #tur.bullets, 1, -1 do
		local bl = tur.bullets[b]
		if bl.state == 1 then
			bl.x, bl.y = bl.x + bl.vx, bl.y + bl.vy
			local mx, my = bl.x - bl.vx / 2, bl.y - bl.vy / 2
			if not self:IsOnScreen(bl.x, bl.y) then
				table.remove(tur.bullets, b)
			else
				for a = #self.astroids, 1, -1 do
					local ast = self.astroids[a]
					if ast.state == 1 and bl.state == 1 then
						if self:AstroidHitPoint(ast, bl.x, bl.y) or self:AstroidHitPoint(ast, mx, my) then
							-- the bullet has no weight (undefined counts as 0 in Flash 6): no push
							self:AstroidHit(a, bl.power)
							FL.GotoAndPlay(bl.mc, "dying")
							bl.state = 2
						end
					end
				end
			end
		elseif bl.state == 3 then
			table.remove(tur.bullets, b)
		end
	end
end

function G:FireBullets()
	local tur = self.ship.turret
	if tur.type > 0 and tur.fireRate <= tur.lastShot then
		MG.Sound("g12", "shoot")
		self.shotsFired = self.shotsFired + 1
		local bl = { mc = FL.New(LIB, BULLET_CID[tur.type]), x = tur.x, y = tur.y, state = 1, power = TURRET[tur.type].power }
		bl.vx, bl.vy = self.heroCos * tur.vel, self.heroSin * tur.vel
		bl.mc.ref = bl
		FL.GotoAndStop(bl.mc, "active")
		tur.lastShot = 0
		table.insert(tur.bullets, bl)
	end
end

function G:CheckKeys()
	local gs = self.gameState
	if gs == 2 or gs == 3 or gs == 4 or gs == 5 then
		local ship = self.ship
		if input.IsKeyDown(KEY_RIGHT) then
			ship.vel.x = ship.engineVel
		elseif input.IsKeyDown(KEY_LEFT) then
			ship.vel.x = -ship.engineVel
		else
			ship.vel.x = 0
		end
		if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) or input.IsKeyDown(KEY_C) then
			if self.shootOK then
				self.shootOK = false
				self.shootRequest = gs == 2
			end
		else
			self.shootOK = true
		end
		if gs == 4 then
			if input.IsKeyDown(KEY_SPACE) or input.IsKeyDown(KEY_ENTER) then
				local scr = self:Screen()
				if self.spaceOK and scr and scr.vars.continueOk then
					self.spaceOK = false
					FL.GotoAndPlay(scr, "animoff")
				end
			else
				self.spaceOK = true
			end
		end
	end
end

function G:InitAstroids()
	self.astroids = {}
	local list = levelList(self.level)
	local posStep = self.boundWidth / (#list + 1)
	local _, ay = self:Marker("astroids0")
	for i, tp in ipairs(list) do
		local posX = self.boundXmin + posStep * i
		self:SpawnAstroid(tp, posX, ay, (i - 1) % 2 == 0 and -1 or 1)
	end
end

function G:SpawnAstroid(tp, x, y, dir)
	local T = ASTROID[tp]
	local a = { type = tp, x = x, y = y, mc = FL.New(LIB, ASTROID_CID[tp]) }
	a.mc.astroidRef = a
	local speed = T.minVel + math.random() * (T.maxVel - T.minVel)
	a.vx = speed * dir * self.speedFactor
	a.vy = -speed * 4 * self.speedFactor
	a.rot = math.floor(math.random() * 360)
	local rv = T.minRotVel + math.random() * (T.maxRotVel - T.minRotVel)
	if math.random() < 0.5 then rv = -rv end
	a.rotVel = rv
	a.radius = T.radius
	a.points = T.points
	a.mx, a.my = x, y
	a.energy = T.energy
	a.weight = T.weight * self.speedFactor
	a.state = 1
	a.depth = 2000 + self.nextAstroidID
	self.nextAstroidID = self.nextAstroidID + 1
	table.insert(self.astroids, a)
end

function G:UpdateAstroids()
	local ship = self.ship
	for i = #self.astroids, 1, -1 do
		local a = self.astroids[i]
		if a.state == 1 then
			a.vy = a.vy + a.weight
			a.x, a.y = a.x + a.vx, a.y + a.vy
			a.rot = a.rot + a.rotVel
			a.mx, a.my = a.x, a.y
			if a.x < self.boundXmin + a.radius then
				a.vx = -a.vx
				a.mx = self.boundXmin + a.radius
			elseif a.x > self.boundXmax - a.radius then
				a.vx = -a.vx
				a.mx = self.boundXmax - a.radius
			end
			if a.y > self.boundYmax - a.radius then
				a.vy = -a.vy - a.weight
				a.my = self.boundYmax - a.radius
				local T = ASTROID[a.type]
				local rv = T.minRotVel + math.random() * (T.maxRotVel - T.minRotVel)
				if math.random() < 0.5 then rv = -rv end
				a.rotVel = rv
			end
			if ship.safeFrames == 0 and not ship.shield.engaged and ship.state == 1 then
				for h = 1, 4 do
					local heroHit = false
					if a.type == 3 then
						-- mc.hitTest(ship.mc.hitarea): the two boxes overlap
						local ax0, ay0, ax1, ay1 = FL.Bounds(a.mc, rotM(a.rot, a.mx, a.my), true)
						local hm, hk = FL.ChildMatrix(ship.mc, "hitarea", self:ShipM(ship))
						local bx0, by0, bx1, by1
						if hk then bx0, by0, bx1, by1 = FL.Bounds(hk, hm, true) end
						if ax0 and bx0 and ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1 then heroHit = true end
					else
						local hp = ship.hitpoints[h]
						if hp.x and self:AstroidHitPoint(a, hp.x, hp.y) then heroHit = true end
					end
					if heroHit then
						ship.state = 3
						FL.GotoAndPlay(ship.mc, "explode")
					end
				end
			end
		end
	end
end

function G:AstroidHit(id, power)
	local a = self.astroids[id]
	MG.Sound("g12", "shothit")
	self.shotsHit = self.shotsHit + 1
	a.energy = a.energy - power
	if a.energy <= 0 then self:KillAstroid(id) end
end

function G:KillAstroid(id)
	local a = self.astroids[id]
	MG.Sound("g12", "pop")
	a.state = 2
	FL.GotoAndPlay(a.mc, "dying")
	for s, tp in ipairs(ASTROID[a.type].spawn) do
		self:SpawnAstroid(tp, a.x, a.y, (s - 1) % 2 == 0 and -1 or 1)
	end
	self.score = self.score + a.points
	self:SetStatus()
	self:SetPoint(a.points, a.x, a.y)
end

function G:RemoveDeadAstroids()
	for i = #self.astroids, 1, -1 do
		if self.astroids[i].state == 3 then
			-- (the original removes "mc", which is nothing there, so the cabbage clip stays - empty by then)
			table.remove(self.astroids, i)
		end
	end
end

function G:MainLoop()
	local gs = self.gameState
	if gs == 2 then
		self:CheckKeys()
		self:UpdateShip()
		self:UpdateBullets()
		self:UpdateAstroids()
		self:RemoveDeadAstroids()
		self:CheckLevelComplete()
	elseif gs == 3 then
		self.waitCount = self.waitCount - 1
		if self.waitCount == 0 then self:ShowLevelCompletedScreen() end
		self:CheckKeys()
		self:UpdateShip()
		self:UpdateBullets()
	elseif gs == 4 then
		self:CheckKeys()
		self:UpdateShip()
		self:UpdateBullets()
	elseif gs == 5 then
		self.waitCount = self.waitCount - 1
		if self.waitCount == 0 then self.gameState = 2 end
		self:CheckKeys()
		self:UpdateShip()
		self:UpdateBullets()
	end
end

-- hint (5 seconds): an aim line straight up from the gun, and the cabbage a shot would hit is ringed
function G:CanHint() return self.gameState == 2 and self.ship ~= nil end
function G:Hint(cost)
	self.hintT = 5
	self.score = math.max(0, self.score - cost)
	self:SetStatus()
	MG.Pop("-" .. cost, false, 300, 60)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.gameState ~= 2 then self.hintT = nil return end
	local am = FL.PathClip(self.root, { "game", "arena" })
	local tur = self.ship and self.ship.turret
	if not am or not tur then return end
	local a = math.min(1, self.hintT * 2)
	local dx, dy = self.heroCos or 0, self.heroSin or -1
	local hitA, hitT = nil, 700
	for _, c in ipairs(self.astroids or {}) do
		if c.state == 1 then
			local r = self:AstroidRadius(c)
			local px, py = c.mx - tur.x, c.my - tur.y
			local t = px * dx + py * dy
			if t > 0 then
				local ex, ey = px - dx * t, py - dy * t
				if ex * ex + ey * ey <= r * r and t < hitT then hitA, hitT = c, t - math.sqrt(math.max(0, r * r - ex * ex - ey * ey)) end
			end
		end
	end
	local x0, y0 = TL.Apply(am, tur.x, tur.y)
	local x1, y1 = TL.Apply(am, tur.x + dx * hitT, tur.y + dy * hitT)
	if y1 < 14 and y0 > 14 then   -- keep the arrow's head on the stage
		local k = (y0 - 14) / (y0 - y1)
		x1, y1 = x0 + (x1 - x0) * k, 14
	end
	MG.HintArrow(x0, y0 - 6, x1, y1, hitA and MG.HINT_GOOD or MG.HINT_GOLD, a * 0.85, 4)
	if hitA then
		local cx, cy = TL.Apply(am, hitA.mx, hitA.my)
		MG.HintRing(cx, cy, self:AstroidRadius(hitA) * math.abs(am[1]) + 6, MG.HINT_GOOD, a, 4)
	end
end

function G:StartNewGame()
	self.score = 0
	self.lives = 3
	self:SetStatus()
	self.nextAstroidID = 0
	self.leftovers = {}
	self:RespawnShip()
	self:StartLevel(1)
end

function G:StartLevel(lvl)
	self.level = lvl
	self.levelStartScore = self.score
	self.speedFactor = 0.5 + lvl * 0.015
	self:InitAstroids()
	self.shotsFired = 0
	self.shotsHit = 0
	self.waitCount = 25
	self.gameState = 5
end

function G:CheckLevelComplete()
	if #self.astroids == 0 and self.ship.state == 1 then self:LevelCompleted() end
end

function G:LevelCompleted()
	local ratio = self.shotsFired > 0 and self.shotsHit / self.shotsFired or 0
	self.shootAccuracy = math.Round(math.min(100, ratio * 100) * 100) / 100
	if self.shootAccuracy == 100 then
		self.shootAccuracyScore = self.shotAccuracyBonusPerfect
	else
		self.shootAccuracyScore = math.Round(ratio * self.shotAccuracyBonus)
	end
	self.waitCount = 25
	self.gameState = 3
end

function G:ShowLevelCompletedScreen()
	self.gameState = 4
	local scr = self:Screen()
	if scr then FL.Play(scr) end
end

-- the level screen's frame 23: the accuracy and the bonus
function G:LevelScreenStats(c)
	c.vars.txt_pct = math.floor(self.shootAccuracy)
	c.vars.txt_bonus = self.shootAccuracyScore
	self.score = self.score + self.shootAccuracyScore
	self:SetStatus()
	c.vars.continueOk = true
	-- "PERFEKT!" only shows at 100 %
	for _, it in ipairs(FL.Items(c)) do
		if it[2] == 223 then
			local k = c.kids[it[3]]
			if k then k.visible = self.shootAccuracy >= 100 end
		end
	end
	if self.shootAccuracy < 100 then AN.Speak("Godt") else AN.Speak("megetGodt") end
	AN.LevelScore(12, self.level, self.score - self.levelStartScore, { total = self.score })
end

function G:GameOver()
	self.vars.score = self.score
	FL.GotoAndPlay(self.root, "gameover")
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g12_status", self.score or 0, self.lives or 3, self.level or 1)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.score = 0
	self.lives = 3
	self.level = 1
	self.gameState = nil
	self.ship = nil
	self.astroids = {}
	self.leftovers = {}
	self.points = {}
	self.vars = { score = 0 }
	self.radii = nil
	self.root = FL.New(LIB, 0)
end

function G:Close()
	if CUR == self then CUR = nil end
end

function G:Step()
	FL.OnSound = function(c, id) if id == 213 then MG.Sound("g12", "s213") end end
	FL.Tick(self.root)
	if self.ship then FL.Tick(self.ship.mc) end
	for _, a in ipairs(self.astroids) do FL.Tick(a.mc) end
	for _, a in ipairs(self.leftovers) do FL.Tick(a.mc) end
	if self.ship then for _, b in ipairs(self.ship.turret.bullets) do FL.Tick(b.mc) end end
	for _, p in ipairs(self.points) do if p.visible then FL.Tick(p) end end
	FL.OnSound = nil
	-- the game clip's enterFrame
	if self.gameState then self:MainLoop() end
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
	AN.FinishGame(12, self.score or 0)
end

-- the clips made at run time, in depth order, drawn in the arena / the game clip
function G:UpdateExtras()
	local arena = self:Arena()
	local game = self:Game()
	if not arena or not game then return end
	local ex = {}
	for _, a in ipairs(self.leftovers) do ex[#ex + 1] = { c = a.mc, m = rotM(a.rot, a.mx, a.my), d = a.depth } end
	for _, a in ipairs(self.astroids) do ex[#ex + 1] = { c = a.mc, m = rotM(a.rot, a.mx, a.my), d = a.depth } end
	local ship = self.ship
	if ship and ship.visible then ex[#ex + 1] = { c = ship.mc, m = self:ShipM(ship), d = 4000 } end
	if ship then
		for i, b in ipairs(ship.turret.bullets) do ex[#ex + 1] = { c = b.mc, m = { 1, 0, 0, 1, b.x, b.y }, d = 50000 + i } end
	end
	table.sort(ex, function(p, q) return p.d < q.d end)
	arena.extra = ex
	local pts = {}
	for _, p in ipairs(self.points) do
		if p.visible and p.x > -100 then pts[#pts + 1] = { c = p, m = { p.s, 0, 0, p.s, p.x, p.y } } end
	end
	game.extra = pts
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(12) return end
	local st = self
	self:UpdateExtras()
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "txt_lvlcompletedaccuracy" then return AN.L("g12_t_accuracy") end
		if name == "txt_lvlcompletedbonus" then return AN.L("g12_t_bonus") end
		return st.vars[name]
	end
	FL.Draw(self.root, I)
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	local f = self.root.frame
	-- the level screen's buttons (Videre, and the small one)
	local scr = self.gameState == 4 and self:Screen()
	if scr and scr.frame >= 23 and scr.frame < 63 then
		local gm = FL.ChildMatrix(self.root, "game", I)
		local sm = FL.ChildMatrix(self:Game(), "levelcompletedscreen", gm)
		for _, it in ipairs(FL.Items(scr)) do
			if it[2] == 218 or it[2] == 230 then
				local k = scr.kids[it[3]]
				local bm = TL.Mul(sm, { it[4], it[5], it[6], it[7], it[8], it[9] })
				local x0, y0, x1, y1 = FL.Bounds(k, bm, true)
				if x0 then
					UI.Button("g12_next" .. it[2], MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
						FL.GotoAndPlay(scr, "animoff")
					end, { hit = FL.HitFn(k, bm) })
				end
			end
		end
	end
	if f >= 19 and f < 91 then
		UI.Button("g12_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(12)
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(12, G)
