-- Sæsoner: pick a season on the left, its card on the right.
-- Only Christmas (the calendar) is playable for now; the others show what is coming.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.saesoner = S

local seasons = {
	{ id = "xmas", name = "sea_xmas", sub = "sea_xmas_sub", games = "sea_xmas_games", total = 24,
	  top = Color(120, 18, 26), bottom = Color(40, 8, 10), glow = Color(255, 215, 106), snow = true },
	{ id = "summer", name = "sea_summer", sub = "sea_summer_sub", games = "sea_summer_games", total = 12,
	  top = Color(42, 111, 158), bottom = Color(95, 176, 214), ground = { Color(242, 211, 138), Color(233, 184, 102) },
	  sun = Color(255, 229, 138), badge = "sea_open" },
	{ id = "newyear", name = "sea_newyear", sub = "sea_newyear_sub", games = "sea_newyear_games", total = 12,
	  top = Color(10, 14, 40), bottom = Color(52, 30, 92), sparks = true },
	{ id = "halloween", name = "sea_halloween", sub = "sea_halloween_sub", games = "sea_halloween_games", total = 12,
	  top = Color(30, 12, 44), bottom = Color(196, 86, 24), moon = Color(255, 236, 190), badge = "sea_open" },
	{ id = "easter", name = "sea_easter", sub = "sea_easter_sub", games = "sea_easter_games", total = 12,
	  top = Color(150, 206, 236), bottom = Color(220, 236, 170), ground = { Color(140, 196, 90), Color(96, 160, 60) },
	  sun = Color(255, 240, 160) },
}

function S:Open(args)
	self.sel = args.season or "summer"
end

local function trophyText(s)
	if s.id == "xmas" then
		return AN.Save.DoneCount(), 24
	end
	if (s.id == "summer" or s.id == "halloween") and AN.Summer then return AN.Summer.TrophyCount(s.id) end
	return 0, s.total
end

