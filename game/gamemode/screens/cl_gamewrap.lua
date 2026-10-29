-- The original game wrapper from main.swf, shown around every calendar game:
--   "start"  board with the game's logo, Start / Hjælp and the highscore scroll (Pyrus says the intro)
--   "help"   the original Hjælp pages on the scroll, with arrows (Pyrus explains the game)
--   "over"   "Du har vundet pebernødder": the nuts fill up one by one, and when you have
--            enough the star comes with your new piece of julepynt (Pyrus: "Meget godt")
-- Everything is drawn from the original artwork at the original positions (AN.WrapPos),
-- scaled to the screen height and centred, so it looks the same on 16:9 and ultrawide.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.gamewrap = S
S.garland = false

local WP = AN.WrapPos
local INK = Color(31, 29, 58)
local SLUG = { "hop", "bibliotekandis", "biblioteksraes", "huskespillet", "labyrint", "dansespil", "badetid",
	"pebergroed", "arkivraes", "gaaseflyvning", "puslespil", "kaalhovedskydning", "denroedehane", "fotoskubber",
	"rotter", "bertramsen", "kiks", "sneboldkamp", "rumtur", "saettekasse", "fodaftryk", "andersen",
	"flyttepakning", "pyntekasse" }
AN.GameSlug = SLUG

local COIN_STEP = 6 / 25      -- a new nut every 6 frames, like the original
local REWARD = { x = 131.45, y = 299.45 }

-- panel space -> virtual screen (the board area -55..825 x -35..640 fills the height)
local k, ox, oy = 1, 0, 0
local function layout()
	k = math.min(1080 / 700, AN.VW / 910)
	ox = (AN.VW - 910 * k) / 2 + 62 * k
	oy = (1080 - 700 * k) / 2 + 48 * k
end

local function X(x) return ox + x * k end
local function Y(y) return oy + y * k end

-- the board's own edge is (-20, -15) .. (819, 614): a wooden frame around it, like the game screens
local BOARD = { -20, -15, 839, 629 }
local FRAME = 26
local function boardFrame()
	local x, y = X(BOARD[1] - FRAME), Y(BOARD[2] - FRAME)
	local w, h = (BOARD[3] + 2 * FRAME) * k, (BOARD[4] + 2 * FRAME) * k
	AN.Box(x + 6, y + 16, w, h, Color(0, 0, 0, 110), 14)
	AN.ImgCover("ui/woodboard.png", x, y, w, h)
	AN.Box(x, y, w, h, Color(40, 14, 2, 150))
	AN.Outline(x, y, w, h, Color(30, 10, 2, 200), 0, 3)
	AN.Outline(x + 3, y + 3, w - 6, h - 6, Color(255, 200, 140, 40), 0, 2)
	AN.Box(X(BOARD[1]) - 5, Y(BOARD[2]) - 5, BOARD[3] * k + 10, BOARD[4] * k + 10, Color(74, 31, 7))
end

local function part(name, alpha, sc, img)
	local r = WP[name]
	if not r then return end
	sc = sc or 1
	local w, h = r[3] * k * sc, r[4] * k * sc
	AN.Img("wrap/" .. (img or name) .. ".png", X(r[1] + r[3] / 2) - w / 2, Y(r[2] + r[4] / 2) - h / 2, w, h, alpha)
end

-- a plank button: the original image grows a little when the mouse is over it
local function plank(id, name, fn, img, opts)
	local r = WP[name]
	local hot = UI.Button(id, X(r[1]), Y(r[2]), r[3] * k, r[4] * k, fn, opts)
	part(name, 255, hot and 1.04 or 1, img)
	return hot
end

function S:Open(args)
	self.n = args.n or 4
	self.state = args.state or "start"
	self.page = 1
	self.res = args.res
	self.value = args.value
	self.entry = args.entry
	self.t0 = RealTime()
	self.shown = 0
	self.starAt = nil
	self.saidStar = false
	if self.res then self.shown = self.res.oldCoins end
	local slug = SLUG[self.n]
	-- Pyrus introduces the game and explains it (unless he is already doing that from the calendar)
	if self.state == "start" and not args.quiet and not AN.VoiceBusy() then
		AN.SpeakChain({ slug .. "_intro", "help_" .. slug })
	end
end

function S:SetState(st)
	self.state = st
	self.page = 1
	if st == "help" then AN.Speak("help_" .. SLUG[self.n]) else AN.StopSpeech() end
end

function S:Think()
	if self.state ~= "over" or not self.res then return end
	local res = self.res
	local target = math.min(res.oldCoins + res.won, res.price)
	local want = res.oldCoins + math.floor((RealTime() - self.t0 - 0.6) / COIN_STEP) + 1
	want = math.Clamp(want, res.oldCoins, target)
	while self.shown < want do
		self.shown = self.shown + 1
		AN.Sound("triangel")
	end
	if self.shown >= target and res.item and not self.starAt then
		self.starAt = RealTime() + 0.35
	end
	if self.starAt and not self.saidStar and RealTime() >= self.starAt then
		self.saidStar = true
		AN.Speak("megetgodt")
	end
