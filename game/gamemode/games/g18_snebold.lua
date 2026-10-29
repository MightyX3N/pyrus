-- Låge 18: Snebold KAMP
-- Rebuilt from the original loader.swf. Aim with the mouse (the red arrow shows direction and power),
-- click to throw. Hit the kids and the dogs; every hit brings the next target, every miss costs a
-- snowball (5 to start with). Same physics as the original: 25 steps a second, gravity 0.5, the
-- throw speed is the arrow length / 8 (max 200), and the wind grows with every level.
local UI, C, MG, TL = AN.UI, AN.Col, AN.MG, AN.TL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
for _, f in ipairs({ "g18_root", "g18_status", "g18_result", "g18_anim", "g18_pos", "g18_mask" }) do
	include(DIR .. f .. ".lua")
end
local ROOT, STATUS, RESULT, A, P, MASK = AN.G18Root, AN.G18Status, AN.G18Result, AN.G18Anim, AN.G18Pos, AN.G18Mask

local G = {
	scoreType = "score",
	goal = 9,         -- the original coolScore
	worst = 0,
	hintUnit = "hint_cost_hits",
	descKey = "desc_18",
	howKey = "how_18",
}

local STAGE_W, STAGE_H = 700, 450
local STEP = 1 / 25
local ARENA_Y = -50                 -- the arena clip sits 50 up in the game
local CHAR = { 95.9, 363.4 }
local MARKER = { -31.7, -53.2 }     -- where the ball leaves Pyrus' hand
local GROUND = { 350.2, 429.8 }
local GROUND_ZERO = 434.4
local MAX_POWER = 200
local GRAVITY = 0.5
local WIND_MAX = 0.4
local GAMEOVER_PAUSE = 5
local STATUS_AT = { 1, 0, 0, 1, 135.95, 26.45 }
local RESULT_AT = { 1, 0, 0, 1, -79, -6.85 }
local WIND_AT = { 135.95 + 213.95, 26.45 + 54.9 }

-- the targets (difficulty 0 = the boys, 1 = the girls, 2 = the dogs), positions in the arena
local TARGETS = {
	{ kind = "boy", d = 0, x = 244, y = 386.8 }, { kind = "boy", d = 0, x = 281.85, y = 382.05 },
	{ kind = "boy", d = 0, x = 319.7, y = 377.85 }, { kind = "boy", d = 0, x = 357.5, y = 377.25 },
	{ kind = "girl", d = 1, x = 420, y = 362.4 }, { kind = "girl", d = 1, x = 456, y = 362.4 },
	{ kind = "girl", d = 1, x = 485, y = 362.4 }, { kind = "girl", d = 1, x = 552, y = 373.4 },
	{ kind = "dog", d = 2, x = 585.2, y = 367.95 }, { kind = "dog", d = 2, x = 618, y = 363.05 },
	{ kind = "dog", d = 2, x = 650.2, y = 357.3 }, { kind = "dog", d = 2, x = 684.8, y = 350.45 },
}
-- dogs first in the arena's depth order, then the boys, then the girls
local DRAW_ORDER = { 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8 }

-- the original hitTest(x, y, true): is the point inside the shape (1 unit cells, spans per row)
local function inMask(m, x, y)
	local r = m.rows[math.floor(y - m.y) + 1]
	if not r then return false end
	local cx = x - m.x
	for i = 1, #r, 2 do
		if cx >= r[i] and cx < r[i + 1] then return true end
	end
	return false
end

-- (for tests: the targets and hit shapes)
G.Targets, G.Masks, G.InMask, G.Ground = TARGETS, MASK, inMask, GROUND

function G:Status()
	return AN.L("g18_status", self.score or 0, self.ammo or 0)
end

