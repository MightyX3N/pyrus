-- Halloween: Græskarskæring (pumpkin carving). A face is drawn on the pumpkin in dotted lines;
-- steer the knife with the arrow keys and hold Space to cut along them. Every bit of the line
-- scores, a whole shape falling out scores extra, and cutting beside the line scratches the
-- pumpkin and costs points. When the face is done the candle is lit and the next pumpkin comes.
-- 90 seconds.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local N = 201
local W, H = 960, 720
local STEP = 1 / 60
local A = "carve/"
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/h201_shapes.lua")
local SHAPES = AN.CarveShapes

local ROUND = 90
-- the pumpkin's picture (600 x 500) and the face's middle
local PX, PY = 180, 100
local FX, FY = 480, 350
-- the pumpkin's body, for "is the knife on the pumpkin"
local BCX, BCY, BRX, BRY = 480, 380, 270, 200

local DIFF = {
	{ tol = 20, speed = 250, eyes = { "tri", "round" }, noses = { false, "tri" }, mouths = { "smile", "o" } },
	{ tol = 14, speed = 250, eyes = { "tri", "round", "slant", "moon" }, noses = { "tri", "round", "heart" }, mouths = { "smile", "teeth", "zigzag" } },
	{ tol = 9, speed = 260, eyes = { "star", "moon", "slant", "tri" }, noses = { "heart", "tri", "round" }, mouths = { "teeth", "zigzag" } },
}
local PTS_DOT, PTS_SHAPE, PTS_FACE, PTS_CLEAN, PTS_SCRATCH = 1, 40, 100, 50, 10

local G = {
	scoreType = "score",
	goal = 2000,
	worst = 0,
	descKey = "su_carving",
}

function G:Status()
	return AN.L("hw_carve_status", self.done or 0, self.score or 0)
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.acc, self.t = 0, 0
	self.left = ROUND
	self.score = 0
	self.done = 0
	self.finished, self.overAt = false, nil
	self.kx, self.ky = FX, FY + 40
	self.pops = {}
	self.falling = {}
	self.cutSnd = 0
	self:NewPumpkin()
	self.slide = 0          -- the new pumpkin rolls in from the right
end
function G:Close() end

