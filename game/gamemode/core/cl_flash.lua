-- A small Flash player for symbols exported by flash_export.py. Like Flash, every sprite instance
-- has its own frame counter, playing state, labels and display list; sprite children are their own
-- instances that keep running while they stay on the same depth. Frame scripts are given by the
-- game as Lua functions (FL.SetActions). Drawing goes through the minigame stage (TL.Pic / TL.Text).
--   local c = FL.New("g01sg", "pigeBamse")    -- by export name or character id
--   FL.Tick(c)                                 -- once per Flash frame
--   FL.Draw(c, matrix)                         -- stage matrix {a,b,c,d,tx,ty}
--   FL.GotoAndStop(c, "walk"), FL.Child(c, "side"), FL.Bounds(c, matrix), FL.HitTest(a, ma, b, mb)
AN = AN or {}
AN.FL = AN.FL or {}
local FL = AN.FL
local TL = AN.TL

FL.actions = FL.actions or {}   -- [lib][cid][frame] = function(clip)
FL.ImgSwap = FL.ImgSwap or {}
FL.LoadHidden = FL.LoadHidden or {}
FL.WrapDyn = FL.WrapDyn or {}
local function MG_S(v) return AN.MG.S(v) end

local function libOf(lib) return AN.FLib[lib] end

local function resolveId(lib, ref)
	if type(ref) == "number" then return ref end
	local L = libOf(lib)
	return L and L.exports[string.lower(ref)]
end
FL.Resolve = resolveId

-- frame scripts: FL.SetActions("g01sg", "pigeBamse" or cid, { [1] = function(c) FL.Stop(c) end, ... })
function FL.SetActions(lib, ref, frames)
	local id = resolveId(lib, ref)
	if not id then return end
	FL.actions[lib] = FL.actions[lib] or {}
	FL.actions[lib][id] = frames
end

local function frameList(def, f)
	local fr = def[4][f]
	local guard = 0
	while type(fr) == "number" and guard < 10000 do
		fr = def[4][fr]
		guard = guard + 1
	end
	return fr or {}
end

-- a new instance of a sprite (or button / shape) character
function FL.New(lib, ref, parent, name)
	local id = resolveId(lib, ref)
	local L = libOf(lib)
	local def = L and id and L.chars[id]
	local c = {
		lib = lib, id = id, def = def, kind = def and def[1] or "none",
		frame = 1, playing = true, vars = {}, kids = {}, parent = parent, name = name,
		visible = true,
	}
	-- FL.LoadHidden[lib][cid]: clips whose onClipEvent(load) sets _visible = false (every time they
	-- are placed again)
	if FL.LoadHidden[lib] and id and FL.LoadHidden[lib][id] then c.visible = false end
	if c.kind == "spr" then
		c.nframes = def[2]
		FL.Rebuild(c)
		FL.RunActions(c)
	else
		c.playing = false
	end
	return c
end

function FL.RunActions(c)
	local a = FL.actions[c.lib] and FL.actions[c.lib][c.id]
	local fn = a and a[c.frame]
	if fn then fn(c) end
	-- sounds started on this frame
	local snd = c.def and c.def[5] and c.def[5][c.frame]
	if snd and FL.OnSound then
		for _, s in ipairs(snd) do FL.OnSound(c, s) end
	end
end

-- (re)create the child instances for the current frame: kept while the instance stays, new ones
-- start at their frame 1
function FL.Rebuild(c)
	if c.kind ~= "spr" then return end
	local items = frameList(c.def, c.frame)
	local keep = {}
	local L = libOf(c.lib)
	for _, it in ipairs(items) do
		local inst, cid = it[3], it[2]
		local ch = L.chars[cid]
		if ch and (ch[1] == "spr" or ch[1] == "btn") then
			keep[inst] = true
			if not c.kids[inst] then
				local k = FL.New(c.lib, cid, c, it.nm)
				c.kids[inst] = k
				k.fresh = true
			end
			c.kids[inst].name = it.nm
		end
	end
	for inst in pairs(c.kids) do
		if not keep[inst] then c.kids[inst] = nil end
	end
end

local function labelFrame(c, target)
	if type(target) == "number" then return target end
	local f = c.def and c.def[3] and c.def[3][string.lower(target)]
	return f
