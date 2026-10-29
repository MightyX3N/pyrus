-- Låge 11: Puslespil
-- Rebuilt from the original loader.swf and its four puzzle files. Pick one of four pictures (three
-- with 30 pieces, Tycho Brahe with 81), then put the jigsaw together: click a piece to pick it up,
-- click again to put it down, and turn the piece you hold with the space bar. Pieces that lie right
-- next to each other (within 20 pixels, turned the same way) click together and move as one.
-- The score is the time. The original game code is ported as it is, quirks and all:
--   * a group of 20 pieces or more never clicks onto anything when you drop it - bring the
--     smaller pieces to it instead
--   * the pause key (P) calls a timer that isn't there, so it does nothing (hidden content: on)
--   * the picture next to the menu never loaded (the thumbnails were not on the CD)
--     (hidden content: shown)
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
include(DIR .. "g11_fl.lua")
local PUZZLES = { "nisserne", "bertramsen", "pyrus", "brahe" }
for _, n in ipairs(PUZZLES) do include(DIR .. "g11_" .. n .. ".lua") end

local G = {
	scoreType = "time",
	goal = 90,        -- the original coolScore (90000 ms)
	worst = 360,      -- the original badScore (360000 ms)
	descKey = "desc_11",
	howKey = "how_11",
}

local STAGE_W, STAGE_H = 800, 600
local STEP = 1 / 24
local MS = 1000 / 24
local LIB = "g11"
local I = { 1, 0, 0, 1, 0, 0 }
local SIZES = { nisserne = 30, bertramsen = 30, pyrus = 30, brahe = 81 }
local SHADOW_COL = { 0, 0, 0, 71, 30, 10 }   -- MyColor.setRGB(4660746)

FL.LoadHidden[LIB] = { [103] = true, [171] = true }   -- the preloader and the pause screen

local CUR

local function hiddenOn() return AN.Save.Get("hidden") ~= false end

local function scoreToTime(ms)
	local min = math.floor(ms / 1000 / 60)
	local sek = math.floor(ms / 1000 - min * 60)
	local thous = math.floor(ms - min * 60000 - sek * 1000)
	return string.format("%02d:%02d:%03d", min, sek, thous)
end

local function rotM(ang, x, y)
	local a = math.rad(ang * 90)
	local c, s = math.Round(math.cos(a)), math.Round(math.sin(a))
	return { c, s, -s, c, x, y }
end

---------------------------------------------------------------------------
-- frame scripts of the loader
---------------------------------------------------------------------------
local function setupActions()
	FL.SetActions(LIB, 0, {
		[21] = function(c)
			FL.Stop(c)
			if CUR then CUR:SelectPuzzleImage(CUR.puzzleName, CUR.puzzleSize) end
		end,
		[28] = function(c) if CUR then CUR:TimStart() end end,   -- the timer clip's onClipEvent(load)
		[29] = function(c) if CUR then CUR:LoadPuzzle() end end,  -- (it loads at once here, so no stop)
		[30] = function(c) FL.Stop(c) if CUR then CUR:InitPuzzle() end end,
		[31] = function(c) if CUR then CUR.score = CUR.timeAcc end end,
		[44] = function(c)
			AN.Speak("GameOver")
			if CUR then CUR.scoreString = scoreToTime(CUR.score or 0) end
		end,
		[168] = function(c) FL.Stop(c) if CUR then CUR:Finish() end end,
	})
end

---------------------------------------------------------------------------
-- the loader: menu and timer
---------------------------------------------------------------------------
function G:SelectPuzzleImage(name, size)
	self.puzzleName = name
	self.puzzleSize = size
	self.vars.numpiecestxt = size .. AN.L("g11_t_inpuzzle")
end

function G:TimStart()
	self.timeAcc = 0
	self.timState = "ON"
	self:TimUpdate()
end

function G:TimUpdate()
	local acc = self.timeAcc or 0
	local min = math.floor(acc / 1000 / 60)
	local sek = math.floor(acc / 1000 - min * 60)
	self.vars.min = string.format("%02d", min)
	self.vars.sek = string.format("%02d", sek)
