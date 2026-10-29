-- Shared helpers for the minigames.
-- Each original game had a fixed Flash stage (e.g. 770 x 440). We keep the game's own
-- coordinates and scale the stage to fill the screen height, centred. Anything outside
-- the stage (ultrawide sides) shows the blurred loft.
AN = AN or {}
AN.MG = AN.MG or {}
local MG = AN.MG
local C = AN.Col

-- The game screen (design A): a wooden header bar with the game's logo, door and the
-- sound / close buttons, the game itself in a wooden frame at its original shape, and a
-- paper panel on the right with how to play, the highscores and the next ornament.
-- The game's own picture is clipped to its frame, so the original artwork never shows a
-- cut edge, whatever the screen shape. Everything is placed from the screen's centre.
local PANEL_W, GAP, PAD = 470, 36, 22
local L = {}
MG.Layout = L

local function wood(x, y, w, h)
	AN.ImgCover("ui/woodboard.png", x, y, w, h)
	AN.Outline(x, y, w, h, Color(60, 20, 4, 170), 0, 3)
end

function MG.SideGarland() AN.Deco.SideGarland() end

-- set up the stage for this frame and draw everything around it. sw, sh = original stage size
function MG.Stage(sw, sh)
	MG.sw, MG.sh = sw, sh
	if AN.UI.screen and (AN.UI.screen.n or 0) > 100 and AN.Summer then return AN.Summer.Stage(sw, sh) end
	-- (from the screen's name: a game may use its own "n" for something else, like door 14's board size)
	local n = tonumber(string.match(AN.UI.screenName or "", "^game(%d+)$") or "") or (AN.UI.screen and AN.UI.screen.n) or 1
	local VW = AN.VW
	local top, bottom = 172, 1046
	local withPanel = VW >= 1500
	local fh = bottom - top
	local sH = fh - 2 * PAD
	local sW = sH * sw / sh
	local maxw = VW - 80 - (withPanel and (PANEL_W + GAP) or 0)
	if sW + 2 * PAD > maxw then sW = maxw - 2 * PAD; sH = sW * sh / sw end
	local group = sW + 2 * PAD + (withPanel and (GAP + PANEL_W) or 0)
	local gx = (VW - group) / 2
	local fy = top + (fh - (sH + 2 * PAD)) / 2
	L.n, L.gx, L.group, L.fy, L.sW, L.sH, L.withPanel = n, gx, group, fy, sW, sH, withPanel
	L.px = gx + sW + 2 * PAD + GAP

	MG.k = sW / sw
	MG.x0 = gx + PAD
	MG.y0 = fy + PAD

	-- room behind, darkened
	AN.UI.Background("sub")
	AN.Box(0, -(AN.OY or 0), VW, AN.VH or 1080, Color(20, 8, 2, 120))

	-- header bar
	wood(gx, 34, group, 110)
	if AN.LangCode() == "da" then
		AN.ImgFit(string.format("titles/%02d.png", n), gx + 22, 40, 220, 98)
	else
		AN.TextFit(AN.GameName(n), "title", 44, gx + 132, 89 + 3, 220, C.shadow, 1, 1)
		AN.TextFit(AN.GameName(n), "title", 44, gx + 132, 89, 220, C.white, 1, 1)
	end
	AN.Text(AN.L("cal_door", n) .. "  ·  " .. AN.Upper(AN.GameName(n)), "black", 20, gx + 262, 60, C.gold)
	local g = AN.UI.screen
	local status = g and g.Status and g:Status() or AN.L("desc_" .. string.format("%02d", n))
	AN.TextFit(status, "bold", 22, gx + 262, 90, math.max(200, (gx + group / 2 - 150) - (gx + 262)), C.cream)

	-- frame
	wood(gx, fy, sW + 2 * PAD, sH + 2 * PAD)
	AN.Box(gx + PAD - 4, fy + PAD - 4, sW + 8, sH + 8, Color(74, 31, 7))

	if withPanel then MG.Panel(n, L.px, fy, PANEL_W, sH + 2 * PAD) end

	-- the game draws itself inside its frame only
	AN.Box(MG.x0, MG.y0, sW, sH, Color(0, 0, 0))
	render.SetScissorRect(AN.PX(MG.x0), AN.SY(MG.y0), AN.PX(MG.x0 + sW), AN.SY(MG.y0 + sH), true)
end