end

function FL.Goto(c, target, play)
	if c.kind ~= "spr" then return end
	local f = labelFrame(c, target)
	if not f then return end
	f = math.Clamp(math.floor(f), 1, c.nframes)
	c.playing = play and true or false
	if f ~= c.frame then
		c.frame = f
		FL.Rebuild(c)
		FL.RunActions(c)
	end
end
function FL.GotoAndStop(c, t) FL.Goto(c, t, false) end
function FL.GotoAndPlay(c, t) FL.Goto(c, t, true) end
function FL.Stop(c) c.playing = false end
function FL.Play(c) c.playing = true end
function FL.NextFrame(c) FL.Goto(c, math.min(c.frame + 1, c.nframes or 1), false) end
function FL.PrevFrame(c) FL.Goto(c, math.max(c.frame - 1, 1), false) end

-- one Flash frame: advance this clip, then its children (new children wait a frame)
function FL.Tick(c)
	if c.kind ~= "spr" then return end
	if c.playing and c.nframes > 1 then
		local f = c.frame + 1
		if f > c.nframes then f = 1 end
		c.frame = f
		FL.Rebuild(c)
		FL.RunActions(c)
	elseif c.playing and c.nframes == 1 then
		-- a one-frame clip that is "playing" runs its frame actions every frame in Flash
	end
	for _, k in pairs(c.kids) do
		if k.fresh then k.fresh = nil else FL.Tick(k) end
	end
end

-- the child instance with an instance name, in the current frame
function FL.Child(c, name)
	if not c or c.kind ~= "spr" then return nil end
	name = string.lower(name)
	for _, it in ipairs(frameList(c.def, c.frame)) do
		if it.nm and string.lower(it.nm) == name then return c.kids[it[3]] end
	end
	return nil
end

local function mul(P, C) return TL.Mul(P, C) end
local function itemM(it) return { it[4], it[5], it[6], it[7], it[8], it[9] } end

-- draw a clip with the stage matrix M; alpha and colour multipliers go down the tree
function FL.Draw(c, M, alpha, col)
	if not c or not c.visible then return end
	alpha = (alpha or 1) * (c.alpha or 1)   -- c.alpha: a script's _alpha (0..1)
	-- c.drawFn: the game draws this clip itself (e.g. a movie loaded into it), at its place in the depth order
	if c.drawFn then c.drawFn(M, alpha, col) return end
	if c.col then
		-- c.col: a script's Color object (setRGB = { 0, 0, 0, r, g, b }); the parents' transform goes on top
		local x = c.col
		if col then
			col = { col[1] * x[1], col[2] * x[2], col[3] * x[3], col[1] * x[4] + (col[4] or 0), col[2] * x[5] + (col[5] or 0), col[3] * x[6] + (col[6] or 0) }
		else
			col = x
		end
	end
	if c.kind == "spr" then
		local L = libOf(c.lib)
		local items = frameList(c.def, c.frame)
		local maskUntil = nil
		for _, it in ipairs(items) do
			if maskUntil and it[1] > maskUntil then
				FL.PopClip()
				maskUntil = nil
			end
			if it.cd then
				-- a mask: the items up to its clip depth are clipped to its bounding box (masks here are rectangles)
				local mk = c.kids[it[3]]
				local x0, y0, x1, y1 = FL.ItemBounds(c, L, it, mul(M, (mk and mk.mat) or itemM(it)))
				if maskUntil then FL.PopClip() end
				FL.PushClip(x0, y0, x1, y1)
				maskUntil = it.cd
			else
				local kid = c.kids[it[3]]
				local m = mul(M, (kid and kid.mat) or itemM(it))   -- kid.mat: a script moved the clip (_x, _y, _rotation, _xscale)
				local a, cc = alpha, col
				if it.cx then
					-- colour transforms combine like Flash: x * mul + add, the parent's applied after the child's
					local x = it.cx
					a = alpha * x[4]
					local pm1, pm2, pm3 = col and col[1] or 1, col and col[2] or 1, col and col[3] or 1
					local pa1, pa2, pa3 = col and col[4] or 0, col and col[5] or 0, col and col[6] or 0
					cc = { pm1 * x[1], pm2 * x[2], pm3 * x[3], pm1 * (x[5] or 0) + pa1, pm2 * (x[6] or 0) + pa2, pm3 * (x[7] or 0) + pa3 }
				end
				if a > 0.004 then FL.DrawChar(c, L, it, m, a, cc) end
			end
		end
		if maskUntil then FL.PopClip() end
		-- clips a script made at run time (attachMovie / duplicateMovieClip): { c = clip, m = matrix }, drawn on top
		if c.extra then
			for _, e in ipairs(c.extra) do FL.Draw(e.c, mul(M, e.m), alpha * (e.a or 1), e.col or col) end
		end
	elseif c.kind == "btn" then
		local L = libOf(c.lib)
		for _, it in ipairs(c.def[2]) do
			FL.DrawChar(c, L, it, mul(M, itemM(it)), alpha, col)
		end
	end
