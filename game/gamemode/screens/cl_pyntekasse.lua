-- Pyntekassen: zooms in on the tree from the main menu. Drag decorations from the
-- box onto the tree, drag them off again to put them back. New ones come from the pebernødder you win in the games.
local UI, C = AN.UI, AN.Col
local S = {}
AN.Screens.pyntekasse = S

local ZOOM_TIME = 0.8

function S:Open(args)
	self.t0 = RealTime()
	self.zoom = args.zoom
	self.dragging = nil   -- { id = "red", fromTree = index or nil }
	self.flash = 0
	-- original: before 14 December Pyrus says the box is for looking, after that it's time to decorate
	if AN.IsDecember() and AN.Today() < 14 then AN.Speak("skattekiste_01") else AN.Speak("skattekiste_02") end
end

local function ease(t) return 1 - (1 - t) ^ 3 end

function S:TreePos()
	local R = AN.R
	local t = 1
	if self.zoom then t = ease(math.Clamp((RealTime() - self.t0) / ZOOM_TIME, 0, 1)) end
	local fx = Lerp(t, 1430 + AN.C, 880 + AN.C)
	local fy = Lerp(t, 225, 70)
	local sc = Lerp(t, 0.638, 1)
	local soft = Lerp(t, 4, 0)
	local shade = Lerp(t, 209, 255)
	return fx, fy, sc, soft, shade, t
end

-- is a point (tree coords) on the tree?
local function onTree(x, y)
	local _, ty = AN.TreeImageRect()
	local apexY, baseY = ty + 70, 860
	if y < apexY - 40 or y > baseY then return false end
	local half = math.max(0, (y - apexY) / (baseY - apexY)) * 360 + 40
	return math.abs(x - 410) <= half
end

