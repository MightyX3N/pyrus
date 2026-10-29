-- Summer: Is-tårnet (the ice cream tower). Pyrus runs the ice cream cart; kids (and now and then a
-- dachshund) come up with an order in a speech bubble: a cone, cup or dog bowl, scoops stacked in a
-- tower in the right order, maybe a topping on top. Build it and serve it before they run out of
-- patience. Played with the keyboard (left/right picks, Space adds, Down takes the last off, Ctrl or
-- Up serves) or the mouse. Three angry customers, or the time running out, ends the round.
local UI, C, MG = AN.UI, AN.Col, AN.MG
local SU = AN.Summer
local G = {
	scoreType = "score",
	goal = 1800,
	worst = 0,
	descKey = "su_icecream",
}
local W, H = 960, 720
local STEP = 1 / 60
local A = "is/"
local TOP = 470                 -- the counter top
local TOWER_X = 690

-- what's in the freezer row, left to right
local ITEMS = {
	{ id = "cone", kind = "box", img = "cone", w = 64, h = 96, top = 8 },
	{ id = "cup", kind = "box", img = "cup", w = 76, h = 60, top = 10 },
	{ id = "bowl", kind = "box", img = "bowl", w = 88, h = 44, top = 10 },
	{ id = "jordbaer", kind = "scoop", img = "s_jordbaer", col = Color(244, 143, 177) },
	{ id = "choko", kind = "scoop", img = "s_choko", col = Color(122, 74, 42) },
	{ id = "vanilje", kind = "scoop", img = "s_vanilje", col = Color(251, 240, 200) },
	{ id = "pistacie", kind = "scoop", img = "s_pistacie", col = Color(168, 212, 138) },
	{ id = "lakrids", kind = "scoop", img = "s_lakrids", col = Color(46, 42, 44) },
	{ id = "guf", kind = "top", img = "t_guf", w = 64, h = 44 },
	{ id = "flodebolle", kind = "top", img = "t_flodebolle", w = 56, h = 54 },
	{ id = "krymmel", kind = "top", img = "t_krymmel", w = 64, h = 30 },
	{ id = "syltetoj", kind = "top", img = "t_syltetoj", w = 64, h = 40 },
}
local BYID = {}
for i, it in ipairs(ITEMS) do it.i = i BYID[it.id] = it end
local SCOOPS = { "jordbaer", "choko", "vanilje", "pistacie", "lakrids" }
local TOPS = { "guf", "flodebolle", "krymmel", "syltetoj" }

local DIFF = {
	{ scoops = { 1, 2 }, top = 0.3, slots = 1, patience = 38, arrive = 2.0 },
	{ scoops = { 2, 4 }, top = 0.6, slots = 2, patience = 30, arrive = 1.6 },
	{ scoops = { 3, 6 }, top = 0.85, slots = 3, patience = 24, arrive = 1.2 },
}
local ROUND = 120
local LOOKS = {
	{ img = "sommer/boy_shirt.png", w = 342, h = 512, dh = 250, show = 0.62 },
	{ img = "sommer/boy_swim.png", w = 340, h = 512, dh = 250, show = 0.62 },
	{ img = "sommer/girl_dress.png", w = 440, h = 512, dh = 230, show = 0.6 },
	{ img = "sommer/girl_swim.png", w = 440, h = 512, dh = 230, show = 0.6 },
}
local DOG = { img = "sommer/dog.png", w = 588, h = 512, dh = 150, show = 0.72, dog = true }
-- where the customers stand (front first)
local SLOTS = { { x = 300, s = 1 }, { x = 170, s = 0.88 }, { x = 60, s = 0.78 } }

---------------------------------------------------------------------------
function G:Status()
	return AN.L("su_ice_status", self.score or 0, self.served or 0, math.max(0, math.ceil(ROUND - (self.time or 0))))
end

function G:Open(args)
	self.diff = SU.Diff()
	self.D = DIFF[self.diff]
	self.phase = "play"
	self.kprev = {}
	self.acc, self.t, self.time = 0, 0, 0
	self.score, self.served, self.strikes = 0, 0, 0
	self.sel = 1
	self.build = {}
	self.queue = {}
	self.leaving = {}
	self.nextArrive = 0.5
	self.finished, self.overAt = false, nil
	self.flash = nil
