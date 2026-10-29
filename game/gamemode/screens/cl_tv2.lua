-- The jul.tv2.dk look: the calendar from TV 2's Christmas site (kalender.swf, the 2006 season as the
-- web archive has it): Pyrus' town at night with the 24 doors. A door you may open fades away and
-- the day's game starts in the original game frame; a door that isn't open yet just says no.
AN = AN or {}
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/k06_fl.lua")

local TV = {}
AN.TV2 = TV
local LIB = "k06"
local I = { 1, 0, 0, 1, 0, 0 }
local DOC_W, DOC_H = 980, 622

local function snd(name)
	local vol = (AN.Save and AN.Save.Get("vol_fx") or 85) / 100
	if vol <= 0 or AN.SoundMode() == 2 then return end
	sound.PlayFile("sound/alletidersnisse/tv2/" .. name .. ".mp3", "noplay", function(ch)
		if IsValid(ch) then ch:SetVolume(vol) ch:Play() end
	end)
end

-- the calendar as big as it fits under the bar at the top
function TV.Place()
	local top = 150
	local k = math.min((AN.VW - 80) / DOC_W, (AN.VH - top - 40) / DOC_H)
	MG.sw, MG.sh = DOC_W, DOC_H
	MG.k = k
	MG.x0 = (AN.VW - DOC_W * k) / 2
	MG.y0 = -(AN.OY or 0) + top + (AN.VH - top - 40 - DOC_H * k) / 2
end

local function itemM(it) return { it[4], it[5], it[6], it[7], it[8], it[9] } end

