-- Låge 4: Huskespil ("Memory Monsters")
-- Rebuilt from the original memory.swf: same 15 monster cards, same layout rule,
-- same scoring (fast pairs give more, streaks give a bonus, a miss costs 6),
-- 10 levels from 5 to 14 pairs, and Gyldengrød watching with his original animations.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local G = {
	scoreType = "score",
	goal = 6000,      -- the original "coolScore"
	levels = 10,
	worst = 0,        -- the original has no badScore for points games: 0 points = 3 pebernødder
	descKey = "desc_04",
	howKey = "how_04",
}

local GYLD = include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/g04_gyld.lua")

local STAGE_W, STAGE_H = 770, 440
local AREA = { x = 189.55, y = 9.5, w = 643.5 - 189.55, h = 392.45 - 9.5 }   -- handle1 -> handle2
local CARD_IMG = { ox = -33, oy = -42, w = 70.5, h = 89.5 }                   -- card png relative to card origin
local LAST_LEVEL = 10

-- Gyldengrød's animations (frame ranges from the original timeline, 25 fps)
local ANIMS = {
	atease     = { 16, 95 },
	nanim1     = { 97, 143 },
	nanim2     = { 146, 216 },
	nanim3     = { 220, 255 },
	take1      = { 257, 324 },
	takepoint  = { 327, 400 },
	fallasleep = { 403, 480, "snoreloop" },
	snoreloop  = { 481, 554, "snoreloop" },
	wakeup     = { 556, 608 },
	point2     = { 611, 682 },
	scratch    = { 689, 750 },
}
-- where his sprite sits on the stage (top-left and size of one packed frame)
local GY = { x = 3.9, y = 53.46, w = 233 / 1.25536, h = 351 / 1.25536 }

---------------------------------------------------------------------------
-- Gyldengrød
---------------------------------------------------------------------------
function G:Anim(name)
	self.anim = name
	self.animFrame = ANIMS[name][1]
	self.animAcc = 0
	if name == "fallasleep" then self.sleeping = true end
end

function G:UpdateAnim(dt)
	self.animAcc = self.animAcc + dt * 25
	while self.animAcc >= 1 do
		self.animAcc = self.animAcc - 1
		self.animFrame = self.animFrame + 1
		local a = ANIMS[self.anim]
		if self.animFrame > a[2] then
			if self.anim == "atease" then
				self.animFrame = 20 + math.random(0, 69)
			else
				local nxt = a[3] or "atease"
				if self.anim == "wakeup" then self.sleeping = false end
				self:Anim(nxt)
			end
		end
	end
	-- the original "idletimer": random small animations, falls asleep when left alone
	if self.anim == "atease" and self.state == "play" then
		self.idleAcc = (self.idleAcc or 0) + dt * 25
		while self.idleAcc >= 1 do
			self.idleAcc = self.idleAcc - 1
			if math.random() > 0.995 then
				self:Anim("nanim" .. math.random(1, 3))
				break
			elseif self.sleepyTime + 15 < RealTime() and math.random() > 0.997 then
				self:Anim("fallasleep")
				break
			end
		end
	end
end

function G:DrawGyld()
	local f = self.animFrame
	local idx = GYLD.seq[f] or 0
	local atlas = GYLD.atlases[math.floor(idx / GYLD.per) + 1]
	local cell = idx % GYLD.per
	local col, row = cell % GYLD.cols, math.floor(cell / GYLD.cols)
	local u0, v0 = col * GYLD.w / atlas[2], row * GYLD.h / atlas[3]
	local u1, v1 = (col + 1) * GYLD.w / atlas[2], (row + 1) * GYLD.h / atlas[3]
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(AN.Mat(atlas[1]))
	surface.DrawTexturedRectUV(AN.PX(MG.X(GY.x)), AN.SY(MG.Y(GY.y)), AN.SX(MG.S(GY.w)), AN.SX(MG.S(GY.h)), u0, v0, u1, v1)
end

---------------------------------------------------------------------------
-- Game flow
---------------------------------------------------------------------------
function G:Open(args)
	self.state = "start"
	self.score = 0
	self.level = 0
	self.cards = {}
	self.sleeping = false
	self.sleepyTime = RealTime()
	self:Anim("atease")
	MG.ResetPops()
	-- the wrapper's Start button brings you here, so the game begins right away
	self:StartGame()
end

function G:Status()
	return AN.L("g04_status", math.max(1, self.level or 1), self.score or 0)
end

function G:StartGame()
	self.score = 0
	self.level = 0
	self.state = "play"
	self:NewLevel()
end

