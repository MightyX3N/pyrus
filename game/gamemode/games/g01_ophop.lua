-- Låge 1: Op og Hop
-- Rebuilt from the original platform engine (game.swf), its level (level.swf), the shared graphics
-- and property pages (sharedgraphics.swf), the in-game dialogs (gui.swf) and the sounds (sound.swf).
-- Pyrus climbs the bookshelves, eats the rice porridge and reaches the magic book at the top while
-- things fall and drive along the shelves. 10 difficulty levels (plus the extra one the original
-- engine runs after the tenth), 3 lives, 100 energy, time bonus after each level.
-- Like the original, the falling things' paths are recorded once before the game starts
-- ("prespooling") and played back every time one is spawned. All the original's quirks are kept,
-- except the score panel's energy and porridge meters, which are made to work.
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g01_sg.lua")
include(DIR .. "g01_level.lua")
include(DIR .. "g01_gui.lua")
include(DIR .. "g01_objects.lua")
local OBJ = AN.G01Objects

local G = {
	scoreType = "score",
	goal = 500,       -- the original coolScore
	worst = 0,
	levels = 11,      -- 10 difficulty levels and the extra one the engine runs after them
	descKey = "desc_01",
	howKey = "how_01",
}

local STAGE_W, STAGE_H = 800, 600
local STEP = 1 / 25
local MS = 40                              -- one frame in milliseconds (25 fps)

-- the engine's constants
local PRESPOOL_FRAMES = 600
local RECEIVE_SCORE_FOR_SAME_FALLER_PAUSE = 10000
local MAX_NUM_FALLERS = 40
local SOUND_LISTENERRANGE = 300
local FALLER_RANGESENSIBILITY = 300
local LOOKUP_RESOLUTION = 10
local ITEMLOOKUP_RESOLUTION = 50
local ITEMLOOKUP_EXTRASIZE_W = 30
local ITEMLOOKUP_EXTRASIZE_H = 100
local MONSTERBEINGHIT_NBFRAMES = 12
local CAMERAEXTEND = 100
local UPDATESOUND_FRAMEINTERVAL = 4
local GRAVITY = 2.3612

-- the level's properties page
local LEVEL = {
	levelTime = 200, minTimeAfterRespawn = 45, numDifficulties = 10, lessTimePrDifficulty = 2,
	winLevel = { "reachcompletionhittester", "pickupallitems" },
	pointsPrSecondLeft = 1,
}

-- the property pages in sharedgraphics.swf
local FALLER = {
	falldriver = { scoreDodge = 15, scoreDestroy = 8, weight = 1, speed = 3, bounceFactor = 0, contactEffect = "falldownandlooseenergy",
		attackPower = 34, flyHeight = 0, floatiness = 0, floatinessFalloff = 0, rotateFactor = 0, fallDown = true, goThroughWalls = true,
		soundLoop = "mechanicloop", soundDie = "fallerdisappear", soundBounce = "" },
	fallbouncer = { scoreDodge = 15, scoreDestroy = 8, weight = 0.5, speed = 5, bounceFactor = 0.22, contactEffect = "looseenergy",
		attackPower = 34, flyHeight = 0, floatiness = 0, floatinessFalloff = 0, rotateFactor = 0, fallDown = true, goThroughWalls = true,
		soundLoop = "enemyflying", soundDie = "fallerdisappear", soundBounce = "bounce" },
	fallflyer = { scoreDodge = 15, scoreDestroy = 8, weight = 1, speed = 5, bounceFactor = 0, contactEffect = "falldownandlooseenergy",
		attackPower = 34, flyHeight = 80, floatiness = 0.5, floatinessFalloff = 0.2, rotateFactor = 0, fallDown = true, goThroughWalls = true,
		soundLoop = "enemyflying", soundDie = "fallerdisappear", soundBounce = "" },
	fallbouncersmall = { scoreDodge = 15, scoreDestroy = 8, weight = 1, speed = 5, bounceFactor = 0.8, contactEffect = "falldownandlooseenergy",
		attackPower = 40, flyHeight = 0, floatiness = 0, floatinessFalloff = 0, rotateFactor = 0, fallDown = true, goThroughWalls = true,
		soundLoop = "enemyflying", soundDie = "fallerdisappear", soundBounce = "" },
	falldriversmall = { scoreDodge = 15, scoreDestroy = 8, weight = 1, speed = 9, bounceFactor = 0, contactEffect = "falldown",
		attackPower = 40, flyHeight = 0, floatiness = 0, floatinessFalloff = 0, rotateFactor = 0, fallDown = true, goThroughWalls = true,
		soundLoop = "mechanicloop", soundDie = "enemyhit", soundBounce = "" },
}
local HERO = { walkSpeed = 6, jumpPower = 31, safeFalldownHeight = 60000, maxEnergy = 100, nbLives = 3,
	sound_footstep = "walking", sound_jump = "herojump", sound_land = "landing", sound_hithead = "headhit", sound_gettingHit = "herohit", sound_die = "dying" }
local ITEM = { sound_pickup = "pickup", scoreForPickup = 5 }

-- the sound module's list (sound.swf): id -> files; loops are "background" sounds
local SND = {
	bounce = { "bounce" }, bouncehigher = { "bouncehigher" }, mechanicloop = { "mechanicloop", loop = true },
	carloop = { "carloop", loop = true }, spawnthing = { "spawnthing" }, jump = { "jump" }, hithead = { "hithead" },
	hitfaller = { "hitfaller" }, enemyflying = { "enemyflying", loop = true },
	walking = { "steps1", "steps2", "steps3", "steps4" },
	fallerdisappear = { "fallerdisappear" }, poppoint = { "pop" }, giggle = { "giggle" }, pickup = { "pickup" },
}

