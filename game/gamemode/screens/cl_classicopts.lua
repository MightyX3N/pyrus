-- The settings of the classic and jul.tv2.dk looks: the original "Indstillinger" scroll from
-- main.swf (its paper, radio buttons, tick boxes, page arrows and "Luk"), with all of the game's
-- settings on it over a few pages, and the seasons as its last page.
AN = AN or {}
local UI, MG, TL, FL = AN.UI, AN.MG, AN.TL, AN.FL
local Save = AN.Save
local CL = AN.Classic
local O = {}
CL.Opt = O
local LIB = "cl"
local INK = Color(43, 30, 22)
local SOFT = Color(110, 82, 58)
local RED = Color(150, 30, 20)

O.page = 1
O.open = false

-- pages: the game, sound and language, screen and server, the seasons
local PAGES = { "set_cat_game", "set_cat_lang", "set_cat_server", "sea_title" }
local SEASONS = { "xmas", "summer", "newyear", "halloween", "easter" }

function O.Open(page)
	O.open = true
	O.page = page or O.page or 1
	O.season = O.season or "xmas"
	O.resetArm, O.resetDone = 0, 0
	O.clips = O.clips or {}
	AN.Sound("scroll_down")
end
function O.Close()
	if not O.open then return end
	O.open = false
	AN.Sound("scroll_up")
	Save.Write()
	if O.onClose then O.onClose() end
end
function O.IsOpen() return O.open end

---------------------------------------------------------------------------
-- drawing in document coordinates (ox, oy = where the 800 x 600 document is in the stage)
---------------------------------------------------------------------------
local ox, oy = 0, 0
local function M(x, y) return { 1, 0, 0, 1, ox + (x or 0), oy + (y or 0) } end
local function pic(cid, x, y, sx, sy, a)
	local ch = AN.FLib[LIB].chars[cid]
	if not ch or ch[1] ~= "img" then return end
	TL.Pic(ch[2], ch[3], ch[4], ch[5], ch[6], { sx or 1, 0, 0, sy or 1, ox + x, oy + y }, a or 1)
end
local function text(str, x, y, size, col, anchor, maxW, face)
	TL.Text(str, face or "bold", size, ox + x, oy + y, nil, col or INK, 1, maxW, anchor == nil and true or anchor)
end
local function width(str, size, face)
	surface.SetFont(AN.Font(face or "bold", math.max(6, math.floor(MG.S(size)))))
	return (surface.GetTextSize(str)) / AN.S / MG.k
end
-- a click area in document coordinates
local function button(id, x, y, w, h, fn, opts)
	return UI.Button("copt_" .. id, MG.x0 + (ox + x) * MG.k, MG.y0 + (oy + y) * MG.k, w * MG.k, h * MG.k, fn,
		opts or { silent = true })
end
local function click(fn) return function(...) AN.Sound("click") fn(...) end end

-- a clip from main.swf, drawn and kept playing
local function clip(key, cid, x, y, s)
	local c = O.clips[key]
	if not c then c = FL.New(LIB, cid) O.clips[key] = c end
	FL.Draw(c, { s or 1, 0, 0, s or 1, ox + x, oy + y })
	return c
end

-- the original radio button: a ring, with the red dot when chosen
local function radio(id, x, y, label, on, fn, size)
	size = size or 13
	local tw = width(label, size)
	local hot = button(id, x - 11, y - 11, tw + 34, 22, click(fn))
	pic(940, x, y)
	if on then pic(941, x, y) end
	text(label, x + 16, y, size, hot and RED or INK, true, 230 - (x - 250))
	return x + 16 + tw + 18
end
-- the original tick box
local function tick(id, x, y, label, on, fn)
	local hot = button(id, x - 10, y - 10, 250, 20, click(function() fn(not on) end))
	pic(932, x, y)
	if on then pic(933, x + 0.3, y - 5.25) end
	text(label, x + 16, y, 13, hot and RED or INK, true, 230)
end
-- a small paper button like "Luk"
local function paperButton(id, x, y, label, fn, col)
	local w = math.max(44, width(label, 12) + 18)
	local hot = button(id, x - w / 2, y - 13, w, 26, click(fn))
	pic(841, x, y, w / 27, 1.42)
	text(label, x, y, 12, col or (hot and RED or INK), false)
	return hot
