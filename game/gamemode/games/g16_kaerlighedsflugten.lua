-- Låge 16: Kærlighedsflugten
-- Rebuilt from the original loader.swf: a Pac-Man in Rigsarkivet. Bertramsen eats all the
-- pebernødder while four ladies chase him; a garlic makes them scared for a while so he can catch
-- them (200, 400, 800, 1600). A bonus thing shows up under the ladies' room now and then. 3 lives.
-- The game code is the original's (the same engine as door 9), quirks included:
--   * only one of the ladies really hunts (along the shortest way between the crossings); one of
--     the others sometimes turns back, the rest go at random
--   * a lady sent home goes into "back in the room" mode as soon as she reaches the room's column
--     anywhere in the maze (the check tests the column twice and never the row)
--   * the lives counter shows one less than you have
-- Hidden content: the game's own background loops (normal, scared, going home) and intro
-- jingles, which are in the file but never played.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g16_fl.lua")

local G = {
	scoreType = "score",
	goal = 5000,      -- the original coolScore
	worst = 0,
	descKey = "desc_16",
	howKey = "how_16",
}

local STAGE_W, STAGE_H = 467, 600
local STEP = 1 / 25
local LIB = "g16"
local I = { 1, 0, 0, 1, 0, 0 }
local NBX, NBY = 28, 31
local GHOST_CID = { [0] = 273, 259, 243, 229 }

local CUR

---------------------------------------------------------------------------
-- the maze (fillGrid): 0 = way without a dot, 2 = dot, 3 = big dot; everything else is wall
---------------------------------------------------------------------------
local MAZE = {
	[1] = "1-12:2 15-26:2", [2] = "1 6 12 15 21 26:2", [3] = "6 12 15 21:2 1 26:3", [4] = "1 6 12 15 21 26:2",
	[5] = "1-26:2", [6] = "1 6 9 18 21 26:2", [7] = "1 6 9 18 21 26:2",
	[8] = "1-6:2 9-12:2 15-18:2 21-26:2", [9] = "6 21:2 12 15:0", [10] = "6 21:2 12 15:0",
	[11] = "6 21:2 9-18:0", [12] = "6 21:2 9 18:0", [13] = "6 21:2 9 18:0",
	[14] = "0-5:0 6:2 7-9:0 18-20:0 21:2 22-27:0", [15] = "6 21:2 9 18:0", [16] = "6 21:2 9 18:0",
	[17] = "6 21:2 9-18:0", [18] = "6 21:2 9 18:0", [19] = "6 21:2 9 18:0",
	[20] = "1-12:2 15-26:2", [21] = "1 6 12 15 21 26:2", [22] = "1 6 12 15 21 26:2",
	[23] = "2 3 6-12:2 15-21:2 24 25:2 13 14:0 1 26:3", [24] = "3 6 9 18 21 24:2", [25] = "3 6 9 18 21 24:2",
	[26] = "1-6:2 9-12:2 15-18:2 21-26:2", [27] = "1 12 15 26:2", [28] = "1 12 15 26:2", [29] = "1-26:2",
}

local function parseMaze()
	local t = {}
	for y, spec in pairs(MAZE) do
		-- groups like "1 6 12:2" (cells, then the type after the colon)
		for group in string.gmatch(spec, "[%d%- ]+:%d") do
			local cells, tp = string.match(group, "([%d%- ]+):(%d)")
			for c in string.gmatch(cells, "[%d%-]+") do
				local a, b = string.match(c, "(%d+)%-(%d+)")
				a, b = tonumber(a or c), tonumber(b or c)
				for x = a, b do t[x .. "_" .. y] = tonumber(tp) end
			end
		end
	end
	return t
end

-- Number(x) on a path step: "" counts as 0, nothing as NaN (no move)
local function num(v)
	if v == nil then return nil end
	if v == "" then return 0 end
	return tonumber(v)
end

