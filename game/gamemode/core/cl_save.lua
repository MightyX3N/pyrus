-- Saving, client side.
--  * Settings (language, volume, look ...) are personal: data/alletidersnisse/save.json on the
--    player's own PC.
--  * Progress (doors, pebernødder, ornaments, the tree) and the highscore lists are kept by the
--    server per Steam ID (core/sv_save.lua). The client keeps a mirror and applies the same rules
--    at once (core/sh_progress.lua), and the server sends its copy back after every change.
--  * A save from before progress moved to the server is handed over the first time the player
--    joins their own game (single-player or a listen server they host).
AN = AN or {}
AN.Save = AN.Save or {}
local Save = AN.Save
local P = AN.Prog

local PATH_DIR = "alletidersnisse"
local PATH = PATH_DIR .. "/save.json"

-- ornament drawn with its hanging point at (x, y). sc = size scale (1 = original size)
function AN.DrawOrnament(id, x, y, sc, alpha)
	local def = AN.OrnamentById[id]
	if not def then return end
	local r = AN.WrapPos["orn_" .. id]
	AN.Img(def.img, x + r[1] * sc, y + r[2] * sc, r[3] * sc, r[4] * sc, alpha)
end
function AN.OrnamentRect(id, sc)
	local r = AN.WrapPos["orn_" .. id]
	return r[1] * sc, r[2] * sc, r[3] * sc, r[4] * sc
end
AN.ORN_TREE_SCALE = 3.0   -- ornament size on the big tree (tree frame units)

local function defaultSettings()
	return {
		lang = "da", look = "modern", doorRule = "date", hidden = true, subs = true,
		vol_music = 70, vol_fx = 85, vol_voice = 100,
		blur = true, vs = "race", share = true, soundmode = 0, firsttime = true,
	}
end

local localFile = { settings = defaultSettings() }   -- what is in save.json
local prog = P.New()                                  -- the mirror of the server's copy
local hs = {}                                         -- ["4"] = { lower = true, list = { ... } }
Save.synced = false

local function legacyOf(t)
	-- the progress part of an old save.json (before saving moved to the server)
	if not istable(t) or t.migrated then return nil end
	local d = { coins = t.coins, rewardIndex = t.rewardIndex, doors = t.doors, scores = t.scores, inv = t.inv, opened = t.opened, tree = t.tree }
	-- the first test version used made-up ornament names
	if (t.v or 1) < 2 then
		local map = { red = "kugle4", green = "kugle5", blue = "kugle1", purple = "kugle11", heart = "hjerte0", cane = "stok0",
			drum = "tromme0", flag = "flag0", silver = "kugle9", gold = "kugle10", star = "star0" }
		local inv = {}
		for k, v in pairs(d.inv or {}) do if map[k] then inv[map[k]] = (inv[map[k]] or 0) + v end end
		d.inv = inv
		for _, o in ipairs(d.tree or {}) do o.id = map[o.id] or o.id end
	end
	d = P.Fix(d)
	if not P.HasProgress(d) then return nil end
	return d
end

function Save.Load()
	localFile = { settings = defaultSettings() }
	if file.Exists(PATH, "DATA") then
		local t = util.JSONToTable(file.Read(PATH, "DATA") or "")
		if istable(t) then
			for k, v in pairs(t) do
				if k == "settings" and istable(v) then
					for sk, sv in pairs(v) do localFile.settings[sk] = sv end
				else
					localFile[k] = v
				end
			end
		end
	end
	prog = P.New()
	Save.Hello()
end

function Save.Write()
	if not file.IsDir(PATH_DIR, "DATA") then file.CreateDir(PATH_DIR) end
	file.Write(PATH, util.TableToJSON(localFile, true))
end