end
-- a slider: a thin line with the radio ring as the knob
local function slider(id, x, y, w, value, fn)
	local function set(vx)
		local dx = (vx - MG.x0) / MG.k - ox
		fn(math.Clamp(math.Round((dx - x) / w * 100), 0, 100))
	end
	button(id, x - 8, y - 10, w + 16, 20, nil, { silent = true, press = function(vx)
		set(vx)
		UI.BeginDrag({ move = function(vx2) set(vx2) end, release = function() Save.Write() end })
	end })
	AN.Box(MG.X(ox + x), MG.Y(oy + y - 1.5), MG.S(w), MG.S(3), SOFT)
	AN.Box(MG.X(ox + x), MG.Y(oy + y - 1.5), MG.S(w * value / 100), MG.S(3), RED)
	pic(940, x + w * value / 100, y)
	pic(941, x + w * value / 100, y)
end
local function heading(str, y)
	text(str, 245, y, 15, INK, true, 270)
end

---------------------------------------------------------------------------
-- the pages
---------------------------------------------------------------------------
local X0 = 250
local function pageGame()
	local y = 182
	heading(AN.L("set_look") .. ":", y)
	y = y + 20
	radio("look1", X0 + 12, y, AN.L("set_modern"), (Save.Get("look") or "modern") == "modern", function() Save.Set("look", "modern") end)
	y = y + 20
	radio("look2", X0 + 12, y, AN.L("set_classic"), Save.Get("look") == "classic", function() Save.Set("look", "classic") end)
	y = y + 20
	radio("look3", X0 + 12, y, AN.L("set_tv2"), Save.Get("look") == "tv2", function() Save.Set("look", "tv2") end)
	y = y + 32
	heading(AN.L("set_doors") .. ":", y)
	y = y + 20
	radio("door1", X0 + 12, y, AN.L("set_follow_date"), Save.Get("doorRule") ~= "progress", function() Save.Set("doorRule", "date") end)
	y = y + 20
	radio("door2", X0 + 12, y, AN.L("set_next_after"), Save.Get("doorRule") == "progress", function() Save.Set("doorRule", "progress") end)
	y = y + 34
	tick("hidden", X0 + 2, y, AN.L("set_hidden"), Save.Get("hidden") ~= false, function(v) Save.Set("hidden", v) end)
	y = y + 24
	tick("hints", X0 + 2, y, AN.L("set_hints"), Save.Get("hints") ~= false, function(v) Save.Set("hints", v) end)
	y = y + 24
	tick("blur", X0 + 2, y, AN.L("set_blur"), Save.Get("blur") ~= false, function(v) Save.Set("blur", v) end)
end

local function pageLang()
	local y = 182
	heading(AN.L("set_language") .. ":", y)
	y = y + 20
	local nx = radio("lang1", X0 + 12, y, "Dansk", Save.Get("lang") ~= "en", function() Save.Set("lang", "da") end)
	radio("lang2", nx, y, "English", Save.Get("lang") == "en", function() Save.Set("lang", "en") end)
	y = y + 30
	tick("subs", X0 + 2, y, AN.L("set_subs"), Save.Get("subs"), function(v) Save.Set("subs", v) end)
	y = y + 34
	heading(AN.L("cl_volume") .. ":", y)
	y = y + 24
	for _, v in ipairs({ { "vol_music", "set_music" }, { "vol_fx", "set_fx" }, { "vol_voice", "set_voice" } }) do
		text(AN.L(v[2]), X0 + 2, y, 13, INK, true, 80)
		local val = Save.Get(v[1]) or 0
		slider(v[1], X0 + 80, y, 135, val, function(nv) Save.Data().settings[v[1]] = nv end)
		text(tostring(val), X0 + 250, y, 12, SOFT, "right")
		y = y + 26
	end
end

