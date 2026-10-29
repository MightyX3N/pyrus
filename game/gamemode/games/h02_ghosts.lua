-- Halloween: Spøgelsesjagt (ghost hunt). The hall of the haunted house is dark; steer the
-- flashlight with the arrow keys. The ghosts can only be seen in the light (in the dark only their
-- eyes glimmer): keep the light on one until it is caught. Quick catches score more. Bats hang
-- in the hall: shine on one and it flaps around, and every ghost you were catching gets away.
-- 90 seconds.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local N = 202
local W, H = 960, 720
local STEP = 1 / 60
local A = "ghost/"
local ROUND = 90
local GW, GH = 100, 117           -- a ghost's size
local X0, X1, Y0, Y1 = 70, 890, 110, 520   -- where the ghosts float

local DIFF = {
	{ R = 165, catch = 0.8, wander = 30, flee = 0, maxG = 2, bats = 1, eyes = 110, life = 14, dark = 230 },
	{ R = 150, catch = 1.1, wander = 50, flee = 80, maxG = 3, bats = 2, eyes = 90, life = 12, dark = 240 },
	{ R = 135, catch = 1.3, wander = 75, flee = 150, maxG = 3, bats = 4, eyes = 70, life = 10, dark = 248 },
}
-- where the bats hang (stage units: the beam above the hall, the frames, the clock)
local HANGS = { { 150, 48 }, { 300, 48 }, { 520, 48 }, { 700, 48 }, { 860, 48 }, { 215, 130 }, { 455, 290 }, { 695, 190 } }
local PTS_GHOST, PTS_QUICK, PTS_BAT = 100, 60, 20
local DARK = Color(6, 2, 12)

local G = {
	scoreType = "score",
	goal = 2500,
	worst = 0,
	descKey = "su_ghosts",
}

