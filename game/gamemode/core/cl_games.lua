-- The 24 calendar games: registry, door rules and starting/finishing a game.
AN = AN or {}
AN.Games = AN.Games or {}

-- Defaults for every door. Game files call AN.RegisterGame(n, def) to make one playable.
--   scoreType: "time" (lower is better) or "score" (higher is better)
--   goal: value that gives full 10 coins (shown on the calendar)
--   worst: value that gives 1 coin
for n = 1, 24 do
	AN.Games[n] = AN.Games[n] or { n = n, made = false, scoreType = "time", goal = 30, worst = 180 }
end

function AN.RegisterGame(n, def)
	def.n = n
	def.made = true
	def.garland = false   -- the game screen has its own decorations
	def.scoreType = def.scoreType or "time"
	AN.Games[n] = def
	-- each game gets its own screen called "game<n>"
	AN.Screens["game" .. n] = def
end

-- pebernødder 3..10 from a result, like the original: floor(3 + t * 7), where t goes
-- from 0 at the game's badScore to 1 at its coolScore
function AN.CoinsFor(n, value)
	local g = AN.Games[n]
	if g.coins then return g.coins(value) end
	local t
	if g.scoreType == "time" then
		t = (g.worst - value) / (g.worst - g.goal)
	else
		t = (value - g.worst) / (g.goal - g.worst)
	end
	return math.Clamp(math.floor(3 + 7 * math.Clamp(t, 0, 1)), 3, 10)
end

function AN.FormatValue(n, value)
	local g = AN.Games[n]
	if value == nil then return "—" end
	if g and g.scoreType == "time" then return AN.FormatTime(value) end
	return tostring(math.floor(value))
end

---------------------------------------------------------------------------
-- Doors
---------------------------------------------------------------------------
function AN.IsDecember()
	return tonumber(os.date("%m")) == 12
end

function AN.Today() return tonumber(os.date("%d")) end

-- doors follow the date only in December and only with that setting on
function AN.UsesDate()
	return AN.IsDecember() and AN.Save.Get("doorRule") ~= "progress"
end

-- returns state: "done", "today", "open", "locked" and for locked a reason key + number
function AN.DoorState(n)
	if n > 24 then return "open" end
	if AN.Save.DoorDone(n) then return "done" end
	if AN.UsesDate() then
		local d = AN.Today()
		if n > d then return "locked", "cal_locked_date", n end
		if n == AN.CurrentDoor() then return "today" end
		return "open"
	end
	-- one at a time: every earlier door with a playable game must be done
	-- (doors whose game isn't made yet don't block the ones after them)
	local blocker = AN.BlockingDoor(n)
	if not blocker then
		if n == AN.CurrentDoor() then return "today" end
		return "open"
	end
	return "locked", "cal_locked_prev", blocker
end

function AN.BlockingDoor(n)
	for i = n - 1, 1, -1 do
		if AN.Games[i].made and not AN.Save.DoorDone(i) then return i end
	end
	return nil
end

-- the door to highlight: today's date in December (if not done) or the first open, unfinished door
function AN.CurrentDoor()
	if AN.UsesDate() then
		local d = math.min(AN.Today(), 24)
		if not AN.Save.DoorDone(d) then return d end
		for i = 1, d do
			if not AN.Save.DoorDone(i) then return i end
		end
		return nil
	end
	-- the first open door with a playable game, else the first open door
	local firstOpen
	for i = 1, 24 do
		if not AN.Save.DoorDone(i) and not AN.BlockingDoor(i) then
			if AN.Games[i].made then return i end
			firstOpen = firstOpen or i
		end
	end
	return firstOpen
end

function AN.DaysToEve()
	local now = os.time()
	local y = tonumber(os.date("%Y"))
	local eve = os.time({ year = y, month = 12, day = 24, hour = 0 })
	local today = os.time({ year = y, month = tonumber(os.date("%m")), day = AN.Today(), hour = 0 })
	if today > eve then eve = os.time({ year = y + 1, month = 12, day = 24, hour = 0 }) end
	return math.floor((eve - today) / 86400 + 0.5)
end

---------------------------------------------------------------------------
-- Start / finish
---------------------------------------------------------------------------
function AN.StartGame(n)
	local g = AN.Games[n]
	if not g or not g.made then return false end
	AN.UI.Open("gamewrap", { n = n, state = "start", keepVoice = true })
	return true
end