function S:Paint()
	local R = AN.R
	local fx, fy, sc, soft, shade, t = self:TreePos()

	UI.Background("box", Lerp(t, 1, 1.25))
	-- warm light behind the tree
	AN.Glow(fx + 410 * sc, fy + 540 * sc, 520 * sc, Color(255, 190, 90), 0.5 * t)
	UI.Shade("box")

	-- tree with its ornaments
	AN.Shadow(fx + 110 * sc, fy + (AN.TREE_H - 76) * sc, 600 * sc, 70 * sc, 160)
	local skip = self.dragging and self.dragging.fromTree or nil
	AN.DrawTree(fx, fy, sc, soft, shade, skip)

	-- placed ornaments can be picked up again (only once the zoom is done)
	if t >= 1 then
		local tree = AN.Save.Tree()
		for i = #tree, 1, -1 do
			local o = tree[i]
			local def = AN.OrnamentById[o.id]
			if def and i ~= skip then
				local rx, ry, rw, rh = AN.OrnamentRect(o.id, AN.ORN_TREE_SCALE)
				UI.Button("placed" .. i, fx + o.x + rx, fy + o.y + ry, rw, rh, nil, { press = function()
					self:BeginDrag(o.id, i)
				end, right = function()
					AN.Save.RemoveOrnament(i)
					AN.Sound("flap")
				end })
			end
		end
	end

	UI.BackButton("main")

	-- left panel
	local x, y = 110, 170
	AN.Img("ui/kiste.png", x, y, 110)
	AN.Text(AN.L("box_title"), "title", 64, x + 128, y + 4, C.white)
	AN.Text(AN.L("box_hint"), "black", 20, x + 128, y + 76, C.gold)
	y = y + 138

	-- inventory: every ornament you have won, with how many
	local items = {}
	for _, o in ipairs(AN.Ornaments) do
		local c = AN.Save.Inv()[o.id] or 0
		if c > 0 then items[#items + 1] = { def = o, count = c } end
	end
	local cols = 6
	local cw, ch, gap = (640 - (cols - 1) * 10) / cols, 112, 10
	if #items == 0 then
		AN.Box(x, y, 640, ch, Color(255, 241, 207, 18), 18)
		AN.TextWrap(AN.L("box_empty"), "bold", 22, x + 24, y + 26, 590, C.sand, 30)
		y = y + ch + gap
	end
	for i, it in ipairs(items) do
		local cx = x + ((i - 1) % cols) * (cw + gap)
		local cy = y + math.floor((i - 1) / cols) * (ch + gap)
		local hot = UI.Button("inv" .. it.def.id, cx, cy, cw, ch, nil, { press = function()
			self:BeginDrag(it.def.id, nil)
		end })
		AN.Box(cx, cy, cw, ch, Color(255, 241, 207, hot and 40 or 26), 14)
		AN.Outline(cx, cy, cw, ch, hot and C.gold or Color(255, 241, 207, 46), 14, 2)
		local dragHere = self.dragging and self.dragging.id == it.def.id and not self.dragging.fromTree
		AN.ImgFit(it.def.img, cx + 12, cy + 10, cw - 24, ch - 34, dragHere and 120 or 255)
		AN.Text("×" .. it.count, "black", 18, cx + cw - 10, cy + ch - 26, C.gold, 2)
	end
	if #items > 0 then y = y + math.ceil(#items / cols) * (ch + gap) end
	y = y + 12

	-- the next ornament you get when you have collected enough pebernødder (original reward system)
	local nxt = AN.Save.NextReward()
	local coins = AN.Save.Coins()
	AN.Box(x, y, 640, 120, Color(255, 190, 90, 41), 18)
	AN.ImgFit(nxt.img, x + 18, y + 14, 60, 92)
	AN.Text(AN.L("box_next"), "black", 18, x + 96, y + 16, C.sand)
	AN.Text(coins .. " / " .. nxt.price, "black", 28, x + 640 - 22, y + 10, C.gold, 2)
	AN.TextWrap(AN.L("box_need", nxt.price - coins), "bold", 20, x + 96, y + 50, 520, C.white, 27)
	y = y + 130
	AN.Box(x, y, 640, 12, Color(255, 241, 207, 38), 6)
	AN.Box(x, y, 640 * math.Clamp(coins / nxt.price, 0, 1), 12, C.gold, 6)

	-- bottom notes
	AN.Text(AN.L("box_spots", #AN.Save.Tree()), "black", 20, x, 1080 - 76, Color(255, 241, 207, 180))
	AN.Text(AN.L("box_remove"), "bold", 17, x, 1080 - 46, Color(255, 241, 207, 130))

	UI.CornerButtons()

	-- the ornament being dragged
	if self.dragging then
		local mx, my = UI.mx, UI.my
		local tx, ty = (mx - fx) / sc, (my - fy) / sc
		local ok = onTree(tx, ty)
		local s2 = AN.ORN_TREE_SCALE * sc
		local rx, ry, rw, rh = AN.OrnamentRect(self.dragging.id, s2)
		if ok then AN.Glow(mx + rx + rw / 2, my + ry + rh / 2, math.max(rw, rh) * 0.8, C.gold, 0.5) end
		AN.DrawOrnament(self.dragging.id, mx, my, s2, ok and 255 or 190)
	end
end

function S:BeginDrag(id, fromTree)
	self.dragging = { id = id, fromTree = fromTree }
	AN.Sound("over")
	UI.BeginDrag({
		move = function() end,
		release = function(mx, my) self:Drop(mx, my) end,
	})
end

function S:Drop(mx, my)
	local d = self.dragging
	self.dragging = nil
	if not d then return end
	local fx, fy, sc = self:TreePos()
	local tx, ty = (mx - fx) / sc, (my - fy) / sc
	if onTree(tx, ty) then
		if d.fromTree then
			AN.Save.MoveOrnament(d.fromTree, tx, ty)
		else
			AN.Save.PlaceOrnament(d.id, tx, ty)
		end
		AN.Sound("click")
	elseif d.fromTree then
		AN.Save.RemoveOrnament(d.fromTree)
		AN.Sound("flap")
	end
end