local function pick(list) return list[math.random(#list)] end

function G:NewPumpkin()
	local D = self.D
	local shapes = {}
	local function add(id, x, y)
		local s = SHAPES[id]
		local dots = {}
		for i = 1, #s.dots, 2 do dots[#dots + 1] = { x = FX + x + s.dots[i], y = FY + y + s.dots[i + 1] } end
		shapes[#shapes + 1] = { id = id, x = FX + x, y = FY + y, dots = dots, left = #dots }
	end
	local eye = pick(D.eyes)
	local l, r = "eye_" .. eye, "eye_" .. eye
	if eye == "slant" then l, r = "eye_slant_l", "eye_slant_r" end
	if eye == "moon" then l, r = "eye_moon", "eye_moon_r" end
	add(l, -105, -60)
	add(r, 105, -60)
	local nose = pick(D.noses)
	if nose then add("nose_" .. nose, 0, 20) end
	add("mouth_" .. pick(D.mouths), 0, 112)
	self.shapes = shapes
	self.scratches = {}
	self.state = "carve"
	self.stateT = 0
	self.slide = 1
end

-- is the knife tip near the line of a shape still being cut (or on a hole already cut)?
function G:NearLine(x, y, r)
	local r2 = r * r
	for _, s in ipairs(self.shapes) do
		if not s.out then
			for _, d in ipairs(s.dots) do
				local dx, dy = d.x - x, d.y - y
				if dx * dx + dy * dy <= r2 then return true end
			end
		else
			local S = SHAPES[s.id]
			if math.abs(x - s.x) < S.w / 2 and math.abs(y - s.y) < S.h / 2 then return true end
		end
	end
	return false
end

function G:Cut(moved)
	local tol = self.D.tol
	local t2 = tol * tol
	local got = 0
	for _, s in ipairs(self.shapes) do
		if not s.out then
			for _, d in ipairs(s.dots) do
				if not d.cut then
					local dx, dy = d.x - self.kx, d.y - self.ky
					if dx * dx + dy * dy <= t2 then
						d.cut = true
						s.left = s.left - 1
						got = got + 1
					end
				end
			end
			if s.left <= 0 then self:ShapeOut(s) end
		end
	end
	if got > 0 then
		self.score = self.score + got * PTS_DOT
		if self.t >= self.cutSnd then
			MG.Sound("g08", "zipper", 0.35)
			self.cutSnd = self.t + 0.35
		end
		return
	end
	-- beside the line: a scratch (only while the knife moves over the pumpkin)
	if not moved then return end
	local ex, ey = (self.kx - BCX) / BRX, (self.ky - BCY) / BRY
	if ex * ex + ey * ey > 1 then return end
	if self:NearLine(self.kx, self.ky, tol + 6) then return end
	if self.lastScratch and self.t - self.lastScratch < 0.3 then return end
	self.lastScratch = self.t
	self.scratches[#self.scratches + 1] = { x = self.kx, y = self.ky, r = math.random(-40, 40) }
	self.score = math.max(0, self.score - PTS_SCRATCH)
	self:Pop("-" .. PTS_SCRATCH, self.kx, self.ky - 30, Color(255, 90, 60))
	MG.Sound("g06", "error", 0.5)
end

function G:ShapeOut(s)
	s.out = true
	self.score = self.score + PTS_SHAPE
	self:Pop("+" .. PTS_SHAPE, s.x, s.y, Color(255, 220, 90))
	self.falling[#self.falling + 1] = { id = s.id, x = s.x, y = s.y, vx = math.random(-60, 60), vy = -120, rot = 0, vr = math.random(-200, 200) }
	MG.Sound("g11", "placegood", 0.7)
	for _, o in ipairs(self.shapes) do if not o.out then return end end
	-- the whole face: light the candle
	local bonus = PTS_FACE + (#self.scratches == 0 and PTS_CLEAN or 0)
	self.score = self.score + bonus
	self.done = self.done + 1
	self.state = "lit"
	self.stateT = 0
	self.clean = #self.scratches == 0
	MG.Sound("ui", "triangel")
	if self.clean and self.done % 3 == 0 then AN.Speak("megetgodt") end
end

function G:Pop(text, x, y, col)
	self.pops[#self.pops + 1] = { text = text, x = x, y = y, t = self.t, col = col }
end

function G:Over()
	if self.overAt then return end
	self.overAt = self.t
	MG.Sound("g14", "done")
end

function G:Step()
	self.t = self.t + STEP
	-- the falling pieces
	for i = #self.falling, 1, -1 do
		local f = self.falling[i]
		f.vy = f.vy + 900 * STEP
		f.x, f.y = f.x + f.vx * STEP, f.y + f.vy * STEP
		f.rot = f.rot + f.vr * STEP
		if f.y > H + 100 then table.remove(self.falling, i) end
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
	self.slide = math.max(0, self.slide - STEP * 2.2)
	self.stateT = self.stateT + STEP
	if self.state == "lit" then
		if self.stateT > 1.6 then self.state = "away" self.stateT = 0 end
	elseif self.state == "away" then
		if self.stateT > 0.45 then self:NewPumpkin() end
	end
	-- the knife
	local dx, dy = 0, 0
	if input.IsKeyDown(KEY_LEFT) then dx = dx - 1 end
	if input.IsKeyDown(KEY_RIGHT) then dx = dx + 1 end
	if input.IsKeyDown(KEY_UP) then dy = dy - 1 end
	if input.IsKeyDown(KEY_DOWN) then dy = dy + 1 end
	local moved = dx ~= 0 or dy ~= 0
	if moved then
		local l = math.sqrt(dx * dx + dy * dy)
		local sp = self.D.speed * STEP
		self.kx = math.Clamp(self.kx + dx / l * sp, 60, W - 60)
		self.ky = math.Clamp(self.ky + dy / l * sp, 120, H - 40)
	end
	self.cutting = input.IsKeyDown(KEY_SPACE)
	if self.cutting and self.state == "carve" and self.slide <= 0 then self:Cut(moved) end
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
	AN.Img(A .. name, MG.X(x), MG.Y(y), MG.S(w), MG.S(h), alpha)
end
local WHITE = Color(255, 255, 255)
local GOLD = Color(255, 214, 90)
local DOT = Color(60, 24, 6)
local CUT = Color(40, 12, 2)

function G:Paint()
	MG.Stage(W, H)
	-- the room (wider than the stage, for wide screens)
	pic("room.jpg", -240, 0, W + 480, H)
	-- Gyldenkål watches with his lantern
	local gh = 300
	AN.Img("halloween/gyld_lantern.png", MG.X(W - 150), MG.Y(590 - gh), MG.S(gh * 490 / 785), MG.S(gh))
	-- the candle on the table
	pic("candle.png", 70, 500, 40, 70)
	AN.Glow(MG.X(90), MG.Y(506), MG.S(70 + 6 * math.sin(self.t * 9)), Color(255, 200, 90), 0.35)

	-- the pumpkin (rolling in, or away when done)
	local off = 0
	if self.slide > 0 then off = self.slide * self.slide * 700 end
	if self.state == "away" then off = -(self.stateT / 0.45) ^ 2 * 800 end
	local function X(x) return MG.X(x + off) end
	AN.Img(A .. "pumpkin.png", X(PX), MG.Y(PY), MG.S(600), MG.S(500))
	-- the scratches
	for _, s in ipairs(self.scratches) do
		AN.ImgRotated(A .. "scratch.png", X(s.x), MG.Y(s.y), MG.S(40), MG.S(12), s.r)
	end
	-- the shapes: holes cut out, dotted lines still to cut
	local lit = self.state == "lit" or self.state == "away"
	local flick = 0.85 + 0.15 * math.sin(self.t * 13) * math.sin(self.t * 7)
	for _, s in ipairs(self.shapes) do
		local S = SHAPES[s.id]
		if s.out then
			AN.Img(A .. (lit and "lit_" or "hole_") .. s.id .. ".png", X(s.x - S.ox), MG.Y(s.y - S.oy), MG.S(S.w), MG.S(S.h), lit and 255 * flick or 255)
		else
			local ds = MG.S(5)
			local cs = MG.S(7)
			for i, d in ipairs(s.dots) do
				if d.cut then
					AN.Box(X(d.x) - cs / 2, MG.Y(d.y) - cs / 2, cs, cs, CUT)
				elseif i % 2 == 1 then
					AN.Box(X(d.x) - ds / 2, MG.Y(d.y) - ds / 2, ds, ds, DOT)
				end
			end
		end
	end
	if lit then
		AN.Glow(X(FX), MG.Y(FY + 30), MG.S(260), Color(255, 190, 60), 0.35 * flick)
	end
	-- the pieces falling out
	for _, f in ipairs(self.falling) do
		local S = SHAPES[f.id]
		AN.ImgRotated(A .. "piece_" .. f.id .. ".png", MG.X(f.x + off), MG.Y(f.y), MG.S(S.w), MG.S(S.h), f.rot)
	end
	-- the knife (its tip at the point), with the reach it cuts in
	if not self.overAt then
		local tol = self.D.tol
		AN.Outline(MG.X(self.kx - tol), MG.Y(self.ky - tol), MG.S(tol * 2), MG.S(tol * 2), Color(255, 255, 255, self.cutting and 200 or 90), MG.S(tol), MG.S(2))
		local dip = self.cutting and 8 or 0
		AN.Img(A .. "knife.png", MG.X(self.kx - 20), MG.Y(self.ky - 148 + dip), MG.S(40), MG.S(150))
	end
	-- the points
	for i = #self.pops, 1, -1 do
		local p = self.pops[i]
		local age = self.t - p.t
		if age > 1 then table.remove(self.pops, i) else
			local c = p.col
			AN.Text(p.text, "title", math.floor(MG.S(30)), MG.X(p.x), MG.Y(p.y - age * 40), Color(c.r, c.g, c.b, 255 * (1 - age)), 1, 1)
		end
	end
	if self.state == "lit" then
		local a = math.Clamp(self.stateT * 3, 0, 1)
		AN.TextShadow(AN.L(self.clean and "hw_carve_clean" or "hw_carve_done"), "title", math.floor(MG.S(46)), MG.X(W / 2) - AN.TextSize(AN.L(self.clean and "hw_carve_clean" or "hw_carve_done"), "title", math.floor(MG.S(46))) / 2, MG.Y(70), Color(255, 220, 90, 255 * a), Color(0, 0, 0, 160 * a), 4)
	end
	-- the top bar: time, pumpkins, score
	AN.Box(MG.X(W / 2 - 300), MG.Y(14), MG.S(600), MG.S(48), Color(30, 10, 40, 200), MG.S(24))
	local secs = math.ceil(self.left)
	AN.Text(AN.L("hw_time", secs), "title", math.floor(MG.S(24)), MG.X(W / 2 - 200), MG.Y(38), secs <= 10 and Color(255, 120, 80) or WHITE, 1, 1)
	AN.Text(AN.L("hw_carve_count", self.done), "title", math.floor(MG.S(24)), MG.X(W / 2), MG.Y(38), WHITE, 1, 1)
	AN.Text(AN.L("hw_points", self.score), "title", math.floor(MG.S(24)), MG.X(W / 2 + 200), MG.Y(38), GOLD, 1, 1)
	if not (AN.VS and AN.VS.Split and AN.VS.Split.on) then AN.Text(AN.L("hw_carve_keys"), "bold", math.floor(MG.S(16)), MG.X(W / 2), MG.Y(H - 24), Color(255, 240, 210, 200), 1, 1) end
	if self.overAt then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(30, 10, 40, 220 * a), MG.S(30))
		AN.Text(AN.L("hw_timeup"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(N)
end

AN.RegisterGame(N, G)
