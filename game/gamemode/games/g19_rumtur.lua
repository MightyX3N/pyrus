-- Låge 19: Rumtur ("Yang Eradicator")
-- Rebuilt from the original loader.swf. You fly a little space ship around the screen
-- (asteroids-style, the screen wraps around) and shoot the asteroids to pieces. Big ones split
-- into smaller ones, and some leave a crystal behind that is worth money when you fly over it.
-- When the screen is empty you get a bonus for your accuracy and your time, and the next level
-- starts with more and bigger rocks. 3 hits and the game is over. The score is your account.
-- The game code is the original's, quirks included:
--   * every crash costs both a ship and a life (both start at 3)
--   * a bullet can hit two rocks that overlap, so the accuracy can go above 100 %
--   * the teleporter (space) keeps its request when it is out of charges, so it fires the moment
--     you get some again (in the original that never happens in a game)
--   * holding "up" while the ship teleports or explodes builds up thrust for when it comes back
--   * Q moves four yellow test markers onto the ship's hit points (a left-over debug key)
--   * the quality menu in the top left corner works, but changes nothing here
-- Hidden content (setting "hidden"): the shop, the warp door and the gear in the file are never
-- used by the original - see the bottom of the file.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g19_fl.lua")

local G = {
	scoreType = "score",
	goal = 10000,     -- the original coolScore
	worst = 0,
	descKey = "desc_19",
	howKey = "how_19",
}

local STAGE_W, STAGE_H = 800, 600
local STEP = 1 / 25
local LIB = "g19"
local I = { 1, 0, 0, 1, 0, 0 }
local ASTROID_CID = { [0] = 115, 119, 111, 106, 113, 117, 109, 104 }
local BULLET_CID = { 101, 87, 91, 96 }
local MINERAL_CID = { [0] = 128, 123, 126 }

