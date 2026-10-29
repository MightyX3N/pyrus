-- Låge 15: Flyvende Rotter
-- Rebuilt from the original game.swf. A rat falls from the attic ceiling; click to make the nisse swing
-- his club. Hit it at the right moment and it flies across the attic (the water spouts from the holes in
-- the floor lift it up again). Land past the line and you can register the distance or try again.
-- Same numbers as the original: 24 steps a second, gravity 1.95, the hit window is 35 around the club,
-- and the distance is 1.5 cm per unit flown. The rat's arms, legs and head swing with the original
-- little limb physics.
local UI, C, MG, TL = AN.UI, AN.Col, AN.MG, AN.TL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
for _, f in ipairs({ "g15_world", "g15_anim", "g15_look", "g15_pos", "g15_sign", "g15_follow", "g15_start" }) do
	include(DIR .. f .. ".lua")
end
local W, A, LOOK, P = AN.G15World, AN.G15Anim, AN.G15Look.look, AN.G15Pos
local SIGN, FOLLOW, START = AN.G15Sign, AN.G15Follow, AN.G15Start

local G = {
	scoreType = "score",
	goal = 4500,      -- the original coolScore
	worst = 0,
	descKey = "desc_15",
	howKey = "how_15",
}

-- the visible window of the original (the game sprite sits at -2.1, 97.9 in it before panning)
local STAGE_W, STAGE_H = 546, 396
local VIEW_X, VIEW_Y = -2.1, 97.9
local STEP = 1 / 24
local GRAVITY = 1.95
local START_REF = { 299.5, -130.35 }
local GROUND_Y = 269.05
local GROUND_OFF = -11
local HIT_Y = 198.3            -- hitAnim._y
local HIT_POS = { 304.2, 198.3 }
local MIN_DIST = 1362.25
local MONSTER = { 100.05, 199.35 }
local LOOK_AT = { 93.25, -8.35 }
local SHADOW = { 1.33, 2.62, 272.1 }
local SIGN_Y = 265.35
local FOLLOW_Y0 = -75.1
local PAN_OFFSET = 340
local RAT_SCALE = 1.11
local PIX = 20

-- the water spouts (crater = x, y, sx, sy of the crater clip; fish = the spout clip next to it)
local CRATERS = {
	{ 2.07, 1.00, -215.25, 232.80 },
	{ 1.44, 0.99, 794.40, 256.95, fish = { "fishB", 785.55, 272.60 } },
	{ 1.52, 1.57, 1674.70, 264.65, fish = { "fishA", 1682.15, 273.40 } },
	{ 1.61, 1.90, 2182.80, 267.70, fish = { "fishB", 2177.30, 273.50 } },
}
-- the "blow" area of a crater: shape bounds (x0, y0, x1, y1) through the blow clip's matrix
local BLOW = { -15.15, -126.3, 11.55, 110.65, sx = 0.74, sy = 0.28, tx = -1.35, ty = -54.6 }

-- the rat: body parts (picture, x, y, base rotation) in draw order, and the limbs with physics
local PARTS = {
	{ "leg2", 5.75, 10.45, -24.8, limb = "leg2" },
	{ "leg1", -7.1, 11.7, 0, limb = "leg1" },
	{ "body", 0.25, 11.2, 0 },
	{ "arm1", -6.9, -5.85, 0, limb = "arm1" },
	{ "head", -0.35, -9.45, 0, limb = "head" },
	{ "body2", 0, 0, 0 },
	{ "arm2", 7.5, -6.1, 0, limb = "arm2" },
}
local LIMBS = {
	arm2 = { angleOffset = 90, fMult = 0.35, airFriction = 0.06, friction = 0.12, graMult = 0.6 },
	arm1 = { angleOffset = -90, fMult = 0.3, airFriction = 0.06, friction = 0.12, graMult = 0.6 },
	leg2 = { angleOffset = 90, fMult = 0.2, airFriction = 0.06, friction = 0.12, graMult = 0.6 },
	leg1 = { angleOffset = 90, fMult = 0.3, airFriction = 0.06, friction = 0.12, graMult = 0.6 },
	head = { angleOffset = 0, fMult = 1.3, airFriction = 0.0001, friction = 0.12, graMult = 0.6 },
}
-- the rat's outline (for the original hitTest between the rat and a spout)
local RAT_BOX = { -20, -29.3, 23, 15 }