-- called by a game when the player finishes. value = seconds or points.
-- opts.hint = true when the player used a hint (marked on the highscore list)
-- a game with levels: one level done, with the points it gave (the level's own highscore list)
-- opts.total: the game's score so far, saved at once as this run's result (so the levels already
-- done count even if the game is left before the end)
AN.CurRun = AN.CurRun or {}
function AN.LevelScore(n, level, value, opts)
	local g = AN.Games[n]
	if not g or not value then return end
	local lower = g.scoreType == "time"
	local hint = (opts and opts.hint) or AN.HintUsed[n] or nil
	AN.Save.LevelScore(n, level, value, lower, hint)
	if opts and opts.total then
		local run = AN.CurRun[n]
		if not run then
			run = { id = AN.Save.NewId() }
			AN.CurRun[n] = run
		end
		run.total, run.hint = opts.total, run.hint or hint
		AN.Save.RunProgress(n, opts.total, lower, run.hint, run.id)
	end
end

-- a new run of a game (the game screen opened, or "play again" inside the game)
function AN.NewRun(n) AN.CurRun[n] = nil AN.HintUsed[n] = nil end

---------------------------------------------------------------------------
-- Hints. A game that has one defines G:Hint(cost) (does the hint and takes the cost off its own
-- score or adds it to its time; returns false if there was nothing to show) and can define
-- G:CanHint() (false while there is nothing to help with, e.g. before the start or after the end).
-- One use costs 5 % of the door's top score (G.goal), or 5 seconds where the score is a time;
-- G.hintCost overrides it. Every result of a run where a hint was used gets the hint mark.
---------------------------------------------------------------------------
AN.HintUsed = AN.HintUsed or {}

function AN.HintsOn() return AN.Save.Get("hints") ~= false end

function AN.HintCost(n)
	local g = AN.Games[n]
	if not g then return 0 end
	if g.hintCost then return g.hintCost end
	if g.scoreType == "time" then return 5 end
	return math.max(1, math.Round((g.goal or 0) * 0.05))
end

-- the hint text for the button: "Hint: -25 points" / "Hint: +5 seconds"
function AN.HintLabel(n)
	local g = AN.Games[n]
	local c = AN.HintCost(n)
	if g and g.scoreType == "time" then return AN.L("hint_cost_time", c) end
	if g and g.hintUnit then return AN.L(g.hintUnit, c) end
	return AN.L("hint_cost_pts", c)
end

function AN.CanHint(n)
	local scr = AN.UI.screen
	if not AN.HintsOn() or not scr or not scr.Hint or AN.UI.screenName ~= "game" .. n then return false end
	if scr.CanHint and not scr:CanHint() then return false end
	return true
end

function AN.UseHint(n)
	if not AN.CanHint(n) then
		AN.Sound("click")
		return false
	end
	local scr = AN.UI.screen
	if scr:Hint(AN.HintCost(n)) == false then return false end
	AN.HintUsed[n] = true
	local run = AN.CurRun[n]
	if run then run.hint = true end
	AN.Sound("triangel")
	return true
end

function AN.FinishGame(n, value, opts)
	if n > 100 and AN.Summer then return AN.Summer.Finish(n, value, opts) end
	local g = AN.Games[n]
	local lower = g.scoreType == "time"
	local hint = opts and opts.hint or nil
	local run = AN.CurRun[n]
	AN.CurRun[n] = nil
	if (run and run.hint) or AN.HintUsed[n] then hint = true end
	AN.HintUsed[n] = nil
	local isRecord, res, id = AN.Save.Finish(n, value, lower, AN.CoinsFor(n, value), hint, run and run.id)
	AN.ScoreTabSel[n] = 0   -- the result screen shows the whole game's list, with this result marked
	AN.UI.Open("gamewrap", { n = n, state = "over", res = res, value = value, record = isRecord, entry = id })
end

-- console: an_play <door>  starts any made game directly (for testing)
concommand.Add("an_play", function(ply, cmd, args)
	local n = tonumber(args[1] or "")
	if n and AN.Games[n] and AN.Games[n].made then AN.StartGame(n) end
end)

-- The tabs above a highscore list, for games with levels: "Total" (the whole game) and one level at a
-- time ("< Level 3 >"). Shown by itself whenever the game has levels. Returns the chosen level
-- (0 = the whole game) and the height used (0 when there are no levels).
AN.ScoreTabSel = AN.ScoreTabSel or {}
AN.ScoreTabLast = AN.ScoreTabLast or {}
function AN.ScoreTabs(n, x, y, w, k, ink, id)
	local count = AN.Save.LevelCount(n)
	if count <= 0 then return 0, 0 end
	local sel = math.min(AN.ScoreTabSel[n] or 0, count)
	local cur = sel > 0 and sel or math.Clamp(AN.ScoreTabLast[n] or 1, 1, count)
	local h, gap = 30 * k, 6 * k
	local size = math.floor(16 * k)
	local cream = Color(255, 241, 207)
	local function pill(bid, bx, bw, label, on, enabled, fn)
		local hot = enabled and AN.UI.Button(bid, bx, y, bw, h, fn, { silent = true })
		local a = on and 255 or (hot and 60 or 28)
		AN.Box(bx, y, bw, h, Color(ink.r, ink.g, ink.b, enabled and a or 12), 8 * k)
		AN.Text(label, "black", size, bx + bw / 2, y + h / 2, on and cream or Color(ink.r, ink.g, ink.b, enabled and 255 or 90), 1, 1)
	end
	local function choose(l)
		AN.ScoreTabSel[n] = l
		if l > 0 then AN.ScoreTabLast[n] = l end
	end
	local tw = math.max(AN.TextSize(AN.L("hs_total"), "black", size) + 24 * k, 80 * k)
	pill(id .. "_tot", x, tw, AN.L("hs_total"), sel == 0, true, function() choose(0) end)
	local aw = 30 * k
	local lx = x + tw + gap
	local lw = w - tw - gap - 2 * (aw + gap)
	pill(id .. "_prev", lx, aw, "<", false, cur > 1, function() choose(math.max(1, cur - 1)) end)
	pill(id .. "_lvl", lx + aw + gap, lw, AN.L("hs_level", cur), sel > 0, true, function() choose(cur) end)
	pill(id .. "_next", lx + aw + gap + lw + gap, aw, ">", false, cur < count, function() choose(math.min(count, cur + 1)) end)
	return sel, h + 10 * k
end
