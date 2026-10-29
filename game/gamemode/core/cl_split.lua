-- Duel split screen: for the games played with the keyboard, both players play at the same time,
-- side by side. Player 1 (left) uses W A S D, player 2 (right) the arrow keys. Two copies of the
-- game run at once; while one copy runs it gets its own player's keys (the game still asks for the
-- arrow keys, Ctrl and Space as always), its own half of the screen and its own random numbers.
-- Only player 1's copy makes sound (two copies would play every sound twice).
-- The games played with the mouse stay as turns (cl_versus.lua).
AN = AN or {}
local UI, MG, C = AN.UI, AN.MG, AN.Col
local VS = AN.VS
local SP = {}
VS.Split = SP

-- the doors that are played split screen
SP.GAMES = { [101] = true, [102] = true, [103] = true, [105] = true, [201] = true, [202] = true, [203] = true, [204] = true, [1] = true, [2] = true, [9] = true, [12] = true, [14] = true, [16] = true, [19] = true }
function SP.Can(n) return SP.GAMES[n] == true and AN.Games[n] and AN.Games[n].made end

-- the keys: what the game asks for -> the keys of each player that count as it
local FIRE1, FIRE2 = { KEY_LCONTROL, KEY_F }, { KEY_RCONTROL, KEY_PAD_0 }
local ACT1, ACT2 = { KEY_SPACE }, { KEY_ENTER, KEY_PAD_ENTER }
SP.KEYS = {
	{
		[KEY_UP] = { KEY_W }, [KEY_DOWN] = { KEY_S }, [KEY_LEFT] = { KEY_A }, [KEY_RIGHT] = { KEY_D },
		[KEY_LCONTROL] = FIRE1, [KEY_RCONTROL] = FIRE1, [KEY_C] = FIRE1,
		[KEY_SPACE] = ACT1, [KEY_ENTER] = ACT1, [KEY_E] = { KEY_E },
	},
	{
		[KEY_UP] = { KEY_UP }, [KEY_DOWN] = { KEY_DOWN }, [KEY_LEFT] = { KEY_LEFT }, [KEY_RIGHT] = { KEY_RIGHT },
		[KEY_LCONTROL] = FIRE2, [KEY_RCONTROL] = FIRE2, [KEY_C] = FIRE2,
		[KEY_SPACE] = ACT2, [KEY_ENTER] = ACT2, [KEY_E] = { KEY_RSHIFT },
	},
}

---------------------------------------------------------------------------
-- running one copy: everything shared is switched over to it, and back afterwards
---------------------------------------------------------------------------
local function noop() end
local function with(p, fn, ...)
	local inst = p.inst
	local realKey, realPop = input.IsKeyDown, MG.pops
	local realStage, realChrome = MG.Stage, MG.Chrome
	local realButton = UI.Button
	local realPlay, realSpeak, realSound, realMG = sound.PlayFile, AN.Speak, AN.Sound, MG.Sound
	local map = SP.KEYS[p.i]
	input.IsKeyDown = function(k)
		local keys = map[k]
		if not keys then return false end
		for _, kk in ipairs(keys) do if realKey(kk) then return true end end
		return false
	end
	MG.pops = p.pops
	-- the stage is this player's half
	local st = p.stage
	MG.x0, MG.y0, MG.k, MG.sw, MG.sh = st.x0, st.y0, st.k, st.sw, st.sh
	MG.Stage = function(sw, sh)
		MG.x0, MG.y0, MG.k, MG.sw, MG.sh = st.x0, st.y0, st.k, sw, sh
		AN.Box(st.x0, st.y0, sw * st.k, sh * st.k, Color(0, 0, 0))
		render.SetScissorRect(AN.PX(st.x0), AN.SY(st.y0), AN.PX(st.x0 + sw * st.k), AN.SY(st.y0 + sh * st.k), true)
	end
	MG.Chrome = function() render.SetScissorRect(0, 0, 0, 0, false) end
	-- the copies' buttons have their own names (the same button in both halves)
	UI.Button = function(id, ...) return realButton("sp" .. p.i .. "_" .. tostring(id), ...) end
	if p.i == 2 then
		sound.PlayFile, AN.Speak, AN.Sound, MG.Sound = noop, noop, noop, noop
	end
	if inst.MakeCurrent then inst:MakeCurrent() end
	SP.cur = p
	math.randomseed(p.rng)
	local ok, err = pcall(fn, inst, ...)
	p.rng = math.random(1, 2000000000)
	SP.cur = nil
	input.IsKeyDown, MG.pops = realKey, realPop
	MG.Stage, MG.Chrome, UI.Button = realStage, realChrome, realButton
	sound.PlayFile, AN.Speak, AN.Sound, MG.Sound = realPlay, realSpeak, realSound, realMG
	if not ok then ErrorNoHalt("[Alletiders Nisse] split " .. p.i .. ": " .. tostring(err) .. "\n") end
