-- Låge 6: Elverdans
-- Rebuilt from the original loader.swf. A "Simon says" with five elves: the elves on the left
-- dance a sequence, one more step each turn, and you click the elves on the right in the same
-- order. Each right step is a point. You have 3 seconds plus 1 second per step to answer; a wrong
-- elf or too slow and the game is over (the elf you should have picked dances to show you).
-- The whole original timeline is played with the Flash player; the game code is the original's.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g06_fl.lua")

local G = {
	scoreType = "score",
	goal = 50,        -- the original coolScore
	worst = 0,
	hintCost = 2,
	descKey = "desc_06",
	howKey = "how_06",
}

local STAGE_W, STAGE_H = 480, 290
local STEP = 1 / 25
local MS = 40
local LIB = "g06"
local I = { 1, 0, 0, 1, 0, 0 }
local LIGHTS = { 115, 117, 126, 128, 130, 136, 141, 147, 161, 166 }

local CUR

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	for _, cid in ipairs(LIGHTS) do
		FL.SetActions(LIB, cid, {
			[1] = function(c) FL.GotoAndStop(c, "off") end,
			[15] = function(c) if CUR then CUR:LightAniDone(c.vars.id) end FL.GotoAndStop(c, "off") end,
			[56] = function(c) stop(c) if CUR then CUR:ShowRightAniDone() end end,
			[81] = function(c) stop(c) if CUR then CUR:DieAniDone() end end,
		})
	end
	-- the elves blink now and then (1 in 75)
	local blink = { [2] = function(c) if math.random(0, 74) < 74 then FL.GotoAndPlay(c, "noblink") end end }
	FL.SetActions(LIB, 125, blink)
	FL.SetActions(LIB, 156, blink)
	FL.SetActions(LIB, 182, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,
		[10] = function(c) if CUR then CUR.hideMouse = true end end,
		[18] = function(c)
			if CUR then
				AN.Speak(CUR.gameOverSpeak or "GameOver")
				CUR.hideMouse = false
			end
			FL.Play(c)
		end,
		[92] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Clip(name) return FL.Child(self:Game(), name) end
function G:Light(i) return self:Clip("light" .. i) end      -- the ones you click
function G:SLight(i) return self:Clip("light1" .. i) end    -- the ones that show the dance

-- the stage rectangle of a light's button (its hit area)
function G:ButtonRect(i)
	local gm = FL.ChildMatrix(self.root, "game", I)
	local lm, light = FL.ChildMatrix(self:Game(), "light" .. i, gm)
	if not light then return nil end
	local bm, btn = FL.ChildMatrix(light, "button", lm)
	if not btn or not btn.visible then return nil end
	local x0, y0, x1, y1 = FL.Bounds(btn, bm, true)
	return x0, y0, x1, y1, FL.HitFn(btn, bm)
end

function G:SetButtons(v)
	for l = 0, 4 do
		local b = FL.Child(self:Light(l), "button")
		if b then b.visible = v end
	end
end

function G:SetScore(v)
	self.score = v
	local sb = self:Clip("statusbar")
	if sb then sb.vars.txt_score = v end
end

function G:SetArm(f)
	local timer = FL.Child(self:Clip("statusbar"), "timer")
	local arm = timer and FL.Child(timer, "arm")
	if arm then FL.GotoAndStop(arm, f) end
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	for l = 0, 4 do
		local m = self:Light(l)
		if m then m.vars.id = l end
		local s = self:SLight(l)
		if s then s.vars.id = l end
	end
	self:SetButtons(false)
	self.baseTime = 3000
	self.wordTime = 1000
	self:StartNewGame()
end

function G:StartNewGame()
	self:SetScore(0)
	self.pauses = {}
	self.speech = {}
	self.curWord = -1
	self.simonState = 0
	self:SimonStartTurn()
end

function G:SimonStartTurn()
	self:SetArm(1)
	self:SetButtons(false)
	self.speech[#self.speech + 1] = math.random(0, 4)
	self.curWord = -1
	self.pauses[#self.pauses + 1] = { count = 25 }
	self.simonState = 2
	self.gameState = 1
end

function G:PlayerStartTurn()
	self:SetButtons(true)
	self.startTime = self.now
	self.levelTime = self.baseTime + self.wordTime * #self.speech
	self.error = false
	self.playerSpeech = {}
	self.playerCurWord = -1
	self.gameState = 2
end

function G:LightPressed(id)
	if self.gameState ~= 2 then return end
	if #self.playerSpeech >= #self.speech or self.error then return end
	self.playerSpeech[#self.playerSpeech + 1] = id
	self.playerCurWord = #self.playerSpeech - 1
	if id ~= self.speech[self.playerCurWord + 1] then
		self.error = true
		FL.GotoAndPlay(self:Light(id), "error")
		MG.Sound("g06", "error")
		self.gameOverSpeak = "GameOver"
		self.gameState = 3
	else
		self:LightLamp(id)
		self:SetScore(self.score + 1)
	end
end

function G:LightLamp(id)
	if self.gameState == 1 then
		FL.GotoAndPlay(self:SLight(id), "on")
	else
		FL.GotoAndPlay(self:Light(id), "on")
	end
	MG.Sound("g06", "beep" .. id)
end

function G:LightAniDone(id)
	if self.gameState == 1 then
		if self.curWord == #self.speech - 1 then self:PlayerStartTurn() end
		self.simonState = 2
	elseif self.gameState == 2 then
		if #self.playerSpeech == #self.speech then self:SimonStartTurn() end
	end
end

function G:UpdateTimer()
	local spent = (self.now - self.startTime) / self.levelTime
	if spent > 1 then
		self:SetArm(101)
		if #self.playerSpeech < #self.speech then
			self.gameState = 3
			local right = self.speech[self.playerCurWord + 2]
			FL.GotoAndPlay(self:Light(right), "showcorrect")
			MG.Sound("g06", "beep" .. right)
			self.gameOverSpeak = "GameOverTidenLoebUd"
		end
	else
		self:SetArm(1 + math.Round(spent * 100))
	end
end

-- the wrong elf has fallen: the right one (shown by the dancing elves) shows itself
function G:DieAniDone()
	local right = self.speech[self.playerCurWord + 1]
	FL.GotoAndPlay(self:SLight(right), "showcorrect")
	MG.Sound("g06", "beep" .. right)
end

function G:ShowRightAniDone()
	self:GameOver()
end

function G:GameOver()
	self.gameState = 4
	self.vars.score = self.score
	FL.GotoAndStop(self.root, "gameover")
end

-- the game clip's enterFrame
function G:EnterFrame()
	if not self.pauses then return end
	if #self.pauses == 0 then
		if self.gameState == 1 then
			if self.simonState == 2 then
				self.curWord = self.curWord + 1
				self:LightLamp(self.speech[self.curWord + 1])
				self.simonState = 1
			end
		elseif self.gameState == 2 then
			self:UpdateTimer()
		end
	else
		for p = #self.pauses, 1, -1 do
			local ps = self.pauses[p]
			ps.count = ps.count - 1
			if ps.count <= 0 then
				if ps.fn then ps.fn() end
				table.remove(self.pauses, p)
			end
		end
	end
end

---------------------------------------------------------------------------
-- hint: the whole dance is shown again, slowly, on the elves you click (a ring and the step's
-- number, 0.8 s a step); your clock stands still meanwhile
---------------------------------------------------------------------------
local HINT_STEP = 0.8
function G:CanHint() return self.gameState == 2 and not self.error and not self.hintT end
function G:Hint(cost)
	self.hintT = 0
	MG.Sound("g06", "beep" .. self.speech[1])
	self:SetScore(math.max(0, self.score - cost))
	MG.Pop("-" .. cost, false, 240, 40)
end
function G:HintStep(dt)
	if not self.hintT then return end
	local before = math.floor(self.hintT / HINT_STEP)
	self.hintT = self.hintT + dt
	self.startTime = self.startTime + dt * 1000    -- the clock waits
	local i = math.floor(self.hintT / HINT_STEP)
	if i ~= before and i < #self.speech then MG.Sound("g06", "beep" .. self.speech[i + 1]) end
	if self.gameState ~= 2 or i >= #self.speech then self.hintT = nil end
end
function G:HintDraw()
	if not self.hintT then return end
	local i = math.floor(self.hintT / HINT_STEP) + 1
	local id = self.speech[i]
	if not id then return end
	local x0, y0, x1, y1 = self:ButtonRect(id)
	if not x0 then return end
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	MG.HintRing(cx, cy, math.max(x1 - x0, y1 - y0) * 0.45, MG.HINT_GOLD)
	MG.HintText(tostring(i), cx, cy, MG.HINT_GOLD, 30)
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g06_status", self.score or 0, #(self.speech or {}))
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.score = 0
	self.gameState = 0
	self.pauses = nil
	self.speech = {}
	self.hintT = nil
	MG.ResetPops()
	self.hideMouse = false
	self.vars = { score = 0 }
	self.root = FL.New(LIB, 0)
	FL.GotoAndStop(self.root, "gameon")
end

function G:Close()
	if CUR == self then CUR = nil end
	self:ShowCursor(true)
end

function G:ShowCursor(show)
	local p = UI.root
	if IsValid(p) and p.SetCursor and self.cursorShown ~= show then
		p:SetCursor(show and "arrow" or "blank")
		self.cursorShown = show
	end
end

function G:Step()
	self.now = self.now + MS
	FL.Tick(self.root)
	self:EnterFrame()
	-- the game's own pointer (mousePointerMc) follows the mouse while the mouse is hidden
	if not MG.x0 then return end
	local mx, my = MG.Mouse()
	local m, k = FL.ChildMatrix(self.root, "mousePointerMc", I)
	if k and self.hideMouse and mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H then
		k.mat = { m[1], m[2], m[3], m[4], mx, my }
	end
end

function G:Think(dt)
	if not self.root then return end
	self.acc = self.acc + math.min(dt, 0.25)
	self:HintStep(math.min(dt, 0.25))
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	self:ShowCursor(true)
	AN.FinishGame(6, self.score or 0)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(6) return end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		return st.vars[name]
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	local mx, my = MG.Mouse()
	local inside = mx > 0 and mx < STAGE_W and my > 0 and my < STAGE_H
	self:ShowCursor(not (self.hideMouse and inside))
	-- the elves' buttons (only there while it is your turn)
	if self.gameState == 2 and self.root.frame < 18 then
		for _, l in ipairs({ 1, 2, 3, 4, 0 }) do   -- in depth order: the topmost last
			local x0, y0, x1, y1, hit = self:ButtonRect(l)
			if x0 then
				-- the box only narrows it down: the button's own hit area decides (the body parts overlap)
				UI.Button("g06_light" .. l, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:LightPressed(l) end, { silent = true, hit = hit })
			end
		end
	end
	if self.root.frame >= 18 and self.root.frame < 91 then
		UI.Button("g06_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(6)
end

AN.RegisterGame(6, G)
