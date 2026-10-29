-- Christmas decorations: the original fir branches, with the original ornaments hanging
-- from them on a thread that is wound around a twig of the branch.
AN = AN or {}
AN.Deco = AN.Deco or {}
local D = AN.Deco

-- points on a twig of each branch picture (fraction of width, height), unflipped
local TWIGS = {
	["ui/br_plain.png"]   = { { 0.25, 0.47 }, { 0.45, 0.39 }, { 0.62, 0.36 }, { 0.80, 0.24 } },
	["ui/br_baubles.png"] = { { 0.13, 0.36 }, { 0.30, 0.27 }, { 0.45, 0.31 } },
	["ui/br_heart.png"]   = { { 0.25, 0.61 }, { 0.45, 0.53 }, { 0.88, 0.11 } },
}
local THREAD = Color(240, 226, 190)

local function imgFlip(path, x, y, w, h, alpha, col)
	local m = AN.Mat(path)
	col = col or color_white
	surface.SetDrawColor(col.r, col.g, col.b, alpha or 255)
	surface.SetMaterial(m)
	surface.DrawTexturedRectUV(AN.PX(x), AN.SY(y), AN.SX(w), AN.SX(h), 1, 0, 0, 1)
end

-- draws a branch (with a soft shadow) and returns a function giving its twig points
function D.Branch(path, x, y, w, flip)
	local h = w * AN.Ratio(path)
	if flip then
		imgFlip(path, x + 6, y + 12, w, h, 70, Color(0, 0, 0))
		imgFlip(path, x, y, w, h)
	else
		AN.Img(path, x + 6, y + 12, w, h, 70, Color(0, 0, 0))
		AN.Img(path, x, y, w, h)
	end
	local pts = TWIGS[path] or {}
	return function(i)
		local p = pts[i]
		if not p then return nil end
		local fx = flip and (1 - p[1]) or p[1]
		return x + fx * w, y + p[2] * h
	end
end

local function line(x1, y1, x2, y2, col, thick)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local a, b, c, d = AN.PX(x1), AN.SY(y1), AN.PX(x2), AN.SY(y2)
	thick = math.max(1, math.floor((thick or 2) * AN.S + 0.5))
	for o = 0, thick - 1 do
		surface.DrawLine(a + o, b, c + o, d)
	end
end

-- an ornament hanging from a twig point: the thread is wound around the twig a few times,
-- then hangs straight down to the ornament's own hanger. maxBottom keeps it clear of content.
function D.Hang(px, py, len, id, w, maxBottom)
	if not px then return end
	local p = "wrap/orn_" .. id .. ".png"
	local h = w * AN.Ratio(p)
	if maxBottom then len = math.min(len, maxBottom - py - h) end
	if len < 8 then return end
	-- the ornament hangs by its own cap, right under the thread
	local cap = AN.OrnCap and AN.OrnCap[id] or { 0.5, 0 }
	local ox, oy = px - cap[1] * w, py + len - cap[2] * h - 1
	-- shadow of thread + ornament
	line(px + 3, py + 6, px + 3, py + len + 6, Color(0, 0, 0, 60), 2)
	AN.Img(p, ox + 5, oy + 9, w, h, 70, Color(0, 0, 0))
	-- thread
	line(px, py + 2, px, py + len + 3, THREAD, 2)
	-- wound around the twig: a few short slanted turns
	for i = 0, 2 do
		local yy = py - 5 + i * 4
		line(px - 6, yy + 3, px + 6, yy - 2, THREAD, 2)
	end
	line(px - 6, py + 6, px + 1, py + 9, THREAD, 2)
	AN.Img(p, ox, oy, w, h)
end

-- hang from twig i of a branch drawn with D.Branch
function D.HangAt(t, i, len, id, w, maxBottom)
	local px, py = t(i)
	D.Hang(px, py, len, id, w, maxBottom)
end

-- wide screens: garland in the room on the sides (outside the content)
function D.SideGarland()
	local VW = AN.VW
	local t = D.Branch("ui/br_heart.png", -150, 300, 420)
	D.HangAt(t, 2, 120, "kugle5", 42)
	D.HangAt(t, 3, 60, "stok0", 26)
	t = D.Branch("ui/br_baubles.png", VW - 250, 300, 360)
	D.HangAt(t, 2, 150, "kugle4", 38)
	t = D.Branch("ui/br_baubles.png", -120, 700, 400, true)
	D.HangAt(t, 2, 70, "hjerte0", 40)
	t = D.Branch("ui/br_heart.png", VW - 300, 760, 380, true)
	D.HangAt(t, 2, 80, "star0", 48)
end

-- the menu screens: a garland along the top between the left column and the corner buttons,
-- and a branch in the bottom right corner
function D.MenuGarland()
	local VW = AN.VW
	local x0, x1 = 560, VW - 300
	local maxBottom = 140
	local i = 0
	local orns = { "kugle4", "star0", "kugle1", "hjerte0", "kugle5", "stok0", "kugle4", "star0" }
	local k = 0
	local x = x0
	while x + 380 <= VW - 230 do
		local path = (i % 2 == 0) and "ui/br_plain.png" or "ui/br_baubles.png"
		local w = (i % 2 == 0) and 380 or 340
		local flip = (i % 3 == 1)
		local y = (i % 2 == 0) and -46 or -70
		local t = D.Branch(path, x, y, w, flip)
		for j = 1, 2 do
			local px, py = t(j + (i % 2))
			if px and px < x1 and px > x0 - 40 then
				k = k + 1
				local id = orns[(k - 1) % #orns + 1]
				D.Hang(px, py, 30 + (k * 17) % 40, id, id == "stok0" and 22 or (id == "star0" and 40 or 30), maxBottom)
			end
		end
		x = x + w - 70
		i = i + 1
	end
	D.Branch("ui/br_heart.png", VW - 330, 1080 - 150, 380, true)
end