local SIGN_LABEL = { animon = 4, animoff = 73, animonWon = 85, animoffWon = 153 }
local SIGN_STOPS = { [34] = true, [83] = true, [150] = true, [160] = true }

local rad = math.rad

function G:Status()
	if self.best and self.best > 0 then
		return AN.L("g15_status_best", self.best)
	end
	return AN.L("g15_status")
end

---------------------------------------------------------------------------
function G:Open(args)
	self.finished = false
	self.acc = 0
	self.started = false        -- the start sign is shown first
	self.best = 0
	self.hintThrow, self.hintCostTotal = nil, 0
	MG.ResetPops()
	-- game.init()
	self.state = "none"
	self.sCount = 0
	self.aState = "none"
	self.panning = false
	self.panPos = -124            -- -this._x (the game sprite starts at 124 in the original)
	self.score = 0
	self.rat = { x = 296.95, y = -251.45, vx = 0, vy = 0, rot = 0, rotVel = 0, visible = true }
	self.monF, self.monPlaying = 3, false   -- idle
	self.lookF = 1
	self.hitF, self.hitPlaying = 1, false
	self.signF, self.signPlaying, self.signX = 1, false, 402.1
	self.followF, self.followX, self.followY, self.followArrow, self.followTxt = 55, 733.25, FOLLOW_Y0, 2, ""
	self.shadowVisible, self.shadowX = false, -213.05
	self.fish = {}
	for i, c in ipairs(CRATERS) do
		if c.fish then self.fish[i] = { f = 1, playing = false, last = -10 } end
	end
	self.limbs = {}
	for _, p in ipairs(PARTS) do
		if p.limb then
			self.limbs[p.limb] = { rot = p[4], rotVel = 0, active = true, ease = 0, old = nil, oldMove = { 0, 0 }, part = p }
		end
	end
end

-- the rat's matrix in the game sprite
function G:RatMatrix()
	local r = self.rat
	local c, s = math.cos(rad(r.rot)) * RAT_SCALE, math.sin(rad(r.rot)) * RAT_SCALE
	return { c, s, -s, c, r.x, r.y }
end

---------------------------------------------------------------------------
-- the original game.loop()
---------------------------------------------------------------------------
function G:Loop()
	self.sCount = self.sCount + 1
	local st = self.state
	local r = self.rat
	if st == "none" then
		self.state = "makeAst"
		self.sCount = 0
	elseif st == "makeAst" then
		if self.sCount == 2 then
			r.x, r.y = START_REF[1], START_REF[2]
			self.aState = "fall"
			-- (the original asks "math.random()" in lower case, which Flash 6 reads as 0: it always falls at 4)
			r.vx, r.vy = 0, 4
			r.rotVel = (math.random() - 0.5) * 12
			self.state = "ast"
			self:MonsterGoto(4, true)    -- gotowait
			self.soundDone = false
		end
	elseif st == "ast" then
		self:DoAstronaut()
	elseif st == "inTheHole" then
		if self.sCount > 20 then
			self.state = "makeAst"
			self.sCount = 0
		end
	elseif st == "landed" then
		if self.sCount == 5 then self:MonsterGoto(3, false) end
		if self.sCount > 40 then
			self.state = "makeAst"
			self.sCount = 0
			self:SignGoto(SIGN_LABEL.animoff)
			r.x, r.y = START_REF[1], START_REF[2] - math.random(0, 5)
		end
	elseif st == "landedwon" then
		if self.sCount == 5 then self:MonsterGoto(3, false) end
	end
	if self.panning then
		local targ = r.x - PAN_OFFSET
		self.panPos = self.panPos + (targ - self.panPos) / 4.9
	end