local function pageServer()
	local y = 182
	tick("share", X0 + 2, y, AN.L("set_share"), Save.Get("share"), function(v) Save.Set("share", v) end)
	y = y + 40
	-- reset needs two clicks
	heading(AN.L("set_reset") .. ":", y)
	y = y + 26
	local armed = RealTime() - O.resetArm < 3
	local done = RealTime() - O.resetDone < 2
	local label = done and AN.L("set_reset_done") or (armed and AN.L("set_reset_confirm") or AN.L("set_reset_btn"))
	local w = math.max(44, width(label, 12) + 18)
	paperButton("reset", X0 + 8 + w / 2, y, label, function()
		if armed then
			Save.Reset()
			O.resetArm = 0
			O.resetDone = RealTime()
		else
			O.resetArm = RealTime()
		end
	end, armed and RED or nil)
end

-- the seasons: Christmas is the calendar; the others are coming
local function seasonCount(id)
	if id == "xmas" then return AN.Save.DoneCount(), 24 end
	if (id == "summer" or id == "halloween") and AN.Summer then return AN.Summer.TrophyCount(id) end
	return 0, ({ summer = 15, newyear = 12, halloween = 12, easter = 12 })[id] or 12
end
local function pageSeasons()
	local y = 178
	for i, id in ipairs(SEASONS) do
		local got, tot = seasonCount(id)
		radio("sea" .. i, X0 + 12, y, AN.L("sea_" .. id), O.season == id, function() O.season = id end)
		text((id == "xmas" or id == "summer" or id == "halloween") and AN.L("sea_count", got, tot) or AN.L("coming_soon"), X0 + 252, y, 11, SOFT, "right")
		y = y + 20
	end
	y = y + 14
	local s = O.season
	heading(AN.L("sea_games") .. ":", y)
	y = y + 18
	local lines = AN.Wrap(AN.L("sea_" .. s .. "_games"), "bold", MG.S(12), MG.S(260))
	for _, l in ipairs(lines) do
		text(l, X0 + 2, y, 12, INK, true, 265)
		y = y + 16
	end
	y = y + 18
	if s == "xmas" then
		paperButton("tocal", X0 + 60, y, AN.L("sea_to_cal"), function() O.Close() end)
	elseif s == "summer" then
		paperButton("tobeach", X0 + 60, y, AN.L("sea_to_beach"), function()
			O.open = false
			Save.Write()
			UI.Open("sommer")
		end)
	elseif s == "halloween" then
		paperButton("tohouse", X0 + 60, y, AN.L("sea_to_house"), function()
			O.open = false
			Save.Write()
			UI.Open("halloween")
		end)
	else
		text(AN.L("sea_soon"), X0 + 2, y, 12, SOFT, true, 265)
	end
end

local DRAW = { pageGame, pageLang, pageServer, pageSeasons }

-- the scroll over the screen (dx, dy = the 800 x 600 document's place in the current stage)
function O.Draw(dx, dy)
	if not O.open then return end
	ox, oy = dx or 0, dy or 0
	-- (clicks outside the scroll do nothing while it is open)
	UI.Button("copt_block", MG.x0 - 4000, MG.y0 - 4000, 9000, 9000, nil, { silent = true, press = function() end })
	pic(927, 0, 0)
	-- the heading: "Indstillinger" on the first page, the page's name after it
	if O.page == 1 then
		pic(931, 212.75, 122.6)
	else
		text(AN.L(PAGES[O.page]), 385, 140, 22, INK, false, 250, "title")
	end
	DRAW[O.page]()
	-- the pages: the arrows from the help pages, and the page number between them
	local n = #PAGES
	text(O.page .. " / " .. n, 312, 442, 12, SOFT, false)
	if O.page > 1 then
		local hot = button("prev", 252, 430, 40, 24, click(function() O.page = O.page - 1 end))
		clip("prev", 709, 272, 442, hot and 0.75 or 0.68)
	end
	if O.page < n then
		local hot = button("next", 332, 430, 40, 24, click(function() O.page = O.page + 1 end))
		clip("next", 714, 352, 442, hot and 0.75 or 0.68)
	end
	-- Luk
	local hot = button("luk", 420, 428, 46, 28, click(function() O.Close() end))
	pic(841, 442.45, 441.6, 1.652, 1.422)
	pic(938, 431.35, 434.8)
	if hot then pic(841, 442.45, 441.6, 1.652, 1.422, 0.25) end
end

-- the clips on the scroll keep playing (25 fps)
function O.Tick()
	if not O.open then return end
	for _, c in pairs(O.clips or {}) do FL.Tick(c) end
end
