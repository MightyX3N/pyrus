-- The seasons after Christmas: Summer Holiday (Sommerferie, a beach) and Halloween (a haunted
-- house). Each season is a place to explore: click the spots on it to play its games. Every
-- season game has three difficulties (Easy, Normal, Hard) with a highscore list each, and a
-- trophy for each difficulty (bronze, silver, gold) when the score reaches the trophy's goal.
-- Summer games are numbered 101 and up, Halloween 201 and up; their results are saved under
-- game * 10 + difficulty.
AN = AN or {}
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer or {}
AN.Summer = SU

-- the games: where they are in their season's picture (1920 x 1080) and the trophy goals
SU.GAMES = {
	{ n = 101, season = "summer", key = "surf", spot = { 600, 500, 480, 230 }, goals = { 1000, 2000, 3000 } },
	{ n = 102, season = "summer", key = "icecream", spot = { 1140, 510, 330, 380 }, goals = { 800, 1300, 1800 } },
	{ n = 103, season = "summer", key = "fishing", spot = { 1590, 450, 330, 360 }, goals = { 600, 900, 1200 } },
	-- (the sandcastle is game 105: copy the castle; the first idea, 104 "build before the tide", was dropped)
	{ n = 105, season = "summer", key = "copycastle", spot = { 820, 760, 220, 240 }, goals = { 400, 650, 900 } },
	{ n = 201, season = "halloween", key = "carving", spot = { 230, 850, 440, 180 }, goals = { 2500, 2800, 3000 } },
	{ n = 202, season = "halloween", key = "ghosts", spot = { 700, 490, 130, 140 }, goals = { 3500, 3500, 3000 } },
	{ n = 203, season = "halloween", key = "trickortreat", spot = { 790, 630, 200, 170 }, goals = { 500, 450, 400 } },
	{ n = 204, season = "halloween", key = "maze", spot = { 1070, 740, 210, 90 }, goals = { 1000, 1500, 2000 } },
}
SU.BY = {}
for _, g in ipairs(SU.GAMES) do SU.BY[g.n] = g end

-- the seasons: the picture, the two in it, where the trophies are, the colours, the song
SU.SEASONS = {
	summer = {
		screen = "sommer", title = "sea_summer", bg = "sommer/beach.jpg", hut = { 330, 560, 300, 330 },
		chars = {
			{ img = "sommer/pyrus_swim.png", w = 440, h = 640, x = 1050, y = 1015, sh = 0.42, bob = 2 },
			{ img = "sommer/gyld_swim.png", w = 400, h = 640, x = 1440, y = 880, sh = 0.47, bob = 1.6, flip = true },
		},
		dim = Color(10, 30, 50), song = "glad_i_bad",
		col = { SEA = Color(31, 111, 168), SEA_HOT = Color(44, 140, 200), SAND = Color(250, 238, 206), SAND_D = Color(226, 201, 150),
			INK = Color(26, 58, 84), SUN = Color(255, 196, 64), SHADE = Color(16, 60, 96), TITLE = Color(20, 60, 100, 140) },
	},
	halloween = {
		screen = "halloween", title = "sea_halloween", bg = "halloween/house.jpg", hut = { 1450, 630, 240, 290 },
		chars = {
			{ img = "halloween/gyld_lantern.png", w = 490, h = 785, x = 640, y = 960, sh = 270 / 785, bob = 1.6 },
			{ img = "halloween/pyrus_cape.png", w = 514, h = 768, x = 1250, y = 1040, sh = 270 / 768, bob = 2 },
		},
		dim = Color(20, 8, 30), song = "drillerigtighed",
		col = { SEA = Color(90, 46, 134), SEA_HOT = Color(120, 66, 170), SAND = Color(246, 234, 212), SAND_D = Color(214, 160, 90),
			INK = Color(42, 22, 56), SUN = Color(255, 154, 42), SHADE = Color(50, 20, 74), TITLE = Color(30, 10, 40, 160) },
	},
}
function SU.SeasonOf(n) return SU.BY[n] and SU.BY[n].season or "summer" end
local CUPS = { "bronze", "silver", "gold" }