end

function G:DoAstronaut()
	local r = self.rat
	if self.aState == "fall" then
		r.y = r.y + r.vy
		r.rot = r.rot + r.rotVel
		if r.y > GROUND_Y + 40 then
			self.state = "inTheHole"
			self.sCount = 0
			AN.Speak("rotter_ikkeramt")
		end
		self.lookF = math.max(1, math.Round(r.y))
	elseif self.aState == "fly" then
		local blow = self:CheckCraterBlows()
		self:SetFollowSign()
		r.vx = r.vx * 0.998
		r.vy = (r.vy + GRAVITY - blow) * 0.998
		r.x = r.x + r.vx
		r.y = r.y + r.vy
		r.rot = r.rot + r.rotVel
		self.shadowVisible = true
		self.shadowX = r.x
		local ground = GROUND_Y + GROUND_OFF
		if not self.soundDone and r.y + 2 * r.vy > ground then
			self.soundDone = true
			MG.Sound("g15", math.random() > 0.5 and "bounce1" or "bounce2")
		end
		if r.y > ground then
			self.soundDone = false
			if math.abs(r.vx) + math.abs(r.vy) > 8 then
				r.y = ground - 1
				r.vx = r.vx * 0.51
				r.vy = r.vy * -0.51
				r.vx = r.vx + r.rotVel * 0.1
				r.rotVel = r.vx * 0.5
			else
				r.y = ground
				if r.x > MIN_DIST then
					self.state = "landedwon"
					self.sCount = 0
					self:ShowSign("Won")
				else
					self.state = "landed"
					self.sCount = 0
					self:ShowSign("")
				end
			end
		end
	end
end

function G:ShowSign(str)
	local r = self.rat
	self.score = math.Round(100 * ((r.x - START_REF[1]) * 0.3) / PIX)
	self:SignGoto(SIGN_LABEL["animon" .. str])
	self.signX = r.x
	self.distTxt = AN.L("g15_dist", self.score)
	if str == "Won" then self.best = math.max(self.best, self.score) end
end

function G:SetFollowSign()
	local r = self.rat
	local f = math.min(80, math.max(1, math.Round(r.y - FOLLOW_Y0) + 15))
	local meters
	if f < 50 then
		self.followF = f
		self.followX = r.x
		self.followY = math.max(FOLLOW_Y0, r.y)
		meters = math.Round((GROUND_Y - r.y) * 0.3 / PIX)
		self.followTxt = AN.L("g15_height", meters)
		local slope = r.vx ~= 0 and r.vy / r.vx or 0
		self.followArrow = slope < -0.3 and 1 or (slope < 0.3 and 2 or 3)
	end
	if f < 3 and meters and self.lastMeter ~= meters then MG.Sound("g15", "tick", 0.5) end
	self.lastMeter = meters
end

-- ast.hitTest(blow): the bounding boxes of the rat and the spout overlap
function G:CheckCraterBlows()
	local r = self.rat
	local m = self:RatMatrix()
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, c in ipairs({ { RAT_BOX[1], RAT_BOX[2] }, { RAT_BOX[3], RAT_BOX[2] }, { RAT_BOX[1], RAT_BOX[4] }, { RAT_BOX[3], RAT_BOX[4] } }) do
		local px, py = TL.Apply(m, c[1], c[2])
		x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
	end
	for i, c in ipairs(CRATERS) do
		local bx0 = c[3] + c[1] * (BLOW.tx + BLOW.sx * BLOW[1])
		local bx1 = c[3] + c[1] * (BLOW.tx + BLOW.sx * BLOW[3])
		local by0 = c[4] + c[2] * (BLOW.ty + BLOW.sy * BLOW[2])
		local by1 = c[4] + c[2] * (BLOW.ty + BLOW.sy * BLOW[4])
		if x1 > bx0 and x0 < bx1 and y1 > by0 and y0 < by1 then
			local dist = math.max(0, GROUND_Y - 20 - r.y)
			local force = math.max(0, 250 - dist) / 250
			force = force ^ 4 * 25
			r.rotVel = r.rotVel - (c[3] - r.x) * 0.16
			local fi = self.fish[i]
			if fi and RealTime() - fi.last > 0.5 then
				fi.f, fi.playing = 6, true
				fi.last = RealTime()
			end
			return force
		end
	end
	return 0
