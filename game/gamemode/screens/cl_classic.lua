-- The classic look: the original main screen (main.swf, the loft with the 24 doors) played as it
-- was, 800 x 600 in the middle of the screen. Its frame scripts are ported to Lua below; the
-- progress (open doors, ornaments, pebernødder, scores) is the same save as the modern look.
AN = AN or {}
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/cl_fl.lua")
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/cl_auto.lua")
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/clpk_fl.lua")
include((GM or GAMEMODE).FolderName .. "/gamemode/games/data/clsk_fl.lua")

local CL = AN.Classic or {}
AN.Classic = CL
local LIB = "cl"
local I = { 1, 0, 0, 1, 0, 0 }
local DOC_W, DOC_H = 800, 600
CL.FPS = 25

-- the classic look (the loft) and the jul.tv2.dk look (its own calendar) both play the games in
-- the original frame from main.swf
function CL.Look() local l = AN.Save.Get("look") return (l == "classic" or l == "tv2") and l or nil end
function CL.Active() return CL.Look() ~= nil end

-- the 800 x 600 document filling the screen height, black around it
function CL.Place()
	local k = AN.VH / DOC_H
	if DOC_W * k > AN.VW then k = AN.VW / DOC_W end
	MG.sw, MG.sh = DOC_W, DOC_H
	MG.k = k
	MG.x0 = (AN.VW - DOC_W * k) / 2
	MG.y0 = -(AN.OY or 0) + (AN.VH - DOC_H * k) / 2
end
function MG.ClassicStage()
	CL.Place()
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	render.SetScissorRect(AN.PX(MG.x0), AN.SY(MG.y0), AN.PX(MG.x0 + DOC_W * MG.k), AN.SY(MG.y0 + DOC_H * MG.k), true)
end
function MG.ClassicEnd() render.SetScissorRect(0, 0, 0, 0, false) end

-- the mouse in document coordinates
function CL.Mouse()
	CL.Place()
	return (UI.mx - MG.x0) / MG.k, (UI.my - MG.y0) / MG.k
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function itemM(it) return { it[4], it[5], it[6], it[7], it[8], it[9] } end
local function child(c, ...)
	for _, nm in ipairs({ ... }) do
		c = c and FL.Child(c, nm)
	end
	return c