end

-- while a copy finishes: its result is kept here, nothing is saved, no result board
if not SP.finishGame then SP.finishGame = AN.FinishGame end
function AN.FinishGame(n, value, opts)
	local p = SP.cur
	if p and SP.on then
		if p.value == nil then
			p.value = value
			p.doneAt = RealTime()
			if p.i == 1 then p.hint = (opts and opts.hint) or nil end
		end
		return
	end
	return SP.finishGame(n, value, opts)
end
if not SP.levelScore then SP.levelScore = AN.LevelScore end
function AN.LevelScore(...)
	if SP.on then return end
	return SP.levelScore(...)
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
local S = { garland = false }
AN.Screens.vssplit = S

function SP.Start(n, seed)
	UI.Open("vssplit", { n = n, seed = seed })
end

function S:Open(args)
	local n = args.n
	self.n = n
	local G = AN.Games[n]
	self.lower = G.scoreType == "time"
	SP.on = true
	AN.NewRun(n)
	self.players = {}
	for i = 1, 2 do
		local inst = setmetatable({}, { __index = G })
		local p = { i = i, inst = inst, pops = {}, rng = args.seed or 1, stage = { x0 = 0, y0 = 0, k = 1, sw = 800, sh = 600 } }
		self.players[i] = p
		self:Place()
		with(p, function(g) math.randomseed(args.seed or 1) g:Open({ n = n }) end)
	end
	-- each copy knows the other one (Skubbespil: one puzzle choice and one shuffle for both)
	self.players[1].inst.partner = self.players[2].inst
	self.players[2].inst.partner = self.players[1].inst
	self.endAt = nil
end

function S:Close()
	for _, p in ipairs(self.players or {}) do
		with(p, function(g)
			if g.StopLoops then g:StopLoops() end
			if g.Close then g:Close() end
		end)
	end
	self.players = nil
	SP.on = false
	AN.NewRun(self.n)
end

-- the two halves: each game at its own shape, as big as fits
local TOP, BOTTOM, GAP = 150, 930, 40
function S:Place()
	-- (the stage size: what the game asked for last, or 800 x 600 before it has drawn)
	for i, p in ipairs(self.players) do
		local sw, sh = p.stage.sw, p.stage.sh
		local hw = (AN.VW - 3 * GAP) / 2
		local hh = BOTTOM - TOP
		local k = math.min(hw / sw, hh / sh)
		local w, h = sw * k, sh * k
		local cx = GAP + (i - 1) * (hw + GAP) + hw / 2
		p.stage.k = k
		p.stage.x0 = cx - w / 2
		p.stage.y0 = TOP + (hh - h) / 2
	end
end

