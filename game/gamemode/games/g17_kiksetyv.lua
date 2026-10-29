-- Låge 17: Kiksetyv
-- Rebuilt from the original loader.swf. Pyrus steals biscuits from the tin while Gyldengrød
-- reads. Click the tin to reach in and grab biscuits (one point a click). Once Pyrus has his
-- hand in the tin, Gyldengrød starts turning his head, faster and faster; click Pyrus to pull
-- the hand out before he is caught. Same numbers as the original: 60 seconds, 25 steps a
-- second, head speed grows by 0.0015 a step and he catches you at 40 degrees.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g17_pos.lua")
include(DIR .. "g17_anim.lua")
local P, A = AN.G17Pos, AN.G17Anim

local G = {
	scoreType = "score",
	goal = 155,       -- the original coolScore
	worst = 0,
	descKey = "desc_17",
	howKey = "how_17",
}

local STAGE_W, STAGE_H = 500, 400
local STEP = 1 / 25
local GAME_TIME = 60
local GAMEOVER_PAUSE = 5
local SPEED_INC, CATCH_POS = 0.0015, 40

-- where things sit on the stage (the original scene)
local BISC = { 278.95, 250.65 }
local PYRUS = { 125.85, 254.4 }
local GYLD = { 408.5, 274.3 }
local COUNT = { 246.9, 139 }
local LOOT = { -1.7, -43 }          -- loot_orig inside the biscuit clip
local HEAD = { 3.65, -45.6, 0.786 } -- Gyldengrød's head inside his clip (x, y, scale)
local TIN_HIT = { -73, -139, 146, 278 }                 -- the biscuit button, in tin coordinates
local PYRUS_HIT = { -12.75 - 73, -3.15 - 139, 146, 278 } -- the button on Pyrus while stealing

local TEAL = Color(0, 78, 115)
local CREAM = Color(255, 255, 233)

-- one frame of an exported animation, drawn with its origin at (ox, oy) on the stage
local function cell(a, idx, ox, oy)
	if not idx then return end
	local atlas = a.atlases[math.floor(idx / a.per) + 1]
	if not atlas then return end
	local c = idx % a.per
	local col, row = c % a.cols, math.floor(c / a.cols)
	local u0, v0 = col * a.cw / atlas[2], row * a.ch / atlas[3]
	local u1, v1 = (col + 1) * a.cw / atlas[2], (row + 1) * a.ch / atlas[3]
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(AN.Mat(atlas[1]))
	surface.DrawTexturedRectUV(AN.PX(MG.X(ox + a.x)), AN.SY(MG.Y(oy + a.y)), AN.SX(MG.S(a.w)), AN.SX(MG.S(a.h)), u0, v0, u1, v1)
end

local function piece(name, ox, oy, alpha)
	local r = P[name]
	MG.Img("g17/" .. name .. ".png", ox + r[1], oy + r[2], r[3], r[4], alpha)
end

-- a piece of the head, turned 'deg' degrees clockwise around the head's origin
local function headPiece(name, deg, alpha)
	local r = P[name]
	local s = HEAD[3]
	local cx, cy = (r[1] + r[3] / 2) * s, (r[2] + r[4] / 2) * s
	local a = math.rad(deg)
	local rx, ry = cx * math.cos(a) - cy * math.sin(a), cx * math.sin(a) + cy * math.cos(a)
	local sx, sy = GYLD[1] + HEAD[1] + rx, GYLD[2] + HEAD[2] + ry
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(AN.Mat("g17/" .. name .. ".png"))
	surface.DrawTexturedRectRotated(AN.PX(MG.X(sx)), AN.SY(MG.Y(sy)), AN.SX(MG.S(r[3] * s)), AN.SX(MG.S(r[4] * s)), -deg)
end

-- a click area in stage coordinates (the original buttons react on press)
local function hit(id, ox, oy, r, fn)
	UI.Button(id, MG.X(ox + r[1]), MG.Y(oy + r[2]), MG.S(r[3]), MG.S(r[4]), fn, { silent = true })
end

local function clock(t)
	t = math.max(0, math.floor(t))
	return string.format("%02d:%02d", math.floor(t / 60), t % 60)
end

function G:Status()
	return AN.L("g17_status", self.score or 0, clock(math.ceil(self.timeLeft or GAME_TIME)))
end

function G:Open(args)
	self.finished = false
	self.signAt = nil
	self.acc = 0
	self.score = 0
	self.gameState = 0          -- 0 countdown, 1 playing, 2 caught, 3 time up, 4 sign
	self.timeSpent = 0
	self.timeLeft = GAME_TIME
	self.cdF = 1
	self.py = { state = 0, anim = "idle", f = 1 }
	self.gy = { state = 0, anim = "idle", f = 1, speed = 0, pos = 0 }
	self.loot = {}
end

function G:PyAnim(name)
	self.py.anim, self.py.f = name, 1
end

function G:GyAnim(name)
	self.gy.anim, self.gy.f = name, 1
end

