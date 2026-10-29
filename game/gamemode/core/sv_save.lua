-- Server side saving: every player's progress per Steam ID, the shared highscore lists and the
-- player profiles. Stored in the server's data folder (in single-player and on a listen server
-- that is the host's own PC):
--   data/alletidersnisse/players/<steamid64>.json   { name = ..., prog = { ... } }
--   data/alletidersnisse/highscores.json            { ["4"] = { lower = true, list = { ... } } }
--     (games with levels also have a list per level: ["1:L3"] = door 1, level 3)
AN = AN or {}
local P = AN.Prog

local DIR = "alletidersnisse"
local PDIR = DIR .. "/players"
local HSPATH = DIR .. "/highscores.json"

util.AddNetworkString("an_hello")    -- C>S: I'm ready (+ my old local save, if any)
util.AddNetworkString("an_act")      -- C>S: one progress action
util.AddNetworkString("an_prog")     -- S>C: your progress
util.AddNetworkString("an_imported") -- S>C: your old local save was taken over
util.AddNetworkString("an_hs")       -- S>C: highscore lists (all, or one door)
util.AddNetworkString("an_prof")     -- C>S: ask for a profile / S>C: the profile
util.AddNetworkString("an_players")  -- C>S: ask for the player list / S>C: the list

local function ensureDirs()
	if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
	if not file.IsDir(PDIR, "DATA") then file.CreateDir(PDIR) end
end