local CUR   -- the running game (for the clips' frame scripts)

local function fmtTime(sec)
	local m = math.floor(sec / 60)
	local s = sec - m * 60
	return m .. ":" .. (s < 10 and "0" .. s or s)
end

---------------------------------------------------------------------------
-- the clips' frame scripts
---------------------------------------------------------------------------
local function hide(c, name) local k = FL.Child(c, name) if k then k.visible = false end end
local function hideChar(c, cid)
	for _, it in ipairs(c.def[4][c.frame] and type(c.def[4][c.frame]) == "table" and c.def[4][c.frame] or {}) do
		if it[2] == cid and c.kids[it[3]] then c.kids[it[3]].visible = false end
	end
end
local function stop(c) FL.Stop(c) end
local function play(c) FL.Play(c) end
local function stopDead(c) FL.Stop(c) if c.parent then c.parent.vars.dead = true end end

local function standDone(c)
	FL.GotoAndStop(c, "stand")
	local g = CUR
	if g and g.mons and c.parent == g.mons.clip then g.mons.animState = 4 end
end

local function setupActions()
	local sg = "g01sg"
	-- the hero's "side" clip
	FL.SetActions(sg, 92, {
		[1] = function(c) hide(c, "hitbox") stop(c) end,
		[7] = play, [11] = function(c) stop(c) hide(c, "hitbox") end, [18] = stop, [23] = play, [27] = stop,
		[49] = stop, [58] = stop, [65] = function(c) FL.GotoAndStop(c, "fall") end, [87] = function(c) FL.GotoAndStop(c, "stand") end,
		[107] = play, [128] = standDone, [137] = play, [159] = standDone,
	})
	FL.SetActions(sg, 48, { [2] = function(c) if c.parent then c.parent.vars.footstep = true end end,
		[10] = function(c) if c.parent then c.parent.vars.footstep = true end end })
	FL.SetActions(sg, 93, { [1] = stop })
	for _, id in ipairs({ 97, 100, 114, 117, 135 }) do
		FL.SetActions(sg, id, { [1] = function(c) stop(c) c.vars.dead = false end })
	end
	FL.SetActions(sg, 113, { [1] = stop, [11] = play, [19] = function(c) FL.GotoAndStop(c, "on") end, [32] = stopDead })
	FL.SetActions(sg, 116, { [1] = stop, [10] = play, [19] = stopDead, [25] = play, [41] = function(c) FL.GotoAndStop(c, "on") end })
	FL.SetActions(sg, 134, { [12] = play, [17] = function(c) FL.GotoAndStop(c, "on") end, [28] = stopDead })
	FL.SetActions(sg, 96, { [10] = play, [20] = function(c) FL.GotoAndStop(c, "on") end, [31] = stopDead })
	FL.SetActions(sg, 99, { [1] = stop, [10] = play, [19] = function(c) FL.GotoAndStop(c, "on") end, [39] = stopDead })
	FL.SetActions(sg, 123, {
		[1] = stop,
		[5] = function(c)
			local a = FL.Child(c, "anim")
			if a then a.vars.amountTxt = c.vars.amountTxt end
			if (tonumber(c.vars.amountTxt) or 0) >= 15 then AN.Speak("godt") else AN.Speak("megetgodt") end
		end,
		[22] = stop,
		[69] = function(c) local a = FL.Child(c, "anim") if a then a.vars.amountTxt = c.vars.amountTxt end end,
		[91] = stop,
	})
	FL.SetActions(sg, 128, { [1] = stop, [2] = stop, [5] = play, [11] = function(c) FL.GotoAndStop(c, "on") end, [15] = play,
		[16] = function() AN.Speak("pebergroed_risengroed") end, [17] = stop })
	FL.SetActions(sg, 138, { [34] = function(c) c.visible = false stop(c) end })

	local lv = "g01lv"
	FL.SetActions(lv, 15, { [1] = stop, [56] = stop })
	FL.SetActions(lv, 39, { [1] = stop, [49] = stop })

	local gui = "g01gui"
	FL.SetActions(gui, 0, { [1] = function(c)
		stop(c)
		for _, n in ipairs({ "gameover", "levelComplete", "scorePanel", "gameCompleted", "gameovertimeout", "stillNeedItems" }) do hide(c, n) end
	end })
	FL.SetActions(gui, 115, { [1] = play, [18] = function(c) stop(c) c.vars.readyForstats = true end,
		[23] = function(c) stop(c) c.visible = false end, [39] = function(c) c.visible = false end })
	FL.SetActions(gui, 122, { [1] = play, [8] = stop, [15] = function(c) c.visible = false end })
	FL.SetActions(gui, 127, { [15] = function(c) c.visible = false end })
	FL.SetActions(gui, 82, { [1] = stop, [8] = function(c) c.visible = false end })
	FL.SetActions(gui, 85, { [1] = play, [54] = function(c) c.visible = false end })
	FL.SetActions(gui, 74, {
		[1] = function(c) stop(c) c.vars.state = "CLOSED" hide(c, "progress") end,
		[7] = play, [19] = function(c) stop(c) c.vars.state = "OPEN" end, [20] = play,
		[31] = function(c) FL.GotoAndStop(c, "stop") c.vars.state = "CLOSED" end, [40] = stop,
	})
	for _, id in ipairs({ 21, 33, 39 }) do FL.SetActions(gui, id, { [1] = stop }) end
	FL.SetActions(gui, 60, { [1] = function(c) hideChar(c, 42) stop(c) end, [2] = stop })
	FL.SetActions(gui, 42, { [1] = stop })
end

---------------------------------------------------------------------------
-- sounds (the original sound module: positional volume and pan around the listener)
---------------------------------------------------------------------------
function G:SoundVolPan(x, y)
	if not x then return 1, 0 end
	local dx, dy = self.listX - x, self.listY - y
	local d2 = dx * dx + dy * dy
	local vol = math.max(100 - d2 / (SOUND_LISTENERRANGE * SOUND_LISTENERRANGE) * 100, 0)
	local pan = math.Clamp(-dx * 2 / SOUND_LISTENERRANGE * 100, -100, 100)
	return vol / 100, pan / 100
end

function G:PlaySound(id, x, y)
	if not id or id == "" then return end
	id = string.lower(id)
	local s = SND[id]
	if not s or s.loop then return end
	local n = #s
	local pick = 1
	if n > 2 then
		repeat pick = math.random(n) until pick ~= s.last
	elseif n == 2 then
		pick = math.random(n)
	end
	s.last = pick
	local vol, pan = self:SoundVolPan(x, y)
	if vol <= 0 then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100 * vol
	if v <= 0 or AN.SoundMode() == 2 then return end
	sound.PlayFile("sound/alletidersnisse/g01/" .. s[pick] .. ".mp3", "noplay", function(ch)
		if IsValid(ch) then ch:SetVolume(v) if ch.SetPan then ch:SetPan(pan) end ch:Play() end
	end)
end

-- the falling things' loop sounds: one per kind, at the nearest one (platSound...)
function G:LoopSound(id, x, y)
	local l = self.loopsnd[id]
	if not l then
		l = { x = x, y = y }
		self.loopsnd[id] = l
		local s = SND[id]
		if not s then return end
		if AN.SoundMode() == 2 or (AN.Save.Get("vol_fx") or 85) <= 0 then return end
		l.loading = true
		sound.PlayFile("sound/alletidersnisse/g01/" .. s[1] .. ".mp3", "noplay", function(ch)
			l.loading = false
			if not IsValid(ch) then return end
			if l.stopped or self.loopsnd[id] ~= l then ch:Stop() return end
			ch:EnableLooping(true)
			l.ch = ch
			self:LoopVolume(l)
			ch:Play()
		end)
	end
	l.x, l.y = x, y
	l.playing = true
end

function G:LoopVolume(l)
	if not IsValid(l.ch) then return end
	local vol, pan = self:SoundVolPan(l.x, l.y)
	l.ch:SetVolume((AN.Save.Get("vol_fx") or 85) / 100 * vol)
	if l.ch.SetPan then l.ch:SetPan(pan) end
end

function G:StopLoops()
	for id, l in pairs(self.loopsnd or {}) do
		l.stopped = true
		if IsValid(l.ch) then l.ch:Stop() end
	end
	self.loopsnd = {}
end

---------------------------------------------------------------------------
-- level setup (initLevel)
---------------------------------------------------------------------------
local function bounds(o) return { xMin = o.b[1], yMin = o.b[2], xMax = o.b[3], yMax = o.b[4] } end

function G:InitLevel()
	self.blocks, self.walls, self.items, self.spawners, self.camFrames = {}, {}, {}, {}, {}
	self.lowestBlockY = -99999
	for _, o in ipairs(OBJ) do
		local v = o.v
		if o.type == "block" then
			self.blocks[#self.blocks + 1] = { bounds = bounds(o), state = 1, absoluteBottom = v.absolutebottom, fallKiller = v.fallkiller,
				monsterFallStopper = v.monsterfallstopper, canJumpThroughFromBelow = v.jumpthroughfrombelow,
				canJumpThroughFromAbove = v.jumpthroughfromabove, touchDamage = v.touchdamage or 0 }
			if o.y > self.lowestBlockY then self.lowestBlockY = o.y end
		elseif o.type == "wall" then
			self.walls[#self.walls + 1] = { bounds = bounds(o), state = 1, touchDamage = v.touchdamage or 0, fallKiller = v.fallkiller }
		elseif o.type == "startpoint" then
			self.startPoint = { x = o.x, y = o.y }
		elseif o.type == "fallerspawn" then
			local onoff, max = {}, 0
			local arr = {}
			for p in string.gmatch(v.includeddifficulties or "", "[^;]+") do arr[#arr + 1] = tonumber(p) or 0 end
			for _, a in ipairs(arr) do if a > max then max = a end end
			for t = 0, max - 1 do onoff[t] = false end
			for _, a in ipairs(arr) do if a > 0 then onoff[a - 1] = true end end
			local types = {}
			for p in string.gmatch(v.libtypes or "", "[^;]+") do types[#types + 1] = p end
			self.spawners[#self.spawners + 1] = {
				x = o.x, y = o.y, spawnActive = true, recordedPath = {}, initialTime = v.initialtime or 0, spawnCount = 0,
				curSpawnInterval = 10000, numSpawnsCount = 0, difficultyOnOff = onoff, curLevelCount = 0,
				spawnInterval = v.spawninterval, numSpawns = v.numspawns, libTypes = types, spawnXDir = v.spawnxdir,
				spawnObjLifetimeMS = (v.spawnobjlifetimems == 0) and 100000000 or v.spawnobjlifetimems,
				spawnIntervalAddPrDifficulty = v.spawnintervaladdprdifficulty or 0, allowPerformanceDisabling = v.allowperformancedisabling,
			}
		elseif o.type == "cameraframe" then
			local b = bounds(o)
			b.viewPreferenceFactor = v.viewpreferencefactor or 0
			self.camFrames[#self.camFrames + 1] = b
		elseif o.type == "item" then
			local inc = {}
			for p in string.gmatch(v.includeddifficulties or "", "[^;]+") do inc[#inc + 1] = p end
			local clip = FL.New("g01sg", v.itemlibname)
			local x0, y0, x1, y1 = FL.Bounds(clip, { 1, 0, 0, 1, 0, 0 }, true)
			self.items[#self.items + 1] = {
				pos = { x = o.x, y = o.y }, startPos = { x = o.x, y = o.y }, vel = { x = 0, y = 0 },
				activationTimeMS = v.activationtimems or 0, requiredForCompletion = v.requiredforcompletion,
				lieOnGround = v.lieonground, fallToGround = v.falltoground, includedDifficulties = inc,
				active = true, diffactive = true, clip = clip, xSize = (x1 or 0) - (x0 or 0), ySize = (y1 or 0) - (y0 or 0),
				mcx = o.x, mcy = o.y,
			}
		elseif o.type == "gamearea" then
			self.gameArea = bounds(o)
		elseif o.type == "completetester" then
			self.complTester = bounds(o)
		elseif o.type == "camerasizedefinition" then
			self.camSize = { w = o.b[3] - o.b[1], h = o.b[4] - o.b[2] }
		end
	end

	-- lookups
	local BUY, BDY, BXL, BXR = 10, 120, 10, 120
	self.levelWidth = self.gameArea.xMax - self.gameArea.xMin
	self.levelHeight = self.gameArea.yMax - self.gameArea.yMin
	self.blockLook, self.wallLook, self.itemLook = {}, {}, {}
	for w, wl in ipairs(self.walls) do
		for t = math.floor((wl.bounds.xMin - BXL) / LOOKUP_RESOLUTION), math.floor((wl.bounds.xMax + BXR) / LOOKUP_RESOLUTION) - 1 do
			self.wallLook[t] = self.wallLook[t] or {}
			table.insert(self.wallLook[t], w)
		end
	end
	for w, bl in ipairs(self.blocks) do
		for t = math.floor((bl.bounds.yMin - BUY) / LOOKUP_RESOLUTION), math.floor((bl.bounds.yMax + BDY) / LOOKUP_RESOLUTION) - 1 do
			self.blockLook[t] = self.blockLook[t] or {}
			table.insert(self.blockLook[t], w)
		end
	end
	local IW = math.floor(self.levelWidth / ITEMLOOKUP_RESOLUTION)
	self.itemLW = IW
	for i, it in ipairs(self.items) do
		local x = -ITEMLOOKUP_EXTRASIZE_W
		while x <= ITEMLOOKUP_EXTRASIZE_W do
			local y = -ITEMLOOKUP_EXTRASIZE_H
			while y <= ITEMLOOKUP_EXTRASIZE_H do
				local idx = math.floor(math.floor((it.pos.y + y) / ITEMLOOKUP_RESOLUTION) * IW + (it.pos.x + x) / ITEMLOOKUP_RESOLUTION)
				self.itemLook[idx] = self.itemLook[idx] or {}
				local found = false
				for _, k in ipairs(self.itemLook[idx]) do if k == i then found = true end end
				if not found then table.insert(self.itemLook[idx], i) end
				y = y + ITEMLOOKUP_RESOLUTION / 2
			end
			x = x + ITEMLOOKUP_RESOLUTION / 2
		end
	end

	-- the camera
	self.camOffX, self.camOffY = self.camSize.w / 2, self.camSize.h / 2
	self.fallerDisableDistSQR = (self.camSize.w * 0.8) ^ 2
end

---------------------------------------------------------------------------
-- the monster (Pyrus)
---------------------------------------------------------------------------
function G:NewMonster()
	local sp = self.startPoint
	local clip = FL.New("g01sg", "pigeBamse")
	local x0, y0, x1, y1 = FL.Bounds(clip, { 1, 0, 0, 1, 0, 0 }, true)
	local m = {
		mainState = 0, animState = 0, animSubState = 0,
		startPos = { x = sp.x, y = sp.y }, pos = { x = sp.x, y = sp.y }, lastPos = { x = -100, y = -100 }, vel = { x = 0, y = 0 },
		curNbLives = 0, waitCount = 0, jumpDir = 0, walkDir = 1, curBlockID = -1, keys = {},
		energy = HERO.maxEnergy, dieWhenHitGround = false, jumpWhenHitDone = false, deathCountdown = 0,
		clip = clip, xSize = (x1 - x0) / 2, ySize = (y1 - y0) * 0.9, duckWasWalking = false, mustDuck = false,
		attackHitCount = 0, nbItemsPickedUp = 0, fallAccum = 0, mcx = sp.x, mcy = sp.y,
	}
	self.mons = m
	return m
end

function G:Side() return FL.Child(self.mons.clip, "side") end
function G:SideGoto(label, playIt)
	local s = self:Side()
	if s then FL.Goto(s, label, playIt) end
end

function G:MonsGotoStartPos()
	local m = self.mons
	m.pos.x, m.pos.y = m.startPos.x, m.startPos.y
	m.animState = 0
	m.mainState = 0
	self:StopWalking()
	m.fallAccum = 0
end

function G:ResetForNewLife()
	self.mons.energy = HERO.maxEnergy
	self:MonsGotoStartPos()
end

function G:ResetForNewLevel()
	self.mons.nbItemsPickedUp = 0
	self:MonsGotoStartPos()
end

function G:ResetForNewGame()
	self.mons.curNbLives = HERO.nbLives
	self:ResetForNewLevel()
end

function G:StopWalking()
	local m = self.mons
	if m.animState == 7 then return end
	self:SideGoto("stand", false)
	m.vel.x = 0
	m.animState = 4
end

function G:StartWalking(dir)
	local m = self.mons
	if m.animState == 7 then
		m.duckWasWalking = true
	elseif m.animState == 3 then
		m.jumpDir = dir
	else
		m.waitCount = 0
		m.vel.x = dir * HERO.walkSpeed
		m.animState = 2
		FL.GotoAndStop(m.clip, dir > 0 and "right" or "left")
		self:SideGoto("walk", true)
	end
	m.walkDir = dir
end

function G:StartJump()
	local m = self.mons
	if m.mainState == 6 then
		m.jumpWhenHitDone = true
	else
		m.jumpWhenHitDone = false
		m.waitCount = 0
		m.animState = 3
		m.mainState = 1
	end
end

function G:Duck()
	local m = self.mons
	m.duckWasWalking = m.animState == 2
	FL.GotoAndStop(m.clip, m.walkDir > 0 and "right" or "left")
	self:SideGoto("duck", true)
	m.animState = 8
end

function G:Unduck()
	local m = self.mons
	if m.duckWasWalking then self:StartWalking(m.walkDir) else self:StopWalking() end
end

function G:DownOnePlatform()
	local m = self.mons
	local b = self.blocks[m.curBlockID]
	if m.mainState ~= 5 and b and b.canJumpThroughFromAbove then
		m.mainState = 5
		self:SideGoto("air2", false)
		m.vel.x, m.vel.y = 0, 0
	end
end

-- block collisions while moving (monsterCollCheck)
function G:MonsCollCheck()
	local m = self.mons
	local collType = 0
	local pos, vel = m.pos, m.vel
	local steps = math.max(math.floor(vel.y / (m.ySize / 2)) + 1, 1)
	if steps > 1 and pos.y > self.lowestBlockY + 100 then
		-- must be out of the level
		m.mainState = 3
		vel.x, vel.y = 0, 0
		return 0
	end
	for s = 1, steps do
		local lx = pos.x - vel.x + vel.x / steps * s
		local ly = pos.y - vel.y + vel.y / steps * s
		if collType ~= 0 then break end
		local look = self.blockLook[math.floor(ly / 10)]
		if look then
			for _, t in ipairs(look) do
				local b = self.blocks[t]
				local bb = b.bounds
				if b.state == 1 and (m.mainState ~= 4 or (b.monsterFallStopper and t ~= m.curBlockID) or b.absoluteBottom) and (m.mainState ~= 5 or t ~= m.curBlockID) then
					if bb.yMin < ly and bb.yMax > ly - m.ySize and bb.xMin < lx + m.xSize and bb.xMax > lx - m.xSize then
						if vel.y > 0 then
							if bb.yMin >= ly - m.ySize / 2 then
								pos.y = bb.yMin
								if m.mainState ~= 3 and vel.y > 3 then self:PlaySound(HERO.sound_land) end
								vel.y = 0
								collType = 1
								m.curBlockID = t
								if b.touchDamage > 0 then self:GotHitAt(b.touchDamage) collType = 3 end
							end
						elseif not b.canJumpThroughFromBelow then
							if bb.yMin < pos.y - m.ySize / 2 then
								if pos.x > bb.xMin and pos.x < bb.xMax then
									pos.y = bb.yMax + m.ySize
									vel.y = -vel.y * 0.1
									vel.x = vel.x * 0.8
									collType = 2
									if b.touchDamage > 0 then self:GotHitAt(b.touchDamage) collType = 4 end
								elseif pos.x <= bb.xMin then
									pos.x = bb.xMin - m.xSize
								elseif pos.x >= bb.xMax then
									pos.x = bb.xMax + m.xSize
								end
							else
								pos.y = bb.yMin
								vel.y = 0
								collType = 1
								m.curBlockID = t
								if b.touchDamage > 0 then self:GotHitAt(b.touchDamage) collType = 3 end
							end
						end
					end
				end
			end
		end
	end
	return collType
end

function G:MonsWalkCollCheck()
	local m = self.mons
	local b = self.blocks[m.curBlockID]
	if not b then return 1 end
	if b.bounds.xMin > m.pos.x + m.xSize or b.bounds.xMax < m.pos.x - m.xSize then
		m.duckWasWalking = true
		m.pos.y = m.pos.y + 2
		if self:MonsCollCheck() == 1 then return 0 end
		m.pos.y = m.pos.y - 2
		return 1
	elseif b.state == 0 then
		return 1
	end
	return 0
end

function G:MonsWallCollCheck()
	local m = self.mons
	local look = self.wallLook[math.floor(m.pos.x / 10)]
	if not look then return 0 end
	local result = 0
	for _, t in ipairs(look) do
		local w = self.walls[t]
		local wb = w.bounds
		if w.state == 1 and wb.yMin < m.pos.y and wb.yMax > m.pos.y - m.ySize and wb.xMin < m.pos.x + m.xSize and wb.xMax > m.pos.x - m.xSize then
			local mvx = m.pos.x - m.lastPos.x
			result = 1
			if mvx > 0 then
				m.pos.x = wb.xMin - m.xSize
			elseif mvx < 0 then
				m.pos.x = wb.xMax + m.xSize
			elseif m.mainState == 0 then
				if m.vel.y > 0 then m.pos.y = wb.yMin else m.pos.y = wb.yMax + m.ySize end
				m.vel.y = 0
				m.mainState = 0
			end
			if m.mainState ~= 0 then self:StopWalking() end
			if w.touchDamage > 0 then self:GotHitAt(w.touchDamage) m.vel.x = 0 end
		end
	end
	return result
end

function G:GotHitAt(force)
	local m = self.mons
	m.energy = m.energy - force
	m.vel.x, m.vel.y = 0, 0
	if m.energy <= 0 then
		m.energy = 0
		self:MonsDie()
	else
		m.mainState = 6
		m.attackHitCount = MONSTERBEINGHIT_NBFRAMES
	end
	self:UpdateScoreBoard()
	self.lp.damageSuffered = self.lp.damageSuffered + force
end

function G:MonsDie()
	local m = self.mons
	AN.Speak("misterliv")
	if m.mainState == 0 then
		m.vel.x = 0
		if m.vel.y < 0 then m.vel.y = 0 end
	end
	self:SideGoto("die", true)
	m.mainState = 3
	m.dieWhenHitGround = false
	m.duckWasWalking = false
	m.deathCountdown = 40
	self:PlaySound(HERO.sound_die)
end

function G:DeathAnimDone()
	local m = self.mons
	m.curNbLives = m.curNbLives - 1
	if m.curNbLives <= 0 then
		-- out of lives
		AN.Speak("gameoveringenliv")
		self.state = "GAMEOVER"
		self:LevelEnded()
		self:ShowDialog("gameover")
	else
		if self.timeLeft < LEVEL.minTimeAfterRespawn * 1000 then self.timeLeft = LEVEL.minTimeAfterRespawn * 1000 end
		self:ResetForNewLife()
	end
end

-- the hero's hitbox and whole clip in level coordinates (where the clip was drawn last)
function G:HeroM() local m = self.mons return { 1, 0, 0, 1, m.mcx, m.mcy } end
function G:HitboxOf()
	local m = self.mons
	local side = self:Side()
	if not side then return nil end
	local sm = FL.ChildMatrix(m.clip, "side", self:HeroM())
	local hm, hb = FL.ChildMatrix(side, "hitbox", sm)
	return hb, hm
end

function G:FallerCollCheckMons()
	local m = self.mons
	local hb, hm = self:HitboxOf()
	for f = 1, #self.fallers do
		local fl = self.fallers[f]
		if fl.mainState ~= 2 and self.clock - fl.spawntime > 500 then
			local dy = math.abs(m.pos.y - fl.mcy)
			if dy < FALLER_RANGESENSIBILITY then
				local dx = math.abs(m.pos.x - fl.mcx)
				if dx < FALLER_RANGESENSIBILITY then
					self:PlatSoundNear(fl.p.soundLoop, fl.pos, dx * dx + dy * dy)
					if hb and FL.HitTest(fl.clip, { 1, 0, 0, 1, fl.mcx, fl.mcy }, hb, hm) then
						self:FallerHit(f)
						break
					end
					local coming, away = false, false
					if fl.curBlockID == m.curBlockID and self.clock - fl.giveScoreTime > RECEIVE_SCORE_FOR_SAME_FALLER_PAUSE and m.mainState ~= 4 then
						if fl.vel.x > 0 and m.pos.x > fl.pos.x then coming = true
						elseif fl.vel.x < 0 and m.pos.x < fl.pos.x then coming = true
						else away = true end
						if coming and self.clock - fl.approachPlayerTime > 2000 then fl.approachPlayerTime = self.clock end
						if away and self.clock - fl.approachPlayerTime < 4000 then
							-- dodged it
							self:DoPopPoint(fl.p.scoreDodge, fl.pos.x, fl.pos.y)
							self:AddScore(fl.p.scoreDodge)
							self:PlaySound("poppoint")
							fl.giveScoreTime = self.clock
						end
					end
				end
			end
		end
	end
end

function G:FallerHit(f)
	local m = self.mons
	local fl = self.fallers[f]
	if m.mainState == 4 or m.mainState == 3 or m.mainState == 6 or fl.mainState == 2 then return end
	local e = fl.p.contactEffect
	if e == "looseenergy" then
		self:GotHitAt(fl.p.attackPower)
		self:FallerDie(fl)
	elseif e == "falldown" then
		m.mainState = 4
		self:SideGoto("air2", false)
		m.vel.x, m.vel.y = 0, 0
	elseif e == "falldownandlooseenergy" then
		self:GotHitAt(fl.p.attackPower)
		if m.energy > 0 then
			self:SideGoto("air2", false)
			m.mainState = 4
			m.vel.x, m.vel.y = 0, 0
			AN.Speak("skidt")
		end
		self:FallerDie(fl)
	end
end

function G:ItemsCollCheck()
	local m = self.mons
	local idx = math.floor(math.floor(m.pos.y / ITEMLOOKUP_RESOLUTION) * self.itemLW + m.pos.x / ITEMLOOKUP_RESOLUTION)
	local look = self.itemLook[idx]
	if not look then return end
	local hb, hm = self:HitboxOf()
	if not hb then return end
	for _, tt in ipairs(look) do
		local it = self.items[tt]
		if it.active and FL.HitTest(it.clip, { 1, 0, 0, 1, it.mcx, it.mcy }, hb, hm) then
			if it.requiredForCompletion then
				m.nbItemsPickedUp = m.nbItemsPickedUp + 1
				self.lp.nbItemsLeft = self.lp.nbItemsLeft - 1
				self:UpdateScoreBoard()
				self:DoPopPoint(ITEM.scoreForPickup, it.pos.x, it.pos.y)
				self:AddScore(ITEM.scoreForPickup)
				table.insert(self.lp.itemsPickedUp, ITEM.scoreForPickup)
			end
			FL.GotoAndStop(it.clip, "disappear")
			it.active = false
			self:PlaySound(ITEM.sound_pickup)
		end
	end
end

-- monsterSetKey
function G:SetKey(key, state)
	local m = self.mons
	local k = m.keys
	if key == "right" or key == "left" then
		local dir = key == "right" and 1 or -1
		if m.mainState == 0 then
			if state then
				if (dir > 0 and m.vel.x <= 0) or (dir < 0 and m.vel.x >= 0) then
					m.vel.x = m.vel.x + dir * HERO.walkSpeed
					FL.GotoAndStop(m.clip, dir > 0 and "right" or "left")
					m.duckWasWalking = true
				end
			elseif dir < 0 then
				m.duckWasWalking = false
			end
		elseif m.mainState == 1 then
			if k[key] then
				self:StartWalking(dir)
				if dir > 0 then k.left = false else k.right = false end
			elseif not k.right and not k.left then
				if m.animState ~= 6 and m.animState ~= 8 then self:StopWalking() end
				m.duckWasWalking = false
			end
		end
	elseif key == "jump" then
		if m.mainState == 1 then
			if m.animState ~= 7 then
				if m.animState == 2 then m.duckWasWalking = true end
				if k.jump then self:StartJump() end
			end
		elseif m.mainState == 6 then
			if k.jump then self:StartJump() end
		end
	elseif key == "down" then
		if m.mainState == 1 and state then self:DownOnePlatform() end
	elseif key == "duck" then
		if m.mainState == 0 then
			m.mustDuck = true
		elseif m.mainState == 1 then
			if state then
				if m.animState ~= 8 then self:Duck() end
			elseif m.animState == 8 then
				self:Unduck()
			end
		end
	end
end

-- monsterCheckKeys: the keys that changed since the last frame
function G:CheckKeys()
	local k = self.mons.keys
	local now = {
		right = input.IsKeyDown(KEY_RIGHT), left = input.IsKeyDown(KEY_LEFT),
		down = input.IsKeyDown(KEY_DOWN), jump = input.IsKeyDown(KEY_UP), duck = input.IsKeyDown(KEY_DOWN),
	}
	for _, key in ipairs({ "right", "left", "down", "jump", "duck" }) do
		if (k[key] or false) ~= now[key] then
			k[key] = now[key]
			self:SetKey(key, now[key])
		end
	end
end

function G:MonsLoop()
	local m = self.mons
	local pos, vel = m.pos, m.vel
	m.lastPos.x, m.lastPos.y = pos.x, pos.y
	local jp = HERO.jumpPower
	if m.mainState == 0 then
		vel.x = vel.x * 0.99
		vel.y = (vel.y + GRAVITY) * 0.98
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		if vel.y > 0 then m.fallAccum = m.fallAccum + vel.y end
		local a = m.animSubState
		if a == 0 then
			if vel.y > -jp * 0.8 then m.animSubState = 1 self:SideGoto("air1", true) end
		elseif a == 1 then
			if vel.y > -jp * 0.15 then m.animSubState = 2 self:SideGoto("air2", false) end
		elseif a == 2 then
			if vel.y > jp * 0.15 then m.animSubState = 3 self:SideGoto("air3", false) end
		elseif a == 3 then
			if vel.y > jp * 0.6 then m.animSubState = 4 self:SideGoto("fall", false) end
		elseif a == 4 then
			if vel.y > 18 then self:SideGoto("fall", false) end
		elseif a == 5 then
			m.waitCount = m.waitCount + 1
			if m.waitCount > 5 then m.waitCount = 0 m.animSubState = 0 self:SideGoto("air1", false) end
		end
		local ct = self:MonsCollCheck()
		if ct == 1 or ct == 3 then
			if m.fallAccum > HERO.safeFalldownHeight then m.dieWhenHitGround = true end
			m.fallAccum = 0
			if not m.dieWhenHitGround then
				if ct == 1 then
					m.animState = 1
					m.mainState = 1
					if m.keys.right then self:StartWalking(1)
					elseif m.keys.left then self:StartWalking(-1)
					else self:SideGoto("land", true) end
				else
					m.mainState = 6
					vel.x = 0
					vel.y = -jp
				end
			end
			m.animSubState = 0
			if m.mustDuck then self:Duck() m.mustDuck = false end
			if m.dieWhenHitGround then self:MonsDie() end
		elseif ct == 2 then
			self:SideGoto("airhit", true)
			self:PlaySound(HERO.sound_hithead)
			m.animSubState = 4
		end
	elseif m.mainState == 1 then
		local an = m.animState
		if an == 1 then
			vel.x = vel.x * 0.7
			if vel.x < 1 then vel.x = 0 m.animState = 4 end
			pos.x = pos.x + vel.x
			pos.y = pos.y + vel.y
		elseif an == 2 then
			pos.x = pos.x + vel.x
			pos.y = pos.y + vel.y
			local side = self:Side()
			if side and side.vars.footstep then
				self:PlaySound(HERO.sound_footstep)
				side.vars.footstep = false
			end
		elseif an == 3 then
			m.waitCount = m.waitCount + 1
			if m.waitCount <= 2 then
				self:SideGoto("jumpantic", false)
			else
				if m.jumpDir ~= 0 then
					vel.x = m.jumpDir * HERO.walkSpeed / 3
					m.jumpDir = 0
				end
				vel.y = -jp
				vel.x = vel.x * 2
				m.animState = 0
				m.mainState = 0
				self:SideGoto("jump", false)
				m.waitCount = 0
				self:PlaySound(HERO.sound_jump)
			end
		elseif an == 4 or an == 5 then
			pos.x = pos.x + vel.x
			pos.y = pos.y + vel.y
		end
		if self:MonsWalkCollCheck() == 1 then
			-- walked off the shelf
			m.mainState = 0
			m.animState = 0
		end
	elseif m.mainState == 4 or m.mainState == 5 then
		vel.x = vel.x * 0.99
		vel.y = (vel.y + GRAVITY) * 0.98
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		if self:MonsCollCheck() == 1 then
			m.animState = 1
			m.mainState = 1
			m.keys.right, m.keys.left = false, false
			self:SideGoto("land", true)
			m.animSubState = 0
		end
	elseif m.mainState == 3 then
		vel.x = vel.x * 0.9
		vel.y = (vel.y + GRAVITY) * 0.98
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		self:MonsCollCheck()
		m.deathCountdown = m.deathCountdown - 1
		local side = self:Side()
		if (side and side.vars.deathAnimDone) or m.deathCountdown <= 0 then self:DeathAnimDone() end
	elseif m.mainState == 6 then
		m.attackHitCount = m.attackHitCount - 1
		vel.y = (vel.y + GRAVITY) * 0.9
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		self:MonsCollCheck()
		if m.attackHitCount <= 0 then
			m.mainState = 0
			vel.y = 0
			if m.jumpWhenHitDone then
				if m.keys.left then m.jumpDir = -2 end
				if m.keys.right then m.jumpDir = 2 end
				self:StartJump()
			end
		end
	end
	if m.mainState ~= 3 then
		self:MonsWallCollCheck()
		self:PlatSoundStart()
		self:FallerCollCheckMons()
		self:PlatSoundConclude()
		self:ItemsCollCheck()
	end
	m.mcx, m.mcy = pos.x, pos.y
	self:CheckKeys()
	self.listX, self.listY = pos.x, pos.y
end

---------------------------------------------------------------------------
-- the loop sounds of things nearby (platSoundFallerStartCheck / Near / Conclude)
---------------------------------------------------------------------------
function G:PlatSoundStart()
	self.skipMod = self.skipMod + 1
	if self.skipMod % UPDATESOUND_FRAMEINTERVAL ~= 0 then return end
	self.nearSounds = {}
end

function G:PlatSoundNear(id, pos, dist)
	if self.skipMod % UPDATESOUND_FRAMEINTERVAL ~= 0 then return end
	if not id or id == "" then return end
	local n = self.nearSounds[id]
	if not n then
		self.nearSounds[id] = { distance = dist, x = pos.x, y = pos.y }
	elseif n.distance > dist then
		n.distance = dist
	end
end

function G:PlatSoundConclude()
	if self.skipMod % UPDATESOUND_FRAMEINTERVAL ~= 0 then return end
	for _, l in pairs(self.loopsnd) do l.playing = false end
	for id, n in pairs(self.nearSounds) do self:LoopSound(id, n.x, n.y) end
	for id, l in pairs(self.loopsnd) do
		if not l.playing then
			l.stopped = true
			if IsValid(l.ch) then l.ch:Stop() end
			self.loopsnd[id] = nil
		end
	end
end

---------------------------------------------------------------------------
-- the falling things
---------------------------------------------------------------------------
function G:NewFaller(lib, x, y)
	local key = string.lower(lib)
	local p = FALLER[key]
	if not p then return nil end
	local clip = FL.New("g01sg", lib)
	local side = FL.Child(clip, "side")
	if side then FL.GotoAndPlay(side, "on") end
	local x0, y0, x1, y1 = FL.Bounds(clip, { 1, 0, 0, 1, 0, 0 }, true)
	if side then FL.GotoAndPlay(side, "enter") end
	local f = {
		lib = lib, p = p, mainState = 0, pos = { x = x, y = y }, lastPos = { x = x, y = y }, vel = { x = 0, y = 0 },
		floatPos = { x = x, y = y }, floatVel = { x = 0, y = 0 }, dead = false, curBlockID = -1,
		clip = clip, xSize = ((x1 or 0) - (x0 or 0)) / 2, ySize = (y1 or 0) - (y0 or 0),
		speed = p.speed, lifeTime = 0, spawntime = self.clock, pathID = 1, recordPath = false,
		approachPlayerTime = 0, giveScoreTime = 0, mcx = x, mcy = y, rot = 0,
	}
	return f
end

function G:FallerSetDir(f)
	FL.GotoAndStop(f.clip, f.vel.x < 0 and "left" or "right")
end

function G:FallerCollCheck(f)
	local collType = 0
	local pos, vel = f.pos, f.vel
	local fh = f.p.flyHeight
	local steps = math.max(math.floor((vel.y + f.floatVel.y) / (f.ySize / 2)) + 1, 1)
	for s = 1, steps do
		local lx = pos.x - vel.x + vel.x / steps * s
		local ly = pos.y - vel.y + vel.y / steps * s + fh
		if collType ~= 0 then break end
		local look = self.blockLook[math.floor(ly / 10)]
		if look then
			for _, t in ipairs(look) do
				local b = self.blocks[t]
				local bb = b.bounds
				if b.state == 1 and bb.yMin < ly and bb.yMax > ly - f.ySize and bb.xMin < lx + f.xSize and bb.xMax > lx - f.xSize then
					if vel.y > 0 then
						if bb.yMin >= ly - f.ySize / 2 then
							pos.y = bb.yMin - fh
							collType = 1
							f.curBlockID = t
						end
					elseif bb.yMin < ly - f.ySize / 2 then
						pos.y = bb.yMax + f.ySize - fh
						collType = 2
						f.curBlockID = t
					else
						pos.y = bb.yMin - fh
						collType = 1
						f.curBlockID = t
					end
					if b.fallKiller then collType = 3 end
				end
			end
		end
	end
	return collType
end

-- recording a path (fallerRecordLoop), only done while prespooling
function G:FallerRecordLoop(f)
	local p = f.p
	local pos, vel = f.pos, f.vel
	local snd = ""
	f.lastPos.x, f.lastPos.y = pos.x, pos.y
	f.lifeTime = f.lifeTime - 40
	if f.lifeTime < 0 and f.mainState ~= 2 then f.mainState = 2 end
	if f.mainState == 0 then
		if p.fallDown then
			vel.y = (vel.y + p.weight) * 0.99
		elseif vel.x == 0 then
			vel.x = f.speed
		end
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		local last = f.curBlockID
		local ct = p.fallDown and self:FallerCollCheck(f) or 0
		if ct == 1 then
			if last == -1 then vel.x = f.speed end
			vel.y = -vel.y * p.bounceFactor
			if math.abs(vel.y) > 3 then snd = p.soundBounce end
			if math.abs(vel.y) < 1 then vel.y = 0 f.mainState = 1 end
		elseif ct == 2 then
			vel.y = -vel.y * p.bounceFactor
			if math.abs(vel.y) > 3 then snd = p.soundBounce end
		elseif ct == 3 then
			f.mainState = 2
			if math.abs(vel.y) > 3 then snd = p.soundDie end
		end
	elseif f.mainState == 1 then
		pos.x = pos.x + vel.x
		pos.y = pos.y + vel.y
		local b = self.blocks[f.curBlockID]
		if b and (pos.x < b.bounds.xMin + 30 or pos.x > b.bounds.xMax - 30) then f.mainState = 0 end
	end
	local mx, my
	if p.floatiness ~= 0 then
		f.floatVel.x = f.floatVel.x + (pos.x - f.floatPos.x) * p.floatiness
		f.floatVel.y = f.floatVel.y + (pos.y - f.floatPos.y) * p.floatiness
		f.floatPos.x = f.floatPos.x + f.floatVel.x
		f.floatPos.y = f.floatPos.y + f.floatVel.y
		f.floatVel.x = f.floatVel.x * p.floatinessFalloff
		f.floatVel.y = f.floatVel.y * p.floatinessFalloff
		mx, my = f.floatPos.x, f.floatPos.y
	else
		mx, my = pos.x, pos.y
	end
	if f.mainState ~= 2 then
		table.insert(f.path, { x = mx, y = my, velX = vel.x, mainState = f.mainState, curBlockID = f.curBlockID, snd = snd })
	end
end

function G:FallerDie(f)
	f.mainState = 2
	local side = FL.Child(f.clip, "side")
	if side then FL.GotoAndPlay(side, "die") end
	self:PlaySound(f.p.soundDie, f.pos.x, f.pos.y)
end

function G:InCam(x, y)
	return x > self.camX - self.camOffX - CAMERAEXTEND and x < self.camX + self.camOffX + CAMERAEXTEND
		and y > self.camY - self.camOffY - CAMERAEXTEND and y < self.camY + self.camOffY + CAMERAEXTEND
end

function G:FallerPlayback(f)
	if f.mainState ~= 2 then
		local path = f.path
		if f.pathID <= #path then
			local pt = path[f.pathID]
			f.pos.x, f.pos.y = pt.x, pt.y
			if self:InCam(pt.x, pt.y) then
				f.mcx, f.mcy = pt.x, pt.y
				f.clip.visible = true
			else
				f.clip.visible = false
			end
			f.vel.x = pt.velX
			self:FallerSetDir(f)
			f.curBlockID = pt.curBlockID
			if pt.snd ~= "" then self:PlaySound(pt.snd, f.pos.x, f.pos.y) end
			f.mainState = pt.mainState
			f.pathID = f.pathID + 1
		elseif f.pathID == #path + 1 then
			self:FallerDie(f)
			f.pathID = f.pathID + 1
		end
	elseif f.clip.vars.dead then
		f.dead = true
	end
end

function G:SpawnFaller(s, lib, record)
	if #self.fallers >= MAX_NUM_FALLERS then return end
	local f = self:NewFaller(lib, s.x, s.y)
	if not f then return end
	f.lifeTime = s.spawnObjLifetimeMS
	local found
	for _, rp in ipairs(s.recordedPath) do
		if rp.lib == lib then found = rp break end
	end
	if not found then
		found = { lib = lib }
		table.insert(s.recordedPath, found)
		f.recordPath = true
	end
	f.path = found
	f.speed = f.speed * s.spawnXDir
	table.insert(self.fallers, f)
	return f
end

function G:SpawnLoop()
	for _, s in ipairs(self.spawners) do
		if s.difficultyOnOff[self.curDifficulty] then
			s.spawnCount = s.spawnCount + MS
			if s.spawnCount >= s.curSpawnInterval and s.numSpawnsCount < s.numSpawns then
				if s.spawnActive then
					self:SpawnFaller(s, s.libTypes[math.random(#s.libTypes)])
				end
				s.spawnCount = 0
				s.numSpawnsCount = s.numSpawnsCount + 1
			end
		end
	end
end

function G:EvaluateActivation()
	local m = self.mons
	for _, s in ipairs(self.spawners) do
		if s.allowPerformanceDisabling then
			local dx, dy = s.x - m.pos.x, s.y - m.pos.y
			s.spawnActive = dx * dx + dy * dy <= self.fallerDisableDistSQR
		end
	end
end

-- before the game: every spawner sends one of each of its things, and their paths are recorded
function G:InitPrespool()
	self.fallers = {}
	for _, s in ipairs(self.spawners) do
		for _, lib in ipairs(s.libTypes) do self:SpawnFaller(s, lib) end
	end
	self.prespoolLength = 0
end

function G:Prespool(n)
	for _ = 1, n do
		for i = #self.fallers, 1, -1 do
			local f = self.fallers[i]
			if f.mainState ~= 2 then self:FallerRecordLoop(f) end
		end
		self.prespoolLength = self.prespoolLength + 1
		if self.prespoolLength > PRESPOOL_FRAMES then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- score
---------------------------------------------------------------------------
function G:AddScore(v)
	self.score = self.score + v
	self.scoreAccum = self.scoreAccum + v
	if self.score < 0 then self.score = 0 end
end

function G:ScoreUpdate()
	if math.floor(self.scoreAccum) ~= 0 then
		local a = self.scoreAccum
		-- (the original compares Math.abs(scoreAccum > 100), so negative amounts count down one by one)
		local d
		if a > 100 then d = 100
		elseif a > 10 then d = 10
		else d = a <= 0 and -1 or 1 end
		self.showScore = self.showScore + d
		if self.showScore < 0 then self.showScore = 0 end
		self.scoreAccum = self.scoreAccum - d
		self:UpdateScoreBoard()
	end
end

function G:DoPopPoint(val, x, y)
	local p = self.pops[self.nextPop]
	p.x, p.y = x, y
	p.clip.visible = true
	p.clip.vars.amountTxt = val
	FL.GotoAndPlay(p.clip, val > 0 and "good" or "bad")
	self.nextPop = self.nextPop % #self.pops + 1
end

function G:UpdateScoreBoard()
	local m = self.mons
	local sec = math.max(0, math.floor(self.timeLeft / 1000) + 1)
	local v = self.vars
	v.txtscore = math.floor(self.showScore)
	v.txttimeleft = fmtTime(sec)
	v.txtdifficulty = self.curDifficulty + 1
	v.txtitemsleft = self.lp.nbItemsLeft
	v.txtlives = m.curNbLives
	local panel = FL.Child(self.gui, "scorePanel")
	if panel then
		-- (the original's meters: energy and "mæthed", how much of the porridge is eaten)
		local e = FL.Child(panel, "energy")
		if e then FL.GotoAndStop(e, math.floor(m.energy / HERO.maxEnergy * 100) + 1) end
		local tot = self.lp.nbRequiredItemsTotal
		local mt = FL.Child(panel, "maethed")
		if mt then FL.GotoAndStop(mt, tot > 0 and math.floor(100 - self.lp.nbItemsLeft / tot * 100) + 1 or 101) end
		local ll = FL.Child(panel, "livesleft")
		if ll then FL.GotoAndStop(ll, m.curNbLives + 1) end
		panel.visible = true
	end
end

-- the stats count on the level complete board (scoreStat_update)
function G:ScoreStatUpdate()
	local lc = FL.Child(self.gui, "levelComplete")
	if not (lc and lc.vars.readyForstats) then return end
	local lp = self.lp
	if self.statType == -1 then self.statType = 0 end
	if self.statType == 999 then
		-- the level's own score (porridge, dodges and the time bonus) on its own list
		AN.LevelScore(1, self.curDifficulty + 1, self.score - (self.levelStartScore or 0), { total = self.score })
		self.state = "PAUSE"
		FL.NextFrame(lc)
		return
	end
	local v = self.vars
	if self.statType == 0 then
		if lp.timeRemainingMS > 500 then
			local nbr = 1
			if lp.timeRemainingMS > 100000 then nbr = 25
			elseif lp.timeRemainingMS > 60000 then nbr = 10
			elseif lp.timeRemainingMS > 10000 then nbr = 5 end
			local scr = LEVEL.pointsPrSecondLeft
			lp.remainTimeScoreAcc = lp.remainTimeScoreAcc + scr * nbr
			lp.totalScore = lp.totalScore + scr * nbr
			lp.timeRemainingMS = math.max(0, lp.timeRemainingMS - 1000 * nbr)
			self:AddScore(scr * nbr)
		else
			lp.timeRemainingMS = 0
			self.statType = 2
		end
		v.txt_timeusedpoints = lp.remainTimeScoreAcc
		v.txt_timeused = fmtTime(math.max(0, math.floor(lp.endTimeRemainingMS / 1000)))
		v.txt_total = math.floor(lp.totalScore)
	elseif self.statType == 2 then
		if #lp.itemsPickedUp > 0 then
			lp.itemAcc = lp.itemAcc + 1
			local last = table.remove(lp.itemsPickedUp)
			lp.itemScoreAcc = lp.itemScoreAcc + last
			lp.totalScore = lp.totalScore + last
			v.txt_itemspickedpoints = lp.itemScoreAcc
			v.txt_itemspicked = lp.itemAcc
			v.txt_total = math.floor(lp.totalScore)
		else
			self.statType = 999
		end
	end
end

function G:ScoreStatReset()
	local lp = self.lp
	lp.itemsPickedUp = {}
	lp.timeRemainingMS, lp.endTimeRemainingMS, lp.damageSuffered = 0, 0, 0
	lp.itemScoreAcc, lp.remainTimeScoreAcc, lp.itemAcc, lp.totalScore = 0, 0, 0, 0
	self.statType = -1
	local lc = FL.Child(self.gui, "levelComplete")
	if lc then lc.vars.readyForstats = false end
	local v = self.vars
	v.txt_itemspickedpoints, v.txt_itemspicked, v.txt_timeusedpoints, v.txt_timeused = 0, 0, 0, 0
	v.txt_damagesufferedpoints, v.txt_damagesuffered, v.txt_total = 0, 0, 0
end

---------------------------------------------------------------------------
-- the game controller
---------------------------------------------------------------------------
function G:ShowDialog(name)
	local d = FL.Child(self.gui, name)
	if not d then return end
	d.visible = true
	FL.GotoAndStop(d, "appear")
	if name == "levelComplete" then
		d.vars.readyForstats = false
		return
	end
	self.vars.score = self.score
	-- GAMEENDED: the loader goes on by itself after 3 seconds
	self.endTimer = 3
end

function G:SetCurtain(show)
	local c = FL.Child(self.gui, "curtain")
	if not c then return end
	if (not show and self.curtainOn) or self.curtainOn == nil then
		FL.GotoAndPlay(c, "open")
		self.curtainOn = false
	elseif show and not self.curtainOn then
		FL.GotoAndPlay(c, "close")
		self.curtainOn = true
	end
end

function G:SetProgress(v)
	local c = FL.Child(self.gui, "curtain")
	local p = c and FL.Child(c, "progress")
	if not p then return end
	if not v then p.visible = false return end
	p.visible = true
	FL.GotoAndStop(p, math.floor(v * 100) + 1)
end

function G:LevelEnded()
	self:StopLoops()
end

function G:CameraNearest()
	local m = self.mons
	local best, bestD = nil, 9999999
	for i, f in ipairs(self.camFrames) do
		local cx = f.xMin + (f.xMax - f.xMin) / 2
		local cy = f.yMin + (f.yMax - f.yMin) / 2
		local d = (cx - m.pos.x) ^ 2 + (cy - m.pos.y) ^ 2
		if f.viewPreferenceFactor ~= 0 then d = d / f.viewPreferenceFactor end
		if d < bestD then best, bestD = i, d end
	end
	return best
end

function G:CameraGoHome()
	local id = self:CameraNearest()
	local f = self.camFrames[id]
	self.lastCamID = id
	self.camX = f.xMin + self.camOffX
	self.camY = f.yMin + self.camOffY
	self.lastCamPos = { x = self.mons.pos.x, y = self.mons.pos.y }
end

function G:UpdateCamera()
	local m = self.mons
	if m.curBlockID == self.lastCamBlock and m.mainState ~= 4 then return end
	if math.abs(m.pos.x - self.lastCamPos.x) + math.abs(m.pos.y - self.lastCamPos.y) >= 10 then
		local id = self:CameraNearest()
		if self.lastCamID ~= id then
			self.lastCamID = id
			local f = self.camFrames[id]
			self.camX = f.xMin + (f.xMax - f.xMin) / 2
			self.camY = f.yMin + (f.yMax - f.yMin) / 2
			self.lastCamPos = { x = m.pos.x, y = m.pos.y }
		end
		self.lastCamBlock = m.curBlockID
	end
end

function G:RemoveFallers()
	self.fallers = {}
end

function G:RestartLevel()
	self.levelStartScore = self.score
	self.forced = false
	self.levelCompleted = false
	self:ResetForNewLife()
	local lp = self.lp
	lp.nbRequiredItemsTotal = 0
	for _, it in ipairs(self.items) do
		-- itemReset
		if #it.includedDifficulties == 0 then
			it.diffactive = true
		else
			it.diffactive = false
			for _, d in ipairs(it.includedDifficulties) do
				if (tonumber(d) or 0) - 1 == self.curDifficulty then it.diffactive = true break end
			end
		end
		it.active = it.diffactive and it.activationTimeMS <= 0
		it.clip.visible = it.active
		if it.active then FL.GotoAndStop(it.clip, "on") else FL.GotoAndStop(it.clip, 1) end
		it.pos.x, it.pos.y = it.startPos.x, it.startPos.y
		if it.lieOnGround then self:ItemFindFloor(it) end
		if it.requiredForCompletion and it.diffactive then lp.nbRequiredItemsTotal = lp.nbRequiredItemsTotal + 1 end
	end
	lp.nbItemsLeft = lp.nbRequiredItemsTotal
	self.timeLeft = LEVEL.levelTime - LEVEL.lessTimePrDifficulty * self.curDifficulty
	if self.timeLeft <= 0 then self.timeLeft = 28800 end
	self.timeLeft = self.timeLeft * 1000
	self:UpdateScoreBoard()
	self:RemoveFallers()
	for _, s in ipairs(self.spawners) do
		s.spawnCount = s.initialTime
		s.curSpawnInterval = s.spawnInterval + s.curLevelCount * s.spawnIntervalAddPrDifficulty
		s.numSpawnsCount = 0
		s.spawnActive = true
	end
	self:ScoreStatReset()
	self.state = "RUNNING"
	self:CameraGoHome()
	self:EvaluateActivation()
	self:SetCurtain(false)
end

function G:ItemFindFloor(it)
	local function coll()
		local look = self.blockLook[math.floor(it.pos.y / 10)]
		if not look then return 0 end
		for _, t in ipairs(look) do
			local b = self.blocks[t]
			local bb = b.bounds
			if b.state == 1 and bb.yMin < it.pos.y and bb.yMax > it.pos.y - it.ySize and bb.xMin < it.pos.x + it.xSize and bb.xMax > it.pos.x - it.xSize then
				if not b.canJumpThroughFromBelow then
					if bb.yMin < it.pos.y - it.ySize / 2 then
						it.pos.y = bb.yMax + it.ySize
						return 2
					else
						it.pos.y = bb.yMin
						return 1
					end
				end
			end
		end
		return 0
	end
	local chk = coll()
	local giveUp = 100
	while chk ~= 1 and giveUp > 0 do
		it.pos.y = it.pos.y + 5
		chk = coll()
		giveUp = giveUp - 1
	end
	it.mcx, it.mcy = it.pos.x, it.pos.y
end

function G:NextLevel()
	self.curLevelID = self.curLevelID + 1
	if self.curDifficulty < LEVEL.numDifficulties then
		self.curDifficulty = self.curDifficulty + 1
		self:RestartLevel()
	else
		-- the whole game is done
		self.levelCompleted = true
		self.state = "PAUSED"
		self:ShowDialog("gameCompleted")
		AN.Speak("megetgodt")
		if self.mons.mainState == 1 then self:StopWalking() end
	end
end

function G:CheckCurtain()
	local c = FL.Child(self.gui, "curtain")
	if c and c.vars.state == self.curtainDest then
		if self.curtainAction == "NEXTLEVEL" then self:NextLevel() end
	end
end

function G:SetCurtainAndAction(show, action)
	self:SetCurtain(show)
	self.curtainDest = show and "CLOSED" or "OPEN"
	self.curtainAction = action
	self.state = "CURTAINPAUSE"
end

function G:ContinueClick()
	self:LevelEnded()
	self:SetCurtainAndAction(true, "NEXTLEVEL")
	local lc = FL.Child(self.gui, "levelComplete")
	if lc then FL.Play(lc) end
end

function G:HeroBoundsHit(r)
	local x0, y0, x1, y1 = FL.Bounds(self.mons.clip, self:HeroM(), true)
	if not x0 then return false end
	return x0 <= r.xMax and r.xMin <= x1 and y0 <= r.yMax and r.yMin <= y1
end

function G:CheckGameCompleted()
	self.completeTest = self.completeTest + 1
	local m = self.mons
	if not (self.forced or (self.completeTest % 25 == 0 and not self.levelCompleted and m.mainState == 1)) then return end
	local nbOK = self.forced and 2 or 0
	local onEnd = false
	-- reachCompletionHitTester
	if self:HeroBoundsHit(self.complTester) then
		onEnd = true
		nbOK = nbOK + 1
	else
		self.lastOnEnd = false
		if not self.forced then return end
	end
	-- pickupAllItems
	if self.lp.nbItemsLeft <= 0 then nbOK = nbOK + 1 end
	if nbOK >= #LEVEL.winLevel then
		self.levelCompleted = true
		self.state = "SCORESTATUS"
		self.lp.timeRemainingMS = self.timeLeft
		self.lp.endTimeRemainingMS = self.timeLeft
		self:LevelEnded()
		self:ShowDialog("levelComplete")
		AN.Speak("megetgodt")     -- the loader's GAMECOMPLETED event (the only level is also the last)
		if m.mainState == 1 then self:StopWalking() end
		return
	end
	if onEnd and onEnd ~= self.lastOnEnd then
		local d = FL.Child(self.gui, "stillNeedItems")
		if d then d.visible = true FL.GotoAndPlay(d, "appear") end
	end
	self.lastOnEnd = onEnd
end

-- one frame of the running game (gameDrawProto)
function G:Draw()
	if self.state == "RUNNING" then
		self.timeLeft = self.timeLeft - MS
		self:UpdateScoreBoard()
		if self.timeLeft < 0 and not self.levelCompleted then
			self.state = "GAMEOVER"
			self:LevelEnded()
			self:ShowDialog("gameovertimeout")
		end
	end
	self:MonsLoop()
	self:SpawnLoop()
	if self.activationCount == 0 then self:EvaluateActivation() end
	self.activationCount = (self.activationCount + 1) % 25
	for i = #self.fallers, 1, -1 do
		local f = self.fallers[i]
		self:FallerPlayback(f)
		if f.dead then table.remove(self.fallers, i) end
	end
	self:ScoreUpdate()
	self:UpdateCamera()
	self:CheckGameCompleted()
end

function G:Step()
	self.clock = self.clock + MS
	-- the clips' own timelines
	FL.Tick(self.gui)
	FL.Tick(self.level)
	FL.Tick(self.mons.clip)
	for _, f in ipairs(self.fallers) do FL.Tick(f.clip) end
	for _, it in ipairs(self.items) do FL.Tick(it.clip) end
	for _, p in ipairs(self.pops) do FL.Tick(p.clip) end

	local st = self.state
	if st == "PRESPOOLING" then
		self:SetProgress(math.min(1, self.prespoolLength / PRESPOOL_FRAMES))
		if self.prespoolDone then
			self.state = "RUNNING"
			self:RestartLevel()
			self:SetProgress(nil)
			self:SetCurtain(false)
		else
			self.prespoolDone = self:Prespool(40)
		end
	elseif st == "RUNNING" then
		self:Draw()
		self:HintStep()
	elseif st == "CURTAINPAUSE" then
		self:CheckCurtain()
	elseif st == "PAUSED" then
		self:ScoreUpdate()
	elseif st == "SCORESTATUS" then
		self:ScoreStatUpdate()
		self:ScoreUpdate()
	end

	for _, l in pairs(self.loopsnd) do self:LoopVolume(l) end

	if self.endTimer then
		self.endTimer = self.endTimer - STEP
		if self.endTimer <= 0 then self:Finish() end
	end
end

---------------------------------------------------------------------------
-- cut content: the level has a thought bubble by the start (Pyrus dreaming of his teddy bear, the
-- "pigeBamse" the hero clip is named after) that the engine never plays. With hidden content on
-- it is played when the game starts. (The level's other unused clip, "endAnim" by the magic book,
-- is only an unfinished grey placeholder, so it is left alone.)
---------------------------------------------------------------------------
function G:CutBubble()
	local b = FL.Child(self.level, "bubble")
	if b then FL.GotoAndPlay(b, "on") end
end

---------------------------------------------------------------------------
-- hint: the engine's own "arrow" clip (made to point from the camera to things off screen, never
-- used) points from Pyrus to the porridge bowls left on the level, for 5 seconds
---------------------------------------------------------------------------
local HINT_FRAMES = 125
function G:CanHint()
	return self.state == "RUNNING" and self.lp and (self.lp.nbItemsLeft or 0) > 0
end
function G:Hint(cost)
	local m = self.mons
	local left = {}
	for _, it in ipairs(self.items) do
		if it.active and it.requiredForCompletion then
			left[#left + 1] = { it = it, d = (it.mcx - m.mcx) ^ 2 + (it.mcy - m.mcy) ^ 2 }
		end
	end
	if #left == 0 then return false end
	table.sort(left, function(a, b) return a.d < b.d end)
	self.hintArrows = {}
	for i = 1, math.min(3, #left) do
		local c = FL.New("g01sg", "arrow")
		FL.GotoAndPlay(c, "appear")
		self.hintArrows[i] = { clip = c, it = left[i].it }
	end
	self.hintLeft = HINT_FRAMES
	self:AddScore(-cost)
	self:DoPopPoint(-cost, m.mcx, m.mcy - 60)
end
function G:HintStep()
	if not self.hintLeft then return end
	self.hintLeft = self.hintLeft - 1
	for _, a in ipairs(self.hintArrows) do FL.Tick(a.clip) end
	if self.hintLeft <= 0 or self.state ~= "RUNNING" then self.hintLeft, self.hintArrows = nil, nil end
end
function G:HintDraw(ax, ay)
	if not self.hintArrows then return end
	local m = self.mons
	for i, a in ipairs(self.hintArrows) do
		if a.it.active then
			-- placed a little way from Pyrus towards the bowl, pointing at it (the clip points up)
			local dx, dy = a.it.mcx - m.mcx, a.it.mcy - (m.mcy - 40)
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			local ux, uy = dx / len, dy / len
			local r = 70 + (i - 1) * 10
			local ang = math.atan2(ux, -uy)
			local cs, sn = math.cos(ang), math.sin(ang)
			local alpha = math.min(1, self.hintLeft / 12)
			a.clip.alpha = alpha
			FL.Draw(a.clip, { cs * 1.4, sn * 1.4, -sn * 1.4, cs * 1.4, ax + m.mcx + ux * r, ay + m.mcy - 40 + uy * r })
		end
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	if self.state == "PRESPOOLING" or not self.mons then return AN.L("g01_t_loading") end
	return AN.L("g01_status", self.curDifficulty + 1, math.floor(self.showScore or 0))
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.clock = 0
	self.score, self.showScore, self.scoreAccum = 0, 0, 0
	self.vars = {}
	self.lp = { itemsPickedUp = {}, nbItemsLeft = 0, nbRequiredItemsTotal = 0, damageSuffered = 0 }
	self.loopsnd, self.nearSounds = {}, {}
	self.skipMod = 0
	self.listX, self.listY = 0, 0
	self.fallers = {}
	self.endTimer = nil
	self.curtainOn = nil
	self.completeTest = 0
	self.activationCount = 0
	self.lastCamBlock = -999
	self.lastCamPos = { x = -9999, y = -9999 }
	self.gui = FL.New("g01gui", 0)
	self.level = FL.New("g01lv", 0)
	self:InitLevel()
	self:NewMonster()
	self:ResetForNewGame()
	self.pops = {}
	for i = 1, 10 do
		local c = FL.New("g01sg", "pop")
		self.pops[i] = { clip = c, x = -1000, y = 0 }
	end
	self.nextPop = 1
	self.curDifficulty = 0
	self.curLevelID = 0
	self.lp.nbItemsLeft = 0
	self:ScoreStatReset()
	self:CameraGoHome()
	-- prespooling with the curtain closed and the loading bar on it
	self.state = "PRESPOOLING"
	self.prespoolDone = false
	self:InitPrespool()
	if AN.Save.Get("hidden") ~= false then self:CutBubble() end
end

function G:Close()
	self:StopLoops()
	if CUR == self then CUR = nil end
end

function G:Think(dt)
	if not self.gui then return end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	self:StopLoops()
	AN.FinishGame(1, self.score or 0)
end

-- the buttons of the visible dialogs (their hit rectangles through their matrices)
local function findButtons(c, M, out)
	if not c or not c.visible then return end
	local L = AN.FLib[c.lib]
	local fr = c.def[4][c.frame]
	while type(fr) == "number" do fr = c.def[4][fr] end
	for _, it in ipairs(fr or {}) do
		local ch = L.chars[it[2]]
		if ch and not it.cd then
			local m = TL.Mul(M, { it[4], it[5], it[6], it[7], it[8], it[9] })
			if ch[1] == "btn" then
				local r = ch[3]
				local xs, ys = {}, {}
				for _, p in ipairs({ { r[1], r[2] }, { r[3], r[2] }, { r[1], r[4] }, { r[3], r[4] } }) do
					local x, y = TL.Apply(m, p[1], p[2])
					xs[#xs + 1], ys[#ys + 1] = x, y
				end
				out[#out + 1] = { cid = it[2], x0 = math.min(unpack(xs)), y0 = math.min(unpack(ys)), x1 = math.max(unpack(xs)), y1 = math.max(unpack(ys)) }
			elseif ch[1] == "spr" then
				findButtons(c.kids[it[3]], m, out)
			end
		end
	end
end

-- the dialogs' text fields: the game's values, and the loader's texts in the player's language
local LEVEL0 = { text_life = "g01_v_life", text_time = "g01_v_time", text_score = "g01_v_score", text_welldone = "g01_v_welldone",
	text_completed = "g01_v_completed", text_totalscore = "g01_v_total", text_gameover = "g01_t_over" }

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.gui then MG.Chrome(1) return end
	local game = self
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if LEVEL0[name] then return AN.L(LEVEL0[name]) end
		local v = game.vars[name]
		if v ~= nil then return v end
		return nil
	end

	-- the level and everything in it, through the camera
	local ax, ay = -self.camX + self.camOffX, -self.camY + self.camOffY
	local LM = { 1, 0, 0, 1, ax, ay }
	FL.Draw(self.level, LM)
	local m = self.mons
	FL.Draw(m.clip, { 1, 0, 0, 1, ax + m.mcx, ay + m.mcy })
	for _, f in ipairs(self.fallers) do
		if not f.recordPath then FL.Draw(f.clip, { 1, 0, 0, 1, ax + f.mcx, ay + f.mcy }) end
	end
	for _, it in ipairs(self.items) do FL.Draw(it.clip, { 1, 0, 0, 1, ax + it.mcx, ay + it.mcy }) end
	for _, p in ipairs(self.pops) do
		if p.clip.frame > 1 then FL.Draw(p.clip, { 1, 0, 0, 1, ax + p.x, ay + p.y }) end
	end
	self:HintDraw(ax, ay)

	-- the dialogs, score panel and curtain
	FL.Draw(self.gui, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil

	-- the dialogs' buttons
	local btns = {}
	findButtons(self.gui, { 1, 0, 0, 1, 0, 0 }, btns)
	for i, b in ipairs(btns) do
		local fn
		if b.cid == 101 then
			fn = function() self:ContinueClick() end
		elseif b.cid ~= 44 and b.cid ~= 49 and b.cid ~= 61 then
			-- OK on the end boards (quitGame: the loader goes on straight away)
			fn = function() self:Finish() end
		end
		if fn then
			UI.Button("g01_btn" .. i, MG.X(b.x0), MG.Y(b.y0), MG.S(b.x1 - b.x0), MG.S(b.y1 - b.y0), fn)
		end
	end

	MG.Chrome(1)
end

-- (Duel split screen: two copies of the game run side by side; the clips' frame scripts
-- talk to the copy that is running right now)
function G:MakeCurrent() CUR = self end

AN.RegisterGame(1, G)