-- the smoke from the chimney: 50 puffs that rise and fade, then start again
local function smokeSetup(holder)
	holder.extra = {}
	for i = 1, 49 do
		local k = FL.New(LIB, 22, holder)
		local x = math.random(0, 3) == 2 and math.random(0, 19) or -math.random(0, 19)
		holder.extra[#holder.extra + 1] = { c = k, m = { 1, 0, 0, 1, x, -(i + math.random(0, 4)) }, a = 1 }
	end
	holder.vars.smoke = true
end
local function smokeStep(holder)
	for _, e in ipairs(holder.extra or {}) do
		if e.m[6] > -60 and e.a > 0 then
			e.m[6] = e.m[6] - math.random(0, 2)
			e.a = e.a - math.random(0, 1) / 100
		else
			e.m[5], e.m[6], e.a = 0, 0, 1
		end
	end
	-- (the first puff is the one in the timeline)
end

local S = AN.Screens.tv2 or {}
AN.Screens.tv2 = S
S.garland = false

function S:Open(args)
	self.root = FL.New(LIB, 0)
	self.acc = 0
	self.hot = nil
	self.fading = {}
	self.cal = FL.Child(self.root, "cal_mc")
	self.doors = {}
	local lm = self.cal and FL.Child(self.cal, "laager_mc")
	if lm then
		for n = 1, 24 do
			local d = FL.Child(lm, "laage" .. n)
			if d then
				self.doors[n] = d
				-- doors already opened stay open
				if AN.Save.Opened(n) and AN.DoorState(n) ~= "locked" then d.alpha = 0 end
			end
		end
	end
	if self.cal then
		for _, it in ipairs(FL.Items(self.cal)) do
			if it[2] == 23 then
				local k = self.cal.kids[it[3]]
				if k then smokeSetup(k) self.smoke = k end
			end
		end
	end
	self.twink = FL.Child(self.root, "twink_")
	self.down = input.IsMouseDown(MOUSE_LEFT)
end

function S:Close()
	if IsValid(UI.root) then UI.root:SetCursor("arrow") end
	AN.Classic.Opt.open = false
end

-- the door under the mouse (doors are invisible boxes over the picture; faded ones still count)
function S:DoorAt(x, y)
	local lm = self.cal and FL.Child(self.cal, "laager_mc")
	if not lm then return nil end
	local M = TL.Mul(FL.ChildMatrix(self.root, "cal_mc", I), FL.ChildMatrix(self.cal, "laager_mc", I))
	for n = 24, 1, -1 do
		local m = FL.ChildMatrix(lm, "laage" .. n, M)
		local d = self.doors[n]
		if m and d then
			local x0, y0, x1, y1 = FL.Bounds(d, m, true)
			if x0 and x >= x0 and x <= x1 and y >= y0 and y <= y1 then return n end
		end
	end
end

function S:Press(n)
	local d = self.doors[n]
	if not d then return end
	if AN.DoorState(n) == "locked" then
		snd("wrong_" .. math.random(0, 3))
		return
	end
	if (d.alpha or 1) <= 0 then
		TV.Play(n)
		return
	end
	snd("down_" .. math.random(0, 7))
	self.fading[n] = true
end

-- the settings / seasons: the original settings scroll, the same as in the classic look
function TV.Options(page)
	local O = AN.Classic.Opt
	O.onClose = function()
		if AN.Save.Get("look") ~= "tv2" then UI.Open("main") end
	end
	O.Open(page)
end

-- the day's game, in the original frame (straight to its start board)
function TV.Play(n)
	AN.Save.SetOpened(n, true)
	UI.Open("classic", { door = n, direct = true })
end

function S:Think(dt)
	if not self.root then return end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= 1 / 25 do
		self.acc = self.acc - 1 / 25
		FL.Tick(self.root)
		AN.Classic.Opt.Tick()
		if self.smoke then smokeStep(self.smoke) end
		for n in pairs(self.fading) do
			local d = self.doors[n]
			d.alpha = (d.alpha or 1) - 0.1
			if d.alpha <= 0 then
				d.alpha = 0
				self.fading[n] = nil
				TV.Play(n)
				return
			end
		end
	end
	TV.Place()
	local x, y = (UI.mx - MG.x0) / MG.k, (UI.my - MG.y0) / MG.k
	local inside = x >= 0 and y >= 0 and x <= DOC_W and y <= DOC_H
	-- the twinkle follows the mouse
	if self.twink then self.twink.mat = { 1, 0, 0, 1, x, y } self.twink.visible = inside end
	local n = inside and not AN.Classic.Opt.IsOpen() and self:DoorAt(x, y) or nil
	if n ~= self.hot then
		self.hot = n
		if n then snd("over") end
	end
	local down = input.IsMouseDown(MOUSE_LEFT)
	if down and not self.down and n and not UI.hot then self:Press(n) end
	self.down = down
	if IsValid(UI.root) then UI.root:SetCursor(n and "hand" or "arrow") end
end

function S:Paint()
	local VW, VH = AN.VW, AN.VH
	local y0 = -(AN.OY or 0)
	-- night sky behind the page
	AN.Box(-(AN.OX or 0), y0, VW + 2 * (AN.OX or 0), VH, Color(10, 18, 40))
	AN.VGrad(0, y0, VW, VH * 0.6, Color(26, 40, 82), 255, 0)

	TV.Place()
	AN.Box(MG.x0 - 6, MG.y0 - 6, DOC_W * MG.k + 12, DOC_H * MG.k + 12, Color(0, 0, 0, 150), 10)
	render.SetScissorRect(AN.PX(MG.x0), AN.SY(MG.y0), AN.PX(MG.x0 + DOC_W * MG.k), AN.SY(MG.y0 + DOC_H * MG.k), true)
	FL.Draw(self.root, I)
	render.SetScissorRect(0, 0, 0, 0, false)

	-- the bar at the top: the other rooms of the game
	local px = 110
	px = px + UI.Pill("tv_box", AN.L("main_box"), px, 52, function() UI.Open("classic", { movie = "pynt" }) end, 22) + 14
	px = px + UI.Pill("tv_scrap", AN.L("main_scrap"), px, 52, function() UI.Open("classic", { movie = "skat" }) end, 22) + 14
	px = px + UI.Pill("tv_sea", AN.L("main_seasons"), px, 52, function() TV.Options(4) end, 22) + 14
	UI.Pill("tv_set", AN.L("main_settings"), px, 52, function() TV.Options(1) end, 22)
	UI.CornerButtons(function() RunConsoleCommand("disconnect") end)
	-- the settings scroll from the classic look, in the middle of the calendar
	TV.Place()
	AN.Classic.Opt.Draw((DOC_W - 800) / 2, (DOC_H - 600) / 2)
end
