-- Fullscreen UI: one root panel, immediate-mode buttons, screen manager and
-- the shared "Menu B" chrome (blurred loft, dark left side, back pill, corner buttons).
AN = AN or {}
AN.UI = AN.UI or {}
AN.Screens = AN.Screens or {}
local UI = AN.UI
local C = AN.Col

UI.regions = {}
UI.hot = nil
UI.mx, UI.my = 0, 0
UI.screen = nil
UI.screenName = nil
UI.fade = 0
UI.time = 0

---------------------------------------------------------------------------
-- Screen manager
---------------------------------------------------------------------------
function UI.Open(name, args)
	if name == "gamewrap" and args and (args.n or 0) > 100 then name = "sgame" end
	local scr = AN.Screens[name]
	if not scr then
		ErrorNoHalt("[Alletiders Nisse] unknown screen " .. tostring(name) .. "\n")
		return
	end
	if UI.screen and UI.screen.Close then UI.screen:Close() end
	if not (args and args.keepVoice) then AN.StopSpeech() end
	UI.screenName = name
	UI.screen = scr
	-- a game screen opening starts a new run of that game
	local gn = tonumber(string.match(name, "^game(%d+)$") or "")
	if gn and AN.NewRun then AN.NewRun(gn) end
	UI.openedAt = RealTime()
	UI.fade = 1
	UI.drag = nil
	if scr.Open then scr:Open(args or {}) end
end

function UI.Start()
	if IsValid(UI.root) then UI.root:Remove() end
	local p = vgui.Create("DPanel")
	p:SetPos(0, 0)
	p:SetSize(ScrW(), ScrH())
	p:MakePopup()
	p:SetKeyboardInputEnabled(false)
	p:SetMouseInputEnabled(true)
	p.Paint = function(self, w, h) UI.Frame(w, h) end
	p.OnMousePressed = function(self, code) UI.MousePressed(code) end
	p.OnMouseReleased = function(self, code) UI.MouseReleased(code) end
	p.OnMouseWheeled = function(self, d)
		if UI.screen and UI.screen.Wheel then UI.screen:Wheel(d) end
	end
	AN.MusicOn()
	p.Think = function(self)
		if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
			self:SetSize(ScrW(), ScrH())
			AN.UpdateScale()
		end
		if UI.screen and UI.screen.Think then UI.screen:Think(FrameTime()) end
	end
	UI.root = p
	UI.Open("main")
	-- the original greeting: a special line the very first time, another one after that
	if not UI.greeted then
		UI.greeted = true
		if AN.Save.Get("firsttime") ~= false then
			AN.Speak("start_first")
			AN.Save.Set("firsttime", false)
		else
			AN.Speak("start_igen")
		end
	end
end

-- a player's Steam avatar (a real vgui panel on top of the screen), square, virtual coords
function UI.Avatar(sid, x, y, size)
	UI.avatars = UI.avatars or {}
	local p = UI.avatars[sid]
	if not IsValid(p) and IsValid(UI.root) then
		p = vgui.Create("AvatarImage", UI.root)
		local ply
		for _, pl in ipairs(player.GetAll()) do
			if pl:SteamID64() == sid then ply = pl end
		end
		if sid == AN.Save.MySid() then ply = LocalPlayer() end
		if ply then p:SetPlayer(ply, 184) elseif sid ~= "local" then p:SetSteamID(sid, 184) end
		p:SetMouseInputEnabled(false)
		UI.avatars[sid] = p
	end
	if not IsValid(p) then return end
	UI.avatarUsed[sid] = true
	p:SetVisible(true)
	p:SetPos(AN.PX(x), AN.SY(y))
	p:SetSize(AN.SX(size), AN.SX(size))
end

