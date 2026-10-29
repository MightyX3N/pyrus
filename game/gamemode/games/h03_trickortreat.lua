-- Halloween: Slik eller ballade (trick or treat). Pyrus walks down the street with his pumpkin
-- bucket: left and right to walk, up to jump, Space to ring the doorbell in front of a door.
-- Most doors give candy, some give a fright (Pyrus stands shaking for a moment), and some
-- nobody opens. The big kids walk the street the other way: jump over them, or they steal
-- some of your candy. 90 seconds; every piece of candy is 10 points.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local N = 203
local W, H = 960, 720
local STEP = 1 / 60
local A = "trick/"
local ROUND = 90
local GY = 600                 -- the pavement
local HOUSE, GAPX = 360, 420   -- a house's width, and from one house to the next
local PH = 170                 -- Pyrus' height
local PW = PH * 514 / 768
local WALK, JUMP, GRAV = 270, 1050, 2200
local PER_CANDY = 10

local DIFF = {
	{ kidEvery = 7, kidSpeed = 120, fright = 0.12, both = false },
	{ kidEvery = 5, kidSpeed = 160, fright = 0.22, both = false },
	{ kidEvery = 3.6, kidSpeed = 200, fright = 0.3, both = true },
}
local KIDS = {
	{ img = "kid_devil.png", w = 342, h = 621, dh = 175 },
	{ img = "kid_witch.png", w = 440, h = 810, dh = 190 },
}

local G = {
	scoreType = "score",
	goal = 2000,
	worst = 0,
	descKey = "su_trickortreat",
}

function G:Status()
	return AN.L("hw_trick_status", self.candy or 0, (self.candy or 0) * PER_CANDY)
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.acc, self.t = 0, 0
	self.left = ROUND
	self.candy = 0
	self.finished, self.overAt = false, nil
	self.px, self.py, self.vy = 120, GY, 0
	self.face = 1
	self.stun = 0
	self.houses = {}
	self.kids = {}
	self.fly = {}
	self.pops = {}
	self.kidAt = 3
	self.kprev = {}
	self.cam = 0
	self.shake = 0
end
function G:Close() end

-- house i (from 0): made the first time it is needed
function G:House(i)
	local h = self.houses[i]
	if h then return h end
	local r = math.random()
	local D = self.D
	h = {
		x = 160 + i * GAPX,
		look = math.random(4),
		jack = math.random() < 0.5,
		state = "closed",
		-- what's behind the door
		out = r < 0.1 and "empty" or (r < 0.1 + D.fright and "fright" or "candy"),
		n = math.random(2, 5),
	}
	h.door = h.x + 180
	self.houses[i] = h
	return h
end

function G:Pressed(k)
	local down = input.IsKeyDown(k)
	local was = self.kprev[k]
	self.kprev[k] = down
	return down and not was
end