end

---------------------------------------------------------------------------
-- the nisse (monster clip)
---------------------------------------------------------------------------
function G:MonsterGoto(f, play)
	self.monF, self.monPlaying = f, play
	self:MonsterScript(f)
end

function G:MonsterScript(f)
	if f == 3 or f == 10 then
		self.monPlaying = false
	elseif f == 20 then
		MG.Sound("g15", "swing", 0.8)
	elseif f == 29 then
		self:AtHitFrame()
	elseif f == 44 then
		if not self.hitIt then self:MonsterGoto(10, false) end
	elseif f == 53 then
		self:MonsterGoto(10, false)
	end
end

function G:AtHitFrame()
	local r = self.rat
	local size = 35
	local d = r.y - HIT_Y
	local ad = math.abs(d)
	if ad < size and self.aState == "fall" and self.state == "ast" then
		self.aState = "fly"
		r.vx = (6.5 + (size - ad) / size * 6.5) * 3.2 + (math.random() - 0.5) * 9
		r.vy = (-3.5 + d * 0.35) * 4.1 + (math.random() - 0.5) * 8
		self.panning = true
		self.hitF, self.hitPlaying = 2, true
		self.hitIt = true
		AN.Speak("rotter_ramt")
	else
		self.hitIt = false
	end
end

function G:MonsterClicked()
	if not self.started then return end
	if self.monF >= 10 and self.monF <= 19 then
		self:MonsterGoto(20, true)    -- swing
	end
end

---------------------------------------------------------------------------
-- the sign
---------------------------------------------------------------------------
function G:SignGoto(f)
	self.signF, self.signPlaying = f, true
	self:SignScript(f)
end

function G:SignScript(f)
	if f == 28 or f == 122 then MG.Sound("g15", "sign", 0.7) end
	if f == 128 then AN.Speak("gameover") end
	if SIGN_STOPS[f] or f == 1 then self.signPlaying = false end
end

function G:TryAgain()
	self.state = "makeAst"
	self.sCount = 0
	self:SignGoto(SIGN_LABEL.animoff)
	self.rat.x, self.rat.y = START_REF[1], START_REF[2] - math.random(0, 5)
	self.soundDone = false
end

function G:MoveOn()
	self:Finish()
end

---------------------------------------------------------------------------
-- the limbs (the original "dangle" helper on each arm, leg and the head)
---------------------------------------------------------------------------
function G:Limbs()
	local m = self:RatMatrix()
	local pr = self.rat.rot
	for name, L in pairs(self.limbs) do
		local cfg = LIMBS[name]
		local p = L.part
		local wx, wy = TL.Apply(m, p[2], p[3])
		local gx, gy = wx - self.panPos, wy     -- the global position (the camera moves too)
		if not L.old then
			L.old = { gx, gy }
		else
			local mvx, mvy = gx - L.old[1], gy - L.old[2]
			if not L.active then
				if mvx ~= 0 and mvy ~= 0 then L.active = true end
				L.old = { gx, gy }
			else
				if math.abs(mvx) + math.abs(mvy) > 60 then
					L.old = { gx, gy }
				else
					local a = rad(cfg.angleOffset + L.rot + pr)
					local ox, oy = math.cos(a), math.sin(a)
					local accx, accy = mvx - L.oldMove[1], mvy - L.oldMove[2]
					L.old = { gx, gy }
					L.oldMove = { mvx, mvy }
					local accTorque = ox * accx + oy * accy
					local graTorque = -(oy * 10)
					local b = rad(0 + L.rot - pr)
					local pvx, pvy = math.cos(b) * 20, math.sin(b) * 20
					local airFric = (-mvy) * pvx + mvx * pvy
					L.rotVel = L.rotVel + graTorque * cfg.graMult + accTorque * cfg.fMult + airFric * cfg.airFriction * 0.23
					L.rotVel = L.rotVel * (1 - cfg.friction)
					L.rot = L.rot + L.rotVel
					if math.abs(L.rotVel) < 0.2 then
						L.ease = L.ease + 1
						if L.ease > 10 then L.active = false; L.ease = 0 end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
