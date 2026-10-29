-- Julekalender: the selected door on the left, the 24 doors on the right.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.kalender = S

function S:Open(args)
	self.sel = args.door or AN.CurrentDoor() or 1
	self.how = false
end

local function drawGameTitle(n, x, y, maxw, maxh, size)
	if AN.LangCode() == "da" then
		AN.ImgFit(string.format("titles/%02d.png", n), x, y, maxw, maxh)
	else
		AN.TextFit(AN.GameName(n), "title", size, x, y + maxh / 2 + 6, maxw, AN.Col.shadow, 0, 1)
		AN.TextFit(AN.GameName(n), "title", size, x, y + maxh / 2, maxw, AN.Col.white, 0, 1)
	end
end
AN.DrawGameTitle = drawGameTitle

function S:Paint()
	local R = AN.R
	UI.Background("sub")
	UI.Shade("sub")
	UI.BackButton("main")

	local n = self.sel
	local g = AN.Games[n]
	local state, reason, rn = AN.DoorState(n)

	-- left: the selected door
	local x, y = 110, 160
	local head
	if AN.UsesDate() and n == AN.Today() then
		head = AN.L("cal_date", AN.Today(), n)
	else
		head = AN.L("cal_door", n)
	end
	AN.Text(head, "black", 22, x, y, C.gold)

	-- the game title (Danish: the original drawn logo; English: the name in the same font)
	if AN.LangCode() == "da" then
		local mh = 200
		local r = AN.Ratio(string.format("titles/%02d.png", n))
		local w = math.min(470, mh / r)
		AN.Img(string.format("titles/%02d.png", n), x - 10, y + 40, w)
		y = y + 40 + w * r + 14
	else
		AN.TextFit(AN.GameName(n), "title", 88, x, y + 46 + 6, 600, C.shadow)
		AN.TextFit(AN.GameName(n), "title", 88, x, y + 46, 600, C.white)
		y = y + 46 + 110
	end

	local body
	if state == "locked" then
		body = AN.L("cal_locked") .. " " .. AN.L(reason, rn)
	elseif not g.made then
		body = AN.L("cal_not_made")
	elseif self.how then
		body = AN.L(g.howKey or "cal_not_made")
	else
		body = AN.L(g.descKey or "cal_not_made")
	end
	y = y + AN.TextWrap(body, "bold", 24, x, y, 600, C.wheat, 35)

	-- stats
	y = y + 24
	local door = AN.Save.Door(n)
	local bw = (600 - 14) / 2
	AN.Box(x, y, bw, 92, Color(255, 241, 207, 20), 16)
	AN.Text(g.scoreType == "time" and AN.L("cal_best") or AN.L("cal_best_score"), "bold", 17, x + 20, y + 16, C.sand)
	AN.Text(door and door.best and AN.FormatValue(n, door.best) or "—", "black", 34, x + 20, y + 40, C.white)
	AN.Box(x + bw + 14, y, bw, 92, Color(255, 241, 207, 20), 16)
	AN.Text(AN.L("cal_goal"), "bold", 17, x + bw + 34, y + 16, C.sand)
	AN.Text(g.made and AN.FormatValue(n, g.goal) or "—", "black", 34, x + bw + 34, y + 40, C.gold)
	y = y + 92 + 30

	local canPlay = g.made and state ~= "locked"
	UI.RedButton("play", AN.L("play"), x, y, 300, 84, 44, function() AN.StartGame(n) end, not canPlay)
	if g.made then
		UI.GhostButton("how", AN.L("cal_how"), x + 314, y, 286, 84, function() self.how = not self.how end)
	end
	y = y + 84 + 18
	local vw = AN.Text(AN.L("cal_versus") .. " ", "black", 20, x, y, C.sand)
	local others = math.max(0, player.GetCount() - 1)
	AN.Text(others > 0 and AN.L("cal_versus_n", others + 1) or AN.L("cal_versus_off"), "black", 20, x + vw, y, C.cream)

	-- right: heading + doors
	local gx, gy = 860 + AN.C, 150
	AN.Text(AN.L("cal_title"), "title", 56, gx, gy, C.white)
	local done = AN.Save.DoneCount()
	local days = AN.DaysToEve()
	local prog = days > 0 and AN.L("cal_progress", done, days) or AN.L("cal_progress_eve", done)
	AN.Text(prog, "black", 22, gx + 960, gy + 30, C.gold, 2)

	local cw, ch, gap = (960 - 5 * 14) / 6, 128, 14
	local top = gy + 92
	for i = 1, 24 do
		local cx = gx + ((i - 1) % 6) * (cw + gap)
		local cy = top + math.floor((i - 1) / 6) * (ch + gap)
		local st = AN.DoorState(i)
		local sel = i == self.sel
		local hot = UI.Button("door" .. i, cx, cy, cw, ch, function() self:DoorClicked(i) end)
		self:DrawDoor(i, st, cx, cy, cw, ch, hot)
		if sel and st ~= "today" then
			AN.Outline(cx - 3, cy - 3, cw + 6, ch + 6, C.gold, 19, 3)
		end
	end

	if not AN.UsesDate() and AN.Save.Get("doorRule") ~= "progress" then
		AN.TextWrap(AN.L("cal_offseason"), "bold", 19, gx, top + 4 * (ch + gap) + 10, 960, C.sand, 26)
	end

	UI.CornerButtons()
