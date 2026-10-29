-- Summer: Fiskekonkurrencen (the fishing contest). Gyldenkål fishes from the jetty, side view with
-- the sea cut through. Aim with left/right, hold Space for the power bar (it decides how deep the
-- hook goes), let go to cast. When the float dips, press Space in time to hook the fish, then keep
-- the fish inside the green zone (move it with up/down) until it's landed. Two minutes; points for
-- every catch (bigger fish more, junk a little, the golden fish a lot).
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local G = {
	scoreType = "score",
	goal = 1400,
	worst = 0,
	descKey = "su_fishing",
}
local W, H = 960, 720
local STEP = 1 / 60
local A = "fisk/"
local SURF = 300                -- the water's surface
local BOTTOM = 690              -- the sea floor
local DECK = 284                -- the jetty's deck
local ROUND = 120

local KINDS = {
	sild = { w = 80, h = 30, pts = 40, fight = 0.6, speed = 1.6, d = { 330, 480 }, weight = 9 },
	makrel = { w = 100, h = 34, pts = 70, fight = 1.0, speed = 2.0, d = { 380, 560 }, weight = 8 },
	hornfisk = { w = 140, h = 26, pts = 90, fight = 1.3, speed = 2.4, d = { 340, 500 }, weight = 5 },
	roedspaette = { w = 100, h = 56, pts = 110, fight = 0.8, speed = 0.8, d = { 640, 665 }, weight = 6 },
	torsk = { w = 130, h = 50, pts = 150, fight = 1.5, speed = 1.2, d = { 520, 640 }, weight = 6 },
	guldfisk = { w = 90, h = 44, pts = 500, fight = 2.0, speed = 2.6, d = { 380, 620 }, weight = 0.6 },
}
local KIND_LIST = { "sild", "makrel", "hornfisk", "roedspaette", "torsk", "guldfisk" }
local JUNK = {
	stoevle = { w = 70, h = 60, pts = 10 },
	flaske = { w = 40, h = 80, pts = 15 },
	tang = { w = 70, h = 60, pts = 5 },
}
local DIFF = {
	{ zone = 120, bite = 0.9, wild = 0.7, fish = 8 },
	{ zone = 90, bite = 0.6, wild = 1.0, fish = 7 },
	{ zone = 64, bite = 0.42, wild = 1.35, fish = 6 },
}
local BAR_Y, BAR_H = 330, 300   -- the reel bar on the right

