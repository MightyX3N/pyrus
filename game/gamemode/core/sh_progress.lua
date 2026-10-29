-- A player's progress (doors, pebernødder, ornaments, tree) and the rules that change it.
-- Shared: the server keeps the real copy per Steam ID and saves it; the client keeps a mirror
-- and applies the same rules at once, so the game never waits for the server.
AN = AN or {}
AN.Prog = AN.Prog or {}
local P = AN.Prog

-- The 25 ornaments of the original, in the original order, with the original prices
-- (price = how many pebernødder you must collect before you get one).
AN.Ornaments = {}
local ORN = {
	{ "flag0", 10 }, { "flag1", 10 }, { "kraemmerhus0", 15 }, { "kraemmerhus1", 15 }, { "kraemmerhus2", 15 },
	{ "hjerte0", 15 }, { "hjerte1", 15 }, { "tromme0", 20 }, { "tromme1", 20 }, { "stok0", 20 }, { "stok1", 20 },
	{ "kugle1", 20 }, { "kugle4", 20 }, { "kugle5", 20 }, { "kugle11", 20 }, { "kugle2", 25 }, { "kugle3", 25 },
	{ "kugle6", 25 }, { "kugle7", 25 }, { "kugle8", 25 }, { "kugle0", 25 }, { "kugle9", 25 }, { "kugle10", 25 },
	{ "lys0", 30 }, { "star0", 40 },
}
AN.OrnamentById = {}
for i, o in ipairs(ORN) do
	local def = { index = i - 1, id = o[1], price = o[2], img = "wrap/orn_" .. o[1] .. ".png" }
	AN.Ornaments[i] = def
	AN.OrnamentById[o[1]] = def
end
-- the fixed order the original hands out ornaments in (0-based ornament indexes)
AN.RewardOrder = { 0, 1, 4, 5, 4, 2, 3, 6, 5, 4, 1, 1, 3, 7, 6, 8, 1, 8, 5, 4, 2, 9, 0, 4, 4, 7, 10, 8, 9, 12, 9, 3, 0, 0, 10, 11, 12, 14, 10, 15, 16, 13, 14, 1, 17, 11, 18, 6, 23, 0, 2, 19, 16, 17, 23, 20, 21, 22, 23, 13, 15, 19, 18, 22, 23, 23, 21, 23, 23, 20, 23, 23, 7, 23, 24 }

P.MAX_SCORES = 10

function P.New()
	return {
		v = 3,
		coins = 0,        -- pebernødder collected towards the next ornament
		rewardIndex = 0,  -- position in AN.RewardOrder (-1 = "random" from now on)
		randCount = 0,    -- ornaments handed out after the fixed order ran out
		doors = {},       -- ["4"] = { done = true, best = 41.2, plays = 3, hint = true }
		scores = {},      -- ["4"] = { { v = 41.2, t = os.time(), h = true }, ... } your own, best first
		inv = {},         -- { kugle4 = 2, ... }
		opened = {},      -- ["4"] = true: calendar doors you have opened
		tree = {},        -- { { id = "kugle4", x = 300, y = 500 }, ... } hanging point in tree-frame coords
	}
end

