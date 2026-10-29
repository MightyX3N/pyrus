-- Summer: Surfing (in the spirit of the surf game in Microsoft Edge, with our own pictures).
-- Surf down the sea as far as you can: steer left/right in five angles, up stops, Space uses a
-- lightning bolt for a burst of speed. Rocks, buoys, logs, sandbars, piers and boats knock you
-- off (a life), seaweed slows you, beach balls and ducks bump you off course, ramps make you jump.
-- Shells give points, hearts lives, bolts boosts. On Normal and Hard something chases you:
-- the crab, the sea serpent or the seagull. The score: metres + 25 per shell.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local G = {
	scoreType = "score",
	goal = 3500,
	worst = 0,
	descKey = "su_surf",
}
local W, H = 960, 720           -- the stage (the sea goes on to the sides on wide screens)
local PY = H * 0.3              -- where the surfer is on the screen
local STEP = 1 / 60
local A = "surf/"

-- the five angles (and stopped): sideways part of the speed, the board's turn
local DIRS = {
	[0] = { dx = 0, rot = 90 },
	[1] = { dx = -0.62, rot = -52 },
	[2] = { dx = -0.26, rot = -24 },
	[3] = { dx = 0, rot = 0 },
	[4] = { dx = 0.26, rot = 24 },
	[5] = { dx = 0.62, rot = 52 },
}
-- the difficulties: speed, how full the sea is, when the chaser comes (in metres)
local DIFF = {
	{ speed = 4.2, fill = 0.5, chaser = nil },
	{ speed = 5.2, fill = 0.66, chaser = 300 },
	{ speed = 6.3, fill = 0.8, chaser = 150 },
}
-- what's in the sea: picture, size (world units), hit box (half width, half height), what it does
local KINDS = {
	rock = { img = "rock", w = 96, h = 76, hw = 38, hh = 18, oy = -6, hit = "crash", weight = 14 },
	rock2 = { img = "rock2", w = 70, h = 60, hw = 26, hh = 14, oy = -6, hit = "crash", weight = 10 },
	buoy = { img = "buoy", w = 36, h = 64, hw = 13, hh = 10, oy = 18, hit = "crash", weight = 9 },
	log = { img = "log", w = 116, h = 44, hw = 46, hh = 10, oy = 2, hit = "crash", weight = 8 },
	sandbar = { img = "sandbar", w = 270, h = 96, hw = 116, hh = 22, oy = 4, hit = "crash", weight = 4, wide = true },
	pier = { img = "pier", w = 130, h = 70, hw = 56, hh = 12, oy = 0, hit = "crash", weight = 3 },
	boat = { img = "boat", w = 130, h = 96, hw = 52, hh = 14, oy = 22, hit = "crash", weight = 3 },
	island = { img = "island", w = 320, h = 230, hw = 130, hh = 34, oy = 50, hit = "crash", weight = 1, far = 2000, wide = true },
	seaweed = { img = "seaweed", w = 130, h = 74, hw = 54, hh = 26, oy = 0, hit = "slow", weight = 8 },
	ball = { img = "ball", w = 40, h = 40, hw = 16, hh = 12, oy = 4, hit = "bump", weight = 5 },
	duck = { img = "duck", w = 44, h = 42, hw = 16, hh = 12, oy = 4, hit = "bump", weight = 4 },
	ramp = { img = "ramp", w = 96, h = 76, hw = 36, hh = 16, oy = 0, hit = "jump", weight = 4 },
	shell = { img = "shell", w = 34, h = 32, hw = 18, hh = 16, oy = 0, hit = "shell", weight = 14 },
	heart = { img = "heart", w = 38, h = 36, hw = 18, hh = 16, oy = 0, hit = "heart", weight = 1.5 },
	bolt = { img = "bolt", w = 34, h = 42, hw = 18, hh = 18, oy = 0, hit = "bolt", weight = 2.5 },
}
local KIND_LIST = {}
for k, v in pairs(KINDS) do v.name = k KIND_LIST[#KIND_LIST + 1] = v end
table.sort(KIND_LIST, function(a, b) return a.name < b.name end)
local CHASERS = {
	crab = { img = "crab", w = 160, h = 112, speed = 1.05, side = 3.0, stuck = true },
	serpent = { img = "serpent", w = 240, h = 112, speed = 1.08, side = 2.0, stuck = true },
	gull = { img = "gull", w = 160, h = 90, speed = 1.0, side = 2.4, stuck = false, flies = true },
}
local CHASER_LIST = { "crab", "serpent", "gull" }
local SURFERS = {
	{ img = "sommer/pyrus_swim.png", board = "board_p", iw = 440, ih = 640, h = 108 },
	{ img = "sommer/gyld_swim.png", board = "board_g", iw = 400, ih = 640, h = 112 },
}

---------------------------------------------------------------------------
function G:Status()
	return AN.L("su_status", math.floor((self.dist or 0) / 10), self.shells or 0, self.lives or 3)
end

function G:Score()
	return math.floor((self.dist or 0) / 10) + (self.shells or 0) * 25
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.phase = "pick"
	self.surfer = self.surfer or 1
	self.kprev = {}
	self.acc = 0
	self.t = 0
	self.dist, self.off = 0, 0
	self.speed = 0
	self.dir = 0
	self.lives, self.power, self.shells = 3, 3, 0
	self.objs = {}
	self.foam = {}
	self.spawnAcc = 0
	self.crash, self.inv, self.fly, self.bumpT, self.boost = 0, 0, 0, 0, 0
	self.chaser = nil
	self.chaserAt = self.D.chaser and (self.D.chaser * 10 + math.random(0, 1500)) or nil
	self.finished = false
	self.overAt = nil
	self.msg = nil
	-- a few things in view at the start
	for i = 1, 6 do self:Spawn(H * 0.75 + i * 140) end
end

function G:Close() end

-- the key was just pressed
function G:Pressed(k)
	local down = input.IsKeyDown(k)
	local was = self.kprev[k]
	self.kprev[k] = down
	return down and not was
end

---------------------------------------------------------------------------
-- the sea
---------------------------------------------------------------------------
local function pickKind(far)
	local total = 0
	for _, k in ipairs(KIND_LIST) do
		if not k.far or far >= k.far then total = total + k.weight end
	end
	local r = math.random() * total
	for _, k in ipairs(KIND_LIST) do
		if not k.far or far >= k.far then
			r = r - k.weight
			if r <= 0 then return k end
		end
	end
	return KIND_LIST[1]
end

-- something new at a screen depth (y from the top of the view); x anywhere around the view
function G:Spawn(sy)
	local k = pickKind(self.dist / 10)
	local x = self.off + math.random() * (W * 1.7) - W * 0.35
	local y = self.dist + sy
	-- not on top of something else
	for _, o in ipairs(self.objs) do
		if math.abs(o.x - x) < (o.k.hw + k.hw + 30) and math.abs(o.y - y) < (o.k.hh + k.hh + 40) then return end
	end
	self.objs[#self.objs + 1] = { k = k, x = x, y = y, ph = math.random() * 6 }
end

function G:Hit(o)
	local k = o.k
	if k.hit == "shell" then
		self.shells = self.shells + 1
		MG.Pop("+25", true, o.x - self.off, o.y - self.dist - 30)
		MG.Sound("g01", "pickup")
		o.dead = true
	elseif k.hit == "heart" then
		self.lives = math.min(5, self.lives + 1)
		MG.Sound("g19", "pickup")
		o.dead = true
	elseif k.hit == "bolt" then
		self.power = math.min(5, self.power + 1)
		MG.Sound("g19", "mineralpickup")
		o.dead = true
	elseif k.hit == "jump" then
		if self.fly <= 0 then self.fly = 1.4 MG.Sound("g01", "jump") end
		if self.chaser then self.chaser.stuck = 2.5 end
	elseif self.fly > 0 or self.crash > 0 then
		return
	elseif k.hit == "slow" then
		if self.inv <= 0 then
			if self.speed > 1.5 then MG.Sound("g07", "bag", 0.7) end
			self.speed = math.min(self.speed, 1.2) self.boost = 0
		end
	elseif k.hit == "bump" then
		if self.inv <= 0 and self.bumpT <= 0 then
			self.dir = ({ 1, 2, 4, 5 })[math.random(4)]
			self.bumpT = 0.7
			MG.Sound("g01", "bounce")
		end
	elseif k.hit == "crash" then
		if self.inv > 0 then return end
		self:Crash()
	end
end

function G:Crash()
	self.lives = self.lives - 1
	self.crash = 1.3
	self.speed = 0
	self.boost = 0
	MG.Sound("g07", "splash-short")
	MG.Sound("g18", "thump1", 0.8)
	AN.Speak("MisterLiv")
	if self.lives <= 0 then self:Over() end
end

function G:Over()
	if self.overAt then return end
	self.lives = math.max(0, self.lives)
	self.overAt = self.t
	self.phase = "over"
end

---------------------------------------------------------------------------
-- one step (1/60 s)
---------------------------------------------------------------------------
function G:Step()
	self.t = self.t + STEP
	if self.phase == "pick" then
		if self:Pressed(KEY_LEFT) then self.surfer = 1 end
		if self:Pressed(KEY_RIGHT) then self.surfer = 2 end
		if self:Pressed(KEY_SPACE) or self:Pressed(KEY_DOWN) then self:Go() end
		return
	end
	if self.phase == "over" then
		if self.t - self.overAt > 2 and not self.finished then
			self.finished = true
			AN.FinishGame(101, self:Score())
		end
		return
	end
	-- timers
	self.crash = math.max(0, self.crash - STEP)
	self.fly = math.max(0, self.fly - STEP)
	self.bumpT = math.max(0, self.bumpT - STEP)
	if self.crash > 0 then
		if self.crash <= STEP then
			-- back on the board, standing still, a moment safe
			self.dir = 0
			self.inv = 2.2
		end
		self:Move(0)
		return
	end
	self.inv = math.max(0, self.inv - STEP)
	-- the keys
	local L, R = self:Pressed(KEY_LEFT), self:Pressed(KEY_RIGHT)
	local Dn, Up, Sp = self:Pressed(KEY_DOWN), self:Pressed(KEY_UP), self:Pressed(KEY_SPACE)
	if self.bumpT <= 0 then
		if L then self.dir = self.dir == 0 and 2 or math.max(1, self.dir - 1) end
		if R then self.dir = self.dir == 0 and 4 or math.min(5, self.dir + 1) end
		if Dn then self.dir = 3 end
	end
	if Up and self.boost <= 0 then self.dir = 0 self.speed = 0 end
	if Sp and self.power > 0 and self.boost <= 0 and self.dir ~= 0 then
		self.power = self.power - 1
		self.boost = 4
		MG.Sound("g19", "warpactive", 0.7)
		if self.dir == 0 then self.dir = 3 end
	end
	-- speed: up to the difficulty's (it goes up a little the farther you get), double while boosting
	local base = self.D.speed + math.min(1.6, self.dist / 10 / 2500)
	if self.dir == 0 then
		self.speed = 0
	else
		if self.speed < 1 then self.speed = 1 end
		local want = base * (self.boost > 0 and 1.9 or 1)
		if self.speed < want then self.speed = math.min(want, self.speed * 1.02 + 0.02) end
		if self.speed > want then self.speed = math.max(want, self.speed - 0.08) end
	end
	self.boost = math.max(0, self.boost - STEP)
	self:Move(self.speed)
	-- foam behind the board
	if self.speed > 0.5 and math.floor(self.t * 60) % 4 == 0 then
		self.foam[#self.foam + 1] = { x = self.off + W / 2, y = self.dist + PY + 18, t = self.t }
	end
	-- hits
	if self.overAt then return end
	local px, py = self.off + W / 2, self.dist + PY + 20
	for _, o in ipairs(self.objs) do
		local k = o.k
		local cy = o.y + (k.oy or 0)
		if not o.dead and math.abs(px - o.x) < k.hw and math.abs(py - cy) < k.hh then
			self:Hit(o)
			if self.crash > 0 or self.overAt then break end
		end
	end
	self:UpdateChaser()
end

-- move along (and make the sea ahead)
function G:Move(sp)
	local d = DIRS[self.dir] or DIRS[3]
	local moved = sp * (1 - math.abs(d.dx) * 0.25)
	self.dist = self.dist + moved
	self.off = self.off + sp * d.dx
	self.spawnAcc = self.spawnAcc + moved
	while self.spawnAcc >= 46 do
		self.spawnAcc = self.spawnAcc - 46
		if math.random() < self.D.fill then self:Spawn(H + 60 + math.random() * 120) end
	end
	-- forget what is behind
	local keep = {}
	for _, o in ipairs(self.objs) do
		if not o.dead and o.y > self.dist - 200 then keep[#keep + 1] = o end
	end
	self.objs = keep
	local f = {}
	for _, x in ipairs(self.foam) do if self.t - x.t < 0.9 then f[#f + 1] = x end end
	self.foam = f
end

-- the chaser on Normal and Hard
function G:UpdateChaser()
	if not self.chaserAt then return end
	local c = self.chaser
	if not c then
		if self.dist >= self.chaserAt then
			local id = CHASER_LIST[math.random(#CHASER_LIST)]
			self.chaser = { id = id, def = CHASERS[id], x = self.off + W / 2, y = self.dist - 160, stuck = 0, t0 = self.t }
			self.msg = { text = AN.L("su_chased", AN.L("su_chaser_" .. id)), t = self.t }
			MG.Sound("g16", "whistle_2")
		end
		return
	end
	local def = c.def
	if c.stuck > 0 then
		c.stuck = c.stuck - STEP
		-- left far behind: it gives up for a while
		if c.y < self.dist - 260 then
			self.chaser = nil
			self.chaserAt = self.dist + 1500 + math.random(0, 1500)
		end
		return
	end
	local base = self.D.speed + math.min(1.6, self.dist / 10 / 2500)
	local tx, ty = self.off + W / 2, self.dist + PY
	if ty - c.y > 4 then c.y = c.y + base * def.speed + (ty - c.y > 400 and 2 or 0) end
	if c.x < tx - 2 then c.x = c.x + def.side elseif c.x > tx + 2 then c.x = c.x - def.side end
	-- caught you
	if self.fly <= 0 and self.crash <= 0 and math.abs(c.x - tx) < 46 and math.abs(c.y + 30 - ty) < 40 then
		self.lives = 0
		self.caught = true
		MG.Sound("g07", "splash-long")
		MG.Sound("g18", "thump2")
		self:Over()
		return
	end
	-- the crab and the serpent get stuck on rocks and things
	if def.stuck then
		for _, o in ipairs(self.objs) do
			if o.k.hit == "crash" and math.abs(c.x - o.x) < o.k.hw + 20 and math.abs(c.y + 40 - (o.y + (o.k.oy or 0))) < o.k.hh + 10 then
				c.stuck = 3
				break
			end
		end
	end
end

function G:Go()
	self.phase = "play"
	self.dir = 3
	self.speed = 1
	self.inv = 1
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

---------------------------------------------------------------------------
-- drawing (stage units; the sea fills the whole view)
---------------------------------------------------------------------------
local function pic(name, cx, cy, w, h, alpha)
	AN.Img(A .. name .. ".png", MG.X(cx - w / 2), MG.Y(cy - h / 2), MG.S(w), MG.S(h), alpha)
end
local function rot(path, cx, cy, w, h, deg, alpha)
	AN.ImgRotated(path, MG.X(cx), MG.Y(cy), MG.S(w), MG.S(h), deg, alpha)
end

function G:DrawSurfer(cx, cy, s, idx, dir, alpha, lying)
	local sf = SURFERS[idx]
	local d = DIRS[dir] or DIRS[3]
	-- the board, then the surfer standing on it, leaning into the turn
	rot(A .. sf.board .. ".png", cx, cy + 8 * s, 44 * 0.85 * s, 130 * 0.85 * s, d.rot, alpha)
	local h = sf.h * s
	local w = h * sf.iw / sf.ih
	if lying then
		rot(sf.img, cx + 8 * s, cy + 6 * s, w, h, 80, alpha)
	else
		local lean = -d.dx * 14
		if dir == 0 then lean = 0 end
		rot(sf.img, cx - math.sin(math.rad(lean)) * h * 0.4, cy - h * 0.42, w, h, lean, alpha)
	end
end

function G:Paint()
	MG.Stage(W, H)
	-- the sea, as far as the view goes
	local vx0 = (0 - MG.x0) / MG.k - 40
	local vx1 = (AN.VW - MG.x0) / MG.k + 40
	local vy0 = (-AN.OY - MG.y0) / MG.k - 40
	local vy1 = (AN.VH - AN.OY - MG.y0) / MG.k + 40
	AN.Box(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(vy1 - vy0), Color(46, 168, 214))
	AN.VGrad(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(vy1 - vy0), Color(20, 110, 170), 0, 110)
	local T = 256
	local ox = -((self.off % T) + T) % T
	local oy = -((self.dist % T) + T) % T
	for ty = vy0 - T + (oy - vy0) % T, vy1, T do
		for tx = vx0 - T + (ox - vx0) % T, vx1, T do
			AN.Img(A .. "ripples.png", MG.X(tx), MG.Y(ty), MG.S(T), MG.S(T))
		end
	end
	-- foam trail
	for _, f in ipairs(self.foam) do
		local a = 1 - (self.t - f.t) / 0.9
		pic("foam", f.x - self.off, f.y - self.dist, 44 * (1 + (1 - a) * 0.6), 44 * (1 + (1 - a) * 0.6), 200 * a)
	end
	-- everything in the sea and the surfer, in depth order
	local list = {}
	for _, o in ipairs(self.objs) do
		local sy = o.y - self.dist
		if sy > vy0 - 200 and sy < vy1 + 200 then list[#list + 1] = { y = o.y + (o.k.oy or 0), o = o } end
	end
	list[#list + 1] = { y = self.dist + PY + 20, me = true }
	if self.chaser and not self.chaser.def.flies then list[#list + 1] = { y = self.chaser.y + 40, ch = true } end
	table.sort(list, function(a, b) return a.y < b.y end)
	for _, it in ipairs(list) do
		if it.o then
			local o, k = it.o, it.o.k
			local bob = (k.hit == "shell" or k.hit == "heart" or k.hit == "bolt" or k.hit == "bump") and math.sin(self.t * 3 + o.ph) * 3 or 0
			pic(k.img, o.x - self.off, o.y - self.dist + bob, k.w, k.h)
		elseif it.me then
			self:PaintMe()
		elseif it.ch then
			self:PaintChaser()
		end
	end
	if self.chaser and self.chaser.def.flies then self:PaintChaser() end
	MG.DrawPops()
	self:PaintHud(vx0, vx1, vy0)
	MG.Chrome(101)
end

function G:PaintMe()
	local cx, cy = W / 2, PY
	if self.phase == "pick" then return end
	if self.crash > 0 then
		pic("splash", cx, cy + 6, 120, 80)
		self:DrawSurfer(cx, cy, 1, self.surfer, 3, 255, true)
		return
	end
	local s = 1
	if self.fly > 0 then
		local f = 1 - self.fly / 1.4
		local hgt = math.sin(f * math.pi)
		s = 1 + 0.35 * hgt
		pic("shadow", cx, cy + 18, 70 * (1 - hgt * 0.3), 20, 255)
		cy = cy - hgt * 40
	end
	local alpha = (self.inv > 0 and math.floor(self.t * 10) % 2 == 0) and 110 or 255
	self:DrawSurfer(cx, cy, s, self.surfer, self.dir, alpha)
end

function G:PaintChaser()
	local c = self.chaser
	local def = c.def
	local fr = math.floor(self.t * (def.flies and 6 or 5)) % 2
	local x, y = c.x - self.off, c.y - self.dist
	if def.flies then
		pic("shadow", x, y + 60, 90, 24)
		y = y - 20 + math.sin(self.t * 4) * 6
	end
	pic(def.img .. fr, x, y, def.w, def.h, c.stuck > 0 and 200 or 255)
end

local WHITE = Color(255, 255, 255)
local DARK = Color(10, 50, 80)
function G:PaintHud(vx0, vx1, vy0)
	-- top bar of the stage: hearts, metres, bolts, shells
	local top = math.max(vy0 + 40, 16)
	local cx = W / 2
	AN.Box(MG.X(cx - 330), MG.Y(top - 8), MG.S(660), MG.S(52), Color(10, 50, 80, 150), MG.S(26))
	AN.Text(AN.L("su_m", math.floor(self.dist / 10)), "title", math.floor(MG.S(30)), MG.X(cx), MG.Y(top + 18), WHITE, 1, 1)
	for i = 1, math.min(5, math.max(3, self.lives)) do
		pic(i <= self.lives and "hud_heart" or "hud_heart0", cx - 110 - (i - 1) * 34, top + 18, 30, 28)
	end
	for i = 1, math.min(5, math.max(3, self.power)) do
		pic(i <= self.power and "hud_bolt" or "hud_bolt0", cx + 110 + (i - 1) * 30, top + 18, 24, 30)
	end
	-- shells (left of the bar)
	pic("shell", cx - 300, top + 16, 30, 28)
	AN.Text("x " .. self.shells, "title", math.floor(MG.S(24)), MG.X(cx - 280), MG.Y(top + 18), WHITE, 0, 1)
	-- the chaser's warning
	if self.msg and self.t - self.msg.t < 3 then
		local a = math.Clamp((3 - (self.t - self.msg.t)) * 2, 0, 1)
		AN.Text(self.msg.text, "title", math.floor(MG.S(34)), MG.X(cx) + 3, MG.Y(H * 0.62) + 3, Color(10, 40, 60, 200 * a), 1, 1)
		AN.Text(self.msg.text, "title", math.floor(MG.S(34)), MG.X(cx), MG.Y(H * 0.62), Color(255, 214, 64, 255 * a), 1, 1)
	end
	if self.boost > 0 then
		pic("hud_bolt", cx + 50, PY - 60, 24 + math.sin(self.t * 20) * 3, 30)
	end
	if self.phase == "pick" then self:PaintPick() end
	if self.phase == "over" then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(cx - 300), MG.Y(H * 0.45), MG.S(600), MG.S(150), Color(10, 50, 80, 200 * a), MG.S(30))
		AN.Text(self.caught and self.chaser and AN.L("su_caught", AN.L("su_chaser_" .. self.chaser.id)) or AN.L("su_gameover"), "title", math.floor(MG.S(46)), MG.X(cx), MG.Y(H * 0.45 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self:Score(), "title", math.floor(MG.S(30)), MG.X(cx), MG.Y(H * 0.45 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
end

-- picking the surfer before the start
function G:PaintPick()
	local cx = W / 2
	AN.Text(AN.L("su_pick"), "title", math.floor(MG.S(48)), MG.X(cx) + 3, MG.Y(130) + 3, DARK, 1, 1)
	AN.Text(AN.L("su_pick"), "title", math.floor(MG.S(48)), MG.X(cx), MG.Y(130), WHITE, 1, 1)
	for i = 1, 2 do
		local x = cx + (i == 1 and -130 or 130)
		local sel = self.surfer == i
		local y = 330 + (sel and math.sin(self.t * 6) * 6 or 0)
		local hot = UI.Button("surf_pick" .. i, MG.X(x - 80), MG.Y(200), MG.S(160), MG.S(200), function()
			if self.surfer == i then self:Go() else self.surfer = i end
		end)
		if sel then AN.Glow(MG.X(x), MG.Y(300), MG.S(110), Color(255, 240, 180), 0.7) end
		self:DrawSurfer(x, y, sel and 1.5 or 1.25, i, 3, (sel or hot) and 255 or 170)
	end
	AN.Box(MG.X(cx - 330), MG.Y(470), MG.S(660), MG.S(50), Color(10, 50, 80, 170), MG.S(25))
	AN.Text(AN.L("su_pick_keys"), "bold", math.floor(MG.S(20)), MG.X(cx), MG.Y(495), WHITE, 1, 1)
end

AN.RegisterGame(101, G)
