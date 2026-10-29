-- Låge 3: Biblioteks Ræs
-- Rebuilt from the original loader.swf: Pyrus flies through the library on a card, you steer
-- him with the mouse between the falling bookshelves. Same rules as the original game clip:
-- 25 steps a second, the speed grows by 0.0142 every step (max 30), new shelves come more
-- often the faster it goes, and the points are the steps survived / 2.
local UI, C, MG = AN.UI, AN.Col, AN.MG
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/g03_pos.lua")
local P = AN.G03Pos

local G = {
	scoreType = "score",
	goal = 600,       -- the original coolScore
	worst = 0,
	descKey = "desc_03",
	howKey = "how_03",
}

local STAGE_W, STAGE_H = 600, 450
local SX, SY = 1.4996, 1.5086          -- the game clip's scale on the stage
local XMIN, XMAX = 20, 375
local ME_Y = 217.2
local STEP = 1 / 25
-- the shelves, in the original order (o0 .. o4); hit boxes from each clip's "hit" child
local SHELVES = {
	{ img = "o18", hit = { -0.2, -6.25, 19.033, 39.223 } },
	{ img = "o12", hit = { 1.7, 1.15, 43.911, 20.267 } },
	{ img = "o17", hit = { -0.2, -6.0, 21.474, 43.377 } },
	{ img = "o19", hit = { 1.7, 1.15, 43.911, 20.267 } },
	{ img = "o30", hit = { -4.2, -8.35, 20.589, 44.101 } },
}
local ME_HIT = { 0.5, -8.7, 21.480, 34.046 }

-- inner game coordinates -> stage
local function IX(x) return x * SX end
local function IY(y) return y * SY end

-- a picture of a clip at (x, y) in game coordinates, drawn at the clip scale 1.4
local function clip(name, x, y, alpha)
	local r = P[name]
	if not r then return end
	MG.Img("g03/" .. name .. ".png", IX(x + r[1] * 1.4), IY(y + r[2] * 1.4), IX(r[3] * 1.4), IY(r[4] * 1.4), alpha)
end

local function hitRect(x, y, h)
	-- h = centre x, centre y, w, h in clip coordinates (scale 1.4)
	return x + (h[1] - h[3] / 2) * 1.4, y + (h[2] - h[4] / 2) * 1.4, h[3] * 1.4, h[4] * 1.4
end

local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

function G:Status()
	return AN.L("g03_status", self.temp or 0)
end

function G:Open(args)
	self.finished = false   -- a new round (this was left over from the last one, so the sign never went away)
	self.signAt = nil
	self.temp = 0
	self.fcount = 0
	self.ncount = 0
	self.speed = 3.5
	self.actObst = 0
	self.bgY = -300
	self.state = "COUNT"
	self.slowLeft = nil
	MG.ResetPops()
	self.countStep = 0
	self.crash = 0
	self.crashId = nil
	self.acc = 0
	self.meX = 160
	self.obst = {}
	for i, s in ipairs(SHELVES) do
		self.obst[i] = { def = s, x = 0, y = -1000, active = false, dead = 0 }
	end
	MG.Sound("g03", "tuut")
end

function G:StartNewObst()
	if self.actObst < #SHELVES - 1 then
		self.actObst = self.actObst + 1
		for _, o in ipairs(self.obst) do
			if not o.active then
				o.active = true
				o.x = XMIN + math.Round(math.random() * ((XMAX - XMIN) / 20)) * 20
				o.y = -19 + math.fmod(self.bgY, 20)
				break
			end
		end
	end
end

-- one step of the original game clip
function G:Step()
	if self.state == "COUNT" then
		self.countStep = self.countStep + 1
		if self.countStep >= 49 then self.state = "ON" end
		return
	end
	if self.state == "ON" then
		self.temp = math.Round(self.fcount / 2)
		self.ncount = self.ncount + 1
		if 15 - self.speed / 2 < self.ncount and self.actObst < 2 + self.speed / 8 then
			self:StartNewObst()
			self.ncount = 0
		end
		local mx, my, mw, mh = hitRect(self.meX, ME_Y, ME_HIT)
		for i, o in ipairs(self.obst) do
			if o.active then o.y = o.y + self.speed end
			if o.y > 385 then
				o.active = false
				o.y = -1000
				self.actObst = self.actObst - 1
			elseif ME_Y - 30 < o.y then
				local ox, oy, ow, oh = hitRect(o.x, o.y, o.def.hit)
				if overlap(mx, my, mw, mh, ox, oy, ow, oh) then
					self.crashId = i
					self.state = "GAMEOVER"
				end
			end
		end
		self.fcount = self.fcount + 1
		self.speed = math.min(30, self.speed + 0.0142)
		self.bgY = self.bgY + self.speed
		if self.bgY >= 0 then
			MG.Sound("g03", "peep", 0.6)
			self.bgY = self.bgY - 300
		end
	elseif self.state == "GAMEOVER" then
		self.speed = 0
		self.crash = self.crash + 1
		if self.crash == 1 then MG.Sound("g03", "hit") end
		if self.crash > 30 then
			self.state = "SIGN"
			self.signAt = RealTime()
			AN.Speak("gameover")
		end
	end