function G:Step()
	if not self.started then return end
	self:Loop()
	self:Limbs()
	if self.monPlaying then
		local f = self.monF + 1
		if f > #A.nisse.all then f = 1 end
		self:MonsterGoto(f, true)
	end
	if self.hitPlaying then
		self.hitF = self.hitF + 1
		if self.hitF > #A.hit.all then self.hitF = 1; self.hitPlaying = false end
	end
	if self.signPlaying then
		self:SignGoto(self.signF + 1)
		if self.signF >= 160 then self.signPlaying = false end
	end
	for _, fi in pairs(self.fish) do
		if fi.playing then
			fi.f = fi.f + 1
			if fi.f == 7 then MG.Sound("g15", "spout", 0.5) end
			if fi.f > 9 then fi.f = 1; fi.playing = false end
		end
	end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

-- hint (one throw): the club glows while the rat falls, and "NOW!" flashes at the moment to click
-- (the swing takes 9 steps to reach the rat, and it falls 4 a step). The cost comes off the result.
function G:CanHint() return self.started and (self.state == "ast" or self.state == "makeAst") and self.aState ~= "fly" and not self.hintThrow end
function G:Hint(cost)
	self.hintThrow = true
	self.hintCostTotal = (self.hintCostTotal or 0) + cost
	MG.Pop("-" .. cost, false, 300, 60)
end
function G:HintDraw(ox, oy)
	if not self.hintThrow then return end
	if self.aState == "fly" or self.state == "inTheHole" then self.hintThrow = nil return end
	if self.state ~= "ast" then return end
	local hx, hy = HIT_POS[1] + ox, HIT_POS[2] + oy
	local d = (self.rat.y + 4 * 9) - HIT_Y
	if math.abs(d) <= 6 then
		MG.HintRing(hx, hy, 34, MG.HINT_GOOD, 1, 5)
		MG.HintText(AN.L("g15_hint_now"), hx, hy - 60, MG.HINT_GOOD, 30)
	elseif d < 0 then
		MG.HintRing(hx, hy, 34, MG.HINT_GOLD, 0.5, 3)
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(15, math.max(0, (self.score or 0) - (self.hintCostTotal or 0)))
end