end


---------------------------------------------------------------------------
-- The doors, like the original calendar: each door swings open on its hinge
-- and shows what is behind it (the game's artwork, or a photo from the series
-- once the game is completed). Doors you have opened stay open.
---------------------------------------------------------------------------
local OPEN_TIME = 0.55
local OPEN_ANGLE = 96

function S:DoorClicked(i)
	local st = AN.DoorState(i)
	if st == "locked" then
		AN.Speak("julekalender_forkert")
		self.shake = self.shake or {}
		self.shake[i] = RealTime()
		self.sel = i
		self.how = false
		return
	end
	self.anim = self.anim or {}
	if AN.Save.Opened(i) and self.sel ~= i then
		-- an open door that isn't chosen: choose it (and leave it open), ready to play
		AN.SpeakChain({ AN.GameSlug[i] .. "_intro", "help_" .. AN.GameSlug[i] })
		self.sel = i
		self.how = false
		return
	end
	if AN.Save.Opened(i) then
		-- the chosen door, clicked again: it closes, like in the original
		AN.Save.SetOpened(i, false)
		self.anim[i] = { t = RealTime(), closing = true }
		AN.Sound("flap")
		return
	end
	AN.Save.SetOpened(i)
	self.anim[i] = { t = RealTime() }
	AN.Sound("flap")
	if self.sel ~= i or not AN.VoiceBusy() then
		local slug = AN.GameSlug[i]
		AN.SpeakChain({ slug .. "_intro", "help_" .. slug })
	end
	self.sel = i
	self.how = false
end

-- what is behind door i
local function behind(i, st, x, y, w, h)
	AN.Box(x, y, w, h, Color(42, 16, 4), 16)
	if st == "done" then
		local p = string.format("stills/%02d.jpg", (i - 1) % 15 + 1)
		AN.ImgCover(p, x + 4, y + 4, w - 8, h - 8)
	else
		AN.ImgFit(string.format("wrap/logo%02d.png", i), x + 6, y + 6, w - 12, h - 12)
	end
	AN.Outline(x, y, w, h, Color(20, 8, 2, 200), 16, 3)
end

-- the closed door's face
local function face(i, st, x, y, w, h, hot)
	if st == "today" then
		AN.Box(x, y, w, h, Color(176, 24, 34), 16)
		AN.BoxEx(x, y, w, h / 2, Color(212, 42, 53), 16, true, true, false, false)
		AN.Text(tostring(i), "title", 56, x + w / 2, y + h / 2 - 10, C.white, 1, 1)
		AN.Text(AN.L("cal_today"), "black", 14, x + w / 2, y + h - 26, C.gold, 1)
	elseif st == "locked" then
		AN.Box(x, y, w, h, Color(20, 8, 2, 140), 16)
		AN.Outline(x, y, w, h, Color(255, 226, 170, hot and 110 or 56), 16, 2)
		AN.Text(tostring(i), "title", 50, x + w / 2, y + h / 2, Color(255, 226, 170, 115), 1, 1)
	else
		AN.Box(x, y, w, h, Color(20, 8, 2, 120), 16)
		AN.Box(x, y, w, h, Color(255, 241, 207, hot and 40 or 26), 16)
		AN.Outline(x, y, w, h, Color(255, 241, 207, hot and 90 or 41), 16, 2)
		AN.Text(tostring(i), "title", 52, x + w / 2, y + h / 2, C.cream, 1, 1)
	end
end

