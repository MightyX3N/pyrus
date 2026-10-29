-- Låge 9: Arkivræs
-- Rebuilt from the original loader.swf: a "Rally-X" in TV 2's archive. Pyrus drives through the
-- shelves and picks up the 10 flags (one of them is a bonus flag that raises the multiplier) while
-- 3 cars hunt him. Space / Ctrl lays a smoke cloud that makes a car stuck for a while (it costs
-- fuel). Hitting a car or a rock costs a life; 3 lives. The fuel left at the end of a level is
-- counted up as a bonus. The radar shows the whole archive.
-- The whole original timeline is played with the Flash player; the game code is the original's,
-- with the same numbers and quirks:
--   * you crash into a rock already one square before you reach it (the original checks the
--     square you are driving towards),
--   * a car stuck in smoke still crashes into you,
--   * the "scared cars you can eat" part of the code (like Pac-Man's ghosts) is never used.
-- Hidden content: the game's own background music (in the file, but never played) plays during
-- the game.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g09_fl.lua")
include(DIR .. "g09_map.lua")

local G = {
	scoreType = "score",
	goal = 30000,     -- the original coolScore
	worst = 0,
	descKey = "desc_09",
	howKey = "how_09",
	levels = nil,
}

local STAGE_W, STAGE_H = 580, 400
local STEP = 1 / 25
local LIB = "g09"
local I = { 1, 0, 0, 1, 0, 0 }
local NBX, NBY = 34, 58

local CUR

-- "START SPILLET" has its text drawn in; an English one is made from it (scripts/g09_en.py)
FL.ImgSwap["g09/fl/s277.png"] = { en = "g09/fl/s277_en.png" }

-- the flag spots: 10 groups, one flag from each group (the original's map 0)
local FLAGS = {
	{ { 4, 4 }, { 8, 6 }, { 11, 9 }, { 4, 12 }, { 8, 13 } },
	{ { 30, 3 }, { 26, 6 }, { 17, 10 }, { 13, 13 }, { 17, 17 } },
	{ { 31, 5 }, { 28, 10 }, { 21, 13 }, { 31, 13 }, { 23, 18 } },
	{ { 15, 23 }, { 22, 23 }, { 16, 28 }, { 22, 29 }, { 17, 33 } },
	{ { 28, 18 }, { 32, 18 }, { 26, 23 }, { 30, 23 }, { 28, 27 } },
	{ { 4, 19 }, { 11, 19 }, { 12, 22 }, { 5, 25 }, { 8, 28 } },
	{ { 30, 32 }, { 4, 33 }, { 13, 33 }, { 22, 35 }, { 27, 36 } },
	{ { 12, 36 }, { 1, 39 }, { 7, 39 }, { 14, 41 }, { 3, 42 } },
	{ { 32, 37 }, { 24, 38 }, { 26, 42 }, { 30, 42 }, { 22, 44 } },
	{ { 9, 46 }, { 29, 49 }, { 4, 52 }, { 22, 53 }, { 29, 54 } },
}
local ROCKS = {
	{ 21, 4 }, { 10, 6 }, { 1, 13 }, { 9, 14 }, { 19, 14 }, { 7, 21 }, { 31, 27 }, { 18, 28 }, { 6, 30 }, { 27, 30 },
	{ 13, 31 }, { 26, 32 }, { 15, 38 }, { 22, 38 }, { 2, 39 }, { 29, 39 }, { 9, 43 }, { 1, 44 }, { 18, 46 }, { 28, 46 }, { 7, 52 },
}
-- the cars: start square and how they hunt (0: along the longest way to Pyrus first, 1: sideways
-- first, 2: up/down first, 3: at random)
local GHOSTS = {
	{ x = 16, y = 54, ai = 0 },
	{ x = 14, y = 54, ai = 1 },
	{ x = 18, y = 54, ai = 2 },
}

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.LoadHidden[LIB] = { [203] = true, [233] = true, [255] = true }   -- hit areas, the bang, corner marks
	for _, cid in ipairs({ 13, 137, 193, 197, 213, 220, 227, 234, 242, 299, 233 }) do
		FL.SetActions(LIB, cid, { [1] = stop })
	end
	FL.SetActions(LIB, 233, { [9] = stop })
	-- the crash: the bang shows, and when it is over Pyrus has lost a life
	FL.SetActions(LIB, 230, {
		[1] = function(c) local h = c.parent and c.parent.parent local b = h and FL.Child(h, "bang") if b then b.visible = true end end,
		[31] = function(c)
			stop(c)
			local h = c.parent and c.parent.parent
			local b = h and FL.Child(h, "bang")
			if b then b.visible = false end
			if CUR then CUR:HeroDieAniDone() end
		end,
	})
	FL.SetActions(LIB, 237, { [101] = function(c) stop(c) if CUR then CUR:SmokeAniDone(c.ref) end end })
	FL.SetActions(LIB, 243, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	FL.SetActions(LIB, 274, {
		[1] = stop,
		[26] = function(c) stop(c) AN.Speak("megetGodt") if CUR then CUR:StartFuelCount() end end,
		[75] = function() if CUR then CUR:EndLevel() end end,
	})
	FL.SetActions(LIB, 279, { [1] = stop, [2] = function() MG.Sound("g09", "car_rev_up") end, [95] = function() if CUR then CUR:LevelIntroPlayed() end end })
	FL.SetActions(LIB, 287, { [1] = stop, [2] = function() MG.Sound("g09", "car_rev_up") end, [95] = function() if CUR then CUR:LevelIntroPlayed() end end })
	FL.SetActions(LIB, 311, { [2] = function(c) stop(c) if CUR then CUR:Init() end end })
	FL.SetActions(LIB, 0, {
		[8] = stop,
		[16] = function(c) AN.Speak("GameOver") FL.Play(c) end,
		[92] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Game() return FL.Child(self.root, "game") end
function G:Clip(name) return FL.Child(self:Game(), name) end

-- a child's position (its _x / _y) inside its parent
local function itemPos(parent, name)
	local m = FL.ChildMatrix(parent, name, I)
	return m and m[5] or 0, m and m[6] or 0
end

local function setPos(parent, name, x, y)
	local m, k = FL.ChildMatrix(parent, name, I)
	if k then k.mat = { m[1], m[2], m[3], m[4], x, y } end
end

-- an attached clip: { c = clip, m = matrix, depth = n }
local function attach(list, cid, depth, x, y, sx, sy)
	local e = { c = FL.New(LIB, cid), m = { sx or 1, 0, 0, sy or sx or 1, x or 0, y or 0 }, depth = depth }
	list[#list + 1] = e
	return e
end

local function detach(list, e)
	for i = #list, 1, -1 do if list[i] == e then table.remove(list, i) end end
end

local function vec(x, y) return { x = x or 0, y = y or 0 } end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:Init()
	local arena = self:Clip("arena")
	local ux, uy = itemPos(arena, "grid_upleft")
	local dx, dy = itemPos(arena, "grid_downright")
	self.gridUL, self.gridDR = vec(ux, uy), vec(dx, dy)
	self.defaultSpeed = (dx - ux) / 110 * 0.8
	self.levelSpeedIncrement = 0.05
	self.maxSpeed = 9.5
	self.flagScore = 100
	self.fuelBonusBase = 25
	self.smokeCost = 0.5
	self.engineCost = 0.01
	self.noFuelSpeedFactor = 0.9
	self:InitPoints()
	self.ISON = false
	self:CreateHero()
	self.gameState = 0
	self:StartNewGame()
end

function G:StartNewGame()
	self.score = 0
	self.lives = 3
	self.pauses = {}
	self.ISON = true
	self:StartLevel(1)
end

-- the points that pop up (5 of them, in the middle of the game window)
function G:InitPoints()
	self.points = {}
	self.nextPoint = 1
end

function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	if not p then
		p = { c = FL.New(LIB, 243), s = 1 }
		self.points[self.nextPoint] = p
	end
	-- the scale is val * 0.5 %, 55..140; for "300 x 2" that is not a number and the scale stays
	if type(val) == "number" then p.s = math.max(55, math.min(140, val * 0.5)) / 100 end
	p.m = { p.s, 0, 0, p.s, x, y }
	p.c.visible = true
	FL.GotoAndPlay(p.c, 1)
	local hl = FL.Child(p.c, "hilite")
	if hl then FL.GotoAndStop(hl, "off") end
	local ani = FL.Child(p.c, "ani")
	if ani then ani.vars.txt = val end
	self.nextPoint = self.nextPoint % 5 + 1
end

function G:CreateHero()
	self.hero = {
		pos = vec(), vel = vec(), startPos = vec(), dir = -1, wannaGo = -1, speed = 0,
		normalSpeed = 0, scareSpeed = 0, speedFactor = 0.8, fuel = 0, state = 0, startDir = 0, isHero = true,
	}
end

-- the grid: 34 x 58 squares over the archive picture
function G:CreateGrid(nbRocks)
	local gs = vec((self.gridDR.x - self.gridUL.x) / NBX, (self.gridDR.y - self.gridUL.y) / NBY)
	self.gridSize = gs
	local off = vec(self.gridUL.x + gs.x / 2, self.gridUL.y + gs.y / 2)
	local rows = {}
	for line in string.gmatch(AN.G09Map, "[01]+") do rows[#rows + 1] = line end
	local grid = {}
	for gx = 0, NBX - 1 do
		grid[gx] = {}
		for gy = 0, NBY - 1 do
			local road = rows[gy + 1] and string.sub(rows[gy + 1], gx + 1, gx + 1) == "0"
			grid[gx][gy] = { id = vec(gx, gy), pos = vec(off.x + gx * gs.x, off.y + gy * gs.y), type = road and 0 or 1, moves = { 1, 1, 1, 1 }, smoking = false, state = -1 }
		end
	end
	self.grid = grid
	-- fillGrid: one flag of each group, one of them the bonus flag, and the rocks
	self.hero.startGridRef = grid[16][51]
	self.hero.startDir = 0
	local bonus = math.random(0, 9)
	for i = 0, 9 do
		local p = FLAGS[i + 1][math.random(1, #FLAGS[i + 1])]
		grid[p[1]][p[2]].type = i == bonus and 3 or 2
	end
	local rocks = {}
	for _, r in ipairs(ROCKS) do rocks[#rocks + 1] = r end
	for _ = 1, nbRocks do
		local k = math.random(1, #rocks)
		local r = table.remove(rocks, k)
		grid[r[1]][r[2]].type = 4
	end
	self:CreateGridStuff()
end

function G:CreateGridStuff()
	local grid, gs = self.grid, self.gridSize
	self.nbFood = 0
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = grid[gx][gy]
			-- moves[dir + 1]: the type of the square that way (the grid wraps round)
			g.moves[1] = grid[gx][(gy - 1) % NBY].type
			g.moves[2] = grid[(gx + 1) % NBX][gy].type
			g.moves[3] = grid[gx][(gy + 1) % NBY].type
			g.moves[4] = grid[(gx - 1) % NBX][gy].type
			if g.type == 2 or g.type == 3 or g.type == 4 then
				if g.type ~= 4 then self.nbFood = self.nbFood + 1 end
				local e = attach(self.arenaStuff, 197, 1000 + gx + gy * NBX, g.pos.x, g.pos.y, gs.x / 100, gs.y / 100)
				FL.GotoAndStop(e.c, g.type - 1)
				e.c.visible = false
				g.mc = e.c
				g.mcEntry = e
			end
		end
	end
end

function G:RemoveGridStuff()
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = self.grid[gx][gy]
			if g.mcEntry then detach(self.arenaStuff, g.mcEntry) end
		end
	end
	for s = #self.smoke, 1, -1 do
		detach(self.arenaStuff, self.smoke[s].entry)
		table.remove(self.smoke, s)
	end
end

function G:CreateGhosts(n)
	self.ghosts = {}
	for g = 0, n - 1 do
		local d = GHOSTS[g + 1]
		local e = attach(self.arenaStuff, 227 - g * 7, 20000 + g)   -- ghost0 = 227, ghost1 = 220, ghost2 = 213
		local gh = {
			id = g, mc = e.c, entry = e, pos = vec(), vel = vec(), startPos = vec(), dir = -1, wannaGo = -1,
			homeTime = 25, homeCount = 0, scaredTime = 200, scaredCount = 0, speed = 0, speedFactor = 0.8, state = 0,
			ai = d.ai, startGridRef = self.grid[d.x][d.y], startDir = 0,
		}
		gh.startPos.x, gh.startPos.y = gh.startGridRef.pos.x, gh.startGridRef.pos.y
		self.ghosts[g + 1] = gh
	end
end

function G:RemoveGhosts()
	for _, gh in ipairs(self.ghosts or {}) do detach(self.arenaStuff, gh.entry) end
end

-- the radar: a dot for each flag, Pyrus and the cars
function G:CreateRadarStuff()
	local radar = self:Clip("radar")
	local ux, uy = itemPos(radar, "grid_upleft")
	local dx, dy = itemPos(radar, "grid_downright")
	local rs = vec((dx - ux) / NBX, (dy - uy) / NBY)
	self.radarSize = rs
	self.radarOff = vec(ux + rs.x / 2, uy + rs.y / 2)
	self.radarStuff = {}
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = self.grid[gx][gy]
			if g.type == 2 or g.type == 3 then
				local e = attach(self.radarStuff, 193, 1000 + gx + gy * NBX, self.radarOff.x + gx * rs.x, self.radarOff.y + gy * rs.y, rs.x / 100, rs.y / 100)
				FL.GotoAndStop(e.c, g.type - 1)
				g.radarMc = e
			end
		end
	end
	local h = self.hero
	h.radarMc = attach(self.radarStuff, 190, 21000, self.radarOff.x + h.startGridRef.id.x * rs.x, self.radarOff.y + h.startGridRef.id.y * rs.y, rs.x / 100, rs.y / 100)
	for _, gh in ipairs(self.ghosts) do
		gh.radarMc = attach(self.radarStuff, 188, 20000 + gh.id, self.radarOff.x + gh.startGridRef.id.x * rs.x, self.radarOff.y + gh.startGridRef.id.y * rs.y, rs.x / 100, rs.y / 100)
	end
end

function G:SetRadar(obj)
	if not obj.radarMc then return end
	obj.radarMc.m[5] = self.radarOff.x + obj.gridPos.id.x * self.radarSize.x
	obj.radarMc.m[6] = self.radarOff.y + obj.gridPos.id.y * self.radarSize.y
end

function G:StartLevel(lvl)
	self.gameState = 1
	self.level = lvl
	self.arenaStuff = self.arenaStuff or {}
	self:CreateGrid(2)
	self:CreateGhosts(3)
	-- the hero's car goes on top of everything in the arena
	local h = self.hero
	if not h.entry then
		h.entry = attach(self.arenaStuff, 234, 21000)
		h.mc = h.entry.c
	end
	self:CreateRadarStuff()
	self.foodLeft = self.nbFood
	self.nbFlagsEaten = 0
	self.bonusMultiplier = 1
	h.startPos.x, h.startPos.y = h.startGridRef.pos.x, h.startGridRef.pos.y
	for gx = 0, NBX - 1 do
		for gy = 0, NBY - 1 do
			local g = self.grid[gx][gy]
			if g.type == 2 or g.type == 3 then
				g.mc.visible = true
				g.state = 1
			elseif g.type == 4 then
				g.mc.visible = true
			end
		end
	end
	self.smoke = {}
	self:InitCam()
	self:SpawnHero()
	self:SpawnGhosts()
	self:UpdateStatusbar()
	if lvl == 1 then
		FL.Play(self:Clip("startgameani"))
	else
		FL.Play(self:Clip("spawnani"))
	end
end

function G:LevelIntroPlayed()
	local anim = FL.Child(self.hero.mc, "anim")
	if anim then FL.GotoAndStop(anim, "walking") end
	self.gameState = 2
	self:StartMusic()
end

function G:EndLevel()
	self:RemoveGridStuff()
	self:RemoveGhosts()
	self:StartLevel(self.level + 1)
end

function G:InitCam()
	local cam = self:Clip("camera")
	local ux, uy = itemPos(cam, "cam_upleft")
	local dx, dy = itemPos(cam, "cam_downright")
	self.cam = { offset = vec(ux, uy), half = vec((dx - ux) / 2, (dy - uy) / 2) }
end

function G:UpdateCamera()
	local h = self.hero
	setPos(self:Game(), "arena", -h.pos.x + self.cam.offset.x + self.cam.half.x, -h.pos.y + self.cam.offset.y + self.cam.half.y)
end

function G:SetVel(o)
	o.vel.x, o.vel.y = 0, 0
	if o.dir == 0 then o.vel.y = -o.speed
	elseif o.dir == 1 then o.vel.x = o.speed
	elseif o.dir == 2 then o.vel.y = o.speed
	elseif o.dir == 3 then o.vel.x = -o.speed end
end

function G:CanWeGo(o, dir)
	if dir == -1 or dir == nil then return 1 end
	return o.gridPos.moves[dir + 1]
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
	FL.GotoAndStop(o.mc, "dir" .. o.dir)
	local anim = FL.Child(o.mc, "anim")
	if o.isHero then
		if anim then FL.GotoAndStop(anim, "walking") end
	elseif o.state == 1 then
		if anim then FL.GotoAndStop(anim, "walking") end
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
	self:SetRadar(o)
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
	h.fuel = 100
	h.state = 1
	FL.GotoAndStop(h.mc, "dir" .. h.dir)
	local anim = FL.Child(h.mc, "anim")
	if anim then FL.GotoAndStop(anim, "standing") end
	h.entry.m[5], h.entry.m[6] = h.pos.x, h.pos.y
	self:SetRadar(h)
	self:UpdateCamera()
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
		FL.GotoAndStop(g.mc, "dir" .. g.dir)
		local anim = FL.Child(g.mc, "anim")
		if anim then FL.GotoAndStop(anim, "standing") end
		g.entry.m[5], g.entry.m[6] = g.pos.x, g.pos.y
		self:SetRadar(g)
	end
end

function G:EatFood(g)
	if g.state ~= 1 then return end
	if g.type == 3 then self.bonusMultiplier = self.bonusMultiplier + 1 end
	self.nbFlagsEaten = self.nbFlagsEaten + 1
	self.score = self.score + self.flagScore * self.nbFlagsEaten * self.bonusMultiplier
	local shown = self.flagScore * self.nbFlagsEaten
	if self.bonusMultiplier > 1 then shown = shown .. " x " .. self.bonusMultiplier end
	self:SetPoint(shown, 200, 200)
	self:UpdateStatusbar()
	g.state = 0
	g.mc.visible = false
	if g.radarMc then g.radarMc.c.visible = false end
	self.foodLeft = self.foodLeft - 1
	MG.Sound("g09", "pickup_flag")
end

function G:FireSmoke()
	MG.Sound("g09", "smoke")
	local h = self.hero
	local e = attach(self.arenaStuff, 237, 19000 + #self.smoke, h.gridPos.pos.x, h.gridPos.pos.y)
	e.c.ref = h.gridPos
	local s = { entry = e, state = 1 }
	self.smoke[#self.smoke + 1] = s
	h.gridPos.smoking = s
	h.fuel = math.max(0, h.fuel - self.smokeCost)
end

function G:SmokeAniDone(ref)
	if ref and ref.smoking then
		ref.smoking.state = 2
		ref.smoking = false
	end
end

function G:RemoveSmoke()
	for s = #self.smoke, 1, -1 do
		if self.smoke[s].state == 2 then
			detach(self.arenaStuff, self.smoke[s].entry)
			table.remove(self.smoke, s)
		end
	end
end

function G:CheckKeys()
	local h = self.hero
	if input.IsKeyDown(KEY_LEFT) then h.wannaGo = 3
	elseif input.IsKeyDown(KEY_RIGHT) then h.wannaGo = 1
	elseif input.IsKeyDown(KEY_UP) then h.wannaGo = 0
	elseif input.IsKeyDown(KEY_DOWN) then h.wannaGo = 2 end
	self.wantSmoke = input.IsKeyDown(KEY_SPACE) or input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
end

function G:UpdateHero()
	local h = self.hero
	if h.state ~= 1 then return end
	h.fuel = h.fuel - self.engineCost
	local fuelSpeed = 1
	if h.fuel < 0 then
		h.fuel = 0
		fuelSpeed = self.noFuelSpeedFactor
	end
	self:SetFuelBar(h.fuel)
	h.pos.x = h.pos.x + h.vel.x * fuelSpeed
	h.pos.y = h.pos.y + h.vel.y * fuelSpeed
	if self.wantSmoke and h.gridPos.smoking == false and h.fuel > 0 then self:FireSmoke() end
	if self:CheckGridPassed(h) then
		self:EatFood(h.gridPos)
		if self:CanWeGo(h, h.wannaGo) == 1 then h.wannaGo = h.dir end
		if self:CanWeGo(h, h.wannaGo) ~= 1 then
			self:ChangeGridPos(h, h.wannaGo)
		else
			local right, left = (h.dir + 1) % 4, (h.dir + 3) % 4
			if self:CanWeGo(h, right) ~= 1 then h.wannaGo = right
			elseif self:CanWeGo(h, left) ~= 1 then h.wannaGo = left
			else h.wannaGo = (h.dir + 2) % 4 end
			self:ChangeGridPos(h, h.wannaGo)
		end
	end
	h.entry.m[5], h.entry.m[6] = h.pos.x, h.pos.y
end

-- which way a car wants to go, best first (the original's four kinds of driver)
local function optimalDirs(ai, tx, ty)
	local o = {}
	if ai == 0 then
		if math.abs(tx) >= math.abs(ty) then
			o[1] = tx > 0 and 1 or 3
			o[2] = ty < 0 and 0 or 2
		else
			o[1] = ty < 0 and 0 or 2
			o[2] = tx > 0 and 1 or 3
		end
		o[3] = (o[2] + 2) % 4
		o[4] = (o[1] + 2) % 4
	elseif ai == 1 then
		if tx ~= 0 then
			if tx > 0 then o[1], o[4] = 1, 3 else o[1], o[4] = 3, 1 end
			if ty < 0 then o[2], o[3] = 0, 2 else o[2], o[3] = 2, 0 end
		else
			if ty < 0 then o[1], o[4] = 0, 2 else o[1], o[4] = 2, 0 end
			if math.random() < 0.5 then o[2], o[3] = 1, 3 else o[2], o[3] = 3, 1 end
		end
	elseif ai == 2 then
		if ty ~= 0 then
			if ty < 0 then o[1], o[4] = 0, 2 else o[1], o[4] = 2, 0 end
			if tx > 0 then o[2], o[3] = 1, 3 else o[2], o[3] = 3, 1 end
		else
			if tx > 0 then o[1], o[4] = 1, 3 else o[1], o[4] = 3, 1 end
			if math.random() < 0.5 then o[2], o[3] = 0, 2 else o[2], o[3] = 2, 0 end
		end
	else
		local avail = { 0, 1, 2, 3 }
		for d = 1, 4 do o[d] = table.remove(avail, math.random(1, #avail)) end
	end
	return o
end

function G:UpdateGhosts()
	if self.hero.state == 2 then return end
	for _, g in ipairs(self.ghosts) do
		local anim = FL.Child(g.mc, "anim")
		if g.state == 4 then
			g.homeCount = g.homeCount - 1
			if g.homeCount <= 0 then
				self:SetVel(g)
				FL.GotoAndStop(g.mc, "dir" .. g.dir)
				anim = FL.Child(g.mc, "anim")
				if anim then FL.GotoAndStop(anim, "walking") end
				g.state = 1
			end
		elseif g.gridPos.smoking ~= false then
			if anim then FL.GotoAndStop(anim, "stuck") end
			g.state = 7
		else
			if g.state == 7 then
				if anim then FL.GotoAndStop(anim, "walking") end
				g.state = 1
			end
			g.pos.x = g.pos.x + g.vel.x
			g.pos.y = g.pos.y + g.vel.y
			if g.state == 1 and self:CheckGridPassed(g) then
				local back = (g.dir + 2) % 4
				local h = self.hero
				local o = optimalDirs(g.ai, h.gridPos.id.x - g.gridPos.id.x, h.gridPos.id.y - g.gridPos.id.y)
				-- drop the ways that are blocked (shelves and rocks); going back is the last choice
				for d = 3, 0, -1 do
					if o[d + 1] ~= nil then
						local t = self:CanWeGo(g, o[d + 1])
						if t ~= 1 and t ~= 4 then
							if o[d + 1] == back then
								table.remove(o, d + 1)
								o[#o + 1] = back
							end
						else
							table.remove(o, d + 1)
						end
					end
				end
				g.wannaGo = o[1]
				self:ChangeGridPos(g, g.wannaGo)
			end
		end
		g.entry.m[5], g.entry.m[6] = g.pos.x, g.pos.y
	end
end

-- hitarea.hitTest(hero.hitarea): the two cars' hit boxes overlap
function G:HitArea(o)
	local m, k = FL.ChildMatrix(o.mc, "hitarea", o.entry.m)
	if not k then return nil end
	return FL.Bounds(k, m, true)
end

function G:CheckCollisions()
	local h = self.hero
	if h.state ~= 1 then return end
	local eat = false
	local ax0, ay0, ax1, ay1 = self:HitArea(h)
	for _, g in ipairs(self.ghosts) do
		if (g.state == 1 or g.state == 7) and ax0 then
			local bx0, by0, bx1, by1 = self:HitArea(g)
			if bx0 and ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1 then eat = true end
		end
	end
	if h.gridPos.type == 4 then eat = true end
	if eat then self:EatHero() end
end

function G:EatHero()
	local h = self.hero
	h.state = 2
	local anim = FL.Child(h.mc, "anim")
	if anim then FL.GotoAndStop(anim, "standing") end
	-- eatHeroPauseDone (the original turned the crash sound down to 10% right after starting it)
	if anim then FL.GotoAndStop(anim, "dying") end
	MG.Sound("g09", "car_crash", 0.1)
	AN.Speak("MisterLiv")
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

function G:CheckLevelCompleted()
	if self.foodLeft <= 0 then
		local anim = FL.Child(self.hero.mc, "anim")
		if anim then FL.GotoAndStop(anim, "standing") end
		FL.Play(self:Clip("lvlcompani"))
		self.gameState = 3
	end
end

-- the fuel left is counted into points (25 per unit of fuel, one unit a frame)
function G:StartFuelCount()
	self.counting = true
	self.fuelBonus = 0
	local a = self:Clip("lvlcompani")
	if a then a.vars.txtFuelBonus = 0 end
end

function G:FuelCount()
	local h = self.hero
	local add, done = 0, false
	if h.fuel >= 1 then
		add = self.fuelBonusBase
		h.fuel = h.fuel - 1
	else
		add = math.Round(self.fuelBonusBase * h.fuel)
		h.fuel = 0
		done = true
	end
	self.fuelBonus = self.fuelBonus + add
	self.score = self.score + add
	self:UpdateStatusbar()
	local a = self:Clip("lvlcompani")
	if a then a.vars.txtFuelBonus = self.fuelBonus end
	if done then
		self.counting = false
		FL.Play(a)
		-- each finished level goes on that level's high score list
		AN.LevelScore(9, self.level, self.score - (self.levelStartScore or 0), { total = self.score })
		self.levelStartScore = self.score
	end
end

function G:SetFuelBar(fuel)
	local sb = self:Clip("statusbar")
	local f = sb and FL.Child(sb, "fuel")
	if not f then return end
	local m, k = FL.ChildMatrix(f, "bar", I)
	if not k then return end
	k.baseM = k.baseM or { m[1], m[2], m[3], m[4], m[5], m[6] }
	local b = k.baseM
	-- _xscale = fuel (the bar is flipped, so it keeps its direction)
	local sx = (b[1] < 0 and -1 or 1) * fuel / 100
	k.mat = { sx, 0, 0, b[4], b[5], b[6] }
end

function G:UpdateStatusbar()
	local sb = self:Clip("statusbar")
	if not sb then return end
	sb.vars.txt_score = self.score
	sb.vars.txt_level = self.level
	local lives = FL.Child(sb, "lives")
	if lives then FL.GotoAndStop(lives, math.min(4, self.lives)) end
	self:SetFuelBar(self.hero.fuel)
end

---------------------------------------------------------------------------
-- hint (15 seconds): the bonus flag is ringed on the radar, the rocks are marked on it, and a "!"
-- warns over Pyrus when he drives towards a rock (you crash a square early, see above)
---------------------------------------------------------------------------
function G:CanHint() return self.gameState == 2 and self.hero and self.hero.state == 1 end
function G:Hint(cost)
	self.hintT = 15
	self.score = math.max(0, self.score - cost)
	self:UpdateStatusbar()
	MG.Pop("-" .. cost, false, 240, 60)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.gameState ~= 2 then self.hintT = nil return end
	local a = math.min(1, self.hintT * 2)
	local rm = FL.PathClip(self.root, { "game", "radar" })
	local rs, ro = self.radarSize, self.radarOff
	if rm and rs and self.grid then
		for gx = 0, NBX - 1 do
			for gy = 0, NBY - 1 do
				local g = self.grid[gx][gy]
				if g.type == 3 and g.state == 1 then
					local x, y = TL.Apply(rm, ro.x + gx * rs.x, ro.y + gy * rs.y)
					MG.HintRing(x, y, 9, MG.HINT_GOLD, a, 3)
				elseif g.type == 4 then
					local x, y = TL.Apply(rm, ro.x + gx * rs.x, ro.y + gy * rs.y)
					MG.HintText("x", x, y, MG.HINT_BAD, 14, a)
				end
			end
		end
	end
	-- a rock straight ahead (within two squares)
	local h = self.hero
	local am = FL.PathClip(self.root, { "game", "arena" })
	if am and h.gridPos and h.dir and h.dir >= 0 then
		local d = ({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } })[h.dir + 1]
		local id = h.gridPos.id
		for k = 1, 2 do
			local g = self.grid[(id.x + d[1] * k) % NBX] and self.grid[(id.x + d[1] * k) % NBX][(id.y + d[2] * k) % NBY]
			if not g or g.type == 1 then break end
			if g.type == 4 then
				local x, y = TL.Apply(am, h.pos.x, h.pos.y)
				MG.HintText("!", x, y - 34, MG.HINT_BAD, 34, a)
				break
			end
		end
	end
end

function G:GameOver()
	self.vars.score = self.score
	self:StopMusic()
	FL.GotoAndStop(self.root, "gameover")
end

function G:MainLoop()
	if not self.ISON then return end
	if self.counting then self:FuelCount() end
	if self.gameState ~= 2 then return end
	if #self.pauses == 0 then
		self:CheckKeys()
		self:UpdateHero()
		self:UpdateCamera()
		self:UpdateGhosts()
		self:CheckCollisions()
		self:RemoveSmoke()
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
-- hidden content: the background music that was left in the file
---------------------------------------------------------------------------
function G:StartMusic()
	if self.musicOn or AN.Save.Get("hidden") == false then return end
	if AN.SoundMode() ~= 0 then return end
	local v = (AN.Save.Get("vol_music") or 70) / 100 * 0.6
	if v <= 0 then return end
	self.musicOn = true
	local me = self
	sound.PlayFile("sound/alletidersnisse/g09/bg_loop.mp3", "noplay noblock", function(ch)
		if not IsValid(ch) then return end
		if CUR ~= me or not me.musicOn then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		me.musicCh = ch
	end)
end

function G:StopMusic()
	self.musicOn = false
	if self.musicCh and IsValid(self.musicCh) then self.musicCh:Stop() end
	self.musicCh = nil
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	return AN.L("g09_status", self.score or 0, self.level or 1, self.lives or 3)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.score = 0
	self.level = 1
	self.lives = 3
	self.counting = false
	self.levelStartScore = 0
	self.ISON = false
	self.arenaStuff, self.radarStuff, self.points = {}, {}, {}
	self.vars = { score = 0 }
	self.root = FL.New(LIB, 0)
	FL.GotoAndStop(self.root, "gameon")
end

function G:Close()
	self:StopMusic()
	if CUR == self then CUR = nil end
end

function G:Step()
	FL.OnSound = function() end
	FL.Tick(self.root)
	for _, e in ipairs(self.arenaStuff) do FL.Tick(e.c) end
	for _, e in ipairs(self.radarStuff or {}) do FL.Tick(e.c) end
	for _, p in ipairs(self.points) do if p.c.visible then FL.Tick(p.c) end end
	FL.OnSound = nil
	self:MainLoop()
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
	self:StopMusic()
	AN.FinishGame(9, self.score or 0)
end

local function byDepth(a, b) return a.depth < b.depth end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(9) return end
	local game = self:Game()
	if game then
		local arena = FL.Child(game, "arena")
		if arena then
			table.sort(self.arenaStuff, byDepth)
			arena.extra = self.arenaStuff
		end
		local radar = FL.Child(game, "radar")
		if radar then radar.extra = self.radarStuff end
		local extra = {}
		for _, p in ipairs(self.points) do if p.c.visible then extra[#extra + 1] = { c = p.c, m = p.m } end end
		game.extra = extra
	end
	local st = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "txt_debug" then return "" end
		return st.vars[name]
	end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	if self.root.frame >= 16 and self.root.frame < 91 then
		UI.Button("g09_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(9)
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(9, G)