---------------------------------------------------------------------------
-- Frame + input
---------------------------------------------------------------------------
function UI.Frame(w, h)
	UI.time = RealTime()
	local cx, cy = input.GetCursorPos()
	UI.mx = cx / AN.S - AN.OX
	UI.my = cy / AN.S - AN.OY
	UI.regions = {}
	UI.avatarUsed = {}

	surface.SetDrawColor(20, 10, 4, 255)
	surface.DrawRect(0, 0, w, h)

	if UI.screen and UI.screen.Paint then
		local ok, err = pcall(UI.screen.Paint, UI.screen)
		if not ok then
			ErrorNoHalt("[Alletiders Nisse] " .. tostring(err) .. "\n")
			draw.SimpleText(tostring(err), "DermaDefault", 10, 10, Color(255, 120, 120))
		end
		-- the menu screens get a garland of the original branches along the top
		if UI.screen.garland ~= false and AN.Deco then
			local ok2, err2 = pcall(AN.Deco.MenuGarland)
			if not ok2 then ErrorNoHalt("[Alletiders Nisse] " .. tostring(err2) .. "\n") end
		end
	end

	-- subtitles for what Pyrus says
	if AN.DrawSubtitle then
		local ok3, err3 = pcall(AN.DrawSubtitle)
		if not ok3 then ErrorNoHalt("[Alletiders Nisse] " .. tostring(err3) .. "\n") end
	end

	-- versus: invitations, the lobby, 3-2-1, the live scores, the results
	if AN.DrawVersus then
		local ok4, err4 = pcall(AN.DrawVersus)
		if not ok4 then ErrorNoHalt("[Alletiders Nisse] " .. tostring(err4) .. "\n") end
	end

	-- drag ghost drawn on top
	if UI.drag and UI.drag.draw then UI.drag.draw(UI.mx, UI.my) end

	-- Steam avatars not drawn this frame are hidden
	for sid, p in pairs(UI.avatars or {}) do
		if IsValid(p) and not UI.avatarUsed[sid] then p:SetVisible(false) end
	end

	-- the hot region is the last one (topmost) under the mouse
	local newHot
	for i = #UI.regions, 1, -1 do
		local r = UI.regions[i]
		if UI.mx >= r.x and UI.mx <= r.x + r.w and UI.my >= r.y and UI.my <= r.y + r.h and (not r.hit or r.hit(UI.mx, UI.my)) then
			newHot = r
			break
		end
	end
	local newId = newHot and newHot.id or nil
	if newId ~= UI.hot then
		local old = UI.hotRegion
		if newHot and (newHot.fn or newHot.press) and not newHot.silent then AN.Sound("over")
		elseif old and (old.fn or old.press) and not old.silent then AN.Sound("out") end
		UI.hoverStart = RealTime()
		UI.hoverVoiced = false
	end
	UI.hot = newId
	UI.hotRegion = newHot
	-- like the original: resting on some buttons makes Pyrus say something
	if newHot and newHot.voice and not UI.hoverVoiced and RealTime() - (UI.hoverStart or 0) >= newHot.voice[2] then
		UI.hoverVoiced = true
		AN.Speak(newHot.voice[1])
	end

	-- fade-in after changing screen
	if UI.fade > 0 then
		UI.fade = math.max(0, 1 - (RealTime() - UI.openedAt) / 0.25)
		surface.SetDrawColor(20, 8, 2, 255 * UI.fade)
		surface.DrawRect(0, 0, w, h)
	end
end

function UI.MousePressed(code)
	local r = UI.hotRegion
	if not r then return end
	if code == MOUSE_LEFT then
		if r.press then
			r.press(UI.mx, UI.my)
		elseif r.fn then
			if not r.silent then AN.Sound("click") end
			r.fn()
		end
	elseif code == MOUSE_RIGHT and r.right then
		r.right()
	end
end

function UI.MouseReleased(code)
	if code == MOUSE_LEFT and UI.drag then
		local d = UI.drag
		UI.drag = nil
		if d.release then d.release(UI.mx, UI.my) end
	end
end

-- start dragging: move(mx,my) called every frame by the screen through UI.drag, release(mx,my) on mouse up
function UI.BeginDrag(t) UI.drag = t end