end

-- hint: 3 seconds of slow motion (the game runs at half speed)
function G:CanHint() return self.state == "ON" and not self.slowLeft end
function G:Hint(cost)
	self.slowLeft = 3
	self.fcount = math.max(0, self.fcount - cost * 2)   -- the points are the steps / 2
	self.temp = math.Round(self.fcount / 2)
	MG.Pop("-" .. cost, false, 300, 380)
end

function G:Think(dt)
	if self.slowLeft then
		self.slowLeft = self.slowLeft - dt
		if self.slowLeft <= 0 or self.state ~= "ON" then self.slowLeft = nil else dt = dt * 0.5 end
	end
	-- steer: the card follows the mouse sideways (the original startDrag with locked y)
	if (self.state == "COUNT" or self.state == "ON") and MG.k and MG.sw == STAGE_W then
		local mx = MG.Mouse()
		self.meX = math.Clamp(mx / SX, XMIN + 5, XMAX - 5)
	end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	if self.state == "SIGN" and RealTime() - self.signAt > 3.2 then self:Finish() end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(3, self.temp)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	-- the floor, scrolling
	local bgy = self.bgY
	MG.Img("g03/bg.jpg", 0, IY(bgy), IX(400), IY(300))
	MG.Img("g03/bg.jpg", 0, IY(bgy + 300), IX(400), IY(300))
	MG.Img("g03/bg.jpg", 0, IY(bgy + 600), IX(400), IY(300))

	-- shelves (the one you hit blinks red like the original "dead" frames)
	local blink = self.crash > 0 and ((self.crash - 1) % 10 >= 3 and (self.crash - 1) % 10 <= 5)
	for i, o in ipairs(self.obst) do
		if o.y > -100 then
			local name = o.def.img
			if blink and i == self.crashId then name = name .. "_hit" end
			clip(name, o.x, o.y)
		end
	end
	clip(blink and "me_hit" or "me", self.meX, ME_Y)

	-- countdown 3, 2, 1 (the original countdown clip: 49 frames)
	if self.state == "COUNT" then
		local f = self.countStep
		local name = f < 12 and "cd3" or (f < 25 and "cd2" or "cd1")
		local r = P[name]
		local k = 2.4
		MG.Img("g03/" .. name .. ".png", IX(200) + r[1] * k, IY(151.2) + r[2] * k, r[3] * k, r[4] * k)
	end

	-- points (the original "termometer" text at the bottom)
	local pr = P.points
	MG.Img("g03/points.png", 336.55 + pr[1], 413.85 + pr[2], pr[3], pr[4])
	AN.Text(tostring(self.temp), "title", math.floor(MG.S(27)), MG.X(300), MG.Y(407), C.cream)

	if self.slowLeft then
		MG.HintText(AN.L("hint_slow"), 300, 40, MG.HINT_GOLD, 26, math.min(1, self.slowLeft * 2))
	end
	MG.DrawPops()

	-- "Spil Slut!" sign
	if self.state == "SIGN" then
		local sr = P.sign
		if AN.LangCode() == "da" then
			MG.Img("g03/sign_da.png", sr[1], sr[2], sr[3], sr[4])
		else
			MG.Img("g03/sign.png", sr[1], sr[2], sr[3], sr[4])
			AN.Text(AN.L("g03_over"), "title", math.floor(MG.S(46)), MG.X(300), MG.Y(150), C.cream, 1)
			AN.Text(AN.L("g03_points"), "title", math.floor(MG.S(15)), MG.X(180), MG.Y(229), C.cream)
		end
		AN.Text(tostring(self.temp), "title", math.floor(MG.S(22)), MG.X(300), MG.Y(224), C.cream)
		if RealTime() - self.signAt > 0.8 then
			AN.Text(AN.L("g03_click"), "black", math.floor(MG.S(11)), MG.X(300), MG.Y(318), Color(255, 241, 207, 210), 1)
		end
		-- click to go on (the original "skip" button)
		UI.Button("g03_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:Finish() end, { silent = true })
	end

	MG.Chrome(3)
end

AN.RegisterGame(3, G)