end

function G:TimStop()
	self:TimUpdate()
	self.timState = "OFF"
end

-- hidden content: the pause the game was meant to have (P, click the screen to go on)
function G:TogglePause()
	local ps = FL.Child(self.root, "pauseScreen")
	if self.timState == "ON" then
		self:TimUpdate()
		self.timState = "PAUSED"
		if ps then ps.visible = true end
	elseif self.timState == "PAUSED" then
		self.timState = "ON"
		if ps then ps.visible = false end
	end
end

---------------------------------------------------------------------------
-- the puzzle (the movie loaded into "main"): the original game code
---------------------------------------------------------------------------
function G:LoadPuzzle()
	local main = FL.Child(self.root, "main")
	self.plib = "g11_" .. self.puzzleName
	self.pz = FL.New(self.plib, 0)
	FL.GotoAndStop(self.pz, 2)
	if main then
		main.drawFn = function(M, alpha, col) self:DrawPuzzle(M, alpha, col) end
	end
end

-- the puzzle's own mouse position (_xmouse inside main)
function G:PMouse()
	local mx, my = MG.Mouse()
	local m = FL.ChildMatrix(self.root, "main", I) or { 1, 0, 0, 1, 386.95, 319.85 }
	return mx - m[5], my - m[6]
end

function G:InitPuzzle()
	self.DRAGGING = false
	self.GAMEON = true
	self.nbGroups = 0
	self.Group = {}
	if self.puzzleName == "brahe" then
		self.Xnum, self.Ynum, self.prefix = 9, 9, "q"
	else
		self.Xnum, self.Ynum, self.prefix = 5, 6, "p"
	end
	local Xnum, Ynum = self.Xnum, self.Ynum
	local N = Xnum * Ynum
	self.N = N
	local pp = {}
	self.pp = pp
	self.depthOf = {}
	self.atDepth = {}
	for _, it in ipairs(FL.Items(self.pz)) do
		local n = it.nm and string.match(it.nm, "^" .. self.prefix .. "(%d+)$")
		if n then
			n = tonumber(n)
			pp[n] = { Xorg = it[8], Yorg = it[9], clip = self.pz.kids[it[3]] }
		end
	end
	for t = 1, N do
		local h = FL.Child(pp[t].clip, "hilite")
		if h then h.visible = false end
		pp[t].hilite = h
		self:SetDepth(t, 1000 - t)
	end
	-- the neighbours ("nabo")
	for xt = 1, Xnum do
		for yt = 1, Ynum do
			local id = xt + Xnum * (yt - 1)
			local nb = {}
			if xt > 1 then nb[#nb + 1] = id - 1 end
			if xt < Xnum then nb[#nb + 1] = id + 1 end
			if yt < Ynum then nb[#nb + 1] = id + Xnum end
			if yt > 1 then nb[#nb + 1] = id - Xnum end
			pp[id].nabo = nb
		end
	end
	for t = 1, N do
		pp[t].X = math.random() * 500 - 250
		pp[t].Y = math.random() * 500 - 250
		pp[t].Ang = math.floor(math.random() * 3.9)
	end
	-- initShadows
	self.SHADOWSON = true
	self.ShadXoff, self.ShadYoff, self.Shadowlift = 4, 4, 3
	for t = 1, N do
		pp[t].sx, pp[t].sy, pp[t].sAng = pp[t].X + 4, pp[t].Y + 4, pp[t].Ang
	end
	self.PlaceTime = -1000
	MG.Sound("g11", "shake")
end

-- swapDepths: the clip that had the depth gets this one's old depth
function G:SetDepth(t, d)
	self.depthOf[t] = d
	self.atDepth[d] = t
end
function G:SwapDepths(t, d)
	local old = self.depthOf[t]
	local other = self.atDepth[d]
	if other == t then return end
	if other then
		self.depthOf[other] = old
		self.atDepth[old] = other
	else
		self.atDepth[old] = nil
	end
	self.depthOf[t] = d
	self.atDepth[d] = t
end

function G:IsInGroup(id)
	local res = -1
	for g = 0, #self.Group do
		local grp = self.Group[g]
		if grp then
			for _, v in ipairs(grp.id) do if v == id then res = g end end
		end
	end
	return res
end

function G:IsInGroupNumber(id, g)
	local grp = self.Group[g]
	if not grp then return false end
	for _, v in ipairs(grp.id) do if v == id then return true end end
	return false
end

function G:AddGrouptoGroup(a, b)
	local A, B = self.Group[a], self.Group[b]
	for _, v in ipairs(B.id) do A.id[#A.id + 1] = v end
	for _, v in ipairs(B.id) do
		self.pp[v].X = self.pp[v].X + self.MVecX
		self.pp[v].Y = self.pp[v].Y + self.MVecY
	end
	B.id = {}
end

function G:CheckDrop()
	local pp, dID = self.pp, self.dID
	local me = pp[dID]
	for _, nb in ipairs(me.nabo) do
		local o = pp[nb]
		if o.Ang == me.Ang and not self:IsInGroupNumber(nb, self.DRAGGROUP) and not self.FOUNDONE then
			local OrgVecX, OrgVecY = o.Xorg - me.Xorg, o.Yorg - me.Yorg
			local VecX, VecY = o.X - me.X, o.Y - me.Y
			local MVecX, MVecY = 0, 0
			local Dx, Dy
			if me.Ang == 0 then
				Dx, Dy = OrgVecX - VecX, OrgVecY - VecY
				if math.sqrt(Dx * Dx + Dy * Dy) < 20 then MVecX, MVecY = -Dx, -Dy self.FOUNDONE = true end
			elseif me.Ang == 2 then
				VecX, VecY = -VecX, -VecY
				Dx, Dy = OrgVecX - VecX, OrgVecY - VecY
				if math.sqrt(Dx * Dx + Dy * Dy) < 20 then MVecX, MVecY = Dx, Dy self.FOUNDONE = true end
			elseif me.Ang == 1 then
				VecX, VecY = VecY, -VecX
				Dx, Dy = OrgVecX - VecX, OrgVecY - VecY
				if math.sqrt(Dx * Dx + Dy * Dy) < 20 then MVecX, MVecY = Dy, -Dx self.FOUNDONE = true end
			elseif me.Ang == 3 then
				VecX, VecY = -VecY, VecX
				Dx, Dy = OrgVecX - VecX, OrgVecY - VecY
				if math.sqrt(Dx * Dx + Dy * Dy) < 20 then MVecX, MVecY = -Dy, Dx self.FOUNDONE = true end
			end
			self.MVecX, self.MVecY = MVecX, MVecY
			if self.FOUNDONE then
				MG.Sound("g11", "placegood")
				if math.random() < 0.3 and not AN.IsSpeaking("Puslespil_Passer") then
					AN.Speak("Puslespil_Passer")
				end
				local GroupID = self:IsInGroup(nb)
				if GroupID >= 0 and self.Group[GroupID].done == false then
					if self.DRAGGROUP < 0 then
						local grp = self.Group[GroupID]
						grp.id[#grp.id + 1] = dID
						me.X, me.Y = me.X + MVecX, me.Y + MVecY
					else
						self:AddGrouptoGroup(GroupID, self.DRAGGROUP)
					end
					self.Group[GroupID].done = true
				elseif GroupID < 0 then
					if self.DRAGGROUP >= 0 then
						o.X, o.Y = o.X - MVecX, o.Y - MVecY
						local grp = self.Group[self.DRAGGROUP]
						grp.id[#grp.id + 1] = nb
					else
						me.X, me.Y = me.X + MVecX, me.Y + MVecY
						self.Group[self.nbGroups] = { id = { dID, nb } }
						self.nbGroups = self.nbGroups + 1
					end
				end
			end
		end
	end
	for g = 0, #self.Group do
		if self.Group[g] then self.Group[g].done = false end
	end
	self:ResetShadows()
end

function G:ResetShadows()
	if not self.SHADOWSON then return end
	local pp = self.pp
	if self.DRAGGROUP < 0 then
		local p = pp[self.dID]
		p.sx, p.sy = p.X + self.ShadXoff, p.Y + self.ShadYoff
	else
		for _, v in ipairs(self.Group[self.DRAGGROUP].id) do
			pp[v].sx, pp[v].sy = pp[v].X + self.ShadXoff, pp[v].Y + self.ShadYoff
		end
	end
end

-- name: the piece number that was pressed, or "" for a click anywhere (onClipEvent mouseDown)
function G:Mclicked(name)
	if not self.GAMEON then return end
	if self.DRAGGING and name == "" then
		self.DRAGGING = false
		self.FOUNDONE = false
		if self.DRAGGROUP < 0 then
			self:CheckDrop()
			MG.Sound("g11", "placebad")
		else
			local grp = self.Group[self.DRAGGROUP]
			if #grp.id < 20 then
				for t = 1, #grp.id do
					self.dID = grp.id[t]
					self:CheckDrop()
				end
			else
				self:ResetShadows()
			end
			MG.Sound("g11", "placebad")
		end
		self.PlaceTime = self.now
		for g = 0, #self.Group do
			local grp = self.Group[g]
			if grp and #grp.id == self.N then self:GameOver() end
		end
	elseif not self.DRAGGING and name ~= "" and self.now > self.PlaceTime + 200 then
		MG.Sound("g11", "lift")
		self.DRAGGING = true
		self.dID = name
		self.DRAGGROUP = self:IsInGroup(name)
		local mx, my = self:PMouse()
		self.X1, self.Y1 = mx, my
		self.PoffX, self.PoffY = self.pp[name].X - mx, self.pp[name].Y - my
		if self.DRAGGROUP < 0 then
			self:SwapDepths(name, 1000)
		else
			for t, v in ipairs(self.Group[self.DRAGGROUP].id) do self:SwapDepths(v, 1000 - (t - 1)) end
		end
	end
end

-- hint: one loose piece puts itself in place next to a neighbour (preferably one in the biggest
-- group), turned the same way, and joins it. +5 seconds on the clock.
function G:CanHint() return self.GAMEON and not self.DRAGGING and self.timState == "ON" and self.pp ~= nil end
local function placeBy(o, me, ang)
	local ox, oy = o.Xorg - me.Xorg, o.Yorg - me.Yorg
	if ang == 0 then return o.X - ox, o.Y - oy
	elseif ang == 1 then return o.X + oy, o.Y - ox
	elseif ang == 2 then return o.X + ox, o.Y + oy
	else return o.X - oy, o.Y + ox end
end
function G:Hint(cost)
	local pp = self.pp
	-- the biggest group, and its size per piece
	local size = {}
	for g = 0, #self.Group do
		local grp = self.Group[g]
		if grp then for _, v in ipairs(grp.id) do size[v] = #grp.id end end
	end
	local best, bestScore
	for t = 1, self.N do
		if self:IsInGroup(t) < 0 then
			for _, nb in ipairs(pp[t].nabo) do
				local sc = (size[nb] or 1) + math.random() * 0.5
				if not bestScore or sc > bestScore then best, bestScore = { t, nb }, sc end
			end
		end
	end
	if not best then return false end
	local me, o = pp[best[1]], pp[best[2]]
	me.Ang = o.Ang
	me.sAng = o.Ang
	me.X, me.Y = placeBy(o, me, o.Ang)
	self.dID = best[1]
	self.DRAGGROUP = -1
	self.FOUNDONE = false
	self:SwapDepths(best[1], 1000)
	self:CheckDrop()
	self.hintPiece, self.hintT = best[1], 1.2
	self.timeAcc = self.timeAcc + cost * 1000
	self:TimUpdate()
	for g = 0, #self.Group do
		local grp = self.Group[g]
		if grp and #grp.id == self.N then self:GameOver() end
	end
end

function G:GameOver()
	self:TimStop()
	self.GAMEON = false
	self.DRAGGING = false
	FL.Play(self.root)
end

function G:Rotate()
	MG.Sound("g11", "rotate")
	if not self.DRAGGING then return end
	local pp = self.pp
	local me = pp[self.dID]
	if self.DRAGGROUP >= 0 then
		for _, v in ipairs(self.Group[self.DRAGGROUP].id) do
			local p = pp[v]
			local xo, yo = p.X - me.X, p.Y - me.Y
			p.X, p.Y = me.X - yo, me.Y + xo
			p.Ang = (p.Ang + 1) % 4
			p.sAng = p.Ang
			p.sx, p.sy = p.X, p.Y
		end
	else
		me.Ang = (me.Ang + 1) % 4
		me.sAng = me.Ang
	end
end

function G:Dragupdate()
	if not self.DRAGGING then return end
	local pp = self.pp
	local mx, my = self:PMouse()
	local lift = self.Shadowlift
	if self.DRAGGROUP >= 0 then
		local xo, yo = mx - self.X1, my - self.Y1
		self.X1, self.Y1 = mx, my
		for _, v in ipairs(self.Group[self.DRAGGROUP].id) do
			local p = pp[v]
			p.X, p.Y = p.X + xo, p.Y + yo
			p.sx, p.sy = p.X + self.ShadXoff * lift, p.Y + self.ShadYoff * lift
		end
	else
		local p = pp[self.dID]
		p.X, p.Y = mx + self.PoffX, my + self.PoffY
		p.sx, p.sy = p.X + self.ShadXoff * lift, p.Y + self.ShadYoff * lift
	end
end

---------------------------------------------------------------------------
-- drawing and the mouse inside the puzzle
---------------------------------------------------------------------------
function G:Order()
	local list = {}
	for t = 1, self.N do list[#list + 1] = t end
	table.sort(list, function(a, b) return self.depthOf[a] < self.depthOf[b] end)
	return list
end

-- the button inside a piece (or any clip) and its matrix
function G:BtnOf(c, M)
	local L = AN.FLib[c.lib]
	for _, it in ipairs(FL.Items(c)) do
		local ch = L.chars[it[2]]
		if ch and ch[1] == "btn" then
			local kid = c.kids[it[3]]
			if kid then return kid, TL.Mul(M, kid.mat or { it[4], it[5], it[6], it[7], it[8], it[9] }) end
		end
	end
end

function G:PieceM(M, t)
	local p = self.pp[t]
	return TL.Mul(M, rotM(p.Ang, p.X, p.Y))
end

function G:ViewerM(M)
	local m, k = FL.ChildMatrix(self.pz, "imageviewer", M)
	return m, k
end

-- the topmost button under the mouse in the puzzle: "viewer", button clip, matrix / "piece", t
function G:TopButton(M, x, y)
	local vm, viewer = self:ViewerM(M)
	if viewer then
		local L = AN.FLib[viewer.lib]
		local items = FL.Items(viewer)
		for i = #items, 1, -1 do
			local it = items[i]
			local ch = L.chars[it[2]]
			local kid = viewer.kids[it[3]]
			if ch and ch[1] == "btn" and kid then
				local bm = TL.Mul(vm, { it[4], it[5], it[6], it[7], it[8], it[9] })
				if FL.HitPoint(kid, bm, x, y) then return "viewer", it[1] end
			end
		end
	end
	if not self.pp then return nil end
	local order = self:Order()
	for i = #order, 1, -1 do
		local t = order[i]
		local btn, bm = self:BtnOf(self.pp[t].clip, self:PieceM(M, t))
		if btn and FL.HitPoint(btn, bm, x, y) then return "piece", t end
	end
	return nil
end

function G:DrawPuzzle(M, alpha, col)
	if not self.pz or not self.pp then return end
	self.mainM = M
	local order = self:Order()
	-- the shadows (duplicates of the pieces, coloured brown)
	if self.SHADOWSON then
		for _, t in ipairs(order) do
			local p = self.pp[t]
			FL.Draw(p.clip, TL.Mul(M, rotM(p.sAng, p.sx, p.sy)), alpha, SHADOW_COL)
		end
	end
	for _, t in ipairs(order) do
		FL.Draw(self.pp[t].clip, self:PieceM(M, t), alpha, col)
	end
	-- imageviewer.swapDepths(5555): on top of the pieces
	local vm, viewer = self:ViewerM(M)
	if viewer then FL.Draw(viewer, vm, alpha, col) end
end

-- the rollOver / rollOut events of the buttons in the puzzle
function G:UpdateHover()
	if not self.pz or not self.pp or not self.mainM or not MG.x0 then return end
	local mx, my = MG.Mouse()
	local kind, a = self:TopButton(self.mainM, mx, my)
	local key = kind and (kind .. a) or nil
	if key == self.hoverKey then return end
	-- rollOut of the old one
	if self.hoverKind == "piece" then
		local h = self.pp[self.hoverA].hilite
		if h then h.visible = false end
	elseif self.hoverKind == "viewer" then
		self:ViewerButton(self.hoverA, false)
	end
	self.hoverKey, self.hoverKind, self.hoverA = key, kind, a
	-- rollOver of the new one
	if kind == "piece" then
		local h = self.pp[a].hilite
		if h then h.visible = true end
	elseif kind == "viewer" then
		self:ViewerButton(a, true)
	end
end

-- the picture in the corner: rolling over it slides it out, rolling off it slides it back
-- depth: the button's depth in the viewer clip. The small button on the peeking picture (depth 12)
-- has on(rollOver) { play(); }; the four big ones around the shown picture have
-- on(rollOver, rollOut, dragOut, dragOver) { gotoAndStop("off"); play(); }
function G:ViewerButton(depth, over)
	local viewer = FL.Child(self.pz, "imageviewer")
	if not viewer then return end
	if depth == 12 then
		if over then FL.Play(viewer) end
	elseif viewer.frame >= 15 and viewer.frame <= 18 then
		FL.GotoAndStop(viewer, "off")
		FL.Play(viewer)
	end
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
function G:Status()
	local min, sek = self.vars and self.vars.min or "00", self.vars and self.vars.sek or "00"
	return AN.L("g11_status", min .. ":" .. sek)
end

function G:Open(args)
	setupActions()
	CUR = self
	self.finished = false
	self.acc = 0
	self.now = 0
	self.score = 0
	self.timeAcc = 0
	self.timState = "OFF"
	self.pz, self.pp = nil, nil
	self.hoverKey = nil
	self.vars = { min = "00", sek = "00" }
	self.puzzleName, self.puzzleSize = "nisserne", 30
	self.scoreString = "0"
	self.root = FL.New(LIB, 0)
end

function G:Close()
	if CUR == self then CUR = nil end
end

function G:Step()
	self.now = self.now + MS
	FL.Tick(self.root)
	if self.pz then
		local viewer = FL.Child(self.pz, "imageviewer")
		if viewer then
			FL.Tick(viewer)
			if viewer.frame == 8 or viewer.frame == 18 then FL.Stop(viewer) end
			if viewer.frame == 27 then FL.GotoAndStop(viewer, "hidden") end
		end
	end
	if self.timState == "ON" then
		self.timeAcc = self.timeAcc + MS
		self.timTick = (self.timTick or 0) + 1
		if self.timTick % 5 == 0 then self:TimUpdate() end   -- the timer clip's 5th frame
	end
	if self.GAMEON and self.timState ~= "PAUSED" then self:Dragupdate() end
	-- the keys (onClipEvent keyDown)
	local space = input.IsKeyDown(KEY_SPACE)
	if space and not self.spaceWas and self.GAMEON and self.timState ~= "PAUSED" then self:Rotate() end
	self.spaceWas = space
	local p = input.IsKeyDown(KEY_P)
	if p and not self.pWas and self.GAMEON and hiddenOn() then self:TogglePause() end
	self.pWas = p
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
	AN.FinishGame(11, (self.score or 0) / 1000)
end

-- a mouse press on the stage while the puzzle is on
function G:Press()
	if self.timState == "PAUSED" then
		self:TogglePause()   -- the pause screen's big button
		return
	end
	if not self.pz or not self.mainM then return end
	local mx, my = MG.Mouse()
	-- onClipEvent(mouseDown) first (it drops what you hold), then the button under the mouse
	if self.DRAGGING then self:Mclicked("") end
	local kind, a = self:TopButton(self.mainM, mx, my)
	if kind == "piece" then self:Mclicked(a) end
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	if not self.root then MG.Chrome(11) return end
	local st = self
	local hidden = hiddenOn()
	-- the preview picture (hidden content): the jpg the menu tried to load
	local preview = FL.Child(self.root, "preview")
	local jlo = preview and FL.Child(preview, "JLo")
	if jlo then
		local pre = FL.Child(jlo, "preload")
		if pre then pre.visible = not hidden end
		jlo.drawFn = nil
		if hidden then
			local name = self.puzzleName
			jlo.drawFn = function(M, alpha)
				TL.Pic("g11/thumb_" .. name .. ".jpg", 0, 0, 365.5, 279, M, alpha)
			end
		end
	end
	FL.VarHook = function(c, var)
		local name = string.lower(string.match(var, "([%w_]+)$") or var)
		if name == "scorestring" then return st.scoreString end
		if name == "txt_hint" then return AN.L("g11_t_hint") end
		return st.vars[name]
	end
	if self.GAMEON and self.timState ~= "PAUSED" then self:Dragupdate() end
	FL.Draw(self.root, { 1, 0, 0, 1, 0, 0 })
	FL.VarHook = nil
	self:UpdateHover()
	if self.hintT and self.pp and self.pp[self.hintPiece] then
		-- the piece that put itself in place lights up for a moment
		self.hintT = self.hintT - FrameTime()
		local h = self.pp[self.hintPiece].hilite
		if h then h.visible = self.hintT > 0 end
		if self.hintT <= 0 then self.hintT = nil end
	end

	local f = self.root.frame
	if f >= 18 and f <= 21 then
		-- the four pictures in the menu (invisible buttons over the names)
		for i, it in ipairs(FL.Items(self.root)) do
			if it[2] == 150 then
				local kid = self.root.kids[it[3]]
				local m = { it[4], it[5], it[6], it[7], it[8], it[9] }
				local btn, bm = FL.CharItem(kid, m, { [149] = true })
				if btn then
					local x0, y0, x1, y1 = FL.Bounds(btn, bm, true)
					local idx = ({ [60] = 1, [62] = 2, [64] = 3, [66] = 4 })[it[1]]
					local name = PUZZLES[idx]
					local hot = UI.Button("g11_pz" .. idx, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
						self:SelectPuzzleImage(name, SIZES[name])
					end, { hit = FL.HitFn(btn, bm) })
					if hot then
						AN.Box(MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), Color(255, 241, 207, 22), MG.S(8))
					end
				end
			elseif it[2] == 152 and f == 21 then
				local kid = self.root.kids[it[3]]
				local m = { it[4], it[5], it[6], it[7], it[8], it[9] }
				local x0, y0, x1, y1 = FL.Bounds(kid, m, true)
				UI.Button("g11_start", MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), function()
					FL.GotoAndPlay(self.root, "restart")
				end, { hit = FL.HitFn(kid, m) })
			end
		end
	elseif self.GAMEON or self.timState == "PAUSED" then
		UI.Button("g11_table", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), nil,
			{ silent = true, press = function() self:Press() end })
	elseif f >= 43 and f < 167 then
		UI.Button("g11_skip", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), function() FL.GotoAndPlay(self.root, "skip") end, { silent = true })
	end
	MG.Chrome(11)
end

AN.RegisterGame(11, G)
