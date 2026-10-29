-- Versus on a server ("Kapløb"): one player invites the others to a door, everyone who joins
-- plays the same game (same random seed) at the same time, live scores are passed around, and
-- at the end everyone gets the ranking. Each player's result is saved by their own client as usual.
util.AddNetworkString("an_vs")

local races = {}
local nextId = 1

local function send(plys, kind, fn)
	net.Start("an_vs")
	net.WriteString(kind)
	if fn then fn() end
	net.Send(plys)
end

local function members(r)
	local t = {}
	for _, p in ipairs(r.players) do if IsValid(p) then t[#t + 1] = p end end
	r.players = t
	return t
end

local function writeList(r)
	local ps = members(r)
	net.WriteUInt(#ps, 8)
	for _, p in ipairs(ps) do
		net.WriteString(p:SteamID64() or "local")
		net.WriteString(p:Nick())
	end
end

local function lobby(r)
	send(members(r), "lobby", function()
		net.WriteUInt(r.id, 16)
		net.WriteUInt(r.n, 8)
		net.WriteString(IsValid(r.host) and r.host:SteamID64() or "")
		writeList(r)
	end)
end

local function finishCheck(r)
	if r.state ~= "run" then return end
	for _, p in ipairs(members(r)) do
		if not r.results[p] then return end
	end
	-- everyone is done: the ranking (best first; time games lower is better)
	local list = {}
	for p, res in pairs(r.results) do
		list[#list + 1] = { sid = IsValid(p) and p:SteamID64() or res.sid, name = res.name, v = res.v, quit = res.quit }
	end
	table.sort(list, function(a, b)
		if a.quit ~= b.quit then return not a.quit end
		if r.lower then return a.v < b.v end
		return a.v > b.v
	end)
	local to = {}
	for p in pairs(r.results) do if IsValid(p) then to[#to + 1] = p end end
	send(to, "result", function()
		net.WriteUInt(r.id, 16)
		net.WriteUInt(r.n, 8)
		net.WriteUInt(#list, 8)
		for _, e in ipairs(list) do
			net.WriteString(e.sid or "")
			net.WriteString(e.name or "?")
			net.WriteFloat(e.v or 0)
			net.WriteBool(e.quit and true or false)
		end
	end)
	races[r.id] = nil
end

local function leave(r, ply, quit)
	if r.state == "lobby" then
		if ply == r.host then
			send(members(r), "cancel", function() net.WriteUInt(r.id, 16) end)
			races[r.id] = nil
			return
		end
		table.RemoveByValue(r.players, ply)
		lobby(r)
	elseif not r.results[ply] then
		r.results[ply] = { name = ply:Nick(), sid = ply:SteamID64(), v = 0, quit = true }
		send(members(r), "done", function()
			net.WriteUInt(r.id, 16)
			net.WriteString(ply:SteamID64() or "")
			net.WriteFloat(0)
			net.WriteBool(true)
		end)
		finishCheck(r)
	end
end

net.Receive("an_vs", function(len, ply)
	local kind = net.ReadString()
	if kind == "invite" then
		local n = net.ReadUInt(8)
		local lower = net.ReadBool()
		-- one race at a time per player
		for _, r in pairs(races) do if table.HasValue(r.players, ply) then leave(r, ply) end end
		local r = { id = nextId, n = n, lower = lower, host = ply, players = { ply }, state = "lobby", results = {},
			seed = math.random(1, 2000000000), t = CurTime() }
		nextId = nextId % 60000 + 1
		races[r.id] = r
		local others = {}
		for _, p in ipairs(player.GetHumans()) do if p ~= ply then others[#others + 1] = p end end
		send(others, "invite", function()
			net.WriteUInt(r.id, 16)
			net.WriteUInt(n, 8)
			net.WriteString(ply:Nick())
		end)
		lobby(r)
	else
		local id = net.ReadUInt(16)
		local r = races[id]
		if not r then return end
		if kind == "join" and r.state == "lobby" then
			if not table.HasValue(r.players, ply) then r.players[#r.players + 1] = ply end
			lobby(r)
		elseif kind == "leave" then
			leave(r, ply)
		elseif kind == "start" and ply == r.host and r.state == "lobby" then
			r.state = "run"
			send(members(r), "go", function()
				net.WriteUInt(r.id, 16)
				net.WriteUInt(r.n, 8)
				net.WriteUInt(r.seed, 32)
				writeList(r)
			end)
		elseif kind == "live" and r.state == "run" then
			local text = string.sub(net.ReadString(), 1, 80)
			if (r.liveAt and r.liveAt[ply] or 0) > CurTime() - 0.3 then return end
			r.liveAt = r.liveAt or {}
			r.liveAt[ply] = CurTime()
			local to = {}
			for _, p in ipairs(members(r)) do if p ~= ply then to[#to + 1] = p end end
			send(to, "live", function()
				net.WriteUInt(r.id, 16)
				net.WriteString(ply:SteamID64() or "")
				net.WriteString(text)
			end)
		elseif kind == "done" and r.state == "run" and not r.results[ply] then
			local v = net.ReadFloat()
			r.results[ply] = { name = ply:Nick(), sid = ply:SteamID64(), v = v, quit = false }
			send(members(r), "done", function()
				net.WriteUInt(r.id, 16)
				net.WriteString(ply:SteamID64() or "")
				net.WriteFloat(v)
				net.WriteBool(false)
			end)
			finishCheck(r)
		end
	end
end)

hook.Add("PlayerDisconnected", "AN_VsLeave", function(ply)
	for _, r in pairs(races) do
		if table.HasValue(r.players, ply) then leave(r, ply, true) end
	end
end)

-- a lobby nobody starts goes away after two minutes
timer.Create("AN_VsClean", 10, 0, function()
	for id, r in pairs(races) do
		if r.state == "lobby" and CurTime() - r.t > 120 then
			send(members(r), "cancel", function() net.WriteUInt(id, 16) end)
			races[id] = nil
		end
	end
end)