end

---------------------------------------------------------------------------
local function closeBtn(n)
	-- the X is part of the board artwork
	UI.Button("wrap_close", X(742), Y(0), 60 * k, 60 * k, function() UI.Open("kalender", { door = n }) end,
		{ voice = { "luk_rollover", 45 / 25 } })
	if UI.Hot("wrap_close") then AN.Glow(X(772), Y(30), 44 * k, C.gold, 0.35) end
end

-- the shared highscore list: place, result (+ the hint mark), and who got it.
-- Clicking a row opens that player's profile.
local function scoreList(n, y0, entry, back)
	local x, y, w = 470, y0 or 236, 270
	local size = math.floor(20 * k)
	-- games with levels: a tab for the whole game and one for each level
	local level, th = AN.ScoreTabs(n, X(x - 6), Y(y), (w + 12) * k, k, INK, "hs_tab")
	y = y + th / k
	local list = AN.Save.Scores(n, level)
	local rows = th > 0 and 9 or 10
	if #list == 0 then
		AN.TextWrap(AN.L("wrap_noscores"), "bold", size, X(x), Y(y), w * k, INK, 22 * k)
		return
	end
	local me = AN.Save.MySid()
	for i = 1, math.min(rows, #list) do
		local e = list[i]
		local yy = Y(y + (i - 1) * 30)
		local id = "hs_row" .. i
		local hot = UI.Button(id, X(x - 6), yy - 3 * k, (w + 12) * k, 28 * k, function()
			AN.UI.Open("profil", { sid = e.sid, back = back })
		end, { silent = true })
		if entry and e.id == entry then
			AN.Box(X(x - 6), yy - 3 * k, (w + 12) * k, 28 * k, Color(255, 215, 106), 6 * k)
		elseif hot then
			AN.Box(X(x - 6), yy - 3 * k, (w + 12) * k, 28 * k, Color(INK.r, INK.g, INK.b, 28), 6 * k)
		end
		AN.Text(i .. ".", "black", size, X(x + 24), yy, INK, 2)
		local vs = AN.FormatValue(n, e.v)
		AN.Text(vs, "black", size, X(x + 36), yy, INK)
		local vx = X(x + 36) + AN.TextSize(vs, "black", size)
		if e.h then AN.HintMark(vx + 13 * k, yy + 11 * k, 9 * k) end
		local nx = vx + (e.h and 28 or 12) * k
		local col = e.sid == me and Color(138, 42, 10) or Color(INK.r, INK.g, INK.b, 200)
		AN.TextEllipsis(e.name or "?", "bold", math.floor(17 * k), X(x + w), yy + 2 * k, X(x + w) - nx, col, 2)
	end
end

function S:PaintStart()
	local n = self.n
	part("start_board")
	part("scroll")
	if AN.LangCode() == "da" then
		part("start_scrolltxt")
	else
		AN.Text(AN.L("wrap_hiscore"), "title", math.floor(34 * k), X(616), Y(104), INK, 1)
		AN.TextWrap(AN.L("wrap_hiscore_sub"), "bold", math.floor(16 * k), X(467), Y(158), 245 * k, INK, 21 * k)
	end
	scoreList(n, nil, nil, { "gamewrap", { n = n, state = "start", quiet = true } })
	part(string.format("logo%02d", n))
	plank("wrap_start", "btn_start", function() self:Go() end)
	plank("wrap_help", "btn_help", function() self:SetState("help") end,
		AN.LangCode() ~= "da" and "btn_help_en" or nil)
	if AN.VS then AN.VS.BoardButtons(n, X(24), Y(540), k) end
	closeBtn(n)
end

function S:PaintHelp()
	local n = self.n
	part("help_base")
	if AN.LangCode() == "da" then
		part("help_title")
	else
		AN.Text(AN.L("wrap_help"), "title", math.floor(34 * k), X(600), Y(136), INK, 1)
	end
	-- the original page; in English the same page without its text, and the text translated
	local key = string.format("help%02d_%d", n, self.page)
	local en = AN.LangCode() ~= "da" and AN.Lang[AN.LangCode()][string.format("help_%02d_%d", n, self.page)]
	if istable(en) then
		part(key .. "_notext", 255, 1, key .. "_notext")
		local blocks = AN.HelpText[n .. "_" .. self.page] or {}
		for i, b in ipairs(blocks) do
			if en[i] then
				AN.TextWrap(en[i], "bold", math.floor(15.5 * k), X(b[1]), Y(b[2]), (b[3] + 6) * k, INK, 20.5 * k)
			end
		end
	else
		part(key)
	end
	local pages = AN.HelpPages[n] or 1
	if pages > 1 then
		local function arrow(id, name, d)
			local r = WP[name]
			local ok = (d < 0 and self.page > 1) or (d > 0 and self.page < pages)
			if ok then
				UI.Button(id, X(r[1] - 8), Y(r[2] - 14), (r[3] + 16) * k, (r[4] + 28) * k, function()
					self.page = math.Clamp(self.page + d, 1, pages)
				end)
			end
			part(name, ok and 255 or 70, UI.Hot(id) and 1.15 or 1)
		end
		arrow("wrap_prev", "help_prev", -1)
		arrow("wrap_next", "help_next", 1)
	end
	part(string.format("logo%02d", n))
	plank("wrap_start", "btn_start", function() self:Go() end)
	plank("wrap_hiscore", "btn_hiscore", function() self:SetState("start") end)
	if AN.VS then AN.VS.BoardButtons(n, X(24), Y(540), k) end
	closeBtn(n)
end

-- the game's logo on the game-over board is the same artwork at 0.8 scale around (103.8, 64.15)
local function goLogo(n)
	local r = WP[string.format("go_logo%02d", n)]
	if not r then return end
	local px, py, s = 103.8, 64.15, 0.8
	AN.Img(string.format("wrap/go_logo%02d.png", n), X(px + (r[1] - px) * s), Y(py + (r[2] - py) * s), r[3] * s * k, r[4] * s * k)
end

function S:PaintOver()
	local n, res = self.n, self.res
	part("go_base")
	goLogo(n)

	-- the right half held an advert in the original: the highscore scroll goes there,
	-- with the result you just got marked
	part("scroll")
	AN.Text(AN.L("wrap_hiscore"), "title", math.floor(34 * k), X(610), Y(104), INK, 1)
	scoreList(n, 170, self.entry, { "gamewrap", { n = n, state = "start", quiet = true } })

	AN.Text(AN.L("wrap_won"), "bold", math.floor(17 * k), X(16), Y(160), C.white)

	-- the nut grid: 40 slots, filled up to what you have towards the next ornament
	local cr = WP.coin_on
	for i = 0, 39 do
		local col, row = i % 8, math.floor(i / 8)
		local cx, cy = REWARD.x - 104.8 + 30 * col, REWARD.y - 56 + 28 * row
		local on = i < self.shown
		local pop = 1
		if on and i >= res.oldCoins then
			local t = RealTime() - self.t0 - 0.6 - (i - res.oldCoins) * COIN_STEP
			pop = 1 + 0.35 * math.max(0, 1 - t / 0.2)
		end
		local w, h = cr[3] * k * pop, cr[4] * k * pop
		AN.Img(on and "wrap/coin_on.png" or "wrap/coin_off.png",
			X(cx + cr[1] + cr[3] / 2) - w / 2, Y(cy + cr[2] + cr[4] / 2) - h / 2, w, h)
	end

	-- messages (original wording)
	local won = res.won
	local msg
	if won < 8 then msg = AN.L("wrap_won_lt8", won)
	elseif won < 10 then msg = AN.L("wrap_won_lt10", won)
	else msg = AN.L("wrap_won_10", won) end
	local y = Y(372)
	y = y + AN.TextWrap(msg, "bold", math.floor(15 * k), X(16), y, 262 * k, C.white, 19 * k) + 4 * k
	if res.item then
		if self.starAt and RealTime() >= self.starAt then
			AN.TextWrap(AN.L("wrap_got_item"), "bold", math.floor(15 * k), X(16), y, 262 * k, C.gold, 19 * k)
		end
	else
		AN.TextWrap(AN.L("box_need", res.price - res.coins), "bold", math.floor(15 * k), X(16), y, 262 * k, C.cream, 19 * k)
	end

	-- the star with the new ornament, over the nuts
	if self.starAt and RealTime() >= self.starAt then
		local t = RealTime() - self.starAt
		local a = math.Clamp(t / 0.25, 0, 1)
		local s = t < 0.3 and (0.4 + 0.8 * (t / 0.3)) or (1.2 - 0.2 * math.min(1, (t - 0.3) / 0.25))
		local cx, cy = X(REWARD.x), Y(REWARD.y)
		AN.Glow(cx, cy, 190 * k * s, Color(255, 250, 220), 0.9 * math.max(0, 1 - t / 0.8))
		local sr = WP.star
		AN.ImgRotated("wrap/star.png", cx, cy, sr[3] * k * s, sr[4] * k * s, math.sin(t * 0.8) * 6, 255 * a)
		local ox2, oy2, ow, oh = AN.OrnamentRect(res.item.id, 2.3 * k * s)
		AN.Img(res.item.img, cx - ow / 2, cy - oh / 2, ow, oh, 255 * a)
	end

	plank("wrap_videre", "go_videre", function() UI.Open("gamewrap", { n = n, state = "start", quiet = true }) end,
		AN.LangCode() ~= "da" and "go_videre_en" or nil)
	closeBtn(n)
end

function S:Go()
	AN.Sound("click")
	UI.Open("game" .. self.n, { n = self.n })
end

function S:Paint()
	layout()
	UI.Background("sub")
	AN.Box(0, -(AN.OY or 0), AN.VW, AN.VH or 1080, Color(20, 8, 2, 120))
	self:Think()
	boardFrame()
	if self.state == "help" then self:PaintHelp()
	elseif self.state == "over" and self.res then self:PaintOver()
	else self:PaintStart() end
	if X(-60) > 300 then AN.MG.SideGarland() end
end