---------------------------------------------------------------------------
function G:Open(args)
	self.finished = false
	self.acc = 0
	self.root = 11            -- root frame: 11 game, 23.. the "Spil Slut!" sign
	self.signAt = nil
	self.gameState = -1
	self.aim = { x = CHAR[1] + MARKER[1], y = CHAR[2] + MARKER[2], nx = 1, ny = 0, power = 0, visible = false }
	self.ball = { hx = self.aim.x, hy = self.aim.y, x = 0, y = 0, vx = 0, vy = 0, f = 1, playing = false, visible = false }
	self.charF, self.charPlaying = 1, false
	self.resultF, self.resultPlaying = 1, false
	-- initTargets: each difficulty in a random order, easiest first
	self.queue = {}
	for d = 0, 2 do
		local list = {}
		for i, t in ipairs(TARGETS) do
			if t.d == d then list[#list + 1] = i end
		end
		while #list > 0 do
			self.queue[#self.queue + 1] = table.remove(list, math.random(#list))
		end
	end
	for _, t in ipairs(TARGETS) do t.visible = false; t.hit = false end
	-- startNewGame
	self.score = 0
	self.ammo = 5
	self.level = 0
	self:InitLevel()
end

function G:InitLevel()
	self.gameState = 0
	self.level = self.level + 1
	self.wind = -WIND_MAX + WIND_MAX * 2 * math.random()
	if self.level < 10 then self.wind = self.wind / (11 - self.level) end
	self:SpawnTarget()
	self:Reload()
	self:StartAiming()
	self.gameState = 1
end

function G:SpawnTarget()
	if #self.queue > 0 then
		self.active = table.remove(self.queue, 1)
	else
		self.active = 8 + math.random(4)    -- after all twelve: a random dog
	end
	local t = TARGETS[self.active]
	t.visible = true
	t.hit = false
end

function G:Reload()
	local b = self.ball
	b.f, b.playing = 1, false
	b.x, b.y = b.hx, b.hy
	b.visible = false
end

function G:StartAiming()
	self.aim.visible = true
	self.charF, self.charPlaying = 1, false   -- gotoAndStop("aim")
end

function G:UpdateAim()
	local a = self.aim
	if not (MG.k and MG.sw == STAGE_W) then return end
	local mx, my = MG.Mouse()
	local dx, dy = mx - a.x, (my - ARENA_Y) - a.y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.001 then return end
	a.nx, a.ny = dx / len, dy / len
	a.power = math.min(len, MAX_POWER)
end

function G:MousePressed()
	if self.gameState == 1 then
		-- fireBullet
		self.aim.visible = false
		local p = self.aim.power / 8
		self.ball.vx, self.ball.vy = self.aim.nx * p, self.aim.ny * p
		self.charPlaying = true
		self.gameState = 15
	end
end

function G:ReleaseBullet()
	self.ball.visible = true
	self.gameState = 2
end

function G:UpdateBullet()
	local b = self.ball
	local t = TARGETS[self.active]
	local still = true
	if t and inMask(MASK[t.kind], b.x - t.x, b.y - t.y) then
		still = false
		self:TargetHit()
	elseif b.y > GROUND_ZERO then
		still = false
		self:TargetMissed()
	elseif inMask(MASK.ground, b.x - GROUND[1], b.y - GROUND[2]) then
		still = false
		self:TargetMissed()
	end
	if still then
		b.vx = b.vx + self.wind
		b.vy = b.vy + GRAVITY
		b.x = b.x + b.vx
		b.y = b.y + b.vy
	end
end

function G:BallHit()
	-- the ball's "hit" splash, with one of the four thumps
	self.ball.f, self.ball.playing = 11, true
	MG.Sound("g18", "thump" .. math.random(4))
end

function G:TargetHit()
	local t = TARGETS[self.active]
	t.hit = true
	if t.kind == "dog" then MG.Sound("g18", "dog") end
	AN.Speak("godt")
	self.score = self.score + 1
	self:BallHit()
	self.wasHit = true
	self.resultF, self.resultPlaying = 10, true
	self.gameState = 3
end

function G:TargetMissed()
	AN.Speak("skidt")
	self:BallHit()
	self.wasHit = false
	self.resultF, self.resultPlaying = 65, true
	self.gameState = 3
end

function G:ResultAnimDone()
	self.resultF, self.resultPlaying = 1, false
	if self.wasHit then
		TARGETS[self.active].visible = false
		self:InitLevel()
	elseif self.ammo > 0 then
		self.ammo = self.ammo - 1
		self:Reload()
		self:StartAiming()
		self.gameState = 1
	else
		-- out of snowballs (the original meant to wait gameOverPause here, then show the sign)
		self.gameState = 4
		self.overAt = 0
	end
end

function G:Step()
	-- the game clip's enterFrame
	if self.gameState == 1 then
		self:UpdateAim()
	elseif self.gameState == 2 then
		self:UpdateBullet()
	elseif self.gameState == 4 then
		self.overAt = self.overAt + STEP
		if self.overAt >= GAMEOVER_PAUSE then
			self.gameState = 5
			self.root = 23
			self.signAt = RealTime()
			AN.Speak("gameover")
		end
	end
	-- Pyrus' throw (frame 19 the swoosh, frame 21 the ball leaves the hand, stop at 34)
	if self.charPlaying then
		self.charF = self.charF + 1
		if self.charF == 19 then MG.Sound("g18", "throw") end
		if self.charF == 21 then self:ReleaseBullet() end
		if self.charF >= 34 then self.charF = 34; self.charPlaying = false end
	end
	local b = self.ball
	if b.playing then
		b.f = b.f + 1
		if b.f >= 17 then b.f = 17; b.playing = false end
	end
	if self.resultPlaying then
		self.resultF = self.resultF + 1
		if self.resultF == 60 or self.resultF == 115 then
			self.resultPlaying = false
			self:ResultAnimDone()
		end
	end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	if self.signAt and RealTime() - self.signAt > 3.2 then self:Finish() end
end

-- hint (one throw): while you aim, dots show where the snowball will fly, wind included
function G:CanHint() return self.gameState == 1 and not self.hintThrow end
function G:Hint(cost)
	self.hintThrow = true
	self.score = math.max(0, self.score - cost)
	MG.Pop("-" .. cost, false, 250, 60)
end
function G:HintDraw()
	if not self.hintThrow then return end
	if self.gameState ~= 1 then
		if self.gameState ~= 15 then self.hintThrow = nil end
		return
	end
	local a, b = self.aim, self.ball
	local p = a.power / 8
	local x, y, vx, vy = b.hx, b.hy, a.nx * p, a.ny * p
	local t = TARGETS[self.active]
	for k = 1, 200 do
		vx = vx + self.wind
		vy = vy + GRAVITY
		x, y = x + vx, y + vy
		if k % 2 == 0 then
			AN.Circle(MG.X(x), MG.Y(y + ARENA_Y), MG.S(3.4), Color(40, 12, 2, 200))
			AN.Circle(MG.X(x), MG.Y(y + ARENA_Y), MG.S(2.4), MG.HINT_GOLD)
		end
		if (t and inMask(MASK[t.kind], x - t.x, y - t.y)) or y > GROUND_ZERO or inMask(MASK.ground, x - GROUND[1], y - GROUND[2]) or x < -50 or x > STAGE_W + 50 then
			MG.HintRing(x, y + ARENA_Y, 10, (t and inMask(MASK[t.kind], x - t.x, y - t.y)) and MG.HINT_GOOD or MG.HINT_BAD, 1, 3)
			break
		end
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(18, self.score)
end

---------------------------------------------------------------------------
local function pic(name, x, y, m, alpha)
	local r = P[name]
	TL.Pic("g18/" .. name .. ".png", r[1], r[2], r[3], r[4], m or { 1, 0, 0, 1, x, y }, alpha)
end

function G:DrawArena()
	local oy = ARENA_Y
	-- Pyrus (behind the snow)
	TL.Cell(A.pyrus, A.pyrus.all[self.charF], CHAR[1], CHAR[2] + oy)
	pic("ground", GROUND[1], GROUND[2] + oy)
	for _, i in ipairs(DRAW_ORDER) do
		local t = TARGETS[i]
		if t.visible then
			local g = A[t.kind]
			TL.Cell(g, g.all[t.hit and 2 or 1], t.x, t.y + oy)
		end
	end
	local b = self.ball
	if b.visible then TL.Cell(A.ball, A.ball.all[b.f], b.x, b.y + oy) end
	local a = self.aim
	if a.visible then
		local s = a.power / 100
		pic("aim", 0, 0, { a.nx * s, a.ny * s, -a.ny, a.nx, a.x, a.y + oy })
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	local hooks = {
		value = function(var)
			if var == "score" then return tostring(self.score) end
			if var == "ammo" then return tostring(self.ammo) end
		end,
		slot = function(name, m, alpha)
			if name == "game" then
				self:DrawArena()
				-- status bar: the texts, and the wind arrow (its bar is stretched by the wind)
				TL.Draw(STATUS, 1, {
					value = function(var)
						if var == "score" then return tostring(self.score) end
						if var == "ammo" then return tostring(self.ammo) end
					end,
					slot = function(n2)
						if n2 == "wind" then
							pic("track", WIND_AT[1], WIND_AT[2])
							local w = (self.wind or 0) / WIND_MAX
							if math.abs(w) > 0.005 then pic("bar", 0, 0, { w, 0, 0, 1, WIND_AT[1], WIND_AT[2] }) end
						end
					end,
				}, STATUS_AT)
				if self.resultF > 1 then TL.Draw(RESULT, self.resultF, {}, RESULT_AT) end
			end
		end,
	}
	TL.Draw(ROOT, self.root, hooks)
	self:HintDraw()
	MG.DrawPops()
	-- throw: a click anywhere on the stage (the original listens to every mouse press)
	if self.gameState == 1 then
		UI.Button("g18_throw", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:MousePressed() end, { silent = true })
	end
	if self.signAt then
		if RealTime() - self.signAt > 0.8 then
			AN.Text(AN.L("g03_click"), "black", math.floor(MG.S(13)), MG.X(350), MG.Y(290), Color(255, 241, 207, 220), 1)
		end
		UI.Button("g18_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:Finish() end, { silent = true })
	end
	MG.Chrome(18)
end

AN.RegisterGame(18, G)
