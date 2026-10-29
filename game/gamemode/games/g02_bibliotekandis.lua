-- Låge 2: Bibliote-Kandis
-- Rebuilt from the original loader.swf. Kandis stands in the library and books come flying from the
-- four sides. A red book flashes 8 times: press the arrow key towards it before it stops and she
-- catches it (10 points). A green book must not be caught: grab towards it and she sits down to read
-- it. A missed red book or a caught green one costs a life; 3 lives. Every caught book makes the next
-- ones come sooner and flash faster. The whole original timeline (intro, the "get ready" board, the
-- catch / miss animations and the game over board) is played back with the Flash player; the game
-- logic is the original's, with the same numbers.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g02_fl.lua")

local G = {
	scoreType = "score",
	goal = 2000,      -- the original coolScore
	worst = 0,
	descKey = "desc_02",
	howKey = "how_02",
}

local STAGE_W, STAGE_H = 480, 290
local STEP = 1 / 25
local MS = 40
local LIB = "g02"

-- the "For sent!" disk has its text drawn in; an English one is made from it
FL.ImgSwap["g02/fl/s171.png"] = { en = "g02/fl/s171_en.png" }

local CUR
local POSE = { [1] = "grab down", [2] = "grab left", [3] = "grab up", [4] = "grab right" }
local REACT = { [1] = "react down", [2] = "react left", [3] = "react up", [4] = "react right" }
local BALL = { [1] = "ball down", [2] = "ball left", [3] = "ball up", [4] = "ball right" }
local BOWL = { [1] = "bowl down", [2] = "bowl left", [3] = "bowl up", [4] = "bowl right" }
-- the player clip's frame for a catch in each direction (grab down .. grab right)
local CATCH_FRAME = { [1] = 6, [2] = 7, [3] = 8, [4] = 9 }

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end
local function play(c) FL.Play(c) end

