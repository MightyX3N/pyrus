-- Versus, chosen on each game's start board:
--   Kapløb: race the other players on the server. One player invites, the others say yes, everyone
--           gets 3-2-1 and plays the same game with the same random layout, with the others' live
--           scores in a strip; at the end everyone gets the ranking. Results are saved as usual.
--   Duel:   two players on one PC take turns with the same layout; the best result wins.
--           Player 1 (the PC's own player) keeps the result as usual, player 2 is a guest.
--           The keyboard games are played split screen instead, both at once (cl_split.lua).
-- Everything here is drawn on top of whatever screen is open (AN.DrawVersus from UI.Frame).
AN = AN or {}
local UI, C = AN.UI, AN.Col
local VS = AN.VS or {}
AN.VS = VS
VS.invites = VS.invites or {}

local function lower(n) return AN.Games[n] and AN.Games[n].scoreType == "time" end
local function myName() return IsValid(LocalPlayer()) and LocalPlayer():Nick() or AN.L("vs_p1") end
local function others()
	local n = 0
	for _, p in ipairs(player.GetHumans()) do if p ~= LocalPlayer() then n = n + 1 end end
	return n
end
VS.Others = others

local function send(kind, fn)
	net.Start("an_vs")
	net.WriteString(kind)
	if fn then fn() end
	net.SendToServer()
end

-- start a game right now in the current look, with a fixed random seed
function VS.PlayNow(n, seed)
	VS.seed = seed
	if AN.Classic and AN.Classic.Active() and n <= 24 then
		UI.Open("classic", { keep = true })
		AN.Classic.cur = n
		AN.Classic.GameStart()
	else
		UI.Open("game" .. n, { n = n })
	end
end

-- back to the game's start board (quietly)
local function toBoard(n)
	UI.Open("gamewrap", { n = n, state = "start", quiet = true })
end

---------------------------------------------------------------------------
-- Kapløb on the server
---------------------------------------------------------------------------
function VS.Invite(n)
	VS.race = nil
	send("invite", function() net.WriteUInt(n, 8) net.WriteBool(lower(n) and true or false) end)
end
function VS.Join(id)
	VS.invites[id] = nil
	send("join", function() net.WriteUInt(id, 16) end)
end
function VS.Leave()
	local r = VS.race
	if r then send("leave", function() net.WriteUInt(r.id, 16) end) end
	VS.race = nil
end

local function readList()
	local list = {}
	for i = 1, net.ReadUInt(8) do list[i] = { sid = net.ReadString(), name = net.ReadString() } end
	return list
end

net.Receive("an_vs", function()
	local kind = net.ReadString()
	if kind == "invite" then
		local id, n, who = net.ReadUInt(16), net.ReadUInt(8), net.ReadString()
		VS.invites[id] = { id = id, n = n, who = who, t = RealTime() }
		AN.Sound("triangel")
	elseif kind == "lobby" then
		local id, n, host = net.ReadUInt(16), net.ReadUInt(8), net.ReadString()
		local list = readList()
		VS.race = VS.race and VS.race.id == id and VS.race or { id = id }
		local r = VS.race
		r.n, r.host, r.list, r.state = n, host, list, "lobby"
	elseif kind == "cancel" then
		local id = net.ReadUInt(16)
		VS.invites[id] = nil
		if VS.race and VS.race.id == id then VS.race = nil end
	elseif kind == "go" then
		local id, n, seed = net.ReadUInt(16), net.ReadUInt(8), net.ReadUInt(32)
		local list = readList()
		VS.race = { id = id, n = n, seed = seed, list = list, state = "count", goAt = RealTime() + 3,
			live = {}, done = {} }
		VS.duel = nil
	elseif kind == "live" then
		local id, sid, text = net.ReadUInt(16), net.ReadString(), net.ReadString()
		if VS.race and VS.race.id == id then VS.race.live[sid] = text end
	elseif kind == "done" then
		local id, sid, v, quit = net.ReadUInt(16), net.ReadString(), net.ReadFloat(), net.ReadBool()
		if VS.race and VS.race.id == id then VS.race.done[sid] = { v = v, quit = quit } end
	elseif kind == "result" then
		local id, n = net.ReadUInt(16), net.ReadUInt(8)
		local list = {}
		for i = 1, net.ReadUInt(8) do
			list[i] = { sid = net.ReadString(), name = net.ReadString(), v = net.ReadFloat(), quit = net.ReadBool() }
		end
		VS.result = { n = n, list = list, notSaved = VS.race and VS.race.notSaved }
		if VS.race and VS.race.id == id then VS.race = nil end
		AN.Sound("triangel")
	end
end)

-- live: what the game shows in its status line, twice a second
hook.Add("Think", "AN_VsLive", function()
	local r = VS.race
	if not r then return end
	if r.state == "count" and RealTime() >= r.goAt then
		r.state = "run"
		VS.PlayNow(r.n, r.seed)
	end
	if r.state == "run" and UI.screenName == "game" .. r.n and RealTime() >= (r.nextLive or 0) then
		r.nextLive = RealTime() + 0.5
		local g = UI.screen
		local ok, st = pcall(function() return g and g.Status and g:Status() end)
		if ok and st then send("live", function() net.WriteUInt(r.id, 16) net.WriteString(tostring(st)) end) end
	end
end)

---------------------------------------------------------------------------
-- Duel on one PC
---------------------------------------------------------------------------
function VS.Duel(n)
	VS.race = nil
	VS.duel = { n = n, seed = math.random(1, 2000000000), turn = 1, res = {}, names = { myName(), AN.L("vs_p2") },
		state = "ready" }
end

-- the result is saved like a normal game, but the result board is skipped
local function saveOnly(n, value, opts)
	local g = AN.Games[n]
	local run = AN.CurRun[n]
	AN.CurRun[n] = nil
	local hint = (opts and opts.hint) or (run and run.hint) or AN.HintUsed[n]
	AN.HintUsed[n] = nil
	AN.Save.Finish(n, value, g.scoreType == "time", AN.CoinsFor(n, value), hint, run and run.id)
end

---------------------------------------------------------------------------
-- Finishing and leaving a game while a versus is on
---------------------------------------------------------------------------
if not VS.finishGame then VS.finishGame = AN.FinishGame end
function AN.FinishGame(n, value, opts)
	local r, d = VS.race, VS.duel
	if r and r.state == "run" and r.n == n and not r.finished then
		r.finished = true
		send("done", function() net.WriteUInt(r.id, 16) net.WriteFloat(value) end)
		if AN.DoorState(n) ~= "locked" then return VS.finishGame(n, value, opts) end
		r.notSaved = true
		toBoard(n)
		return
	end
	if d and d.n == n and d.state == "play" then
		d.res[d.turn] = value
		if d.turn == 1 then
			saveOnly(n, value, opts)
			d.turn = 2
			d.state = "ready"
		else
			AN.CurRun[n] = nil
			AN.HintUsed[n] = nil
			d.state = "result"
		end
		VS.leaving = true
		toBoard(n)
		VS.leaving = false
		return
	end
	return VS.finishGame(n, value, opts)
end

-- a game screen closed before the end: gave up
if not VS.uiOpen then VS.uiOpen = UI.Open end
function UI.Open(name, args)
	local was = UI.screenName
	local r, d = VS.race, VS.duel
	local playing = was and string.match(was, "^game(%d+)$")
	local nowGame = string.match(name or "", "^game(%d+)$")
	if playing and not nowGame and not VS.leaving then
		if r and r.state == "run" and not r.finished and tonumber(playing) == r.n then VS.Leave() end
		if d and d.state == "play" then VS.duel = nil end
	end
	-- a game opens with the versus' random seed (the same layout for everyone)
	if nowGame and VS.seed then
		math.randomseed(VS.seed)
	end
	if not nowGame then VS.seed = nil end
	return VS.uiOpen(name, args)
end

---------------------------------------------------------------------------
-- The buttons on the start board: Kapløb and Duel (x, y = top-left, s = scale)
---------------------------------------------------------------------------
local WOOD = Color(122, 52, 18)
local WOOD_HOT = Color(158, 70, 26)
local CREAM = Color(255, 241, 207)
function VS.BoardButtons(n, x, y, s)
	local w, h, gap = 190 * s, 52 * s, 14 * s
	local o = others()
	local function btn(id, label, sub, bx, enabled, fn)
		local hot = enabled and UI.Button(id, bx, y, w, h, fn) or false
		AN.Box(bx + 3 * s, y + 5 * s, w, h, Color(0, 0, 0, 90), 10 * s)
		AN.Box(bx, y, w, h, enabled and (hot and WOOD_HOT or WOOD) or Color(90, 60, 45), 10 * s)
		AN.Outline(bx, y, w, h, Color(40, 14, 2, 200), 10 * s, 2)
		local a = enabled and 255 or 120
		AN.Text(label, "title", math.floor(24 * s), bx + w / 2, y + (sub and 18 or 26) * s, Color(CREAM.r, CREAM.g, CREAM.b, a), 1, 1)
		if sub then AN.Text(sub, "bold", math.floor(13 * s), bx + w / 2, y + 39 * s, Color(255, 215, 106, a), 1, 1) end
		return hot
	end
	btn("vs_race", AN.L("vs_race"), o > 0 and AN.L("vs_players", o + 1) or AN.L("vs_race_off"), x, o > 0,
		function() VS.Invite(n) end)
	btn("vs_duel", AN.L("vs_duel"), AN.L("vs_duel_sub"), x + w + gap, true, function() VS.Duel(n) end)
end

---------------------------------------------------------------------------
-- Drawing: invitations, the lobby, 3-2-1, the live strip, the results
---------------------------------------------------------------------------
local function panel(w, h)
	local x, y = AN.VW / 2 - w / 2, AN.VH / 2 - (AN.OY or 0) - h / 2
	-- (nothing behind can be clicked)
	UI.Button("vs_block", -2000, -2000, AN.VW + 4000, AN.VH + 4000, nil, { silent = true, press = function() end })
	AN.Box(0, -(AN.OY or 0), AN.VW, AN.VH, Color(10, 4, 0, 150))
	AN.Box(x + 6, y + 14, w, h, Color(0, 0, 0, 110), 22)
	AN.Box(x, y, w, h, Color(248, 234, 208), 22)
	AN.Outline(x, y, w, h, Color(226, 201, 155), 22, 3)
	return x, y
end
local INK = Color(59, 26, 8)
local RED = Color(138, 42, 10)

local function pbtn(id, label, x, y, w, fn, red)
	local hot = UI.Button(id, x, y, w, 56, fn)
	AN.Box(x, y + 4, w, 56, red and C.redDark or Color(90, 40, 14), 14)
	AN.Box(x, y, w, 56, red and (hot and Color(222, 44, 57) or C.red) or (hot and WOOD_HOT or WOOD), 14)
	AN.Text(label, "black", 24, x + w / 2, y + 28, C.white, 1, 1)
end

local function value(n, v) return AN.FormatValue(n, v) end

local function drawInvites()
	local y = 30 - (AN.OY or 0)
	for id, inv in pairs(VS.invites) do
		if RealTime() - inv.t > 30 then
			VS.invites[id] = nil
		else
			local w, h = 760, 150
			local x = AN.VW / 2 - w / 2
			AN.Box(x + 4, y + 8, w, h, Color(0, 0, 0, 110), 20)
			AN.Box(x, y, w, h, Color(248, 234, 208), 20)
			AN.Outline(x, y, w, h, C.gold, 20, 3)
			AN.TextWrap(AN.L("vs_invite", inv.who, inv.n, AN.GameName(inv.n)), "black", 24, x + 28, y + 20, w - 56, INK, 30)
			pbtn("vs_inv_yes" .. id, AN.L("vs_yes"), x + w - 28 - 200 - 14 - 200, y + h - 74, 200, function() VS.Join(id) end, true)
			pbtn("vs_inv_no" .. id, AN.L("vs_no"), x + w - 28 - 200, y + h - 74, 200, function() VS.invites[id] = nil end)
			y = y + h + 14
		end
	end
end

local function drawLobby(r)
	local w = 640
	local h = 210 + #r.list * 44
	local x, y = panel(w, h)
	AN.Text(AN.L("vs_lobby", AN.GameName(r.n)), "title", 40, x + 30, y + 24, RED)
	local yy = y + 92
	for _, p in ipairs(r.list) do
		AN.Circle(x + 44, yy + 16, 7, C.gold)
		AN.Text(p.name .. (p.sid == r.host and ("  " .. AN.L("vs_host")) or ""), "bold", 24, x + 62, yy, INK)
		yy = yy + 44
	end
	local me = AN.Save.MySid()
	if r.host == me then
		pbtn("vs_go", AN.L("vs_start"), x + 30, y + h - 86, 260, function()
			send("start", function() net.WriteUInt(r.id, 16) end)
		end, true)
		pbtn("vs_cancel", AN.L("vs_cancel"), x + w - 30 - 220, y + h - 86, 220, function() VS.Leave() end)
	else
		local host = "?"
		for _, p in ipairs(r.list) do if p.sid == r.host then host = p.name end end
		AN.Text(AN.L("vs_waiting", host), "bold", 22, x + 30, y + h - 68, INK)
		pbtn("vs_leave", AN.L("vs_leave"), x + w - 30 - 220, y + h - 86, 220, function() VS.Leave() end)
	end
end

local function drawCount(r)
	local left = math.ceil(r.goAt - RealTime())
	UI.Button("vs_block", -2000, -2000, AN.VW + 4000, AN.VH + 4000, nil, { silent = true, press = function() end })
	AN.Box(0, -(AN.OY or 0), AN.VW, AN.VH, Color(10, 4, 0, 160))
	AN.Text(AN.GameName(r.n), "title", 60, AN.VW / 2, AN.VH / 2 - (AN.OY or 0) - 160, C.white, 1, 1)
	AN.Text(tostring(math.max(1, left)), "title", 220, AN.VW / 2, AN.VH / 2 - (AN.OY or 0) + 10, C.gold, 1, 1)
end

-- the others' scores, top right, while racing
local function drawStrip(r)
	if UI.screenName ~= "game" .. r.n then return end
	local me = AN.Save.MySid()
	local rows = {}
	for _, p in ipairs(r.list) do
		if p.sid ~= me then
			local d = r.done[p.sid]
			local txt
			if d and d.quit then txt = AN.L("vs_quit")
			elseif d then txt = AN.L("vs_done", value(r.n, d.v))
			else txt = r.live[p.sid] or "…" end
			rows[#rows + 1] = { p.name, txt, d ~= nil }
		end
	end
	if #rows == 0 then return end
	local w = 460
	local x, y = AN.VW - w - 30, 170 - (AN.OY or 0)
	AN.Box(x, y, w, 44 + #rows * 52, Color(20, 8, 2, 200), 16)
	AN.Text(AN.L("vs_race"), "black", 18, x + 18, y + 12, C.gold)
	for i, row in ipairs(rows) do
		local yy = y + 40 + (i - 1) * 52
		AN.TextFit(row[1], "black", 20, x + 18, yy, w - 36, C.white)
		AN.TextFit(row[2], "bold", 17, x + 18, yy + 24, w - 36, row[3] and C.gold or C.cream)
	end
end

local function drawResult(res)
	local w = 680
	local h = 200 + #res.list * 46
	local x, y = panel(w, h)
	AN.Text(AN.L("vs_result", AN.GameName(res.n)), "title", 40, x + 30, y + 24, RED)
	local me = AN.Save.MySid()
	local yy = y + 92
	for i, e in ipairs(res.list) do
		local col = e.sid == me and RED or INK
		AN.Text(i .. ".", "black", 26, x + 60, yy, col, 2)
		AN.TextFit(e.name, "black", 26, x + 76, yy, 340, col)
		AN.Text(e.quit and AN.L("vs_quit") or value(res.n, e.v), "black", 26, x + w - 30, yy, col, 2)
		yy = yy + 46
	end
	if res.notSaved then AN.Text(AN.L("vs_notsaved"), "bold", 18, x + 30, y + h - 104, INK) end
	pbtn("vs_res_close", AN.L("vs_close"), x + w / 2 - 110, y + h - 80, 220, function() VS.result = nil end, true)
end

local function drawDuel(d)
	local n = d.n
	if d.state == "ready" then
		local w, h = 680, (VS.Split and VS.Split.Can(n)) and 340 or 300
		local x, y = panel(w, h)
		AN.Text(AN.L("vs_duel") .. ": " .. AN.GameName(n), "title", 40, x + 30, y + 24, RED)
		local yy = y + 96
		if d.turn == 2 then
			AN.Text(AN.L("vs_got", d.names[1], value(n, d.res[1])), "bold", 24, x + 30, yy, INK)
			yy = yy + 40
		end
		local split = VS.Split and VS.Split.Can(n)
		if split then
			-- the keyboard games: both at once, side by side
			AN.Text(AN.L("vs_split"), "black", 28, x + 30, yy, INK)
			AN.Text(d.names[1] .. ":  " .. AN.L("vs_keys1"), "bold", 21, x + 30, yy + 44, INK)
			AN.Text(d.names[2] .. ":  " .. AN.L("vs_keys2"), "bold", 21, x + 30, yy + 76, INK)
		else
			AN.Text(AN.L("vs_turn", d.names[d.turn]), "black", 30, x + 30, yy, INK)
		end
		pbtn("vs_duel_go", AN.L("vs_start"), x + 30, y + h - 86, 260, function()
			if split then
				d.state = "split"
				VS.Split.Start(n, d.seed)
				return
			end
			d.state = "play"
			VS.PlayNow(n, d.seed)
		end, true)
		pbtn("vs_duel_stop", AN.L("vs_cancel"), x + w - 30 - 220, y + h - 86, 220, function() VS.duel = nil end)
	elseif d.state == "result" then
		local w, h = 680, 330
		local x, y = panel(w, h)
		AN.Text(AN.L("vs_duel") .. ": " .. AN.GameName(n), "title", 40, x + 30, y + 24, RED)
		local a, b = d.res[1], d.res[2]
		local win
		if a == nil or b == nil then win = (a ~= nil and 1) or (b ~= nil and 2) or nil
		elseif a == b then win = nil
		elseif lower(n) then win = a < b and 1 or 2
		else win = a > b and 1 or 2 end
		for i = 1, 2 do
			local yy = y + 92 + (i - 1) * 46
			local col = win == i and RED or INK
			AN.TextFit(d.names[i], "black", 26, x + 40, yy, 360, col)
			AN.Text(value(n, d.res[i]), "black", 26, x + w - 40, yy, col, 2)
		end
		AN.Text(win and AN.L("vs_wins", d.names[win]) or AN.L("vs_draw"), "title", 34, x + w / 2, y + 210, C.redDark, 1, 1)
		pbtn("vs_duel_again", AN.L("vs_again"), x + 30, y + h - 86, 260, function() VS.Duel(n) end, true)
		pbtn("vs_duel_back", AN.L("vs_back"), x + w - 30 - 220, y + h - 86, 220, function() VS.duel = nil end)
	end
end

function AN.DrawVersus()
	local r, d = VS.race, VS.duel
	if r then
		if r.state == "lobby" then drawLobby(r)
		elseif r.state == "count" then drawCount(r)
		elseif r.state == "run" then drawStrip(r) end
	end
	if d and d.state ~= "play" then drawDuel(d) end
	if VS.result then drawResult(VS.result) end
	drawInvites()
end