local function quad(pts, col)
	draw.NoTexture()
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local poly = {}
	for _, p in ipairs(pts) do poly[#poly + 1] = { x = AN.PX(p[1]), y = AN.SY(p[2]) } end
	surface.DrawPoly(poly)
end

-- the swinging door: a rounded rectangle (same corners as the other doors) bent into the
-- perspective of a door turning on its left hinge. fw = how wide it looks now (negative =
-- folded out to the left), grow = how much taller its free edge looks.
local function roundedDoor(cx, cy, cw, ch, fw, grow, col)
	local r = 16
	-- keep the corners round on screen however narrow the door looks while turning
	local ru = math.min(0.5, r / math.max(1, math.abs(fw)))
	local pts = {}
	local function corner(u0, v0, a0)
		for s = 0, 6 do
			local a = math.rad(a0 + s * 15)
			pts[#pts + 1] = { u0 + math.cos(a) * ru, v0 + math.sin(a) * r }
		end
	end
	-- clockwise in door space: top-left, top-right, bottom-right, bottom-left
	corner(ru, r, 180)
	corner(1 - ru, r, 270)
	corner(1 - ru, ch - r, 0)
	corner(ru, ch - r, 90)
	local out = {}
	for _, p in ipairs(pts) do
		local u, v = p[1], p[2]
		local top = cy - u * grow
		local bot = cy + ch + u * grow
		out[#out + 1] = { cx + u * fw, top + (bot - top) * (v / ch) }
	end
	if fw < 0 then
		local rev = {}
		for j = #out, 1, -1 do rev[#rev + 1] = out[j] end
		out = rev
	end
	quad(out, col)
end

function S:DrawDoor(i, st, cx, cy, cw, ch, hot)
	-- locked doors shake when you try them
	local sh = self.shake and self.shake[i]
	if sh and RealTime() - sh < 0.4 then
		cx = cx + math.sin((RealTime() - sh) * 60) * 5 * (1 - (RealTime() - sh) / 0.4)
	end
	if st == "today" then
		AN.Glow(cx + cw / 2, cy + ch / 2, cw * 0.75, C.gold, 0.9)
		AN.Box(cx - 4, cy - 4, cw + 8, ch + 8, C.gold, 19)
	end
	local an = self.anim and self.anim[i]
	local running = an and RealTime() - an.t < OPEN_TIME
	local opened = (AN.Save.Opened(i) or (running and an.closing)) and st ~= "locked"
	if not opened then
		face(i, st, cx, cy, cw, ch, hot)
		return
	end
	behind(i, st, cx, cy, cw, ch)
	-- the door itself, swung open on its left hinge (or swinging shut again)
	local k = an and math.Clamp((RealTime() - an.t) / OPEN_TIME, 0, 1) or 1
	k = 1 - (1 - k) * (1 - k)
	if an and an.closing then k = 1 - k end
	local a = math.rad(OPEN_ANGLE * k)
	local fw = cw * math.cos(a)
	local grow = ch * 0.14 * math.sin(a)       -- the free edge comes towards you
	if fw > 2 then
		-- front of the door, still facing us
		local col = st == "today" and Color(190, 30, 40) or Color(74, 50, 38)
		roundedDoor(cx, cy, cw, ch, fw, grow, col)
		if fw > cw * 0.55 then
			AN.Text(tostring(i), "title", math.floor(52 * fw / cw), cx + fw / 2, cy + ch / 2, C.cream, 1, 1)
		end
	else
		-- past halfway: we see the back of the door, folded out to the left
		roundedDoor(cx, cy, cw, ch, math.min(fw, -2), grow, st == "today" and Color(120, 16, 24) or Color(52, 34, 24))
	end
	-- number badge on the open door (not while the door still covers it)
	if fw < cw * 0.2 then
		AN.Box(cx + 6, cy + 6, 30, 24, Color(20, 8, 2, 200), 8)
		AN.Text(tostring(i), "black", 16, cx + 21, cy + 9, C.cream, 1)
	end
	local d = AN.Save.Door(i)
	if st == "done" and d and AN.Games[i].made and d.best then
		local txt = tostring(AN.CoinsFor(i, d.best))
		local tw = AN.TextSize(txt, "black", 15) + 30
		AN.Box(cx + cw - tw - 6, cy + ch - 30, tw, 24, Color(20, 8, 2, 200), 8)
		AN.Img("wrap/coin_on.png", cx + cw - tw + 0, cy + ch - 27, 20, 17)
		AN.Text(txt, "black", 15, cx + cw - 12, cy + ch - 27, C.gold, 2)
	end
end
