-- Låge 8: Pebergrød
-- Rebuilt from the original loader.swf. Twelve bowls of rice porridge; while they are mixed, pepper is
-- shaken into one of them. Browse the bowls with the arrows and eat them by clicking - but not the one
-- with pepper. 100 points a bowl, 500 extra for the last clean bowl, minus 6 points per second used.
-- The original timeline (intro, mixing, the endings and the score count) is played back frame by frame
-- from the exported display list; the scripted parts are rebuilt here with the same numbers.
local UI, C, MG, TL = AN.UI, AN.Col, AN.MG, AN.TL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g08_anim.lua")
include(DIR .. "g08_tl.lua")
local A, T = AN.G08Anim, AN.G08TL
local BOWL, PEPPER, ARROW = A.bowl, A.pepper, A.arrow

local G = {
	scoreType = "score",
	goal = 1400,      -- the original coolScore
	worst = 0,
	descKey = "desc_08",
	howKey = "how_08",
}

local STAGE_W, STAGE_H = 400, 400
local STEP = 1 / 25
local LABEL = { intro2 = 15, left = 65, right = 98, game = 104, BONUS = 115, gameover = 200, penalty = 279, score = 291 }
local BOWL_LABEL = { mousehover = 2, ripfake = 9, ripreal = 47, mousenohover = 129, BONUS = 140 }

function G:Status()
	if (self.f or 0) < 104 then return AN.L("g08_status_wait") end
	return AN.L("g08_status", self.eaten or 0, self.timer or "0")
end

---------------------------------------------------------------------------
-- intervals (the original setInterval / clearInterval)
---------------------------------------------------------------------------
function G:SetInterval(name, ms, fn)
	self.iv[name] = { period = ms / 1000, acc = 0, fn = fn }
end

function G:ClearInterval(name)
	self.iv[name] = nil
end

function G:RunIntervals(dt)
	for name, iv in pairs(table.Copy(self.iv)) do
		local cur = self.iv[name]
		if cur == iv or (cur and cur.fn == iv.fn) then
			cur.acc = cur.acc + dt
			while self.iv[name] == cur and cur.acc >= cur.period do
				cur.acc = cur.acc - cur.period
				cur.fn()
			end
		end
	end
end

---------------------------------------------------------------------------
-- the root timeline
---------------------------------------------------------------------------
function G:Goto(f, play)
	self.f = f
	self.playing = play
	self:FrameScript(f)
end

function G:NextFrame()
	self:Goto(self.f + 1, false)
end

-- the shufflers row slides to a position, then the timeline goes on (the original "shuffle")
function G:Shuffle(newPos)
	self:SetInterval("shuffle", 40, function()
		local dif = self.shX - newPos
		if math.abs(dif) > 50 then
			self.shX = self.shX - (dif / 30 + 40 * (dif > 0 and 1 or -1))
		else
			self.shX = newPos
			self:ClearInterval("shuffle")
			self:NextFrame()
		end
	end)
end

function G:ShowPepper()
	self.realVisible = true
	self.pepF = 1
	self.pepPlaying = true
end

function G:FrameScript(f)
	local fake = self.fakeNum
	local posA, posB, posC = -1800, 0, (1 - fake) * 200
	if f == 14 then
		self.playing = false
	elseif f == 15 then
		MG.Sound("g08", "whoosh")
	elseif f == 31 then
		self.playing = false
		self.realVisible = false
		self:Shuffle(posA)
	elseif f == 32 then
		self.playing = true
	elseif f == 37 then
		self.playing = false
		self:Shuffle(fake < 7 and posC or posB)
	elseif f == 38 then
		self.playing = true
		if fake < 7 then self:ShowPepper() else self:Goto(LABEL.left, true) end
	elseif f == 70 then
		self.playing = false
		self.realVisible = false
		self:Shuffle(fake < 7 and posA or posC)
	elseif f == 71 then
		self.playing = true
		if fake > 6 then self:ShowPepper() else self:Goto(LABEL.right, true) end
	elseif f == 103 then
		self.playing = false
		self.realVisible = false
		self:Shuffle(posB)
	elseif f == 104 then
		self.playing = false
		self:StartGame()
	elseif f == 140 or f == 234 then
		self.fading = true
	elseif f == 199 or f == 278 then
		self.playing = false
		self.points = 0
		self:SetInterval("points", 20, function()
			if self.points < self.realscore then
				self:Pling()
				self.points = self.points + 10
				self.score = self.score - 10
			else
				self:ClearInterval("points")
				self:Goto(LABEL.penalty, true)
			end
		end)
	elseif f == 282 then
		self.playing = false
		self.penalty = 0
		self:SetInterval("penalty", 20, function()
			if self.penalty / 6 < self.seconds then
				self:Pling()
				self.penalty = self.penalty + 6
				-- the original count-down of the clock (it never takes a minute off)
				if self.ones > 0 then
					self.ones = self.ones - 1
				elseif self.tens > 0 then
					self.tens = self.tens - 1
					self.ones = 9
				end
				self.timer = self.minutes .. ":" .. self.tens .. self.ones
			else
				self:ClearInterval("penalty")
				self:Goto(LABEL.score, true)
			end
		end)
	elseif f == 299 then
		self.realscore = self.points - self.penalty - (self.hintCostTotal or 0)
		MG.Sound("g08", "ding")
	elseif f == 309 then
		AN.Speak("gameover")
	elseif f == 376 then
		self.playing = false
		self.finalAt = RealTime()
		self.score = self.realscore
	end