-- register a clickable region. returns hovered
function UI.Button(id, x, y, w, h, fn, opts)
	local r = { id = id, x = x, y = y, w = w, h = h, fn = fn }
	if opts then
		r.silent = opts.silent
		r.press = opts.press
		r.right = opts.right
		r.voice = opts.voice
		r.hit = opts.hit      -- hit(mx, my): an exact shape test inside the rectangle (e.g. a Flash button's hit area)
	end
	UI.regions[#UI.regions + 1] = r
	return UI.hot == id
end

function UI.Hot(id) return UI.hot == id end

---------------------------------------------------------------------------
-- Shared chrome
---------------------------------------------------------------------------
-- kind: "menu" (main menu, lighter), "sub" (sub screens), "box" (decoration box, more blur)
function UI.Background(kind, zoom)
	local sw, sh = ScrW(), ScrH()
	local path = "bg/" .. (kind or "sub") .. ".jpg"
	if AN.Save.Get("blur") == false then path = "bg/loft.jpg" end
	local m = AN.Mat(path)
	-- cover the whole screen (image is 16:9)
	local iw, ih = sw, sw * 9 / 16
	if ih < sh then ih = sh; iw = sh * 16 / 9 end
	zoom = zoom or 1
	iw, ih = iw * zoom, ih * zoom
	local col = 255
	if path == "bg/loft.jpg" then col = (kind == "menu") and 204 or 158 end
	surface.SetDrawColor(col, col, col, 255)
	surface.SetMaterial(m)
	-- bottom of the loft image stays at the bottom of the screen
	surface.DrawTexturedRect((sw - iw) / 2, sh - ih, iw, ih)
end

-- dark side panel. style "sub" (strong), "menu" (main menu), "box"
function UI.Shade(style)
	local d = C.dark
	local H = AN.VH
	local y = -AN.OY
	if AN.OX > 0 then AN.Box(-AN.OX, y, AN.OX, H, Color(d.r, d.g, d.b, 242)) end
	if style == "menu" then
		AN.HGrad(0, y, 580, H, d, 242, 217)
		AN.HGrad(580, y, 480, H, d, 217, 64)
		AN.HGrad(1060, y, 380, H, d, 64, 0)
	elseif style == "box" then
		AN.HGrad(0, y, 540, H, d, 235, 180)
		AN.HGrad(540, y, 420, H, d, 180, 0)
	else
		local rest = 51 + (style == "settings" and 38 or 0)
		AN.HGrad(0, y, 640, H, d, 242, 224)
		AN.HGrad(640, y, 320, H, d, 224, 90)
		AN.HGrad(960, y, 600, H, d, 90, rest)
		AN.Box(1560, y, AN.VW - 1560, H, Color(d.r, d.g, d.b, rest))
	end
end

-- outline pill button with text; returns width
function UI.Pill(id, text, x, y, fn, size, opts)
	size = size or 24
	local tw = AN.TextSize(text, "bold", size)
	local w, h = tw + 52, size + 26
	local hot = UI.Button(id, x, y, w, h, fn, opts)
	if hot then AN.Box(x, y, w, h, Color(255, 241, 207, 28), h / 2) end
	AN.Outline(x, y, w, h, hot and C.gold or Color(255, 241, 207, 90), h / 2, 2)
	AN.Text(text, "bold", size, x + w / 2, y + h / 2, hot and C.gold or C.cream, 1, 1)
	return w
end

function UI.BackButton(target)
	UI.Pill("back", AN.L("back"), 110, 60, function() UI.Open(target or "main") end)
end

function UI.CornerButtons(onQuit)
	local x = AN.VW - 36 - 80
	-- Lyd: all on -> music off -> mute (like the original)
	local mode = AN.SoundMode()
	local hotL = UI.Button("corner_sound", x - 94, 30, 80, 80, function() AN.CycleSoundMode() end)
	AN.Img("ui/lyd.png", x - 94 + (hotL and -3 or 0), 30 + (hotL and -3 or 0), hotL and 86 or 80, hotL and 86 or 80, mode == 2 and 120 or 255)
	if mode > 0 then
		surface.SetDrawColor(mode == 2 and Color(200, 32, 45) or Color(255, 215, 106))
		local a, b = AN.PX(x - 94 + 14), AN.SY(30 + 66)
		local c, d = AN.PX(x - 94 + 66), AN.SY(30 + 14)
		for o = -2, 2 do surface.DrawLine(a + o, b, c + o, d) end
	end
	if hotL then
		local tip = mode == 0 and AN.L("snd_all") or (mode == 1 and AN.L("snd_nomusic") or AN.L("snd_mute"))
		AN.Text(tip, "black", 18, x - 54, 122, AN.Col.cream, 1)
	end
	local hotQ = UI.Button("corner_quit", x, 30, 80, 80, onQuit or function() UI.Open("main") end, { voice = { "luk_rollover", 45 / 25 } })
	AN.Img("ui/luk.png", x + (hotQ and -3 or 0), 30 + (hotQ and -3 or 0), hotQ and 86 or 80, hotQ and 86 or 80)
end

-- big red button (Spil!, Prøv igen)
function UI.RedButton(id, text, x, y, w, h, size, fn, disabled)
	local hot = (not disabled) and UI.Button(id, x, y, w, h, fn)
	local press = hot and input.IsMouseDown(MOUSE_LEFT)
	local oy = press and 4 or 0
	if disabled then
		AN.Box(x, y, w, h, Color(110, 70, 60, 200), 20)
		AN.Text(text, "title", size, x + w / 2, y + h / 2, Color(255, 241, 207, 140), 1, 1)
		return
	end
	AN.Box(x, y + 6, w, h, C.redDark, 20)
	if hot then AN.Glow(x + w / 2, y + h / 2, w * 0.6, Color(255, 120, 80), 0.6) end
	AN.Box(x, y + oy, w, h, hot and Color(222, 44, 57) or C.red, 20)
	AN.Text(text, "title", size, x + w / 2, y + oy + h / 2, C.white, 1, 1)
end

-- secondary outlined rounded button
function UI.GhostButton(id, text, x, y, w, h, fn, size)
	size = size or 24
	local hot = UI.Button(id, x, y, w, h, fn)
	if hot then AN.Box(x, y, w, h, Color(255, 241, 207, 24), 20) end
	AN.Outline(x, y, w, h, hot and C.gold or Color(255, 241, 207, 90), 20, 2)
	AN.Text(text, "bold", size, x + w / 2, y + h / 2, hot and C.gold or C.cream, 1, 1)
end

-- dark card
function UI.Card(x, y, w, h)
	AN.Box(x, y, w, h, Color(20, 8, 2, 184), 20)
end

-- segmented choice: options = { {label, value}, ... }
function UI.Choice(idp, x, y, w, h, options, current, onPick, disabledFn)
	local n = #options
	local gap = 12
	local bw = (w - gap * (n - 1)) / n
	for i, o in ipairs(options) do
		local bx = x + (i - 1) * (bw + gap)
		local sel = o[2] == current
		local hot = UI.Button(idp .. i, bx, y, bw, h, function() onPick(o[2]) end)
		if sel then
			AN.Box(bx, y, bw, h, C.gold, 16)
			AN.TextFit(o[1], "black", 24, bx + bw / 2, y + h / 2, bw - 20, C.brown, 1, 1)
		else
			if hot then AN.Box(bx, y, bw, h, Color(255, 241, 207, 22), 16) end
			AN.Outline(bx, y, bw, h, hot and C.gold or Color(255, 241, 207, 77), 16, 2)
			AN.TextFit(o[1], "bold", 24, bx + bw / 2, y + h / 2, bw - 20, hot and C.gold or C.cream, 1, 1)
		end
	end
end

-- checkbox toggle with label
function UI.Toggle(id, x, y, value, onToggle)
	local hot = UI.Button(id, x, y, 110, 40, function() onToggle(not value) end)
	if value then
		AN.Box(x, y + 3, 34, 34, C.gold, 7)
		-- tick
		surface.SetDrawColor(C.brown)
		local a = { AN.PX(x + 8), AN.SY(y + 20) }
		local b = { AN.PX(x + 15), AN.SY(y + 28) }
		local c = { AN.PX(x + 27), AN.SY(y + 11) }
		for o = -1, 1 do
			surface.DrawLine(a[1], a[2] + o, b[1], b[2] + o)
			surface.DrawLine(b[1], b[2] + o, c[1], c[2] + o)
		end
	else
		AN.Outline(x, y + 3, 34, 34, hot and C.gold or Color(255, 241, 207, 140), 7, 2)
	end
	AN.Text(value and AN.L("on") or AN.L("off"), "bold", 22, x + 48, y + 20, hot and C.gold or C.cream, 0, 1)
end

-- horizontal slider 0..100
function UI.Slider(id, x, y, w, value, onChange)
	local h = 34
	local function set(mx)
		local v = math.Clamp(math.Round((mx - x) / w * 100), 0, 100)
		onChange(v)
	end
	UI.Button(id, x, y, w, h, nil, { press = function(mx)
		set(mx)
		UI.BeginDrag({ move = function(mx2) set(mx2) end })
	end })
	AN.Box(x, y + h / 2 - 6, w, 12, Color(255, 241, 207, 38), 6)
	AN.Box(x, y + h / 2 - 6, w * value / 100, 12, C.gold, 6)
	AN.Circle(x + w * value / 100, y + h / 2, 15, C.gold)
	AN.Circle(x + w * value / 100, y + h / 2, 9, C.cream)
end

-- generic drag follow: screens call this in Think so drags with "move" update while held
hook.Add("Think", "AN_DragMove", function()
	local d = UI.drag
	if d and d.move then
		if input.IsMouseDown(MOUSE_LEFT) then
			d.move(UI.mx, UI.my)
		else
			UI.drag = nil
			if d.release then d.release(UI.mx, UI.my) end
		end
	end
end)

-- left-side list entry (Spumoni title + optional subtitle + optional right text)
function UI.ListItem(id, x, y, w, h, title, sub, right, selected, fn, icon, titleSize, opts)
	local hot = UI.Button(id, x, y, w, h, fn, opts)
	if selected then
		AN.HGrad(x, y, w, h, Color(255, 190, 90), 82, 10)
		AN.Box(x, y, 4, h, C.gold)
	elseif hot then
		AN.Box(x, y, w, h, Color(255, 241, 207, 20), 18)
	end
	local tx = x + 24
	if icon then
		AN.ImgFit(icon, x + 24, y + (h - 76) / 2, 76, 76)
		tx = x + 122
	end
	local ts = titleSize or (selected and 48 or 40)
	local titleCol = (selected or hot) and C.white or C.cream
	if sub then
		AN.TextFit(title, "title", ts, tx, y + h / 2 - 14, w - (tx - x) - 90, titleCol, 0, 1)
		AN.Text(sub, "bold", 19, tx, y + h / 2 + 22, selected and C.gold or C.sand, 0, 1)
	else
		AN.TextFit(title, "title", ts, tx, y + h / 2, w - (tx - x) - 90, titleCol, 0, 1)
	end
	if right then AN.Text(right, "black", 20, x + w - 24, y + h / 2, selected and C.gold or C.sand, 2, 1) end
	return hot
end

-- speech bubble (cream, tail bottom-right)
function UI.Bubble(text, rx, y, maxw, size)
	size = size or 28
	local lines = AN.Wrap(text, "bold", size, maxw - 56)
	local lw = 0
	for _, l in ipairs(lines) do lw = math.max(lw, AN.TextSize(l, "bold", size)) end
	local w = lw + 56
	local lh = size * 1.3
	local h = #lines * lh + 40
	local x = rx - w
	AN.Box(x + 4, y + 10, w, h, Color(0, 0, 0, 90), 26)
	draw.RoundedBoxEx(AN.SX(26), AN.PX(x), AN.SY(y), AN.SX(w), AN.SX(h), C.cream, true, true, true, false)
	for i, l in ipairs(lines) do
		AN.Text(l, "bold", size, x + 28, y + 20 + (i - 1) * lh, C.brown)
	end
	return w, h
end
