-- Scrapbog: pictures from the show, trophies, highscores and (later) Pyrus' voice lines.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.scrapbog = S

local STILLS = 15
local PER_PAGE = 8
local rots = { -2, 1.5, -1, 2, 1, -2.5, 2, -1.5 }

function S:Open(args)
	self.tab = args.tab or "pics"
	self.page = 1
	self.big = nil
	AN.Speak("scrapbog_start")
end

function S:Paint()
	local R = AN.R
	UI.Background("sub")
	UI.Shade("sub")
	UI.BackButton("main")

	local x, y = 110, 170
	AN.Img("ui/scrapbog.png", x, y, 150)
	AN.Text(AN.L("scr_title"), "title", 64, x + 168, y + 4, C.white)
	y = y + 120

	local tabs = {
		{ "pics", AN.L("scr_pics"), tostring(STILLS) },
		{ "trophies", AN.L("scr_trophies"), "0 / 72" },
		{ "highscores", AN.L("scr_highscores"), AN.L("scr_games", 24) },
		{ "voice", AN.L("scr_voice"), AN.L("scr_lines", 131) },
	}
	for _, t in ipairs(tabs) do
		UI.ListItem("tab_" .. t[1], x, y, 600, 88, t[2], nil, t[3], self.tab == t[1], function()
			self.tab = t[1]
			self.big = nil
		end, nil, 40)
		y = y + 98
	end

	local rx, ry, rw = 860 + AN.C, 150, 960
	if self.tab == "pics" then
		self:PaintPics(rx, ry, rw)
	elseif self.tab == "highscores" then
		self:PaintScores(rx, ry, rw)
	elseif self.tab == "trophies" then
		UI.Card(rx, ry, rw, 140)
		AN.TextWrap(AN.L("scr_trophy_soon"), "bold", 26, rx + 36, ry + 34, rw - 72, C.wheat, 36)
	else
		UI.Card(rx, ry, rw, 140)
		AN.TextWrap(AN.L("scr_voice_soon"), "bold", 26, rx + 36, ry + 34, rw - 72, C.wheat, 36)
	end

	UI.CornerButtons()

	-- enlarged picture on top of everything
	if self.big then
		local p = string.format("stills/%02d.jpg", self.big)
		UI.Button("big_close", -100, -100, AN.VW + 200, AN.VH + 200, function() self.big = nil end, { silent = true })
		AN.Box(-AN.OX, -AN.OY, AN.VW + AN.OX * 2, AN.VH, Color(10, 4, 1, 220))
		local r = AN.Ratio(p)
		local h = 860
		local w = h / r
		if w > AN.VW - 200 then w = AN.VW - 200; h = w * r end
		local bx, by = (AN.VW - w) / 2, (1080 - h) / 2
		AN.Box(bx - 14, by - 14, w + 28, h + 28 + 26, Color(251, 243, 223), 6)
		AN.Img(p, bx, by, w, h)
		AN.Text(AN.L("scr_close"), "black", 20, AN.VW / 2, by + h + 18, C.brown, 1)
	end
end

