-- Profiler: everyone who has played on this server (the ones playing now first). A profile shows
-- the player's Steam picture and name, how far they are, their best result in every game
-- (with the hint mark) and their decorated tree.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.profil = S

local ROW_H, ROW_GAP = 76, 8

function S:Open(args)
	self.sid = args.sid or AN.Save.MySid()
	self.back = args.back
	self.scroll = 0
	AN.PlayerList = nil
	AN.Save.RequestPlayers()
	AN.Save.RequestProfile(self.sid)
	self.asked = RealTime()
end

function S:Select(sid)
	if sid == self.sid then return end
	self.sid = sid
	AN.Save.RequestProfile(sid)
	self.asked = RealTime()
end

function S:Wheel(d)
	self.scroll = math.max(0, self.scroll - d)
end

function S:Think()
	-- keep what is shown fresh while the screen is open
	if RealTime() - (self.asked or 0) > 5 then
		self.asked = RealTime()
		AN.Save.RequestPlayers()
		AN.Save.RequestProfile(self.sid)
	end
end

local function goBack(self)
	if self.back then UI.Open(self.back[1], self.back[2]) else UI.Open("main") end
end

function S:PaintList(x, y, w, h)
	local list = AN.PlayerList
	if not list then
		AN.Text(AN.L("prof_loading"), "bold", 22, x + 24, y + 20, C.sand)
		return
	end
	local me = AN.Save.MySid()
	-- online first, then the most doors
	local rows = {}
	for _, p in ipairs(list) do rows[#rows + 1] = p end
	table.sort(rows, function(a, b)
		if a.online ~= b.online then return a.online end
		if (a.done or 0) ~= (b.done or 0) then return (a.done or 0) > (b.done or 0) end
		return tostring(a.name) < tostring(b.name)
	end)
	local fit = math.floor(h / (ROW_H + ROW_GAP))
	self.scroll = math.min(self.scroll, math.max(0, #rows - fit))
	for i = 1, fit do
		local p = rows[i + self.scroll]
		if not p then break end
		local ry = y + (i - 1) * (ROW_H + ROW_GAP)
		local sel = p.sid == self.sid
		local hot = UI.Button("prof_p" .. i, x, ry, w, ROW_H, function() self:Select(p.sid) end)
		if sel then
			AN.HGrad(x, ry, w, ROW_H, Color(255, 190, 90), 82, 10)
			AN.Box(x, ry, 4, ROW_H, C.gold)
		elseif hot then
			AN.Box(x, ry, w, ROW_H, Color(255, 241, 207, 20), 14)
		end
		UI.Avatar(p.sid, x + 16, ry + 10, 56)
		local name = p.name or "?"
		if p.sid == me then name = name .. " " .. AN.L("prof_you") end
		AN.TextEllipsis(name, "black", 24, x + 88, ry + 24, w - 88 - 24, (sel or hot) and C.white or C.cream, 0, 1)
		AN.Text(AN.L("prof_doors", p.done or 0), "bold", 18, x + 88, ry + 52, sel and C.gold or C.sand, 0, 1)
		if p.online then
			AN.Circle(x + w - 22, ry + 24, 7, Color(120, 210, 110))
		end
	end
	if #rows > fit then
		AN.Text(AN.L("prof_more", #rows - fit), "bold", 17, x + 24, y + fit * (ROW_H + ROW_GAP) + 4, C.sand)
	end
end

function S:PaintProfile(rx, ry, rw, rh)
	UI.Card(rx, ry, rw, rh)
	local p = AN.Profiles[self.sid]
	if not p then
		AN.Text(AN.L("prof_loading"), "bold", 26, rx + 36, ry + 36, C.wheat)
		return
	end
	-- header: picture, name, how far they are
	local x, y = rx + 36, ry + 32
	AN.Box(x - 4, y - 4, 128, 128, Color(255, 241, 207, 40), 12)
	UI.Avatar(p.sid, x, y, 120)
	local name = p.name or "?"
	AN.TextEllipsis(name, "title", 52, x + 150, y + 30, rw - 220, C.white, 0, 1)
	AN.Text(p.online and AN.L("prof_online") or AN.L("prof_offline"), "bold", 19, x + 150, y + 70, p.online and Color(150, 225, 140) or C.sand, 0, 1)
	-- stats
	local sx = x + 150
	local function stat(label, value)
		local lw = math.max(AN.TextSize(value, "black", 26), AN.TextSize(label, "bold", 16)) + 34
		AN.Text(value, "black", 26, sx, y + 108, C.gold, 0, 1)
		AN.Text(label, "bold", 16, sx, y + 134, C.sand, 0, 1)
		sx = sx + lw
	end
	stat(AN.L("prof_stat_doors"), (p.done or 0) .. "/24")
	stat(AN.L("prof_stat_coins"), tostring(p.coins or 0))
	stat(AN.L("prof_stat_orns"), tostring(p.owned or 0))

	-- best result in every game
	local gx, gy = rx + 36, ry + 210
	local gw = rw - 36 - 36 - 330
	AN.Text(AN.L("prof_best"), "title", 30, gx, gy, C.gold)
	AN.HintMark(gx + gw - 140, gy + 18, 10)
	AN.Text(AN.L("prof_hint_key"), "bold", 16, gx + gw - 124, gy + 18, C.sand, 0, 1)
	gy = gy + 50
	local colW = (gw - 16) / 2
	for n = 1, 24 do
		local col = n <= 12 and 0 or 1
		local row = (n - 1) % 12
		local bx = gx + col * (colW + 16)
		local by = gy + row * 46
		local b = p.best[tostring(n)]
		AN.Box(bx, by, colW, 40, Color(255, 241, 207, b and 26 or 10), 10)
		AN.Text(tostring(n), "black", 16, bx + 12, by + 20, C.sand, 0, 1)
		AN.TextFit(AN.GameName(n), "bold", 18, bx + 44, by + 20, colW - 44 - 92, C.cream, 0, 1)
		local v = b and b.v and AN.FormatValue(n, b.v) or AN.L("scr_hs_none")
		AN.Text(v, "black", 18, bx + colW - 12, by + 20, b and C.gold or C.sand, 2, 1)
		if b and b.h then
			local vw = AN.TextSize(v, "black", 18)
			AN.HintMark(bx + colW - 12 - vw - 14, by + 20, 9)
		end
	end

	-- their tree
	local tx = rx + rw - 36 - 300
	local ty = ry + 200
	AN.Text(AN.L("prof_tree"), "title", 30, tx + 150, ty + 10, C.gold, 1)
	local sc = 300 / AN.TREE_W
	AN.DrawTree(tx, ty + 50, sc, 0, 255, nil, p.tree)
	if p.next and AN.OrnamentById[p.next] then
		local by = ty + 50 + AN.TREE_H * sc + 18
		AN.Text(AN.L("box_next"), "bold", 18, tx + 150, by, C.sand, 1)
		AN.ImgFit(AN.OrnamentById[p.next].img, tx + 130, by + 26, 40, 60)
	end
end

function S:Paint()
	UI.Background("sub")
	UI.Shade("sub")
	UI.Pill("back", AN.L("back"), 110, 60, function() goBack(self) end)

	local x, y = 110, 170
	AN.Text(AN.L("prof_title"), "title", 64, x, y, C.white)
	AN.Text(AN.L("prof_sub"), "bold", 20, x, y + 80, C.sand)
	self:PaintList(x, y + 130, 600, 1080 - (y + 130) - 60)

	self:PaintProfile(860 + AN.C, 150, 960, 830)

	UI.CornerButtons()
end