function S:Think(dt)
	if not self.players then return end
	for i = 2, 1, -1 do
		local p = self.players[i]
		if p.value == nil then with(p, function(g) if g.Think then g:Think(dt) end end) end
	end
	local a, b = self.players[1], self.players[2]
	-- a time: the first one done has won (the other one's clock has already passed it)
	if not self.endAt then
		if (a.value ~= nil and b.value ~= nil) or (self.lower and (a.value ~= nil or b.value ~= nil)) then
			self.endAt = RealTime() + 1.5
		end
	elseif RealTime() >= self.endAt then
		self:End()
	end
end

function S:End()
	local n = self.n
	local d = VS.duel
	local a, b = self.players[1], self.players[2]
	if d and d.n == n then
		d.res = { a.value, b.value }
		d.state = "result"
	end
	-- player 1's result is saved as usual
	local value, hint = a.value, a.hint
	VS.leaving = true
	UI.Open("gamewrap", { n = n, state = "start", quiet = true })
	VS.leaving = false
	if value ~= nil and n > 100 and AN.Summer then
		AN.Summer.SaveOnly(n, value)
	elseif value ~= nil then
		local g = AN.Games[n]
		AN.Save.Finish(n, value, g.scoreType == "time", AN.CoinsFor(n, value), hint, nil)
	end
end

local CREAM = Color(255, 241, 207)
function S:Paint()
	local n = self.n
	if n > 100 and AN.Summer then
		AN.Summer.Background(AN.Summer.SeasonOf(n), 150)
	else
		AN.UI.Background("sub")
		AN.Box(0, -(AN.OY or 0), AN.VW, AN.VH or 1080, Color(20, 8, 2, 150))
	end
	if not self.players then return end
	-- the stage sizes the games asked for
	for _, p in ipairs(self.players) do
		p.stage.sw, p.stage.sh = p.lastSW or p.stage.sw, p.lastSH or p.stage.sh
	end
	self:Place()
	AN.Text(AN.L("vs_duel") .. ": " .. AN.GameName(n), "title", 44, AN.VW / 2, 52, CREAM, 1, 1)
	local d = VS.duel
	for i, p in ipairs(self.players) do
		local st = p.stage
		local w, h = st.sw * st.k, st.sh * st.k
		-- frame
		AN.ImgCover("ui/woodboard.png", st.x0 - 16, st.y0 - 16, w + 32, h + 32)
		AN.Box(st.x0 - 4, st.y0 - 4, w + 8, h + 8, Color(74, 31, 7))
		-- the name and the keys above, the score below
		local name = d and d.names and d.names[i] or AN.L("vs_p" .. i)
		AN.TextFit(name, "black", 26, st.x0, st.y0 - 46, w * 0.5, C.gold)
		AN.TextFit(AN.L("vs_keys" .. i), "bold", 18, st.x0 + w, st.y0 - 42, w * 0.5, CREAM, 2)
		with(p, function(g)
			g:Paint()
			p.lastSW, p.lastSH = MG.sw, MG.sh
		end)
		render.SetScissorRect(0, 0, 0, 0, false)
		local status = p.inst.Status and p.inst:Status() or ""
		AN.TextFit(status, "bold", 22, st.x0 + w / 2, st.y0 + h + 34, w, CREAM, 1, 1)
		-- done: the half goes dark with the result
		if p.value ~= nil then
			local t = math.Clamp((RealTime() - p.doneAt) / 0.4, 0, 1)
			AN.Box(st.x0, st.y0, w, h, Color(10, 4, 0, 170 * t))
			AN.Text(AN.L("vs_done", AN.FormatValue(n, p.value)), "title", 40, st.x0 + w / 2, st.y0 + h / 2, Color(255, 215, 106, 255 * t), 1, 1)
		end
	end
	-- Luk: stop the duel
	local qx = AN.VW - 30 - 82
	local hot = UI.Button("sp_quit", qx, 14, 82, 82, function()
		VS.duel = nil
		VS.leaving = true
		UI.Open("gamewrap", { n = n, state = "start", quiet = true })
		VS.leaving = false
	end)
	AN.Img("ui/luk.png", qx + (hot and -3 or 0), 14 + (hot and -3 or 0), hot and 88 or 82, hot and 88 or 82)
end