---------------------------------------------------------------------------
-- talking to the server
---------------------------------------------------------------------------
local function sendTable(t)
	local s = util.Compress(util.TableToJSON(t)) or ""
	net.WriteUInt(#s, 32)
	net.WriteData(s, #s)
end

local function readTable()
	local len = net.ReadUInt(32)
	if len <= 0 then return nil end
	local s = util.Decompress(net.ReadData(len) or "")
	if not s then return nil end
	return util.JSONToTable(s)
end

function Save.Hello()
	local legacy = legacyOf(localFile)
	if legacy then
		-- which doors count time (lower is better), for sorting the old results
		legacy.lower = {}
		for n = 1, 24 do
			if AN.Games and AN.Games[n] and AN.Games[n].scoreType == "time" then legacy.lower[tostring(n)] = true end
		end
	end
	net.Start("an_hello")
	net.WriteBool(legacy ~= nil)
	if legacy then sendTable(legacy) end
	net.SendToServer()
end

local function send(act, a)
	net.Start("an_act")
	net.WriteString(act)
	sendTable(a or {})
	net.SendToServer()
end

net.Receive("an_prog", function()
	Save.sid = net.ReadString()
	local t = readTable()
	if istable(t) then
		prog = P.Fix(t)
		Save.synced = true
	end
end)

net.Receive("an_imported", function()
	-- the old progress now lives on the server; keep only the settings here
	localFile = { settings = localFile.settings, migrated = true }
	Save.Write()
end)

net.Receive("an_hs", function()
	local all = net.ReadBool()
	local t = readTable() or {}
	if all then hs = {} end
	for k, v in pairs(t) do
		if istable(v) then
			v.list = istable(v.list) and v.list or {}
			hs[tostring(k)] = v
		end
	end
end)

-- profiles and the player list (answers arrive later; screens read them from AN.Profiles)
AN.Profiles = AN.Profiles or {}
AN.PlayerList = AN.PlayerList or nil
function Save.RequestProfile(sid)
	net.Start("an_prof")
	net.WriteString(sid)
	net.SendToServer()
end
function Save.RequestPlayers()
	net.Start("an_players")
	net.SendToServer()
end
net.Receive("an_prof", function()
	local t = readTable()
	if istable(t) and t.sid then
		t.tree = istable(t.tree) and t.tree or {}
		local best = {}
		for k, v in pairs(istable(t.best) and t.best or {}) do best[tostring(k)] = v end
		t.best = best
		t.got = RealTime()
		AN.Profiles[t.sid] = t
	end
end)
net.Receive("an_players", function()
	local t = readTable()
	if istable(t) then AN.PlayerList = t end
end)

-- my own id on the server's lists (the host of a local game may be "local")
function Save.MySid()
	return Save.sid or (IsValid(LocalPlayer()) and LocalPlayer():SteamID64()) or "local"
end

---------------------------------------------------------------------------
-- the API the screens use
---------------------------------------------------------------------------
function Save.Data() return localFile end

-- settings
function Save.Get(key) return localFile.settings[key] end
function Save.Set(key, value)
	localFile.settings[key] = value
	Save.Write()
end

-- start over (your own progress on this server)
function Save.Reset()
	P.Apply(prog, "reset")
	send("reset")
end

function Save.Coins() return prog.coins end

function Save.Door(n) return prog.doors[tostring(n)] end
function Save.DoorDone(n)
	local d = prog.doors[tostring(n)]
	return d and d.done or false
end
function Save.DoneCount() return P.DoneCount(prog) end

-- a finished game: your progress and the shared highscore list. returns isRecord, reward, entry id
function Save.NewId()
	return Save.MySid() .. ":" .. os.time() .. ":" .. math.random(100000, 999999)
end

function Save.Finish(n, value, lower, won, hint, runId)
	local id = runId or Save.NewId()
	local a = { n = n, v = value, lower = lower, won = won, h = hint or nil, id = id, t = os.time() }
	local isRecord, res = P.Apply(prog, "result", a)
	-- shown at once on our own list; the server's list replaces it a moment later
	local key = tostring(n)
	hs[key] = hs[key] or { lower = lower, list = {} }
	local name = IsValid(LocalPlayer()) and LocalPlayer():Nick() or "?"
	P.InsertScore(hs[key].list, { sid = Save.MySid(), name = name, v = value, t = os.time(), h = hint or nil, id = id }, lower)
	send("result", a)
	return isRecord, res, id
end

function Save.Opened(n) return prog.opened[tostring(n)] == true end
function Save.SetOpened(n, open)
	P.SetOpened(prog, n, open)
	send("open", { n = n, open = open ~= false })
end

-- the shared highscore list for a game (everyone on this server); with a level: that level's list
local function hsKey(n, l)
	if l and l > 0 then return n .. ":L" .. l end
	return tostring(n)
end
function Save.Scores(n, level)
	local d = hs[hsKey(n, level)]
	return d and d.list or {}
end

-- the running score of a game with levels, saved after every level (replaced by later saves and by
-- the final result with the same id)
function Save.RunProgress(n, value, lower, hint, id)
	local a = { n = n, v = value, lower = lower, h = hint or nil, id = id, t = os.time() }
	P.Apply(prog, "run", a)
	local key = tostring(n)
	hs[key] = hs[key] or { lower = lower, list = {} }
	local name = IsValid(LocalPlayer()) and LocalPlayer():Nick() or "?"
	P.InsertScore(hs[key].list, { sid = Save.MySid(), name = name, v = value, t = os.time(), h = hint or nil, id = id }, lower)
	send("run", a)
end

-- a finished level of a game with levels: its score goes on that level's own list
function Save.LevelScore(n, level, value, lower, hint)
	local id = Save.MySid() .. ":" .. os.time() .. ":" .. math.random(100000, 999999)
	local key = hsKey(n, level)
	hs[key] = hs[key] or { lower = lower, list = {} }
	local name = IsValid(LocalPlayer()) and LocalPlayer():Nick() or "?"
	P.InsertScore(hs[key].list, { sid = Save.MySid(), name = name, v = value, t = os.time(), h = hint or nil, id = id }, lower)
	send("lvl", { n = n, l = level, v = value, lower = lower, h = hint or nil, id = id })
	return id
end

-- how many level tabs a game's lists have: the levels the game has, and any level with results
function Save.LevelCount(n)
	local c = AN.Games and AN.Games[n] and AN.Games[n].levels or 0
	local pre = tostring(n) .. ":L"
	for k, d in pairs(hs) do
		if string.sub(k, 1, #pre) == pre and #(d.list or {}) > 0 then
			local l = tonumber(string.sub(k, #pre + 1))
			if l and l > c then c = l end
		end
	end
	return c
end

-- your own results for a game
function Save.MyScores(n) return prog.scores[tostring(n)] or {} end

-- inventory / tree
function Save.Inv() return prog.inv end
function Save.InvCount()
	local c = 0
	for _, v in pairs(prog.inv) do c = c + v end
	return c
end
function Save.OwnedCount() return P.OwnedCount(prog) end
function Save.NextReward() return P.NextReward(prog) end
function Save.Tree() return prog.tree end

function Save.PlaceOrnament(id, x, y)
	if not P.PlaceOrnament(prog, id, x, y) then return false end
	send("place", { id = id, x = x, y = y })
	return true
end

function Save.MoveOrnament(i, x, y)
	P.MoveOrnament(prog, i, x, y)
	send("move", { i = i, x = x, y = y })
end

function Save.RemoveOrnament(i)
	P.RemoveOrnament(prog, i)
	send("remove", { i = i })
end