-- the original button handlers
function G:BiscuitsPressed()
	if self.gameState ~= 1 then return end
	local py = self.py
	if py.state == 0 then
		py.state = 1
		self:PyAnim("reaching")
	elseif py.state == 2 then
		py.state = 3
		self:PyAnim("stealing")
		py.f = 2
		MG.Sound("g17", "steal", 0.8)
		self.loot[#self.loot + 1] = { f = 1 }
		self.score = self.score + 1
	end
end

function G:PyrusPressed()
	if self.gameState ~= 1 then return end
	local py = self.py
	if py.state == 2 or py.state == 3 then
		py.state = 4
		self:PyAnim("escaping")
		MG.Sound("g17", "escape")   -- a sound stream in the escape animation
	end
end

function G:CatchPyrus()
	AN.Speak("skidt")
	self.gy.state = 3
	self:GyAnim("catching")
	self.py.state = 5
	self:PyAnim("crying")
	self.gameState = 2
end

-- hint (10 seconds): a danger meter shows how far Gyldengrød has turned his head (he sees Pyrus at
-- the top), with "OUT!" when it is time to pull the hand out
function G:CanHint() return self.gameState == 1 and not self.hintT end
function G:Hint(cost)
	self.hintT = 10
	self.score = math.max(0, self.score - cost)
	MG.Pop("-" .. cost, false, 430, 60)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.gameState ~= 1 then self.hintT = nil return end
	local a = math.min(1, self.hintT * 2)
	local gy = self.gy
	local k = gy.state == 1 and math.Clamp(gy.pos / CATCH_POS, 0, 1) or 0
	-- (the head turns faster and faster: warn a little early)
	local danger = k > 0.6
	local x, y, w, h = 452, 110, 22, 150
	AN.Box(MG.X(x - 3), MG.Y(y - 3), MG.S(w + 6), MG.S(h + 6), Color(40, 12, 2, 220 * a), MG.S(4))
	local col = danger and MG.HINT_BAD or (k > 0.35 and MG.HINT_GOLD or MG.HINT_GOOD)
	AN.Box(MG.X(x), MG.Y(y + h * (1 - k)), MG.S(w), MG.S(h * k), Color(col.r, col.g, col.b, 255 * a), MG.S(3))
	MG.HintText("!", x + w / 2, y - 16, MG.HINT_BAD, 20, a)
	if danger and (self.py.state == 2 or self.py.state == 3) then
		MG.HintText(AN.L("g17_hint_out"), PYRUS[1], PYRUS[2] - 150, MG.HINT_BAD, 28, a)
	end
end

function G:GameOver()
	if self.gameState == 4 then return end
	self.gameState = 4
	self.signAt = RealTime()
	AN.Speak("gameover")
end

-- one step (the original runs at 25 frames a second)
function G:Step()
	-- countdown clip: 3, 2, 1, NU! (countdownDone on its frame 40)
	if self.cdF <= #A.countdown.start then
		self.cdF = self.cdF + 1
		if self.cdF == 40 and self.gameState == 0 then self.gameState = 1 end
	end

	if self.gameState == 1 then
		-- Gyldengrød turns his head while Pyrus has his hand in the tin
		local gy = self.gy
		if gy.state == 1 then
			gy.speed = gy.speed + SPEED_INC
			gy.pos = gy.pos + gy.speed
			if gy.pos >= CATCH_POS then self:CatchPyrus() end
		elseif gy.state == 2 then
			gy.pos = 0
		end
		self.timeSpent = self.timeSpent + STEP
		self.timeLeft = GAME_TIME - self.timeSpent
		if self.timeLeft <= 0 then
			self.timeLeft = 0
			self.gameState = 3
		end
	elseif self.gameState == 3 then
		self.timeSpent = self.timeSpent + STEP
		if GAME_TIME - self.timeSpent <= -GAMEOVER_PAUSE then self:GameOver() end
	end

	-- Pyrus
	local py = self.py
	if py.state == 0 then
		py.f = py.f % #A.pyrus.idle + 1
	elseif py.state == 1 then
		py.f = py.f + 1
		if py.f > #A.pyrus.reaching then
			-- pyrusReachingAnimDone
			py.state = 2
			self:PyAnim("stealing")
			if self.gy.state ~= 3 then
				self.gy.state = 1
				self:GyAnim("looking")
			end
		end
	elseif py.state == 3 then
		py.f = py.f + 1
		if py.f > #A.pyrus.stealing then
			py.state = 2   -- reachingAnimDone: back to the still hand-in-tin frame
			py.f = 1
		end
	elseif py.state == 4 then
		py.f = py.f + 1
		if py.f > #A.pyrus.escaping then
			-- pyrusEscapingAnimDone
			py.state = 0
			self:PyAnim("idle")
			self.gy.state = 2
			self.gy.pos = 0
			self:GyAnim("idle")
		end
	elseif py.state == 5 then
		py.f = py.f % #A.pyrus.crying + 1
	end

	-- Gyldengrød catching
	local gy = self.gy
	if gy.state == 3 then
		gy.f = gy.f + 1
		if gy.f > #A.gylden.catching then
			gy.f = #A.gylden.catching
			self:GameOver()   -- gyldenCatchingAnimDone
		end
	end

	-- biscuits flying into the sack
	for i = #self.loot, 1, -1 do
		local l = self.loot[i]
		l.f = l.f + 1
		if l.f > #A.loot.fly then table.remove(self.loot, i) end
	end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	if self.gameState == 4 and RealTime() - self.signAt > 3.2 then self:Finish() end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(17, self.score)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	local bg = P.bg
	MG.Img("g17/bg.jpg", bg[1], bg[2], bg[3], bg[4])

	-- the biscuit tin, the biscuits flying out of it, and the sack in front
	piece("tin", BISC[1], BISC[2])
	for _, l in ipairs(self.loot) do
		cell(A.loot, A.loot.fly[l.f], BISC[1] + LOOT[1], BISC[2] + LOOT[2])
	end
	piece("sack", BISC[1], BISC[2])

	-- Pyrus
	local py = self.py
	local seq = A.pyrus[py.anim]
	cell(A.pyrus, seq[math.Clamp(py.f, 1, #seq)], PYRUS[1], PYRUS[2])

	-- Gyldengrød: the turning head while he is looking, his own animation otherwise
	local gy = self.gy
	if gy.state == 1 then
		piece("gbody", GYLD[1], GYLD[2])
		local deg = gy.pos
		headPiece("head_lo", deg)
		headPiece("anger", deg, math.Clamp(gy.pos / CATCH_POS, 0, 1) * 255)
		headPiece("head_hi", deg)
	elseif gy.state == 3 then
		cell(A.gylden, A.gylden.catching[math.Clamp(gy.f, 1, #A.gylden.catching)], GYLD[1], GYLD[2])
	else
		cell(A.gylden, A.gylden.idle[1], GYLD[1], GYLD[2])
	end

	-- the buttons: the tin, and Pyrus himself while his hand is in the tin
	if self.gameState == 1 then
		hit("g17_tin", BISC[1], BISC[2], TIN_HIT, function() self:BiscuitsPressed() end)
		if py.state == 2 or py.state == 3 then
			hit("g17_pyrus", PYRUS[1], PYRUS[2], PYRUS_HIT, function() self:PyrusPressed() end)
		end
	end

	-- countdown 3, 2, 1, NU!  (in English the last one says GO!)
	local cd = A.countdown.start
	if self.cdF <= #cd then
		local idx = cd[self.cdF]
		if idx >= 39 and AN.LangCode() ~= "da" then
			if idx < 49 then
				local fade = 1 - (idx - 39) / 10
				AN.Text(AN.L("g17_go"), "title", math.floor(MG.S(110)), MG.X(COUNT[1] - 5), MG.Y(COUNT[2] + 24), TEAL, 1, 1, 255 * fade)
			end
		elseif idx > 0 then
			cell(A.countdown, idx, COUNT[1], COUNT[2])
		end
	end

	-- status bar: time left and score (the original "SCORE:" label)
	local sz = math.floor(MG.S(27))
	local t = clock(math.ceil(self.timeLeft))
	AN.Text(t, "title", sz, MG.X(60) + MG.S(1.5), MG.Y(25) + MG.S(1.5), CREAM, 1, 1)
	AN.Text(t, "title", sz, MG.X(60), MG.Y(25), TEAL, 1, 1)
	local st = P.status
	MG.Img("g17/status.png", 135.95 + st[1], -2.55 + st[2], st[3], st[4])
	local s = tostring(self.score)
	AN.Text(s, "title", sz, MG.X(486) + MG.S(1.5), MG.Y(25) + MG.S(1.5), CREAM, 2, 1)
	AN.Text(s, "title", sz, MG.X(486), MG.Y(25), TEAL, 2, 1)

	self:HintDraw()
	MG.DrawPops()

	-- "Spil Slut!" sign
	if self.gameState == 4 then
		local sr = AN.G17Sign.sign
		if AN.LangCode() == "da" then
			MG.Img("g17/sign_da.png", sr[1], sr[2], sr[3], sr[4])
		else
			MG.Img("g17/sign.png", sr[1], sr[2], sr[3], sr[4])
			AN.Text(AN.L("g03_over"), "title", math.floor(MG.S(44)), MG.X(246), MG.Y(158), CREAM, 1, 1)
			AN.Text(AN.L("g03_points"), "title", math.floor(MG.S(15)), MG.X(130), MG.Y(214), CREAM, 0, 1)
		end
		AN.Text(s, "title", math.floor(MG.S(17)), MG.X(366), MG.Y(214), CREAM, 2, 1)
		if RealTime() - self.signAt > 0.8 then
			AN.Text(AN.L("g03_click"), "black", math.floor(MG.S(10)), MG.X(250), MG.Y(300), Color(255, 241, 207, 210), 1)
		end
		UI.Button("g17_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:Finish() end, { silent = true })
	end

	MG.Chrome(17)
end

AN.RegisterGame(17, G)