---------------------------------------------------------------------------
-- drawing (the game sprite's coordinates -> the window)
---------------------------------------------------------------------------
function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	local ox, oy = VIEW_X - (self.panPos + 124), VIEW_Y
	local V = { 1, 0, 0, 1, ox, oy }
	local function at(x, y) return x + ox, y + oy end

	-- the attic (only the tiles in view)
	for _, t in ipairs(W.bg) do
		local x = t[2] + ox
		if x < STAGE_W and x + t[4] > 0 then MG.Img(t[1], x, t[3] + oy, t[4], t[5]) end
	end
	-- the water spouts
	for i, c in ipairs(CRATERS) do
		local fi = self.fish[i]
		if fi then
			local g = A[c.fish[1]]
			local x, y = at(c.fish[2], c.fish[3])
			if x > -150 and x < STAGE_W + 150 then TL.Cell(g, g.all[fi.f], x, y) end
		end
	end
	-- the nisse (watching the rat while he waits)
	local mx, my = at(MONSTER[1], MONSTER[2])
	TL.Cell(A.nisse, A.nisse.all[self.monF], mx, my)
	if self.monF >= 10 and self.monF <= 19 then
		TL.Cell(LOOK, LOOK.all[math.Clamp(self.lookF, 1, #LOOK.all)], mx + LOOK_AT[1], my + LOOK_AT[2])
	end
	-- shadow and rat
	local r = self.rat
	if self.shadowVisible then
		local sp = P.shadow
		TL.Pic("g15/shadow.png", sp[1], sp[2], sp[3], sp[4], { SHADOW[1], 0, 0, SHADOW[2], self.shadowX + ox, SHADOW[3] + oy })
	end
	if r.visible then
		local m = TL.Mul(V, self:RatMatrix())
		for _, p in ipairs(PARTS) do
			local rot = p.limb and self.limbs[p.limb].rot or p[4]
			local c, s = math.cos(rad(rot)), math.sin(rad(rot))
			local pm = TL.Mul(m, { c, s, -s, c, p[2], p[3] })
			local q = P[p[1]]
			TL.Pic("g15/" .. p[1] .. ".png", q[1], q[2], q[3], q[4], pm)
		end
	end
	-- the height sign while the rat is above the roof
	if self.followF < 50 then
		TL.Draw(FOLLOW, self.followF, {
			value = function() return self.followTxt end,
			slot = function(name, m2) TL.CellM(A.arrow, A.arrow.all[self.followArrow], m2) end,
		}, { 1, 0, 0, 1, self.followX + ox, self.followY + oy })
	end
	-- the club's hit flash
	local hx, hy = at(HIT_POS[1], HIT_POS[2])
	TL.Cell(A.hit, A.hit.all[self.hitF], hx, hy)
	-- the floor in front
	for _, t in ipairs(W.fg) do
		local x = t[2] + ox
		if x < STAGE_W and x + t[4] > 0 then MG.Img(t[1], x, t[3] + oy, t[4], t[5]) end
	end
	self:HintDraw(ox, oy)
	MG.DrawPops()
	-- the distance sign (with its buttons when you made it)
	if self.signF > 1 then
		local sm = { 1, 0, 0, 1, self.signX + ox, SIGN_Y + oy }
		TL.Draw(SIGN, self.signF, {
			value = function(var) if var == "distTxt" then return self.distTxt or "" end end,
			item = function(key, m2, ch)
				if (key == "f239" or key == "f242") and self.signF == 150 then
					local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
					for _, c in ipairs({ { ch[3], ch[4] }, { ch[3] + ch[5], ch[4] }, { ch[3], ch[4] + ch[6] }, { ch[3] + ch[5], ch[4] + ch[6] } }) do
						local px, py = TL.Apply(m2, c[1], c[2])
						x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
					end
					UI.Button("g15_" .. key, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
						MG.Sound("g15", "menu", 0.6)
						if key == "f239" then self:TryAgain() else self:MoveOn() end
					end, { silent = true })
				end
			end,
		}, sm)
	end
	-- click anywhere to swing (the original's huge invisible button on the nisse while he waits)
	if self.started and self.monF >= 10 and self.monF <= 19 then
		UI.Button("g15_swing", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:MonsterClicked() end, { silent = true })
	end
	-- the start sign
	if not self.started then
		local sm = { 1.25, 0, 0, 1.25, 287.8 - 126.1, 169.1 - 116 }
		TL.Draw(START, 2, {
			item = function(key, m2, ch)
				if key == "f43" then
					UI.Button("g15_start", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function()
						self.started = true
					end, { silent = true })
				end
			end,
		}, sm)
	end
	MG.Chrome(15)
end

AN.RegisterGame(15, G)