-- the paper panel next to the game
function MG.Panel(n, x, y, w, h)
	local INK = Color(59, 26, 8)
	local RED = Color(138, 42, 10)
	AN.Box(x + 4, y + 14, w, h, Color(0, 0, 0, 90), 22)
	AN.Box(x, y, w, h, Color(248, 234, 208), 22)
	AN.Outline(x, y, w, h, Color(226, 201, 155), 22, 3)
	local cx, cy, cw = x + 26, y + 24, w - 52
	AN.Text(AN.L("mg_howto"), "title", 32, cx, cy, RED)
	cy = cy + 52
	cy = cy + AN.TextWrap(AN.L("how_" .. string.format("%02d", n)), "bold", 18, cx, cy, cw, INK, 25) + 12
	local keys = AN.Lang[AN.LangCode()]["keys_" .. string.format("%02d", n)] or AN.Lang.da["keys_" .. string.format("%02d", n)] or {}
	if AN.HintsOn() and AN.UI.screen and AN.UI.screen.Hint then
		keys = table.Copy(keys)
		local g = AN.Games[n]
		keys[#keys + 1] = { "H", AN.L(g and g.scoreType == "time" and "hint_key_time" or "hint_key") }
	end
	for _, kv in ipairs(keys) do
		local kw = AN.TextSize(kv[1], "black", 16) + 18
		AN.Box(cx, cy, kw, 28, INK, 6)
		AN.Text(kv[1], "black", 16, cx + 9, cy + 4, C.cream)
		AN.Text(kv[2], "bold", 17, cx + kw + 10, cy + 4, INK)
		cy = cy + 36
	end
	-- a free tip (just advice: no cost, no mark)
	local tip = AN.Lang[AN.LangCode()]["tip_" .. string.format("%02d", n)]
	if tip then
		cy = cy + 2
		local tw = AN.TextSize(AN.L("mg_tip"), "black", 18)
		AN.Text(AN.L("mg_tip"), "black", 18, cx, cy, RED)
		cy = cy + AN.TextWrap(tip, "bold", 17, cx, cy + 26, cw, INK, 23) + 34
	end
	cy = cy + 6
	for dx = 0, cw - 8, 14 do AN.Box(cx + dx, cy, 8, 2, Color(216, 185, 138)) end
	cy = cy + 16

	-- highscores (everyone on this server)
	AN.Text(AN.L("wrap_hiscore"), "title", 28, cx, cy, RED)
	cy = cy + 46
	local level, th = AN.ScoreTabs(n, cx, cy, cw, 1, INK, "mg_tab")
	cy = cy + th
	local list = AN.Save.Scores(n, level)
	local me = AN.Save.MySid()
	local rowsRoom = math.floor((y + h - 120 - cy) / 44)
	if #list == 0 then
		cy = cy + AN.TextWrap(AN.L("wrap_noscores"), "bold", 17, cx, cy, cw, INK, 24)
	end
	for i = 1, math.min(#list, 5, rowsRoom) do
		local e = list[i]
		local mine = e.sid == me
		AN.Box(cx, cy, cw, 38, mine and C.gold or Color(59, 26, 8, 18), 10)
		AN.Text(tostring(i), "black", 18, cx + 14, cy + 8, Color(138, 58, 16))
		local vs = AN.FormatValue(n, e.v)
		AN.Text(vs, "black", 18, cx + 50, cy + 8, INK)
		local vx = cx + 50 + AN.TextSize(vs, "black", 18)
		if e.h then AN.HintMark(vx + 14, cy + 19, 10) end
		local nx = vx + (e.h and 32 or 14)
		AN.TextEllipsis(e.name or "?", "bold", 17, cx + cw - 14, cy + 9, cx + cw - 14 - nx, Color(122, 90, 58), 2)
		cy = cy + 44
	end

	-- the next ornament and the pebernødder towards it
	local nxt = AN.Save.NextReward()
	local coins = AN.Save.Coins()
	local by = y + h - 104
	AN.Box(cx - 6, by, cw + 12, 86, Color(59, 26, 8, 20), 14)
	AN.ImgFit(nxt.img, cx + 4, by + 10, 40, 66)
	AN.Text(AN.L("box_next"), "black", 18, cx + 58, by + 12, INK)
	local nuts = math.min(nxt.price, 20)
	for i = 0, nuts - 1 do
		AN.Img("wrap/coin_on.png", cx + 58 + (i % 10) * 26, by + 40 + math.floor(i / 10) * 20, 24, 20, i < coins and 255 or 70)
	end
	AN.Text(coins .. "/" .. nxt.price, "black", 22, cx + cw, by + 30, Color(138, 58, 16), 2)
end

-- after the game has drawn: stop clipping, then the decorations and the buttons on top
function MG.Chrome(n)
	render.SetScissorRect(0, 0, 0, 0, false)
	if (n or 0) > 100 and AN.Summer then return AN.Summer.Chrome(n) end
	local gx, group, fy = L.gx, L.group, L.fy
	local VW = AN.VW
	-- garland over the middle of the header, ornaments wound onto its twigs, hanging in the gap above the frame
	local D = AN.Deco
	local mx = gx + group / 2 - 120
	local maxBottom = fy - 8
	-- (the plain branch: the bauble branch has baubles painted on that would hang over the game)
	local t = D.Branch("ui/br_plain.png", mx, -36, 420)
	D.HangAt(t, 1, 70, "kugle5", 30, maxBottom)
	D.HangAt(t, 3, 50, "kugle1", 30, maxBottom)
	t = D.Branch("ui/br_plain.png", mx + 380, -10, 330, true)
	D.HangAt(t, 2, 60, "star0", 44, maxBottom)
	D.HangAt(t, 4, 40, "kugle4", 30, maxBottom)
	if L.withPanel then
		t = D.Branch("ui/br_plain.png", L.px + PANEL_W - 250, fy - 92, 330)
		D.HangAt(t, 4, 12, "hjerte0", 40)
	end
	D.Branch("ui/br_plain.png", gx - 120, 1080 - 70, 420)
	if VW > 2200 then MG.SideGarland() end

	-- sound + close (back to the game's start board)
	local bx = gx + group - 196
	local mode = AN.SoundMode()
	local hotL = AN.UI.Button("mg_sound", bx, 48, 82, 82, function() AN.CycleSoundMode() end)
	AN.Img("ui/lyd.png", bx + (hotL and -3 or 0), 48 + (hotL and -3 or 0), hotL and 88 or 82, hotL and 88 or 82, mode == 2 and 120 or 255)
	if mode > 0 then
		surface.SetDrawColor(mode == 2 and Color(200, 32, 45) or Color(255, 215, 106))
		local a, b = AN.PX(bx + 14), AN.SY(48 + 68)
		local c, d = AN.PX(bx + 68), AN.SY(48 + 14)
		for o = -2, 2 do surface.DrawLine(a + o, b, c + o, d) end
	end
	if hotL then
		local tip = mode == 0 and AN.L("snd_all") or (mode == 1 and AN.L("snd_nomusic") or AN.L("snd_mute"))
		AN.Text(tip, "black", 18, bx + 41, 150, C.cream, 1)
	end
	-- the hint button (a light bulb), for games that have a hint
	local g = AN.UI.screen
	if g and g.Hint and AN.HintsOn() then
		local hx = bx - 92
		local can = AN.CanHint(n)
		local hotH = AN.UI.Button("mg_hint", hx, 48, 82, 82, function() AN.UseHint(n) end, { silent = true })
		local lift = hotH and can
		AN.Img("ui/hint.png", hx + (lift and -3 or 0), 48 + (lift and -3 or 0), lift and 88 or 82, lift and 88 or 82, can and 255 or 110)
		if AN.HintUsed[n] then AN.HintMark(hx + 74, 56, 10) end
		if hotH then
			AN.Text(can and AN.HintLabel(n) or AN.L("hint_none"), "black", 18, hx + 41, 150, C.cream, 1)
		end
	end
	local qx = bx + 92
	local hotQ = AN.UI.Button("mg_quit", qx, 48, 82, 82, function()
		-- levels already done (and saved): the run ends with their score, pebernødder and all
		local run = AN.CurRun and AN.CurRun[n]
		local scr = AN.UI.screen
		if run and run.total and scr and not scr.finished then
			scr.finished = true
			if scr.StopLoops then scr:StopLoops() end
			AN.FinishGame(n, run.total)
			return
		end
		AN.UI.Open("gamewrap", { n = n, state = "start", quiet = true })
	end,
		{ voice = { "luk_rollover", 45 / 25 } })
	AN.Img("ui/luk.png", qx + (hotQ and -3 or 0), 48 + (hotQ and -3 or 0), hotQ and 88 or 82, hotQ and 88 or 82)
end

function MG.X(x) return MG.x0 + x * MG.k end
function MG.Y(y) return MG.y0 + y * MG.k end
function MG.S(v) return v * MG.k end

-- mouse in stage coordinates
function MG.Mouse()
	return (AN.UI.mx - MG.x0) / MG.k, (AN.UI.my - MG.y0) / MG.k
end

-- draw an image placed in stage coordinates
function MG.Img(path, x, y, w, h, alpha)
	AN.Img(path, MG.X(x), MG.Y(y), MG.S(w), h and MG.S(h) or nil, alpha)
end

-- The game's own background, placed in stage coordinates, and continued out to the
-- screen edges on wider screens by stretching its outermost pixel columns/rows
-- (no blur, no loft: the game's own wood/wall just continues).
function MG.Backdrop(path, x, y, w, h)
	local m = AN.Mat(path)
	local sx, sy = AN.PX(MG.X(x)), AN.SY(MG.Y(y))
	local sw, sh = AN.SX(MG.S(w)), AN.SX(MG.S(h))
	local SW, SH = ScrW(), ScrH()
	local e = 2 / math.max(1, m:Width())       -- two source pixels
	local ev = 2 / math.max(1, m:Height())
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(m)
	surface.DrawTexturedRect(sx, sy, sw, sh)
	if sx > 0 then surface.DrawTexturedRectUV(0, sy, sx + 1, sh, 0, 0, e, 1) end
	if sx + sw < SW then surface.DrawTexturedRectUV(sx + sw - 1, sy, SW - sx - sw + 1, sh, 1 - e, 0, 1, 1) end
	if sy > 0 then surface.DrawTexturedRectUV(0, 0, SW, sy + 1, 0, 0, 1, ev) end
	if sy + sh < SH then surface.DrawTexturedRectUV(0, sy + sh - 1, SW, SH - sy - sh + 1, 0, 1 - ev, 1, 1) end
end

-- floating score text ("+40", "-6") that rises and fades
MG.pops = {}
function MG.ResetPops() MG.pops = {} end
function MG.Pop(text, good, x, y)
	MG.pops[#MG.pops + 1] = { text = text, good = good, x = x, y = y, t0 = RealTime() }
end
function MG.DrawPops()
	local now = RealTime()
	for i = #MG.pops, 1, -1 do
		local p = MG.pops[i]
		local t = (now - p.t0) / 1.3
		if t >= 1 then
			table.remove(MG.pops, i)
		else
			local a = 255 * math.min(1, (1 - t) * 2.5)
			local y = p.y - 40 * t
			local col = p.good and Color(255, 236, 120) or Color(255, 110, 90)
			local size = math.floor(MG.S(16) + 0.5)
			AN.Text(p.text, "title", size, MG.X(p.x) + 3, MG.Y(y) + 3, Color(40, 12, 2), 1, 1, a)
			AN.Text(p.text, "title", size, MG.X(p.x), MG.Y(y), col, 1, 1, a)
		end
	end
end

-- game sound from sound/alletidersnisse/<folder>/<name>.mp3
function MG.Sound(folder, name, vol)
	local v = (AN.Save.Get("vol_fx") or 85) / 100 * (vol or 1)
	if v <= 0 or AN.SoundMode() == 2 then return end
	sound.PlayFile("sound/alletidersnisse/" .. folder .. "/" .. name .. ".mp3", "noplay", function(ch)
		if IsValid(ch) then ch:SetVolume(v) ch:Play() end
	end)
end

-- H uses a hint in the game being played
local hWas = false
hook.Add("Think", "AN_HintKey", function()
	local down = input.IsKeyDown(KEY_H)
	if down and not hWas then
		local scr = AN.UI.screen
		local name = AN.UI.screenName or ""
		local n = tonumber(string.match(name, "^game(%d+)$") or "")
		if n and scr and scr.Hint and AN.HintsOn() and not vgui.GetKeyboardFocus() then AN.UseHint(n) end
	end
	hWas = down
end)

---------------------------------------------------------------------------
-- drawing for hints, in stage coordinates (so they scale with the game): a pulsing ring, an
-- arrow, a highlighted box, a label. Each has a dark edge so it shows on any background.
---------------------------------------------------------------------------
MG.HINT_GOLD = Color(255, 214, 64)
MG.HINT_GOOD = Color(70, 220, 90)
MG.HINT_BAD = Color(235, 50, 50)
local DARK = Color(40, 12, 2)

local function poly(pts, col, a)
	local p = {}
	for i, v in ipairs(pts) do p[i] = { x = AN.PX(MG.X(v[1])), y = AN.SY(MG.Y(v[2])) } end
	draw.NoTexture()
	surface.SetDrawColor(col.r, col.g, col.b, (col.a or 255) * (a or 1))
	surface.DrawPoly(p)
end
function MG.HintPulse() return 0.75 + 0.25 * math.sin(RealTime() * 8) end

-- a thick ring around (x, y)
function MG.HintRing(x, y, r, col, a, thick)
	col = col or MG.HINT_GOLD
	a = (a or 1) * MG.HintPulse()
	thick = thick or math.max(3, r * 0.14)
	AN.Glow(MG.X(x), MG.Y(y), MG.S(r * 1.6), col, a)
	local seg = 32
	for pass = 1, 2 do
		local t = pass == 1 and thick + 3 or thick
		local c = pass == 1 and DARK or col
		for i = 0, seg - 1 do
			local a0, a1 = i / seg * math.pi * 2, (i + 1) / seg * math.pi * 2
			local r0, r1 = r - t / 2, r + t / 2
			poly({ { x + math.cos(a0) * r1, y + math.sin(a0) * r1 }, { x + math.cos(a1) * r1, y + math.sin(a1) * r1 },
				{ x + math.cos(a1) * r0, y + math.sin(a1) * r0 }, { x + math.cos(a0) * r0, y + math.sin(a0) * r0 } }, c, a)
		end
	end
end

-- an arrow from (x1, y1) to (x2, y2)
function MG.HintArrow(x1, y1, x2, y2, col, a, w)
	col = col or MG.HINT_GOLD
	a = (a or 1) * MG.HintPulse()
	w = w or 8
	local dx, dy = x2 - x1, y2 - y1
	local len = math.max(1, math.sqrt(dx * dx + dy * dy))
	local ux, uy = dx / len, dy / len
	local nx, ny = -uy, ux
	local head = math.min(len * 0.6, w * 3)
	for pass = 1, 2 do
		local e = pass == 1 and 2 or 0
		local c = pass == 1 and DARK or col
		local hx, hy = x2 - ux * head, y2 - uy * head
		local hw = w / 2 + e
		poly({ { x1 + nx * hw - ux * e, y1 + ny * hw - uy * e }, { hx + nx * hw, hy + ny * hw }, { hx - nx * hw, hy - ny * hw }, { x1 - nx * hw - ux * e, y1 - ny * hw - uy * e } }, c, a)
		local bw = w * 1.6 + e * 1.5
		poly({ { x2 + ux * e * 1.5, y2 + uy * e * 1.5 }, { hx - nx * bw - ux * e, hy - ny * bw - uy * e }, { hx + nx * bw - ux * e, hy + ny * bw - uy * e } }, c, a)
	end
end

-- a highlighted rectangle
function MG.HintBox(x, y, w, h, col, a, thick)
	col = col or MG.HINT_GOLD
	a = (a or 1) * MG.HintPulse()
	thick = thick or 4
	AN.Box(MG.X(x), MG.Y(y), MG.S(w), MG.S(h), Color(col.r, col.g, col.b, 60 * a))
	AN.Outline(MG.X(x) - 2, MG.Y(y) - 2, MG.S(w) + 4, MG.S(h) + 4, Color(DARK.r, DARK.g, DARK.b, 255 * a), 6, MG.S(thick) + 3)
	AN.Outline(MG.X(x), MG.Y(y), MG.S(w), MG.S(h), Color(col.r, col.g, col.b, 255 * a), 6, MG.S(thick))
end

-- a short label with a dark edge
function MG.HintText(txt, x, y, col, size, a)
	col = col or MG.HINT_GOLD
	a = a or 1
	local sz = math.floor(MG.S(size or 18) + 0.5)
	for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { 2, 2 } }) do
		AN.Text(txt, "title", sz, MG.X(x) + o[1], MG.Y(y) + o[2], DARK, 1, 1, 255 * a)
	end
	AN.Text(txt, "title", sz, MG.X(x), MG.Y(y), col, 1, 1, 255 * a)
end

-- a plain thick line (no head), for drawn paths
function MG.HintLine(x1, y1, x2, y2, col, a, w)
	col = col or MG.HINT_GOLD
	a = (a or 1) * MG.HintPulse()
	w = w or 6
	local dx, dy = x2 - x1, y2 - y1
	local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
	local nx, ny = -dy / len, dx / len
	for pass = 1, 2 do
		local hw = w / 2 + (pass == 1 and 2 or 0)
		local ex, ey = dx / len * (pass == 1 and 2 or 1), dy / len * (pass == 1 and 2 or 1)
		poly({ { x1 + nx * hw - ex, y1 + ny * hw - ey }, { x2 + nx * hw + ex, y2 + ny * hw + ey }, { x2 - nx * hw + ex, y2 - ny * hw + ey }, { x1 - nx * hw - ex, y1 - ny * hw - ey } }, pass == 1 and DARK or col, a)
	end
end