function G:Pop(text, x, y, col)
	self.pops[#self.pops + 1] = { text = text, x = x, y = y, t = self.t, col = col or Color(255, 220, 90) }
end

function G:Over()
	if self.overAt then return end
	self.overAt = self.t
	MG.Sound("g14", "done")
end

function G:Step()
	self.t = self.t + STEP
	for i = #self.fly, 1, -1 do
		local f = self.fly[i]
		f.k = f.k + STEP / 0.6
		if f.k >= 1 then table.remove(self.fly, i) end
	end
	if self.overAt then
		if self.t - self.overAt > 2.4 and not self.finished then
			self.finished = true
			AN.FinishGame(N, self.candy * PER_CANDY)
		end
		return
	end
	self.left = self.left - STEP
	if self.left <= 0 then self.left = 0 self:Over() return end
	local D = self.D
	self.shake = math.max(0, self.shake - STEP)
	-- Pyrus
	local onGround = self.py >= GY
	local ring = self:Pressed(KEY_SPACE)
	local jump = self:Pressed(KEY_UP)
	if self.stun > 0 then
		self.stun = self.stun - STEP
	else
		local dx = 0
		if input.IsKeyDown(KEY_LEFT) then dx = dx - 1 end
		if input.IsKeyDown(KEY_RIGHT) then dx = dx + 1 end
		if dx ~= 0 then self.face = dx end
		self.walking = dx ~= 0 and onGround
		self.px = math.max(40, self.px + dx * WALK * STEP)
		if jump and onGround then
			self.vy = -JUMP
			MG.Sound("g01", "jump", 0.5)
		end
	end
	if not onGround or self.vy < 0 then
		self.vy = self.vy + GRAV * STEP
		self.py = self.py + self.vy * STEP
		if self.py >= GY then self.py, self.vy = GY, 0 end
	end
	self.cam = math.max(0, self.px - 300)
	-- the doors
	local first = math.max(0, math.floor((self.cam - 200) / GAPX))
	for i = first, first + 4 do
		local h = self:House(i)
		if h.state == "closed" and ring and onGround and self.stun <= 0 and math.abs(self.px - h.door) < 50 then
			h.state, h.st = "ringing", 0
			ring = false
			MG.Sound("g08", "ding", 0.8)
		elseif h.state == "ringing" then
			h.st = h.st + STEP
			if h.st > 0.55 then
				h.st = 0
				if h.out == "empty" then
					h.state = "done"
					self:Pop(AN.L("hw_trick_empty"), h.door, GY - 240, Color(200, 190, 220))
					MG.Sound("g04", "nomatch", 0.6)
				else
					h.state = "open"
					if h.out == "candy" then
						MG.Sound("g19", "door", 0.6)
					else
						MG.Sound("g10", "witchdie", 0.8)
						self.stun = 1.4
						self.shake = 0.5
						self.vy = -420
						self.py = math.min(self.py, GY - 1)
						self:Pop(AN.L("hw_trick_boo"), h.door, GY - 300, Color(255, 120, 80))
					end
				end
			end
		elseif h.state == "open" then
			h.st = h.st + STEP
			if h.out == "candy" and not h.given and h.st > 0.35 then
				h.given = true
				self.candy = self.candy + h.n
				for c = 1, h.n do
					self.fly[#self.fly + 1] = { x = h.door, y = GY - 80, k = -0.12 * (c - 1), img = "candy" .. math.random(3) .. ".png" }
				end
				self:Pop("+" .. h.n * PER_CANDY, h.door, GY - 220)
				MG.Sound("g01", "pickup", 0.7)
			end
			if h.st > 1.3 then h.state = "done" end
		end
	end
	-- the big kids
	if self.t >= self.kidAt then
		self.kidAt = self.t + D.kidEvery * (0.7 + math.random() * 0.6)
		local fromLeft = D.both and math.random() < 0.3 and self.cam > 200
		local k = KIDS[math.random(#KIDS)]
		self.kids[#self.kids + 1] = {
			k = k, dir = fromLeft and 1 or -1,
			x = fromLeft and (self.cam - 120) or (self.cam + W + 120),
			speed = D.kidSpeed * (0.85 + math.random() * 0.3), ph = math.random() * 6,
		}
	end
	for i = #self.kids, 1, -1 do
		local k = self.kids[i]
		k.x = k.x + k.dir * k.speed * STEP * (k.stole and 2 or 1)
		k.ph = k.ph + STEP
		-- bumping into Pyrus (not when he is over their heads)
		if not k.stole and math.abs(k.x - self.px) < 48 and self.py > GY - 100 then
			k.stole = true
			k.dir = (k.x > self.px) and 1 or -1
			local take = math.min(2, self.candy)
			self.candy = self.candy - take
			if take > 0 then
				self:Pop("-" .. take * PER_CANDY, self.px, GY - 220, Color(255, 110, 80))
				MG.Sound("g17", "steal", 0.8)
			else
				MG.Sound("g01", "giggle", 0.8)
			end
			self.stun = math.max(self.stun, 0.5)
			self.vy = -380
			self.py = math.min(self.py, GY - 1)
		end
		if k.x < self.cam - 400 or k.x > self.cam + W + 400 then table.remove(self.kids, i) end
	end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local WHITE = Color(255, 255, 255)
local GOLD = Color(255, 214, 90)

function G:Paint()
	MG.Stage(W, H)
	local cam = self.cam
	if self.shake > 0 then cam = cam + math.sin(self.t * 70) * 8 * self.shake / 0.5 end
	local function X(wx) return MG.X(wx - cam) end
	-- the sky and the town far away (moving slowly)
	local off = -((cam * 0.2) % 1440) - 240
	AN.Img(A .. "sky.jpg", MG.X(off), MG.Y(0), MG.S(1440), MG.S(H))
	AN.Img(A .. "sky.jpg", MG.X(off + 1440), MG.Y(0), MG.S(1440), MG.S(H))
	-- the houses, with bushes and fences between
	local first = math.max(0, math.floor((cam - 600) / GAPX))
	for i = first, first + 5 do
		local h = self:House(i)
		local hx = h.x
		AN.Img(A .. "fence.png", X(hx - 70), MG.Y(GY - 70), MG.S(190), MG.S(70))
		AN.Img(A .. "house" .. h.look .. ".png", X(hx), MG.Y(GY - 430), MG.S(HOUSE), MG.S(430))
		AN.Img(A .. "bush.png", X(hx - 70), MG.Y(GY - 62), MG.S(120), MG.S(70))
		-- the door
		local dx, dy = h.door - 36, GY - 132
		if h.state == "open" then
			AN.Img(A .. "doorway.png", X(dx), MG.Y(dy), MG.S(72), MG.S(128))
			if h.out == "candy" then
				local k = math.min(1, h.st / 0.25)
				AN.Img(A .. "bowl.png", X(h.door - 10), MG.Y(dy + 60), MG.S(110 * k), MG.S(70 * k))
			else
				local k = math.min(1, h.st / 0.2)
				local s = 0.6 + 0.8 * k
				AN.Img("ghost/ghost.png", X(h.door - 60 * s), MG.Y(GY - 40 - 140 * s), MG.S(120 * s), MG.S(140 * s))
			end
		else
			AN.Img(A .. "door.png", X(dx), MG.Y(dy), MG.S(72), MG.S(128))
		end
		-- the porch lamp: on until the door has been tried
		local on = h.state ~= "done"
		AN.Img(A .. (on and "lamp_on.png" or "lamp_off.png"), X(h.door + 50), MG.Y(GY - 150), MG.S(30), MG.S(40))
		if on then AN.Glow(X(h.door + 65), MG.Y(GY - 128), MG.S(60), Color(255, 220, 120), 0.35) end
		if h.jack then
			AN.Img(A .. "jack.png", X(h.door - 120), MG.Y(GY - 56), MG.S(70), MG.S(60))
		end
		-- ringing: a bell
		if h.state == "ringing" then
			AN.Text(AN.L("hw_trick_ding"), "title", math.floor(MG.S(28)), X(h.door + 20 + math.sin(h.st * 30) * 4), MG.Y(dy - 30), GOLD, 1, 1)
		end
		-- standing in front of an untried door: show Space
		if h.state == "closed" and math.abs(self.px - h.door) < 50 and self.py >= GY then
			local a = 180 + 75 * math.sin(self.t * 6)
			AN.Box(X(h.door) - MG.S(70), MG.Y(dy - 50), MG.S(140), MG.S(34), Color(30, 10, 40, 200), MG.S(17))
			AN.Text(AN.L((AN.VS and AN.VS.Split and AN.VS.Split.on) and "hw_trick_ring_sp" or "hw_trick_ring"), "bold", math.floor(MG.S(18)), X(h.door), MG.Y(dy - 33), Color(255, 240, 200, a), 1, 1)
		end
	end
	-- the pavement and the street
	AN.Box(MG.X(-600), MG.Y(GY - 4), MG.S(W + 1200), MG.S(60), Color(84, 74, 96))
	AN.Box(MG.X(-600), MG.Y(GY - 4), MG.S(W + 1200), MG.S(6), Color(120, 108, 132))
	AN.Box(MG.X(-600), MG.Y(GY + 56), MG.S(W + 1200), MG.S(H - GY), Color(40, 34, 50))
	for i = math.floor((cam - 600) / 120), math.floor((cam + W + 600) / 120) do
		AN.Box(X(i * 120), MG.Y(GY + 2), MG.S(3), MG.S(54), Color(70, 60, 82))
		AN.Box(X(i * 120 + 30), MG.Y(GY + 100), MG.S(60), MG.S(8), Color(200, 190, 140, 120))
	end
	-- the big kids
	for _, k in ipairs(self.kids) do
		local kk = k.k
		local dh = kk.dh
		local dw = dh * kk.w / kk.h
		local bob = math.abs(math.sin(k.ph * 9)) * 6
		local flip = k.dir > 0
		SU.Img(A .. kk.img, MG.X(k.x - cam - dw / 2), MG.Y(GY - dh - bob + 4), MG.S(dw), MG.S(dh), flip)
		if k.stole then
			AN.Text(AN.L("hw_trick_haha"), "title", math.floor(MG.S(24)), MG.X(k.x - cam), MG.Y(GY - dh - 30), WHITE, 1, 1)
		end
	end
	-- Pyrus
	local bob = self.walking and math.abs(math.sin(self.t * 12)) * 5 or 0
	local shiver = self.stun > 0 and math.sin(self.t * 60) * 3 or 0
	SU.Img("halloween/pyrus_cape.png", MG.X(self.px - cam - PW / 2 + shiver), MG.Y(self.py - PH - bob + 4), MG.S(PW), MG.S(PH), self.face < 0)
	if self.stun > 0.6 then
		AN.Text("!", "title", math.floor(MG.S(48)), MG.X(self.px - cam), MG.Y(self.py - PH - 30), Color(255, 220, 90), 1, 1)
	end
	-- candy flying into the bucket (top left)
	local bx, by = 70, 100
	for _, f in ipairs(self.fly) do
		if f.k > 0 then
			local k = f.k
			local x = (f.x - cam) + (bx - (f.x - cam)) * k
			local y = f.y + (by - f.y) * k - math.sin(k * math.pi) * 160
			AN.Img(A .. f.img, MG.X(x - 20), MG.Y(y - 13), MG.S(40), MG.S(26))
		end
	end
	-- the points
	for i = #self.pops, 1, -1 do
		local p = self.pops[i]
		local age = self.t - p.t
		if age > 1.2 then table.remove(self.pops, i) else
			local c = p.col
			AN.Text(p.text, "title", math.floor(MG.S(32)), MG.X(p.x - cam), MG.Y(p.y - age * 40), Color(c.r, c.g, c.b, 255 * math.min(1, 1.2 - age)), 1, 1)
		end
	end
	-- the bucket and the top bar
	AN.Img(A .. "bucket.png", MG.X(bx - 45), MG.Y(by - 45), MG.S(90), MG.S(90))
	AN.Text(tostring(self.candy), "title", math.floor(MG.S(30)), MG.X(bx), MG.Y(by + 60), GOLD, 1, 1)
	AN.Box(MG.X(W / 2 - 300), MG.Y(14), MG.S(600), MG.S(48), Color(30, 10, 40, 210), MG.S(24))
	local secs = math.ceil(self.left)
	AN.Text(AN.L("hw_time", secs), "title", math.floor(MG.S(24)), MG.X(W / 2 - 200), MG.Y(38), secs <= 10 and Color(255, 120, 80) or WHITE, 1, 1)
	AN.Text(AN.L("hw_trick_count", self.candy), "title", math.floor(MG.S(24)), MG.X(W / 2), MG.Y(38), WHITE, 1, 1)
	AN.Text(AN.L("hw_points", self.candy * PER_CANDY), "title", math.floor(MG.S(24)), MG.X(W / 2 + 200), MG.Y(38), GOLD, 1, 1)
	if not (AN.VS and AN.VS.Split and AN.VS.Split.on) then
		AN.Text(AN.L("hw_trick_keys"), "bold", math.floor(MG.S(16)), MG.X(W / 2), MG.Y(H - 24), Color(255, 240, 210, 170), 1, 1)
	end
	if self.overAt then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(30, 10, 40, 220 * a), MG.S(30))
		AN.Text(AN.L("hw_timeup"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.candy * PER_CANDY, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(N)
end

AN.RegisterGame(N, G)