end

-- a text colour through a colour transform
local function txtCol(r, g, b, col)
	if not col then return Color(r, g, b) end
	return Color(math.Clamp(r * col[1] + (col[4] or 0), 0, 255), math.Clamp(g * col[2] + (col[5] or 0), 0, 255), math.Clamp(b * col[3] + (col[6] or 0), 0, 255))
end

local function picCol(path, x, y, w, h, m, a, col)
	if col then
		-- tinted (colour transform: the multiplier, plus the added colour as it shows on white)
		local r = math.Clamp(col[1] + (col[4] or 0) / 255, 0, 1)
		local g = math.Clamp(col[2] + (col[5] or 0) / 255, 0, 1)
		local b = math.Clamp(col[3] + (col[6] or 0) / 255, 0, 1)
		if math.abs(r - 1) > 0.01 or math.abs(g - 1) > 0.01 or math.abs(b - 1) > 0.01 then
			FL.tint = { r, g, b }
		end
	end
	TL.Pic(path, x, y, w, h, m, a)
	FL.tint = nil
end

function FL.DrawChar(c, L, it, m, a, col)
	local ch = L.chars[it[2]]
	if not ch then return end
	local kind = ch[1]
	if kind == "img" then
		-- a picture with text in it can have a version per language: FL.ImgSwap[path][lang] = path
		local path = ch[2]
		local sw = FL.ImgSwap[path]
		if sw and sw[AN.LangCode()] then path = sw[AN.LangCode()] end
		picCol(path, ch[3], ch[4], ch[5], ch[6], m, a, col)
	elseif kind == "tiles" then
		for _, t in ipairs(ch[2]) do picCol(t[1], t[2], t[3], t[4], t[5], m, a, col) end
	elseif kind == "morph" then
		local r = it.r or 0
		local best, bk
		for k, v in pairs(ch[2]) do
			if not best or math.abs(k - r) < math.abs(bk - r) then best, bk = v, k end
		end
		if best and best[1] == "img" then picCol(best[2], best[3], best[4], best[5], best[6], m, a, col) end
	elseif kind == "spr" or kind == "btn" then
		local k = c.kids[it[3]]
		if k then FL.Draw(k, m, a, col) end
	elseif kind == "text" then
		local str = (FL.TextHook and FL.TextHook(ch[2])) or AN.L(ch[2])
		local tcol = txtCol(ch[6], ch[7], ch[8], col)
		local lines = string.Explode("\n", str)
		local lh = ch[10] or ch[5]
		for i, line in ipairs(lines) do
			local ly = ch[4] + (i - (#lines + 1) / 2) * lh
			local lx = ch[12] == 0 and ch[9] or ch[3]
			local px, py = TL.Apply(m, lx, ly)
			-- a translation (or our wider font) is made smaller to fit the original's width
			local ow = 2 * (ch[3] - ch[9])
			local maxW = ow > 4 and ow * 1.06 * math.sqrt(m[1] * m[1] + m[2] * m[2]) or nil
			TL.Text(line, "title", ch[5], px, py, m, tcol, a, maxW, ch[12] == 0)
		end
	elseif kind == "dyn" then
		local v = FL.VarValue(c, ch[2])
		if v == nil then v = ch[12] end
		v = tostring(v or "")
		if v ~= "" then
			local s = math.sqrt(m[1] * m[1] + m[2] * m[2])
			local al = ch[8]
			local ax = al == 1 and (ch[3] + ch[5] - 2) or (al == 2 and (ch[3] + ch[5] / 2) or (ch[3] + 2))
			-- one line: in the middle of the box; a box made for several lines: the first line at its top
			local lineH = ch[7] * 1.2
			local ay = ch[6] > lineH * 2 and (ch[4] + 2 + lineH / 2) or (ch[4] + ch[6] / 2)
			local lm = { m[1] / s, m[2] / s, m[3] / s, m[4] / s, 0, 0 }
			-- several lines (\n or \r in the text): one under the other
			local lines = string.Explode("\n", (string.gsub(v, "\r\n?", "\n")))
			-- FL.WrapDyn[lib]: a box made for several lines wraps its words, like Flash's word wrap
			if FL.WrapDyn[c.lib] and ch[6] > lineH * 2 then
				lines = AN.Wrap(table.concat(lines, "\n"), FL.DynFace or "title", MG_S(ch[7] * s), MG_S((ch[5] - 4) * s))
			end
			-- (a field with several lines wraps in Flash: here a line too wide for the box is made smaller)
			local maxW = (#lines > 1 or ch[6] > lineH * 2) and (ch[5] - 4) * s or nil
			for i, line in ipairs(lines) do
				local px, py = TL.Apply(m, ax, ay + (i - 1) * lineH)
				TL.Text(line, FL.DynFace or "title", ch[7] * s, px, py, lm, txtCol(ch[9], ch[10], ch[11], col), a, maxW, al == 0 or (al == 1 and "right"))
			end
		end
	end
end

-- a text field's variable: looked up on the clip that holds the field (Flash timeline variables)
function FL.VarValue(c, var)
	if var == "" then return nil end
	if string.sub(var, 1, 3) == "@L:" then return AN.L(string.sub(var, 4)) end
	local name = string.match(var, "([%w_]+)$") or var
	local lname = string.lower(name)
	local cur = c
	if string.find(var, "_parent.", 1, true) then cur = c.parent or c end
	for k, v in pairs(cur.vars) do
		if string.lower(k) == lname then return v end
	end
	if FL.VarHook then return FL.VarHook(c, var) end
	return nil
end

-- bounding box of a clip through matrix M: x0, y0, x1, y1 (nil when empty)
function FL.Bounds(c, M, ignoreVisible)
	if not c then return nil end
	if not ignoreVisible and not c.visible then return nil end
	local x0, y0, x1, y1
	local function add(px, py)
		if not x0 then x0, y0, x1, y1 = px, py, px, py return end
		if px < x0 then x0 = px end
		if py < y0 then y0 = py end
		if px > x1 then x1 = px end
		if py > y1 then y1 = py end
	end
	local function rect(m, r)
		for _, p in ipairs({ { r[1], r[2] }, { r[1] + r[3], r[2] }, { r[1], r[2] + r[4] }, { r[1] + r[3], r[2] + r[4] } }) do
			add(TL.Apply(m, p[1], p[2]))
		end
	end
	local L = libOf(c.lib)
	local items = c.kind == "spr" and frameList(c.def, c.frame) or (c.kind == "btn" and c.def[2] or {})
	for _, it in ipairs(items) do
		if not it.cd then
			local kid = c.kids[it[3]]
			local m = mul(M, (kid and kid.mat) or itemM(it))
			local ch = L.chars[it[2]]
			if ch then
				local kind = ch[1]
				if kind == "img" then rect(m, { ch[3], ch[4], ch[5], ch[6] })
				elseif kind == "tiles" then
					for _, t in ipairs(ch[2]) do rect(m, { t[2], t[3], t[4], t[5] }) end
				elseif kind == "morph" then
					for _, v in pairs(ch[2]) do if v[1] == "img" then rect(m, { v[3], v[4], v[5], v[6] }) break end end
				elseif kind == "dyn" then rect(m, { ch[3], ch[4], ch[5], ch[6] })
				elseif kind == "spr" or kind == "btn" then
					local k = c.kids[it[3]]
					if k then
						local a, b, cc, d = FL.Bounds(k, m, true)
						if a then add(a, b) add(cc, d) end
					end
				end
			end
		end
	end
	-- a button with only a hit area (nothing drawn): its hit area
	if not x0 and c.kind == "btn" and c.def and c.def[3] then
		local b = c.def[3]
		rect(M, { b[1], b[2], b[3] - b[1], b[4] - b[2] })
	end
	return x0, y0, x1, y1
end

-- the exact hit test: is the stage point (x, y) on the clip drawn with matrix M? Buttons use their
-- hit area (a pixel mask from the exporter); sprites test their children, topmost first; pictures
-- count with their box.
local B64 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/"
local B64V = {}
for i = 1, 64 do B64V[string.byte(B64, i)] = i - 1 end
local function hitRows(h)
	if h.rows then return h.rows end
	local rows = {}
	for line in string.gmatch(h[3] .. "|", "([^|]*)|") do
		local r = {}
		for i = 1, #line - 1, 2 do r[#r + 1] = B64V[string.byte(line, i)] * 64 + B64V[string.byte(line, i + 1)] end
		rows[#rows + 1] = r
	end
	h.rows = rows
	return rows
end
local function invApply(m, x, y)
	local det = m[1] * m[4] - m[2] * m[3]
	if math.abs(det) < 1e-9 then return nil end
	x, y = x - m[5], y - m[6]
	return (m[4] * x - m[3] * y) / det, (-m[2] * x + m[1] * y) / det
end
function FL.HitPoint(c, M, x, y)
	if not c then return false end
	if c.kind == "btn" then
		local b, h = c.def[3], c.def[4]
		local lx, ly = invApply(M, x, y)
		if not lx or not b then return false end
		if lx < b[1] or lx > b[3] or ly < b[2] or ly > b[4] then return false end
		if not h then return true end
		local rows = hitRows(h)
		local px, py = math.floor((lx - b[1]) * 2), math.floor((ly - b[2]) * 2)
		local r = rows[py + 1]
		if not r then return false end
		for i = 1, #r - 1, 2 do
			if px >= r[i] and px < r[i + 1] then return true end
		end
		return false
	elseif c.kind == "spr" then
		if not c.visible then return false end
		local L = libOf(c.lib)
		local items = frameList(c.def, c.frame)
		for i = #items, 1, -1 do
			local it = items[i]
			if not it.cd then
				local ch = L.chars[it[2]]
				local kid = c.kids[it[3]]
				local m = mul(M, (kid and kid.mat) or itemM(it))
				if ch and (ch[1] == "spr" or ch[1] == "btn") and kid then
					if FL.HitPoint(kid, m, x, y) then return true end
				elseif ch then
					local x0, y0, x1, y1 = FL.ItemBounds(c, L, it, m)
					if x0 and x >= x0 and x <= x1 and y >= y0 and y <= y1 then return true end
				end
			end
		end
	end
	return false
end

-- for UI.Button: a hit function testing a clip (stage matrix M) under the mouse
function FL.HitFn(c, M)
	return function(vx, vy)
		local MG = AN.MG
		return FL.HitPoint(c, M, (vx - MG.x0) / MG.k, (vy - MG.y0) / MG.k)
	end
end

function FL.HitTest(a, ma, b, mb)
	local ax0, ay0, ax1, ay1 = FL.Bounds(a, ma, true)
	local bx0, by0, bx1, by1 = FL.Bounds(b, mb, true)
	if not ax0 or not bx0 then return false end
	return ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1
end

-- the matrix of a named child inside c (for hit tests on parts like a "hitbox")
function FL.ChildMatrix(c, name, M)
	name = string.lower(name)
	for _, it in ipairs(frameList(c.def, c.frame)) do
		if it.nm and string.lower(it.nm) == name then
			local kid = c.kids[it[3]]
			return mul(M, (kid and kid.mat) or itemM(it)), kid
		end
	end
	return nil
end

-- the display list of a clip's current frame, and the stage box of the first item with one of the
-- given characters (e.g. an unnamed button inside a clip): x0, y0, x1, y1
function FL.Items(c) return c and c.kind == "spr" and frameList(c.def, c.frame) or {} end
function FL.CharItem(c, M, cids)
	for _, it in ipairs(FL.Items(c)) do
		if cids[it[2]] then
			local kid = c.kids[it[3]]
			if kid then return kid, mul(M, kid.mat or itemM(it)) end
		end
	end
	return nil
end
function FL.CharBounds(c, M, cids)
	for _, it in ipairs(FL.Items(c)) do
		if cids[it[2]] then
			local kid = c.kids[it[3]]
			local m = mul(M, (kid and kid.mat) or itemM(it))
			if kid then return FL.Bounds(kid, m, true) end
		end
	end
	return nil
end

function FL.Label(c, f)
	for k, v in pairs(c.def[3] or {}) do if v == (f or c.frame) then return k end end
end

-- the bounding box (stage coordinates) of one display list item drawn with matrix m
function FL.ItemBounds(c, L, it, m)
	local ch = L.chars[it[2]]
	if not ch then return nil end
	local x0, y0, x1, y1
	local function add(px, py)
		if not x0 then x0, y0, x1, y1 = px, py, px, py return end
		x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
	end
	local function rect(r)
		for _, p in ipairs({ { r[1], r[2] }, { r[1] + r[3], r[2] }, { r[1], r[2] + r[4] }, { r[1] + r[3], r[2] + r[4] } }) do
			add(TL.Apply(m, p[1], p[2]))
		end
	end
	local kind = ch[1]
	if kind == "img" then rect({ ch[3], ch[4], ch[5], ch[6] })
	elseif kind == "tiles" then for _, t in ipairs(ch[2]) do rect({ t[2], t[3], t[4], t[5] }) end
	elseif kind == "morph" then for _, v in pairs(ch[2]) do if v[1] == "img" then rect({ v[3], v[4], v[5], v[6] }) break end end
	elseif kind == "spr" or kind == "btn" then
		local k = c.kids[it[3]]
		if k then return FL.Bounds(k, m, true) end
	end
	return x0, y0, x1, y1
end

-- clipping (masks) as scissor rectangles inside the minigame stage
FL.clipStack = {}
local function applyClip()
	local r = FL.clipStack[#FL.clipStack]
	local MG = AN.MG
	local bx0, by0 = AN.PX(MG.x0), AN.SY(MG.y0)
	local bx1, by1 = AN.PX(MG.x0 + MG.S(MG.sw or 0)), AN.SY(MG.y0 + MG.S(MG.sh or 0))
	if r then
		render.SetScissorRect(math.max(bx0, r[1]), math.max(by0, r[2]), math.min(bx1, r[3]), math.min(by1, r[4]), true)
	else
		render.SetScissorRect(bx0, by0, bx1, by1, true)
	end
end

function FL.PushClip(x0, y0, x1, y1)
	local MG = AN.MG
	local r
	if not x0 then
		r = { 0, 0, 0, 0 }
	else
		r = { AN.PX(MG.X(x0)), AN.SY(MG.Y(y0)), AN.PX(MG.X(x1)), AN.SY(MG.Y(y1)) }
	end
	local top = FL.clipStack[#FL.clipStack]
	if top then r = { math.max(r[1], top[1]), math.max(r[2], top[2]), math.min(r[3], top[3]), math.min(r[4], top[4]) } end
	if r[3] < r[1] then r[3] = r[1] end
	if r[4] < r[2] then r[4] = r[2] end
	FL.clipStack[#FL.clipStack + 1] = r
	applyClip()
end

function FL.PopClip()
	FL.clipStack[#FL.clipStack] = nil
	applyClip()
end

-- a clip found by its instance names from c (e.g. { "game", "stage", "ball" }): its stage matrix,
-- the clip, and its box on the stage (x0, y0, x1, y1). M = c's own stage matrix (default none).
function FL.PathClip(c, names, M)
	local m = M or { 1, 0, 0, 1, 0, 0 }
	local k = c
	for _, nm in ipairs(names) do
		if not k then return nil end
		m, k = FL.ChildMatrix(k, nm, m)
		if not m then return nil end
	end
	if not k then return nil end
	local x0, y0, x1, y1 = FL.Bounds(k, m, true)
	return m, k, x0, y0, x1, y1
end