local function setupActions()
	local stops = {}
	for f = 1, 9 do stops[f] = stop end
	stops[25] = function(c) FL.GotoAndPlay(c, "goal") end
	stops[26] = stop
	FL.SetActions(LIB, 146, stops)                                  -- Kandis
	local s8 = {}
	for f = 1, 8 do s8[f] = stop end
	FL.SetActions(LIB, 161, s8)                                     -- the book
	FL.SetActions(LIB, 168, { [2] = function() MG.Sound("ui", "point") end, [7] = stop })   -- the catch splash
	FL.SetActions(LIB, 169, { [1] = stop })
	FL.SetActions(LIB, 172, { [28] = stop })                        -- "For sent!"
	FL.SetActions(LIB, 173, { [1] = stop })
	FL.SetActions(LIB, 0, {
		[12] = stop,
		[20] = function(c) AN.Speak("gameoveringenliv") FL.Play(c) end,
		[98] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	-- the game clip: its frame scripts call back into the game
	FL.SetActions(LIB, 179, {
		[31] = function() if CUR then CUR:InitGame() end end,
		[32] = function(c) if CUR then CUR:GameStartFrame() end stop(c) end,
		[46] = function() if CUR then CUR:ScoreIncDone() end end,
		[57] = function() if CUR then CUR:LifeLostAnim() end end,
		[112] = function() if CUR then CUR:LifeLostDone() end end,
		[114] = function() if CUR then CUR:GameOverFrame() end end,
		[154] = stop,
	})
end

---------------------------------------------------------------------------
-- the original game code (the "game" clip's scripts)
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Stage() return FL.Child(self:Game(), "stage") end
function G:Clip(name) return FL.Child(self:Stage(), name) end

function G:InitGame()
	-- initInterface / initLevel / initPlayers / initEnemies
	self.player = { delay = 100, delayCount = 100, direction = 0, score = 0, life = 3, state = "ready" }
	self.ball = { level = 1, flash = { 0, 100, 0, 100, 0, 100, 0, 100 }, alpha = 0 }
	self.ball.flashFrames = #self.ball.flash
	self:ResetBall()
	self.gameState = "running"
end

function G:ResetBall()
	local b = self.ball
	b.state = "inactive"
	b.shotDelay = 1500 - b.level * 40
	b.flashDelay = 150 - b.level / 2
	b.shotDelayCount = b.shotDelay
	b.flashDelayCount = b.flashDelay
	b.flashFramesCount = b.flashFrames
	b.oldDirection = b.direction
	repeat
		b.ballSelect = math.Round(math.random() * 5)
		b.bType = b.ballSelect >= 4 and "bowlingball" or "football"
		b.direction = math.Round(math.random() * 3 + 1)
	until b.direction ~= b.oldDirection
end

function G:SetBallAlpha(a)
	self.ball.alpha = a
	local c = self:Clip("ball")
	if c then c.alpha = a / 100 end
end

function G:DoEnemies()
	local b = self.ball
	if b.shotDelayCount < 0 then
		local mc = self:Clip("ball")
		local player = self:Clip("player1")
		if b.bType == "bowlingball" then
			FL.GotoAndStop(mc, BOWL[b.direction])
			self:Flashes(false)
			if self.player.direction == b.direction then self.gameState = "life lost" end
		else
			FL.GotoAndStop(mc, BALL[b.direction])
			self:Flashes(true, BALL[b.direction])
			if player and player.frame == CATCH_FRAME[b.direction] then
				self.gameState = "scoreInc"
				local pop = self:Clip("ballpop")
				FL.GotoAndStop(pop, BALL[b.direction])
				local anim = FL.Child(pop, "anim")
				if anim then FL.GotoAndPlay(anim, 1) end
			end
		end
	else
		b.shotDelayCount = b.shotDelayCount - MS
	end
end

-- footballFlashes / bowlingballFlashes
function G:Flashes(football, label)
	local b = self.ball
	b.flashDelayCount = b.flashDelayCount - MS
	if b.flashDelayCount < 0 then
		b.flashDelayCount = b.flashDelay
		if b.flashFramesCount > 0 then
			b.state = "active"
			self:SetBallAlpha(b.flash[b.flashFramesCount])
			b.flashFramesCount = b.flashFramesCount - 1
		elseif football then
			-- too late
			self.gameState = "life lost"
			local pop = self:Clip("ballpopbad")
			FL.GotoAndStop(pop, label)
			local anim = FL.Child(pop, "anim")
			if anim then FL.GotoAndPlay(anim, 1) end
		else
			-- the green book went by
			self:ResetBall()
		end
	end
end

function G:SetPlayerPose()
	local mc = self:Clip("player1")
	if not mc then return end
	local d = self.player.direction
	if POSE[d] then
		FL.GotoAndStop(mc, POSE[d])
	elseif self.ball.state == "active" then
		-- the original goes to frame "ball.Destination + 1", which was never set (so nothing happens).
		-- Those frames are Kandis looking towards the book; with hidden content on she does.
		if AN.Save.Get("hidden") ~= false and REACT[self.ball.direction] then
			FL.GotoAndStop(mc, REACT[self.ball.direction])
		end
	else
		FL.GotoAndStop(mc, "idle")
	end
end

function G:ICheck()
	local p = self.player
	local d = 0
	if input.IsKeyDown(KEY_DOWN) then d = 1
	elseif input.IsKeyDown(KEY_LEFT) then d = 2
	elseif input.IsKeyDown(KEY_UP) then d = 3
	elseif input.IsKeyDown(KEY_RIGHT) then d = 4 end
	p.direction = d
	if d ~= 0 then
		p.delayCount = p.delay
		p.state = "grabbing"
	end
end

function G:DoPlayer()
	local p = self.player
	self:SetPlayerPose()
	if p.state == "grabbing" then
		p.delayCount = p.delayCount - MS
		if p.delayCount < 0 then p.state = "ready" end
	else
		self:ICheck()
	end
end

function G:MainLoop()
	local st = self.gameState
	local game = self:Game()
	if st == "running" then
		self:DoPlayer()
		self:DoEnemies()
	elseif st == "scoreInc" then
		self.gameState = "paused"
		self:SetBallAlpha(100)
		FL.GotoAndPlay(game, "scoreinc")
	elseif st == "life lost" then
		AN.Speak("bibliotekandis_misterliv01")
		self.gameState = "paused"
		self:SetBallAlpha(100)
		self:SetPlayerPose()
		FL.GotoAndPlay(game, "life lost")
	elseif st == "gameOver" then
		self.gameState = "paused"
		self:SetBallAlpha(0)
		FL.GotoAndPlay(game, "gameover")
	end
end

-- frame 32 ("gameStart")
function G:GameStartFrame()
	self:SetBallAlpha(0)
	if self.player then self.vars.player1life = self.player.life end
end

-- frame 46: a book caught
function G:ScoreIncDone()
	local p = self.player
	p.score = p.score + 10
	self.vars.player1score = p.score
	self.ball.level = self.ball.level + 1
	self:ResetBall()
	self.gameState = "running"
	FL.GotoAndStop(self:Game(), "gamestart")
end

-- frame 57: Kandis reads the green book, or the red book flies past her
function G:LifeLostAnim()
	self:SetBallAlpha(0)
	local mc = self:Clip("player1")
	if mc then FL.GotoAndPlay(mc, self.ball.bType == "bowlingball" and "bowling" or "goal") end
end

-- frame 112
function G:LifeLostDone()
	local p = self.player
	p.life = p.life - 1
	FL.Stop(self:Game())
	if p.life <= 0 then
		self.gameState = "gameOver"
	else
		self.vars.player1life = p.life
		self:ResetBall()
		p.state, p.direction = "ready", 0
		self.gameState = "running"
		FL.GotoAndStop(self:Game(), "gamestart")
	end
end

-- frame 114: the root goes to its game over board
function G:GameOverFrame()
	self.vars.score = self.player.score
	FL.GotoAndStop(self.root, "gameover")
end

---------------------------------------------------------------------------
-- hint: for the next 3 books, the book is ringed clearly red (catch it) or green (leave it) as soon
-- as it starts flashing, with an arrow from Kandis towards it (the flashing makes the colour hard to see)
---------------------------------------------------------------------------
function G:CanHint() return self.gameState == "running" and self.player ~= nil end
function G:Hint(cost)
	self.hintBooks = (self.hintBooks or 0) + 3
	self.hintBall = nil
	local p = self.player
	p.score = math.max(0, p.score - cost)
	self.vars.player1score = p.score
	MG.Pop("-" .. cost, false, 240, 120)
end
function G:HintTrack()
	-- one book used up each time a new one is set up
	local b = self.ball
	if self.hintBooks and self.hintBooks > 0 and b and b.state == "active" and self.hintBall ~= b.shotDelay .. b.direction .. b.bType then
		self.hintBall = b.shotDelay .. b.direction .. b.bType
		self.hintBooks = self.hintBooks - 1
		self.hintShow = true
	end
	if b and b.state ~= "active" then self.hintShow = false end
end
function G:HintDraw()
	if not self.hintShow or self.gameState ~= "running" then return end
	local _, _, x0, y0, x1, y1 = FL.PathClip(self.root, { "game", "stage", "ball" })
	local _, _, px0, py0, px1, py1 = FL.PathClip(self.root, { "game", "stage", "player1" })
	if not x0 then return end
	local col = self.ball.bType == "football" and MG.HINT_BAD or MG.HINT_GOOD
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local r = math.max(x1 - x0, y1 - y0) * 0.5 + 6
	MG.HintRing(cx, cy, r, col)
	MG.HintText(AN.L(self.ball.bType == "football" and "g02_hint_catch" or "g02_hint_leave"), cx, (cy - r - 16 < 14) and (cy + r + 16) or (cy - r - 16), col, 18)
	if px0 then
		local kx, ky = (px0 + px1) / 2, (py0 + py1) / 2
		local dx, dy = cx - kx, cy - ky
		local d = math.max(1, math.sqrt(dx * dx + dy * dy))
		if d > r + 70 then
			MG.HintArrow(kx + dx / d * 30, ky + dy / d * 30, cx - dx / d * (r + 10), cy - dy / d * (r + 10), col)
		end
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	local p = self.player
	return AN.L("g02_status", p and p.score or 0, p and math.max(0, p.life) or 3)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.vars = { player1life = 3, player1score = 0, score = 0 }
	self.player, self.ball, self.gameState = nil, nil, nil
	self.hintBooks, self.hintShow = nil, nil
	MG.ResetPops()
	self.root = FL.New(LIB, 0)
	FL.GotoAndStop(self.root, "gameon")
end

function G:Close()
	if CUR == self then CUR = nil end
end

function G:Step()
	FL.OnSound = function(c, id) if id == 4 then MG.Sound("g02", "buzz") end end
	FL.Tick(self.root)
	FL.OnSound = nil
	self:MainLoop()
	self:HintTrack()
end

function G:Think(dt)
	if not self.root then return end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	AN.FinishGame(2, self.player and self.player.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(2) return end
	local game = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		return game.vars[name]
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	-- the game over board: a click anywhere skips to the end (its button covers the whole stage)
	if self.root.frame >= 20 and self.root.frame < 96 then
		UI.Button("g02_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(2)
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(2, G)