end
function G:Close() end

function G:Pressed(k)
	local down = input.IsKeyDown(k)
	local was = self.kprev[k]
	self.kprev[k] = down
	return down and not was
end

---------------------------------------------------------------------------
-- orders
---------------------------------------------------------------------------
function G:NewCustomer()
	local c = { t0 = self.t, x = -200 }
	if math.random() < 0.15 then
		c.look = DOG
		c.order = { "bowl" }
		for i = 1, math.random(1, 2) do c.order[#c.order + 1] = ({ "vanilje", "jordbaer" })[math.random(2)] end
	else
		c.look = LOOKS[math.random(#LOOKS)]
		c.order = { math.random() < 0.6 and "cone" or "cup" }
		local lo, hi = self.D.scoops[1], self.D.scoops[2]
		for i = 1, math.random(lo, hi) do c.order[#c.order + 1] = SCOOPS[math.random(#SCOOPS)] end
		if math.random() < self.D.top then c.order[#c.order + 1] = TOPS[math.random(#TOPS)] end
	end
	c.patience = self.D.patience + 3 * #c.order
	c.left = c.patience
	self.queue[#self.queue + 1] = c
end

-- add the chosen item to the tower (container first, scoops, one topping last)
function G:Add(i)
	local it = ITEMS[i]
	local b = self.build
	local last = b[#b] and BYID[b[#b]]
	if it.kind == "box" then
		if #b > 0 then return self:Buzz() end
	else
		if #b == 0 then return self:Buzz() end
		if last.kind == "top" then return self:Buzz() end
		if #b >= 9 then return self:Buzz() end
	end
	b[#b + 1] = it.id
	self.bump = self.t
	MG.Sound(it.kind == "scoop" and "g01" or "g21", it.kind == "scoop" and "pop" or "place", 0.7)
end
function G:Undo()
	if #self.build > 0 then table.remove(self.build) MG.Sound("g11", "lift", 0.6) end
end
function G:Buzz()
	self.flash = { t = self.t, bad = true }
	MG.Sound("g06", "error", 0.6)
end

function G:Serve()
	local c = self.queue[1]
	if not c or #self.build == 0 then return self:Buzz() end
	local ok = #self.build == #c.order
	if ok then for i = 1, #c.order do if self.build[i] ~= c.order[i] then ok = false break end end end
	if ok then
		local pts = 30 + 15 * #c.order + math.floor(40 * math.Clamp(c.left / c.patience, 0, 1))
		self.score = self.score + pts
		self.served = self.served + 1
		MG.Pop("+" .. pts, true, SLOTS[1].x, TOP - 190)
		c.happy = true
		if math.random() < 0.35 then AN.Speak(({ "megetgodt", "godt" })[math.random(2)]) end
	else
		self.score = math.max(0, self.score - 20)
		MG.Pop("-20", false, SLOTS[1].x, TOP - 190)
		c.happy = false
		self.strikes = self.strikes + 1
		AN.Speak("skidt")
	end
	table.remove(self.queue, 1)
	c.leaveAt = self.t
	c.leftFrom = c.x
	if ok then MG.Sound("ui", "point") MG.Sound("g19", "cash", 0.7) else MG.Sound("tv2", "wrong") end
	self.leaving[#self.leaving + 1] = c
	self.build = {}
	self.flash = { t = self.t, bad = not ok }
	if self.strikes >= 3 then self:Over() end
end

function G:Over()
	if self.overAt then return end
	self.overAt = self.t
	self.phase = "over"
	MG.Sound("g14", "done")
end

---------------------------------------------------------------------------
function G:Step()
	self.t = self.t + STEP
	if self.phase == "over" then
		if self.t - self.overAt > 2.2 and not self.finished then
			self.finished = true
			AN.FinishGame(102, self.score)
		end
		return
	end
	self.time = self.time + STEP
	if self.time >= ROUND then return self:Over() end
	-- keys
	if self:Pressed(KEY_LEFT) then self.sel = (self.sel - 2) % #ITEMS + 1 end
	if self:Pressed(KEY_RIGHT) then self.sel = self.sel % #ITEMS + 1 end
	if self:Pressed(KEY_SPACE) then self:Add(self.sel) end
	if self:Pressed(KEY_DOWN) then self:Undo() end
	local serve = self:Pressed(KEY_LCONTROL)
	if self:Pressed(KEY_RCONTROL) then serve = true end
	if self:Pressed(KEY_UP) then serve = true end
	if serve then self:Serve() end
	-- customers come and wait
	if #self.queue < self.D.slots then
		self.nextArrive = self.nextArrive - STEP
		if self.nextArrive <= 0 then
			self:NewCustomer()
			MG.Sound("g08", "pling", 0.6)
			self.nextArrive = self.D.arrive + math.random() * 1.5
		end
	end
	for i = #self.queue, 1, -1 do
		local c = self.queue[i]
		c.left = c.left - STEP
		if c.left <= 0 then
			-- gave up waiting
			table.remove(self.queue, i)
			c.happy = false
			c.angry = true
			c.leaveAt = self.t
			c.leftFrom = c.x
			self.leaving[#self.leaving + 1] = c
			self.strikes = self.strikes + 1
			MG.Sound("g02", "buzz")
			if i == 1 then self.build = {} end
			if self.strikes >= 3 then self:Over() end
		end
	end
	-- walking to their places
	for i, c in ipairs(self.queue) do
		local tx = SLOTS[i].x
		c.x = c.x + (tx - c.x) * math.min(1, STEP * 6)
	end
	local keep = {}
	for _, c in ipairs(self.leaving) do
		if self.t - c.leaveAt < 1.5 then keep[#keep + 1] = c end
	end
	self.leaving = keep
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local function pic(name, x, y, w, h, alpha)
	AN.Img(A .. name .. ".png", MG.X(x), MG.Y(y), MG.S(w), MG.S(h), alpha)
end
local WHITE = Color(255, 255, 255)
local INK = Color(26, 58, 84)

-- a tower: container on the base line, scoops stacked, topping on top (x = centre)
local function tower(list, x, base, s, wob, t)
	if #list == 0 then return end
	local box = BYID[list[1]]
	local bw, bh = box.w * s, box.h * s
	pic(box.img, x - bw / 2, base - bh, bw, bh)
	local y = base - bh + box.top * s
	for i = 2, #list do
		local it = BYID[list[i]]
		local sway = wob and math.sin(t * 3 + i * 0.7) * (i - 1) * 1.2 * s or 0
		if it.kind == "scoop" then
			local w, h = 72 * s, 56 * s
			pic(it.img, x - w / 2 + sway, y - h + 14 * s, w, h)
			y = y - 34 * s
		else
			local w, h = it.w * s, it.h * s
			pic(it.img, x - w / 2 + sway, y - h + (it.id == "syltetoj" and 22 or (it.id == "krymmel" and 18 or 10)) * s, w, h)
		end
	end
end

function G:DrawCustomer(c, x, s, alpha)
	local L = c.look
	local h = L.dh * s
	local w = h * L.w / L.h
	local bob = math.sin(self.t * 2 + (c.t0 or 0)) * 2
	local y = TOP - h * L.show + bob
	if c.angry and c.leaveAt then y = y + math.min(1, (self.t - c.leaveAt)) * 20 end
	AN.Img(L.img, MG.X(x - w / 2), MG.Y(y), MG.S(w), MG.S(h), alpha)
end

function G:Paint()
	MG.Stage(W, H)
	-- the beach behind, filling the view
	local vx0 = (0 - MG.x0) / MG.k
	local vx1 = (AN.VW - MG.x0) / MG.k
	local vy0 = (-AN.OY - MG.y0) / MG.k
	local vy1 = (AN.VH - AN.OY - MG.y0) / MG.k
	local bw = math.max(vx1 - vx0, (vy1 - vy0) * 16 / 9)
	local bh = bw * 9 / 16
	AN.Img("sommer/beach.jpg", MG.X((vx0 + vx1) / 2 - bw / 2), MG.Y(vy1 - bh), MG.S(bw), MG.S(bh))
	AN.Box(MG.X(vx0), MG.Y(vy0), MG.S(vx1 - vx0), MG.S(vy1 - vy0), Color(10, 40, 70, 60))
	-- the cart: poles, the awning
	AN.Box(MG.X(10), MG.Y(80), MG.S(14), MG.S(TOP - 80), Color(150, 150, 160))
	AN.Box(MG.X(936), MG.Y(80), MG.S(14), MG.S(TOP - 80), Color(150, 150, 160))
	-- Pyrus behind the cart, on the right
	local ph = 300
	AN.Img("sommer/pyrus_swim.png", MG.X(870 - ph * 440 / 640 / 2), MG.Y(TOP - ph * 0.74 + math.sin(self.t * 2) * 2), MG.S(ph * 440 / 640), MG.S(ph))
	-- the customers (back of the queue first), leaving ones walk off to the left
	for i = #self.queue, 1, -1 do
		local c = self.queue[i]
		self:DrawCustomer(c, c.x, SLOTS[i].s, 255)
	end
	for _, c in ipairs(self.leaving) do
		local k = math.min(1, (self.t - c.leaveAt) / 1.5)
		local x = (c.leftFrom or SLOTS[1].x) - k * 500
		self:DrawCustomer(c, x, 1, 255 * (1 - k))
	end
	-- the counter
	pic("counter", vx0, TOP, vx1 - vx0, 250)
	pic("awning", vx0, 0, vx1 - vx0, 110)
	-- the tower being built, on the counter
	tower(self.build, TOWER_X, TOP + 8, 1, true, self.t)
	if self.flash and self.flash.bad and self.t - self.flash.t < 0.4 then
		AN.Text("X", "title", math.floor(MG.S(60)), MG.X(TOWER_X), MG.Y(TOP - 60), Color(220, 40, 40, 255 * (1 - (self.t - self.flash.t) / 0.4)), 1, 1)
	end
	-- serve button (Ctrl / Up)
	local sx, sy, sw, sh = 770, TOP - 64, 150, 50
	local hot = UI.Button("ice_serve", MG.X(sx), MG.Y(sy), MG.S(sw), MG.S(sh), function() self:Serve() end)
	AN.Box(MG.X(sx), MG.Y(sy + 4), MG.S(sw), MG.S(sh), Color(16, 60, 96), MG.S(26))
	AN.Box(MG.X(sx), MG.Y(sy), MG.S(sw), MG.S(sh), hot and Color(44, 140, 200) or Color(31, 111, 168), MG.S(26))
	AN.Text(AN.L("su_ice_serve"), "title", math.floor(MG.S(26)), MG.X(sx + sw / 2), MG.Y(sy + sh / 2), WHITE, 1, 1)
	AN.Text(AN.L("su_ice_servekey"), "bold", math.floor(MG.S(13)), MG.X(sx + sw / 2), MG.Y(sy + sh + 14), WHITE, 1, 1)
	-- the freezer row: what you can add
	local n = #ITEMS
	local slotW = 74
	local x0 = W / 2 - n * slotW / 2
	for i, it in ipairs(ITEMS) do
		local x = x0 + (i - 1) * slotW
		local y = TOP + 70
		local sel = i == self.sel
		local hotI = UI.Button("ice_item" .. i, MG.X(x + 2), MG.Y(y), MG.S(slotW - 4), MG.S(96), function()
			self.sel = i
			self:Add(i)
		end)
		AN.Box(MG.X(x + 2), MG.Y(y), MG.S(slotW - 4), MG.S(96), sel and Color(255, 214, 64) or (hotI and Color(255, 255, 255, 230) or Color(255, 255, 255, 180)), MG.S(14))
		if sel then AN.Outline(MG.X(x + 2), MG.Y(y), MG.S(slotW - 4), MG.S(96), Color(200, 120, 0), MG.S(14), MG.S(3)) end
		local cx = x + slotW / 2
		if it.kind == "box" then
			local k = math.min(60 / it.w, 70 / it.h)
			pic(it.img, cx - it.w * k / 2, y + 48 - it.h * k / 2, it.w * k, it.h * k)
		elseif it.kind == "scoop" then
			pic(it.img, cx - 30, y + 28, 60, 47)
		else
			local k = math.min(56 / it.w, 50 / it.h)
			pic(it.img, cx - it.w * k / 2, y + 48 - it.h * k / 2, it.w * k, it.h * k)
		end
		AN.TextFit(AN.L("su_ice_" .. it.id), "bold", math.floor(MG.S(11)), MG.X(cx), MG.Y(y + 86), MG.S(slotW - 8), INK, 1, 1)
	end
	AN.Text(AN.L("su_ice_keys"), "bold", math.floor(MG.S(15)), MG.X(W / 2), MG.Y(TOP + 186), INK, 1, 1)
	-- the orders: a bubble beside the first customer, a patience bar over everyone's head
	for i, c in ipairs(self.queue) do
		local sl = SLOTS[i]
		local f = math.Clamp(c.left / c.patience, 0, 1)
		if i == 1 then
			local bw2 = 150
			local bh2 = math.min(330, 60 + 34 * #c.order)
			local bx, by = 470, TOP - 20 - bh2
			-- the bubble's tail points at the customer
			AN.Box(MG.X(bx - bw2 / 2), MG.Y(by), MG.S(bw2), MG.S(bh2), Color(255, 255, 255, 240), MG.S(24))
			surface.SetDrawColor(255, 255, 255, 240)
			draw.NoTexture()
			surface.DrawPoly({ { x = AN.PX(MG.X(bx - bw2 / 2 + 2)), y = AN.SY(MG.Y(by + bh2 - 60)) }, { x = AN.PX(MG.X(bx - bw2 / 2 - 34)), y = AN.SY(MG.Y(by + bh2 - 30)) }, { x = AN.PX(MG.X(bx - bw2 / 2 + 2)), y = AN.SY(MG.Y(by + bh2 - 30)) } })
			local s = math.min(0.75, (bh2 - 26) / (110 + 34 * (#c.order - 1)))
			tower(c.order, bx, by + bh2 - 14, s, false, self.t)
		end
		local w = 100 * sl.s
		local headY = TOP - c.look.dh * sl.s * c.look.show - 18
		local col = f > 0.5 and Color(70, 200, 90) or (f > 0.25 and Color(255, 196, 64) or Color(230, 60, 50))
		AN.Box(MG.X(c.x - w / 2), MG.Y(headY), MG.S(w), MG.S(10), Color(0, 0, 0, 120), MG.S(5))
		AN.Box(MG.X(c.x - w / 2), MG.Y(headY), MG.S(w * f), MG.S(10), col, MG.S(5))
	end
	MG.DrawPops()
	-- the score and the clock on the awning
	AN.Box(MG.X(W / 2 - 200), MG.Y(14), MG.S(400), MG.S(48), Color(10, 50, 80, 190), MG.S(24))
	local left = math.max(0, math.ceil(ROUND - self.time))
	AN.Text(string.format("%d:%02d", math.floor(left / 60), left % 60), "title", math.floor(MG.S(28)), MG.X(W / 2 - 110), MG.Y(38), left <= 10 and Color(255, 120, 100) or WHITE, 1, 1)
	AN.Text(AN.L("su_ice_pts", self.score), "title", math.floor(MG.S(28)), MG.X(W / 2 + 60), MG.Y(38), Color(255, 214, 64), 1, 1)
	for i = 1, 3 do
		AN.Text(i <= self.strikes and "X" or "o", "title", math.floor(MG.S(26)), MG.X(W / 2 + 230 + (i - 1) * 26), MG.Y(38), i <= self.strikes and Color(230, 60, 50) or WHITE, 1, 1)
	end
	if self.phase == "over" then
		local a = math.Clamp((self.t - self.overAt) * 2, 0, 1)
		AN.Box(MG.X(W / 2 - 300), MG.Y(H * 0.3), MG.S(600), MG.S(150), Color(10, 50, 80, 210 * a), MG.S(30))
		AN.Text(self.strikes >= 3 and AN.L("su_ice_angry") or AN.L("su_ice_closed"), "title", math.floor(MG.S(44)), MG.X(W / 2), MG.Y(H * 0.3 + 50), Color(255, 255, 255, 255 * a), 1, 1)
		AN.Text(AN.L("su_result") .. ": " .. self.score, "title", math.floor(MG.S(30)), MG.X(W / 2), MG.Y(H * 0.3 + 108), Color(255, 214, 64, 255 * a), 1, 1)
	end
	MG.Chrome(102)
end

AN.RegisterGame(102, G)