local function sendTable(t)
	local s = util.Compress(util.TableToJSON(t)) or ""
	net.WriteUInt(#s, 32)
	net.WriteData(s, #s)
end

local function readTable(maxLen)
	local len = net.ReadUInt(32)
	if len <= 0 or len > (maxLen or 262144) then return nil end
	local s = util.Decompress(net.ReadData(len) or "", 1048576)
	if not s then return nil end
	return util.JSONToTable(s)
end

---------------------------------------------------------------------------
-- players
---------------------------------------------------------------------------
local cache = {}   -- sid -> { name, prog }

local function validSid(sid)
	return isstring(sid) and string.match(sid, "^%d+$") ~= nil and #sid < 24
end

local function playerPath(sid) return PDIR .. "/" .. sid .. ".json" end

local function loadPlayer(sid)
	if cache[sid] then return cache[sid], true end
	local exists = file.Exists(playerPath(sid), "DATA")
	local rec
	if exists then
		rec = util.JSONToTable(file.Read(playerPath(sid), "DATA") or "")
	end
	if not istable(rec) then rec = { name = "?", prog = P.New() } end
	rec.prog = P.Fix(rec.prog)
	cache[sid] = rec
	return rec, exists
end

local function savePlayer(sid)
	local rec = cache[sid]
	if not rec then return end
	ensureDirs()
	file.Write(playerPath(sid), util.TableToJSON(rec))
end

local function sidOf(ply)
	if game.SinglePlayer() or ply:IsListenServerHost() then
		-- the host of a local game; bots and offline games still get one fixed id
		local s = ply:SteamID64()
		if not validSid(s) or s == "0" then return "local" end
		return s
	end
	local s = ply:SteamID64()
	if not validSid(s) then return "bot" end
	return s
end

local function sendProg(ply)
	local sid = sidOf(ply)
	local rec = loadPlayer(sid)
	net.Start("an_prog")
	net.WriteString(sid)
	sendTable(rec.prog)
	net.Send(ply)
end

---------------------------------------------------------------------------
-- highscores
---------------------------------------------------------------------------
local hs = nil

local function loadHS()
	if hs then return hs end
	hs = {}
	if file.Exists(HSPATH, "DATA") then
		local t = util.JSONToTable(file.Read(HSPATH, "DATA") or "")
		if istable(t) then
			for k, v in pairs(t) do
				if istable(v) and istable(v.list) then hs[tostring(k)] = v end
			end
		end
	end
	return hs
end

local function saveHS()
	ensureDirs()
	file.Write(HSPATH, util.TableToJSON(loadHS()))
end

local function sendHS(target, n)
	local all = loadHS()
	local out = {}
	if n then out[tostring(n)] = all[tostring(n)] or { list = {} } else out = all end
	net.Start("an_hs")
	net.WriteBool(n == nil)
	sendTable(out)
	if target then net.Send(target) else net.Broadcast() end
end

local function addScore(n, e, lower)
	local all = loadHS()
	local key = tostring(n)
	local door = all[key] or { list = {} }
	door.lower = lower
	P.InsertScore(door.list, e, lower)
	all[key] = door
end

---------------------------------------------------------------------------
-- messages
---------------------------------------------------------------------------
net.Receive("an_hello", function(len, ply)
	local sid = sidOf(ply)
	local legacy = net.ReadBool() and readTable() or nil
	local rec, existed = loadPlayer(sid)
	rec.name = ply:Nick()
	local local_ = game.SinglePlayer() or ply:IsListenServerHost()
	-- the progress from before saving moved to the server: only taken over on the player's own
	-- PC (single-player / their own listen server), and only if nothing is saved here yet
	if istable(legacy) and local_ and not (existed and P.HasProgress(rec.prog)) then
		local lowerOf = istable(legacy.lower) and legacy.lower or {}
		legacy.lower = nil
		rec.prog = P.Fix(legacy)
		-- their old results go on the highscore lists too
		for key, list in pairs(rec.prog.scores) do
			local n = tonumber(key)
			local lower = lowerOf[key] == true
			if n and istable(list) then
				for i, s in ipairs(list) do
					if tonumber(s.v) then
						addScore(n, { sid = sid, name = rec.name, v = tonumber(s.v), t = tonumber(s.t) or 0, h = s.h or nil, id = sid .. ":old:" .. key .. ":" .. i }, lower)
					end
				end
			end
		end
		saveHS()
		net.Start("an_imported")
		net.Send(ply)
	end
	savePlayer(sid)
	sendProg(ply)
	sendHS(ply)
end)

net.Receive("an_act", function(len, ply)
	local act = net.ReadString()
	local a = readTable(65536) or {}
	local sid = sidOf(ply)
	local rec = loadPlayer(sid)
	rec.name = ply:Nick()
	P.Apply(rec.prog, act, a)
	if (act == "result" or act == "run") and tonumber(a.n) and tonumber(a.v) then
		addScore(tonumber(a.n), {
			sid = sid, name = rec.name, v = tonumber(a.v), t = os.time(), h = a.h == true or nil,
			id = isstring(a.id) and string.sub(a.id, 1, 64) or (sid .. ":" .. os.time()),
		}, a.lower == true)
		saveHS()
		sendHS(nil, tonumber(a.n))
	end
	if act == "lvl" and tonumber(a.n) and tonumber(a.l) and tonumber(a.v) then
		local n, l, v = math.floor(tonumber(a.n)), math.floor(tonumber(a.l)), tonumber(a.v)
		if n >= 1 and n <= 24 and l >= 1 and l <= 99 and v == v and v ~= math.huge and v ~= -math.huge then
			local key = n .. ":L" .. l
			addScore(key, {
				sid = sid, name = rec.name, v = v, t = os.time(), h = a.h == true or nil,
				id = isstring(a.id) and string.sub(a.id, 1, 64) or (sid .. ":" .. os.time()),
			}, a.lower == true)
			saveHS()
			sendHS(nil, key)
		end
		return
	end
	savePlayer(sid)
	-- the client already did the same; send the result back so the two never drift apart
	sendProg(ply)
end)

-- a profile: name, progress summary, best results and the decorated tree
local function profileOf(sid)
	local rec = loadPlayer(sid)
	local d = rec.prog
	local best = {}
	for k, x in pairs(d.doors) do
		if x.done then best[k] = { v = x.best, h = x.hint, plays = x.plays } end
	end
	local online = false
	for _, p in ipairs(player.GetAll()) do
		if sidOf(p) == sid then online = true end
	end
	return {
		sid = sid, name = rec.name, online = online,
		done = P.DoneCount(d), coins = d.coins, owned = P.OwnedCount(d),
		next = P.NextReward(d).id, best = best, tree = d.tree,
	}
end

net.Receive("an_prof", function(len, ply)
	local sid = net.ReadString()
	if sid ~= "local" and not validSid(sid) then return end
	if not file.Exists(playerPath(sid), "DATA") and not cache[sid] then return end
	net.Start("an_prof")
	sendTable(profileOf(sid))
	net.Send(ply)
end)

net.Receive("an_players", function(len, ply)
	local out, seen = {}, {}
	for _, p in ipairs(player.GetAll()) do
		local sid = sidOf(p)
		if not seen[sid] then
			seen[sid] = true
			local rec = loadPlayer(sid)
			out[#out + 1] = { sid = sid, name = p:Nick(), online = true, done = P.DoneCount(rec.prog) }
		end
	end
	local files = file.Find(PDIR .. "/*.json", "DATA") or {}
	for _, f in ipairs(files) do
		local sid = string.StripExtension(f)
		if not seen[sid] and #out < 200 then
			seen[sid] = true
			local rec = loadPlayer(sid)
			out[#out + 1] = { sid = sid, name = rec.name, online = false, done = P.DoneCount(rec.prog) }
		end
	end
	net.Start("an_players")
	sendTable(out)
	net.Send(ply)
end)

-- keep the remembered name up to date, and free the cache of players who left
hook.Add("PlayerDisconnected", "an_save", function(ply)
	local sid = sidOf(ply)
	savePlayer(sid)
end)