function S:Paint()
	local R = AN.R
	UI.Background("sub")
	UI.Shade("sub")
	UI.BackButton("main")

	local x, y = 110, 170
	AN.Text(AN.L("sea_title"), "title", 64, x, y, C.white)
	y = y + 90
	y = y + AN.TextWrap(AN.L("sea_intro"), "bold", 22, x, y, 600, C.wheat, 32) + 20

	local cur
	for _, s in ipairs(seasons) do
		local got, tot = trophyText(s)
		local sel = s.id == self.sel
		if sel then cur = s end
		UI.ListItem("sea_" .. s.id, x, y, 600, 96, AN.L(s.name), AN.L(s.sub),
			(s.id == "xmas" or s.id == "summer" or s.id == "halloween") and (got .. " / " .. tot) or (got > 0 and (got .. " / " .. tot) or "—"),
			sel, function() self.sel = s.id end, nil, 40)
		y = y + 106
	end

	-- the season card
	local cx, cy, cw, ch = 860 + AN.C, 150, 960, 820
	local s = cur or seasons[2]
	-- sky
	AN.Box(cx, cy, cw, ch, s.top, 30)
	if s.ground then
		AN.VGrad2(cx, cy + 20, cw, ch * 0.48 - 20, s.top, Color(s.bottom.r, s.bottom.g, s.bottom.b, 255))
		AN.Box(cx, cy + ch * 0.48, cw, ch * 0.52, s.ground[1], 30)
		AN.Box(cx, cy + ch * 0.48, cw, 40, s.ground[1])
		AN.VGrad2(cx, cy + ch * 0.6, cw, ch * 0.4 - 30, s.ground[1], Color(s.ground[2].r, s.ground[2].g, s.ground[2].b, 255))
		AN.BoxEx(cx, cy + ch - 30, cw, 30, s.ground[2], 30, false, false, true, true)
		AN.VGrad(cx, cy + ch * 0.46, cw, 30, C.white, 0, 120)
		AN.VGrad(cx, cy + ch * 0.48 + 0, cw, 30, C.white, 120, 0)
	else
		AN.VGrad2(cx, cy + 30, cw, ch - 60, s.top, Color(s.bottom.r, s.bottom.g, s.bottom.b, 255))
		AN.BoxEx(cx, cy + ch - 30, cw, 30, s.bottom, 30, false, false, true, true)
	end
	if s.sun then
		AN.Glow(cx + cw - 155, cy + 135, 160, s.sun, 1.2)
		AN.Circle(cx + cw - 155, cy + 135, 65, s.sun)
	end
	if s.moon then
		AN.Glow(cx + cw - 170, cy + 150, 150, s.moon, 0.9)
		AN.Circle(cx + cw - 170, cy + 150, 70, s.moon)
		AN.Circle(cx + cw - 140, cy + 130, 62, s.top)
	end
	if s.sparks or s.snow then
		local rng = 1
		for i = 1, 70 do
			rng = (rng * 1103515245 + 12345) % 2147483648
			local px = cx + 30 + (rng % (cw - 60))
			rng = (rng * 1103515245 + 12345) % 2147483648
			local py = cy + 30 + (rng % 520)
			local tw = 0.5 + 0.5 * math.sin(RealTime() * 2 + i)
			if s.snow then
				local fall = (RealTime() * 30 + i * 37) % 560
				AN.Circle(px, cy + 30 + (py - cy - 30 + fall) % 560, 3 + (i % 3), Color(255, 255, 255, 140 + 80 * tw))
			else
				local col = (i % 3 == 0) and Color(255, 215, 106) or ((i % 3 == 1) and Color(255, 120, 160) or Color(140, 200, 255))
				AN.Circle(px, py, 2 + (i % 3), Color(col.r, col.g, col.b, 90 + 150 * tw))
			end
		end
	end

	-- badge + title
	local badge = s.badge and AN.L(s.badge) or AN.Upper(AN.L(s.sub))
	local bw = AN.TextSize(badge, "black", 18) + 36
	AN.Box(cx + 50, cy + 46, bw, 38, Color(20, 8, 2, 140), 19)
	AN.Text(badge, "black", 18, cx + 50 + bw / 2, cy + 65, C.gold, 1, 1)
	AN.TextShadow(AN.L(s.name), "title", 96, cx + 50, cy + 96, C.white, Color(20, 40, 60, 115), 6)

	-- bottom info box
	local gl = AN.Wrap(AN.L(s.games), "bold", 26, cw - 160)
	local bww = cw - 100
	local bh = 50 + #gl * 32 + 24 + 76 + 26
	local bx, by = cx + 50, cy + ch - 50 - bh
	AN.Box(bx, by, bww, bh, Color(20, 8, 2, 199), 22)
	AN.Text(AN.L("sea_games"), "bold", 18, bx + 30, by + 26, C.sand)
	AN.TextWrap(AN.L(s.games), "bold", 26, bx + 30, by + 50, bww - 60, C.white, 32)
	local got, tot = trophyText(s)
	local playY = by + bh - 26 - 76
	if s.id == "xmas" then
		UI.RedButton("sea_play", AN.L("sea_to_cal"), bx + 30, playY, 330, 76, 32, function() UI.Open("kalender") end)
	elseif s.id == "summer" then
		UI.RedButton("sea_play", AN.L("sea_to_beach"), bx + 30, playY, 330, 76, 32, function() UI.Open("sommer") end)
	elseif s.id == "halloween" then
		UI.RedButton("sea_play", AN.L("sea_to_house"), bx + 30, playY, 330, 76, 32, function() UI.Open("halloween") end)
	else
		UI.RedButton("sea_play", AN.L("coming_soon"), bx + 30, playY, 330, 76, 30, nil, true)
	end
	local tx = bx + 30 + 330 + 24
	local tw = bww - (tx - bx) - 30
	AN.Text(AN.L("sea_trophies"), "bold", 18, tx, playY + 14, C.sand)
	AN.Text(AN.L("sea_count", got, tot), "bold", 18, tx + tw, playY + 14, C.sand, 2)
	AN.Box(tx, playY + 44, tw, 12, Color(255, 241, 207, 38), 6)
	if got > 0 then AN.Box(tx, playY + 44, tw * got / tot, 12, C.gold, 6) end

	UI.CornerButtons()
end