function G:Status()
	return AN.L("hw_ghost_status", self.caught or 0, self.score or 0)
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.acc, self.t = 0, 0
	self.left = ROUND
	self.score, self.caught = 0, 0
	self.finished, self.overAt = false, nil
	self.bx, self.by = W / 2, H - 150
	self.ghosts, self.puffs, self.pops = {}, {}, {}
	self.spawnAt = 0.8
	self.bats = {}
	local free = {}
	for i = 1, #HANGS do free[i] = i end
	for i = 1, self.D.bats do
		local k = table.remove(free, math.random(#free))
		self.bats[i] = { hang = k, x = HANGS[k][1], y = HANGS[k][2], state = "hang", lit = 0 }
	end
end
function G:Close() end

function G:Pop(text, x, y, col)
	self.pops[#self.pops + 1] = { text = text, x = x, y = y, t = self.t, col = col }
end

function G:Spawn()
	-- somewhere away from the light
	local x, y
	for _ = 1, 12 do
		x, y = math.random(X0, X1), math.random(Y0, Y1)
		if (x - self.bx) ^ 2 + (y - self.by) ^ 2 > (self.D.R * 1.8) ^ 2 then break end
	end
	local a = math.random() * math.pi * 2
	self.ghosts[#self.ghosts + 1] = { x = x, y = y, vx = math.cos(a), vy = math.sin(a), ph = math.random() * 6, age = 0, fade = 0, catch = 0 }
	MG.Sound("g08", "whoosh", 0.35)
end

function G:Over()
	if self.overAt then return end
	self.overAt = self.t
	MG.Sound("g14", "done")
end

function G:Step()
	self.t = self.t + STEP
	for i = #self.puffs, 1, -1 do
		if self.t - self.puffs[i].t > 0.7 then table.remove(self.puffs, i) end
	end
	if self.overAt then
		if self.t - self.overAt > 2.4 and not self.finished then
			self.finished = true
			AN.FinishGame(N, self.score)
		end
		return
	end
	self.left = self.left - STEP
	if self.left <= 0 then self.left = 0 self:Over() return end
	local D = self.D
	-- the flashlight
	local dx, dy = 0, 0
	if input.IsKeyDown(KEY_LEFT) then dx = dx - 1 end
	if input.IsKeyDown(KEY_RIGHT) then dx = dx + 1 end
	if input.IsKeyDown(KEY_UP) then dy = dy - 1 end
	if input.IsKeyDown(KEY_DOWN) then dy = dy + 1 end
	if dx ~= 0 or dy ~= 0 then
		local l = math.sqrt(dx * dx + dy * dy)
		self.bx = math.Clamp(self.bx + dx / l * 380 * STEP, 30, W - 30)
		self.by = math.Clamp(self.by + dy / l * 380 * STEP, 40, H - 60)
	end
	-- new ghosts
	if #self.ghosts < D.maxG and self.t >= self.spawnAt then
		self:Spawn()
		self.spawnAt = self.t + 1.2
	end
	local R = D.R
	for i = #self.ghosts, 1, -1 do
		local g = self.ghosts[i]
		g.age = g.age + STEP
		g.fade = g.leaving and math.max(0, g.fade - STEP * 1.5) or math.min(1, g.fade + STEP * 1.5)
		local ddx, ddy = g.x - self.bx, g.y - self.by
		local d = math.sqrt(ddx * ddx + ddy * ddy)
		local inLight = d < R * 0.7 and g.fade > 0.5 and not g.leaving
		g.lit = d < R + 30
		-- drifting about, and away from the light
		g.ph = g.ph + STEP
		local sp = D.wander
		local vx, vy = g.vx * sp, g.vy * sp
		if g.lit and D.flee > 0 and d > 1 then
			local f = D.flee * (1 - math.min(1, g.catch * 0.6))
			vx, vy = vx + ddx / d * f, vy + ddy / d * f
		end
		g.x = g.x + vx * STEP + math.cos(g.ph * 1.3) * 18 * STEP
		g.y = g.y + vy * STEP + math.sin(g.ph * 2.1) * 26 * STEP
		if g.x < X0 then g.x, g.vx = X0, math.abs(g.vx) elseif g.x > X1 then g.x, g.vx = X1, -math.abs(g.vx) end
		if g.y < Y0 then g.y, g.vy = Y0, math.abs(g.vy) elseif g.y > Y1 then g.y, g.vy = Y1, -math.abs(g.vy) end
		if math.random() < STEP * 0.4 then
			local a = math.random() * math.pi * 2
			g.vx, g.vy = math.cos(a), math.sin(a)
		end
		-- catching
		if inLight then
			g.catch = g.catch + STEP / D.catch
			if g.catch >= 1 then
				local pts = PTS_GHOST + math.max(0, math.floor(PTS_QUICK - g.age * 6))
				self.score = self.score + pts
				self.caught = self.caught + 1
				self:Pop("+" .. pts, g.x, g.y - 40, Color(200, 255, 160))
				self.puffs[#self.puffs + 1] = { x = g.x, y = g.y, t = self.t }
				MG.Sound("g16", "eat_ghost", 0.8)
				table.remove(self.ghosts, i)
				self.spawnAt = math.max(self.spawnAt, self.t + 0.6)
				if self.caught % 10 == 0 then AN.Speak("megetgodt") end
			end
		else
			g.catch = math.max(0, g.catch - STEP * 0.5)
		end
		if g.ghostGone then table.remove(self.ghosts, i) end
		-- a ghost that has floated about for long enough goes away (and another comes)
		if g.age > D.life and not g.leaving and g.catch <= 0 then g.leaving = true end
		if g.leaving and g.fade <= 0 then g.ghostGone = true end
	end
	-- the bats
	for _, b in ipairs(self.bats) do
		if b.state == "hang" then
			local near = (b.x - self.bx) ^ 2 + (b.y + 20 - self.by) ^ 2 < 60 * 60
			b.lit = near and b.lit + STEP or 0
			if b.lit > 0.25 and self.t > 1.5 then self:Startle(b) end
		else
			b.ft = b.ft + STEP
			b.x = b.x + b.vx * STEP
			b.y = b.y + math.sin(b.ft * 6) * 120 * STEP + b.vy * STEP
			if b.x < 40 or b.x > W - 40 then b.vx = -b.vx end
			if b.y < 60 or b.y > H - 140 then b.vy = -b.vy end
			if b.ft > 2.6 then
				-- back to a free hanging place
				local used = {}
				for _, o in ipairs(self.bats) do if o ~= b and o.state == "hang" then used[o.hang] = true end end
				local k
				repeat k = math.random(#HANGS) until not used[k]
				b.hang, b.x, b.y, b.state, b.lit = k, HANGS[k][1], HANGS[k][2], "hang", 0
			end
		end
	end
end

function G:Startle(b)
	b.state = "fly"
	b.ft = 0
	b.vx = (math.random() < 0.5 and -1 or 1) * math.random(260, 360)
	b.vy = math.random(80, 160)
	self.score = math.max(0, self.score - PTS_BAT)
	self:Pop("-" .. PTS_BAT, b.x, b.y + 50, Color(255, 110, 80))
	for _, g in ipairs(self.ghosts) do g.catch = 0 end
	MG.Sound("g01", "enemyflying", 0.7)
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
	local D = self.D
	AN.Img(A .. "hall.jpg", MG.X(-240), MG.Y(0), MG.S(1440), MG.S(H))
	-- the hanging bats (only seen in the light, under the darkness)
	for _, b in ipairs(self.bats) do
		if b.state == "hang" then
			local sw = math.sin(self.t * 2 + b.hang) * 3
			AN.ImgRotated(A .. "bat_hang.png", MG.X(b.x), MG.Y(b.y + 34), MG.S(50), MG.S(70), sw)
		end
	end
	-- the ghosts
	for _, g in ipairs(self.ghosts) do
		local shake = g.catch > 0 and math.sin(self.t * 50) * 4 * g.catch or 0
		local s = 1 - g.catch * 0.25
		local img = g.catch > 0.05 and "ghost_scared.png" or "ghost.png"
		AN.Img(A .. img, MG.X(g.x - GW * s / 2 + shake), MG.Y(g.y - GH * s / 2), MG.S(GW * s), MG.S(GH * s), 235 * g.fade)
	end
	-- the darkness, with the flashlight's hole
	local R = D.R
	local size = 4 * R
	local x0, y0 = MG.X(self.bx - size / 2), MG.Y(self.by - size / 2)
	local S = MG.S(size)
	local da = D.dark
	local dk = Color(DARK.r, DARK.g, DARK.b, da)
	AN.Img(A .. "dark.png", x0, y0, S, S, da)
	local L, T = MG.X(-600), MG.Y(-600)
	local Rr, B = MG.X(W + 600), MG.Y(H + 600)
	AN.Box(L, T, Rr - L, y0 - T, dk)
	AN.Box(L, y0 + S, Rr - L, B - y0 - S, dk)
	AN.Box(L, y0, x0 - L, S, dk)
	AN.Box(x0 + S, y0, Rr - x0 - S, S, dk)
	-- in the dark: the ghosts' eyes glimmer
	for _, g in ipairs(self.ghosts) do
		if not g.lit then
			local a = D.eyes * g.fade * (0.6 + 0.4 * math.sin(self.t * 3 + g.ph))
			AN.Img(A .. "eyes.png", MG.X(g.x - 16), MG.Y(g.y - GH / 2 + 34), MG.S(32), MG.S(13), a)
		end
	end
	-- the catching rings
	for _, g in ipairs(self.ghosts) do
		if g.catch > 0 then
			local w = MG.S(GW * 0.9)
			AN.Box(MG.X(g.x) - w / 2, MG.Y(g.y + GH / 2 + 4), w, MG.S(10), Color(0, 0, 0, 160), MG.S(5))
			AN.Box(MG.X(g.x) - w / 2, MG.Y(g.y + GH / 2 + 4), w * math.min(1, g.catch), MG.S(10), Color(160, 255, 120), MG.S(5))
		end
	end
	-- caught: a puff
	for _, p in ipairs(self.puffs) do
		local k = (self.t - p.t) / 0.7
		local s = 80 + 80 * k
		AN.Img(A .. "puff.png", MG.X(p.x - s / 2), MG.Y(p.y - s / 2), MG.S(s), MG.S(s), 255 * (1 - k))
	end
	-- the flying bats (black against everything)
	for _, b in ipairs(self.bats) do
		if b.state == "fly" then
			local up = math.floor(b.ft * 12) % 2 == 0
			AN.Img(A .. (up and "bat_up.png" or "bat_down.png"), MG.X(b.x - 60), MG.Y(b.y - 35), MG.S(120), MG.S(70))
		end
	end
	-- the points
	for i = #self.pops, 1, -1 do
		local p = self.pops[i]
		local age = self.t - p.t
		if age > 1 then table.remove(self.pops, i) else
			local c = p.col
			AN.Text(p.text, "title", math.floor(MG.S(32)), MG.X(p.x), MG.Y(p.y - age * 40), Color(c.r, c.g, c.b, 255 * (1 - age)), 1, 1)
		end
	end
	-- the top bar
	AN.Box(MG.X(W / 2 - 300), MG.Y(14), MG.S(600), MG.S(48), Color(30, 10, 40, 210), MG.S(24))
	local secs = math.ceil(self.left)
	AN.Text(AN.L("hw_time", secs), "title", math.floor(MG.S(24)), MG.X(W / 2 - 200), MG.Y(38), secs <= 10 and Color(255, 120, 80) or WHITE, 1, 1)
	AN.Text(AN.L("hw_ghost_count", self.caught), "title", math.floor(MG.S(24)), MG.X(W / 2), MG.Y(38), WHITE, 1, 1)
	AN.Text(AN.L("hw_points", self.score), "title", math.floor(MG.S(24)), MG.X(W / 2 + 200), MG.Y(38), GOLD, 1, 1)
	if not (AN.VS and AN.VS.Split and AN.VS.Split.on) then
		AN.Text(AN.L("hw_ghost_keys"), "bold", math.floor(MG.S(16)), MG.X(W / 2), MG.Y(H - 24), Color(255, 240, 210, 170), 1, 1)
	end
	if self.overAt then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(30, 10, 40, 220 * a), MG.S(30))
		AN.Text(AN.L("hw_timeup"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(N)
end

AN.RegisterGame(N, G)