end

-- the counting "bleep" (the original plays one every 20 ms; a few less here so they don't pile up)
function G:Pling()
	local t = RealTime()
	if t - (self.lastPling or 0) < 0.06 then return end
	self.lastPling = t
	MG.Sound("g08", "pling", 0.5)
end

function G:StartGame()
	self.seconds, self.ones, self.tens, self.minutes = 0, 0, 0, 0
	self:SetInterval("timer", 1000, function()
		self.seconds = self.seconds + 1
		self.ones = self.ones + 1
		if self.ones == 10 then
			self.tens = self.tens + 1
			self.ones = 0
			if self.tens == 6 then
				self.minutes = self.minutes + 1
				self.tens = 0
			end
		end
		self.timer = self.minutes .. ":" .. self.tens .. self.ones
	end)
	self.moveActive = true
	self.mmX = 0
	self.arrowL, self.arrowR = true, true
	-- the bowls (the original duplicates "moustache0" twelve times; number fakeNum has the pepper)
	self.bowls = {}
	for i = 0, 11 do
		self.bowls[i] = { f = 1, playing = false, flag = true, fake = (i == self.fakeNum and i ~= 0), hover = false }
	end
end

-- arrows: browse the row one bowl at a time
function G:ViewMan(i)
	if not self.moveActive then return end
	MG.Sound("g08", "whoosh")
	self.currentMan = self.currentMan + i
	local newPos = self.mmX + i * 200
	self.moveActive = false
	self:SetInterval("move", 40, function()
		local dif = self.mmX - newPos
		if math.abs(dif) > 4 then
			self.mmX = self.mmX - dif / 2
		else
			self.mmX = newPos
			self:ClearInterval("move")
			self.moveActive = true
		end
	end)
	self.arrowR = self.currentMan <= 10
	self.arrowL = self.currentMan >= 1
end

---------------------------------------------------------------------------
-- a bowl (the original guy_mc)
---------------------------------------------------------------------------
function G:BowlGoto(b, f, play)
	b.f = f
	b.playing = play
	self:BowlScript(b, f)
end

function G:BowlScript(b, f)
	if f == 8 or f == 46 or f == 128 or f == 180 then
		b.playing = false
	elseif f == 9 then
		if not AN.IsSpeaking("pebergroed_risengroed") then
			AN.Speak("pebergroed_risengroed")
		end
		if self.realscore > 900 then
			-- the last clean bowl: the bonus
			b.f = BOWL_LABEL.BONUS
			b.playing = true
			self:Goto(LABEL.BONUS, true)
			self:ClearInterval("timer")
		end
	elseif f == 19 then
		self.realscore = self.realscore + 100
		self.score = self.score + 100
		self.eaten = self.eaten + 1
	elseif f == 74 then
		AN.Speak("pebergroed_pebergroed")
	elseif f == 139 then
		b.playing = false
		b.flag = true
	elseif f == 150 then
		self.realscore = self.realscore + 500
		self.score = self.score + 500
		self.eaten = self.eaten + 1
	end
end

function G:BowlOver(b, over)
	if b.flag == false then return end
	if over then self:BowlGoto(b, BOWL_LABEL.mousehover, true) else self:BowlGoto(b, BOWL_LABEL.mousenohover, true) end
end

function G:BowlRelease(b)
	if b.flag == false then return end
	b.flag = false
	if not b.fake then
		self:BowlGoto(b, BOWL_LABEL.ripfake, true)
	else
		self:BowlGoto(b, BOWL_LABEL.ripreal, true)
		self:Goto(LABEL.gameover, true)
		self:ClearInterval("timer")
	end
end

---------------------------------------------------------------------------
function G:Open(args)
	self.finished = false
	self.finalAt = nil
	self.iv = {}
	self.acc = 0
	-- frame 1 of the original
	self.fakeNum = math.floor(math.random() * 10) + 1
	self.seconds = 0
	self.score = 0
	self.realscore = 0
	self.hintPepper, self.hintCostTotal = nil, 0
	MG.ResetPops()
	self.currentMan = 10
	self.timer = "0"
	self.eaten = 0
	self.points, self.penalty = 0, 0
	self.shX = 0
	self.mmX = 0
	self.mmAlpha = 100
	self.fading = false
	self.realVisible = false
	self.pepF, self.pepPlaying = 1, false
	self.bowls = nil
	self.arrows = {}
	self.f = 1
	self.playing = true
	self:FrameScript(1)
end

function G:Step()
	-- the root timeline
	if self.playing and self.f < 376 then
		self:Goto(self.f + 1, true)
	end
	-- the pepper shaker (plays once each time it is shown; zip sounds on its frames 5, 13, 21)
	if self.pepPlaying then
		self.pepF = self.pepF + 1
		if self.pepF > #PEPPER.all then
			self.pepF = 1
			self.pepPlaying = false
		elseif self.pepF == 5 or self.pepF == 13 or self.pepF == 21 then
			MG.Sound("g08", "zipper", 0.7)
		end
	end
	-- the bowls
	if self.bowls then
		for i = 0, 11 do
			local b = self.bowls[i]
			if b.playing and b.f < #BOWL.all then
				self:BowlGoto(b, b.f + 1, true)
			end
		end
	end
	-- arrows animate while the mouse is on them
	for _, a in pairs(self.arrows) do
		if a.playing then a.f = a.f % #ARROW.all + 1 end
	end
	if self.fading then self.mmAlpha = self.mmAlpha - 10 end
end

function G:Think(dt)
	dt = math.min(dt, 0.25)
	self:RunIntervals(dt)
	self.acc = self.acc + dt
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	-- roll over / roll out of the bowls (only while they can be clicked)
	if self.bowls and self.f == LABEL.game then
		for i = 0, 11 do
			local b = self.bowls[i]
			local hot = UI.Hot("g08_bowl" .. i)
			if hot ~= b.hover then
				b.hover = hot
				self:BowlOver(b, hot)
			end
		end
	end
	for id, a in pairs(self.arrows) do
		local hot = UI.Hot(id)
		if hot ~= a.hover then
			a.hover = hot
			a.playing = hot
		end
	end
	if self.finalAt and RealTime() - self.finalAt > 2.5 then self:Finish() end
end

-- hint: the bowl with the pepper is ringed in red for the rest of the game (an arrow at the edge
-- points the way while it is off screen). The cost comes off at the end, with the time penalty.
function G:CanHint()
	if self.f ~= LABEL.game or not self.bowls or self.hintPepper then return false end
	for i = 0, 11 do local b = self.bowls[i] if b.fake and b.flag then return true end end
	return false
end
function G:Hint(cost)
	self.hintPepper = true
	self.hintCostTotal = (self.hintCostTotal or 0) + cost
	self.score = self.score - cost
	MG.Pop("-" .. cost, false, 200, 60)
end
function G:HintDraw()
	if not self.hintPepper or self.f ~= LABEL.game or not self.bowls then return end
	for i = 0, 11 do
		local b = self.bowls[i]
		if b.fake and b.flag then
			local x = self.mmX + 1 + 200 * i
			if x > -60 and x < STAGE_W + 60 then
				MG.HintRing(x, 200, 95, MG.HINT_BAD)
				MG.HintText(AN.L("g08_hint"), x, 90, MG.HINT_BAD, 26)
			elseif x < 0 then
				MG.HintArrow(80, 125, 14, 125, MG.HINT_BAD, 1, 12)
				MG.HintText(AN.L("g08_hint"), 70, 95, MG.HINT_BAD, 18)
			else
				MG.HintArrow(STAGE_W - 80, 125, STAGE_W - 14, 125, MG.HINT_BAD, 1, 12)
				MG.HintText(AN.L("g08_hint"), STAGE_W - 70, 95, MG.HINT_BAD, 18)
			end
		end
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(8, math.max(0, self.realscore))
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local function drawBowl(b, x, y, alpha)
	local idx = BOWL.all[b.f]
	TL.Cell(BOWL, idx, x, y, alpha)
	TL.CellTexts(BOWL, "all", b.f, x, y, alpha)
end

-- an arrow (the original arrow movie clip): a button while it is shown
function G:Arrow(id, m, alpha, fn)
	local a = self.arrows[id]
	if not a then a = { f = 1, playing = false, hover = false }; self.arrows[id] = a end
	local fr = ARROW.frames[ARROW.all[a.f]]
	if not fr then return end
	TL.CellM(ARROW, ARROW.all[a.f], m, alpha)
	local sc = ARROW.scale
	if fn then
		local x0, x1 = m[1] * fr[6] + m[5], m[1] * (fr[6] + fr[4] / sc) + m[5]
		if x1 < x0 then x0, x1 = x1, x0 end
		local y0, y1 = m[4] * fr[7] + m[6], m[4] * (fr[7] + fr[5] / sc) + m[6]
		UI.Button(id, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), fn, { silent = true })
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	local hooks = {}
	hooks.value = function(var)
		if var == "_parent.score" then return tostring(self.score)
		elseif var == "_parent.timer" then return tostring(self.timer)
		elseif var == "points" then return tostring(self.points)
		elseif var == "penalty" then return tostring(self.penalty)
		elseif var == "_parent.realscore" then return tostring(self.realscore) end
	end
	hooks.slot = function(name, m, alpha)
		if name == "shufflers" then
			for i = 0, 11 do
				local x = self.shX + 1 + 200 * i
				if x > -120 and x < STAGE_W + 120 then TL.Cell(BOWL, BOWL.all[1], x, 200, alpha) end
			end
		elseif name == "pepper" then
			if self.realVisible then TL.Cell(PEPPER, PEPPER.all[self.pepF], m[5], m[6], alpha) end
		elseif name == "minimen" then
			if not self.bowls then return end
			local a = math.max(0, self.mmAlpha) / 100 * alpha
			if a <= 0 then return end
			local top
			for i = 0, 11 do
				local b = self.bowls[i]
				local x = self.mmX + 1 + 200 * i
				if b.fake then top = { b, x } else
					if x > -120 and x < STAGE_W + 120 then drawBowl(b, x, 200, a) end
				end
			end
			if top and top[2] > -120 and top[2] < STAGE_W + 120 then drawBowl(top[1], top[2], 200, a) end
			-- click areas (the bowl clip's invisible 200 x 320 hit shape), kept inside the stage
			if self.f == LABEL.game then
				for i = 0, 11 do
					local x = self.mmX + 1 + 200 * i
					local x0, x1 = math.max(0, x - 100), math.min(STAGE_W, x + 100)
					if x1 > x0 then
						local b = self.bowls[i]
						UI.Button("g08_bowl" .. i, MG.X(x0), MG.Y(40), MG.S(x1 - x0), MG.S(320), function() self:BowlRelease(b) end, { silent = true })
					end
				end
			end
		elseif name == "arrow" then
			if self.f < 104 then
				-- the start arrow of the intro
				self:Arrow("g08_start", m, alpha, self.f < LABEL.intro2 and function() self:Goto(LABEL.intro2, true) end or nil)
			elseif m[1] < 0 then
				if self.arrowL then self:Arrow("g08_next", m, alpha, self.f == LABEL.game and function() self:ViewMan(-1) end or nil) end
			else
				if self.arrowR then self:Arrow("g08_prev", m, alpha, self.f == LABEL.game and function() self:ViewMan(1) end or nil) end
			end
		end
	end
	TL.Draw(T, self.f, hooks)
	self:HintDraw()
	MG.DrawPops()
	if self.f == 376 and self.finalAt and RealTime() - self.finalAt > 0.6 then
		AN.Text(AN.L("g03_click"), "black", math.floor(MG.S(11)), MG.X(200), MG.Y(385), Color(102, 0, 51, 220), 1)
		UI.Button("g08_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() self:Finish() end, { silent = true })
	end
	MG.Chrome(8)
end

AN.RegisterGame(8, G)
