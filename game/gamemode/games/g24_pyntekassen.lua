-- Låge 24: Pyntekassen
-- Rebuilt from the original loader.swf (in the CD's "spil 01" folder - the calendar's list has the
-- folders of door 1 and door 24 swapped). A match-3 game: click two neighbouring Christmas
-- ornaments to swap them; three or more of a kind in a row disappear and new ones fall in. A swap
-- that makes no row is swapped back. Each level needs a number of good moves (20 + 2 per level);
-- the bar at the bottom is the time you have for your next good move - if it runs out, the game
-- is over. Longer rows, several rows at once and chain reactions give bonus points, and from level
-- 2 and 5 there are more kinds of ornament.
-- The game code is the original's ("SugarRush"), quirks included:
--   * the time bar only resets on a good move, so bad swaps eat your time
--   * the score counts up 6 points a frame towards the real score
--   * the swap sound is played on "_level.efx", which doesn't exist, so it is never heard
--   * the 35 point numbers flash "000" in the top left corner when a level starts
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g24_fl.lua")
FL.ImgSwap["g24/fl/s297.png"] = { en = "g24/fl/s297_en.png" }   -- "Næste Level ...fortsæt" is part of the picture
-- the bonus banners' words are pictures too: "På en række" (a black outline and a picture per
-- letter: in English the whole "In a row" is in the outline's picture) and "Række" in "MULTI Række"
FL.ImgSwap["g24/fl/s357.png"] = { en = "g24/fl/s357_en.png" }
for i = 358, 365 do FL.ImgSwap["g24/fl/t" .. i .. ".png"] = { en = "g24/fl/blank_en.png" } end
FL.ImgSwap["g24/fl/s378.png"] = { en = "g24/fl/s378_en.png" }
FL.ImgSwap["g24/fl/t379.png"] = { en = "g24/fl/t379_en.png" }

local G = {
	scoreType = "score",
	goal = 9000,      -- the original coolScore
	worst = 0,
	descKey = "desc_24",
	howKey = "how_24",
}

local STAGE_W, STAGE_H = 495, 398
local STEP = 1 / 25
local LIB = "g24"
local I = { 1, 0, 0, 1, 0, 0 }
local TILE_CID = { [0] = 215, 212, 209, 206, 203, 200, 197 }

-- onClipEvent(load) { _visible = false }: the preloader
FL.LoadHidden[LIB] = { [256] = true }

local CUR

local function stop(c) FL.Stop(c) end

local function setupActions()
	FL.SetActions(LIB, 0, {
		[4] = function(c) FL.GotoAndStop(c, "initgame") end,    -- the preloader: everything is loaded
		[10] = stop,
		[20] = function(c) if CUR then CUR:InitGame() end FL.Play(c) end,
		[21] = function() local ld = CUR and CUR:Clip("leveldone") if ld and ld.vars.ison then FL.GotoAndPlay(ld, "animoff") end end,
		[28] = function(c)
			stop(c)
			local g = CUR and CUR:Game()
			if g then g.visible = true end
			c.vars.scoreTxt = "0"
		end,
		[36] = function() AN.Speak("gameovertidenloebud") end,
		[110] = function(c) stop(c) if CUR then CUR:Finish() end end,
	})
	-- the quality window: its button is hidden (showButton = false); the plank at the bottom opens it
	FL.SetActions(LIB, 251, {
		[1] = function(c)
			stop(c)
			for _, it in ipairs(FL.Items(c)) do
				if it[2] == 233 and c.kids[it[3]] then c.kids[it[3]].visible = false end
			end
		end,
		[2] = function(c)
			stop(c)
			-- the radio buttons: r1 = LOW, r2 = MEDIUM, r3 = HIGH; their dots start hidden, and the
			-- current quality's one is only marked active (so its dot never shows)
			local names = { [9] = "LOW", [14] = "MEDIUM", [19] = "HIGH" }
			for _, it in ipairs(FL.Items(c)) do
				local k = c.kids[it[3]]
				if k and names[it[1]] then
					k.quality = names[it[1]]
					k.vars.isActive = CUR and CUR.quality == k.quality or false
					local dot = FL.Child(k, "dot")
					if dot then dot.visible = false end
				end
			end
		end,
	})
	FL.SetActions(LIB, 246, { [1] = stop })
	FL.SetActions(LIB, 294, { [1] = function(c) stop(c) c.visible = false end })
	FL.SetActions(LIB, 303, {   -- "Level slut!"
		[1] = function(c) c.vars.ison = false stop(c) end,
		[2] = function(c) c.vars.ison = true end,
		[9] = function(c) stop(c) AN.Speak("HuskeSpillet_LevelSlut") end,
		[10] = function(c) c.vars.ison = false end,
		[17] = function() if CUR then FL.GotoAndStop(CUR.root, "initgame") end end,
	})
	FL.SetActions(LIB, 309, {   -- out of time
		[1] = stop,
		[30] = function() if CUR then FL.GotoAndPlay(CUR.root, "gameover") end end,
	})
	FL.SetActions(LIB, 315, {   -- pause
		[1] = function(c) stop(c) c.vars.ison = false end,
		[2] = function(c)
			c.vars.saveState = CUR and CUR.gameState
			if CUR then CUR.gameState = "paused" end
			c.vars.ison = true
		end,
		[9] = function(c) c.vars.isOnAndDone = true stop(c) end,
		[10] = function(c) c.vars.isPlaying = true c.vars.ison = false end,
		[17] = function(c)
			c.vars.isPlaying = false
			if CUR and c.vars.saveState and c.vars.saveState ~= "" then CUR.gameState = c.vars.saveState end
		end,
	})
	FL.SetActions(LIB, 372, { [1] = stop, [21] = function(c) c.vars.current = 0 end })
	FL.SetActions(LIB, 153, { [25] = function(c) c.visible = false FL.GotoAndStop(c, 1) end })
	for _, cid in ipairs({ 123, 261, 340, 355, 381 }) do FL.SetActions(LIB, cid, { [1] = stop }) end
	FL.SetActions(LIB, 321, { [1] = stop, [2] = stop })
	FL.SetActions(LIB, 282, { [2] = stop })
	local efx = {}
	for _, f in ipairs({ 1, 8, 15, 24, 37, 51, 64, 77, 91, 104, 117, 133 }) do efx[f] = stop end
	FL.SetActions(LIB, 273, efx)
	-- the ornaments: def / glow / selected / active (it grows a little) / animoff
	for _, cid in pairs(TILE_CID) do
		FL.SetActions(LIB, cid, {
			[1] = function(c) stop(c) c.gfxMode = "back" end,
			[10] = function(c) c.gfxMode = "grow" c.gfxCount = 0 end,
			[25] = function(c) c.visible = false stop(c) end,
			[27] = stop,
		})
	end