function G:Status()
	return AN.L("su_fish_status", self.score or 0, self.caught or 0, math.max(0, math.ceil(ROUND - (self.time or 0))))
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.kprev = {}
	self.acc, self.t, self.time = 0, 0, 0
	self.score, self.caught = 0, 0
	self.state = "aim"          -- aim, power, cast, wait, bite, reel, land
	self.aim = 600
	self.power = 0
	self.powerDir = 1
	self.fish = {}
	self.junk = {}
	for i = 1, self.D.fish do self:SpawnFish(true) end
	for i = 1, 4 do
		local ids = { "stoevle", "flaske", "tang" }
		local id = ids[math.random(#ids)]
		self.junk[#self.junk + 1] = { id = id, k = JUNK[id], x = 380 + math.random() * 540, y = BOTTOM - JUNK[id].h / 2 + 6 }
	end
	self.finished, self.overAt = false, nil
	self.msg = nil
end
function G:Close() end

function G:Pressed(k)
	local down = input.IsKeyDown(k)
	local was = self.kprev[k]
	self.kprev[k] = down
	return down and not was
end

function G:SpawnFish(anywhere)
	local total = 0
	for _, id in ipairs(KIND_LIST) do total = total + KINDS[id].weight end
	local r = math.random() * total
	local id = KIND_LIST[1]
	for _, i in ipairs(KIND_LIST) do
		r = r - KINDS[i].weight
		if r <= 0 then id = i break end
	end
	local k = KINDS[id]
	local dir = math.random() < 0.5 and -1 or 1
	local x = anywhere and (320 + math.random() * 620) or (dir > 0 and 260 or W + 120)
	self.fish[#self.fish + 1] = { id = id, k = k, x = x, y = k.d[1] + math.random() * (k.d[2] - k.d[1]), dir = dir, ph = math.random() * 6, speed = k.speed * (0.7 + math.random() * 0.6) }
end

---------------------------------------------------------------------------
function G:Step()
	self.t = self.t + STEP
	if self.overAt then
		if self.t - self.overAt > 2.2 and not self.finished then
			self.finished = true
			AN.FinishGame(103, self.score)
		end
		return
	end
	self.time = self.time + STEP
	if self.time >= ROUND and self.state ~= "reel" then
		self:Over()
		return
	end
	local L, R = input.IsKeyDown(KEY_LEFT), input.IsKeyDown(KEY_RIGHT)
	local Up, Dn = input.IsKeyDown(KEY_UP), input.IsKeyDown(KEY_DOWN)
	local spDown = input.IsKeyDown(KEY_SPACE)
	local spPress = self:Pressed(KEY_SPACE)
	local st = self.state
	-- the fish swim about
	for _, f in ipairs(self.fish) do
		if not f.hooked and not f.coming then
			f.x = f.x + f.dir * f.speed
			f.y = f.y + math.sin(self.t * 1.3 + f.ph) * 0.3
			if f.x < 250 or f.x > W + 140 then f.dir = -f.dir end
			if math.random() < 0.002 then f.dir = -f.dir end
		end
	end
	if st == "aim" then
		if L then self.aim = math.max(360, self.aim - 6) end
		if R then self.aim = math.min(920, self.aim + 6) end
		if spPress then self.state = "power" self.power = 0 self.powerDir = 1 end
	elseif st == "power" then
		if L then self.aim = math.max(360, self.aim - 6) end
		if R then self.aim = math.min(920, self.aim + 6) end
		self.power = self.power + self.powerDir * STEP * 1.4
		if self.power >= 1 then self.power = 1 self.powerDir = -1 end
		if self.power <= 0 then self.power = 0 self.powerDir = 1 end
		if not spDown then
			-- cast: the float flies out, the hook sinks to its depth
			self.state = "cast"
			self.castT = 0
			self.floatX = self.aim
			self.depth = SURF + 40 + self.power * (BOTTOM - SURF - 50)
			self.hookY = SURF
			MG.Sound("g08", "whoosh", 0.7)
			self.splashAt = self.t + 0.5
		end
	elseif st == "cast" then
		self.castT = self.castT + STEP
		if self.splashAt and self.t >= self.splashAt then self.splashAt = nil MG.Sound("g07", "splash-short", 0.6) end
		if self.castT > 0.5 then
			self.hookY = math.min(self.depth, self.hookY + 5)
			if self.hookY >= self.depth then self.state = "wait" self.waitT = 0 end
		end
	elseif st == "wait" then
		self.waitT = self.waitT + STEP
		-- reel in early to try again
		if spPress or Up then self.state = "aim" return end
		-- a fish nearby comes to look, and bites after a moment
		if not self.coming then
			local best, bd
			for _, f in ipairs(self.fish) do
				local d = math.abs(f.x - self.floatX) + math.abs(f.y - self.hookY) * 0.6
				if d < 220 and (not bd or d < bd) then best, bd = f, d end
			end
			if best and math.random() < 0.025 then
				self.coming = best
				best.coming = true
				-- (it comes at the hook mouth first, from the side it is on)
				best.side = best.x < self.floatX and -1 or 1
				best.biteAt = self.t + 0.8 + math.random() * 1.5
			end
			-- the hook on the bottom snags junk now and then
			if not self.coming and self.hookY > BOTTOM - 40 then
				for _, j in ipairs(self.junk) do
					if math.abs(j.x - self.floatX) < 50 and math.random() < 0.01 then
						self.junkHook = j
						self.state = "bite"
						self.biteT = 0
						break
					end
				end
			end
		else
			local f = self.coming
			f.x = f.x + (self.floatX + f.side * f.k.w * 0.46 - f.x) * 0.04
			f.y = f.y + (self.hookY - f.y) * 0.04
			if self.t >= f.biteAt then self.state = "bite" self.biteT = 0 MG.Sound("g03", "peep") end
		end
	elseif st == "bite" then
		self.biteT = self.biteT + STEP
		if spPress then
			-- hooked!
			self.state = "reel"
			MG.Sound("g11", "lift")
			self.hooked = self.coming
			if self.hooked then self.hooked.hooked = true self.hooked.coming = nil end
			self.coming = nil
			self.zone = BAR_Y + BAR_H / 2
			self.mark = BAR_Y + BAR_H / 2
			self.markV = 0
			self.prog = 0.3
		elseif self.biteT > self.D.bite then
			-- too slow: it swims off
			if self.coming then self.coming.coming = nil self.coming.dir = -self.coming.dir self.coming.speed = self.coming.k.speed * 1.5 end
			self.coming = nil
			self.junkHook = nil
			self.msg = { text = AN.L("su_fish_gone"), t = self.t }
			MG.Sound("g06", "error", 0.6)
			self.state = "wait"
			self.waitT = 0
		end
	elseif st == "reel" then
		-- the zone moves with up/down, the fish jumps about
		local zh = self.D.zone
		if Up then self.zone = self.zone - 5 end
		if Dn then self.zone = self.zone + 5 end
		self.zone = math.Clamp(self.zone, BAR_Y + zh / 2, BAR_Y + BAR_H - zh / 2)
		local fight = (self.hooked and self.hooked.k.fight or 0.25) * self.D.wild
		if math.random() < 0.03 * fight + 0.01 then self.markV = (math.random() * 2 - 1) * 5 * fight end
		self.mark = math.Clamp(self.mark + self.markV, BAR_Y + 6, BAR_Y + BAR_H - 6)
		self.markV = self.markV * 0.985
		if self.mark <= BAR_Y + 6 or self.mark >= BAR_Y + BAR_H - 6 then self.markV = -self.markV * 0.5 end
		local inside = math.abs(self.mark - self.zone) < zh / 2
		self.prog = math.Clamp(self.prog + (inside and 0.28 or -0.22) * STEP, 0, 1)
		self.inside = inside
		-- the catch comes closer as you reel
		local f = self.hooked
		local tx = 330
		if f then
			f.x = self.floatX + (tx - self.floatX) * self.prog + (f.side or 1) * f.k.w * 0.46
			f.y = self.depth + (SURF + 20 - self.depth) * self.prog
		end
		if self.prog >= 1 then
			self:Land()
		elseif self.prog <= 0 then
			-- the line snapped
			if f then f.hooked = nil f.dir = 1 f.speed = f.k.speed * 1.6 end
			self.hooked = nil
			self.junkHook = nil
			self.msg = { text = AN.L("su_fish_snap"), t = self.t }
			MG.Sound("g11", "placebad")
			self.state = "aim"
			if self.time >= ROUND then self.overAt = self.t end
		end
	end
	-- fish that left are replaced
	local keep = {}
	for _, f in ipairs(self.fish) do if not f.gone then keep[#keep + 1] = f end end
	self.fish = keep
	while #self.fish < self.D.fish do self:SpawnFish(false) end
end

function G:Over()
	if not self.overAt then self.overAt = self.t MG.Sound("g14", "done") end
end

function G:Land()
	local pts, name
	if self.hooked then
		pts = self.hooked.k.pts
		name = AN.L("su_fish_" .. self.hooked.id)
		self.hooked.gone = true
		if self.hooked.id == "guldfisk" then AN.Speak("megetgodt") end
	elseif self.junkHook then
		pts = self.junkHook.k.pts
		name = AN.L("su_fish_" .. self.junkHook.id)
		local j = self.junkHook
		j.x = 380 + math.random() * 540
	else
		pts, name = 0, "?"
	end
	self.score = self.score + pts
	self.caught = self.caught + 1
	self.msg = { text = name .. "  +" .. pts, t = self.t, good = true }
	MG.Sound("ui", pts >= 500 and "triangel" or "point")
	MG.Sound("g07", "splash-short", 0.4)
	self.hooked, self.junkHook = nil, nil
	self.state = "aim"
	if self.time >= ROUND then self.overAt = self.t end
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
local function pic(name, x, y, w, h, alpha)
	AN.Img(A .. name .. ".png", MG.X(x), MG.Y(y), MG.S(w), MG.S(h), alpha)
end
local function flipPic(name, x, y, w, h, flip, alpha)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(AN.Mat(A .. name .. ".png"))
	local u0, u1 = 0, 1
	if flip then u0, u1 = 1, 0 end
	surface.DrawTexturedRectUV(AN.PX(MG.X(x)), AN.SY(MG.Y(y)), AN.SX(MG.S(w)), AN.SX(MG.S(h)), u0, 0, u1, 1)
end
local function line(x1, y1, x2, y2, col, w)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local a, b, c, d = AN.PX(MG.X(x1)), AN.SY(MG.Y(y1)), AN.PX(MG.X(x2)), AN.SY(MG.Y(y2))
	for o = 0, math.max(0, math.floor((w or 1) * AN.S * MG.k) - 1) do surface.DrawLine(a, b + o, c, d + o) end
end
local WHITE = Color(255, 255, 255)

-- Gyldenkål on the jetty: where his hand (and the rod) is
local GY = { h = 230, x = 140 }
local function gyld()
	local h = GY.h
	local w = h * 444 / 640
	local x0, y0 = GY.x - w / 2, DECK - h * 0.94
	return x0, y0, w, h, x0 + w * 0.828, y0 + h * 0.58
end

function G:Paint()
	MG.Stage(W, H)
	local vx0 = (0 - MG.x0) / MG.k
	local vx1 = (AN.VW - MG.x0) / MG.k
	local vy0 = (-AN.OY - MG.y0) / MG.k
	local vy1 = (AN.VH - AN.OY - MG.y0) / MG.k
	-- sky, sea, sea floor
	AN.Box(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(SURF - vy0), Color(110, 190, 235))
	AN.VGrad(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(SURF - vy0), Color(60, 150, 220), 255, 0)
	AN.Circle(MG.X(800), MG.Y(90), MG.S(46), Color(255, 240, 160))
	AN.Box(MG.X(vx0), MG.Y(SURF), MG.S(vx1 - vx0), MG.S(vy1 - SURF), Color(40, 140, 190))
	AN.VGrad(MG.X(vx0), MG.Y(SURF), MG.S(vx1 - vx0), MG.S(vy1 - SURF), Color(10, 60, 110), 0, 210)
	AN.Box(MG.X(vx0), MG.Y(BOTTOM), MG.S(vx1 - vx0), MG.S(vy1 - BOTTOM), Color(214, 180, 110))
	-- light rays and bubbles
	for i = 0, 5 do
		local bx = 300 + i * 120 + math.sin(self.t * 0.5 + i) * 20
		AN.Box(MG.X(bx), MG.Y(SURF), MG.S(30), MG.S(BOTTOM - SURF), Color(255, 255, 255, 10))
	end
	-- junk on the bottom, the fish
	for _, j in ipairs(self.junk) do
		if j ~= self.junkHook or self.state ~= "reel" then
			pic(j.id, j.x - j.k.w / 2, j.y - j.k.h / 2, j.k.w, j.k.h)
		end
	end
	if self.junkHook and self.state == "reel" then
		local j = self.junkHook
		local x = self.floatX + (330 - self.floatX) * self.prog
		local y = self.depth + (SURF + 20 - self.depth) * self.prog
		pic(j.id, x - j.k.w / 2, y - j.k.h / 2, j.k.w, j.k.h)
	end
	for _, f in ipairs(self.fish) do
		local k = f.k
		local wig = math.sin(self.t * 8 + f.ph) * (f.hooked and 4 or 1.5)
		local flip = f.dir > 0
		if f.hooked or f.coming then flip = (f.side or 1) < 0 end
		flipPic(f.id, f.x - k.w / 2, f.y - k.h / 2 + wig, k.w, k.h, flip)
	end
	-- the water's surface line
	AN.Box(MG.X(vx0), MG.Y(SURF - 3), MG.S(vx1 - vx0), MG.S(6), Color(200, 240, 255, 180))
	-- the jetty and Gyldenkål
	pic("jetty", 0, DECK, 300, 420)
	pic("bucket", 30, DECK - 52, 60, 56)
	local gx, gy, gw, gh, hx, hy = gyld()
	AN.Img("sommer/gyld_fish.png", MG.X(gx), MG.Y(gy), MG.S(gw), MG.S(gh))
	-- the rod and the line
	local tipX, tipY = hx + 150, hy - 95
	if self.state == "reel" then tipX, tipY = hx + 150 + math.sin(self.t * 20) * 4, hy - 60 end
	line(hx - 10, hy + 14, tipX, tipY, Color(90, 52, 22), 4)
	local st = self.state
	local lineCol = Color(255, 255, 255, 200)
	if st == "aim" or st == "power" then
		line(tipX, tipY, tipX, tipY + 60, lineCol, 1)
		pic("float", tipX - 8, tipY + 56, 16, 30)
		-- the aim marker on the water
		local a = 0.6 + 0.4 * math.sin(self.t * 6)
		AN.Box(MG.X(self.aim - 20), MG.Y(SURF - 4), MG.S(40), MG.S(8), Color(255, 214, 64, 220 * a), MG.S(4))
		AN.Text("v", "title", math.floor(MG.S(28)), MG.X(self.aim), MG.Y(SURF - 30), Color(255, 214, 64, 255 * a), 1, 1)
	elseif st == "cast" then
		local k = math.min(1, self.castT / 0.5)
		local fx = tipX + (self.floatX - tipX) * k
		local fy = tipY + (SURF - tipY) * k - math.sin(k * math.pi) * 120
		line(tipX, tipY, fx, fy, lineCol, 1)
		pic("float", fx - 8, fy - 26, 16, 30)
		if k >= 1 then line(self.floatX, SURF, self.floatX, self.hookY, Color(255, 255, 255, 120), 1) end
	else
		local dip = (st == "bite") and (8 + math.sin(self.t * 30) * 4) or math.sin(self.t * 2) * 2
		local fx = self.floatX
		if st == "reel" then fx = self.floatX + (330 - self.floatX) * self.prog end
		line(tipX, tipY, fx, SURF - 20 + dip, lineCol, 1)
		pic("float", fx - 8, SURF - 24 + dip, 16, 30)
		local hy2 = st == "reel" and (self.depth + (SURF + 20 - self.depth) * self.prog) or self.hookY
		line(fx, SURF + dip, fx, hy2, Color(255, 255, 255, 120), 1)
		if st ~= "reel" then
			line(fx, hy2, fx + 6, hy2 + 8, Color(200, 200, 200), 2)
		end
		if st == "bite" then
			AN.Text("!", "title", math.floor(MG.S(56)), MG.X(fx + 30), MG.Y(SURF - 60), Color(255, 80, 60), 1, 1)
		end
	end
	-- the power bar (by the jetty)
	if st == "power" then
		local bx, by, bw, bh = 230, 140, 24, 120
		AN.Box(MG.X(bx), MG.Y(by), MG.S(bw), MG.S(bh), Color(0, 0, 0, 140), MG.S(6))
		local f = self.power
		local col = Color(math.floor(80 + 175 * f), math.floor(220 - 120 * f), 60)
		AN.Box(MG.X(bx + 3), MG.Y(by + bh - 3 - (bh - 6) * f), MG.S(bw - 6), MG.S((bh - 6) * f), col, MG.S(4))
		AN.Text(AN.L("su_fish_depth"), "bold", math.floor(MG.S(13)), MG.X(bx + bw / 2), MG.Y(by - 12), WHITE, 1, 1)
	end
	-- the reel bar (right side)
	if st == "reel" then
		local bx, bw = W - 70, 44
		AN.Box(MG.X(bx - 6), MG.Y(BAR_Y - 6), MG.S(bw + 12), MG.S(BAR_H + 12), Color(10, 40, 70, 210), MG.S(12))
		local zh = self.D.zone
		AN.Box(MG.X(bx), MG.Y(self.zone - zh / 2), MG.S(bw), MG.S(zh), self.inside and Color(90, 220, 110, 230) or Color(90, 220, 110, 140), MG.S(8))
		pic(self.hooked and self.hooked.id or "stoevle", bx - 6, self.mark - 14, bw + 12, 28)
		-- landed so far
		AN.Box(MG.X(bx - 30), MG.Y(BAR_Y), MG.S(12), MG.S(BAR_H), Color(0, 0, 0, 140), MG.S(6))
		AN.Box(MG.X(bx - 30), MG.Y(BAR_Y + BAR_H * (1 - self.prog)), MG.S(12), MG.S(BAR_H * self.prog), Color(255, 214, 64), MG.S(6))
	end
	-- messages
	if self.msg and self.t - self.msg.t < 1.8 then
		local a = math.Clamp((1.8 - (self.t - self.msg.t)) * 2, 0, 1)
		AN.Text(self.msg.text, "title", math.floor(MG.S(36)), MG.X(600) + 3, MG.Y(200) + 3, Color(10, 40, 60, 200 * a), 1, 1)
		AN.Text(self.msg.text, "title", math.floor(MG.S(36)), MG.X(600), MG.Y(200), self.msg.good and Color(255, 214, 64, 255 * a) or Color(255, 255, 255, 255 * a), 1, 1)
	end
	-- the hint for the keys, by state
	local key = ({ aim = "su_fish_k_aim", power = "su_fish_k_power", cast = "su_fish_k_wait", wait = "su_fish_k_wait", bite = "su_fish_k_bite", reel = "su_fish_k_reel" })[st]
	if key and not self.overAt then
		AN.Box(MG.X(W / 2 - 300), MG.Y(H - 40), MG.S(600), MG.S(32), Color(10, 40, 70, 170), MG.S(16))
		AN.Text(AN.L(key), "bold", math.floor(MG.S(17)), MG.X(W / 2), MG.Y(H - 24), WHITE, 1, 1)
	end
	-- score and clock
	AN.Box(MG.X(W / 2 - 180), MG.Y(14), MG.S(360), MG.S(48), Color(10, 50, 80, 190), MG.S(24))
	local left = math.max(0, math.ceil(ROUND - self.time))
	AN.Text(string.format("%d:%02d", math.floor(left / 60), left % 60), "title", math.floor(MG.S(28)), MG.X(W / 2 - 90), MG.Y(38), left <= 10 and Color(255, 120, 100) or WHITE, 1, 1)
	AN.Text(AN.L("su_ice_pts", self.score), "title", math.floor(MG.S(28)), MG.X(W / 2 + 70), MG.Y(38), Color(255, 214, 64), 1, 1)
	if self.overAt then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(10, 50, 80, 210 * a), MG.S(30))
		AN.Text(AN.L("su_fish_over"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(103)
end

AN.RegisterGame(103, G)