function SU.Made(n) return AN.Games[n] and AN.Games[n].made end
function SU.Key(n, d) return n * 10 + (d or SU.Diff()) end
function SU.Diff() return math.Clamp(tonumber(AN.Save.Get("sdiff")) or 2, 1, 3) end
function SU.SetDiff(d) AN.Save.Set("sdiff", d) end
function SU.Name(n) return AN.L("su_" .. (SU.BY[n] and SU.BY[n].key or "?")) end

-- the best result of a game on a difficulty, and whether its trophy is won
function SU.Best(n, d)
	local x = AN.Save.Door(SU.Key(n, d))
	return x and x.best
end
function SU.HasTrophy(n, d)
	local g, b = SU.BY[n], SU.Best(n, d)
	return g and b ~= nil and b >= g.goals[d]
end
function SU.TrophyCount(season)
	season = season or "summer"
	local c, tot = 0, 0
	for _, g in ipairs(SU.GAMES) do
		if g.season == season then
			tot = tot + 3
			for d = 1, 3 do if SU.HasTrophy(g.n, d) then c = c + 1 end end
		end
	end
	return c, tot
end

-- saving a result (no pebernødder in the summer: trophies instead)
local function save(n, value, opts)
	local g = AN.Games[n]
	local lower = g.scoreType == "time"
	local run = AN.CurRun[n]
	AN.CurRun[n] = nil
	local hint = (opts and opts.hint) or (run and run.hint) or AN.HintUsed[n] or nil
	AN.HintUsed[n] = nil
	local d = SU.Diff()
	local had = SU.HasTrophy(n, d)
	local isRecord, _, id = AN.Save.Finish(SU.Key(n, d), value, lower, 0, hint, run and run.id)
	return isRecord, id, (not had) and SU.HasTrophy(n, d)
end
function SU.SaveOnly(n, value) save(n, value) end
function SU.Finish(n, value, opts)
	local isRecord, id, trophy = save(n, value, opts)
	UI.Open("sgame", { n = n, state = "over", value = value, record = isRecord, entry = id, trophy = trophy })
end

---------------------------------------------------------------------------
-- the beach picture, covering the screen with its bottom at the bottom
---------------------------------------------------------------------------
local B = { s = 1, x0 = 0, y0 = 0 }
local function place()
	local s = math.max(AN.VW / 1920, AN.VH / 1080)
	B.s = s
	B.x0 = (AN.VW - 1920 * s) / 2
	B.y0 = 1080 + AN.OY - 1080 * s
end
local function BX(x) return B.x0 + x * B.s end
local function BY(y) return B.y0 + y * B.s end
SU.BX, SU.BY_ = BX, BY

-- an image, optionally mirrored
local function img(path, x, y, w, h, flip, alpha)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(AN.Mat(path))
	local u0, u1 = 0, 1
	if flip then u0, u1 = 1, 0 end
	surface.DrawTexturedRectUV(AN.PX(x), AN.SY(y), AN.SX(w), AN.SX(h), u0, 0, u1, 1)
end
SU.Img = img

-- the season's picture with the two in it (a little bob, like they're breathing)
function SU.Background(season, dim)
	local S = SU.SEASONS[season] or SU.SEASONS.summer
	place()
	AN.Img(S.bg, B.x0, B.y0, 1920 * B.s, 1080 * B.s)
	local t = RealTime()
	for i, c in ipairs(S.chars) do
		local ch = c.h * B.s * c.sh
		local cw = ch * c.w / c.h
		img(c.img, BX(c.x), BY(c.y) - ch + math.sin(t * c.bob + i) * 2 * B.s, cw, ch, c.flip)
	end
	if dim then AN.Box(0, -AN.OY, AN.VW, AN.VH, Color(S.dim.r, S.dim.g, S.dim.b, dim)) end
end
function SU.Beach(dim) SU.Background("summer", dim) end