function S:PaintPics(rx, ry, rw)
	local pages = math.ceil(STILLS / PER_PAGE)
	local cw = (rw - 3 * 18) / 4
	local first = (self.page - 1) * PER_PAGE + 1
	for k = 0, PER_PAGE - 1 do
		local i = first + k
		if i > STILLS then break end
		local col, row = k % 4, math.floor(k / 4)
		local fx = rx + col * (cw + 18)
		local fy = ry + row * (220 + 24 + 30)
		local fw, fh = cw, 220 + 24
		local hot = UI.Button("still" .. i, fx, fy, fw, fh, function() self.big = i end)
		local rot = rots[k + 1] or 0
		local lift = hot and 1.05 or 1
		local cx, cy = fx + fw / 2, fy + fh / 2
		-- polaroid frame (rotated): shadow, paper, picture
		surface.SetDrawColor(0, 0, 0, 110)
		draw.NoTexture()
		surface.DrawTexturedRectRotated(AN.PX(cx + 4), AN.SY(cy + 12), AN.SX(fw * lift), AN.SX(fh * lift), rot)
		surface.SetDrawColor(251, 243, 223, 255)
		surface.DrawTexturedRectRotated(AN.PX(cx), AN.SY(cy), AN.SX(fw * lift), AN.SX(fh * lift), rot)
		-- picture: crop to cover a (fw-20) x 220 area, then rotate with the frame
		local p = string.format("stills/%02d.jpg", i)
		local iw, ih = (fw - 20) * lift, 220 * lift
		local r = AN.Ratio(p)
		local boxR = ih / iw
		local u0, v0, u1, v1 = 0, 0, 1, 1
		if r > boxR then local vis = boxR / r v0 = (1 - vis) / 2 v1 = 1 - v0 else local vis = r / boxR u0 = (1 - vis) / 2 u1 = 1 - u0 end
		-- offset of the picture centre from the frame centre (picture sits 4px higher)
		local a = math.rad(-rot)
		local ox, oy = 0, -7 * lift
		local pcx = cx + ox * math.cos(a) - oy * math.sin(a)
		local pcy = cy + ox * math.sin(a) + oy * math.cos(a)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(AN.Mat(p))
		-- DrawTexturedRectRotated has no UV version; use a polygon with UVs
		local hw, hh = AN.SX(iw) / 2, AN.SX(ih) / 2
		local scx, scy = AN.PX(pcx), AN.SY(pcy)
		local ca, sa = math.cos(a), math.sin(a)
		local function pt(dx, dy, u, v)
			return { x = scx + dx * ca - dy * sa, y = scy + dx * sa + dy * ca, u = u, v = v }
		end
		surface.DrawPoly({ pt(-hw, -hh, u0, v0), pt(hw, -hh, u1, v0), pt(hw, hh, u1, v1), pt(-hw, hh, u0, v1) })
	end
	-- pager
	local py = ry + 2 * (220 + 24 + 30) + 10
	local label = AN.L("scr_page", self.page, pages)
	local lw = AN.TextSize(label, "black", 20)
	local cx = rx + rw / 2
	AN.Text(label, "black", 20, cx, py + 20, C.wheat, 1, 1)
	if self.page > 1 then
		local hot = UI.Button("prev", cx - lw / 2 - 70, py, 50, 40, function() self.page = self.page - 1 end)
		AN.Text("‹", "black", 34, cx - lw / 2 - 45, py + 18, hot and C.gold or C.cream, 1, 1)
	end
	if self.page < pages then
		local hot = UI.Button("next", cx + lw / 2 + 20, py, 50, 40, function() self.page = self.page + 1 end)
		AN.Text("›", "black", 34, cx + lw / 2 + 45, py + 18, hot and C.gold or C.cream, 1, 1)
	end
end

function S:PaintScores(rx, ry, rw)
	UI.Card(rx, ry, rw, 830)
	local colW = (rw - 72 - 30) / 2
	for n = 1, 24 do
		local col = n <= 12 and 0 or 1
		local row = (n - 1) % 12
		local x = rx + 36 + col * (colW + 30)
		local y = ry + 30 + row * 64
		local door = AN.Save.Door(n)
		AN.Box(x, y, colW, 54, Color(255, 241, 207, door and door.best and 26 or 12), 14)
		AN.Text(tostring(n), "black", 18, x + 16, y + 27, C.sand, 0, 1)
		AN.TextFit(AN.GameName(n), "bold", 22, x + 56, y + 27, colW - 170, C.cream, 0, 1)
		local v = door and door.best and AN.FormatValue(n, door.best) or AN.L("scr_hs_none")
		AN.Text(v, "black", 22, x + colW - 16, y + 27, door and door.best and C.gold or C.sand, 2, 1)
		if door and door.best and door.hint then
			AN.HintMark(x + colW - 16 - AN.TextSize(v, "black", 22) - 16, y + 27, 10)
		end
	end
end