function G:NewLevel()
	self.level = self.level + 1
	self.levelStartScore = self.score
	local pairs = 5 + (self.level - 1)
	local n = pairs * 2
	self.pairsLeft = pairs
	self.turned = nil
	self.pressOk = true
	self.streak = 0
	self.lastPairTime = RealTime()
	self.nextLevelSign = false
	self.timers = {}

	-- pick different pictures for the pairs, then shuffle
	local pics = {}
	for i = 0, 14 do pics[#pics + 1] = i end
	for i = #pics, 2, -1 do local j = math.random(i) pics[i], pics[j] = pics[j], pics[i] end
	local deck = {}
	for p = 1, pairs do
		deck[#deck + 1] = { pair = p, img = pics[p] }
		deck[#deck + 1] = { pair = p, img = pics[p] }
	end
	for i = #deck, 2, -1 do local j = math.random(i) deck[i], deck[j] = deck[j], deck[i] end

	-- original layout: a loose grid with random offsets and tilt, scaled to fit the card area
	local antalx = math.floor(math.sqrt((AREA.w + 32) / (AREA.h + 4) / 0.9 * n) + 0.5)
	local antaly = math.ceil(n / antalx)
	local sc = math.min(AREA.w / antalx, AREA.h / antaly) / 100
	self.cardScale = sc
	self.cards = {}
	local k = 1
	for t = 0, antaly - 1 do
		for tt = 0, antalx - 1 do
			local c = deck[k]
			if c then
				c.hx = tt * 90 + 50 + math.random(0, 29) - 15
				c.hy = 100 * t + 50 + math.random(0, 29) - 15
				c.rot = math.random(0, 29) - 15
				c.x = AREA.x + c.hx * sc
				c.y = AREA.y + c.hy * sc
				c.face = false       -- showing the picture?
				c.flipT = nil        -- time a flip started
				c.flipTo = nil
				c.picked = 0
				c.matched = false
				self.cards[k] = c
			end
			k = k + 1
		end
	end
	-- deal-in animation
	self.dealT = RealTime()
end

function G:After(delay, fn)
	self.timers[#self.timers + 1] = { t = RealTime() + delay, fn = fn }
end

function G:Flip(c, toFace)
	c.flipT = RealTime()
	c.flipTo = toFace
end

function G:CardClicked(c)
	if not self.pressOk or c.face or c.flipT or c.matched then return end
	if self.sleeping and self.anim ~= "wakeup" then self:Anim("wakeup") end
	self:Flip(c, true)
	c.picked = c.picked + 1
	MG.Sound("g04", "turn")
	if not self.turned then
		self.turned = c
		-- Gyldengrød reacts: scratches his head if you've seen the partner a few times
		local partner
		for _, o in ipairs(self.cards) do if o ~= c and o.pair == c.pair then partner = o end end
		if not self.sleeping and self.anim == "atease" then
			if partner and partner.picked > 2 then self:Anim("scratch")
			elseif math.random() > 0.9 then self:Anim("point2") end
		end
		return
	end

	local a, b = self.turned, c
	self.turned = nil
	local mx, my = (a.x + b.x) / 2, (a.y + b.y) / 2
	if a.pair ~= b.pair then
		self.pressOk = false
		self.score = self.score - 6
		MG.Pop("-6", false, mx, my)
		self.streak = 0
		self:After(0.85, function()
			MG.Sound("g04", "nomatch")
			self:Flip(a, false)
			self:Flip(b, false)
			self.lastPairTime = RealTime()
			self.pressOk = true
		end)
	else
		a.matched, b.matched = true, true
		self.streak = self.streak + 1
		-- points: faster pairs give more (original formula)
		local mod = ((RealTime() - self.lastPairTime) * 1000 + 2000) / 2000
		local pts = math.floor(10 * (5 + self.level - 1) / mod + 0.5)
		if self.streak > 1 then
			local bonus = self.streak * 10
			MG.Pop(pts .. " + " .. bonus, true, mx, my)
			AN.Speak("huskespillet_bonus01", true)
			pts = pts + bonus
		else
			MG.Pop(tostring(pts), true, mx, my)
		end
		self.score = self.score + pts
		self.sleepyTime = RealTime()
		self.pairsLeft = self.pairsLeft - 1
		if self.pairsLeft > 0 and not self.sleeping then
			if math.random() > 0.3 then self:Anim("take1") else self:Anim("takepoint") end
		end
		self:After(0.6, function()
			MG.Sound("g04", "match")
			self.lastPairTime = RealTime()
			if self.pairsLeft <= 0 then
				AN.LevelScore(4, self.level, self.score - (self.levelStartScore or 0), { total = math.max(0, self.score) })
				if self.level >= LAST_LEVEL then
					self:Finish()
				else
					self.nextLevelSign = true
					MG.Sound("g04", "level", 0.6)
					AN.Speak("huskespillet_levelslut")
				end
			end
		end)
	end
end

-- hint: every card still face down is turned up for a second, then back
function G:CanHint()
	return self.state == "play" and self.pressOk and not self.nextLevelSign and (self.pairsLeft or 0) > 0
end
function G:Hint(cost)
	local shown = {}
	for _, c in ipairs(self.cards) do
		if not c.matched and not c.face and not c.flipT then
			self:Flip(c, true)
			shown[#shown + 1] = c
		end
	end
	if #shown == 0 then return false end
	self.pressOk = false
	self.score = self.score - cost
	MG.Pop("-" .. cost, false, 87, 340)
	MG.Sound("g04", "turn")
	self:After(1.2, function()
		for _, c in ipairs(shown) do self:Flip(c, false) end
		MG.Sound("g04", "turn")
		self:After(0.25, function()
			self.lastPairTime = self.lastPairTime + 1.45   -- the time looking doesn't count against the pair
			self.pressOk = true
		end)
	end)
end

function G:Finish()
	self.state = "done"
	AN.FinishGame(4, math.max(0, self.score))
end

function G:Think(dt)
	dt = math.min(dt, 0.1)
	self:UpdateAnim(dt)
	if self.timers then
		local now = RealTime()
		for i = #self.timers, 1, -1 do
			local t = self.timers[i]
			if now >= t.t then
				table.remove(self.timers, i)
				t.fn()
			end
		end
	end
	-- finish flips (0.2 s)
	for _, c in ipairs(self.cards) do
		if c.flipT and RealTime() - c.flipT >= 0.2 then
			c.face = c.flipTo
			c.flipT = nil
		end
	end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function G:DrawCard(c, i)
	local sc = self.cardScale
	-- flip: squash horizontally, switch face half way
	local xs = 1
	local showFace = c.face
	if c.flipT then
		local t = math.Clamp((RealTime() - c.flipT) / 0.2, 0, 1)
		xs = math.abs(math.cos(t * math.pi))
		if t >= 0.5 then showFace = c.flipTo else showFace = not c.flipTo end
		xs = math.max(xs, 0.05)
	end
	-- deal in: drop from above with a little delay per card
	local dy = 0
	local dt = RealTime() - (self.dealT or 0) - i * 0.03
	if dt < 0.35 then
		local t = math.Clamp(dt / 0.35, 0, 1)
		dy = -(1 - t) * (1 - t) * 60
		if dt < 0 then return end
	end
	local path = showFace and string.format("g04/card%02d.png", c.img) or "g04/back.png"
	local w, h = CARD_IMG.w * sc, CARD_IMG.h * sc
	-- image centre relative to the card origin, rotated with the card
	local ox, oy = (CARD_IMG.ox + CARD_IMG.w / 2) * sc, (CARD_IMG.oy + CARD_IMG.h / 2) * sc
	local a = math.rad(c.rot)
	local cx = c.x + ox * math.cos(a) - oy * math.sin(a)
	local cy = c.y + dy + ox * math.sin(a) + oy * math.cos(a)
	local hot = UI.Hot("card" .. i) and self.pressOk and not c.face and not c.flipT
	local lift = hot and 1.05 or 1
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(AN.Mat(path))
	surface.DrawTexturedRectRotated(AN.PX(MG.X(cx)), AN.SY(MG.Y(cy)), AN.SX(MG.S(w * xs * lift)), AN.SX(MG.S(h * lift)), -c.rot)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	-- board, built wide (stage x -500 .. 1300) from the original wood so ultrawide shows more of the room
	MG.Backdrop("g04/bg.jpg", -500, 0, 1800, 440)
	self:DrawGyld()

	-- HUD: level and score (original positions)
	local lvl = self.level
	AN.Text(AN.L("g04_level"), "title", math.floor(MG.S(13)), MG.X(19.5), MG.Y(343), C.cream)
	AN.Text(lvl .. " / " .. LAST_LEVEL, "title", math.floor(MG.S(13)), MG.X(87), MG.Y(343), C.white)
	AN.Text(AN.L("g04_score"), "title", math.floor(MG.S(13)), MG.X(19.5), MG.Y(372), C.cream)
	AN.Text(tostring(self.score), "title", math.floor(MG.S(13)), MG.X(87), MG.Y(372), C.white)

	if self.state == "play" or self.state == "done" then
		-- cards (register click regions first so the topmost card wins)
		local sc = self.cardScale or 1
		for i, c in ipairs(self.cards) do
			local hw, hh = 33 * sc, 42 * sc
			UI.Button("card" .. i, MG.X(c.x - hw), MG.Y(c.y - hh), MG.S(hw * 2), MG.S(hh * 2), function() self:CardClicked(c) end, { silent = true })
		end
		for i, c in ipairs(self.cards) do self:DrawCard(c, i) end
		MG.DrawPops()

		-- "Stop nu!" ends the game with the points you have
		local stopPath = AN.LangCode() == "da" and "g04/stop_da.png" or "g04/stop_en.png"
		local hot = UI.Button("stop", MG.X(313), MG.Y(362), MG.S(131), MG.S(65), function() self:Finish() end)
		local lift = hot and 3 or 0
		MG.Img(stopPath, 313, 362 - lift, 131)

		if self.nextLevelSign then
			local p = AN.LangCode() == "da" and "g04/next_da.png" or "g04/next_en.png"
			local w = 290
			local h = w * AN.Ratio(p)
			local x, y = 445, 380 - h
			local hot2 = UI.Button("next", MG.X(x), MG.Y(y), MG.S(w), MG.S(h), function()
				self.nextLevelSign = false
				self:NewLevel()
			end)
			if hot2 then AN.Glow(MG.X(x + w / 2), MG.Y(y + h / 2), MG.S(w * 0.7), C.gold, 0.6) end
			MG.Img(p, x, y - (hot2 and 4 or 0), w)
		end
	end

	MG.Chrome(4)
end

AN.RegisterGame(4, G)
