-- Hovedmenu: side panel on the left, the table group (Gyldengrød, Kandis, Pyrus)
-- on the right, and the player's own decorated tree blurred in the background.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.main = S

-- The tree "frame" is 820 x 980 (same as the decoration box); the tree image sits at its bottom.
AN.TREE_W, AN.TREE_H = 820, 980

function AN.TreeImageRect()
	local w = AN.TREE_W
	local h = w * AN.Ratio("ui/trae.png")
	return 0, AN.TREE_H - h, w, h
end

-- draw the tree with the saved ornaments. x,y = top-left of the frame, sc = scale
-- soft = fake blur radius (virtual px), shade = 0..255 brightness
function AN.DrawTree(x, y, sc, soft, shade, skipIndex, tree)
	local col = Color(shade or 255, shade or 255, shade or 255)
	local tx, ty, tw, th = AN.TreeImageRect()
	local function img(path, ix, iy, iw)
		local ih = iw * AN.Ratio(path)
		if soft and soft > 0 then
			AN.ImgSoft(path, x + ix * sc, y + iy * sc, iw * sc, ih * sc, soft, 255, col)
		else
			AN.Img(path, x + ix * sc, y + iy * sc, iw * sc, ih * sc, 255, col)
		end
	end
	img("ui/trae.png", tx, ty, tw)
	for i, o in ipairs(tree or AN.Save.Tree()) do
		if i ~= skipIndex then
			local def = AN.OrnamentById[o.id]
			if def then
				local rx, ry, rw = AN.OrnamentRect(o.id, AN.ORN_TREE_SCALE)
				img(def.img, o.x + rx, o.y + ry, rw)
			end
		end
	end
end

function S:Open() end

function S:Paint()
	local R = AN.R
	UI.Background("menu")

	-- blurred tree behind the table group
	AN.DrawTree(1430 + AN.C, 225, 0.638, 4, 209)

	UI.Shade("menu")

	-- logo + name
	local lh = AN.Img("ui/logo.png", 110, 40, 300)
	AN.Text(AN.L("main_title"), "title", 40, 124, 40 + lh - 6, C.gold)

	-- navigation
	local cur = AN.CurrentDoor()
	local calSub
	if cur then
		if AN.UsesDate() and cur == math.min(AN.Today(), 24) then
			calSub = AN.L("main_cal_today", cur)
		else
			calSub = AN.L("main_cal_next", cur)
		end
	elseif AN.Save.DoneCount() >= 24 then
		calSub = AN.L("main_cal_done")
	else
		calSub = AN.L("main_cal_wait")
	end

	local y = 400
	UI.ListItem("nav_cal", 110, y, 600, 104, AN.L("main_cal"), calSub, nil, true,
		function() UI.Open("kalender") end, "ui/trae.png", 48)
	y = y + 114
	UI.ListItem("nav_sea", 110, y, 600, 104, AN.L("main_seasons"), AN.L("main_seasons_sub"), nil, false,
		function() UI.Open("saesoner") end, "ui/rulle.png", 40)
	y = y + 114
	UI.ListItem("nav_box", 110, y, 600, 104, AN.L("main_box"),
		AN.L("main_box_sub", AN.Save.Coins(), AN.Save.OwnedCount()), nil, false,
		function() UI.Open("pyntekasse", { zoom = true }) end, "ui/kiste.png", 40, { voice = { "skattekiste_rollover", 20 / 25 } })
	y = y + 114
	UI.ListItem("nav_scrap", 110, y, 600, 104, AN.L("main_scrap"), AN.L("main_scrap_sub"), nil, false,
		function() UI.Open("scrapbog") end, "ui/scrapbog.png", 40, { voice = { "scrapbog_rollover", 20 / 25 } })
	y = y + 128

	local px = 134
	px = px + UI.Pill("nav_set", AN.L("main_settings"), px, y, function() UI.Open("indstillinger") end, 22, { voice = { "instillinger_rollover", 20 / 25 } }) + 14
	px = px + UI.Pill("nav_prof", AN.L("main_profiles"), px, y, function() UI.Open("profil") end, 22) + 14
	UI.Pill("nav_quit", AN.L("quit"), px, y, function() RunConsoleCommand("disconnect") end, 22)

	-- table group (original composition)
	AN.Shadow(976 + AN.C, 960, 800, 90, 150)
	AN.Img("ui/bordscene.png", 926 + AN.C, 380, 880)

	-- Pyrus speaks
	local bubble
	if cur then
		bubble = AN.L("main_bubble_today", AN.GameName(cur))
	elseif AN.Save.DoneCount() >= 24 then
		bubble = AN.L("main_bubble_done")
	else
		bubble = AN.L("main_bubble_wait")
	end
	UI.Bubble(bubble, 1800 + AN.C, 170, 420, 28)

	UI.CornerButtons(function() RunConsoleCommand("disconnect") end)

	-- footer with today's date
	local d = AN.L("date_fmt", AN.Today(), AN.L("month_" .. tonumber(os.date("%m"))))
	AN.Text(AN.L("main_footer", d, AN.Version), "bold", 18, 134, 1080 - 36 - 22, Color(255, 241, 207, 140))
end
