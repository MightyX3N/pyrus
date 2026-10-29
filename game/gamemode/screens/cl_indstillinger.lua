-- Indstillinger: four categories on the left, their settings on the right. Saved instantly.
local UI, C = AN.UI, AN.Col
local Save = AN.Save
local S = {}
AN.Screens.indstillinger = S

function S:Open(args)
	self.cat = args.cat or "game"
	self.resetArm = 0
	self.resetDone = 0
end

-- a settings card with title + description; returns y after the card, and the y for controls
local function card(x, y, w, title, sub, h)
	local lines = AN.Wrap(sub, "bold", 19, w - 56 - (h and 0 or 0))
	local textH = 34 + #lines * 26
	h = h or (24 + textH + 16 + 64 + 24)
	UI.Card(x, y, w, h)
	AN.Text(title, "black", 26, x + 28, y + 22, C.white)
	for i, l in ipairs(lines) do AN.Text(l, "bold", 19, x + 28, y + 58 + (i - 1) * 26, C.sand) end
	return y + h + 16, y + 24 + textH + 16
end

-- card with the toggle on the right side
local function toggleHeight(w, sub) return 24 + 34 + #AN.Wrap(sub, "bold", 19, w - 56 - 160) * 26 + 24 end
local function toggleCard(id, x, y, w, title, sub, value, onToggle, hmin)
	local lines = AN.Wrap(sub, "bold", 19, w - 56 - 160)
	local h = math.max(hmin or 0, 24 + 34 + #lines * 26 + 24)
	UI.Card(x, y, w, h)
	AN.Text(title, "black", 26, x + 28, y + 22, C.white)
	for i, l in ipairs(lines) do AN.Text(l, "bold", 19, x + 28, y + 58 + (i - 1) * 26, C.sand) end
	UI.Toggle(id, x + w - 140, y + h / 2 - 20, value, onToggle)
	return y + h + 16
end

function S:Paint()
	local R = AN.R
	UI.Background("sub")
	UI.Shade("settings")
	UI.BackButton("main")

	local x, y = 110, 170
	AN.Img("ui/indstillinger.png", x, y, 300)
	y = y + 300 * AN.Ratio("ui/indstillinger.png") + 26
	local cats = {
		{ "game", AN.L("set_cat_game") },
		{ "lang", AN.L("set_cat_lang") },
		{ "screen", AN.L("set_cat_screen") },
		{ "server", AN.L("set_cat_server") },
	}
	local heading
	for _, c in ipairs(cats) do
		if c[1] == self.cat then heading = c[2] end
		UI.ListItem("cat_" .. c[1], x, y, 600, 84, c[2], nil, nil, self.cat == c[1], function() self.cat = c[1] end, nil, 40)
		y = y + 94
	end

	local rx, ry, rw = 860 + AN.C, 150, 960
	AN.Text(heading or "", "title", 56, rx, ry, C.white)
	ry = ry + 90

	if self.cat == "game" then
		local ny, cy = card(rx, ry, rw, AN.L("set_look"), AN.L("set_look_sub"))
		UI.Choice("look", rx + 28, cy, rw - 56, 64,
			{ { AN.L("set_modern"), "modern" }, { AN.L("set_classic"), "classic" }, { AN.L("set_tv2"), "tv2" } },
			Save.Get("look") or "modern", function(v) Save.Set("look", v) end)
		ry = ny
		ny, cy = card(rx, ry, rw, AN.L("set_doors"), AN.L("set_doors_sub"))
		UI.Choice("doors", rx + 28, cy, rw - 56, 64,
			{ { AN.L("set_follow_date"), "date" }, { AN.L("set_next_after"), "progress" } },
			Save.Get("doorRule"), function(v) Save.Set("doorRule", v) end)
		ry = ny
		-- hidden content and hints side by side
		local hw = (rw - 16) / 2
		local th = math.max(toggleHeight(hw, AN.L("set_hidden_sub")), toggleHeight(hw, AN.L("set_hints_sub")))
		toggleCard("hidden", rx, ry, hw, AN.L("set_hidden"), AN.L("set_hidden_sub"), Save.Get("hidden"),
			function(v) Save.Set("hidden", v) end, th)
		ry = toggleCard("hints", rx + hw + 16, ry, hw, AN.L("set_hints"), AN.L("set_hints_sub"), Save.Get("hints") ~= false,
			function(v) Save.Set("hints", v) end, th)

		-- reset needs two clicks
		local lines = AN.Wrap(AN.L("set_reset_sub"), "bold", 19, rw - 56 - 260)
		local h = 24 + 34 + #lines * 26 + 24
		UI.Card(rx, ry, rw, h)
		AN.Text(AN.L("set_reset"), "black", 26, rx + 28, ry + 22, C.white)
		for i, l in ipairs(lines) do AN.Text(l, "bold", 19, rx + 28, ry + 58 + (i - 1) * 26, C.sand) end
		local armed = RealTime() - self.resetArm < 3
		local done = RealTime() - self.resetDone < 2
		local label = done and AN.L("set_reset_done") or (armed and AN.L("set_reset_confirm") or AN.L("set_reset_btn"))
		local bw = math.max(150, AN.TextSize(label, "bold", 22) + 52)
		local bx, by = rx + rw - 28 - bw, ry + h / 2 - 30
		local hot = UI.Button("reset", bx, by, bw, 60, function()
			if armed then
				Save.Reset()
				self.resetArm = 0
				self.resetDone = RealTime()
			else
				self.resetArm = RealTime()
			end
		end)
		if armed then AN.Box(bx, by, bw, 60, Color(200, 32, 45, 200), 16) end
		AN.Outline(bx, by, bw, 60, C.bad, 16, 2)
		AN.Text(label, "bold", 22, bx + bw / 2, by + 30, (armed or hot) and C.white or C.badText, 1, 1)

	elseif self.cat == "lang" then
		local ny, cy = card(rx, ry, rw, AN.L("set_language"), AN.L("set_language_sub"))
		UI.Choice("lang", rx + 28, cy, rw - 56, 64, { { "Dansk", "da" }, { "English", "en" } },
			Save.Get("lang"), function(v) Save.Set("lang", v) end)
		ry = ny
		-- subtitles with an example line
		local lines = AN.Wrap(AN.L("set_subs_sub"), "bold", 19, rw - 56 - 160)
		local h = 24 + 34 + #lines * 26 + 24 + 70
		UI.Card(rx, ry, rw, h)
		AN.Text(AN.L("set_subs"), "black", 26, rx + 28, ry + 22, C.white)
		for i, l in ipairs(lines) do AN.Text(l, "bold", 19, rx + 28, ry + 58 + (i - 1) * 26, C.sand) end
		UI.Toggle("subs", rx + rw - 140, ry + 30, Save.Get("subs"), function(v) Save.Set("subs", v) end)
		if Save.Get("subs") then
			AN.Box(rx + 28, ry + h - 24 - 58, rw - 56, 58, Color(0, 0, 0, 140), 14)
			AN.Text(AN.L("set_sub_example"), "bold", 24, rx + rw / 2, ry + h - 24 - 29, C.white, 1, 1)
		end
		ry = ry + h + 16
		-- volumes
		UI.Card(rx, ry, rw, 3 * 52 + 48)
		local vols = { { "vol_music", "set_music" }, { "vol_fx", "set_fx" }, { "vol_voice", "set_voice" } }
		for i, v in ipairs(vols) do
			local ly = ry + 24 + (i - 1) * 52
			AN.Text(AN.L(v[2]), "black", 24, rx + 28, ly + 17, C.white, 0, 1)
			local val = Save.Get(v[1]) or 0
			UI.Slider(v[1], rx + 250, ly, rw - 250 - 110, val, function(nv)
				if nv ~= Save.Get(v[1]) then Save.Data().settings[v[1]] = nv end
			end)
			AN.Text(tostring(val), "black", 24, rx + rw - 28, ly + 17, C.gold, 2, 1)
		end

	elseif self.cat == "screen" then
		ry = toggleCard("blur", rx, ry, rw, AN.L("set_blur"), AN.L("set_blur_sub"), Save.Get("blur") ~= false,
			function(v) Save.Set("blur", v) end)

	else
		ry = toggleCard("share", rx, ry, rw, AN.L("set_share"), AN.L("set_share_sub"), Save.Get("share"),
			function(v) Save.Set("share", v) end)
	end

	UI.CornerButtons()
end

-- volume sliders write to the save file once the mouse is released
function S:Think()
	if not input.IsMouseDown(MOUSE_LEFT) and self.dirty then
		Save.Write()
		self.dirty = false
	end
	if input.IsMouseDown(MOUSE_LEFT) and UI.drag then self.dirty = true end
end