---------------------------------------------------------------------------
-- the stage of a summer game: the whole screen (the game draws its own world around it)
---------------------------------------------------------------------------
function SU.Stage(sw, sh)
	MG.sw, MG.sh = sw, sh
	local k = math.min(AN.VW / sw, AN.VH / sh)
	MG.k = k
	MG.x0 = (AN.VW - sw * k) / 2
	MG.y0 = (1080 - sh * k) / 2
	AN.Box(-AN.OX, -AN.OY, AN.VW + 2 * AN.OX, AN.VH, Color(0, 0, 0))
end
function SU.Chrome(n)
	render.SetScissorRect(0, 0, 0, 0, false)
	-- sound and quit (back to the game's board), top right
	local x = AN.VW - 30 - 72
	local y = 20 - AN.OY
	local mode = AN.SoundMode()
	local hotL = UI.Button("su_sound", x - 84, y, 72, 72, function() AN.CycleSoundMode() end)
	AN.Img("ui/lyd.png", x - 84 + (hotL and -3 or 0), y + (hotL and -3 or 0), hotL and 78 or 72, hotL and 78 or 72, mode == 2 and 120 or 255)
	if mode > 0 then
		surface.SetDrawColor(mode == 2 and Color(200, 32, 45) or Color(255, 215, 106))
		local a, b = AN.PX(x - 84 + 12), AN.SY(y + 60)
		local c, d = AN.PX(x - 84 + 60), AN.SY(y + 12)
		for o = -2, 2 do surface.DrawLine(a + o, b, c + o, d) end
	end
	local hotQ = UI.Button("su_quit", x, y, 72, 72, function()
		local scr = UI.screen
		if scr and scr.StopLoops then scr:StopLoops() end
		UI.Open("sgame", { n = n, quiet = true })
	end)
	AN.Img("ui/luk.png", x + (hotQ and -3 or 0), y + (hotQ and -3 or 0), hotQ and 78 or 72, hotQ and 78 or 72)
end

---------------------------------------------------------------------------
-- small drawing helpers in the summer style: sea blue and sand
---------------------------------------------------------------------------
-- (the colours follow the season: SU.Theme sets them before drawing)
local SEA, SEA_HOT, SAND, SAND_D, INK, SUN, SHADE, TITLE
function SU.Theme(season)
	local c = (SU.SEASONS[season] or SU.SEASONS.summer).col
	SEA, SEA_HOT, SAND, SAND_D, INK, SUN, SHADE, TITLE = c.SEA, c.SEA_HOT, c.SAND, c.SAND_D, c.INK, c.SUN, c.SHADE, c.TITLE
	SU.Colors = c
end
SU.Theme("summer")

function SU.Panel(x, y, w, h)
	AN.Box(x + 8, y + 14, w, h, Color(0, 20, 40, 90), 28)
	AN.Box(x, y, w, h, SAND, 28)
	AN.Outline(x, y, w, h, SAND_D, 28, 4)
end
function SU.Button(id, label, x, y, w, h, fn, size, on)
	local hot = UI.Button(id, x, y, w, h, fn)
	AN.Box(x, y + 5, w, h, SHADE, h / 2)
	AN.Box(x, y + ((hot and input.IsMouseDown(MOUSE_LEFT)) and 3 or 0), w, h, (on or hot) and SEA_HOT or SEA, h / 2)
	AN.Text(label, "title", size or 28, x + w / 2, y + h / 2 + ((hot and input.IsMouseDown(MOUSE_LEFT)) and 3 or 0), C.white, 1, 1)
	return hot
end
local function pill(id, label, x, y, w, h, on, fn)
	local hot = UI.Button(id, x, y, w, h, fn)
	AN.Box(x, y, w, h, on and SEA or Color(SEA.r, SEA.g, SEA.b, hot and 50 or 22), h / 2)
	AN.Text(label, "black", 22, x + w / 2, y + h / 2, on and C.white or INK, 1, 1)
end
SU.Pill = pill

---------------------------------------------------------------------------
-- the beach (the summer's main screen)
---------------------------------------------------------------------------
local S = {}
S.__index = S
for id, sea in pairs(SU.SEASONS) do
	AN.Screens[sea.screen] = setmetatable({ garland = false, season = id }, S)
end

function S:Open(args)
	self.trophies = args and args.trophies or false
	self.toast = nil
end

function S:Paint()
	local season = self.season
	local SEAS = SU.SEASONS[season]
	SU.Theme(season)
	SU.Background(season)
	local function goBack()
		if AN.Classic and AN.Classic.Active() then UI.Open("main") else UI.Open("saesoner", { season = season }) end
	end
	local hotSpot
	-- the spots
	for _, g in ipairs(SU.GAMES) do
		local r = g.season == season and g.spot
		if r then
			local hot = UI.Button("su_spot" .. g.n, BX(r[1]), BY(r[2]), r[3] * B.s, r[4] * B.s, function()
				if SU.Made(g.n) then
					UI.Open("sgame", { n = g.n })
				else
					self.toast = { text = AN.L("su_soon", SU.Name(g.n)), t = RealTime() }
				end
			end)
			if hot and not self.trophies then hotSpot = { g = g, r = r } end
		end
	end
	local h = SEAS.hut
	local hotHut = UI.Button("su_hut", BX(h[1]), BY(h[2]), h[3] * B.s, h[4] * B.s, function() self.trophies = true end)
	-- the hovered spot: a glow and its name
	local function label(text, cx, cy, sub)
		local w = math.max(AN.TextSize(text, "title", 34), sub and AN.TextSize(sub, "bold", 18) or 0) + 50
		local hh = sub and 84 or 60
		AN.Box(cx - w / 2 + 4, cy - hh + 8, w, hh, Color(0, 0, 0, 90), 18)
		AN.Box(cx - w / 2, cy - hh, w, hh, SAND, 18)
		AN.Text(text, "title", 34, cx, cy - hh + 30, INK, 1, 1)
		if sub then AN.Text(sub, "bold", 18, cx, cy - 22, SEA, 1, 1) end
	end
	if hotSpot and not self.trophies then
		local r = hotSpot.r
		local cx, cy = BX(r[1] + r[3] / 2), BY(r[2] + r[4] / 2)
		AN.Glow(cx, cy, r[3] * B.s * 0.7, Color(255, 240, 180), 0.55)
		local made = SU.Made(hotSpot.g.n)
		label(SU.Name(hotSpot.g.n), cx, BY(r[2]) - 6, not made and AN.L("coming_soon") or nil)
	elseif hotHut and not self.trophies then
		local got, tot = SU.TrophyCount(season)
		label(AN.L("sea_trophies"), BX(h[1] + h[3] / 2), BY(h[2]) - 6, AN.L("sea_count", got, tot))
	end
	-- top left: the title and back
	AN.TextShadow(AN.L(SEAS.title), "title", 72, 60, 30 - AN.OY + 30, C.white, TITLE, 5)
	UI.Pill("back", AN.L("back"), 60, 140 - AN.OY + 20, goBack)
	local got, tot = SU.TrophyCount(season)
	AN.Text(AN.L("sea_trophies") .. ":  " .. AN.L("sea_count", got, tot), "black", 22, 60, 240 - AN.OY + 20, C.white)
	-- "coming soon" message
	if self.toast then
		local a = 1 - math.Clamp((RealTime() - self.toast.t - 2) / 0.5, 0, 1)
		if a <= 0 then self.toast = nil else
			local w = AN.TextSize(self.toast.text, "black", 26) + 60
			AN.Box(AN.VW / 2 - w / 2, 900, w, 64, Color(SHADE.r, SHADE.g, SHADE.b, 220 * a), 32)
			AN.Text(self.toast.text, "black", 26, AN.VW / 2, 932, Color(255, 255, 255, 255 * a), 1, 1)
		end
	end
	if self.trophies then self:PaintTrophies() end
	UI.CornerButtons(function() UI.Open("main") end)
end

-- the trophy shelf in the beach hut: every game, a cup for each difficulty
function S:PaintTrophies()
	local season = self.season
	local list = {}
	for _, g in ipairs(SU.GAMES) do if g.season == season then list[#list + 1] = g end end
	UI.Button("su_block", -2000, -2000, AN.VW + 4000, AN.VH + 4000, nil, { silent = true, press = function() end })
	AN.Box(0, -AN.OY, AN.VW, AN.VH, Color(0, 0, 0, 150))
	local w, h = 1100, 820
	local x, y = AN.VW / 2 - w / 2, 540 - h / 2
	SU.Panel(x, y, w, h)
	AN.Text(AN.L("sea_trophies"), "title", 54, x + w / 2, y + 56, INK, 1, 1)
	local got, tot = SU.TrophyCount(season)
	AN.Text(AN.L("sea_count", got, tot), "black", 22, x + w / 2, y + 104, SEA, 1, 1)
	local colX = { x + 520, x + 710, x + 900 }
	for d = 1, 3 do
		AN.Text(AN.L("su_diff" .. d), "black", 22, colX[d], y + 150, INK, 1, 1)
	end
	for i, g in ipairs(list) do
		local ry = y + 172 + (i - 1) * 104
		AN.Box(x + 40, ry, w - 80, 96, Color(SEA.r, SEA.g, SEA.b, i % 2 == 0 and 14 or 26), 18)
		AN.Text(SU.Name(g.n), "title", 30, x + 70, ry + 36, SU.Made(g.n) and INK or Color(INK.r, INK.g, INK.b, 120))
		if not SU.Made(g.n) then AN.Text(AN.L("coming_soon"), "bold", 18, x + 70, ry + 68, SEA) end
		for d = 1, 3 do
			local has = SU.HasTrophy(g.n, d)
			local cw, chh = 54, 65
			AN.Img("sommer/cup_" .. (has and CUPS[d] or "empty") .. ".png", colX[d] - cw / 2, ry + 6, cw, chh, has and 255 or 150)
			local best = SU.Best(g.n, d)
			AN.Text(has and AN.FormatValue(g.n, best) or AN.L("su_goal", g.goals[d]), "bold", 15, colX[d], ry + 84, has and SEA or Color(INK.r, INK.g, INK.b, 150), 1, 1)
		end
	end
	SU.Button("su_tr_close", AN.L("vs_close"), x + w / 2 - 120, y + h - 84, 240, 60, function() self.trophies = false end, 28)
end

---------------------------------------------------------------------------
-- a summer game's board: how to play, the difficulty, the highscores; and the result after
---------------------------------------------------------------------------
local W = { garland = false }
AN.Screens.sgame = W

function W:Open(args)
	self.n = args.n or 101
	self.state = args.state or "start"
	self.value, self.record, self.entry, self.trophy = args.value, args.record, args.entry, args.trophy
	self.openedAt = RealTime()
	if self.state == "over" and self.trophy then AN.Sound("triangel") end
end

local function scoreList(n, d, x, y, w, rows, entry)
	local list = AN.Save.Scores(SU.Key(n, d))
	AN.Text(AN.L("su_scores", AN.L("su_diff" .. d)), "black", 22, x, y, INK)
	y = y + 40
	if #list == 0 then
		AN.TextWrap(AN.L("su_noscores"), "bold", 20, x, y, w, Color(INK.r, INK.g, INK.b, 160), 28)
		return
	end
	for i = 1, math.min(rows, #list) do
		local e = list[i]
		local yy = y + (i - 1) * 38
		local mine = entry and e.id == entry
		if mine then AN.Box(x - 10, yy - 4, w + 20, 36, Color(255, 196, 64, 90), 10) end
		AN.Text(i .. ".", "black", 20, x + 28, yy + 14, INK, 2, 1)
		AN.TextFit(e.name or "?", "bold", 20, x + 40, yy + 14, w - 160, INK, nil, 1)
		AN.Text(AN.FormatValue(n, e.v), "black", 20, x + w, yy + 14, SEA, 2, 1)
	end
end

local function cupRow(n, x, y)
	for d = 1, 3 do
		local has = SU.HasTrophy(n, d)
		AN.Img("sommer/cup_" .. (has and CUPS[d] or "empty") .. ".png", x + (d - 1) * 60, y, 46, 55, has and 255 or 130)
	end
end

function W:Paint()
	local n = self.n
	local season = SU.SeasonOf(n)
	SU.Theme(season)
	SU.Background(season, 110)
	local w, h = 1300, 780
	local x, y = AN.VW / 2 - w / 2, 540 - h / 2 + 20
	SU.Panel(x, y, w, h)
	-- header
	AN.Box(x, y, w, 110, SEA, 28)
	AN.Box(x, y + 60, w, 50, SEA)
	AN.TextShadow(SU.Name(n), "title", 60, x + 50, y + 22, C.white, TITLE, 4)
	cupRow(n, x + w - 250, y + 28)
	local d = SU.Diff()
	local lx, lw = x + 50, 640
	if self.state == "over" then
		-- the result
		local t = RealTime() - self.openedAt
		AN.Text(AN.L("su_result"), "black", 26, lx, y + 150, INK)
		AN.Text(AN.FormatValue(n, self.value or 0), "title", 110, lx, y + 190, SEA)
		local yy = y + 330
		if self.record then
			AN.Text(AN.L("su_record"), "title", 36, lx, yy, Color(200, 60, 40))
			yy = yy + 56
		end
		if self.trophy then
			local k = math.Clamp(t / 0.6, 0, 1)
			local s = 1 + 0.25 * math.sin(math.min(t, 1.2) * 8) * (1 - math.min(t / 1.2, 1))
			AN.Glow(lx + 60, yy + 70, 120, SUN, 0.8 * k)
			AN.Img("sommer/cup_" .. CUPS[d] .. ".png", lx + 60 - 50 * s, yy + 70 - 60 * s, 100 * s, 120 * s, 255 * k)
			AN.TextWrap(AN.L("su_trophy_won", AN.L("su_cup" .. d)), "title", 30, lx + 140, yy + 30, 460, INK, 38)
		else
			local g = SU.BY[n]
			if g and not SU.HasTrophy(n, d) then
				AN.TextWrap(AN.L("su_trophy_goal", g.goals[d], AN.L("su_cup" .. d)), "bold", 22, lx, yy, 560, INK, 30)
			end
		end
		SU.Button("su_again", AN.L("su_again"), lx, y + h - 110, 280, 72, function() UI.Open("game" .. n, { n = n }) end, 32)
		SU.Button("su_board", AN.L("vs_back"), lx + 300, y + h - 110, 240, 72, function() UI.Open("sgame", { n = n, quiet = true }) end, 30)
	else
		-- how to play
		AN.TextWrap(AN.L("su_how_" .. SU.BY[n].key), "bold", 23, lx, y + 145, lw - 20, INK, 33)
		-- a game with two modes: pick the mode (each has its own lists and trophies)
		local modes = SU.BY[n].modes
		if modes then
			for i, m in ipairs(modes) do
				pill("su_m" .. i, AN.L("su_mode_" .. SU.BY[m].key), lx + (i - 1) * 300, y + 366, 288, 50, m == n, function()
					self.n = m
				end)
			end
		end
		-- difficulty
		AN.Text(AN.L("su_diff"), "black", 22, lx, y + 430, INK)
		for i = 1, 3 do
			pill("su_d" .. i, AN.L("su_diff" .. i), lx + (i - 1) * 200, y + 466, 186, 52, d == i, function() SU.SetDiff(i) end)
		end
		AN.TextWrap(AN.L("su_diffinfo_" .. SU.BY[n].key .. d), "bold", 18, lx, y + 532, lw - 20, SEA, 26)
		SU.Button("su_start", AN.L("su_play"), lx, y + h - 120, 300, 80, function() UI.Open("game" .. n, { n = n }) end, 40)
		-- (Kapløb and Duel above the play button, inside the left column)
		if AN.VS then AN.VS.BoardButtons(n, lx, y + h - 196, 1) end
	end
	-- right: the highscores of the chosen difficulty
	local rx, rw = x + 760, w - 760 - 50
	AN.Box(rx - 24, y + 135, rw + 48, h - 135 - 30, Color(SEA.r, SEA.g, SEA.b, 20), 22)
	scoreList(n, d, rx, y + 160, rw, 12, self.state == "over" and self.entry or nil)
	-- close: back to the beach
	UI.CornerButtons(function() UI.Open(SU.SEASONS[season].screen) end)
end