-- onClipEvent(load) { _visible = false }: hit areas (the ship's, the crystals', the warp door's)
FL.LoadHidden[LIB] = { [27] = true }

local CUR

---------------------------------------------------------------------------
-- the original's tables
---------------------------------------------------------------------------
local COOLER = {
	[0] = { name = "CHILL", value = 0.15, price = 340 },
	{ name = "WINTER", value = 0.25, price = 800 },
	{ name = "BLACK ICE", value = 0.4, price = 1500 },
}
local ENGINE = {
	[0] = { name = "FIRE", acc = 0.04, rotVel = 6, gfxID = 1, price = 300 },
	{ name = "FURY", acc = 0.07, rotVel = 10, gfxID = 2, price = 550 },
}
local SHIELD = {
	[0] = { name = "BUCKLER", max = 100, price = 150 },
	{ name = "KITE", max = 200, price = 300 },
	{ name = "TOWER", max = 500, price = 750 },
	{ name = "WARD", max = 1000, price = 1500 },
}
local BEAMER = {
	[0] = { name = "FLY", max = 3, gfxID = 1, price = 240 },
	{ name = "SCOTTY", max = 6, gfxID = 2, price = 420 },
}
local TURRET = {
	{ name = "ADDER", angle = 6, fireRate = 2, vel = 8, power = 1, heatStrain = 2, weight = 0.01, price = 600 },
	{ name = "VIPER", angle = 3, fireRate = 3, vel = 10, power = 2, heatStrain = 3, weight = 0.1, price = 1200 },
	{ name = "ANACONDA", angle = 12, fireRate = 25, vel = 5, power = 100, heatStrain = 10, weight = 0.5, price = 1550 },
	{ name = "COBRA", angle = -3, fireRate = 2, vel = 12, power = 3, heatStrain = 5, weight = 0.25, price = 2500 },
}
local function mm(a, b) return { min = a, max = b, range = b - a } end
local ASTROID = {
	[0] = { energy = 35, weight = 5, minVel = 2, maxVel = 2.5, minRotVel = 2, maxRotVel = 4, spawn = { 1, 2, 2, 3, 3, 3 }, prob = 1, mineral = 0, bx = mm(-80, 880), by = mm(-80, 620) },
	{ energy = 12, weight = 1.5, minVel = 1, maxVel = 2, minRotVel = 1, maxRotVel = 2, spawn = { 2, 2 }, prob = 1, mineral = 1, bx = mm(-40, 840), by = mm(-40, 580) },
	{ energy = 5, weight = 1, minVel = 2, maxVel = 4, minRotVel = 2, maxRotVel = 4, spawn = { 3, 3, 3, 3 }, prob = 0.5, mineral = 2, bx = mm(-25, 825), by = mm(-25, 565) },
	{ energy = 1, weight = 0.5, minVel = 3, maxVel = 6, minRotVel = 3, maxRotVel = 6, spawn = {}, prob = 0.3, mineral = 2, bx = mm(-10, 810), by = mm(-10, 550) },
	{ energy = 70, weight = 10, minVel = 2, maxVel = 2.5, minRotVel = 2, maxRotVel = 4, spawn = { 5, 6, 6, 7, 7, 7 }, prob = 1, mineral = 0, bx = mm(-80, 880), by = mm(-80, 620) },
	{ energy = 25, weight = 3, minVel = 1, maxVel = 2, minRotVel = 1, maxRotVel = 2, spawn = { 6, 6 }, prob = 1, mineral = 1, bx = mm(-40, 840), by = mm(-40, 580) },
	{ energy = 10, weight = 2, minVel = 2, maxVel = 4, minRotVel = 2, maxRotVel = 4, spawn = { 7, 7, 7, 7 }, prob = 0.5, mineral = 2, bx = mm(-25, 825), by = mm(-25, 565) },
	{ energy = 2, weight = 1, minVel = 3, maxVel = 6, minRotVel = 3, maxRotVel = 6, spawn = {}, prob = 0.3, mineral = 2, bx = mm(-10, 810), by = mm(-10, 550) },
}
local MINERAL = { [0] = { value = 600, lifeTime = 250 }, { value = 225, lifeTime = 200 }, { value = 60, lifeTime = 125 } }

-- areas[0].levels
local LEVELS = {
	{ 1 }, { 1, 1 }, { 1, 1, 2 }, { 1, 1, 1 }, { 1, 1, 1, 2 }, { 0, 1, 2 }, { 1, 1, 5 }, { 0, 1, 5 }, { 0, 1, 5, 6 },
	{ 4 }, { 4, 1 }, { 4, 1, 1 }, { 4, 1, 5 }, { 4, 1, 5, 6 }, { 4, 1, 5, 5 }, { 4, 5, 5, 5 }, { 4, 4, 5, 5 }, { 4, 4, 4, 5 },
}
local function levelList(l)
	if LEVELS[l] then return LEVELS[l] end
	if l < 999 then return { 4, 4, 4, 4 } end
	return { 3, 3 }    -- "auto adding astroids to level"
end

-- mc.hitTest(x, y, true) on a rock: how far its picture reaches from its centre, in 48 directions
-- (measured from the exported pictures)
local PROFILE = {
	[0] = { 45, 46, 48, 45, 43, 42, 43, 46.5, 49.5, 50, 52, 55, 60.5, 71.5, 81.5, 81.5, 82.5, 79, 72.5, 68, 64, 62, 61, 61, 61, 53.5, 48, 44.5, 43, 41.5, 41, 41, 42, 48, 50, 53, 57.5, 64, 79.5, 82, 87, 76, 67.5, 54.5, 50, 47.5, 46, 45 },
	[1] = { 42, 40, 39, 44, 42, 40.5, 39.5, 39, 39.5, 40.5, 42.5, 45, 44.5, 43, 42.5, 42, 43, 42.5, 42.5, 43.5, 45, 47.5, 49, 45.5, 42.5, 40.5, 39.5, 39, 39, 40.5, 42, 39, 37, 35, 34, 34, 34.5, 35.5, 36, 34.5, 34, 34, 34, 35.5, 37, 39.5, 43, 45 },
	[2] = { 30.5, 30.5, 32, 29.5, 29, 28.5, 28.5, 27, 25.5, 25, 25, 25, 25.5, 26, 24.5, 24, 24, 24, 25, 26, 28, 30.5, 34, 32, 29.5, 28.5, 27.5, 27, 27, 26.5, 25, 24, 23.5, 23, 23.5, 24, 25.5, 27, 29.5, 28.5, 29, 29, 30.5, 31.5, 33.5, 31.5, 30.5, 30 },
	[3] = { 9, 9, 9, 9, 9.5, 9.5, 10, 10.5, 11, 12, 12, 12, 11.5, 11.5, 11.5, 12.5, 12, 11.5, 10.5, 9.5, 9.5, 8.5, 9, 8.5, 9, 9, 9.5, 10.5, 12, 12, 11.5, 11, 10.5, 11, 10.5, 11.5, 12, 11.5, 11.5, 11.5, 12, 13, 13, 11.5, 11, 10.5, 10, 9.5 },
	[4] = { 55, 55.5, 53.5, 52.5, 52.5, 53.5, 52.5, 51.5, 50.5, 51, 52.5, 47.5, 42, 38.5, 35.5, 34, 33, 39, 51.5, 53.5, 55, 55, 55.5, 57, 56.5, 55, 53, 46.5, 43, 41.5, 41.5, 43, 50, 51, 51.5, 52.5, 53, 53.5, 56, 56, 61, 60.5, 57.5, 56, 60.5, 57, 55.5, 54.5 },
	[5] = { 16, 19.5, 25.5, 41, 59.5, 49, 40, 34.5, 30.5, 27.5, 25.5, 47, 39.5, 34, 26, 30, 37.5, 39.5, 55, 38, 25, 21, 19, 17.5, 17, 16, 16, 15.5, 16, 17, 17.5, 19.5, 25.5, 41.5, 52, 39.5, 32.5, 31, 30.5, 14, 12.5, 11.5, 11, 11, 11.5, 11.5, 12.5, 14 },
	[6] = { 23, 21.5, 21.5, 21, 21, 21.5, 22.5, 23.5, 20.5, 19, 17.5, 16.5, 16.5, 16, 16, 16.5, 17, 18, 17.5, 18, 18, 22.5, 23.5, 22.5, 22.5, 21.5, 22, 22.5, 23, 24.5, 25.5, 28, 26, 24.5, 24.5, 24, 23.5, 24, 24.5, 25.5, 22.5, 21.5, 20.5, 21.5, 25.5, 25.5, 26, 24.5 },
	[7] = { 17.5, 15.5, 14.5, 13.5, 13, 12.5, 12.5, 12.5, 12, 12.5, 12.5, 12.5, 13.5, 14.5, 16, 18.5, 20.5, 21, 18, 16, 13.5, 12, 11.5, 10.5, 10, 10, 10, 10, 10, 10.5, 10.5, 9.5, 8.5, 8, 7.5, 7.5, 7.5, 7.5, 7.5, 9, 10, 10.5, 12, 14, 15.5, 15, 16, 16.5 },
}

local function rotM(deg, x, y, sx, sy)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	sx, sy = sx or 1, sy or sx or 1
	return { c * sx, s * sx, -s * sy, c * sy, x, y }
end

local function hiddenOn() return AN.Save.Get("hidden") ~= false end

---------------------------------------------------------------------------
-- sounds: the game's sound module ("background" sounds loop until stopped)
---------------------------------------------------------------------------
local LOOPS = { thrust = true, shield = true, warpactive = true }

function G:PlaySound(name)
	name = string.gsub(name, " ", "_")
	if not LOOPS[name] then MG.Sound("g19", name) return end
	if self.loops[name] then return end
	self.loops[name] = "loading"
	if AN.SoundMode() == 2 then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100
	if v <= 0 then return end
	local me = self
	sound.PlayFile("sound/alletidersnisse/g19/" .. name .. ".mp3", "noplay noblock", function(ch)
		if not IsValid(ch) then return end
		if CUR ~= me or me.loops[name] ~= "loading" then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		me.loops[name] = ch
	end)
end

function G:StopSound(name)
	local ch = self.loops[name]
	if ch and ch ~= "loading" and IsValid(ch) then ch:Stop() end
	self.loops[name] = nil
end

function G:StopAllSounds()
	for name in pairs(self.loops) do self:StopSound(name) end
end

---------------------------------------------------------------------------
-- frame scripts
---------------------------------------------------------------------------
local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 0, {
		[2] = function(c) FL.GotoAndPlay(c, "game on") end,    -- the preloader: everything is loaded
		[14] = function(c) stop(c) if CUR then CUR:InitGame(0) end end,
		[23] = function(c) AN.Speak("GameOverIngenLiv") FL.Play(c) end,
		[99] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	FL.SetActions(LIB, 605, {
		[1] = stop,
		[15] = stop,
		[20] = function() if CUR then CUR.endTime = CUR.ms end end,
		[37] = function(c) stop(c) if CUR then CUR:GiveBonus(c) end end,
		[71] = function(c) stop(c) if CUR then FL.GotoAndStop(CUR.root, "game over") end end,
		[80] = function() if CUR then CUR:OpenShop() end end,
		[89] = function(c) stop(c) if CUR then CUR:ShopAccountAppear() end end,
		[103] = function(c) stop(c) if CUR then FL.GotoAndStop(CUR.root, "game over") end end,
	})
	FL.SetActions(LIB, 60, {
		[1] = stop,
		[9] = function(c) FL.Play(c) end,
		[17] = function() if CUR then CUR:ShipWarpGone() end end,
		[22] = function(c) FL.Play(c) end,
		[30] = function() if CUR then CUR:ShipWarpArrived() end end,
		[46] = function(c)
			if CUR then CUR:PlaySound("shipexplode") end
			AN.Speak("MisterLiv")
			FL.Play(c)
		end,
		[80] = function(c) stop(c) if CUR then CUR:ShipExplodeAniDone() end end,
	})
	local ASTEND = { [115] = 59, [119] = 57, [111] = 56, [106] = 55, [113] = 59, [117] = 57, [109] = 56, [104] = 55 }
	for cid, f in pairs(ASTEND) do
		FL.SetActions(LIB, cid, {
			[1] = stop,
			[f] = function(c) if c.astroidRef then c.astroidRef.state = 3 end stop(c) end,
		})
	end
	for _, cid in ipairs(BULLET_CID) do
		FL.SetActions(LIB, cid, {
			[1] = stop,
			[10] = function(c) FL.Play(c) end,
			[13] = function(c) if c.ref then c.ref.state = 3 end stop(c) end,
		})
	end
	for _, cid in pairs(MINERAL_CID) do
		local rm = function(c) if CUR then CUR:RemoveClip(c) end end
		FL.SetActions(LIB, cid, {
			[1] = stop, [9] = function(c) FL.Play(c) end, [16] = rm,
			[21] = function(c) FL.Play(c) end, [28] = rm,
		})
	end
	-- the warp door: onClipEvent(load) gotoAndStop("gone")
	FL.SetActions(LIB, 166, { [1] = function(c) FL.GotoAndStop(c, "gone") end, [62] = stop })
	FL.SetActions(LIB, 165, {
		[41] = function() if CUR then CUR:PlaySound("warpactive") end end,
		[59] = function(c) stop(c) if CUR then CUR.warpDoorActive = true end end,
		[93] = function(c) if c.parent then FL.GotoAndStop(c.parent, "gone") end end,
	})
	FL.SetActions(LIB, 164, { [29] = function(c) FL.GotoAndPlay(c, 1) end })
	FL.SetActions(LIB, 202, { [1] = stop })
	-- the quality menu
	FL.SetActions(LIB, 259, {
		[1] = function(c) stop(c) c.vars.abort = false end,
		[13] = stop,
	})
	FL.SetActions(LIB, 256, { [1] = function(c)
		stop(c)
		-- onClipEvent(load): gotoAndStop(dataholder.gameQuality)
		if CUR and CUR.quality and CUR.quality ~= "high" then FL.GotoAndStop(c, CUR.quality) end
	end })
	-- the shop's clips (hidden content)
	for _, cid in ipairs({ 296, 364, 387, 392, 395, 508, 511, 522, 528 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
	G.SetupShopActions()
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function G:Main() return FL.Child(self.root, "main") end
function G:Arena() return FL.Child(self:Main(), "arena") end
function G:Statusbar() return FL.Child(self:Main(), "statusbar") end

-- a named child's _rotation / _yscale, keeping the rest of its placed matrix
local function baseItem(c, name)
	for _, it in ipairs(FL.Items(c)) do
		if it.nm and string.lower(it.nm) == name then return it, c.kids[it[3]] end
	end
end
local function setRotation(c, name, deg)
	local it, k = baseItem(c, name)
	if not it or not k then return end
	local sx = math.sqrt(it[4] * it[4] + it[5] * it[5])
	local sy = math.sqrt(it[6] * it[6] + it[7] * it[7])
	local a = math.rad(deg)
	k.mat = { math.cos(a) * sx, math.sin(a) * sx, -math.sin(a) * sy, math.cos(a) * sy, it[8], it[9] }
end
local function setYScale(c, name, pct)
	local it, k = baseItem(c, name)
	if not it or not k then return end
	k.mat = { it[4], it[5], it[6], pct / 100, it[8], it[9] }
end

-- attachMovie into the arena: a clip at a depth (a clip already there is replaced)
function G:Attach(cid, depth, obj)
	local c = FL.New(LIB, cid)
	c.depth = depth
	self.dyn[depth] = { c = c, o = obj }
	return c
end
function G:RemoveClip(c)
	if c and c.depth and self.dyn[c.depth] and self.dyn[c.depth].c == c then self.dyn[c.depth] = nil end
end

function G:Status()
	return AN.L("g19_status", self.hero and self.hero.credits or 0, self.level or 1, self.hero and self.hero.lives or 3)
end

-- a rock's picture under the stage point (x, y)?
function G:AstroidHitPoint(a, x, y)
	local prof = PROFILE[a.type]
	if not prof then return false end
	local dx, dy = x - a.mcx, y - a.mcy
	local r = math.rad(a.mcrot)
	local lx = dx * math.cos(r) + dy * math.sin(r)
	local ly = -dx * math.sin(r) + dy * math.cos(r)
	local d = math.sqrt(lx * lx + ly * ly)
	if d > 90 then return false end
	local n = #prof
	local ang = math.atan2(ly, lx) % (2 * math.pi)
	local f = ang / (2 * math.pi) * n
	local i0 = math.floor(f) % n
	local i1 = (i0 + 1) % n
	local t = f - math.floor(f)
	local lim = prof[i0 + 1] * (1 - t) + prof[i1 + 1] * t
	return d <= lim
end

function G:ShipM()
	local s = self.ship
	return rotM(s.mcRot, s.mcX, s.mcY, s.mcScale / 100)
end

---------------------------------------------------------------------------
-- the original game code
---------------------------------------------------------------------------
function G:InitGame(miss)
	FL.GotoAndPlay(self:Main(), "game")
	self.hero = { credits = 0, lives = 3, ships = 3, minerals = 0, cargo = 0, areaCargo = 0 }
	self:InitShip()
	self:InitShop()
	self.hero.minerals = 0
	self:StartMission(miss)
end

function G:StartMission(miss)
	self.curMission = miss
	self.curStage = -1
	self:NextStage()
end

function G:NextStage()
	self.curStage = self.curStage + 1
	if self.curStage < 1 then
		self.area = 0
		self:InitLevel(1)
	else
		FL.GotoAndPlay(self:Main(), "missioncompleted")
	end
end

function G:InitShip()
	local ship = {
		mc = self:Attach(60, 4000),
		insurance = 0, escapeCapsule = false, dize = false, accelerating = false,
		beamers = { type = 0, amount = 0, max = 0 },
		shield = { type = 0, amount = 0, max = 0, engaged = false },
		engine = { type = 0, acc = 0, rotVel = 0 },
		turrets = {},
		phys = { x = 0, y = 0, vx = 0, vy = 0, acc = 0, rot = 0 },
		hitpoints = {},
		safeFrames = 0, ejected = false, state = 0,
		mcX = 0, mcY = 0, mcRot = 0, mcScale = 100, visible = true, fireVisible = true,
	}
	for t = 0, 2 do
		ship.turrets[t] = { type = -1, x = 0, y = 0, angle = 0, fireRate = 0, lastShot = 0, vel = 0, power = 0, temp = 0,
			cooler = { type = 0, value = 0 }, heatStrain = 0, bulletNB = 0, bullets = {} }
	end
	for h = 0, 5 do ship.hitpoints[h] = { x = 0, y = 0 } end
	self.ship = ship
	self:InstallBeamer(0)
	ship.beamers.amount = 3
	self:InstallShield(0)
	self:InstallEngine(0)
	self:InstallTurret(0, 1)
	self:InstallCooler(0, 0)
	self:InstallTurret(1, -1)
	self:InstallCooler(1, 0)
	self:InstallTurret(2, -1)
	self:InstallCooler(2, 0)
end

function G:InstallTurret(place, tp)
	local t = self.ship.turrets[place]
	local T = TURRET[tp] or {}
	t.type = tp
	t.angle, t.fireRate, t.vel, t.power, t.heatStrain = T.angle, T.fireRate, T.vel, T.power, T.heatStrain
	local sb = self:Statusbar()
	local mc = sb and FL.Child(sb, "turret" .. place)
	if not mc then return end
	if tp == -1 then FL.GotoAndStop(mc, "empty")
	elseif tp == 0 then FL.GotoAndStop(mc, "nogun")
	else
		FL.GotoAndStop(mc, "gun")
		mc.vars.txt_name = T.name
		setRotation(mc, "needle", 0)
		mc.vars.txt_temp = 0
	end
end
function G:InstallEngine(tp)
	local e = self.ship.engine
	e.type, e.acc, e.rotVel = tp, ENGINE[tp].acc, ENGINE[tp].rotVel
end
function G:InstallCooler(place, tp)
	local c = self.ship.turrets[place].cooler
	c.type, c.value = tp, COOLER[tp].value
end
function G:InstallShield(tp)
	local s = self.ship.shield
	s.type, s.amount, s.max = tp, SHIELD[tp].max, SHIELD[tp].max
end
function G:InstallBeamer(tp)
	local b = self.ship.beamers
	b.type, b.max = tp, BEAMER[tp].max
	self:ShowBeamers()
end
function G:ShowBeamers()
	local sb = self:Statusbar()
	local bm = sb and FL.Child(sb, "beamers")
	if not bm then return end
	FL.GotoAndStop(bm, BEAMER[self.ship.beamers.type].gfxID)
	local gfx = FL.Child(bm, "gfx")
	if gfx then FL.GotoAndStop(gfx, self.ship.beamers.amount + 1) end
end

function G:InitLevel(lvl)
	self.gameState = 1
	FL.GotoAndPlay(self:Main(), "game")
	self.level = lvl
	self.warpDoorActive = false
	self.secFrm = 0
	self.shotsFired = 0
	self.shotsHit = 0
	self.minerals = {}
	self.mineralNB = 0
	self:InitAstroids()
	self.enemies = {}
	local sb = self:Statusbar()
	for t = 0, 2 do
		local tur = self.ship.turrets[t]
		local mc = sb and FL.Child(sb, "turret" .. t)
		if mc then
			if tur.type == -1 then FL.GotoAndStop(mc, "empty")
			elseif tur.type == 0 then FL.GotoAndStop(mc, "nogun")
			else
				FL.GotoAndStop(mc, "gun")
				mc.vars.txt_name = TURRET[tur.type].name
				setRotation(mc, "needle", 0)
				mc.vars.txt_temp = 0
			end
		end
	end
	self:SetStatus()
	self:ShowBeamers()
	self:ShowShieldBar()
	self.startTime = self.ms
	self:RespawnShip()
end

function G:SetStatus()
	local sb = self:Statusbar()
	if not sb then return end
	sb.vars.ships = self.hero.ships
	sb.vars.lives = self.hero.lives
	sb.vars.cargo = self.hero.cargo
	sb.vars.credits = self.hero.credits
end

function G:ShowShieldBar()
	local sb = self:Statusbar()
	local sh = sb and FL.Child(sb, "shield")
	if sh then setYScale(sh, "bar", self.ship.shield.amount / self.ship.shield.max * 100) end
end

function G:InitAstroids()
	self.astroids = {}
	self.nextAstroidID = 0
	for _, tp in ipairs(levelList(self.level)) do
		local x, y
		repeat
			x = math.random() * 800
			y = math.random() * 600
		until (x - 400) * (x - 400) + (y - 300) * (y - 300) > 20000
		self:SpawnAstroid(tp, x, y)
	end
end

function G:SpawnAstroid(tp, x, y)
	local T = ASTROID[tp]
	local a = { type = tp, x = x, y = y, vx = 0, vy = 0 }
	a.mc = self:Attach(ASTROID_CID[tp], 2000 + self.nextAstroidID, a)
	a.mc.astroidRef = a
	repeat
		local speed = T.minVel + math.random() * (T.maxVel - T.minVel)
		local dir = math.floor(math.random() * 360)
		a.vx = math.cos(math.rad(dir)) * speed * 1   -- areas[0].speedFactor
		a.vy = math.sin(math.rad(dir)) * speed * 1
	until math.abs(a.vx) > 0.3 and math.abs(a.vy) > 0.3
	a.rot = math.floor(math.random() * 360)
	local rv = T.minRotVel + math.random() * (T.maxRotVel - T.minRotVel)
	if math.random() < 0.5 then rv = -rv end
	a.rotVel = rv
	a.mcx, a.mcy, a.mcrot = x, y, 0
	a.energy = T.energy
	a.weight = T.weight
	a.state = 1
	table.insert(self.astroids, a)
	self.nextAstroidID = self.nextAstroidID + 1
end

function G:RespawnShip()
	local ship = self.ship
	local p = ship.phys
	p.vx, p.vy, p.acc = 0, 0, 0
	p.x, p.y = 400, 270
	p.rot = -90
	ship.mcX, ship.mcY, ship.mcRot = p.x, p.y, p.rot
	ship.mcScale = 100
	FL.GotoAndStop(ship.mc, "normal")
	local sb = self:Statusbar()
	for t = 0, 2 do
		local tur = ship.turrets[t]
		if tur.type > 0 then
			tur.temp = 0
			local mc = sb and FL.Child(sb, "turret" .. t)
			if mc then
				setRotation(mc, "needle", 0)
				mc.vars.txt_temp = 0
			end
		end
	end
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	if not ship.escapeCapsule then self.ejectVisible = false end
	self.warpRequest = false
	self.ejectRequest = false
	ship.safeFrames = 75
	ship.ejected = false
	ship.state = 1
	self.gameState = 2
end

function G:UpdateShip()
	local ship = self.ship
	if ship.state ~= 1 then return end
	if self.warpRequest and ship.beamers.amount > 0 then
		self.warpRequest = false
		self:ShipWarpStart(1)
		return
	elseif self.ejectRequest then
		self.ejectRequest = false
		self:ShipEject()
		return
	end
	local p = ship.phys
	self.heroCos = math.cos(math.rad(p.rot))
	self.heroSin = math.sin(math.rad(p.rot))
	p.acc = p.acc * 0.985
	p.vx = p.vx * 0.98
	p.vy = p.vy * 0.98
	p.vx = p.vx + p.acc * self.heroCos
	p.vy = p.vy + p.acc * self.heroSin
	p.x = p.x + p.vx
	p.y = p.y + p.vy
	if p.x < 0 then p.x = p.x + 800 elseif p.x > 800 then p.x = p.x - 800 end
	if p.y < 0 then p.y = p.y + 540 elseif p.y > 540 then p.y = p.y - 540 end
	ship.mcX, ship.mcY, ship.mcRot = p.x, p.y, p.rot
	local M = self:ShipM()
	for t = 0, 5 do
		local m = FL.ChildMatrix(ship.mc, "hitpoint" .. t, M)
		if m then ship.hitpoints[t].x, ship.hitpoints[t].y = m[5], m[6] end
	end
	-- (the original only works out where turret 0 is)
	local nTur = self.fixTurrets and 2 or 0
	for t = 0, nTur do
		local m = FL.ChildMatrix(ship.mc, "turret" .. t, M)
		if m then ship.turrets[t].x, ship.turrets[t].y = m[5], m[6] end
	end
	if self.shootRequest then
		self.shootRequest = false
		self:FireBullets()
	end
	local sb = self:Statusbar()
	for t = 0, 2 do
		local tur = ship.turrets[t]
		if tur.type > 0 then
			tur.temp = math.max(0, tur.temp - tur.cooler.value)
			local mc = sb and FL.Child(sb, "turret" .. t)
			if mc then
				setRotation(mc, "needle", tur.temp * 1.8)
				mc.vars.txt_temp = math.floor(tur.temp)
			end
			tur.lastShot = tur.lastShot + 1
		end
	end
	if self.shieldRequest then
		if ship.shield.amount > 0 then
			if not ship.shield.engaged then
				ship.shield.engaged = true
				self:PlaySound("shield")
			end
			ship.shield.amount = ship.shield.amount - 1
			self:ShowShieldBar()
		elseif ship.shield.engaged then
			ship.shield.engaged = false
			self:StopSound("shield")
		end
	else
		ship.shield.engaged = false
		self:StopSound("shield")
	end
	if ship.safeFrames > 0 then
		ship.safeFrames = ship.safeFrames - 1
		if ship.safeFrames % 2 == 0 then
			ship.visible = ship.safeFrames % 4 == 0
		end
	end
end

function G:ShipCrash()
	local ship = self.ship
	ship.state = 3
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	FL.GotoAndPlay(ship.mc, "explode")
end

function G:ShipExplodeAniDone()
	local ship = self.ship
	local hero = self.hero
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	if ship.insurance > 0 then
		ship.insurance = ship.insurance - 1
	else
		self:InstallBeamer(0)
		ship.beamers.amount = 3
		self:ShowBeamers()
		self:InstallEngine(0)
		self:InstallShield(0)
		self:InstallTurret(0, 1)
		self:InstallCooler(0, 0)
		self:InstallTurret(1, -1)
		self:InstallCooler(1, 0)
		self:InstallTurret(2, -1)
		self:InstallCooler(2, 0)
		ship.escapeCapsule = false
		ship.dize = false
		hero.ships = hero.ships - 1
	end
	if not ship.ejected then hero.lives = hero.lives - 1 end
	if hero.lives == 0 or hero.ships == 0 then
		self:GameOver()
	else
		ship.shield.amount = ship.shield.max
		self:ShowShieldBar()
		self:RespawnShip()
	end
	local sb = self:Statusbar()
	if sb then sb.vars.ships = hero.ships sb.vars.lives = hero.lives end
end

function G:ShipWarpStart(val)
	local ship = self.ship
	self:PlaySound("ship beam")
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	ship.state = 2
	ship.beamers.amount = ship.beamers.amount - val
	local sb = self:Statusbar()
	local bm = sb and FL.Child(sb, "beamers")
	local gfx = bm and FL.Child(bm, "gfx")
	if gfx then FL.GotoAndStop(gfx, ship.beamers.amount + 1) end
	ship.phys.vx, ship.phys.vy, ship.phys.acc = 0, 0, 0
	FL.GotoAndPlay(ship.mc, "warpgoing")
	if ship.shield.engaged then
		ship.shield.engaged = false
		self:StopSound("shield")
	end
end

function G:ShipWarpGone()
	local ship = self.ship
	if self.gameState == 5 then
		FL.GotoAndPlay(self:Main(), "levelstats")
		FL.Stop(ship.mc)
	else
		ship.phys.x = 100 + math.random() * 600
		ship.phys.y = 100 + math.random() * 400
		ship.mcX, ship.mcY = ship.phys.x, ship.phys.y
		FL.GotoAndPlay(ship.mc, "warpcoming")
	end
end

function G:ShipWarpArrived()
	local ship = self.ship
	FL.GotoAndStop(ship.mc, "normal")
	ship.state = 1
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	AN.Speak("aarhhvad")
end

function G:ShipEject()
	local ship = self.ship
	ship.accelerating = false
	ship.fireVisible = false
	self:StopSound("thrust")
	self:StopSound("shield")
	ship.ejected = true
	ship.state = 3
	FL.GotoAndPlay(ship.mc, "explode")
	if ship.shield.engaged then
		ship.shield.engaged = false
		self:StopSound("shield")
	end
end

function G:IsOnScreen(x, y)
	return x > 0 and x < 800 and y > 0 and y < 540
end

function G:UpdateBullets()
	local ship = self.ship
	for t = 0, 2 do
		local list = ship.turrets[t].bullets
		for b = #list, 1, -1 do
			local bl = list[b]
			if bl.state == 1 then
				bl.x, bl.y = bl.x + bl.vx, bl.y + bl.vy
				if not self:IsOnScreen(bl.x, bl.y) then
					self:RemoveClip(bl.mc)
					table.remove(list, b)
				else
					for a = #self.astroids, 1, -1 do
						local ast = self.astroids[a]
						if ast.state == 1 and self:AstroidHitPoint(ast, bl.x, bl.y) then
							self.shotsHit = self.shotsHit + 1
							local w = bl.weight / ast.weight
							self:AstroidHit(a, bl.power, { x = bl.vx * w, y = bl.vy * w })
							FL.GotoAndPlay(bl.mc, "dying")
							bl.state = 2
						end
					end
				end
			elseif bl.state == 3 then
				self:RemoveClip(bl.mc)
				table.remove(list, b)
			end
		end
	end
end

function G:FireBullets()
	local ship = self.ship
	for t = 0, 2 do
		local tur = ship.turrets[t]
		if tur.type > 0 and tur.temp <= 100 - tur.heatStrain and tur.fireRate <= tur.lastShot then
			self:PlaySound("firebullet" .. tur.type)
			self.shotsFired = self.shotsFired + 1
			local bl = { state = 1 }
			bl.mc = self:Attach(BULLET_CID[tur.type], 50000 + 10000 * t + tur.bulletNB, bl)
			tur.temp = tur.temp + tur.heatStrain
			tur.lastShot = 0
			local c, s
			if t == 0 then
				c, s = self.heroCos, self.heroSin
			elseif t == 1 then
				c, s = math.cos(math.rad(ship.phys.rot + tur.angle)), math.sin(math.rad(ship.phys.rot + tur.angle))
			else
				c, s = math.cos(math.rad(ship.phys.rot - tur.angle)), math.sin(math.rad(ship.phys.rot - tur.angle))
			end
			bl.x, bl.y = tur.x, tur.y
			bl.vx = c * tur.vel + ship.phys.vx
			bl.vy = s * tur.vel + ship.phys.vy
			bl.mc.ref = bl
			FL.GotoAndStop(bl.mc, "active")
			bl.weight = TURRET[tur.type].weight
			bl.power = TURRET[tur.type].power
			table.insert(tur.bullets, bl)
			tur.bulletNB = tur.bulletNB + 1
		end
	end
end

function G:RemoveBullets()
	for t = 0, 2 do
		local list = self.ship.turrets[t].bullets
		for b = #list, 1, -1 do
			self:RemoveClip(list[b].mc)
			table.remove(list, b)
		end
	end
end

function G:UpdateAstroids()
	local ship = self.ship
	for i = #self.astroids, 1, -1 do
		local a = self.astroids[i]
		if a.state == 1 then
			local T = ASTROID[a.type]
			a.x, a.y = a.x + a.vx, a.y + a.vy
			a.rot = a.rot + a.rotVel
			if a.x < T.bx.min then a.x = a.x + T.bx.range elseif a.x > T.bx.max then a.x = a.x - T.bx.range end
			if a.y < T.by.min then a.y = a.y + T.by.range elseif a.y > T.by.max then a.y = a.y - T.by.range end
			a.mcx, a.mcy, a.mcrot = a.x, a.y, a.rot
			if ship.safeFrames == 0 and not ship.shield.engaged and ship.state == 1 then
				for h = 0, 5 do
					local hp = ship.hitpoints[h]
					if self:AstroidHitPoint(a, hp.x, hp.y) then self:ShipCrash() end
				end
			end
		end
	end
end

function G:AstroidHit(id, power, relWeight)
	local a = self.astroids[id]
	self:PlaySound("bullethitrock")
	a.energy = a.energy - power
	if a.energy <= 0 then
		self:KillAstroid(id, relWeight)
	else
		a.vx = a.vx + relWeight.x
		a.vy = a.vy + relWeight.y
	end
end

function G:KillAstroid(id, relWeight)
	local a = self.astroids[id]
	local T = ASTROID[a.type]
	self:PlaySound("exploderock" .. (a.type % 4))
	a.state = 2
	FL.GotoAndPlay(a.mc, "dying")
	if math.random() < T.prob then
		local len = math.sqrt(relWeight.x * relWeight.x + relWeight.y * relWeight.y)
		local sp = 0.5 + math.random() * 0.5
		local vx, vy = relWeight.x / len * sp, relWeight.y / len * sp
		if len == 0 then vx, vy = 0 / 0, 0 / 0 end
		self:SpawnMineral(T.mineral, a.x, a.y, vx, vy)
	end
	for _, tp in ipairs(T.spawn) do self:SpawnAstroid(tp, a.x, a.y) end
end

function G:RemoveDeadAstroids()
	for i = #self.astroids, 1, -1 do
		-- (the original removes "mc", which is nothing there: the finished clip stays where it is)
		if self.astroids[i].state == 3 then table.remove(self.astroids, i) end
	end
end

function G:SpawnMineral(tp, x, y, vx, vy)
	local m = { x = x, y = y, vx = vx, vy = vy, rot = 0, age = 0, state = 1 }
	m.mc = self:Attach(MINERAL_CID[tp], 1000 + self.mineralNB, m)
	m.value = MINERAL[tp].value
	m.lifeTime = MINERAL[tp].lifeTime
	table.insert(self.minerals, m)
	self.mineralNB = self.mineralNB + 1
end

function G:UpdateMinerals()
	local ship = self.ship
	local hm, hk = FL.ChildMatrix(ship.mc, "hitarea", self:ShipM())
	local bx0, by0, bx1, by1
	if hk then bx0, by0, bx1, by1 = FL.Bounds(hk, hm, true) end
	for i = #self.minerals, 1, -1 do
		local m = self.minerals[i]
		m.x, m.y = m.x + m.vx, m.y + m.vy
		if m.x < 0 then m.x = m.x + 800 elseif m.x > 800 then m.x = m.x - 800 end
		if m.y < 0 then m.y = m.y + 540 elseif m.y > 540 then m.y = m.y - 540 end
		m.rot = m.rot + 1
		local hit = false
		if bx0 then
			local ax0, ay0, ax1, ay1 = FL.Bounds(m.mc, rotM(m.rot, m.x, m.y), true)
			hit = ax0 and ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1
		end
		if hit then
			self:PlaySound("mineralpickup")
			self.hero.cargo = self.hero.cargo + m.value
			self.hero.credits = self.hero.credits + m.value
			local sb = self:Statusbar()
			if sb then sb.vars.cargo = self.hero.cargo sb.vars.credits = self.hero.credits end
			FL.GotoAndPlay(m.mc, "pickup")
			table.remove(self.minerals, i)
		else
			m.age = m.age + 1
			if m.age >= m.lifeTime then
				self:PlaySound("mineraldisappear")
				FL.GotoAndPlay(m.mc, "disappear")
				table.remove(self.minerals, i)
			end
		end
	end
end

function G:CheckKeys()
	local gs = self.gameState
	local ship = self.ship
	if gs == 2 or gs == 4 then
		if input.IsKeyDown(KEY_UP) then
			ship.phys.acc = ship.phys.acc + ship.engine.acc
			if ship.state == 1 and not ship.accelerating then
				ship.accelerating = true
				ship.fireVisible = true
				self:PlaySound("thrust")
			end
		else
			ship.phys.acc = 0
			if ship.state == 1 and ship.accelerating then
				ship.accelerating = false
				ship.fireVisible = false
				self:StopSound("thrust")
			end
		end
		if input.IsKeyDown(KEY_SPACE) then
			if self.warpOK then
				self.warpOK = false
				self.warpRequest = true
			end
		else
			self.warpOK = true
		end
		if input.IsKeyDown(KEY_RIGHT) then
			ship.phys.rot = ship.phys.rot + ship.engine.rotVel
		elseif input.IsKeyDown(KEY_LEFT) then
			ship.phys.rot = ship.phys.rot - ship.engine.rotVel
		end
		if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) or input.IsKeyDown(KEY_C) then
			if self.shootOK then
				self.shootOK = false
				self.shootRequest = true
			end
		else
			self.shootOK = true
		end
		self.shieldRequest = input.IsKeyDown(KEY_DOWN)
		if input.IsKeyDown(KEY_E) and ship.escapeCapsule then self.ejectRequest = true end
		if input.IsKeyDown(KEY_Q) then
			-- the test markers onto the hit points
			for t = 0, 3 do
				self.tests[t] = { x = ship.hitpoints[t].x, y = ship.hitpoints[t].y }
			end
		end
	elseif gs == 5 then
		local main = self:Main()
		if input.IsKeyDown(KEY_ENTER) and main and main.frame == 37 then
			if self.spaceOK then
				self.spaceOK = false
				self:LevelCompleted()
			end
		else
			self.spaceOK = true
		end
	end
end

function G:CheckLevelComplete()
	if #self.astroids == 0 and #self.minerals == 0 and #self.enemies == 0 and self.ship.state == 1 then
		self.gameState = 4
		if hiddenOn() then
			self:OpenWarpDoor()
		else
			FL.GotoAndPlay(self:Main(), "levelstats")
		end
	end
end

-- frame 37 of the game clip: the level's bonus
function G:GiveBonus(c)
	self.gameState = 5
	AN.Speak("HuskeSpillet_LevelSlut")
	local v = c.vars
	v.txt_level = self.level
	-- (no shots at all gives NaN in the original, which would wreck the score: count it as 0 %)
	local acc = self.shotsFired > 0 and math.Round(1000 * self.shotsHit / self.shotsFired) / 10 or 0
	local accScore
	if acc == 100 then accScore = 5000 * 2 else accScore = math.Round(5000 * acc / 100) end
	local startCredits = self.levelStartCredits or 0
	self.hero.credits = self.hero.credits + accScore
	local s = tostring(acc)
	if string.sub(s, -2, -2) ~= "." then s = s .. ".0" end
	v.txt_accpct = s
	v.txt_accscore = accScore
	local timeSpent = math.floor(self.endTime - self.startTime)
	local mins = math.floor(timeSpent / 60000)
	local secs = math.floor(timeSpent / 1000) - mins * 60
	v.txt_mins = mins
	v.txt_secs = secs == 0 and "00" or (secs < 10 and "0" .. secs or secs)
	local hund = math.floor(timeSpent / 10) % 100
	v.txt_hundreds = hund == 0 and "00" or (hund < 10 and "0" .. hund or hund)
	local timeScore
	if timeSpent <= 30000 then
		timeScore = 5000 * 2
	else
		timeScore = math.max(0, math.Round(5000 * ((90000 - (timeSpent - 30000)) / 90000)))
	end
	v.txt_timescore = timeScore
	self.hero.credits = self.hero.credits + timeScore
	AN.LevelScore(19, self.level, self.hero.credits - startCredits, { total = self.hero.credits })
	self.levelStartCredits = self.hero.credits
end

function G:LevelCompleted()
	self:StopSound("thrust")
	self:StopSound("shield")
	self.gameState = 3
	self:RemoveBullets()
	if hiddenOn() and not self.shopDone then
		self:AreaCompleted()
		return
	end
	self.shopDone = false
	self:InitLevel(self.level + 1)
end

function G:GameOver()
	self.root.vars.score = self.hero.credits
	self.gameState = 7
	FL.GotoAndPlay(self:Main(), "gameover")
end

function G:MainLoop()
	local gs = self.gameState
	if gs == 2 then
		self:CheckKeys()
		if self.ship.state == 1 then self:UpdateShip() end
		self:UpdateAstroids()
		self:UpdateBullets()
		self:UpdateMinerals()
		self.secFrm = self.secFrm + 1
		if self.secFrm >= 25 then
			self.secFrm = 0
			self:RemoveDeadAstroids()
			if self.ship.state == 1 then self:CheckLevelComplete() end
		end
	elseif gs == 4 then
		self:CheckKeys()
		if self.ship.state == 1 then
			if self.warpDoorActive then self:ApplyBlackHole() end
			self:UpdateShip()
			self:CheckWarpDoorHit()
		end
		self:UpdateBullets()
	elseif gs == 5 then
		self:CheckKeys()
	elseif gs == 6 then
		self:UpdateGunrack()
	elseif gs == 7 then
		self:UpdateBullets()
		self:UpdateAstroids()
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.ms = 0
	self.dyn = {}
	self.loops = {}
	self.tests = {}
	self.testClips = {}
	self.astroids = {}
	self.minerals = {}
	self.enemies = {}
	self.gameState = nil
	self.ship = nil
	self.hero = nil
	self.level = 1
	self.quality = "high"
	self.shopDone = false
	self.fixTurrets = hiddenOn()
	self.root = FL.New(LIB, 0)
end

function G:Close()
	self:StopAllSounds()
	if CUR == self then CUR = nil end
end

function G:Step()
	self.ms = self.ms + 40
	FL.OnSound = function(c, id) MG.Sound("g19", "s" .. id) end
	FL.Tick(self.root)
	local ks = {}
	for d in pairs(self.dyn) do ks[#ks + 1] = d end
	table.sort(ks)
	for _, d in ipairs(ks) do
		local e = self.dyn[d]
		if e then FL.Tick(e.c) end
	end
	FL.OnSound = nil
	-- the game clip's enterFrame (only while it is on the stage)
	if self.gameState and self:Main() then self:MainLoop() end
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
	self:StopAllSounds()
	AN.FinishGame(19, self.hero and self.hero.credits or 0)
end

-- the clips made at run time, in depth order, drawn in the arena
function G:UpdateExtras()
	local arena = self:Arena()
	if not arena then return end
	local ex = {}
	local ks = {}
	for d in pairs(self.dyn) do ks[#ks + 1] = d end
	table.sort(ks)
	for _, d in ipairs(ks) do
		local e = self.dyn[d]
		local o = e.o
		if d == 4000 and self.ship then
			local s = self.ship
			if s.visible then
				local sh = FL.Child(s.mc, "shield")
				if sh then sh.visible = s.shield.engaged end
				local exh = FL.Child(s.mc, "exhaust")
				local fire = exh and FL.Child(exh, "fire")
				if fire then fire.visible = s.fireVisible end
				ex[#ex + 1] = { c = e.c, m = self:ShipM() }
			end
		elseif o and o.mcx then
			ex[#ex + 1] = { c = e.c, m = rotM(o.mcrot, o.mcx, o.mcy) }
		elseif o and o.rot then
			ex[#ex + 1] = { c = e.c, m = rotM(o.rot, o.x, o.y) }
		elseif o then
			ex[#ex + 1] = { c = e.c, m = { 1, 0, 0, 1, o.x, o.y } }
		end
	end
	-- the test markers (swapDepths 9000-9003: above the ship and the rocks)
	for _, it in ipairs(FL.Items(arena)) do
		if it.nm and string.sub(it.nm, 1, 4) == "test" then
			local k = arena.kids[it[3]]
			local t = tonumber(string.sub(it.nm, 5))
			if k then k.visible = false end
			if t then
				self.testClips[t] = self.testClips[t] or FL.New(LIB, 168)
				local p = self.tests[t] or { x = it[8], y = it[9] }
				ex[#ex + 1] = { c = self.testClips[t], m = { 1, 0, 0, 1, p.x, p.y } }
			end
		end
	end
	arena.extra = ex
	-- the debugger (loop times) sits above the stage, out of sight
	local dbg = FL.Child(self:Main(), "debugger")
	if dbg then dbg.visible = false end
	local sb = self:Statusbar()
	local ej = sb and FL.Child(sb, "eject")
	if ej then ej.visible = self.ejectVisible ~= false end
end

-- an unnamed button (by character id) inside a clip, and its stage matrix
local function btnIn(c, M, cid)
	return FL.CharItem(c, M, { [cid] = true })
end

function G:Button(id, k, m, fn)
	if not k then return end
	local x0, y0, x1, y1 = FL.Bounds(k, m, true)
	if not x0 then return end
	UI.Button(id, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), fn, { hit = FL.HitFn(k, m) })
end

-- the Flash buttons on the stage: every button character in the display tree, with the clip it
-- sits in (its "this"); BTN[cid](game, clip) is its on(release), ROLL[cid] its rollOver / rollOut
local BTN = {
	[278] = function(g) if g.gameState == 5 then g:LevelCompleted() end end,          -- "Videre"
	[185] = function(g) g.ejectRequest = true end,                                     -- the E button
	[238] = function(g, c) FL.Play(c) end,                                             -- "Kvalitet" / exit: "Nej"
	[243] = function(g, c) g.quality = "medium" FL.GotoAndStop(c, "medium") end,
	[244] = function(g, c) g.quality = "low" FL.GotoAndStop(c, "low") end,
	[255] = function(g, c) g.quality = "high" FL.GotoAndStop(c, "high") end,
	[249] = function(g, c) if c.parent then FL.Play(c.parent) end end,
	-- the shop
	[385] = function(g, c) FL.GotoAndPlay(c, "disappear") end,
	[415] = function(g) g:ShopStatusbuttonPressed() end,
	[419] = function(g) g:BuyButtonPressed() end,
	[423] = function(g) local x = g:ShopClip("exitconfirm") if x then FL.Play(x) end end,
	[434] = function(g) g:CycleShopItems(1) end,
	[436] = function(g) g:CycleShopItems(-1) end,
	[519] = function(g, c) c.vars.exit = true FL.Play(c) end,
	[590] = function(g) g:TurretSelected(2) end,
	[592] = function(g) g:TurretSelected(1) end,
	[594] = function(g) g:TurretSelected(0) end,
	[601] = function(g) g:RegretBuy() end,
}
local ROLL = {
	[577] = { "WEAPON", 0 }, [578] = { "ENGINE" }, [579] = { "SHIELD" }, [580] = { "BEAMER" }, [581] = { "COOLER", 0 },
	[582] = { "WEAPON", 1 }, [584] = { "COOLER", 1 }, [586] = { "WEAPON", 2 }, [588] = { "COOLER", 2 },
}

local function itemM(it) return { it[4], it[5], it[6], it[7], it[8], it[9] } end
local function walkButtons(c, M, out)
	if not c or c.kind ~= "spr" or not c.visible then return end
	for _, it in ipairs(FL.Items(c)) do
		local k = c.kids[it[3]]
		if k and not it.cd then
			local m = TL.Mul(M, k.mat or itemM(it))
			if k.kind == "btn" then
				if BTN[it[2]] or ROLL[it[2]] then out[#out + 1] = { cid = it[2], k = k, m = m, c = c } end
			else
				walkButtons(k, m, out)
			end
		end
	end
	if c.extra then
		for _, e in ipairs(c.extra) do walkButtons(e.c, TL.Mul(M, e.m), out) end
	end
end

-- hint (8 seconds): the crystals are ringed with an arrow from the ship to the nearest, and the
-- rocks that will hit the ship within a second and a half (if nothing changes) are ringed in red
function G:CanHint() return self.gameState == 2 and self.ship and self.ship.state == 1 end
function G:Hint(cost)
	self.hintT = 8
	self.hero.credits = math.max(0, self.hero.credits - cost)
	self:SetStatus()
	MG.Pop("-" .. cost, false, 400, 80)
end
function G:HintDraw()
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 or self.gameState ~= 2 then self.hintT = nil return end
	local am = FL.PathClip(self.root, { "main", "arena" })
	local s = self.ship
	if not am or not s then return end
	local a = math.min(1, self.hintT * 2)
	local sx, sy = s.mcX, s.mcY
	local best, bd
	for _, m in ipairs(self.minerals or {}) do
		local x, y = TL.Apply(am, m.x, m.y)
		MG.HintRing(x, y, 12, MG.HINT_GOLD, a, 3)
		local d = (m.x - sx) ^ 2 + (m.y - sy) ^ 2
		if not bd or d < bd then best, bd = m, d end
	end
	if best and s.visible and bd > 50 * 50 then
		local x0, y0 = TL.Apply(am, sx, sy)
		local x1, y1 = TL.Apply(am, best.x, best.y)
		local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
		local ux, uy = (x1 - x0) / d, (y1 - y0) / d
		MG.HintArrow(x0 + ux * 24, y0 + uy * 24, x1 - ux * 18, y1 - uy * 18, MG.HINT_GOLD, a * 0.8, 4)
	end
	-- rocks on a collision course (straight lines, 1.5 s ahead)
	local vx, vy = s.phys and s.phys.vx or 0, s.phys and s.phys.vy or 0
	for _, r in ipairs(self.astroids or {}) do
		if r.x and r.vx then
			self.hintRad = self.hintRad or {}
			local rr = r.type and self.hintRad[r.type]
			if not rr then
				local x0, x1
				if r.mc then x0, _, x1 = FL.Bounds(r.mc, I, true) end
				rr = (x0 and x1) and (x1 - x0) / 2 or 20
				if r.type then self.hintRad[r.type] = rr end
			end
			local rad = rr + 14
			for k = 0, 37, 3 do
				local dx = (r.x + r.vx * k) - (sx + vx * k)
				local dy = (r.y + r.vy * k) - (sy + vy * k)
				if dx * dx + dy * dy < rad * rad then
					local x, y = TL.Apply(am, r.mcx or r.x, r.mcy or r.y)
					MG.HintRing(x, y, rad, MG.HINT_BAD, a, 3)
					break
				end
			end
		end
	end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(19) return end
	self:UpdateExtras()
	FL.Draw(self.root, I)
	self:HintDraw()
	MG.DrawPops()
	local main = self:Main()
	if main then
		local list = {}
		walkButtons(main, FL.ChildMatrix(self.root, "main", I), list)
		local hot = {}
		for i, b in ipairs(list) do
			local id = "g19_b" .. b.cid .. "_" .. i
			local x0, y0, x1, y1 = FL.Bounds(b.k, b.m, true)
			if x0 then
				local fn = BTN[b.cid]
				UI.Button(id, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
					if fn and CUR == self then fn(self, b.c) end
				end, { hit = FL.HitFn(b.k, b.m), silent = not fn })
				if ROLL[b.cid] and UI.Hot(id) then hot = ROLL[b.cid] end
			end
		end
		-- rollOver / rollOut (the ship status on the blueprint)
		local key = hot[1] and (hot[1] .. (hot[2] or "")) or nil
		if key ~= self.rollKey then
			if self.rollKey then self:ShipStatsRollout() end
			self.rollKey = key
			if key then self:ShipStatsRollover(hot[1], hot[2]) end
		end
	end
	local f = self.root.frame
	if f >= 23 and f < 98 then
		UI.Button("g19_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(19)
end

---------------------------------------------------------------------------
-- hidden content: the warp door and Yang's Deep Space Garage
-- The original has a whole shop (weapons, engines, coolers, teleporters, shields, insurance, an
-- escape capsule, extra gun mounts ...) and a warp door that opens when a level is cleared - the
-- help text even says "don't be afraid to travel into the light". None of it is ever reached: the
-- level just fades to the bonus screen. With hidden content on, the door opens, you fly into the
-- light, get your bonus, and the shop opens before the next level. Its "next area" button takes
-- you on to the next level (in the original it would have ended the mission). Extra gun mounts
-- fire from the ship's wings (the original never worked out where they are). The shop's code is
-- the original's; the crystals you pick up on a level are the money you shop with.
---------------------------------------------------------------------------
function G.SetupShopActions()
	FL.SetActions(LIB, 603, {   -- the blueprint
		[1] = function(c)
			c.vars.open = false
			stop(c)
			local g = CUR
			if g and (g.buyingWeapon or g.buyingCooler or g.buyingGunmount or g.showingShipStatus) then FL.Play(c) end
		end,
		[39] = function(c)
			c.vars.open = true
			stop(c)
			local g = CUR
			if not g then return end
			local b = FL.Child(c, "buttons")
			if g.buyingWeapon or g.buyingCooler or g.buyingGunmount then
				if b then FL.GotoAndStop(b, "selectturret") end
			elseif not g.showingShipStatus then
				FL.Play(c)
			elseif b then
				FL.GotoAndStop(b, "stats")
			end
		end,
		[40] = function(c) c.vars.open = false end,
	})
	FL.SetActions(LIB, 602, {   -- its buttons
		[5] = function(c)
			local g = CUR
			if not g then return end
			local w1, w2 = g.ship.turrets[1].type, g.ship.turrets[2].type
			local function hide(n) local k = FL.Child(c, n) if k then k.visible = false end end
			if w1 <= 0 then hide("w1") end
			if w2 <= 0 then hide("w2") end
			if w1 == -1 then hide("c1") end
			if w2 == -1 then hide("c2") end
		end,
		[20] = function(c)
			local g = CUR
			if not g then return end
			local T = g.ship.turrets
			local buy = g.allItems[g.curShopItemId + 1].id
			local function hide(n) local k = FL.Child(c, n) if k then k.visible = false end end
			if g.buyingWeapon then
				if T[0].type == buy then hide("t0") end
				if T[1].type == -1 or T[1].type == buy then hide("t1") end
				if T[2].type == -1 or T[2].type == buy then hide("t2") end
			elseif g.buyingCooler then
				if T[0].cooler.type == buy then hide("t0") end
				if T[1].type == -1 or T[1].cooler.type == buy then hide("t1") end
				if T[2].type == -1 or T[2].cooler.type == buy then hide("t2") end
			elseif g.buyingGunmount then
				hide("t0")
				if T[1].type ~= -1 then hide("t1") end
				if T[2].type ~= -1 then hide("t2") end
			end
		end,
	})
	FL.SetActions(LIB, 564, {   -- the ship status
		[1] = function(c) c.vars.open = false stop(c) if CUR and CUR.showingShipStatus then FL.Play(c) end end,
		[7] = function(c) if CUR then CUR:WriteStats(FL.Child(c, "txt")) end end,
		[17] = function(c) c.vars.open = true stop(c) if CUR and not CUR.showingShipStatus then FL.Play(c) end end,
		[18] = function(c) c.vars.open = false end,
	})
	FL.SetActions(LIB, 511, {   -- the panel
		[1] = stop,
		[17] = function(c)
			if CUR then CUR:ShowAccount(c) end
			-- onClipEvent(load) of its buttons
			for n, f in pairs({ statusbutton = "on", buybutton = "off", donebutton = "on" }) do
				local k = FL.Child(c, n)
				if k then FL.GotoAndStop(k, f) end
			end
			for _, it in ipairs(FL.Items(c)) do
				if it[2] == 441 then
					local k = c.kids[it[3]]
					local b = k and FL.Child(k, "buttons")
					if b then FL.GotoAndStop(b, "on") end
				end
			end
		end,
		[33] = function(c) stop(c) if CUR then CUR:UpdateSpecWindow() end end,
	})
	FL.SetActions(LIB, 428, { [1] = function(c)
		stop(c)
		-- the label inside: "Næste Område" (the original: "Afslut Mission", there is only one area)
		for _, it in ipairs(FL.Items(c)) do
			if it[2] == 426 and c.kids[it[3]] then FL.GotoAndStop(c.kids[it[3]], "nextarea") end
		end
	end })
	FL.SetActions(LIB, 382, { [1] = function(c) if CUR then CUR:ShowAccount(c) end end })
	FL.SetActions(LIB, 387, {   -- the account
		[1] = stop, [3] = stop, [15] = stop,
		[29] = function(c) stop(c) local r = CUR and CUR:ShopClip("ramp") if r then FL.Play(r) end end,
	})
	FL.SetActions(LIB, 364, {   -- the ramp
		[1] = stop,
		[21] = function(c) local p = CUR and CUR:ShopClip("panel") if p then FL.Play(p) end end,
		[32] = stop,
	})
	FL.SetActions(LIB, 395, { [1] = stop, [30] = function() if CUR then CUR:ShowShipEquipment() end end })
	FL.SetActions(LIB, 522, {   -- "are you sure?"
		[1] = function(c) stop(c) c.vars.exit = false end,
		[13] = stop,
		[24] = function(c) if c.vars.exit and CUR then CUR:FinishShopping() end end,
	})
	for _, cid in ipairs({ 353, 360, 361, 418, 422, 440 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
end

function G:ShopMC() return FL.Child(self:Main(), "shopmc") end
function G:ShopClip(name) return FL.Child(self:ShopMC(), name) end

local function priceString(val)
	local s = ""
	if val < 0 then val = -val s = "-" end
	local mills = math.floor(val / 1000000)
	val = val - mills * 1000000
	local th = math.floor(val / 1000)
	local rest = val - th * 1000
	local function pad(n) if n >= 100 then return tostring(n) elseif n >= 10 then return "0" .. n elseif n > 0 then return "00" .. n end return "000" end
	if mills > 0 then
		s = s .. mills .. "," .. pad(th) .. ","
	elseif th > 0 then
		s = s .. th .. ","
	end
	if mills > 0 or th > 0 then s = s .. pad(rest) else s = s .. rest end
	return s
end

function G:InitShop()
	local cats = { {}, {}, {}, {}, {}, {} }
	for i = 1, 4 do cats[1][i] = { price = TURRET[i].price, type = "WEAPON", id = i } end
	for i = 0, 1 do cats[2][#cats[2] + 1] = { price = ENGINE[i].price, type = "ENGINE", id = i } end
	for i = 0, 2 do cats[3][#cats[3] + 1] = { price = COOLER[i].price, type = "COOLER", id = i } end
	for i = 0, 1 do cats[4][#cats[4] + 1] = { price = BEAMER[i].price, type = "BEAMER", id = i } end
	for i = 0, 3 do cats[5][#cats[5] + 1] = { price = SHIELD[i].price, type = "SHIELD", id = i } end
	for _, it in ipairs({ { 100, "BEAMERUNIT" }, { 4, "SHIELDUNIT" }, { 2500, "INSURANCE" }, { 1, "DIZE" }, { 250, "ESCAPECAPSULE" },
		{ 500, "GUNMOUNT" }, { 1000, "SHIP" }, { 1000, "LIFE" }, { 100, "CASH" } }) do
		cats[6][#cats[6] + 1] = { price = it[1], type = it[2], id = 0 }
	end
	self.shopCats = cats
	self.allItems = {}
	for _, c in ipairs(cats) do for _, it in ipairs(c) do self.allItems[#self.allItems + 1] = it end end
	self.nbShopItems = #self.allItems
	self.gunrack = { x = 0, vx = 0, wannaBe = 0, width = 228, totalWidth = 228 * self.nbShopItems, lightOn = false, lightBroken = false }
end

function G:RackItem(prefix, r)
	local rack = self:ShopClip("gunrack")
	return rack and FL.Child(rack, prefix .. r)
end

function G:OpenShop()
	local g = self.gunrack
	g.x, g.vx, g.wannaBe = 0, 0, 0
	g.lightOn = true
	g.lightBroken = false
	self:ShowShipEquipment()
	self.curShopItemId = 0
	self.buyingWeapon, self.buyingCooler, self.buyingGunmount = false, false, false
	self.showingShipStatus = false
	for r = 1, 4 do
		local id = (self.curShopItemId - 3 + r) % self.nbShopItems
		local mc = self:RackItem("item", r)
		if mc then FL.GotoAndStop(mc, id + 1) end
	end
end

function G:ShopAccountAppear()
	local a = self:ShopClip("account")
	if a then FL.GotoAndPlay(a, "appear") end
end

function G:ShowAccount(c)
	if not c then return end
	c.vars.txt_cargo = priceString(self.hero.areaCargo) .. ".00"
	c.vars.txt_credits = priceString(self.hero.credits) .. ".00"
	c.vars.txt_minerals = priceString(self.hero.minerals) .. ".00"
end

function G:CycleShopItems(dir)
	self:PlaySound("shopCycleItem")
	local g = self.gunrack
	g.lightOn = false
	g.lightBroken = false
	g.wannaBe = g.wannaBe + dir * g.width
	self.curShopItemId = (self.curShopItemId + dir) % self.nbShopItems
	self:UpdateSpecWindow()
end

function G:SpecClips()
	local p = self:ShopClip("panel")
	local sa = p and FL.Child(p, "specall")
	return sa and FL.Child(sa, "spec"), sa and FL.Child(sa, "specshadow"), p
end

function G:UpdateSpecWindow()
	local item = self.allItems[self.curShopItemId + 1]
	local ship = self.ship
	local price = item.price
	local priceStr = "Y$ " .. priceString(price) .. ".00"
	local off = false
	local units
	local T = ship.turrets
	if item.type == "WEAPON" then
		off = true
		if not self.buyingWeapon then
			for t = 0, 2 do if item.id ~= T[t].type and T[t].type > -1 then off = false end end
		end
	elseif item.type == "ENGINE" then off = item.id == ship.engine.type
	elseif item.type == "COOLER" then
		off = true
		if not self.buyingCooler then
			for t = 0, 2 do if item.id ~= T[t].cooler.type and T[t].type ~= -1 then off = false end end
		end
	elseif item.type == "BEAMER" then off = item.id == ship.beamers.type
	elseif item.type == "SHIELD" then off = item.id == ship.shield.type
	elseif item.type == "BEAMERUNIT" then
		if ship.beamers.amount >= ship.beamers.max then off = true priceStr = AN.L("g19_powerupFull") end
	elseif item.type == "SHIELDUNIT" then
		local missing = ship.shield.max - ship.shield.amount
		if missing == 0 then
			off = true
			priceStr = AN.L("g19_powerupFull")
			units = "* 50 " .. AN.L("g19_powerupDesc17")
		elseif missing >= 50 then
			price = price * 50
			priceStr = "Y$ " .. priceString(price) .. ".00"
			units = "* 50 " .. AN.L("g19_powerupDesc17")
		else
			price = price * missing
			priceStr = "Y$ " .. priceString(price) .. ".00"
			units = "* " .. missing .. " " .. AN.L("g19_powerupDesc17")
		end
	elseif item.type == "DIZE" then
		if ship.dize then off = true priceStr = AN.L("g19_powerupPurchased") end
	elseif item.type == "ESCAPECAPSULE" then
		if ship.escapeCapsule then off = true priceStr = AN.L("g19_powerupPurchased") end
	elseif item.type == "GUNMOUNT" then
		off = true
		if not self.buyingGunmount then
			for t = 1, 2 do if T[t].type == -1 then off = false end end
		end
	end
	local spec, shadow, panel = self:SpecClips()
	for _, c in ipairs({ spec or false, shadow or false }) do
		if c then
			FL.GotoAndStop(c, self.curShopItemId + 1)
			c.vars.txt_price = priceStr
			if units then c.vars.txt_units = units end
		end
	end
	local bb = panel and FL.Child(panel, "buybutton")
	if bb then FL.GotoAndStop(bb, (price > self.hero.minerals or off) and "off" or "on") end
end

function G:UpdateGunrack()
	local g = self.gunrack
	g.vx = math.ceil((g.wannaBe - g.x) / 3)
	g.x = g.x + g.vx
	if g.x < 0 then
		g.x = g.x + g.totalWidth
		g.wannaBe = g.wannaBe + g.totalWidth
	elseif g.x > g.totalWidth then
		g.x = g.x - g.totalWidth
		g.wannaBe = g.wannaBe - g.totalWidth
	end
	local posOffset = math.fmod(g.x, g.width)
	local itemOffset = math.floor(g.x / g.width)
	local shop = self:ShopMC()
	local rack = shop and FL.Child(shop, "gunrack")
	if not rack then return end
	for _, it in ipairs(FL.Items(shop)) do
		if it.nm == "gunrack" then rack.mat = { it[4], it[5], it[6], it[7], posOffset, it[9] } end
	end
	for r = 1, 4 do
		local mc = FL.Child(rack, "item" .. r)
		local bg = FL.Child(rack, "bg" .. r)
		local id = itemOffset - 3 + r
		if id < 0 then id = id + self.nbShopItems elseif id >= self.nbShopItems then id = id - self.nbShopItems end
		if mc then FL.GotoAndStop(mc, id + 1) end
		if bg then
			if id == self.curShopItemId and math.abs(g.vx) < 2 then
				if not g.lightOn then
					self:PlaySound("lightswitch")
					g.lightOn = true
					FL.GotoAndStop(bg, 2)
				elseif not g.lightBroken then
					FL.GotoAndStop(bg, 2)
					if math.random() < 0.001 then
						g.lightBroken = true
						self:PlaySound("lightbreak")
						FL.GotoAndStop(bg, 1)
					end
				end
			else
				FL.GotoAndStop(bg, 1)
			end
		end
	end
end

function G:PanelButtons(state)
	local p = self:ShopClip("panel")
	if not p then return end
	for _, n in ipairs({ "buybutton", "statusbutton", "donebutton" }) do
		local k = FL.Child(p, n)
		if k then FL.GotoAndStop(k, state) end
	end
	-- (panel.cycler does not exist: the arrows stay on)
end

function G:OpenBlueprintFor()
	local bp = self:ShopClip("blueprint")
	if not bp then return end
	if not bp.vars.open then
		FL.Play(bp)
	else
		local b = FL.Child(bp, "buttons")
		if b then FL.GotoAndStop(b, "selectturret") end
	end
end

function G:Charge(amount, build, stats)
	self:PlaySound("cash")
	self.hero.minerals = self.hero.minerals - amount
	local p = self:ShopClip("panel")
	self:ShowAccount(p)
	if build then
		local b = self:ShopClip("builder")
		if b then FL.GotoAndPlay(b, 1) end
	end
	if stats then
		local ss = self:ShopClip("shipstatus")
		self:WriteStats(ss and FL.Child(ss, "txt"))
	end
end

function G:BuyButtonPressed()
	local item = self.allItems[self.curShopItemId + 1]
	local ship = self.ship
	if self.hero.minerals < item.price then return end
	local t = item.type
	if t == "WEAPON" or t == "COOLER" or t == "GUNMOUNT" then
		local p = self:ShopClip("panel")
		local bb = p and FL.Child(p, "buybutton")
		if bb then FL.GotoAndStop(bb, "off") end
		for _, n in ipairs({ "statusbutton", "donebutton" }) do
			local k = p and FL.Child(p, n)
			if k then FL.GotoAndStop(k, "off") end
		end
		if t == "WEAPON" then self.buyingWeapon = true elseif t == "COOLER" then self.buyingCooler = true else self.buyingGunmount = true end
		self:OpenBlueprintFor()
	elseif t == "ENGINE" then
		self:InstallEngine(item.id)
		self:Charge(item.price, true)
	elseif t == "BEAMER" then
		self:InstallBeamer(item.id)
		ship.beamers.amount = math.min(ship.beamers.amount, ship.beamers.max)
		self:Charge(item.price, true)
	elseif t == "SHIELD" then
		self:InstallShield(item.id)
		self:Charge(item.price, true)
	elseif t == "BEAMERUNIT" then
		if ship.beamers.amount < ship.beamers.max then ship.beamers.amount = ship.beamers.amount + 1 end
		self:Charge(item.price, false, true)
	elseif t == "SHIELDUNIT" then
		local missing = ship.shield.max - ship.shield.amount
		local cost
		if missing >= 50 then
			cost = item.price * 50
			ship.shield.amount = ship.shield.amount + 50
		else
			cost = item.price * missing
			ship.shield.amount = ship.shield.max
		end
		self:Charge(cost, false, true)
	elseif t == "INSURANCE" then
		ship.insurance = ship.insurance + 1
		self:Charge(item.price, false, true)
	elseif t == "DIZE" then
		ship.dize = true
		self:Charge(item.price, true)
	elseif t == "ESCAPECAPSULE" then
		ship.escapeCapsule = true
		self:Charge(item.price, true)
	elseif t == "SHIP" then
		self.hero.ships = self.hero.ships + 1
		self:Charge(item.price, false, true)
	elseif t == "LIFE" then
		self.hero.lives = self.hero.lives + 1
		self:Charge(item.price, false, true)
	elseif t == "CASH" then
		self.hero.credits = self.hero.credits + item.price * 10
		self:Charge(item.price, false, true)
	end
	self:UpdateSpecWindow()
end

function G:TurretSelected(id)
	local item = self.allItems[self.curShopItemId + 1]
	if self.buyingWeapon then
		self.buyingWeapon = false
		self:InstallTurret(id, item.id)
	elseif self.buyingCooler then
		self.buyingCooler = false
		self:InstallCooler(id, item.id)
	elseif self.buyingGunmount then
		self.buyingGunmount = false
		self:InstallTurret(id, 0)
	end
	local bp = self:ShopClip("blueprint")
	if bp then FL.Play(bp) end
	self:Charge(item.price, true)
	self:PanelButtons("on")
	self:UpdateSpecWindow()
end

function G:RegretBuy()
	self.buyingWeapon, self.buyingCooler, self.buyingGunmount = false, false, false
	local bp = self:ShopClip("blueprint")
	if bp then
		if not self.showingShipStatus then
			FL.Play(bp)
		else
			local b = FL.Child(bp, "buttons")
			if b then FL.GotoAndStop(b, "stats") end
		end
	end
	self:PanelButtons("on")
	self:UpdateSpecWindow()
end

function G:ShipStatsRollover(tp, id)
	local ship = self.ship
	local n1, n2, n3, n4 = #self.shopCats[1], #self.shopCats[2], #self.shopCats[3], #self.shopCats[4]
	local itemId
	if tp == "WEAPON" then itemId = ship.turrets[id].type - 1
	elseif tp == "COOLER" then itemId = ship.turrets[id].cooler.type + n1 + n2
	elseif tp == "ENGINE" then itemId = ship.engine.type + n1
	elseif tp == "BEAMER" then itemId = ship.beamers.type + n1 + n2 + n3
	elseif tp == "SHIELD" then itemId = ship.shield.type + n1 + n2 + n3 + n4 end
	local it = itemId and self.allItems[itemId + 1]
	if not it then return end
	local str = "Y$ " .. priceString(it.price) .. ".00"
	local spec, shadow = self:SpecClips()
	for _, c in ipairs({ spec or false, shadow or false }) do
		if c then FL.GotoAndStop(c, itemId + 1) c.vars.txt_price = str end
	end
end

function G:ShipStatsRollout() self:UpdateSpecWindow() end

function G:ShopStatusbuttonPressed()
	self.showingShipStatus = not self.showingShipStatus
	local ss, bp = self:ShopClip("shipstatus"), self:ShopClip("blueprint")
	if ss then FL.Play(ss) end
	if bp then FL.Play(bp) end
end

function G:ShowShipEquipment()
	local ramp = self:ShopClip("ramp")
	local sh = ramp and FL.Child(ramp, "ship")
	if sh then
		for t = 1, 2 do
			local w = FL.Child(sh, "wing" .. t)
			local tp = self.ship.turrets[t].type
			if w then FL.GotoAndStop(w, tp <= 0 and 2 + tp or 3) end
		end
		local ex = FL.Child(sh, "exhaust")
		if ex then FL.GotoAndStop(ex, ENGINE[self.ship.engine.type].gfxID) end
	end
	local ss = self:ShopClip("shipstatus")
	self:WriteStats(ss and FL.Child(ss, "txt"))
end

function G:WriteStats(mc)
	if not mc then return end
	local ship, v = self.ship, mc.vars
	local T = ship.turrets
	v.txt_weap0 = TURRET[T[0].type] and TURRET[T[0].type].name
	v.txt_cool0 = COOLER[T[0].cooler.type].name
	for t = 1, 2 do
		local tp = T[t].type
		if tp == -1 then
			v["txt_weap" .. t], v["txt_cool" .. t] = "-", "-"
		elseif tp == 0 then
			v["txt_weap" .. t] = AN.L("g19_shipStatusNone")
			v["txt_cool" .. t] = COOLER[0].name    -- coolerTypes[0]: the type number, not the cooler
		else
			v["txt_weap" .. t] = TURRET[tp].name
			v["txt_cool" .. t] = COOLER[T[t].cooler.type].name
		end
	end
	v.txt_engine = ENGINE[ship.engine.type].name
	v.txt_beamer = BEAMER[ship.beamers.type].name
	v.txt_beamercharges = ship.beamers.amount
	v.txt_shield = SHIELD[ship.shield.type].name
	v.txt_shieldpct = math.floor(ship.shield.amount / ship.shield.max * 100) .. " %"
	v.txt_dize = AN.L(ship.dize and "g19_shipStatusInstalled" or "g19_shipStatusNo")
	v.txt_escapecapsule = AN.L(ship.escapeCapsule and "g19_shipStatusInstalled" or "g19_shipStatusNo")
	v.txt_insurance = ship.insurance
	v.txt_ships = self.hero.ships
	v.txt_lives = self.hero.lives
end

function G:AreaCompleted()
	local h = self.hero
	h.minerals = h.minerals + h.cargo
	h.areaCargo = h.cargo
	h.cargo = 0
	self.gameState = 6
	FL.GotoAndPlay(self:Main(), "shop")
end

function G:FinishShopping()
	self.showingShipStatus = false
	self.shopDone = true
	self:LevelCompleted()
end

-- the warp door
function G:WarpDoor()
	local a = self:Arena()
	return a and FL.Child(a, "warpdoor")
end

function G:OpenWarpDoor()
	local wd = self:WarpDoor()
	if wd then FL.GotoAndPlay(wd, "appear") end
end

function G:DoorHitarea()
	local wd = self:WarpDoor()
	local door = wd and FL.Child(wd, "door")
	if not door then return nil end
	local am = FL.ChildMatrix(self:Main(), "arena", I)
	local wm = FL.ChildMatrix(self:Arena(), "warpdoor", am)
	local dm = FL.ChildMatrix(wd, "door", wm)
	local hm, hk = FL.ChildMatrix(door, "hitarea", dm)
	return hk, hm, door
end

function G:ApplyBlackHole()
	local hk, hm = self:DoorHitarea()
	if not hk then return end
	local p = self.ship.phys
	local dx, dy = p.x - hm[5], p.y - hm[6]
	local d2 = dx * dx + dy * dy
	if d2 < 90000 then
		local power = d2 / 90000 - 1
		self.ship.mcScale = 100 + 30 * power
		local len = math.sqrt(d2)
		if len > 0 then
			p.vx = p.vx + dx / len * power * 0.7
			p.vy = p.vy + dy / len * power * 0.7
		end
	end
end

function G:CheckWarpDoorHit()
	local hk, hm, door = self:DoorHitarea()
	if not hk then return end
	local sm, sk = FL.ChildMatrix(self.ship.mc, "hitarea", self:ShipM())
	if sk and FL.HitTest(sk, sm, hk, hm) then
		self:StopAllSounds()
		self:ShipWarpStart(0)
		self.gameState = 5
		FL.GotoAndPlay(door, "hit")
	end
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(19, G)