end
CL.Child = child
-- a clip's own matrix inside its parent (as a script sees _x, _y, _xscale ...)
local function ownM(c)
	if c.mat then return c.mat end
	local p = c.parent
	if not p then return I end
	for _, it in ipairs(FL.Items(p)) do
		if p.kids[it[3]] == c then return itemM(it) end
	end
	-- (a clip's own frame script runs while it is being made, before its parent lists it)
	if c.name then
		local lname = string.lower(c.name)
		for _, it in ipairs(FL.Items(p)) do
			if it.nm and string.lower(it.nm) == lname and not p.kids[it[3]] then return itemM(it) end
		end
	end
	return I
end
CL.OwnM = ownM
local function setXY(c, x, y)
	local m = ownM(c)
	c.mat = { m[1], m[2], m[3], m[4], x, y }
end

-- every live clip under c (also invisible ones) with its stage matrix: fn(clip, M, visible)
local function walk(c, M, vis, fn)
	if not c then return end
	fn(c, M, vis)
	vis = vis and c.visible
	if c.kind == "spr" then
		for _, it in ipairs(FL.Items(c)) do
			local k = c.kids[it[3]]
			if k and not it.cd then walk(k, TL.Mul(M, k.mat or itemM(it)), vis, fn) end
		end
		if c.extra then
			for _, e in ipairs(c.extra) do walk(e.c, TL.Mul(M, e.m), vis, fn) end
		end
	end
end
CL.Walk = walk

-- attachMovie: a new clip on top of c's own children
function CL.Attach(c, ref, name, m, lib)
	local k = FL.New(lib or c.lib or LIB, ref, c, name)
	c.extra = c.extra or {}
	c.extra[#c.extra + 1] = { c = k, m = m or { 1, 0, 0, 1, 0, 0 }, name = name }
	return k
end
function CL.Attached(c, name)
	for _, e in ipairs(c.extra or {}) do
		if e.name == name then return e.c, e end
	end
end

-- sounds of the main screen (mainSoundPlayer)
local SND = { cardboard = "flap", kiste_open = "kiste_open", kiste_close = "kiste_close", click = "click",
	click_over = "over", click_out = "out", scroll_up = "scroll_up", scroll_down = "scroll_down",
	options_up = "scroll_up", options_down = "scroll_down", triangel = "triangel", point_01 = "point" }
function CL.Snd(id)
	if SND[id] then AN.Sound(SND[id]) end
end

---------------------------------------------------------------------------
-- Frame scripts
---------------------------------------------------------------------------
local AUTO = {
	stop = function(c) FL.Stop(c) end,
	play = function(c) FL.Play(c) end,
	g1p = function(c) FL.GotoAndPlay(c, 1) end,
	g1s = function(c) FL.GotoAndStop(c, 1) end,
	hide = function(c) c.visible = false FL.Stop(c) end,
}

-- onClipEvent(load) { _visible = false }: the holders for the loaded movies, the cover, the debug
-- log, the little clips that say a line when you rest the mouse on a button, and the reference
-- points of the doors
FL.LoadHidden[LIB] = { [672] = true, [872] = true, [436] = true, [438] = true, [440] = true, [443] = true, [285] = true, [1044] = true,
	[1080] = true, [1006] = true }

FL.WrapDyn[LIB] = true
FL.WrapDyn.clpk = true
FL.WrapDyn.clsk = true

CL.Script = {}   -- [cid] = { [frame] = fn } on top of the simple ones
function CL.SetupActions()
	local all = {}
	for cid, frames in pairs(AN.ClassicAuto) do
		all[cid] = all[cid] or {}
		for f, k in pairs(frames) do all[cid][f] = AUTO[k] end
	end
	for cid, frames in pairs(CL.Script) do
		all[cid] = all[cid] or {}
		for f, fn in pairs(frames) do all[cid][f] = fn end
	end
	for cid, t in pairs(all) do FL.SetActions(LIB, cid, t) end
	for lib, scripts in pairs(CL.ScriptL or {}) do
		for cid, t in pairs(scripts) do FL.SetActions(lib, cid, t) end
	end
end

-- the date, like the original's decemberDate: 1 = 1 December (0 = 30 November, -1 = 29 November ...)
function CL.DecemberDate()
	local now = os.date("*t")
	local y = now.year
	if now.month < 11 then y = y - 1 end
	local dec1 = os.time({ year = y, month = 12, day = 1, hour = 0 })
	local today = os.time({ year = now.year, month = now.month, day = now.day, hour = 0 })
	return math.floor((today - dec1) / 86400 + 0.5) + 1
end

function CL.Locked(n) return AN.DoorState(n) == "locked" end

---------------------------------------------------------------------------
-- The doors (sprite 1110, named "Låge1" .. "Låge24")
---------------------------------------------------------------------------
local D = {}
CL.DoorFns = D

function D.Segs(c)
	local t = {}
	for i = 1, 12 do t[i] = FL.Child(c, "s" .. i) end
	return t
end

local function refXY(c, name)
	local m = FL.ChildMatrix(c, name, I)
	if not m then return nil end
	return m[5], m[6]
end

-- Initialize_Placements
function D.Init(c)
	FL.Stop(c)
	local day = tonumber(string.match(c.name or "", "(%d+)$") or "") or 1
	c.vars.day = day
	CL.doors[day] = c
	local m = ownM(c)
	c.sx = math.sqrt(m[1] * m[1] + m[2] * m[2])
	c.sy = math.sqrt(m[3] * m[3] + m[4] * m[4])
	c.X, c.Y = m[5], m[6]
	local tlx = refXY(c, "refTL")
	local trx, try = refXY(c, "refTR")
	local _, bry = refXY(c, "refBR")
	c.boxW = (trx or 60) - (tlx or 0)
	c.boxH = (bry or 60) - (try or 0)
	-- the picture behind the door
	local content = FL.Child(c, "content")
	if content then
		content.extra = nil
		local pic = CL.Attach(content, 356, "content", { 1 / c.sx, 0, 0, 1 / c.sy, 0, 0 })
		FL.GotoAndStop(pic, day + 1)
		content.visible = false
	end
	local num = FL.Child(c, "num")
	if num then num.vars.daytxt = day end
	if AN.Save.Opened(day) and not CL.Locked(day) then
		FL.GotoAndStop(c, "open")
		if content then content.visible = true end
		for _, s in pairs(D.Segs(c)) do s.visible = false end
	end
end

-- updatePos: the door flap is drawn as 12 strips of the background, bent between the reference
-- points while the door turns (frames 2 - 8)
function D.UpdatePos(c)
	local segs = D.Segs(c)
	local tlx, tly = refXY(c, "refTL")
	local trx, try = refXY(c, "refTR")
	local blx, bly = refXY(c, "refBL")
	local brx, bry = refXY(c, "refBR")
	if not trx or not tlx or not blx or not brx then
		for _, s in pairs(segs) do s.visible = false end
		return
	end
	local n = 12
	local topSlope = (try - tly) / n
	local botSlope = (bry - bly) / n
	local swidth = trx - tlx
	local xacc, yacc, ybacc = tlx, tly, bly
	for t = 1, n do
		local s = segs[t]
		if s then
			s.visible = true
			local dh = (ybacc - yacc) / c.boxH * 100 / c.sy
			s.mat = { 1.1, 0, 0, dh / 100, xacc, yacc }
			local bg = FL.Child(s, "bg")
			if bg then bg.mat = { 1, 0, 0, 1, -(c.X + (t - 1) * 5 * c.sx), -c.Y } end
		end
		xacc = xacc + swidth / n
		yacc = yacc + topSlope
		ybacc = ybacc + botSlope
	end
end

CL.Script[1110] = {
	[1] = function(c) D.Init(c) end,
	[2] = function(c)
		if c.backwards then
			AN.Save.SetOpened(c.vars.day, false)
			c.onEnter = nil
			c.backwards = false
			FL.GotoAndStop(c, 1)
			return
		end
		local content = FL.Child(c, "content")
		if content then content.visible = true end
	end,
	[15] = function(c)
		FL.Stop(c)
		if c.onEnter then
			c.onEnter = nil
			AN.Save.SetOpened(c.vars.day, true)
		end
	end,
}

---------------------------------------------------------------------------
-- Buttons: the button scripts of main.swf. fn(p, btn): p = the timeline the button is on ("this")
---------------------------------------------------------------------------
CL.B = {}
local B = CL.B
-- buttons of the movies loaded into the main screen (pyntekasse.swf, skattekiste.swf)
CL.BL = { clpk = {}, clsk = {} }
local function BH(c)
	if c.lib == LIB then return B[c.id] end
	return CL.BL[c.lib] and CL.BL[c.lib][c.id]
end
CL.BH = BH
local function spark(on) local s = child(CL.root, "sparkTrail") if s then s.vars.hilite = on end end

-- a door: open it
B[1082] = {
	release = function(p)
		local day = p.vars.day
		if CL.Locked(day) then
			CL.MainClick("LÅGE_FORBUDT")
		else
			p.onEnter = function(c) D.UpdatePos(c) end
			CL.Snd("cardboard")
			FL.Play(p)
		end
	end,
	over = function(p) if not CL.Locked(p.vars.day) then spark(true) end end,
	out = function() spark(false) end,
}
-- an open door: close it again
B[1106] = {
	release = function(p)
		p.onEnter = function(c)
			c.backwards = true
			FL.PrevFrame(c)
			if c.onEnter then D.UpdatePos(c) end
		end
		CL.Snd("cardboard")
	end,
}
-- the picture behind an open door: play the game
B[1107] = {
	release = function(p) CL.MainClick("LÅGE", p.vars.day) end,
	over = function() spark(true) end,
	out = function() spark(false) end,
}
-- Pyntekassen (the box with the ornaments)
B[1038] = {
	release = function() CL.MainClick("PYNTEKASSE") end,
	over = function(p) FL.GotoAndPlay(p, "open") spark(true) end,
	out = function(p) p.vars.doClose = true spark(false) end,
}
-- the tree: also the decoration box
B[990] = { release = function() CL.MainClick("PYNTEKASSE") end }
-- Indstillinger
B[1051] = {
	release = function() CL.MainClick("OPTIONS") end,
	over = function(p) FL.GotoAndPlay(p, "animon") spark(true) end,
	out = function(p) FL.GotoAndPlay(p, "animoff") spark(false) end,
}
-- Scrapbogen
B[1060] = {
	release = function() CL.MainClick("SCRAPBOG") end,
	over = function(p) FL.GotoAndPlay(p, "animon") spark(true) end,
	out = function(p) FL.GotoAndPlay(p, "animoff") spark(false) end,
}
-- the jul.tv2.dk newspaper (the original opened the web site)
B[1076] = {
	release = function() gui.OpenURL("http://jul.tv2.dk/") end,
	over = function(p) FL.GotoAndPlay(p, "animon") spark(true) end,
	out = function(p) p.vars.doClose = true spark(false) end,
}
-- Pyrus' roll: unrolls when the mouse comes on it, rolls up when it leaves
B[1113] = { over = function(p) FL.GotoAndPlay(p, "animon") end }
B[1121] = { over = function(p) FL.GotoAndPlay(p, "animoff") end }
-- a day on the roll
B[200] = {
	release = function(p)
		CL.MainClick("LÅGE", p.vars.day)
		local roll = child(CL.root, "pyrusrulleButMC")
		if roll then FL.GotoAndPlay(roll, "animoff") end
	end,
}
-- close (X), with "are you sure?"
local function clickSounds(t)
	t.press = t.press or function() CL.Snd("click") end
	local over, out = t.over, t.out
	t.over = function(p, b) CL.Snd("click_over") if over then over(p, b) end end
	t.out = function(p, b) CL.Snd("click_out") if out then out(p, b) end end
	return t
end
B[1202] = clickSounds({
	release = function() CL.MainClick("MAIN_PRECLOSE") end,
	over = function(p) FL.GotoAndStop(p, "over") end,
	out = function(p) FL.GotoAndStop(p, "normal") end,
})
B[1206] = { release = function(p) FL.GotoAndStop(p.parent or p, 1) end }   -- no
B[1208] = { release = function() CL.MainClick("MAIN_CLOSECONFIRM") end }  -- yes
B[1232] = { release = function() CL.MainClick("MAIN_CLOSE") end }
B[1233] = clickSounds({
	release = function() CL.MainClick("MAIN_CLOSE") end,
	over = function(p) FL.GotoAndStop(p, "over") end,
	out = function(p) FL.GotoAndStop(p, "normal") end,
})
-- sound: all on -> music off -> mute
for _, id in ipairs({ 1216, 1220, 1224 }) do
	B[id] = clickSounds({ release = function() CL.MuteToggle() end })
end

---------------------------------------------------------------------------
-- Sprite scripts of the loft
---------------------------------------------------------------------------
-- the box with the ornaments opens on rollover and closes again when the mouse leaves
CL.Script[1045] = {
	[1] = function(c) c.vars.doClose = false FL.Stop(c) end,
	[2] = function() CL.Snd("kiste_open") end,
	[7] = function(c)
		FL.Stop(c)
		c.onEnter = function(cc)
			if cc.vars.doClose then
				FL.Play(cc)
				CL.Snd("kiste_close")
				cc.onEnter = nil
			end
		end
	end,
}
CL.Script[1054] = { [1] = function(c) FL.Stop(c) end, [2] = function() CL.Snd("options_up") end, [7] = function(c) FL.Stop(c) end }
CL.Script[1077] = {
	[1] = function(c) c.vars.doClose = false FL.Stop(c) end,
	[3] = function() CL.Snd("options_down") end,
	[8] = function(c)
		FL.Stop(c)
		c.onEnter = function(cc) if cc.vars.doClose then FL.Play(cc) end end
	end,
}
CL.Script[1124] = {
	[1] = function(c) FL.Stop(c) end,
	[3] = function() CL.Snd("scroll_down") end,
	[10] = function(c) FL.Stop(c) CL.FillPyrusRoll(child(c, "linksHolder")) end,
	[11] = function() CL.Snd("scroll_up") end,
	[18] = function() AN.StopSpeech() end,
}

-- the clips that say a line when the mouse rests on a button: (waitFrames, sound) by the button clip
local REST = { [1045] = { 15, "skattekiste_rollover" }, [1054] = { 20, "instillinger_rollover" },
	[1066] = { 20, "scrapbog_rollover" }, [1077] = { 20, "klikpaajultv2dk" }, [1124] = { 500, "pyrusrulle_rollover" },
	[1203] = { 45, "luk_rollover" } }
CL.Script[1044] = {
	[1] = function(c)
		local r = c.parent and REST[c.parent.id]
		if r then c.vars.wait, c.vars.snd = r[1], r[2] end
		c.onEnter = function(cc)
			if not cc.vars.wait then return end
			cc.vars.wait = cc.vars.wait - 1
			if cc.vars.wait == 0 then AN.Speak(cc.vars.snd) end
		end
	end,
}

-- Pyrus' roll: a line for every day, the days not open yet say when they come
function CL.FillPyrusRoll(holder)
	if not holder then return end
	holder.extra = nil
	local h = 20.6
	local dd = CL.DecemberDate()
	for g = 1, 24 do
		local early = CL.Locked(g)
		local k = CL.Attach(holder, early and 194 or 203, "link" .. (g - 1), { 1, 0, 0, 1, 0, h * (g - 1) })
		k.vars.day = g
		k.vars.txt_day = g .. "."
		if not early then
			k.vars.txt_name = AN.GameName(g)
		elseif AN.UsesDate() then
			local left = g - dd
			k.vars.txt_name = left == 1 and AN.L("cl_roll_tomorrow") or AN.L("cl_roll_days", left)
		else
			k.vars.txt_name = AN.L("cl_roll_after", AN.BlockingDoor(g) or g - 1)
		end
		-- the button on a line plays the day (its script reads "day" from the line)
		for _, kid in pairs(k.kids) do kid.vars.day = g end
	end
end

-- the date at the top
function CL.DateText()
	local dd = CL.DecemberDate()
	local y = tonumber(os.date("%Y"))
	if dd < -1 and dd > -60 then return AN.L("cl_date_wait", 1 - dd), false
	elseif dd == -1 then return AN.L("cl_date_m1"), false
	elseif dd == 0 then return AN.L("cl_date_0"), false
	elseif dd >= 1 and dd < 23 then return AN.L("cl_date_day", dd, y), true
	elseif dd == 23 then return AN.L("cl_date_23"), true
	elseif dd == 24 then return AN.L("cl_date_24"), true
	elseif dd == 25 then return AN.L("cl_date_25"), true
	elseif dd == 26 then return AN.L("cl_date_26"), true
	elseif dd >= 27 and dd <= 31 then return AN.L("cl_date_day", dd, y), true
	end
	return AN.L("cl_date_next", AN.DaysToEve()), true
end
CL.Script[1196] = {
	[1] = function(c)
		FL.Stop(c)
		local txt, show = CL.DateText()
		c.vars.txt = txt
		local g = child(c.parent, "gyldengrod")
		if g then g.visible = show end
		-- Kandis at the table: the original hides her and then tries to show her again by a name she
		-- doesn't have, so she never came. Shown with the hidden content.
		for _, k in pairs(c.parent.kids) do
			if k.id == 1006 then k.visible = show and AN.Save.Get("hidden") ~= false end
		end
	end,
}

-- the tree in the loft with the player's own ornaments (the same tree as in the modern look)
function CL.DecorateTree(tree)
	if not tree then return end
	tree.extra = nil
	-- modern tree frame (820 wide, the image at its bottom) -> the tree clip's own coordinates
	local tx, ty, tw, th = AN.TreeImageRect()
	local fx, fy = 350 / tw, 428 / th
	local items, star = {}, nil
	for _, o in ipairs(AN.Save.Tree()) do
		local x, y = -186.2 + (o.x - tx) * fx, -187.25 + (o.y - ty) * fy
		if o.id == "star0" then star = { o.id, x, y } else items[#items + 1] = { o.id, x, y } end
	end
	if star then items[#items + 1] = star end
	for i, it in ipairs(items) do
		local k = CL.Attach(tree, it[1], "item" .. (i - 1), { 1, 0, 0, 1, it[2], it[3] })
		FL.Stop(k)
	end
	-- like the original: the tree comes to the loft on 14 December
	if AN.UsesDate() and CL.DecemberDate() < 14 then tree.visible = false end
end
CL.Script[991] = { [1] = function(c) CL.DecorateTree(c) end }

-- the sparkles: follow the mouse over the doors and buttons
CL.Script[1126] = {
	[1] = function(c)
		c.extra = nil
		for t = 0, 39 do
			local s = CL.Attach(c, 39, "spark" .. t)
			FL.Stop(s)
			s.visible = false
		end
		c.vars.cur = 0
		c.onEnter = function(cc)
			if not (cc.vars.hilite or cc.vars.trail) then return end
			local mx, my = CL.Mouse()
			local m = CL.RootMatrix(cc)
			if not m then return end
			local e = cc.extra[cc.vars.cur + 1]
			if e then
				local a = math.rad(math.random() * 360)
				e.m = { math.cos(a), math.sin(a), -math.sin(a), math.cos(a), mx - m[5], my - m[6] }
				e.c.visible = true
				FL.GotoAndPlay(e.c, 1)
			end
			cc.vars.cur = (cc.vars.cur + 1) % 40
		end
	end,
}

-- mute button: 0 = all on, 1 = music off, 2 = mute (the same setting as the modern look)
function CL.UpdateMute()
	local m = child(CL.root, "muteMC")
	if not m then return end
	local mode = AN.SoundMode()
	FL.GotoAndStop(m, mode == 2 and "mute" or (mode == 1 and "nomusic" or "nomute"))
end
function CL.MuteToggle()
	AN.CycleSoundMode()
	CL.UpdateMute()
end
CL.Script[1225] = { [1] = function(c) FL.Stop(c) end }
-- the credits after "Ja": at their end the program closes
CL.Script[1230] = { [838] = function(c) FL.Stop(c) CL.MainClick("MAIN_CLOSE") end }

-- the stage matrix of a clip (from the root)
function CL.RootMatrix(c)
	local chain = {}
	local k = c
	while k and k.parent do
		chain[#chain + 1] = k
		k = k.parent
	end
	if k ~= CL.root then
		-- an attached clip: look it up in its parent's extra list
	end
	local m = I
	for i = #chain, 1, -1 do
		local kk = chain[i]
		local em
		for _, e in ipairs(kk.parent.extra or {}) do
			if e.c == kk then em = e.m end
		end
		m = TL.Mul(m, em or ownM(kk))
	end
	return m
end

---------------------------------------------------------------------------
-- mainclick
---------------------------------------------------------------------------
function CL.HideButtons()
	for _, nm in ipairs({ "linkButMc", "pyrusrulleButMC", "optionsButMC", "pynteButMC", "tree", "skatButMC" }) do
		local b = child(CL.root, nm, "btn")
		if b then b.visible = false end
	end
	local gui = child(CL.root, "GUI")
	if gui then gui.visible = false end
	for _, d in pairs(CL.doors) do
		for _, nm in ipairs({ "butOpen", "butCloser", "butContent" }) do
			local b = FL.Child(d, nm)
			if b then b.visible = false end
		end
	end
	CL.buttonsHidden = true
end
function CL.ShowButtons()
	for _, nm in ipairs({ "linkButMc", "pyrusrulleButMC", "optionsButMC", "pynteButMC", "tree", "skatButMC" }) do
		local b = child(CL.root, nm, "btn")
		if b then b.visible = true end
	end
	local gui = child(CL.root, "GUI")
	if gui then gui.visible = true end
	for _, d in pairs(CL.doors) do
		for _, nm in ipairs({ "butOpen", "butCloser", "butContent" }) do
			local b = FL.Child(d, nm)
			if b then b.visible = true end
		end
	end
	CL.buttonsHidden = false
end

function CL.MainClick(param, data)
	param = AN.Upper(param)
	if param == "PYNTEKASSE" then
		CL.ShowMovie("holderPynt", "clpk")
		CL.HideButtons()
		local pk = CL.movies.holderPynt
		if pk then FL.GotoAndPlay(pk, "splash") end
	elseif param == "SCRAPBOG" then
		CL.ShowMovie("holderSkat", "clsk")
		AN.Speak("scrapbog_start")
		CL.HideButtons()
	elseif (param == "PYNTEKASSE_CLOSE" or param == "SKATTEKISTE_CLOSE") and CL.Look() == "tv2" then
		if param == "PYNTEKASSE_CLOSE" then CL.HideMovie("holderPynt") else CL.HideMovie("holderSkat") end
		AN.StopSpeech()
		UI.Open("tv2")
	elseif param == "PYNTEKASSE_CLOSE" then
		CL.HideMovie("holderPynt")
		CL.ShowButtons()
		CL.DecorateTree(child(CL.root, "tree"))
		AN.StopSpeech()
	elseif param == "SKATTEKISTE_CLOSE" then
		AN.StopSpeech()
		local sk = CL.movies.holderSkat
		local content = sk and FL.Child(sk, "content")
		if content then FL.GotoAndStop(content, 1) end
		CL.HideMovie("holderSkat")
		CL.ShowButtons()
	elseif param == "OPTIONS" then
		-- the original settings scroll, over the loft
		CL.HideButtons()
		CL.Opt.onClose = function()
			if CL.Look() ~= "classic" then UI.Open("main") else CL.ShowButtons() end
		end
		CL.Opt.Open()
	elseif param == "MAIN_PRECLOSE" then
		local gui = child(CL.root, "GUI")
		if gui then FL.GotoAndStop(gui, "quitconfirm") end
	elseif param == "MAIN_CLOSECONFIRM" then
		FL.GotoAndStop(CL.root, "credits")
	elseif param == "MAIN_CLOSE" then
		CL.Quit()
	elseif param == "LÅGE" then
		CL.StartDoor(data)
	elseif param == "LÅGE_FORBUDT" then
		AN.Speak("julekalender_forkert")
	end
end

-- leaving the classic main screen ends the game, like the modern menu's "Afslut"
function CL.Quit()
	RunConsoleCommand("disconnect")
end

---------------------------------------------------------------------------
-- A game, in the original frame (ingameGUI): Pyrus' intro, the start board with the highscores
-- and the help pages, the game itself on the grey stage, and the pebernødder after it
---------------------------------------------------------------------------
local function gui() return child(CL.root, "ingameGUI") end

-- lågeklik: Pyrus comes in
function CL.StartDoor(n)
	if not (AN.Games[n] and AN.Games[n].made) then
		AN.Speak("julekalender_forkert")
		return
	end
	CL.cur = n
	CL.HideButtons()
	AN.StopSpeech()
	local g = gui()
	if g then g.vars.curGameDay = n FL.GotoAndStop(g, "intro") end
end

-- the start board: the game's logo, Start, Hjælp and the highscores
function CL.IntroDone()
	local n = CL.cur
	if not n then return end
	local g = gui()
	if not g then return end
	g.vars.curGameDay = n
	FL.GotoAndStop(g, "gamestartsk?rm")
	AN.StopSpeech()
	AN.Speak(AN.GameSlug[n] .. "_intro")
end

-- Start: the game on the grey stage
function CL.GameStart()
	local n = CL.cur
	if not n then return end
	AN.StopSpeech()
	local g = gui()
	if g then FL.GotoAndStop(g, "ingame") end
	FL.GotoAndStop(CL.root, "playinggame")
	CL.HideButtons()
	CL.inGame = n
	UI.Open("game" .. n, { classic = true })
end

-- back: to the start board, or (toMain) to the loft
function CL.GameBack(toMain)
	CL.inGame = nil
	if UI.screenName ~= "classic" then UI.Open("classic", { keep = true }) end
	local g = gui()
	if toMain and CL.Look() == "tv2" then
		CL.cur = nil
		AN.StopSpeech()
		UI.Open("tv2")
		return
	end
	if toMain then
		CL.cur = nil
		FL.GotoAndStop(CL.root, "loaddone")
		if g then FL.GotoAndStop(g, 1) end
		CL.ShowButtons()
		AN.StopSpeech()
	elseif g then
		FL.GotoAndStop(g, "gamestartsk?rm")
	end
end

-- the game is over: the pebernødder (the result is already saved by AN.FinishGame)
function CL.GameOver(n, value, res)
	CL.inGame = nil
	CL.cur = n
	CL.lastRes = res
	CL.lastValue = value
	UI.Open("classic", { keep = true })
	local g = gui()
	if g then FL.GotoAndStop(g, "gameover") end
end

-- ingameGUI's frame 7: Pyrus does the intro
CL.Script[925] = {
	[1] = function(c) FL.Stop(c) end,
	[7] = function(c)
		local p = child(c.parent, "pyrus")
		if p then FL.GotoAndStop(p, "intro") end
	end,
	[41] = function(c) FL.Stop(c) end,
}
-- Pyrus' intro: at its end the start board comes (or at once with a click on him)
CL.Script[1189] = { [195] = function(c) CL.IntroDone() if c.parent then FL.GotoAndStop(c.parent, 1) end end }
B[1190] = { release = function() CL.IntroDone() end }
B[1191] = { release = function(p) CL.IntroDone() FL.GotoAndStop(p, "idle") end }

-- the start board
CL.Script[837] = { [1] = function(c) FL.Stop(c) end }
-- the game's logo: one frame per day
CL.Script[667] = { [1] = function(c) FL.GotoAndStop(c, CL.cur or 1) end }
CL.Script[861] = { [1] = function(c) FL.GotoAndStop(c, CL.cur or 1) end }
-- the highscores of this door on the board (the same list as the modern look: best first)
function CL.FillScores(list)
	local pane = child(list, "scrollPane")
	if not pane then return end
	pane.extra = nil
	-- the scroll pane component: its placeholder goes, and the scroll bar too while the list fits
	for _, k in pairs(pane.kids) do k.visible = false end
	local sb = FL.Child(list, "sb")
	if sb then sb.visible = false end
	local n = CL.cur or 1
	local scores = AN.Save.Scores(n)
	for t, e in ipairs(scores) do
		if t > 10 then break end
		local r = CL.Attach(pane, 27, "row" .. (t - 1), { 1, 0, 0, 1, 0, 2 + (t - 1) * 15 })
		r.vars.number = t
		r.vars.name = e.name or "?"
		if AN.Games[n].scoreType == "time" then
			r.vars.score = CL.ScoreToTime(e.v)
		else
			r.vars.score = math.floor(e.v or 0)
		end
		local um = FL.Child(r, "um")
		if um then um.visible = false end
	end
end
CL.Script[691] = { [1] = function(c) CL.FillScores(c) end }
-- times like the original: mm:ss:ttt
function CL.ScoreToTime(sec)
	local ms = math.floor((sec or 0) * 1000 + 0.5)
	local m = math.floor(ms / 60000)
	local s = math.floor(ms / 1000) - m * 60
	return string.format("%02d:%02d:%03d", m, s, ms - m * 60000 - s * 1000)
end
-- Start
B[669] = clickSounds({ release = function() CL.GameStart() end })
-- X on the start board: back to the loft
B[481] = clickSounds({ release = function() CL.GameBack(true) end })
-- Hjælp, and back to the highscores
B[695] = clickSounds({ release = function(p) AN.StopSpeech() FL.GotoAndStop(p, "help") end })
B[836] = { release = function(p) AN.StopSpeech() FL.GotoAndStop(p, "hiscore") end }

-- the help pages: one frame per day, the pages inside it
CL.Script[834] = {
	[1] = function(c)
		local day = CL.cur or 1
		FL.GotoAndStop(c, day)
		c.vars.curPage = 1
		CL.HelpArrows(c)
		AN.Speak("help_" .. AN.GameSlug[day])
	end,
}
function CL.HelpArrows(c)
	local h = FL.Child(c, "helpmc")
	local pages = h and h.nframes or 1
	if h then FL.GotoAndStop(h, c.vars.curPage or 1) end
	local prev, nxt = FL.Child(c, "prevArrow"), FL.Child(c, "nextArrow")
	if prev then prev.visible = (c.vars.curPage or 1) > 1 end
	if nxt then nxt.visible = (c.vars.curPage or 1) < pages end
end
B[708] = { release = function(p) local h = p.parent if h then h.vars.curPage = math.max(1, (h.vars.curPage or 1) - 1) CL.HelpArrows(h) end end }
B[713] = { release = function(p) local h = p.parent if h then h.vars.curPage = (h.vars.curPage or 1) + 1 CL.HelpArrows(h) end end }

-- in the game: the X in the corner asks first
CL.Script[849] = { [1] = function(c) FL.Stop(c) end }
B[838] = clickSounds({ release = function(p) FL.GotoAndStop(p, "dialog") end })
B[844] = clickSounds({ release = function() CL.QuitGame() end })
B[847] = clickSounds({ release = function(p) FL.GotoAndStop(p, 1) end })
-- leaving a game in the middle: levels already done count (like the modern look)
function CL.QuitGame()
	local n = CL.inGame
	local run = n and AN.CurRun and AN.CurRun[n]
	local scr = UI.screen
	if run and run.total and scr and not scr.finished then
		scr.finished = true
		if scr.StopLoops then scr:StopLoops() end
		AN.FinishGame(n, run.total)
		return
	end
	if scr and scr.StopLoops then scr:StopLoops() end
	CL.GameBack(false)
end

-- after the game: the pebernødder fill up one by one; with enough of them the new ornament comes
CL.Script[924] = {
	[1] = function(c)
		FL.Stop(c)
		-- the box for the content from jul.tv2.dk: nothing comes, so its "CONTENT HOLDER" goes
		local h = FL.Child(c, "holder")
		if h then h.visible = false end
	end,
	[12] = function(c)
		local pt = FL.Child(c, "pointtime")
		if pt then FL.GotoAndStop(pt, AN.Games[CL.cur or 1].scoreType == "time" and "time" or "point") end
		local on = FL.Child(c, "onlineSubmitMc")
		if on then on.visible = false end
		c.vars.usernametxt = IsValid(LocalPlayer()) and LocalPlayer():Nick() or ""
		local n = CL.cur or 1
		c.vars.scoretxt = AN.Games[n].scoreType == "time" and CL.ScoreToTime(CL.lastValue) or math.floor(CL.lastValue or 0)
	end,
	[67] = function(c) FL.Stop(c) end,
}
-- the line over the box: what jul.tv2.dk had that day in December 2006 (nothing outside December)
local LAAGE = { "Kom i julestemning. Vind musikken fra Pyrus på jul.tv2.dk", "Vind Pyrus' nissehue på jul.tv2.dk",
	"Husk STOR adventskonkurrence på jul.tv2.dk", "Vind den Pyrus julebog på jul.tv2.dk", "Lær mere om Pyrus sangene på jul.tv2.dk",
	"Pyrus konfektkonkurrence og konfektkage på jul.tv2.dk", "Vind Pyrus Trylle Medaljon på jul.tv2.dk",
	"Vind præmier fra Julemærkefonden på jul.tv2.dk.", "Vind Pyrus strikhuer med keystrings på jul.tv2.dk",
	"Husk STOR adventskonkurrencen på jul.tv2.dk", "Send Pyrus julekort på jul.tv2.dk",
	"Kom i julestemning. Vind musikken fra Pyrus på jul.tv2.dk", "Chat med Pyrus i aften på jul.tv2.dk",
	"Vind Pyrus nissehuer og Pyrus julebøger på jul.tv2.dk", "Vind Pyrus Trylle Medaljon og strikhue med keystring på jul.tv2.dk",
	"Prøv nyt Pyrus spil på jul.tv2.dk", "Husk STOR adventskonkurrence på jul.tv2.dk", "Få flot computer-billedalbum på jul.tv2.dk",
	"Få et gratis Pyrus mobil-billede på jul.tv2.dk", "Test dig selv på jul.tv2.dk", "Vind TV 2 Sputnik abonnement på jul.tv2.dk",
	"Tænd et julelys på jul.tv2.dk", "Vind ekstra store præmier på jul.tv2.dk", "Overraskelse og adventkonkurrence på jul.tv2.dk" }
CL.Script[880] = {
	[1] = function(c)
		local dd = CL.DecemberDate()
		c.vars.txt = (dd > 0 and dd < 25 and AN.LangCode() == "da") and LAAGE[dd] or ""
	end,
}
-- "Videre": on to the name (the player's own name) and back to the start board
B[867] = clickSounds({ release = function(p) FL.GotoAndStop(p, "entername") end })
B[900] = clickSounds({ release = function(p) FL.GotoAndStop(p, "entername") end })
B[886] = clickSounds({ release = function() CL.GameBack(false) end })
B[863] = clickSounds({ release = function() CL.GameBack(false) end })
B[914] = clickSounds({ release = function() CL.GameBack(false) end })
B[922] = clickSounds({ release = function() CL.GameBack(false) end })

-- the reward: coins fill up (state 1), the ornament comes when there are enough (state 2)
CL.Script[878] = {
	[1] = function(c)
		local res = CL.lastRes or { won = 0, oldCoins = 0, price = 10 }
		local v = c.vars
		v.state = 0
		v.shown = false
		v.user = res.oldCoins or 0
		v.showing = v.user
		v.added = 0
		v.won = res.won or 0
		v.price = res.price or 10
		v.item = res.item
		v.newPrice = res.newPrice or v.price
		local ra = child(c, "rewardAni", "gfx")
		if ra and res.item then
			ra.extra = nil
			CL.Attach(ra, res.item.id, "item")
		end
		for i = 0, 39 do
			local coin = FL.Child(c, "coin" .. i)
			if coin then
				if i >= v.price then coin.visible = false
				elseif i < v.user then FL.GotoAndStop(coin, "on") end
			end
		end
		v.pause = -20
		v.state = 1
		local p = c.parent
		if p then
			if v.won < 8 then p.vars.txt = AN.L("cl_won_a", v.won)
			elseif v.won < 10 then p.vars.txt = AN.L("cl_won_b", v.won)
			else p.vars.txt = AN.L("cl_won_c", v.won) end
		end
		CL.Explain(c)
		c.onEnter = function(cc) if cc.vars.state == 1 then CL.CoinStep(cc) end end
	end,
}
function CL.Explain(c)
	local v = c.vars
	if c.parent then c.parent.vars.explainTxt = AN.L("cl_won_more", v.price - v.showing) end
end
function CL.CoinStep(c)
	local v = c.vars
	v.pause = v.pause + 1
	if v.pause >= 6 then
		if v.user + v.added >= v.price and not v.shown and v.item then
			v.state = 2
			local ra = FL.Child(c, "rewardAni")
			if ra then FL.GotoAndPlay(ra, "animon") end
		elseif v.added >= v.won then
			v.state = 2
		else
			local coin = FL.Child(c, "coin" .. v.showing)
			if coin then FL.GotoAndStop(coin, "on") end
			CL.Snd("triangel")
			v.showing = v.showing + 1
			v.pause = 0
			v.added = v.added + 1
		end
	end
	CL.Explain(c)
end
-- the star with the new ornament
CL.Script[877] = {
	[1] = function(c) FL.Stop(c) local g = FL.Child(c, "gfx") if g then g.visible = false end end,
	[7] = function(c) local g = FL.Child(c, "gfx") if g then g.visible = true end end,
	[13] = function() AN.Speak("megetgodt") end,
	[74] = function(c) FL.Stop(c) if c.parent then CL.RewardAniDone(c.parent) end end,
}
-- the ornament animation calls this at its end
function CL.RewardAniDone(c)
	local v = c.vars
	v.shown = true
	local ra = FL.Child(c, "rewardAni")
	if ra then FL.GotoAndStop(ra, "off") end
	v.user, v.showing = 0, 0
	v.won = v.won - v.added
	v.added = 0
	v.price = v.newPrice
	for i = 0, 39 do
		local coin = FL.Child(c, "coin" .. i)
		if coin then
			if i >= v.price then coin.visible = false else coin.visible = true FL.GotoAndStop(coin, "off") end
		end
	end
	v.state = 1
end


---------------------------------------------------------------------------
-- The movies loaded into the main screen: pyntekasse.swf (the box with the ornaments, where you
-- decorate the tree) and skattekiste.swf (the scrapbook)
---------------------------------------------------------------------------
CL.movies = CL.movies or {}
function CL.ShowMovie(holderName, lib)
	local h = child(CL.root, holderName)
	if not h then return end
	h.visible = true
	local mv = CL.movies[holderName]
	if not mv or mv.parent ~= h then
		h.extra = nil
		mv = CL.Attach(h, 0, "movie", nil, lib)
		CL.movies[holderName] = mv
	end
	return mv
end
function CL.HideMovie(holderName)
	local h = child(CL.root, holderName)
	if h then h.visible = false end
end

local PK, SK = CL.BL.clpk, CL.BL.clsk
CL.PK = {}
local P = CL.PK
P.MAX = 75

-- the ornaments in the original's order (pynt[]): export names
local function pyntName(i) local d = AN.Ornaments[i + 1] return d and d.id end
local function pyntIndex(id) local d = AN.OrnamentById[id] return d and d.index end

-- everything the player owns: the box plus the tree
function P.Owned()
	local inv = {}
	for i = 0, #AN.Ornaments - 1 do inv[i] = 0 end
	for id, n in pairs(AN.Save.Inv()) do local i = pyntIndex(id) if i then inv[i] = inv[i] + n end end
	for _, o in ipairs(AN.Save.Tree()) do local i = pyntIndex(o.id) if i then inv[i] = inv[i] + 1 end end
	return inv
end

-- modern tree frame <-> the tree clip's own coordinates (the same tree picture)
function P.ToTree(x, y)
	local tx, ty, tw, th = AN.TreeImageRect()
	return -186.2 + (x - tx) * 350 / tw, -187.25 + (y - ty) * 428 / th
end
function P.FromTree(x, y)
	local tx, ty, tw, th = AN.TreeImageRect()
	return tx + (x + 186.2) * tw / 350, ty + (y + 187.25) * th / 428
end

local function noPynt(owned)
	local any = false
	for _, n in pairs(owned) do if n > 0 then any = true end end
	return any and "" or AN.L("cl_pk_none")
end

-- frame 2: off to decorating (from 14 December, like the original) or just looking in the box
CL.ScriptL = CL.ScriptL or {}
CL.ScriptL.clpk = {
	[0] = {
		[1] = function(c) FL.Stop(c) end,
		[2] = function(c)
			FL.Stop(c)
			if AN.UsesDate() and CL.DecemberDate() < 14 then
				AN.Speak("skattekiste_01")
				FL.GotoAndStop(c, "inventory")
			else
				AN.Speak("skattekiste_02")
				FL.GotoAndStop(c, "pynte")
			end
		end,
		[11] = function(c) FL.Stop(c) P.DisplayInventory(c) end,
		[23] = function(c) FL.Stop(c) P.CreatePyntItems(c) end,
	},
	-- the scroll bar of the box
	[117] = { [1] = function(c) end, [2] = function(c) FL.Stop(c) P.ScrollInit(c) end },
	[94] = { [1] = function(c) FL.Stop(c) end },
	[37] = { [1] = function(c) FL.Stop(c) end, [406] = function(c) FL.Stop(c) end },
	[15] = { [34] = function(c) FL.GotoAndPlay(c, 1) end },
}
FL.LoadHidden.clpk = { [121] = true, [143] = true }
CL.ScriptL.clsk = {
	[0] = { [2] = function(c) FL.Stop(c) CL.SK.Init(c) end },
	[10] = { [1] = function(c) FL.Stop(c) end },
	[51] = { [1] = function(c) FL.Stop(c) end },
}
FL.LoadHidden.clsk = { [47] = true }
-- the button (132) that takes the box to decorating shows from Christmas Eve (when the box opened
-- in look-only mode)
CL.ScriptL.clpk[132] = { [1] = function(c) c.visible = not (AN.UsesDate() and CL.DecemberDate() < 24) end }

-- look only: every ornament you own, in rows
function P.DisplayInventory(root)
	local owned = P.Owned()
	root.vars.txt_noPynt = noPynt(owned)
	local holder = FL.Child(root, "invholder")
	if not holder then return end
	holder.extra = nil
	local area = FL.Child(root, "scrollarea1")
	local rowW = 350
	local rowH, spacing = 90, 20
	local row, rowX, n = 0, 0, 0
	for p = 0, #AN.Ornaments - 1 do
		for _ = 1, owned[p] do
			local k = CL.Attach(holder, pyntName(p), "item" .. n)
			FL.Stop(k)
			local x0, _, x1 = FL.Bounds(k, I, true)
			local w = (x0 and (x1 - x0) or 30) + spacing
			if rowX + w > rowW then row = row + 1 rowX = 0 end
			CL.SetXY(k, rowX + w / 2, rowH / 2 + row * rowH)
			rowX = rowX + w
			n = n + 1
		end
	end
end

-- decorating: a box for each kind you own (with how many), the tree as it is saved
function P.CreatePyntItems(root)
	P.root = root
	local owned = P.Owned()
	root.vars.txt_noPynt = noPynt(owned)
	root.vars.txt_info = AN.L("cl_pk_info", P.MAX)
	local holder = FL.Child(root, "invholder")
	if not holder then return end
	holder.extra = nil
	local col, row = 0, 0
	P.items = {}
	for p = 0, #AN.Ornaments - 1 do
		if owned[p] > 0 then
			local k = CL.Attach(holder, 94, "item" .. p, { 1, 0, 0, 1, 17 + 115 * col, 13 + 105 * row })
			k.vars.id = p
			k.vars.amount = owned[p]
			FL.GotoAndStop(k, "on")
			local g = FL.Child(k, "gfx")
			if g then FL.GotoAndStop(g, p + 1) end
			P.items[p] = k
			col = col + 1
			if col >= 3 then row = row + 1 col = 0 end
		end
	end
	-- the tree as it is saved
	local tree = FL.Child(root, "tree")
	if tree then tree.extra = nil end
	P.onTree = 0
	for _, o in ipairs(AN.Save.Tree()) do
		local i = pyntIndex(o.id)
		if i then
			local x, y = P.ToTree(o.x, o.y)
			P.PutOnTree(i, x, y)
		end
	end
end
function P.Amount(i, d)
	local k = P.items and P.items[i]
	if k then k.vars.amount = (k.vars.amount or 0) + d end
end
function P.PutOnTree(i, x, y)
	local tree = FL.Child(P.root, "tree")
	if not tree then return end
	P.Amount(i, -1)
	local k = CL.Attach(tree, pyntName(i), "item" .. i, { 1, 0, 0, 1, x, y })
	FL.Stop(k)
	k.vars.id = i
	P.onTree = P.onTree + 1
	-- an ornament on the tree can be dragged again (and off the tree, back into the box)
	k.mouse = {
		press = function(t) CL.StartDrag(t) end,
		release = function(t) P.ItemReleased(t) end,
		releaseOutside = function(t) P.ItemReleased(t) end,
	}
	if pyntName(i) == "star0" then
		-- the star on top of the others
		local list = tree.extra
		table.insert(list, table.remove(list, #list))
	end
	return k
end
function P.OnTree(k)
	local tree = FL.Child(P.root, "tree")
	local hit = tree and FL.Child(tree, "hitarea")
	if not hit then return false end
	local x, y = CL.GetXY(k)
	local m = CL.RootMatrix(tree)
	local dx, dy = m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6]
	local was = hit.visible
	hit.visible = true
	local ok = FL.HitPoint(hit, TL.Mul(m, ownM(hit)), dx, dy)
	hit.visible = was
	return ok
end
function P.Remove(k)
	local tree = k.parent
	for j, e in ipairs(tree.extra or {}) do
		if e.c == k then table.remove(tree.extra, j) break end
	end
end
function P.ItemReleased(k)
	CL.StopDrag()
	if not P.OnTree(k) then
		P.Amount(k.vars.id, 1)
		P.onTree = P.onTree - 1
		P.Remove(k)
	end
end
-- a box clicked: a new ornament follows the mouse
PK[88] = {
	press = function(p)
		local i = p.vars.id
		if P.onTree >= P.MAX or (p.vars.amount or 0) <= 0 then return end
		local k = P.PutOnTree(i, -1000, 0)
		if k then
			P.dragging = k
			CL.StartDrag(k, true)
		end
	end,
	release = function() P.DragDone() end,
	releaseOutside = function() P.DragDone() end,
}
function P.DragDone()
	local k = P.dragging
	P.dragging = nil
	if k then P.ItemReleased(k) end
end
-- take everything off the tree again
function P.ClearTree()
	local tree = P.root and FL.Child(P.root, "tree")
	if not tree then return end
	for _, e in ipairs(tree.extra or {}) do P.Amount(e.c.vars.id, 1) end
	tree.extra = nil
	P.onTree = 0
end
-- save the tree (the same tree as in the modern look)
function P.Done()
	local tree = P.root and FL.Child(P.root, "tree")
	if not tree then return end
	for i = #AN.Save.Tree(), 1, -1 do AN.Save.RemoveOrnament(i) end
	for _, e in ipairs(tree.extra or {}) do
		local id = pyntName(e.c.vars.id)
		local x, y = P.FromTree(e.m[5], e.m[6])
		if id then AN.Save.PlaceOrnament(id, x, y) end
	end
end
PK[131] = { release = function(p) FL.GotoAndStop(p.parent or p, "pynte") end }
PK[151] = { release = function(p) FL.GotoAndStop(p, "inventory") end }
PK[155] = { release = function() P.ClearTree() end }
PK[156] = { release = function() P.ClearTree() end }
local function closeBox(save)
	return function(p)
		if save then P.Done() end
		CL.MainClick("PYNTEKASSE_CLOSE")
		FL.GotoAndStop(p, 1)
	end
end
PK[127] = clickSounds({ release = closeBox(false) })
PK[137] = clickSounds({ release = closeBox(false) })
PK[146] = clickSounds({ release = closeBox(true) })
PK[153] = clickSounds({ release = closeBox(true) })
PK[157] = clickSounds({ release = closeBox(true) })

-- the scroll bar of the box (a small scroll component of its own)
function P.ScrollInit(sb)
	local root = sb.parent
	local clip, area = FL.Child(root, "invholder"), FL.Child(root, "scrollarea1")
	if not clip or not area then return end
	local _, cy0, _, cy1 = FL.Bounds(clip, I, true)
	local _, ay0, _, ay1 = FL.Bounds(area, I, true)
	local ch, ah = (cy1 or 0) - (cy0 or 0), (ay1 or 0) - (ay0 or 0)
	local _, top = CL.GetXY(area)
	sb.vars.top = top
	sb.vars.bot = -45 + top + (ch - ah) * -1
	local box, slider = FL.Child(sb, "sliderareabox"), FL.Child(sb, "slider")
	local _, by0, _, by1 = box and FL.Bounds(box, I, true)
	local _, sy0, _, sy1 = slider and FL.Bounds(slider, I, true)
	sb.vars.max = ((by1 or 0) - (by0 or 0)) - ((sy1 or 0) - (sy0 or 0))
	if slider then CL.SetXY(slider, 0, 0) end
	local cx = CL.GetXY(clip)
	CL.SetXY(clip, cx, top)
	sb.visible = ch >= ah
end
function P.ScrollTo(sb, y)
	local slider = FL.Child(sb, "slider")
	local max = sb.vars.max or 1
	y = math.Clamp(y, 0, math.max(0, max))
	if slider then local x = CL.GetXY(slider) CL.SetXY(slider, x, y) end
	local clip = FL.Child(sb.parent, "invholder")
	if clip and max > 0 then
		local cx = CL.GetXY(clip)
		CL.SetXY(clip, cx, (sb.vars.bot - sb.vars.top) * (y / max) + sb.vars.top)
	end
end
local function sliderY(sb) local slider = FL.Child(sb, "slider") local _, y = slider and CL.GetXY(slider) return y or 0 end
PK[113] = { press = function(p) P.ScrollTo(p, sliderY(p) - (p.vars.step or 90)) end }
PK[115] = { press = function(p) P.ScrollTo(p, sliderY(p) + (p.vars.step or 90)) end }
PK[107] = { press = function(p)
	local _, my = CL.ToLocal(p, CL.Mouse())
	P.ScrollTo(p, sliderY(p) + (my < sliderY(p) and -90 or 90))
end }
PK[110] = {
	press = function(p)
		local _, my = CL.ToLocal(p, CL.Mouse())
		local off = my - sliderY(p)
		p.onEnter = function(sb)
			local _, y = CL.ToLocal(sb, CL.Mouse())
			P.ScrollTo(sb, y - off)
		end
	end,
	release = function(p) p.onEnter = nil end,
	releaseOutside = function(p) p.onEnter = nil end,
}

-- the scrapbook: 16 pictures from the series, chosen in the list on the right
CL.SK = {}
local SKITEMS = { "Det mig!!", "Os 3 nisser", "Kandis", "Masser af papir", "Gymnastik?!?", "Pyrus og switch",
	"BAD??  Øuuuuuv...", "I arkivet", "Gaaaab...", "Fuld skrue!", "Gyldengrød", "Pyha", "Flere af de der mennesker",
	"Ska hun nu gøre rent igen?", "Gyldengrød læser", "Dagens Julesjov på TV2" }
function CL.SK.Init(root)
	local holder = FL.Child(root, "itemHolder")
	if not holder then return end
	holder.extra = nil
	for _, k in pairs(holder.kids) do k.visible = false end   -- the placeholder line
	for i, label in ipairs(SKITEMS) do
		local k = CL.Attach(holder, 10, "item" .. (i - 1))
		local _, y0, _, y1 = FL.Bounds(k, I, true)
		CL.SetXY(k, 0, ((y1 or 23) - (y0 or 0)) * (i - 1))
		k.vars.id = i - 1
		k.vars.txt_label = AN.LangCode() == "da" and label or AN.L("cl_sk_" .. i)
	end
end
SK[2] = {
	release = function(p)
		local root = p.parent and p.parent.parent
		local content = root and FL.Child(root, "content")
		if content then FL.GotoAndStop(content, p.vars.id + 1) end
	end,
	over = function(p) FL.GotoAndStop(p, "over") end,
	out = function(p) FL.GotoAndStop(p, 1) end,
}
SK[56] = clickSounds({ release = function() CL.MainClick("SKATTEKISTE_CLOSE") end })
SK[75] = { release = function() CL.MainClick("SKATTEKISTE_CLOSE") end }
SK[64] = clickSounds({ release = function() gui.OpenURL("http://teddy.tv2.dk/") end })

---------------------------------------------------------------------------
-- The classic look takes over the main menu, the calendar and the game frame
---------------------------------------------------------------------------
if not CL.uiOpen then CL.uiOpen = UI.Open end
function UI.Open(name, args)
	if name == "gamewrap" and args and (args.n or 0) > 100 then name = "sgame" end
	if CL.Active() then
		if name == "main" or name == "kalender" then
			name = CL.Look() == "tv2" and "tv2" or "classic"
		elseif name == "gamewrap" then
			args = args or {}
			if args.state == "over" then
				CL.GameOver(args.n, args.value, args.res)
			elseif CL.inGame and CL.root then
				-- a game left with its own button: back to its start board
				CL.uiOpen("classic", { keep = true, keepVoice = args.keepVoice })
				CL.cur = args.n or CL.cur
				CL.GameBack(false)
			elseif UI.screenName ~= "classic" then
				CL.uiOpen("classic", { door = args.n })
			else
				CL.StartDoor(args.n)
			end
			return
		end
	end
	return CL.uiOpen(name, args)
end

-- the game's stage in the classic look: the game at its own size in the middle of the grey 800 x 600
if not CL.mgStage then CL.mgStage, CL.mgChrome = MG.Stage, MG.Chrome end
function CL.InGame()
	return CL.Active() and CL.inGame and UI.screenName == "game" .. CL.inGame and CL.root
end
function MG.Stage(sw, sh)
	if not CL.InGame() then return CL.mgStage(sw, sh) end
	CL.Place()
	local k, dx, dy = MG.k, MG.x0, MG.y0
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	AN.Box(dx, dy, DOC_W * k, DOC_H * k, Color(102, 102, 102))
	-- the root's own layers under the game (nothing much on the "playinggame" frame)
	render.SetScissorRect(AN.PX(dx), AN.SY(dy), AN.PX(dx + DOC_W * k), AN.SY(dy + DOC_H * k), true)
	local g = gui()
	if g then g.visible = false end
	FL.Draw(CL.root, I)
	if g then g.visible = true end
	MG.sw, MG.sh = sw, sh
	MG.x0 = dx + (DOC_W - sw) / 2 * k
	MG.y0 = dy + (DOC_H - sh) / 2 * k
	render.SetScissorRect(AN.PX(MG.x0), AN.SY(MG.y0), AN.PX(MG.x0 + sw * k), AN.SY(MG.y0 + sh * k), true)
end
function MG.Chrome(n)
	if not CL.InGame() then return CL.mgChrome(n) end
	local sx0, sy0 = MG.x0, MG.y0
	local sw, sh = MG.sw, MG.sh
	CL.Place()
	render.SetScissorRect(AN.PX(MG.x0), AN.SY(MG.y0), AN.PX(MG.x0 + DOC_W * MG.k), AN.SY(MG.y0 + DOC_H * MG.k), true)
	local g = gui()
	if g then FL.Draw(g, ownM(g)) end
	render.SetScissorRect(0, 0, 0, 0, false)
	-- the hint (a light bulb) beside the 4:3 picture, for games that have one
	local scr = UI.screen
	local k = MG.k
	local right = MG.x0 + DOC_W * k
	if scr and scr.Hint and AN.HintsOn() and AN.VW - right > 120 then
		local hx, hy = right + 24, MG.y0 + 24
		local can = AN.CanHint(n)
		local hot = UI.Button("mg_hint", hx, hy, 82, 82, function() AN.UseHint(n) end, { silent = true })
		local lift = hot and can
		AN.Img("ui/hint.png", hx + (lift and -3 or 0), hy + (lift and -3 or 0), lift and 88 or 82, lift and 88 or 82, can and 255 or 110)
		if AN.HintUsed[n] then AN.HintMark(hx + 74, hy + 8, 10) end
		if hot then AN.TextWrap(can and AN.HintLabel(n) or AN.L("hint_none"), "black", 18, hx, hy + 96, 160, AN.Col.cream, 24) end
	end
	-- (games read MG.x0 / MG.k for the mouse after drawing)
	MG.x0, MG.y0, MG.sw, MG.sh = sx0, sy0, sw, sh
	MG.k = k
end

-- the root keeps playing under the game (the X in the corner, its dialog)
hook.Add("Think", "AN_ClassicGame", function()
	if not CL.InGame() then return end
	CL.gameAcc = (CL.gameAcc or 0) + math.min(FrameTime(), 0.25)
	while CL.gameAcc >= 1 / CL.FPS do
		CL.gameAcc = CL.gameAcc - 1 / CL.FPS
		CL.Step(CL.root)
	end
	local x, y = CL.Mouse()
	CL.Mouse4(CL.st, x, y, input.IsMouseDown(MOUSE_LEFT))
end)

---------------------------------------------------------------------------
-- Running: ticks at 25 fps, onEnterFrame handlers, buttons under the mouse
---------------------------------------------------------------------------
-- one Flash frame of a whole movie: frames, then every clip's onEnterFrame, then the buttons
function CL.Step(root, state)
	FL.Tick(root)
	-- clips made by attachMovie are not in a timeline: they play here
	local list, att = {}, {}
	walk(root, I, true, function(c, M, vis)
		if c.onEnter then list[#list + 1] = c end
		if c.extra then
			for _, e in ipairs(c.extra) do att[#att + 1] = e.c end
		end
	end)
	for _, k in ipairs(att) do FL.Tick(k) end
	for _, c in ipairs(list) do
		if c.onEnter then c.onEnter(c) end
	end
end

-- a clip's place in its parent: _x / _y (for attached clips, their entry in the parent's list)
function CL.SetXY(c, x, y)
	for _, e in ipairs((c.parent and c.parent.extra) or {}) do
		if e.c == c then e.m = { e.m[1], e.m[2], e.m[3], e.m[4], x, y } return end
	end
	setXY(c, x, y)
end
function CL.GetXY(c)
	for _, e in ipairs((c.parent and c.parent.extra) or {}) do
		if e.c == c then return e.m[5], e.m[6] end
	end
	local m = ownM(c)
	return m[5], m[6]
end
-- a document point in a clip's own coordinates
function CL.ToLocal(c, x, y)
	local m = CL.RootMatrix(c)
	local det = m[1] * m[4] - m[2] * m[3]
	if math.abs(det) < 1e-9 then return 0, 0 end
	x, y = x - m[5], y - m[6]
	return (m[4] * x - m[3] * y) / det, (-m[2] * x + m[1] * y) / det
end
-- startDrag: the clip follows the mouse (lock = its centre on the mouse)
function CL.StartDrag(c, lock)
	local mx, my = CL.Mouse()
	local px, py = CL.ToLocal(c.parent, mx, my)
	local x, y = CL.GetXY(c)
	CL.drag = { c = c, dx = lock and 0 or x - px, dy = lock and 0 or y - py }
	CL.DragUpdate()
end
function CL.StopDrag() CL.drag = nil end
function CL.DragUpdate()
	local d = CL.drag
	if not d or not d.c.parent then return end
	local mx, my = CL.Mouse()
	local px, py = CL.ToLocal(d.c.parent, mx, my)
	CL.SetXY(d.c, px + d.dx, py + d.dy)
end

-- the topmost button under the mouse (with a script), its matrix
function CL.ButtonAt(root, x, y)
	local found, fm
	walk(root, I, true, function(c, M, vis)
		if vis and c.visible and ((c.kind == "btn" and BH(c)) or c.mouse) and FL.HitPoint(c, M, x, y) then
			found, fm = c, M
		end
	end)
	return found, fm
end

-- rollOver / rollOut, press / release like Flash buttons
-- the handlers of a button (its script, "this" = the timeline it is on) or of a clip with its own
-- onPress / onRelease (c.mouse, "this" = the clip)
local function H(b)
	if b.mouse then return b.mouse, b end
	return BH(b) or {}, b.parent
end
function CL.Mouse4(st, x, y, down)
	CL.DragUpdate()
	local b = (x and st.root) and CL.ButtonAt(st.root, x, y) or nil
	if b ~= st.hot then
		local old = st.hot
		st.hot = b
		if old then local h, t = H(old) if h.out then h.out(t, old) end end
		if b then local h, t = H(b) if h.over then h.over(t, b) end end
	end
	if down and not st.down then
		st.down = true
		st.pressed = b
		if b then local h, t = H(b) if h.press then h.press(t, b) end end
	elseif not down and st.down then
		st.down = false
		local p = st.pressed
		st.pressed = nil
		if p then
			local h, t = H(p)
			if p == b then
				if h.release then h.release(t, p) end
			elseif h.releaseOutside then
				h.releaseOutside(t, p)
			end
		end
	end
	-- the hand over buttons (only when that changes: some games hide the cursor themselves)
	local hand = b ~= nil
	if hand ~= st.hand then
		st.hand = hand
		if IsValid(UI.root) then UI.root:SetCursor(hand and "hand" or "arrow") end
		if not hand and UI.screen and UI.screen.cursorShown ~= nil then UI.screen.cursorShown = nil end
	end
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------
local S = AN.Screens.classic or {}
AN.Screens.classic = S
S.garland = false

function S:Open(args)
	self.acc = 0
	if args.keep and CL.root then
		self.root = CL.root
		CL.st.down = input.IsMouseDown(MOUSE_LEFT)
		return
	end
	CL.SetupActions()
	CL.doors = {}
	CL.cur, CL.inGame = nil, nil
	CL.st = { down = input.IsMouseDown(MOUSE_LEFT) }
	self.root = FL.New(LIB, 0)
	CL.root = self.root
	CL.st.root = self.root
	FL.GotoAndStop(self.root, "loaddone")
	FL.GotoAndStop(self.root, 12)
	CL.UpdateMute()
	-- from the jul.tv2.dk calendar: the decoration box or the scrapbook by itself
	if args.movie == "pynt" then CL.MainClick("PYNTEKASSE") end
	if args.movie == "skat" then CL.MainClick("SCRAPBOG") end
	if args.door then
		CL.StartDoor(args.door)
		-- from the jul.tv2.dk calendar: straight to the start board (Pyrus walks in over the loft)
		if args.direct then CL.IntroDone() end
	end
end

function S:Close()
	if IsValid(UI.root) then UI.root:SetCursor("arrow") end
	CL.Opt.open = false
end

function S:Think(dt)
	if not self.root then return end
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= 1 / CL.FPS do
		self.acc = self.acc - 1 / CL.FPS
		CL.Step(self.root)
		CL.Opt.Tick()
	end
	local x, y = CL.Mouse()
	if CL.Opt.IsOpen() then x, y = nil, nil end
	CL.Mouse4(CL.st, x, y, input.IsMouseDown(MOUSE_LEFT))
end

function S:Paint()
	MG.ClassicStage()
	FL.Draw(self.root, I)
	-- the start board: Kapløb and Duel under Start and Hjælp
	local g = child(self.root, "ingameGUI")
	if g and g.frame >= 23 and g.frame < 41 and CL.cur and AN.VS then
		AN.VS.BoardButtons(CL.cur, MG.x0 + 28 * MG.k, MG.y0 + 540 * MG.k, MG.k * 0.62)
	end
	CL.Opt.Draw(0, 0)
	MG.ClassicEnd()
end