local function split(path)
	local t = {}
	for part in string.gmatch(path .. "_", "([^_]*)_") do t[#t + 1] = part end
	-- "a_b_".split("_") -> { "a", "b", "" }
	return t
end

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.LoadHidden[LIB] = { [206] = true, [306] = true, [298] = true }   -- hit areas, grid marks, preloader
	for _, cid in ipairs({ 141, 17, 46, 57, 62, 67, 194, 207, 229, 243, 259, 273, 291, 316, 320, 328, 333 }) do
		FL.SetActions(LIB, cid, { [1] = stop })
	end
	FL.SetActions(LIB, 284, { [30] = function(c) stop(c) if CUR then CUR:HeroDieAniDone() end end })
	FL.SetActions(LIB, 296, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	FL.SetActions(LIB, 316, { [1] = stop, [56] = function() if CUR then CUR:StartLevel(CUR.level + 1) end end })
	FL.SetActions(LIB, 320, { [1] = stop, [56] = function() if CUR then CUR:LevelIntroPlayed() end end })
	FL.SetActions(LIB, 328, { [1] = stop, [62] = function() if CUR then CUR:LevelIntroPlayed() end end })
	FL.SetActions(LIB, 342, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndStop(c, "gameon") end,
		[9] = stop,
		[17] = function(c) AN.Speak("GameOverIngenLiv") end,
		[91] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Clip(name) return FL.Child(self:Game(), name) end

local function itemPos(parent, name)
	local m = FL.ChildMatrix(parent, name, I)
	return m and m[5] or 0, m and m[6] or 0
end

local function vec(x, y) return { x = x or 0, y = y or 0 } end

function G:Attach(cid, depth, x, y, sx, sy)
	local e = { c = FL.New(LIB, cid), m = { sx or 1, 0, 0, sy or sx or 1, x or 0, y or 0 }, depth = depth }
	self.arenaStuff[#self.arenaStuff + 1] = e
	return e
end

function G:Detach(e)
	for i = #self.arenaStuff, 1, -1 do if self.arenaStuff[i] == e then table.remove(self.arenaStuff, i) end end
end

local function anim(o) return FL.Child(o.mc, "anim") end
local function animTo(o, label) local a = anim(o) if a then FL.GotoAndStop(a, label) end end
local function dirTo(o) if o.dir ~= nil then FL.GotoAndStop(o.mc, "dir" .. o.dir) end end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	local arena = self:Clip("arena")
	local ux, uy = itemPos(arena, "grid_upleft")
	local dx, dy = itemPos(arena, "grid_downright")
	self.gridUL, self.gridDR = vec(ux, uy), vec(dx, dy)
	self.notSoScaredTime = 100
	self.fruitTime = 200
	self.fruitSpawnTime = 250
	self.defaultSpeed = (dx - ux) / 110
	self.levelSpeedIncrement = 0.05
	self.maxSpeed = 9.5
	self.nbFruits = 3
	self.ghostScoreMultiplier = 0
	self.points = {}
	self.nextPoint = 1
	self.ISON = false
	self:CreateGrid()
	self:CreateHero()
	self:CreateGhosts()
	self.gameState = 0
	self:StartNewGame()
end

function G:CreateGrid()
	local gs = vec((self.gridDR.x - self.gridUL.x) / NBX, (self.gridDR.y - self.gridUL.y) / NBY)
	self.gridSize = gs
	local off = vec(self.gridUL.x + gs.x / 2, self.gridUL.y + gs.y / 2)
	local types = parseMaze()
	local grid = {}
	for gx = 0, NBX - 1 do
		grid[gx] = {}
		for gy = 0, NBY - 1 do
			grid[gx][gy] = {
				id = vec(gx, gy), pos = vec(off.x + gx * gs.x, off.y + gy * gs.y), type = types[gx .. "_" .. gy] or 1,
				moves = { [0] = false, false, false, false }, destForkRoads = { [0] = false, false, false, false },
				forkRoad = false, state = -1,
			}
		end
	end
	self.grid = grid
	self.ghostExit = grid[13][11]
	self.fruitSpot = grid[13][17]
	self:CreateGridStuff()
end

function G:CreateGridStuff()
	local grid, gs = self.grid, self.gridSize
	self.nbFood = 0
	self.forkRoads = {}
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = grid[gx][gy]
			local n = 0
			if grid[gx][(gy - 1) % NBY].type ~= 1 then g.moves[0] = true n = n + 1 end
			if grid[(gx + 1) % NBX][gy].type ~= 1 then g.moves[1] = true n = n + 1 end
			if grid[gx][(gy + 1) % NBY].type ~= 1 then g.moves[2] = true n = n + 1 end
			if grid[(gx - 1) % NBX][gy].type ~= 1 then g.moves[3] = true n = n + 1 end
			if g.type ~= 1 and n > 2 then
				local f = { id = #self.forkRoads, gridPos = g, destinations = { [0] = false, false, false, false },
					roads = { [0] = false, false, false, false }, roadSteps = { [0] = false, false, false, false } }
				self.forkRoads[#self.forkRoads + 1] = f
				g.forkRoad = f
			end
			if g.type == 2 or g.type == 3 then
				self.nbFood = self.nbFood + 1
				local e = self:Attach(194, 1000 + gx + gy * NBX, g.pos.x, g.pos.y, gs.x / 100, gs.y / 100)
				FL.GotoAndStop(e.c, g.type - 1)
				e.c.visible = false
				g.mc = e.c
			end
		end
	end
	self:CreateForkRoads()
end

local function step(x, y, d)
	if d == 0 then y = (y - 1) % NBY
	elseif d == 1 then x = (x + 1) % NBX
	elseif d == 2 then y = (y + 1) % NBY
	elseif d == 3 then x = (x - 1) % NBX end
	return x, y
end

function G:CreateForkRoads()
	local grid = self.grid
	for _, f in ipairs(self.forkRoads) do
		for d = 0, 3 do
			if f.gridPos.moves[d] == true then
				local road, steps = "", 0
				local cur = f.gridPos
				local curDir = d
				for _ = 1, 2000 do
					local nx, ny = step(cur.id.x, cur.id.y, curDir)
					cur = grid[nx][ny]
					local fromDir = (curDir + 2) % 4
					road = road .. curDir .. "_"
					steps = steps + 1
					cur.destForkRoads[fromDir] = f
					if cur.forkRoad ~= false then
						f.destinations[d] = cur.forkRoad
						f.roads[d] = road
						f.roadSteps[d] = steps
						break
					end
					local right, left = (curDir + 1) % 4, (curDir + 3) % 4
					if cur.moves[curDir] ~= true then
						if cur.moves[right] == true then curDir = right
						elseif cur.moves[left] == true then curDir = left
						else break end
					end
				end
			end
		end
	end
end

-- the shortest way on the grid (breadth first; a square is marked when it has been looked at)
function G:GetPath(from, to, restrictedDir)
	local grid = self.grid
	local checked = {}
	local list = { { x = from.id.x, y = from.id.y, path = "", noGo = restrictedDir } }
	local i = 1
	while list[i] do
		local p = list[i]
		if p.x == to.id.x and p.y == to.id.y then return split(p.path) end
		for d = 0, 3 do
			if d ~= p.noGo and grid[p.x][p.y].moves[d] == true then
				local nx, ny = step(p.x, p.y, d)
				if not checked[nx * 100 + ny] then
					list[#list + 1] = { x = nx, y = ny, path = p.path .. d .. "_", noGo = (d + 2) % 4 }
				end
			end
		end
		checked[p.x * 100 + p.y] = true
		i = i + 1
		if i > 200000 then break end
	end
	return {}
end

-- the shortest way between two crossings, along the roads between them
function G:GetPathForkRoad(from, to, restrictedDir)
	local result = {}
	if not from then return result end
	local checked = {}
	local list = { { forkRoad = from, path = "", noGo = restrictedDir, steps = 0 } }
	local minSteps = 99999
	local i = 1
	while list[i] do
		local p = list[i]
		local f = p.forkRoad
		if f == to then
			if p.steps < minSteps then
				minSteps = p.steps
				result = split(p.path)
			end
		else
			for d = 0, 3 do
				local dest = f.destinations[d]
				if d ~= p.noGo and dest ~= false then
					if checked[dest.id] ~= true or dest == to then
						if p.steps < minSteps then
							list[#list + 1] = { forkRoad = dest, path = p.path .. f.roads[d], noGo = -1, steps = p.steps + f.roadSteps[d] }
						end
					end
				end
			end
		end
		checked[f.id] = true
		i = i + 1
		if i > 200000 then break end
	end
	return result
end

function G:CreateHero()
	local e = self:Attach(291, 2000)
	local h = {
		mc = e.c, entry = e, startPos = vec(), pos = vec(), vel = vec(), dir = -1, wannaGo = -1, speed = 0,
		normalSpeed = 0, scareSpeed = 0, speedFactor = 1, nextForkRoad = false, state = 0, isHero = true,
	}
	h.startGridRef = self.grid[13][23]
	h.startPos.x = h.startGridRef.pos.x + self.gridSize.x / 2
	h.startPos.y = h.startGridRef.pos.y
	h.startDir = 3
	self.hero = h
end

function G:CreateGhosts()
	local defs = {
		[0] = { x = 13, y = 13, dir = 0, home = 0, sf = 0.9 },
		[1] = { x = 13, y = 14, dir = 0, home = 25, sf = 1.1 },
		[2] = { x = 11, y = 14, dir = 1, home = 50, sf = 1 },
		[3] = { x = 15, y = 14, dir = 3, home = 75, sf = 1 },
	}
	self.ghosts = {}
	for g = 0, 3 do
		local d = defs[g]
		local e = self:Attach(GHOST_CID[g], 3000 + 10 - g)
		local gh = {
			id = g, mc = e.c, entry = e, startPos = vec(), pos = vec(), vel = vec(), exitPos = vec(), dir = -1, wannaGo = -1,
			homeTime = d.home, homeCount = 0, scaredTime = 200, scaredCount = 0, speed = 0, speedFactor = d.sf, state = 0,
			ai = { path = {} }, startDir = d.dir,
		}
		gh.startGridRef = self.grid[d.x][d.y]
		gh.startPos.x = gh.startGridRef.pos.x + self.gridSize.x / 2
		gh.startPos.y = gh.startGridRef.pos.y
		gh.exitPos.x = self.ghostExit.pos.x + self.gridSize.x / 2
		gh.exitPos.y = self.ghostExit.pos.y
		self.ghosts[g + 1] = gh
	end
end

function G:SetVel(o)
	o.vel.x, o.vel.y = 0, 0
	if o.dir == 0 then o.vel.y = -o.speed
	elseif o.dir == 1 then o.vel.x = o.speed
	elseif o.dir == 2 then o.vel.y = o.speed
	elseif o.dir == 3 then o.vel.x = -o.speed end
end

function G:CanWeGo(o, dir)
	if dir == -1 or dir == nil then return false end
	return o.gridPos.moves[dir] == true
end

function G:CheckGridPassed(o)
	local v, p, g = o.vel, o.pos, o.gridPos.pos
	if v.x < 0 then return p.x < g.x
	elseif v.x > 0 then return p.x > g.x
	elseif v.y < 0 then return p.y < g.y
	elseif v.y > 0 then return p.y > g.y end
	return false
end

function G:AnimChangeDir(o)
	if o.isHero then
		dirTo(o)
		animTo(o, "walking")
	elseif o.state == 1 then
		dirTo(o)
		animTo(o, "walking")
	elseif o.state == 2 then
		dirTo(o)
		animTo(o, o.scaredCount > 100 and "scared" or "notsoscared")
	elseif o.state == 4 then
		dirTo(o)
		animTo(o, "dead")
	end
end

function G:ChangeGridPos(o, dir)
	local oldDir = o.dir
	o.dir = dir
	local gp = o.gridPos
	local dist = math.abs(o.pos.x - gp.pos.x + (o.pos.y - gp.pos.y))
	o.pos.x, o.pos.y = gp.pos.x, gp.pos.y
	o.vel.x, o.vel.y = 0, 0
	local nx, ny = gp.id.x, gp.id.y
	local w, h = self.gridDR.x - self.gridUL.x, self.gridDR.y - self.gridUL.y
	if dir == 0 then
		o.pos.y = o.pos.y - dist
		o.vel.y = -o.speed
		ny = ny - 1
		if ny < 0 then ny = NBY - 1 o.pos.y = o.pos.y + h end
	elseif dir == 1 then
		o.pos.x = o.pos.x + dist
		o.vel.x = o.speed
		nx = nx + 1
		if nx >= NBX then nx = 0 o.pos.x = o.pos.x - w end
	elseif dir == 2 then
		o.pos.y = o.pos.y + dist
		o.vel.y = o.speed
		ny = ny + 1
		if ny >= NBY then ny = 0 o.pos.y = o.pos.y - h end
	elseif dir == 3 then
		o.pos.x = o.pos.x - dist
		o.vel.x = -o.speed
		nx = nx - 1
		if nx < 0 then nx = NBX - 1 o.pos.x = o.pos.x + w end
	end
	o.gridPos = self.grid[nx][ny]
	if oldDir ~= dir then self:AnimChangeDir(o) end
end

function G:SpawnHero()
	local h = self.hero
	h.pos.x, h.pos.y = h.startPos.x, h.startPos.y
	h.gridPos = h.startGridRef
	h.dir = h.startDir
	h.normalSpeed = math.min(self.maxSpeed, (1 + self.levelSpeedIncrement * self.level) * self.defaultSpeed * h.speedFactor)
	h.scareSpeed = math.min(self.maxSpeed, h.normalSpeed * 1.3)
	h.speed = h.normalSpeed
	self:SetVel(h)
	h.nextForkRoad = h.gridPos.destForkRoads[h.dir]
	h.state = 1
	dirTo(h)
	animTo(h, "respawning")
	if self.fruitEaten == false then
		self.fruitFrames = self.fruitTime + self.fruitSpawnTime
	else
		self.fruitFrames = 0
	end
end

function G:SpawnGhosts()
	for _, g in ipairs(self.ghosts) do
		g.pos.x, g.pos.y = g.startPos.x, g.startPos.y
		g.gridPos = g.startGridRef
		g.dir = g.startDir
		g.speed = math.min(self.maxSpeed, (1 + self.levelSpeedIncrement * self.level) * self.defaultSpeed * g.speedFactor)
		g.vel.x, g.vel.y = 0, 0
		g.homeCount = g.homeTime
		g.state = 4
		dirTo(g)
		animTo(g, "standing")
		g.hidden = false
	end
end

function G:EatFood(g)
	if g.state ~= 1 then return end
	if g.type == 2 then
		self.score = self.score + 10
	elseif g.type == 3 then
		self:ScareGhosts()
		self.score = self.score + 50
	end
	self:UpdateStatusbar()
	g.state = 0
	g.mc.visible = false
	self.foodLeft = self.foodLeft - 1
	MG.Sound("g16", "eat_food" .. (self.foodLeft % 2))
end

function G:UpdateHero()
	local h = self.hero
	if h.state ~= 1 then return end
	h.pos.x = h.pos.x + h.vel.x
	h.pos.y = h.pos.y + h.vel.y
	local passed = self:CheckGridPassed(h)
	if h.vel.x == 0 and h.vel.y == 0 and h.wannaGo >= 0 then passed = true end
	if passed then
		self:EatFood(h.gridPos)
		if not self:CanWeGo(h, h.wannaGo) then h.wannaGo = h.dir end
		if self:CanWeGo(h, h.wannaGo) then
			self:ChangeGridPos(h, h.wannaGo)
			if h.gridPos.destForkRoads[h.dir] ~= false then h.nextForkRoad = h.gridPos.destForkRoads[h.dir] end
		else
			h.pos.x, h.pos.y = h.gridPos.pos.x, h.gridPos.pos.y
			h.vel.x, h.vel.y = 0, 0
			animTo(h, "standing")
		end
	end
end

function G:EatHero()
	local h = self.hero
	h.state = 2
	animTo(h, "standing")
	AN.Speak("MisterLiv")
	self:AddPause(50, function() self:EatHeroPauseDone() end)
	self:RemoveFruit()
	self.fruitFrames = 0
end

function G:EatHeroPauseDone()
	animTo(self.hero, "dying")
	MG.Sound("g16", "pac_die")
	for _, g in ipairs(self.ghosts) do g.hidden = true end   -- mc._x = -10000
end

function G:HeroDieAniDone()
	self.lives = self.lives - 1
	if self.lives <= 0 then
		self:GameOver()
	else
		self:SpawnHero()
		self:SpawnGhosts()
		self:UpdateStatusbar()
		FL.Play(self:Clip("spawnani"))
		self.gameState = 1
	end
end

function G:UpdateGhosts()
	if self.hero.state == 2 then return end
	local stopScared, stopReturning = false, false
	local h = self.hero
	for _, g in ipairs(self.ghosts) do
		g.hidden = false
		if g.state == 4 then
			g.homeCount = g.homeCount - 1
			if g.homeCount <= 0 then
				self:SetVel(g)
				dirTo(g)
				animTo(g, "walking")
				g.state = 5
			end
		else
			if g.state == 2 then
				g.scaredCount = g.scaredCount - 1
				if g.scaredCount <= 0 then
					animTo(g, "walking")
					g.state = 1
					stopScared = true
				elseif g.scaredCount == 100 then
					animTo(g, "notsoscared")
				end
			end
			g.pos.x = g.pos.x + g.vel.x
			g.pos.y = g.pos.y + g.vel.y
			if g.state == 1 or g.state == 2 then
				if self:CheckGridPassed(g) then
					local newDirs = {}
					if self:CanWeGo(g, g.dir) then newDirs[#newDirs + 1] = g.dir end
					local t = (g.dir + 1) % 4
					if self:CanWeGo(g, t) then newDirs[#newDirs + 1] = t end
					t = (g.dir + 3) % 4
					if self:CanWeGo(g, t) then newDirs[#newDirs + 1] = t end
					local function pick()
						-- (hint: a turn decided in advance, if it still fits)
						local plan = g.hintPlan
						if plan and #plan > 0 then
							local d = table.remove(plan, 1)
							for _, v in ipairs(newDirs) do if v == d then return d end end
							g.hintPlan = nil
						end
						return newDirs[math.floor(math.random() * #newDirs) + 1]
					end
					if g.gridPos.forkRoad ~= false then
						if g.id == 0 then
							if g.state == 2 then
								g.wannaGo = pick()
							elseif g.gridPos.forkRoad == h.nextForkRoad then
								g.wannaGo = num(self:GetPath(g.gridPos, h.gridPos, g.dir)[1])
							else
								g.wannaGo = num(self:GetPathForkRoad(g.gridPos.forkRoad, h.nextForkRoad, (g.dir + 2) % 4)[1])
							end
						elseif g.id == 2 then
							if math.random() < 0.5 then
								t = (g.dir + 2) % 4
								if self:CanWeGo(g, t) then newDirs[#newDirs + 1] = t end
							end
							g.wannaGo = pick()
						else
							g.wannaGo = pick()
						end
					else
						g.wannaGo = newDirs[1]
					end
					self:ChangeGridPos(g, g.wannaGo)
				end
			elseif g.state == 3 then
				-- the eyes go into the ghost house
				local ex, st = g.exitPos, g.startPos
				if g.pos.y == ex.y then
					if g.dir == 1 then
						if g.pos.x >= ex.x then
							g.dir = 2
							g.pos.y = g.pos.y + (g.pos.x - ex.x)
							g.pos.x = ex.x
							g.vel.x, g.vel.y = 0, g.speed
						end
					elseif g.pos.x <= ex.x then
						g.dir = 2
						g.pos.y = g.pos.y + (ex.x - g.pos.x)
						g.pos.x = ex.x
						g.vel.x, g.vel.y = 0, g.speed
					end
				elseif g.pos.y >= st.y then
					local home = false
					if g.dir == 2 then
						if g.pos.x == st.x then
							home = true
						elseif g.pos.x > st.x then
							g.dir = 3
							g.pos.x = g.pos.x - (g.pos.y - st.y)
							g.pos.y = st.y
							g.vel.x, g.vel.y = -g.speed, 0
						else
							g.dir = 1
							g.pos.x = g.pos.x + (g.pos.y - st.y)
							g.pos.y = st.y
							g.vel.x, g.vel.y = g.speed, 0
						end
					elseif g.dir == 3 then
						if g.pos.x <= st.x then home = true end
					elseif g.dir == 1 then
						if g.pos.x >= st.x then home = true end
					end
					if home then
						g.dir = g.startDir
						g.pos.y = st.y
						g.vel.x, g.vel.y = 0, 0
						g.homeCount = g.homeTime
						dirTo(g)
						animTo(g, "standing")
						g.state = 4
						stopReturning = true
					end
				end
			elseif g.state == 5 then
				-- out of the ghost house
				local ex = g.exitPos
				if g.dir == 1 then
					if g.pos.x >= ex.x then
						g.dir = 0
						g.pos.y = g.pos.y - (g.pos.x - ex.x)
						g.pos.x = ex.x
						g.vel.x, g.vel.y = 0, -g.speed
						dirTo(g)
						animTo(g, "walking")
					end
				elseif g.dir == 3 then
					if g.pos.x <= ex.x then
						g.dir = 0
						g.pos.y = g.pos.y - (ex.x - g.pos.x)
						g.pos.x = ex.x
						g.vel.x, g.vel.y = 0, -g.speed
						dirTo(g)
						animTo(g, "walking")
					end
				elseif g.pos.y <= ex.y then
					if g.id == 0 then
						g.dir = h.pos.x < g.pos.x and 3 or 1
					else
						g.dir = math.random() < 0.5 and 3 or 1
					end
					if g.dir == 3 then
						g.pos.x = g.pos.x - (ex.y - g.pos.y)
						g.vel.x = -g.speed
					else
						g.pos.x = g.pos.x + (ex.y - g.pos.y)
						g.vel.x = g.speed
					end
					g.pos.y = ex.y
					g.vel.y = 0
					g.gridPos = self.grid[self.ghostExit.id.x][self.ghostExit.id.y]
					g.state = 1
					dirTo(g)
					animTo(g, "walking")
				end
			elseif g.state == 6 then
				-- the eyes on their way home (along the path worked out when it was eaten)
				if self:CheckGridPassed(g) then
					self:ChangeGridPos(g, num(table.remove(g.ai.path, 1)))
				end
				if g.gridPos.id.x == self.ghostExit.id.x then g.state = 3 end
			end
		end
	end
	if stopReturning then
		if self:NbDeadGhosts() == 0 and self:NbScaredGhosts() <= 0 then h.speed = h.normalSpeed end
	elseif stopScared and self:NbScaredGhosts() == 0 and self:NbDeadGhosts() == 0 then
		h.speed = h.normalSpeed
	end
end

function G:EatGhost(g)
	self.ghostScoreMultiplier = self.ghostScoreMultiplier + 1
	local pts = 100 * 2 ^ self.ghostScoreMultiplier
	self.score = self.score + pts
	self:SetPoint(pts, g.pos.x, g.pos.y)
	MG.Sound("g16", "eat_ghost")
	if not AN.IsSpeaking("Godt") then AN.Speak("Godt") end
	self:AddPause(20)
	g.scaredCount = 0
	animTo(g, "dead")
	g.hidden = true
	g.state = 6
	g.ai.path = self:GetPath(g.gridPos, self.ghostExit)
	-- dir = ai.path[0]; setVel(ghosts[g]) has no ghost there (g is not set), so the eyes keep going
	-- the way the ghost was going until they reach the next square
	g.dir = num(g.ai.path[1])
end

function G:ScareGhosts()
	self.ghostScoreMultiplier = 0
	for _, g in ipairs(self.ghosts) do
		if g.state == 1 or g.state == 2 then
			g.scaredCount = g.scaredTime
			g.dir = (g.dir + 2) % 4
			g.vel.x, g.vel.y = -g.vel.x, -g.vel.y
			dirTo(g)
			animTo(g, "scared")
			g.state = 2
		end
	end
	self.hero.speed = self.hero.scareSpeed
end

function G:NbScaredGhosts()
	local n = 0
	for _, g in ipairs(self.ghosts) do if g.state == 2 then n = n + 1 end end
	return n
end

function G:NbDeadGhosts()
	local n = 0
	for _, g in ipairs(self.ghosts) do if g.state == 6 or g.state == 3 then n = n + 1 end end
	return n
end

-- hitarea.hitTest(hitarea): the boxes overlap
function G:HitBox(e)
	local m, k = FL.ChildMatrix(e.c, "hitarea", e.m)
	if not k then return nil end
	return FL.Bounds(k, m, true)
end

local function overlap(a, b)
	return a[1] and b[1] and a[1] <= b[3] and b[1] <= a[3] and a[2] <= b[4] and b[2] <= a[4]
end

function G:CheckCollisions()
	local hb = { self:HitBox(self.hero.entry) }
	if self.fruitFrames > 0 and self.fruit then
		if overlap({ self:HitBox(self.fruit) }, hb) then self:EatFruit() end
	end
	for _, g in ipairs(self.ghosts) do
		if not g.hidden and overlap({ self:HitBox(g.entry) }, hb) then
			if g.state == 2 then self:EatGhost(g)
			elseif g.state == 1 then self:EatHero() end
		end
	end
end

function G:CheckLevelCompleted()
	if self.foodLeft <= 0 then
		animTo(self.hero, "standing")
		FL.Play(self:Clip("lvlcompani"))
		self.gameState = 3
		AN.LevelScore(16, self.level, self.score - self.levelStartScore, { total = self.score })
	end
end

function G:EatFruit()
	self.nbFruitsEaten = self.nbFruitsEaten + 1
	local pts = 200 * (self.fruitId + 1)
	self.score = self.score + pts
	self:SetPoint(pts, self.fruit.m[5], self.fruit.m[6])
	self.fruitEaten = true
	self:RemoveFruit()
	self.fruitFrames = 0
	MG.Sound("g16", "eat_fruit")
end

function G:RemoveFruit()
	if self.fruit then self:Detach(self.fruit) self.fruit = nil end
end

function G:UpdateFruit()
	if self.fruitFrames > 0 then
		self.fruitFrames = self.fruitFrames - 1
		if self.fruitFrames == self.fruitTime then
			self:RemoveFruit()
			self.fruit = self:Attach(207, 1990, self.fruitSpot.pos.x + self.gridSize.x / 2, self.fruitSpot.pos.y)
			self.fruitId = self.nbFruitsEaten % self.nbFruits
			FL.GotoAndStop(self.fruit.c, self.fruitId + 1)
		elseif self.fruitFrames == 0 then
			self:RemoveFruit()
		end
	end
end

function G:UpdateStatusbar()
	local sb = self:Clip("statusbar")
	if not sb then return end
	sb.vars.txt_score = self.score
	sb.vars.txt_level = self.level
	local lives = FL.Child(sb, "lives")
	if lives then FL.GotoAndStop(lives, math.min(4, self.lives)) end
end

function G:AddPause(n, fn)
	self.pauses[#self.pauses + 1] = { count = n, fn = fn }
end

-- the points that pop up (5 of them, put in the game clip at the arena's numbers)
function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	if not p then p = { c = FL.New(LIB, 296) } self.points[self.nextPoint] = p end
	local s = math.max(55, math.min(140, val * 0.5)) / 100
	p.m = { s, 0, 0, s, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local hl = FL.Child(p.c, "hilite")
	if hl then FL.GotoAndStop(hl, "off") end
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
	self.nextPoint = self.nextPoint % 5 + 1
end

function G:StartNewGame()
	self.score = 0
	self.lives = 3
	self.nbFruitsEaten = 0
	self.pauses = {}
	self.ISON = true
	self:StartLevel(1)
end

function G:StartLevel(lvl)
	self.gameState = 1
	self.level = lvl
	self.levelStartScore = self.score
	self.foodLeft = self.nbFood
	self.fruitEaten = false
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = self.grid[gx][gy]
			if g.type == 2 or g.type == 3 then
				g.mc.visible = true
				g.state = 1
			end
		end
	end
	self:SpawnHero()
	self:SpawnGhosts()
	self:UpdateStatusbar()
	if lvl == 1 then
		FL.Play(self:Clip("startgameani"))
		self:Jingle("level_intro")
	else
		FL.Play(self:Clip("spawnani"))
		self:Jingle("level_intro2")
	end
end

function G:LevelIntroPlayed()
	animTo(self.hero, "walking")
	self.gameState = 2
end

function G:CheckKeys()
	local h = self.hero
	if input.IsKeyDown(KEY_LEFT) then h.wannaGo = 3
	elseif input.IsKeyDown(KEY_RIGHT) then h.wannaGo = 1
	elseif input.IsKeyDown(KEY_UP) then h.wannaGo = 0
	elseif input.IsKeyDown(KEY_DOWN) then h.wannaGo = 2
	else h.wannaGo = -1 end
end

---------------------------------------------------------------------------
-- hint (3 seconds): each lady's way ahead is drawn on the maze. The ladies who go at random get
-- their next turns decided now (so the drawing is what they will do); the one who hunts is drawn
-- along the shortest way to Bertramsen.
---------------------------------------------------------------------------
local LADY_COL = { [0] = Color(235, 50, 50), Color(255, 140, 200), Color(80, 200, 255), Color(255, 170, 40) }
local HINT_SQUARES = 14
function G:CanHint()
	if self.gameState ~= 2 or not self.hero or self.hero.state == 2 or self.hintT then return false end
	for _, g in ipairs(self.ghosts or {}) do if g.state == 1 or g.state == 2 then return true end end
	return false
end
function G:Hint(cost)
	self.hintT = 3
	self.score = math.max(0, self.score - cost)
	self:UpdateStatusbar()
	MG.Pop("-" .. cost, false, 240, 90)
	for _, g in ipairs(self.ghosts) do
		g.hintPlan = nil
		if g.state == 1 or g.state == 2 then
			local plan = {}
			self:HintWalk(g, function(sq, newDirs, isFork)
				if isFork and (g.id ~= 0 or g.state == 2) then
					local d = newDirs[math.floor(math.random() * #newDirs) + 1]
					plan[#plan + 1] = d
					return d
				end
			end)
			g.hintPlan = plan
		end
	end
end
-- walk a lady's way ahead square by square; decide(sq, newDirs, isFork) picks at a crossing
function G:HintWalk(g, decide, onSquare)
	local sq, dir = g.gridPos, g.dir
	local planI = 1
	local hunt = g.id == 0 and g.state == 1 and self:GetPath(g.gridPos, self.hero.gridPos, (g.dir + 2) % 4) or nil
	for k = 1, HINT_SQUARES do
		if onSquare then onSquare(sq, k) end
		local newDirs = {}
		if sq.moves[dir] == true then newDirs[#newDirs + 1] = dir end
		local t = (dir + 1) % 4
		if sq.moves[t] == true then newDirs[#newDirs + 1] = t end
		t = (dir + 3) % 4
		if sq.moves[t] == true then newDirs[#newDirs + 1] = t end
		if #newDirs == 0 then break end
		local isFork = sq.forkRoad ~= false
		local d
		if hunt then
			d = num(hunt[k])
			if d == nil then break end
		elseif decide then
			d = decide(sq, newDirs, isFork)
		elseif isFork and g.hintPlan then
			d = g.hintPlan[planI]
			planI = planI + 1
		end
		d = d or newDirs[1]
		local nx, ny = step(sq.id.x, sq.id.y, d)
		sq, dir = self.grid[nx][ny], d
	end
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.gameState ~= 2 then
		self.hintT = nil
		for _, g in ipairs(self.ghosts or {}) do g.hintPlan = nil end
		return
	end
	local am = FL.PathClip(self.root, { "game", "arena" })
	if not am then return end
	local a = math.min(1, self.hintT * 2)
	for _, g in ipairs(self.ghosts) do
		if g.state == 1 or g.state == 2 then
			local col = g.state == 2 and Color(120, 120, 255) or LADY_COL[g.id] or MG.HINT_GOLD
			local pts = { { TL.Apply(am, g.pos.x, g.pos.y) } }
			self:HintWalk(g, nil, function(sq) pts[#pts + 1] = { TL.Apply(am, sq.pos.x, sq.pos.y) } end)
			for k = 2, #pts do
				local p0, p1 = pts[k - 1], pts[k]
				if math.abs(p1[1] - p0[1]) + math.abs(p1[2] - p0[2]) < 60 then   -- (not across the wrap-around)
					if k == #pts then
						MG.HintArrow(p0[1], p0[2], p1[1], p1[2], col, a, 4)
					else
						MG.HintLine(p0[1], p0[2], p1[1], p1[2], col, a, 4)
					end
				end
			end
		end
	end
end

function G:GameOver()
	self.vars.score = self.score
	self:SetLoop(nil)
	FL.GotoAndPlay(self.root, "gameover")
end

function G:MainLoop()
	if not self.ISON or self.gameState ~= 2 then return end
	if #self.pauses == 0 then
		self:CheckKeys()
		self:UpdateHero()
		self:UpdateGhosts()
		self:UpdateFruit()
		self:CheckCollisions()
		self:CheckLevelCompleted()
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
-- hidden content: the sound loops and jingles that are in the file but never played
---------------------------------------------------------------------------
local function hiddenOn() return AN.Save.Get("hidden") ~= false end

function G:Jingle(name)
	if hiddenOn() then MG.Sound("g16", name, 0.8) end
end

function G:SetLoop(name)
	if not hiddenOn() then name = nil end
	if name == self.loopName then return end
	self.loopName = name
	if self.loopCh and IsValid(self.loopCh) then self.loopCh:Stop() end
	self.loopCh = nil
	if not name or AN.SoundMode() == 2 then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100 * 0.5
	if v <= 0 then return end
	local me = self
	sound.PlayFile("sound/alletidersnisse/g16/" .. name .. ".mp3", "noplay noblock", function(ch)
		if not IsValid(ch) then return end
		if CUR ~= me or me.loopName ~= name then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		me.loopCh = ch
	end)
end

function G:UpdateLoop()
	local want = nil
	if self.gameState == 2 and self.hero and self.hero.state == 1 then
		if self:NbDeadGhosts() > 0 then want = "returning_loop"
		elseif self:NbScaredGhosts() > 0 then want = "scared_loop"
		else want = "bg_loop" end
	end
	self:SetLoop(want)
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g16_status", self.score or 0, self.level or 1, self.lives or 3)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.score = 0
	self.level = 1
	self.lives = 3
	self.ISON = false
	self.gameState = 0
	self.arenaStuff, self.points, self.pauses = {}, {}, {}
	self.fruit = nil
	self.fruitFrames = 0
	self.vars = { score = 0 }
	self.loopName = nil
	self.root = FL.New(LIB, 0)
end

function G:Close()
	self:SetLoop(nil)
	if CUR == self then CUR = nil end
end

function G:Step()
	FL.Tick(self.root)
	for _, e in ipairs(self.arenaStuff) do FL.Tick(e.c) end
	for _, p in ipairs(self.points) do if p.c.visible then FL.Tick(p.c) end end
	self:MainLoop()
	-- the clips follow the game objects (mc._x = pos.x ...)
	if self.hero then
		local h = self.hero
		h.entry.m[5], h.entry.m[6] = h.pos.x, h.pos.y
		for _, g in ipairs(self.ghosts) do
			g.entry.m[5], g.entry.m[6] = g.pos.x, g.pos.y
			g.entry.c.visible = not g.hidden
		end
	end
	self:UpdateLoop()
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
	self:SetLoop(nil)
	AN.FinishGame(16, self.score or 0)
end

local function byDepth(a, b) return a.depth < b.depth end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(16) return end
	local game = self:Game()
	if game then
		local arena = FL.Child(game, "arena")
		if arena then
			table.sort(self.arenaStuff, byDepth)
			arena.extra = self.arenaStuff
		end
		local extra = {}
		for _, p in ipairs(self.points) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		return st.vars[name]
	end
	FL.Draw(self.root, I)
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	if self.root.frame >= 16 and self.root.frame < 89 then
		UI.Button("g16_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(16)
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(16, G)