end

---------------------------------------------------------------------------
-- hint: two ornaments that make a row when swapped wiggle (ringed, with arrows) until you move
---------------------------------------------------------------------------
function G:FindMove()
	local F = self.field
	if not F then return nil end
	local function t(x, y) return F[x] and F[x][y] and F[x][y].typ end
	local function run(x, y, a, b)
		local c = t(x, y)
		local n, i = 1, 1
		while t(x + a * i, y + b * i) == c do n, i = n + 1, i + 1 end
		i = 1
		while t(x - a * i, y - b * i) == c do n, i = n + 1, i + 1 end
		return n
	end
	local found = {}
	for x = 0, self.xSize - 1 do
		for y = 0, self.ySize - 1 do
			for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
				local x2, y2 = x + d[1], y + d[2]
				if F[x2] and F[x2][y2] and F[x][y] then
					F[x][y].typ, F[x2][y2].typ = F[x2][y2].typ, F[x][y].typ
					local ok = run(x, y, 1, 0) >= 3 or run(x, y, 0, 1) >= 3 or run(x2, y2, 1, 0) >= 3 or run(x2, y2, 0, 1) >= 3
					F[x][y].typ, F[x2][y2].typ = F[x2][y2].typ, F[x][y].typ
					if ok then found[#found + 1] = { x, y, x2, y2 } end
				end
			end
		end
	end
	return #found > 0 and found[math.random(#found)] or nil
end
function G:CanHint() return self.gameState == "waitInput" and not self.hintMove and self:FindMove() ~= nil end
function G:Hint(cost)
	local mv = self:FindMove()
	if not mv then return false end
	self.hintMove = mv
	local v = self.vars
	v.targetScore = math.max(0, v.targetScore - cost)
	v.score = math.min(v.score, v.targetScore)
	v.scoreTxt = v.score
	MG.Pop("-" .. cost, false, 120, 40)
end
function G:HintDraw()
	local mv = self.hintMove
	if not mv then return end
	if self.gameState ~= "waitInput" then self.hintMove = nil return end
	local gm = FL.ChildMatrix(self.root, "game", { 1, 0, 0, 1, 0, 0 })
	if not gm then return end
	local sx, sy = self:StartRef()
	local ts = self.tileSize
	local wig = math.sin(RealTime() * 18) * 2.5
	local ax, ay = TL.Apply(gm, sx + mv[1] * ts, sy + mv[2] * ts)
	local bx, by = TL.Apply(gm, sx + mv[3] * ts, sy + mv[4] * ts)
	local dx, dy = (bx - ax) / ts, (by - ay) / ts
	MG.HintRing(ax + dy * wig, ay + dx * wig, ts * 0.55, MG.HINT_GOLD, 1, 3)
	MG.HintRing(bx - dy * wig, by - dx * wig, ts * 0.55, MG.HINT_GOLD, 1, 3)
	local mx, my = (ax + bx) / 2, (ay + by) / 2
	MG.HintArrow(mx - dx * 4, my - dy * 4, mx + dx * 12, my + dy * 12, MG.HINT_GOLD, 1, 4)
	MG.HintArrow(mx + dx * 4, my + dy * 4, mx - dx * 12, my - dy * 12, MG.HINT_GOLD, 1, 4)
end

function G:Clip(name) return FL.Child(self.root, name) end
function G:Game() return self:Clip("game") end

function G:PlayEfx(lbl)
	local e = self:Clip("efx")
	if not e then return end
	FL.GotoAndPlay(e, lbl)
	local fx = FL.Child(e, "fxmc")
	if fx then FL.GotoAndPlay(fx, 2) end
end

function G:Status()
	return AN.L("g24_status", self.vars.targetScore or 0, self.vars.level or 1)
end

local function rnd(n) return math.floor(math.random() * n) end

---------------------------------------------------------------------------
-- the original game code (the "game" clip)
---------------------------------------------------------------------------
function G:InitGame()
	local v = self.vars
	self.mainState = "rungame"
	self:InitPoints()
	self.xSize, self.ySize, self.tileSize = 8, 8, 34
	self.hiliteDelay = 10
	self.moveCount = 0
	self.moveFramCount = 0
	self.fallGeneration = 0
	local lev1 = math.min(8, v.level / 2)
	local lev2 = math.max(0, v.level / 2 - 8)
	self.numFramesPrMove = math.max(50, 500 - lev1 * 50 - lev2 / 3 * 10)
	if v.level < 2 then self.nbTypes = 5 elseif v.level < 5 then self.nbTypes = 6 else self.nbTypes = 7 end
	self.numMovesPrLevel = math.Round(20 + v.level * 2)
	self.gameState = "makeLevel"
	self.selected = {}
	local g = self:Game()
	if g then FL.GotoAndStop(g, "on") end
	self.endIt = false
	self.field = {}
	self.tiles = {}
	self.nTiles = 0
end

function G:StartRef()
	for _, it in ipairs(FL.Items(self:Game())) do
		if it.nm == "startRef" then return it[8], it[9] end
	end
	return 36.2, 119.8
end

function G:InitPoints()
	self.points = {}
	for t = 1, 35 do
		local p = FL.New(LIB, 153)
		p.x, p.y = 0, 0
		self.points[t] = p
	end
	self.nextPoint = 1
end

function G:SetPoint(val, x, y)
	local p = self.points[self.nextPoint]
	p.x, p.y = x, y
	p.visible = true
	local ani = FL.Child(p, "ani")
	if ani then ani.vars.txt = val end
	FL.Play(p)
	self.nextPoint = self.nextPoint % 35 + 1
end

function G:UpdateGui()
	local v = self.vars
	v.levelTxt = v.level
	v.movesTxt = math.max(0, self.numMovesPrLevel - self.moveCount)
	if v.score < v.targetScore then
		v.score = v.score + 6
		self:PlayEfx("scorecount")
		if v.score > v.targetScore then v.score = v.targetScore end
	end
	v.scoreTxt = v.score
	local g = self:Game()
	local bar = g and FL.Child(g, "bar")
	if bar then
		for _, it in ipairs(FL.Items(g)) do
			if it.nm == "bar" then bar.mat = { self.moveFramCount / self.numFramesPrMove * it[4], it[5], it[6], it[7], it[8], it[9] } end
		end
	end
end

function G:Cell(x, y) return self.field[x] and self.field[x][y] end

function G:AttachTypeMC(tile, id, pos)
	local old = tile.mc
	local c = FL.New(LIB, TILE_CID[tile.typ])
	c.x, c.y = old and old.x or nil, old and old.y or nil
	c.velY = 0
	c.pos = { x = pos.x, y = pos.y }
	c.id = id
	c.gfxScale = 100
	tile.mc = c
end

function G:BuildNewLevel()
	local sx, sy = self:StartRef()
	self.field = {}
	self.tiles = {}
	self.buttons = {}
	local n = 0
	for x = 0, self.xSize - 1 do
		self.field[x] = {}
		for y = 0, self.ySize - 1 do
			n = n + 1
			local t = rnd(self.nbTypes)
			-- (the cell's button: its own id tracks which ornament is in the cell)
			local b = { id = n, pos = { x = x, y = y }, x = sx + x * self.tileSize, y = sy + y * self.tileSize }
			self.buttons[n] = b
			self.field[x][y] = { typ = t, newTyp = t, xFlag = false, yFlag = false, mc = b }
		end
	end
	for t = 1, 25 do
		if self:CheckForMatch(0) then
			for x = 0, self.xSize - 1 do
				for y = 0, self.ySize - 1 do
					local f = self.field[x][y]
					if f.xFlag or f.yFlag then
						local tp = rnd(self.nbTypes)
						f.typ, f.newTyp = tp, tp
					end
				end
			end
		else
			break
		end
	end
	n = 0
	for x = 0, self.xSize - 1 do
		for y = 0, self.ySize - 1 do
			n = n + 1
			local tile = { targPos = { x = x, y = y }, typ = self.field[x][y].typ, moveState = 0 }
			self.tiles[n] = tile
			self:AttachTypeMC(tile, n, { x = x, y = y })
			tile.targetX = sx + x * self.tileSize
			tile.targetY = sy + y * self.tileSize
			tile.mc.x = tile.targetX
			tile.mc.y = 450
		end
	end
	self.nTiles = n
end

function G:ResetFlags()
	for x = 0, self.xSize - 1 do
		for y = 0, self.ySize - 1 do
			local f = self.field[x] and self.field[x][y]
			if f then f.xFlag, f.yFlag = false, false end
		end
	end
end

function G:AddMove()
	if self.gameState == "makeLevel" or self.fallGeneration > 1 then return end
	if not self.moveCountLocked then
		self.moveCount = self.moveCount + 1
		self.moveCountLocked = true
	end
	if self.moveCount >= self.numMovesPrLevel then self.endIt = true end
end

function G:CheckInARowBonus(val)
	if val <= 3 then return end
	local b = self:Clip("inarowBonus")
	if not b then return end
	if (b.vars.current or 0) < val then
		b.vars.current = val
		FL.GotoAndPlay(b, "on")
		b.vars.txt = val
	end
end

function G:CheckForMatch(pointVal)
	local found = false
	local rows = 0
	self:ResetFlags()
	self.matches = {}
	self.moveCountLocked = false
	local F = self.field
	for x = 0, self.xSize - 1 do
		for y = 0, self.ySize - 1 do
			local org = F[x][y].newTyp
			if x < self.xSize - 2 and not F[x][y].xFlag then
				local same = 1
				for k = x + 1, self.xSize - 1 do
					if F[k][y].newTyp == org then same = same + 1 else break end
				end
				if same > 2 then
					found = true
					rows = rows + 1
					self:AddMove()
					self:CheckInARowBonus(same)
					pointVal = 10 * self.fallGeneration * (same - 2) * rows
					for k = x, x + same - 1 do
						F[k][y].xFlag = true
						table.insert(self.matches, { x = k, y = y, points = pointVal, id = F[k][y].mc.id })
					end
				end
			end
			if y < self.ySize - 2 and not F[x][y].yFlag then
				local same = 1
				for k = y + 1, self.ySize - 1 do
					if F[x][k].newTyp == org then same = same + 1 else break end
				end
				if same > 2 then
					found = true
					rows = rows + 1
					self:AddMove()
					self:CheckInARowBonus(same)
					pointVal = 10 * self.fallGeneration * (same - 2) * rows
					for k = y, y + same - 1 do
						F[x][k].yFlag = true
						table.insert(self.matches, { x = x, y = k, points = pointVal, id = F[x][k].mc.id })
					end
				end
			end
		end
	end
	if rows > 1 then
		local b = self:Clip("multiRowBonus")
		if b then FL.GotoAndPlay(b, "on") b.vars.txt = "MULTI" end
	end
	return found
end

function G:GiveMatchPoints()
	local sx, sy = self:StartRef()
	for _, m in ipairs(self.matches) do
		self:SetPoint(m.points, sx + m.x * self.tileSize, sy + m.y * self.tileSize)
		local t = self.tiles[m.id]
		if t then FL.GotoAndStop(t.mc, "glow") end
		self.moveAccumPoints = self.moveAccumPoints + m.points
	end
end

function G:AnimTiles(kind)
	local sx, sy = self:StartRef()
	local any = false
	for i = 1, self.nTiles do
		local t = self.tiles[i]
		if t.moveState == 1 then
			any = true
			local c = t.mc
			local tx, ty = sx + c.pos.x * self.tileSize, sy + c.pos.y * self.tileSize
			if kind == "gravity" then
				c.velY = (c.velY or 0) + 2.7 + (math.random() - 0.5) * 1.4
				c.y = c.y + c.velY
				if c.y > ty then
					if self.playLand then
						self.playLand = false
						self:PlayEfx("land")
					end
					c.y = ty
					c.velY = c.velY * -0.5
				end
				local d = math.abs(c.x - tx) + math.abs(c.y - ty)
				if d < 2 and math.abs(c.velY) < 4.5 then
					c.x, c.y = tx, ty
					t.moveState = 0
					c.velY = 0
				end
			else
				c.x = c.x + (tx - c.x) / 3
				c.y = c.y + (ty - c.y) / 3
				if math.abs(c.x - tx) + math.abs(c.y - ty) < 2 then
					c.x, c.y = tx, ty
					t.moveState = 0
				end
			end
		end
	end
	return any
end

function G:LevelAnimTiles()
	self:PlayEfx("swoosh")
	local moving = 0
	local busy = false
	for i = 1, self.nTiles do
		local t = self.tiles[i]
		if t.moveState == 10 then
			moving = moving + 1
			busy = true
			local c = t.mc
			c.x = c.x + (t.targetX - c.x) / 2
			c.y = c.y + (t.targetY - c.y) / 2
			if math.abs(c.x - t.targetX) + math.abs(c.y - t.targetY) < 5 then
				c.x, c.y = t.targetX, t.targetY
				t.moveState = 0
			end
		end
	end
	-- (tiles.length is 65: index 0 is empty)
	local len = self.nTiles + 1
	if moving == 0 then
		if self.nextTile <= len then
			busy = true
			if self.tiles[self.nextTile] then self.tiles[self.nextTile].moveState = 10 end
			self.nextTile = self.nextTile + 1
		end
	elseif moving < 10 then
		busy = true
		if self.nextTile <= len then
			if self.tiles[self.nextTile] then self.tiles[self.nextTile].moveState = 10 end
			self.nextTile = self.nextTile + 1
		end
	else
		busy = true
	end
	return busy
end

function G:Loop()
	self:UpdateGui()
	local st = self.gameState
	local F = self.field
	if st == "makeLevel" then
		self:BuildNewLevel()
		self.gameState = "makeLevelAnim"
		self.nextTile = 0
	elseif st == "makeLevelAnim" then
		if not self:LevelAnimTiles() then
			self.gameState = "resetInput"
			self.vars.scoreTxt = "0"
		end
	elseif st == "clearLevel" then
		self.counter = self.counter + 1
		local c = self.counter
		if self.tiles[c] then FL.GotoAndPlay(self.tiles[c].mc, "animOff") end
		self:PlayEfx("click2")
		if self.tiles[c + 8] then FL.GotoAndStop(self.tiles[c + 8].mc, "def") end
		if self.tiles[c + 12] then FL.GotoAndStop(self.tiles[c + 12].mc, "glow") end
		if c > self.nTiles + 1 then self.gameState = "changeLevelInit" end
	elseif st == "changeLevelInit" then
		-- the level is done: into its own highscore list, and the run's score so far is saved
		local total = self.vars.targetScore or 0
		AN.LevelScore(24, self.vars.level, total - (self.levelStartScore or 0), { total = total })
		self.levelStartScore = total
		self.vars.level = self.vars.level + 1
		local ld = self:Clip("leveldone")
		if ld then FL.GotoAndPlay(ld, "animon") end
		local g = self:Game()
		if g then g.visible = false end
		self.gameState = "wait"
	elseif st == "resetInput" then
		for i = 1, 2 do
			local s = self.selected[i]
			if s and self.tiles[s.id] then FL.GotoAndStop(self.tiles[s.id].mc, "def") end
		end
		self.selected = {}
		self:ResetFlags()
		self.gameState = "waitInput"
		self.counter = 0
		if self.endIt then self.gameState = "clearLevel" end
	elseif st == "waitInput" then
		self.moveFramCount = self.moveFramCount + 1
		if self.moveFramCount > self.numFramesPrMove then
			self.gameState = "timeRanOut"
			self.counter = 0
		end
	elseif st == "checkMove" then
		local a, b = self.selected[1].pos, self.selected[2].pos
		local f1, f2 = F[a.x][a.y], F[b.x][b.y]
		f1.newTyp = f2.typ
		f2.newTyp = f1.typ
		f1.mc.id, f2.mc.id = f2.mc.id, f1.mc.id
		self.fallGeneration = 1
		self.moveAccumPoints = 0
		if self:CheckForMatch(50) then
			self.fallGeneration = self.fallGeneration + 1
			f1.typ, f2.typ = f1.newTyp, f2.newTyp
			for _, p in ipairs({ { f1, a }, { f2, b } }) do
				local t = self.tiles[p[1].mc.id]
				t.moveState = 1
				t.mc.pos.x, t.mc.pos.y = p[2].x, p[2].y
			end
			self.moveFramCount = 0
			self.gameState = "moveAnim"
			self:PlayEfx("goodmove")
		else
			self.gameState = "resetInput"
			f1.newTyp, f2.newTyp = f1.typ, f2.typ
			f1.mc.id, f2.mc.id = f2.mc.id, f1.mc.id
			self:PlayEfx("badmove")
		end
	elseif st == "moveAnim" then
		self.counter = self.counter + 1
		-- (counter 1: _level.efx.playEfx("swap") - no such clip)
		if not self:AnimTiles() then
			local s = self.selected[1]
			if s and self.tiles[s.id] then FL.GotoAndStop(self.tiles[s.id].mc, "def") end
			self.gameState = "fillHilite"
			self.counter = 0
		end
	elseif st == "removeMatches" then
		self.counter = self.counter + 1
		for x = 0, self.xSize - 1 do
			for y = 0, self.ySize - 1 do
				local f = F[x][y]
				local id = f.mc.id
				if f.xFlag or f.yFlag then
					if self.counter == 1 then
						FL.GotoAndPlay(self.tiles[id].mc, "animoff")
					elseif self.counter == 10 then
						f.xFlag, f.yFlag = true, false
						local t = self.tiles[id]
						t.typ = rnd(self.nbTypes)
						self:AttachTypeMC(t, id, { x = x, y = y })
						t.mc.visible = false
					end
				end
			end
		end
		if self.counter == 10 then
			self.counter = 0
			self.gameState = "fillIn"
		end
	elseif st == "fillIn" then
		self:PlayEfx("fill")
		local sx, sy = self:StartRef()
		for x = 0, self.xSize - 1 do
			local removed, drop = {}, {}
			local lowest = -1
			for y = self.ySize - 1, 0, -1 do
				if F[x][y].xFlag and lowest == -1 then lowest = y end
				if lowest >= 0 then
					local id = F[x][y].mc.id
					if F[x][y].xFlag then
						table.insert(removed, id)
						self.tiles[id].mc.y = sy - #removed * self.tileSize
						self.tiles[id].mc.visible = true
					else
						table.insert(drop, id)
					end
				end
			end
			for _, id in ipairs(removed) do table.insert(drop, id) end
			for y = lowest, 0, -1 do
				local id = table.remove(drop, 1)
				F[x][y].mc.id = id
				F[x][y].typ = self.tiles[id].typ
				F[x][y].newTyp = self.tiles[id].typ
				self.tiles[id].mc.pos.x, self.tiles[id].mc.pos.y = x, y
				self.tiles[id].moveState = 1
			end
		end
		self.gameState = "fillAnim"
		self.playLand = true
		self.counter = 0
	elseif st == "fillAnim" then
		if not self:AnimTiles("gravity") then
			if self:CheckForMatch(50) then
				local rb = self:Clip("rushBonus")
				if rb then
					FL.GotoAndPlay(rb, "on")
					local fg = self.fallGeneration
					if fg == 2 then rb.vars.txt = "DOBBELT" elseif fg == 3 then rb.vars.txt = "TRIPLE" elseif fg > 3 then rb.vars.txt = "MEGA" end
				end
				self.fallGeneration = self.fallGeneration + 1
				self.gameState = "fillHilite"
				self.counter = 0
			else
				local tm = self:Clip("thisMoveTotal")
				if tm then tm.vars.txt = self.moveAccumPoints FL.GotoAndPlay(tm, "on") end
				self.vars.targetScore = self.vars.targetScore + self.moveAccumPoints
				local p = self.moveAccumPoints
				if not AN.IsSpeaking() then
					if p >= 500 then AN.Speak("megetGodt")
					elseif p > 90 then AN.Speak("Godt")
					elseif p > 30 then AN.Speak("Pyntekasse_Bonus03") end
				end
				self.moveAccumPoints = 0
				self.gameState = "resetInput"
				self.counter = 0
			end
		end
	elseif st == "fillHilite" then
		self.counter = self.counter + 1
		if self.counter == 1 then
			self:GiveMatchPoints()
			self:PlayEfx("remove")
		elseif self.counter > self.hiliteDelay then
			self.gameState = "removeMatches"
			self.counter = 0
		end
	elseif st == "timeRanOut" then
		local tr = self:Clip("timeRanOut")
		if tr then FL.GotoAndPlay(tr, "animon") end
		self.gameState = "gameDone"
	end
end

-- a cell's button: rollOver / rollOut / release
function G:TileMouseAction(kind, b)
	local id, pos = b.id, b.pos
	local t = self.tiles[id]
	if not t then return end
	local sel1 = self.selected[1]
	if kind == "over" then
		if (not sel1 or id ~= sel1.id) and self.gameState == "waitInput" then
			self:PlayEfx("click2")
			FL.GotoAndStop(t.mc, "active")
		end
	elseif kind == "out" then
		if (not sel1 or id ~= sel1.id) and self.gameState == "waitInput" then FL.GotoAndStop(t.mc, "def") end
	elseif kind == "release" and self.gameState == "waitInput" then
		local s = { id = id, pos = { x = pos.x, y = pos.y } }
		if #self.selected == 0 then
			self:PlayEfx("click1")
			table.insert(self.selected, s)
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local f = self:Cell(pos.x + d[1], pos.y + d[2])
				if f then f.xFlag = 1 end
			end
			FL.GotoAndStop(t.mc, "selected")
		elseif #self.selected == 1 then
			local f = self:Cell(pos.x, pos.y)
			if f and f.xFlag == 1 then
				self.gameState = "checkMove"
				table.insert(self.selected, s)
			else
				self:PlayEfx("badmove")
				self.gameState = "resetInput"
			end
		end
	end
end

-- the pause button
function G:PausePressed()
	local help, pg = self:Clip("help"), self:Clip("pausegfx")
	if not help then return end
	local hv = help.vars
	if not hv.ison and hv.isPlaying ~= true then
		if pg then FL.Play(pg) end
		FL.Play(help)
	elseif hv.isOnAndDone and hv.isPlaying ~= true then
		hv.isOnAndDone = false
		if pg then FL.Play(pg) end
		FL.Play(help)
	end
	self:PlayEfx("click2")
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.vars = { level = 1, score = 0, targetScore = 0, scoreTxt = 0 }
	self.levelStartScore = 0
	self.points = {}
	self.tiles = {}
	self.nTiles = 0
	self.buttons = {}
	self.selected = {}
	self.mainState = "none"
	self.gameState = nil
	self.hoverId = nil
	self.quality = "MEDIUM"    -- initQuality
	self.root = FL.New(LIB, 0)
	self.root.vars = self.vars
end

function G:Close()
	if CUR == self then CUR = nil end
end

local function tickGfx(c)
	if not c.gfxMode then return end
	if c.gfxMode == "back" then
		if math.abs(c.gfxScale - 100) < 1 then
			c.gfxScale = 100
			c.gfxMode = nil
		else
			c.gfxScale = c.gfxScale + (100 - c.gfxScale) / 2
		end
	else
		c.gfxCount = c.gfxCount + 1
		if c.gfxCount < 5 then c.gfxScale = c.gfxScale + (112 - c.gfxScale) / 2 else c.gfxScale = 112 end
	end
	for _, it in ipairs(FL.Items(c)) do
		if it.nm == "gfx" and c.kids[it[3]] then
			local s = c.gfxScale / 100
			c.kids[it[3]].mat = { s, 0, 0, s, it[8], it[9] }
		end
	end
end

function G:Step()
	FL.OnSound = function(c, id) MG.Sound("g24", "s" .. id) end
	FL.Tick(self.root)
	for i = 1, self.nTiles do
		local t = self.tiles[i]
		if t and t.mc then FL.Tick(t.mc) tickGfx(t.mc) end
	end
	for _, p in ipairs(self.points) do if p.visible then FL.Tick(p) end end
	-- the main clip's enterFrame
	if self.mainState == "rungame" and self:Game() then self:Loop() end
	FL.OnSound = nil
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
	AN.FinishGame(24, math.max(self.vars.score or 0, self.vars.targetScore or 0))
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(24) return end
	local game = self:Game()
	local gm = game and FL.ChildMatrix(self.root, "game", I)
	if game then
		local ex = {}
		for i = 1, self.nTiles do
			local t = self.tiles[i]
			if t and t.mc and t.mc.x then ex[#ex + 1] = { c = t.mc, m = { 1, 0, 0, 1, t.mc.x, t.mc.y } } end
		end
		for _, p in ipairs(self.points) do
			if p.visible then ex[#ex + 1] = { c = p, m = { 1, 0, 0, 1, p.x, p.y } } end
		end
		game.extra = ex
	end
	-- texts like "_parent.txt" / "txt" in the bonus clips: the nearest clip up the tree that has it
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		local cur = c.parent
		while cur do
			for k, v in pairs(cur.vars or {}) do if string.lower(k) == name then return v end end
			cur = cur.parent
		end
		return nil
	end
	FL.Draw(self.root, I)
	FL.VarHook = nil
	self:HintDraw()
	MG.DrawPops()
	-- the cells' buttons (later ones on top): hover and click
	local hover
	if game and game.visible and gm then
		local mx, my = MG.Mouse()
		local lx, ly = mx - gm[5], my - gm[6]
		for i = self.nTiles, 1, -1 do
			local b = self.buttons[i]
			-- the button's hit area: 40 x 40 around the cell's corner offset (-20, -20)
			if b and lx >= b.x - 20 and lx < b.x + 20 and ly >= b.y - 20 and ly < b.y + 20 then hover = b break end
		end
		if hover and self.gameState then
			UI.Button("g24_cell", MG.X(hover.x - 20 + gm[5]), MG.Y(hover.y - 20 + gm[6]), MG.S(40), MG.S(40), function()
				if CUR == self then self:TileMouseAction("release", hover) end
			end, { silent = true })
		end
	end
	if hover ~= self.hoverB then
		if self.hoverB then self:TileMouseAction("out", self.hoverB) end
		self.hoverB = hover
		if hover then self:TileMouseAction("over", hover) end
	end
	-- the root's buttons: pause (318), "Fortsæt" in the level screen (301), skip on game over (383)
	local f = self.root.frame
	for _, it in ipairs(FL.Items(self.root)) do
		local k = self.root.kids[it[3]]
		if k then
			local m = k.mat or { it[4], it[5], it[6], it[7], it[8], it[9] }
			if it[2] == 318 and f >= 28 and f < 36 then
				local x0, y0, x1, y1 = FL.Bounds(k, m, true)
				if x0 then UI.Button("g24_pause", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() self:PausePressed() end, { hit = FL.HitFn(k, m), silent = true }) end
			elseif it[2] == 303 and k.frame == 9 then
				local bk, bm = FL.CharItem(k, m, { [302] = true })
				local b2, m2
				if bk then b2, m2 = FL.CharItem(bk, bm, { [301] = true }) end
				if b2 then
					local x0, y0, x1, y1 = FL.Bounds(b2, m2, true)
					if x0 then UI.Button("g24_next", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
						FL.Play(k)
						self:PlayEfx("click2")
					end, { hit = FL.HitFn(b2, m2), silent = true }) end
				end
			end
		end
	end
	-- the quality window
	local qw, qm
	for _, it in ipairs(FL.Items(self.root)) do
		if it[2] == 251 then qw = self.root.kids[it[3]] qm = qw and (qw.mat or { it[4], it[5], it[6], it[7], it[8], it[9] }) end
		if it[2] == 252 and qw then
			local k = self.root.kids[it[3]]
			local m = k and (k.mat or { it[4], it[5], it[6], it[7], it[8], it[9] })
			local x0, y0, x1, y1
			if k then x0, y0, x1, y1 = FL.Bounds(k, m, true) end
			if x0 then UI.Button("g24_quality", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() FL.GotoAndStop(qw, 2) end, { hit = FL.HitFn(k, m) }) end
		end
	end
	if qw and qw.frame == 2 then
		for _, it in ipairs(FL.Items(qw)) do
			local k = qw.kids[it[3]]
			local m = k and TL.Mul(qm, k.mat or { it[4], it[5], it[6], it[7], it[8], it[9] })
			if k and k.quality then
				local x0, y0, x1, y1 = FL.Bounds(k, m, true)
				if x0 then UI.Button("g24_q" .. it[1], MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
					-- on(press) setQuality(...): the radio of that quality checks itself
					self.quality = k.quality
					for _, it2 in ipairs(FL.Items(qw)) do
						local r = qw.kids[it2[3]]
						if r and r.quality then
							if r.quality == k.quality then
								if not r.vars.isActive then
									r.vars.isActive = true
									local d = FL.Child(r, "dot") if d then d.visible = true end
									for _, it3 in ipairs(FL.Items(qw)) do
										local o = qw.kids[it3[3]]
										if o and o.quality and o ~= r then
											o.vars.isActive = false
											local d2 = FL.Child(o, "dot") if d2 then d2.visible = false end
										end
									end
								end
							end
						end
					end
				end) end
			elseif k and it[2] == 242 then
				local ck, cm = FL.CharItem(k, m, { [240] = true })
				if ck then
					local x0, y0, x1, y1 = FL.Bounds(ck, cm, true)
					if x0 then UI.Button("g24_qok", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function() FL.GotoAndStop(qw, 1) end, { hit = FL.HitFn(ck, cm) }) end
				end
			end
		end
	end
	if f >= 36 and f < 108 then
		UI.Button("g24_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(24)
end

AN.RegisterGame(24, G)