-- make a table read from JSON safe to use (number keys back to strings, missing fields)
function P.Fix(d)
	if not istable(d) then return P.New() end
	local base = P.New()
	for k, v in pairs(base) do
		if d[k] == nil then d[k] = v end
	end
	for _, field in ipairs({ "doors", "scores", "opened" }) do
		local fixed = {}
		for k, v in pairs(istable(d[field]) and d[field] or {}) do fixed[tostring(k)] = v end
		d[field] = fixed
	end
	-- the tree is a list
	local tree = {}
	for _, o in pairs(istable(d.tree) and d.tree or {}) do
		if istable(o) and AN.OrnamentById[o.id] then tree[#tree + 1] = { id = o.id, x = tonumber(o.x) or 0, y = tonumber(o.y) or 0 } end
	end
	d.tree = tree
	return d
end

-- has anything been played / collected at all?
function P.HasProgress(d)
	return istable(d) and (next(d.doors or {}) ~= nil or (d.coins or 0) > 0 or next(d.inv or {}) ~= nil or #(d.tree or {}) > 0)
end

function P.DoneCount(d)
	local c = 0
	for i = 1, 24 do
		local x = d.doors[tostring(i)]
		if x and x.done then c = c + 1 end
	end
	return c
end

function P.OwnedCount(d)
	local c = #d.tree
	for _, v in pairs(d.inv) do c = c + v end
	return c
end

local function better(a, b, lower)
	if lower then return a < b end
	return a > b
end

-- a finished game. returns isRecord (your own best)
local function dropId(list, id)
	if not id then return end
	for i = #list, 1, -1 do
		if list[i].id == id then table.remove(list, i) end
	end
end

-- a game with levels saves its running score after every level, so the levels already done count
-- even if the game is left or the player drops out. The run's entry is replaced by every later save
-- and by the final result.
function P.RunProgress(d, n, value, lower, hint, t, id)
	local key = tostring(n)
	local x = d.doors[key] or { plays = 0 }
	x.done = true
	if x.bestId == id then
		x.best, x.hint = value, hint or nil
	elseif x.best == nil or better(value, x.best, lower) then
		-- remember the best from before this run, so the final result can still count as a record
		x.prevBest, x.prevHint, x.bestId = x.best, x.hint, id
		x.best, x.hint = value, hint or nil
	end
	d.doors[key] = x
	local list = d.scores[key] or {}
	dropId(list, id)
	list[#list + 1] = { v = value, t = t or os.time(), h = hint or nil, id = id }
	table.sort(list, function(a, b) return better(a.v, b.v, lower) end)
	while #list > P.MAX_SCORES do table.remove(list) end
	d.scores[key] = list
end

function P.RecordResult(d, n, value, lower, hint, t, id)
	local key = tostring(n)
	local x = d.doors[key] or { plays = 0 }
	if id and x.bestId == id then
		x.best, x.hint = x.prevBest, x.prevHint
	end
	x.bestId, x.prevBest, x.prevHint = nil, nil, nil
	x.done = true
	x.plays = (x.plays or 0) + 1
	local isRecord = x.best == nil or better(value, x.best, lower)
	if isRecord then
		x.best = value
		x.hint = hint or nil
	end
	d.doors[key] = x
	local list = d.scores[key] or {}
	dropId(list, id)
	list[#list + 1] = { v = value, t = t or os.time(), h = hint or nil, id = id }
	table.sort(list, function(a, b) return better(a.v, b.v, lower) end)
	while #list > P.MAX_SCORES do table.remove(list) end
	d.scores[key] = list
	return isRecord
end

-- the ornament you are saving up for
function P.NextReward(d)
	local idx
	if (d.rewardIndex or 0) >= 0 then
		idx = AN.RewardOrder[(d.rewardIndex or 0) + 1]
	else
		-- the original picks at random once the fixed order has run out; here it is a fixed
		-- shuffle so the server and the player's screen agree on it
		local c = d.randCount or 0
		idx = AN.RewardOrder[(c * 37 + 11) % (#AN.RewardOrder - 1) + 1]
	end
	return AN.Ornaments[idx + 1]
end

-- the original reward: add pebernødder; when you have enough you get the next ornament.
-- returns { won, oldCoins, price, item (or nil), newPrice, coins }
function P.GiveCoins(d, won)
	won = math.Clamp(math.floor(tonumber(won) or 0), 0, 10)
	local res = { won = won, oldCoins = d.coins, price = P.NextReward(d).price }
	d.coins = d.coins + won
	local item = P.NextReward(d)
	if d.coins >= item.price then
		d.inv[item.id] = (d.inv[item.id] or 0) + 1
		d.coins = d.coins - item.price
		res.item = item
		if (d.rewardIndex or 0) >= 0 then
			d.rewardIndex = (d.rewardIndex or 0) + 1
			if d.rewardIndex >= #AN.RewardOrder then d.rewardIndex = -1 end
		else
			d.randCount = (d.randCount or 0) + 1
		end
	end
	res.newPrice = P.NextReward(d).price
	res.coins = d.coins
	return res
end

function P.SetOpened(d, n, open)
	n = tonumber(n)
	if not n or n < 1 or n > 24 then return end
	d.opened[tostring(n)] = (open ~= false) or nil
end

function P.PlaceOrnament(d, id, x, y)
	if (d.inv[id] or 0) <= 0 then return false end
	d.inv[id] = d.inv[id] - 1
	if d.inv[id] <= 0 then d.inv[id] = nil end
	d.tree[#d.tree + 1] = { id = id, x = tonumber(x) or 0, y = tonumber(y) or 0 }
	return true
end

function P.MoveOrnament(d, i, x, y)
	local o = d.tree[tonumber(i) or 0]
	if not o then return end
	o.x, o.y = tonumber(x) or o.x, tonumber(y) or o.y
end

function P.RemoveOrnament(d, i)
	i = tonumber(i) or 0
	local o = d.tree[i]
	if not o then return end
	table.remove(d.tree, i)
	d.inv[o.id] = (d.inv[o.id] or 0) + 1
end

-- apply one action (the client does it at once, the server does the same and saves it)
-- a result key: a calendar door (1-24) or a season game's list (game * 10 + difficulty, 1010-2999)
function P.ValidN(n) return n and ((n >= 1 and n <= 24) or (n >= 1010 and n <= 2999)) end

function P.Apply(d, act, a)
	a = a or {}
	if act == "result" then
		local n = tonumber(a.n)
		local v = tonumber(a.v)
		if not P.ValidN(n) or not v or v ~= v or v == math.huge or v == -math.huge then return end
		local rec = P.RecordResult(d, n, v, a.lower == true, a.h == true, tonumber(a.t), isstring(a.id) and a.id or nil)
		if n > 24 then return rec, { won = 0, coins = d.coins } end
		local res = P.GiveCoins(d, a.won)
		return rec, res
	elseif act == "run" then
		local n = tonumber(a.n)
		local v = tonumber(a.v)
		if not P.ValidN(n) or not v or v ~= v or v == math.huge or v == -math.huge or not isstring(a.id) then return end
		P.RunProgress(d, n, v, a.lower == true, a.h == true, tonumber(a.t), a.id)
	elseif act == "open" then
		P.SetOpened(d, a.n, a.open)
	elseif act == "place" then
		return P.PlaceOrnament(d, a.id, a.x, a.y)
	elseif act == "move" then
		P.MoveOrnament(d, a.i, a.x, a.y)
	elseif act == "remove" then
		P.RemoveOrnament(d, a.i)
	elseif act == "reset" then
		local fresh = P.New()
		for k in pairs(d) do d[k] = nil end
		for k, v in pairs(fresh) do d[k] = v end
	end
end

---------------------------------------------------------------------------
-- The shared highscore lists (one per game, everyone on the server)
---------------------------------------------------------------------------
P.HS_MAX = 10

-- entry = { sid = steamid64, name = nick, v = value, t = time, h = hint used, id = unique id }
function P.InsertScore(list, e, lower)
	if e.id then
		for i = #list, 1, -1 do
			if list[i].id == e.id then table.remove(list, i) end
		end
	end
	list[#list + 1] = e
	table.sort(list, function(a, b)
		if a.v == b.v then return (a.t or 0) < (b.t or 0) end
		return better(a.v, b.v, lower)
	end)
	while #list > P.HS_MAX do table.remove(list) end
	return list
end
